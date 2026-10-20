#!/usr/bin/python3
"""Agent ownership, hidden panes, event coalescing and state-only hooks."""

import asyncio
from contextlib import redirect_stdout
import importlib.util
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest.mock import Mock, patch

config = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(config))
import agent_events
import terminal_protocol as protocol
import terminal_tracker as tracker


def pane(identifier=1, program="codex", title="Agent", active=True):
    return {"id": identifier, "is_active": active, "title": title,
        "foreground_processes": [{"pid": identifier + 20, "cmdline": [program, "private-argument"]}]}


def layout():
    return [{"id": 1, "wm_class": "kitty", "tabs": [
        {"is_active": True, "windows": [pane(), pane(2, "claude", "✳ Agent", False)]},
        {"is_active": False, "windows": [pane(3, title="[ ! ] Action Required | Agent")]}]}]


class ProtocolTests(unittest.TestCase):
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
