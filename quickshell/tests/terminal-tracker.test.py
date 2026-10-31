#!/usr/bin/python3
"""Agent ownership, hidden panes, event coalescing and state-only hooks."""

import asyncio
from contextlib import redirect_stdout
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
from types import ModuleType, SimpleNamespace
import unittest
from unittest.mock import Mock, patch

config = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(config))
import agent_events
import terminal_protocol as protocol
import terminal_tracker as tracker
import terminal_labels as labels


def pane(identifier=1, program="codex", title="Agent", active=True):
    return {"id": identifier, "is_active": active, "title": title,
        "foreground_processes": [{"pid": identifier + 20, "cmdline": [program, "private-argument"]}]}


def layout():
    return [{"id": 1, "wm_class": "kitty", "tabs": [
        {"is_active": True, "windows": [pane(), pane(2, "claude", "✳ Claude Code", False)]},
        {"is_active": False, "windows": [pane(3, title="[ ! ] Action Required | Agent")]}]}]


class ProtocolTests(unittest.TestCase):
    def test_claude_footer_counts_require_the_final_footer_and_handle_zero(self):
        zero = dict(agents=0, shells=0, monitors=0)
        for mode in ('⏵⏵ bypass permissions on', '⏵⏵ accept edits on',
                '⏸ plan mode on', 'auto mode', '? for shortcuts'):
            self.assertEqual(protocol.claude_footer_counts(['Private output: 9 shells', mode, '']), zero)
            self.assertEqual(protocol.claude_footer_counts([mode + ' · 1 agent, 2 shells, 3 monitors']),
                dict(agents=1, shells=2, monitors=3))
        self.assertEqual(protocol.claude_footer_counts(
            ['⏵⏵ bypass permissions on (shift+tab to cycle) · PR #123 · 1 shell']),
            dict(agents=0, shells=1, monitors=0))
        self.assertEqual(protocol.claude_footer_counts(['2 shells, 2 monitors']),
            dict(agents=0, shells=2, monitors=2))
        for lines in ([], [''], ['Private output mentions 2 shells and 2 monitors'],
                ['⏵⏵ bypass permissions on · 2 shells', 'Choose an option'],
                ['⏵⏵ bypass permissions on · -1 shell'],
                ['⏵⏵ bypass permissions on · 10000 shells'],
                ['⏵⏵ bypass permissions on · 1 shell, 2 shells']):
            self.assertIsNone(protocol.claude_footer_counts(lines))

    def test_activity_records_accept_only_bounded_counts(self):
        for value in (None, {}, {'shells': 2}, dict(agents=True, shells=0, monitors=0),
                dict(agents=-1, shells=0, monitors=0), dict(agents=0, shells='2', monitors=0),
                dict(agents=0, shells=10000, monitors=0),
                dict(agents=0, shells=1, monitors=0, text='private')):
            self.assertIsNone(protocol.activity_counts(value))
        value = dict(agents=2, shells=3, monitors=1)
        self.assertEqual(protocol.activity_counts(value), value)

    def test_claude_session_names_strip_activity_and_skip_startup_titles(self):
        for marker in ('✳', '✳️', '✻', '⠋', '⠙', '◐', '◓', ''):
            self.assertEqual(protocol.session_name('claude', marker + ' Refactor upload cache'), 'Refactor upload cache')
        for generic in ('Claude', 'Claude Code', '✳ Claude Code', 'Claude Code v2.1.305', ''):
            self.assertEqual(protocol.session_name('claude', generic), '')
        self.assertEqual(protocol.session_name('kimi', 'Unknown title'), '')
        current = layout()
        current[0]['tabs'][0]['windows'][1]['title'] = '✳ Refactor upload cache'
        self.assertEqual(protocol.snapshot(current)[0]['panes'][1]['threadName'], 'Refactor upload cache')

    def test_codex_thread_name_comes_from_default_title_without_activity_frames(self):
        name = 'Refactor upload cache'
        for prefix in ('', '⠋ ', '⠙ ', '[ ! ] Action Required | ', '[ . ] Action Required | '):
            for suffix in ('', ' ⠋', ' ⠙'):
                title = prefix + name + suffix + ' | fixture-project'
                self.assertEqual(protocol.codex_thread_name(title), name)
                self.assertEqual(protocol.semantic_title_key('codex', title), name + ' | fixture-project')
        self.assertEqual(protocol.codex_thread_name('⠋ fixture-project'), '')
        self.assertEqual(protocol.codex_thread_name('⠋ ⠙ | fixture-project'), '')
        self.assertEqual(protocol.codex_thread_name('Name | with separator | project'), 'Name | with separator')

    def test_title_comparison_ignores_frames_and_preserves_real_changes(self):
        for frame in ['⠋', '⠙', '⠹', '◐', '◓', '✳', '✳️', '✻', '·', '']:
            self.assertEqual(protocol.title_key(f' {frame}  Editor, file '), 'Editor, file')
        self.assertEqual(protocol.title_key('[ . ] Action Required | Editor, file'), 'Editor, file')
        self.assertNotEqual(protocol.title_key('⠋ First tab'), protocol.title_key('⠙ Second tab'))
        self.assertNotEqual(protocol.title_key('file ⠋'), protocol.title_key('file ⠙'))

    def test_all_tabs_and_split_panes_are_tracked_without_private_content(self):
        value = protocol.snapshot(layout())
        self.assertEqual([p["id"] for p in value[0]["panes"]], [1, 2, 3])
        self.assertEqual([p["active"] for p in value[0]["panes"]], [True, False, False])
        self.assertEqual(value[0]["panes"][2]["titleState"], "waiting")
        serialized = json.dumps(value)
        self.assertNotIn("private-argument", serialized)
        self.assertNotIn("Action Required", serialized)

    def test_interpreters_and_daemon_exclusion(self):
        current = pane(program="node")
        current["foreground_processes"][0]["cmdline"] = ["/usr/bin/node", "/app/codex.js"]
        self.assertEqual(protocol.agent_kind(current), "codex")
        current["foreground_processes"][0]["cmdline"].append("app-server")
        self.assertEqual(protocol.agent_kind(current), "")
        current["at_prompt"] = True
        self.assertEqual(protocol.programs(current), [])

    def test_antigravity_aliases_only_track_interactive_sessions(self):
        current = pane()
        process = current['foreground_processes'][0]
        for executable in ('/opt/agy', '/opt/antigravity'):
            for args in ([], ['--continue'], ['--remote-control'], ['-i', 'remote-control']):
                process['cmdline'] = [executable, *args]
                self.assertEqual(protocol.agent_process(current), ('antigravity', 21))
            for args in (['-p', 'private prompt'], ['--print=private'], ['--prompt', 'private'],
                    ['remote-control', 'start'], ['mic-serve']):
                process['cmdline'] = [executable, *args]
                self.assertEqual(protocol.agent_process(current), ('', 0))
        process['cmdline'] = ['/usr/bin/python3', '/fixture/agy', '/fixture/control']
        self.assertEqual(protocol.agent_kind(current), 'antigravity')
        current['at_prompt'] = True
        self.assertEqual(protocol.agent_kind(current), '')

    def test_antigravity_payload_to_title_and_snapshot_discards_private_data(self):
        payload = dict(agent_state='idle', tool_confirmation_pending=False,
            workspace=dict(current_dir='/private/fixture-project'), session_id='private-session',
            model=dict(display_name='private-model'), extra='private content')
        current = layout()
        native = current[0]['tabs'][0]['windows'][0]
        native['foreground_processes'][0]['cmdline'] = ['/opt/agy', '-i', 'private prompt']
        for state, expected in (('idle', 'idle'), ('thinking', 'running'), ('working', 'running'),
                ('tool_use', 'running'), ('initializing', 'running'), ('future-state', '')):
            payload['agent_state'] = state
            native['title'] = protocol.antigravity_title(payload)
            value = protocol.snapshot(current)[0]['panes'][0]
            self.assertEqual(value['agent'], 'antigravity')
            self.assertEqual(value['titleState'], expected)
            self.assertEqual(protocol.semantic_title_key('antigravity', native['title']), 'fixture-project')
            self.assertNotIn('private', json.dumps(value))
        payload['tool_confirmation_pending'] = True
        native['title'] = protocol.antigravity_title(payload)
        self.assertEqual(protocol.snapshot(current)[0]['panes'][0]['titleState'], 'waiting')
        for malformed in (None, [], {}, {'agent_state': []}, {'workspace': 'unexpected'}):
            self.assertEqual(protocol.title_state('antigravity', protocol.antigravity_title(malformed)), '')
        self.assertEqual(protocol.title_state('antigravity', '[agy:idle]invalid'), '')
        self.assertEqual(protocol.antigravity_title(dict(agent_state='idle', cwd='/private/project\n\u202e')),
            '[agy:idle] project')

    def test_antigravity_title_command_accepts_json_and_handles_invalid_input(self):
        for payload, expected in (('{"agent_state":"tool_use","tool_confirmation_pending":true}',
                '[agy:waiting] Antigravity\n'), ('not JSON', '[agy:unknown] Antigravity\n')):
            result = subprocess.run([sys.executable, str(config / 'antigravity-title')], input=payload,
                capture_output=True, text=True, check=True)
            self.assertEqual(result.stdout, expected)
            self.assertEqual(result.stderr, '')

    def test_antigravity_state_changes_do_not_refresh_foreground_inventory(self):
        spec = importlib.util.spec_from_file_location('terminal_watcher', config.parent / 'kitty/terminal-watcher.py')
        watcher = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(watcher)
        watcher._panes = {1: {'agent': 'antigravity', 'titleState': 'idle'}}
        watcher._title_keys = {1: 'fixture-project'}
        window = type('Window', (), {'id': 1})()
        with patch.object(watcher, 'send') as send, patch.object(watcher, 'schedule') as schedule:
            for state in ('running', 'running', 'waiting', 'idle'):
                watcher.on_title_change(None, window, {'title': f'[agy:{state}] fixture-project'})
            self.assertEqual([call.args[0]['state'] for call in send.call_args_list], ['running', 'waiting', 'idle'])
            schedule.assert_not_called()
            watcher.on_title_change(None, window, {'title': 'shell prompt'})
            schedule.assert_called_once()

    def test_precedence_and_unknown_are_not_false_idle(self):
        aggregate = lambda *states: protocol.aggregate([{"state": state} for state in states])
        self.assertEqual(aggregate("idle", "running", "waiting"), "waiting")
        self.assertEqual(aggregate("running", ""), "running")
        self.assertEqual(aggregate("idle", ""), "")
        self.assertEqual(aggregate("idle", "idle"), "idle")
        self.assertEqual(aggregate(), "")

    def test_watcher_ignores_spinner_and_blink_frames(self):
        spec = importlib.util.spec_from_file_location("terminal_watcher", config.parent / "kitty/terminal-watcher.py")
        watcher = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(watcher)
        watcher._panes = {1: {"agent": "codex", "titleState": "idle"}}
        window = type("Window", (), {"id": 1})()
        messages = []
        with patch.object(watcher, "send", side_effect=messages.append), patch.object(watcher, "schedule"):
            for frame in ["⠋", "⠙", "⠹", "⠸"] * 25:
                watcher.on_title_change(None, window, {"title": frame + " Agent"})
            for frame in ["!", "."] * 25:
                watcher.on_title_change(None, window, {"title": f"[ {frame} ] Action Required | Agent"})
            watcher.on_title_change(None, window, {"title": "Agent"})
        self.assertEqual([message["state"] for message in messages], ["running", "waiting", "idle"])


class LabelTests(unittest.TestCase):
    def test_project_root_worktree_and_non_git_folder(self):
        with tempfile.TemporaryDirectory() as temporary:
            project = Path(temporary) / 'feature-auth'
            child = project / 'src/package'
            child.mkdir(parents=True)
            (project / '.git').write_text('gitdir: /unused')
            self.assertEqual(labels.project_name(str(child)), 'feature-auth')
            self.assertEqual(labels.project_name(str(Path(temporary) / 'notes')), 'notes')

    def test_bounded_names_and_stable_duplicate_suffixes(self):
        first = labels.make_context('codex', 1, 'shell', '', [])
        second = labels.make_context('claude', 2, 'shell', '', [first])
        self.assertEqual(labels.display_label(first), 'shell')
        self.assertEqual(labels.display_label(second), 'shell·2')
        self.assertEqual(labels.context(json.dumps(second), 'claude', 2), second)
        self.assertIsNone(labels.context(second, 'claude', 3))
        long = labels.make_context('codex', 3, 'project', 'a very long feature name', [first])
        self.assertEqual(len(labels.display_label(long)), 12)
        self.assertEqual(labels.clean_label('  shell\n tray\u202e  '), 'shell tray')

    def test_only_unlabeled_agents_include_directory_for_discovery(self):
        native = layout()
        current = native[0]['tabs'][0]['windows'][0]
        current['cwd'] = '/private/project/src'
        self.assertEqual(protocol.snapshot(native)[0]['panes'][0]['directory'], current['cwd'])
        value = labels.make_context('codex', 21, 'project', 'tray', [])
        current['user_vars'] = {labels.LABEL_VARIABLE: json.dumps(value)}
        self.assertNotIn('directory', protocol.snapshot(native)[0]['panes'][0])
        current['foreground_processes'][0]['pid'] = 42
        self.assertIsNone(protocol.snapshot(native)[0]['panes'][0]['context'])


class FooterWatcherTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('footer_watcher', config.parent / 'kitty/terminal-watcher.py')
        self.watcher = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.watcher)

    def screen(self, lines, continued=()):
        return SimpleNamespace(lines=len(lines), line=lambda index: lines[index],
            linebuf=SimpleNamespace(is_continued=lambda index: index in continued))

    def test_wrapped_footer_lines_are_joined_without_exposing_screen_text(self):
        native = SimpleNamespace(screen=self.screen(
            ['private message', '⏵⏵ bypass permissions on · 2 shells, 3 moni', 'tors'], (2,)))
        self.assertEqual(self.watcher.footer_counts(native), dict(agents=0, shells=2, monitors=3))
        native.screen = self.screen(['discarded'] + ['continuation'] * 8, tuple(range(1, 9)))
        self.assertIsNone(self.watcher.footer_counts(native))
        self.assertIsNone(self.watcher.footer_counts(SimpleNamespace()))

    def test_one_timer_while_claude_exists_and_change_only_updates(self):
        watcher = self.watcher
        watcher._panes = {2: dict(id=2, agent='claude', agentPid=22)}
        native = SimpleNamespace(screen=self.screen(['⏵⏵ bypass permissions on · 2 monitors']))
        boss = SimpleNamespace(window_id_map={2: native})
        timers = SimpleNamespace(add_timer=Mock(return_value=7), remove_timer=Mock())
        with patch.dict(sys.modules, {'kitty': ModuleType('kitty'), 'kitty.fast_data_types': timers}), \
                patch.object(watcher, 'send') as send:
            watcher.sync_activity_timer(boss)
            watcher.sync_activity_timer(boss)
            self.assertEqual(timers.add_timer.call_count, 1)
            self.assertEqual(timers.add_timer.call_args.args[1:], (2.0, True))
            watcher.sample_activity(boss)
            watcher.sample_activity(boss)
            self.assertEqual(send.call_count, 1)
            self.assertEqual(send.call_args.args[0],
                dict(event='activity', pane=2, agentPid=22, activity=dict(agents=0, shells=0, monitors=2)))
            native.screen = self.screen(['Choose an option'])
            watcher.sample_activity(boss)
            self.assertIsNone(send.call_args.args[0]['activity'])
            watcher._panes = {3: dict(agent='codex')}
            watcher.sync_activity_timer(boss)
            watcher.shutdown()
            timers.remove_timer.assert_called_once_with(7)


class HookTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.enterContext(patch.dict(os.environ, XDG_RUNTIME_DIR=self.directory.name,
            KITTY_PID="123", KITTY_WINDOW_ID="7"))
        self.enterContext(patch.object(agent_events, "process_identity", return_value=("42", "kitty")))
        self.path = Path(self.directory.name) / "quickshell-agents/123-7.json"

    def event(self, name, **values):
        agent_events.record_event("claude", {"hook_event_name": name, "session_id": "main", **values})

    def test_state_transitions_questions_and_repeated_tool_events(self):
        self.event("SessionStart", prompt="private", cwd="/private")
        self.event("UserPromptSubmit", prompt="private")
        before = self.path.stat().st_mtime_ns
        for _ in range(30): self.event("PreToolUse", tool_name="Bash")
        self.assertEqual(self.path.stat().st_mtime_ns, before)
        self.event("PreToolUse", tool_name="AskUserQuestion")
        self.assertEqual(json.loads(self.path.read_text())["state"], "waiting")
        self.event("PostToolUse", tool_name="AskUserQuestion")
        self.assertEqual(json.loads(self.path.read_text())["state"], "running")
        self.event("PermissionRequest")
        self.assertEqual(json.loads(self.path.read_text())["state"], "waiting")
        self.event("Stop")
        value = json.loads(self.path.read_text())
        self.assertEqual(value["state"], "idle")
        self.assertEqual(set(value), {"agent", "state", "start", "session", "at"})
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)

    def test_nested_sessions_cannot_clear_or_revive_parent(self):
        self.event("SessionStart")
        self.event("PermissionRequest")
        self.event("Stop", agent_id="child")
        self.event("SessionEnd", session_id="different")
        self.assertEqual(json.loads(self.path.read_text())["state"], "waiting")
        self.event("SessionEnd")
        self.assertFalse(self.path.exists())

    def test_non_permission_notification_does_not_mark_waiting(self):
        self.event("SessionStart")
        self.event("Notification", notification_type="auth_success")
        self.assertEqual(json.loads(self.path.read_text())["state"], "idle")


class TrackerTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.enterContext(patch.object(tracker, 'process_identity', return_value=('42', 'kitty')))

    async def model(self):
        model = tracker.Tracker()
        model.clients = [{"pid": 123, "address": "a1", "appId": "kitty"}]
        model.instances = {123: {"start": "42", "windows": protocol.snapshot(layout()),
            "titles": {}, "hooks": {}, "watched": True}}
        return model

    async def test_hidden_waiting_agent_and_stale_instance_events(self):
        model = await self.model()
        model.schedule_publish = lambda: None
        self.assertEqual(model.windows()["a1"]["agentState"], "waiting")
        model.event({"pid": 123, "start": "wrong", "event": "close", "pane": 3})
        self.assertEqual(len(model.windows()["a1"]["agents"]), 3)
        model.event({"pid": 123, "start": "42", "event": "state", "pane": 3, "state": "running"})
        self.assertEqual(model.windows()["a1"]["agentState"], "running")
        model.event({"pid": 123, "start": "42", "event": "close", "pane": 3})
        self.assertEqual(model.windows()["a1"]["agentState"], "idle")

    async def test_activity_updates_check_process_ownership_and_preserve_session_state(self):
        model = await self.model()
        model.schedule_publish = Mock()
        value = dict(agents=1, shells=2, monitors=3)
        event = dict(pid=123, start='42', event='activity', pane=2, agentPid=22, activity=value)
        model.event(event)
        agent = model.windows()['a1']['agents'][1]
        self.assertEqual(agent['activity'], value)
        self.assertEqual(agent['state'], 'idle')
        model.schedule_publish.reset_mock()
        for changed in (event, dict(event, agentPid=99),
                dict(event, activity=dict(agents=0, shells=-1, monitors=0))):
            model.event(changed)
        model.schedule_publish.assert_not_called()
        self.assertEqual(model.windows()['a1']['agents'][1]['activity'], value)
        model.event(dict(event, activity=None))
        self.assertIsNone(model.windows()['a1']['agents'][1]['activity'])
        self.assertEqual(model.requests, 0)

    async def test_labels_discover_once_and_survive_metadata_and_state_changes(self):
        model = await self.model()
        with patch.object(tracker, 'project_name', return_value='shell') as project, \
                patch.object(tracker, 'kitty_request', return_value=None) as request:
            model.prepare_labels()
            await asyncio.gather(*model.tasks)
            self.assertEqual([a['label'] for a in model.windows()['a1']['agents']], ['shell', 'shell·2', 'shell·3'])
            for _ in range(5):
                model.instances[123]['windows'][0]['panes'][0]['directory'] = '/another/project'
                model.prepare_labels()
            self.assertEqual(project.call_count, 3)
            self.assertEqual(request.call_count, 3)
            self.assertNotIn('/another/project', json.dumps(model.windows()))

    async def test_agent_automatic_name_promotes_from_project_and_custom_names_win(self):
        model = await self.model()
        model.schedule_publish = lambda: None
        native = model.instances[123]['windows'][0]['panes'][0]
        other = model.instances[123]['windows'][0]['panes'][1]
        with patch.object(tracker, 'project_name', return_value='project'), \
                patch.object(tracker, 'kitty_request', return_value=None) as request, redirect_stdout(io.StringIO()):
            model.prepare_labels()
            await asyncio.gather(*model.tasks)
            native['threadName'] = 'Refactor upload cache'
            other['threadName'] = 'Refresh search index'
            model.prepare_labels()
            await asyncio.gather(*model.tasks)
            value = model.instances[123]['labels'][1]
            self.assertEqual(value['source'], 'thread')
            self.assertFalse(value['custom'])
            self.assertEqual(model.windows()['a1']['agents'][0]['fullLabel'], native['threadName'])
            self.assertEqual(model.windows()['a1']['agents'][1]['fullLabel'], other['threadName'])
            self.assertEqual(labels.display_label(value), native['threadName'])
            writes = request.call_count
            for _ in range(30): model.prepare_labels()
            self.assertEqual(request.call_count, writes)
            await model.rename(dict(address='a1', pane=1, label='uploads'))
            native['threadName'] = 'A different session'
            model.prepare_labels()
            self.assertEqual(model.windows()['a1']['agents'][0]['fullLabel'], 'uploads')
            await model.rename(dict(address='a1', pane=1, label=''))
            self.assertEqual(model.windows()['a1']['agents'][0]['fullLabel'], 'A different session')
            await model.rename(dict(address='a1', pane=2, label='search'))
            other['threadName'] = 'Another Claude session'
            model.prepare_labels()
            self.assertEqual(model.windows()['a1']['agents'][1]['fullLabel'], 'search')
            await model.rename(dict(address='a1', pane=2, label=''))
            self.assertEqual(model.windows()['a1']['agents'][1]['fullLabel'], 'Another Claude session')

    async def test_rename_persists_only_that_pane_and_rejects_failed_writes(self):
        model = await self.model()
        model.schedule_publish = lambda: None
        with patch.object(tracker, 'kitty_request', return_value=None):
            model.prepare_labels()
            await asyncio.gather(*model.tasks)
        before = model.windows()['a1']['agents']
        with patch.object(tracker, 'process_identity', return_value=('42', 'kitty')), \
                patch.object(tracker, 'kitty_request', return_value=None) as request, redirect_stdout(io.StringIO()):
            await model.rename(dict(address='a1', pane=2, label='shell/auth'))
            self.assertEqual(request.call_args.args[:2], (123, 'set-user-vars'))
            self.assertEqual(request.call_args.args[2]['match'], 'id:2')
            after = model.windows()['a1']['agents']
            self.assertEqual(after[1]['label'], 'shell/auth')
            self.assertEqual(after[0], before[0])
            self.assertEqual(after[2], before[2])
        with patch.object(tracker, 'process_identity', return_value=('42', 'kitty')), \
                patch.object(tracker, 'kitty_request', side_effect=OSError), redirect_stdout(io.StringIO()) as output:
            await model.rename(dict(address='a1', pane=2, label='new-name'))
            self.assertFalse(json.loads(output.getvalue())['renamed']['ok'])
            self.assertEqual(model.windows()['a1']['agents'], after)

    async def test_bootstrap_restores_suffixes_before_assigning_new_labels(self):
        model = await self.model()
        model.instances[123]['windows'][0]['panes'] = model.instances[123]['windows'][0]['panes'][:1]
        model.instances[124] = dict(start='43', windows=[], labels={}, initialized=False)
        model.prepare_labels()
        self.assertFalse(model.instances[123]['labels'])
        restored = protocol.snapshot(layout())[0]
        restored['panes'] = restored['panes'][:1]
        restored['panes'][0]['context'] = dict(identity='codex:21', project='shell', label='shell', number=7, custom=False)
        model.instances[124].update(windows=[restored], initialized=True)
        with patch.object(tracker, 'project_name', return_value='shell'), patch.object(tracker, 'kitty_request', return_value=None):
            model.prepare_labels()
            await asyncio.gather(*model.tasks)
        self.assertEqual(model.instances[124]['labels'][1]['number'], 7)
        self.assertEqual(model.instances[123]['labels'][1]['number'], 1)

    async def test_agent_activation_selects_only_a_current_owned_pane(self):
        model = await self.model()
        model.schedule_publish = lambda: None
        self.assertEqual([agent['active'] for agent in model.windows()['a1']['agents']], [True, False, False])
        with patch.object(tracker, 'process_identity', return_value=('42', 'kitty')), \
                patch.object(tracker, 'kitty_request', return_value=None) as request, redirect_stdout(io.StringIO()) as output:
            await model.activate(dict(address='a1', pane=3))
            request.assert_awaited_once_with(123, 'focus-window', {'match': 'id:3'})
            self.assertTrue(json.loads(output.getvalue())['activated']['ok'])
            await model.activate(dict(address='a1', pane=99))
            await model.activate(dict(address='missing', pane=3))
            request.assert_awaited_once()
        with patch.object(tracker, 'process_identity', return_value=('43', 'kitty')), \
                patch.object(tracker, 'kitty_request') as request, redirect_stdout(io.StringIO()):
            await model.activate(dict(address='a1', pane=3))
            request.assert_not_awaited()

    async def test_pending_label_write_checks_pane_and_process_ownership(self):
        model = await self.model()
        value = labels.make_context('codex', 21, 'shell', 'tray', [])
        with patch.object(tracker, 'kitty_request') as request:
            self.assertFalse(await model.persist_label(123, 99, value))
            self.assertFalse(await model.persist_label(123, 2, value))
            with patch.object(tracker, 'process_identity', return_value=('43', 'kitty')):
                self.assertFalse(await model.persist_label(123, 1, value))
            request.assert_not_awaited()

    async def test_ambiguous_os_windows_never_borrow_another_agent(self):
        model = await self.model()
        model.clients.append({"pid": 123, "address": "a2", "appId": "kitty"})
        model.instances[123]["windows"].append(protocol.snapshot(layout())[0])
        self.assertTrue(all(not window["agents"] for window in model.windows().values()))

    async def test_reused_pid_discards_the_old_instance_before_mapping_new_window(self):
        model = await self.model()
        old_task = Mock()
        model.instances[123]["task"] = old_task
        model.schedule_publish = lambda: None
        with patch.object(tracker, "process_identity", return_value=("43", "kitty")), \
                patch.object(tracker, "kitty_request", return_value=True):
            model.receive({"windows": [{"pid": 123, "address": "a2", "appId": "kitty"}]})
            await asyncio.gather(*model.tasks)
        old_task.cancel.assert_called_once()
        self.assertEqual(model.instances[123]["start"], "43")
        self.assertEqual(model.windows()["a2"]["agents"], [])

    async def test_watched_instances_do_not_poll_and_stable_state_does_not_publish(self):
        model = await self.model()
        request = self.enterContext(patch.object(tracker, "kitty_request", return_value=True))
        await model.attach(123)
        output = io.StringIO()
        with redirect_stdout(output):
            await asyncio.sleep(.03)
            before = output.getvalue()
            model.publish()
            await asyncio.sleep(1.1)
            self.assertEqual(output.getvalue(), before)
        self.assertEqual(request.call_count, 1)


if __name__ == "__main__":
    unittest.main()
