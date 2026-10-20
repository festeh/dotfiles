#!/usr/bin/env python3
"""Foreground identity, ambiguous window mapping, and bounded reader traffic."""

import asyncio
from contextlib import redirect_stdout
import importlib.util
import io
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("kitty_apps", Path(__file__).resolve().parents[1] / "kitty_apps.py")
apps = importlib.util.module_from_spec(spec)
spec.loader.exec_module(apps)


def pane(program="editor-cli", pid=20, active=True, prompt=False):
    return dict(pid=pid, is_active=active, is_focused=False, at_prompt=prompt,
        foreground_processes=[dict(pid=pid + 1, cmdline=["/usr/bin/" + program, "private-document"])])


def layout(program="editor-cli"):
    return [dict(id=1, wm_class="kitty", tabs=[dict(is_active=True, windows=[pane(program)])])]


class IdentityTests(unittest.TestCase):
    def test_active_pane_does_not_require_compositor_focus(self):
        current = layout()[0]
        current["tabs"].append(dict(is_active=False, windows=[pane("unfocused-app")]))
        current["tabs"][0]["windows"].append(pane("inactive-pane", active=False))
        result, watched = apps.resolve_layout([current], [dict(address="a1", appId="kitty")])
        self.assertEqual(result, {"a1": {"kitty": True, "programs": ["editor-cli"]}})
        self.assertEqual(watched, {20, 21})

    def test_interpreted_cli_and_shell_prompt(self):
        current = pane()
        current["foreground_processes"] = [dict(pid=2, cmdline=["/usr/bin/node", "/app/bin/codex.js", "private-session"]),
            dict(pid=3, cmdline=["/usr/bin/codex", "--resume", "private-session"]),
            dict(pid=4, cmdline=["/usr/bin/zsh", "-c", "irrelevant"])]
        self.assertEqual(apps.programs(current), ["codex"])
        current["at_prompt"] = True
        self.assertEqual(apps.programs(current), [])
        current["at_prompt"] = False
        current["foreground_processes"] = [dict(pid=1, cmdline=["node", "-e", "codex"])]
        self.assertEqual(apps.programs(current), ["node"])

    def test_multiple_os_windows_use_unique_classes_and_ambiguous_ones_fall_back(self):
        first, second = layout("codex")[0], layout("claude")[0]
        second["wm_class"] = "custom-terminal"
        clients = [dict(address="a1", appId="kitty"), dict(address="a2", appId="custom-terminal")]
        result, _ = apps.resolve_layout([first, second], clients)
        self.assertEqual(result["a1"]["programs"], ["codex"])
        self.assertEqual(result["a2"]["programs"], ["claude"])
        second["wm_class"] = "kitty"
        clients[1]["appId"] = "kitty"
        result, watched = apps.resolve_layout([first, second], clients)
        self.assertTrue(all(value["programs"] == [] for value in result.values()))
        self.assertEqual(watched, set())


class ReaderTests(unittest.IsolatedAsyncioTestCase):
    async def run_reader(self, request):
        reader = apps.Reader()
        reader.receive({"windows": [dict(pid=10, address="a1", appId="kitty")]})
        stats = {10: ("1", -1, "kitty"), 20: ("2", 21, "zsh"), 21: ("3", 21, "editor-cli")}
        self.enterContext(patch.object(apps, "process_stat", side_effect=lambda pid: stats.get(pid)))
        self.enterContext(patch.object(apps, "kitty_request", side_effect=request))
        self.enterContext(redirect_stdout(io.StringIO()))

        async def input_until_closed():
            await asyncio.Event().wait()

        reader.input = input_until_closed
        task = asyncio.create_task(reader.run())

        async def stop():
            reader.closed = True
            reader.wake.set()
            await asyncio.wait_for(task, 1)

        self.addAsyncCleanup(stop)
        await asyncio.sleep(.03)
        return reader, stats

    async def test_idle_does_not_query_kitty_and_foreground_changes_do(self):
        queries = []

        async def request(pid):
            queries.append(pid)
            return layout("editor-cli" if len(queries) == 1 else "claude")

        reader, stats = await self.run_reader(request)
        await asyncio.sleep(1.05)
        self.assertEqual(queries, [10])
        stats[20] = ("2", 22, "zsh")
        await asyncio.sleep(1.05)
        self.assertEqual(queries, [10, 10])
        self.assertEqual(reader.records[10]["result"]["a1"]["programs"], ["claude"])

    async def test_spinner_updates_coalesce_and_removal_discards_state(self):
        queries = []

        async def request(pid):
            queries.append(pid)
            return layout()

        reader, _ = await self.run_reader(request)
        for _ in range(50): reader.receive({"refresh": 10})
        await asyncio.sleep(.35)
        self.assertEqual(queries, [10, 10])
        reader.receive({"windows": []})
        await asyncio.sleep(.03)
        self.assertEqual(reader.records, {})

    async def test_unavailable_remote_control_has_bounded_retries(self):
        queries = []

        async def request(pid):
            queries.append(pid)
            raise OSError("private socket unavailable")

        reader, _ = await self.run_reader(request)
        await asyncio.sleep(1.45)
        self.assertEqual(queries, [10, 10, 10])
        self.assertEqual(reader.records[10]["result"], {"a1": {"kitty": True, "programs": []}})


if __name__ == "__main__":
    unittest.main()
