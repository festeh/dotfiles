#!/usr/bin/env python3
"""Read foreground app identities from known Kitty instances, without CLI forks."""

import asyncio
import json
import os
from pathlib import Path
import re
import sys
import time

FRAME = b"\x1bP@kitty-cmd"
END = b"\x1b\\"
SHELLS = {"sh", "bash", "zsh", "fish", "dash", "nu", "xonsh"}


def process_stat(pid):
    """Only inspect known PIDs: start time, foreground group and executable name."""
    try:
        text = Path(f"/proc/{pid}/stat").read_text()
        _, _, tail = text.rpartition(") ")
        fields = tail.split()
        return (fields[19], int(fields[5]), text[text.index("(") + 1:text.rindex(")")])
    except (OSError, ValueError, IndexError):
        return None


def programs(window):
    if window.get("at_prompt"):
        return []
    result = []
    for process in sorted(window.get("foreground_processes", []), key=lambda p: p.get("pid", 0)):
        argv = process.get("cmdline") or []
        if not argv or not isinstance(argv[0], str):
            continue
        executable = os.path.basename(argv[0])
        # Interpreted CLIs often publish node/python as argv[0]. Only accept an
        # actual script argument, never shell text, flags, titles or arguments.
        if re.fullmatch(r"node(?:js)?|python(?:\d+(?:\.\d+)?)?|ruby|perl", executable):
            if len(argv) > 1 and not argv[1].startswith("-"):
                script = os.path.basename(argv[1])
                executable = re.sub(r"\.(?:[cm]?js|py|rb|pl)$", "", script)
        if executable and executable not in SHELLS and executable not in result:
            result.append(executable)
    return result


def active_pane(os_window):
    tabs = os_window.get("tabs", [])
    active = [tab for tab in tabs if tab.get("is_active")]
    if not active and len(tabs) == 1:
        active = tabs
    if len(active) != 1:
        return None
    panes = active[0].get("windows", [])
    selected = [window for window in panes if window.get("is_active")]
    if not selected and len(panes) == 1:
        selected = panes
    return selected[0] if len(selected) == 1 else None


def resolve_layout(layout, clients):
    result, watched = {}, set()
    for client in clients:
        matches = layout if len(layout) == len(clients) == 1 else [
            window for window in layout if window.get("wm_class") == client["appId"]]
        # Shared Kitty processes can own multiple OS windows. Do not guess by
        # title or list order when their compositor identities are ambiguous.
        same_class = sum(c["appId"] == client["appId"] for c in clients)
        pane = active_pane(matches[0]) if len(matches) == 1 and same_class == 1 else None
        result[client["address"]] = {"kitty": True, "programs": programs(pane) if pane else []}
        if pane and isinstance(pane.get("pid"), int):
            watched.add(pane["pid"])
            for process in pane.get("foreground_processes", []):
                if isinstance(process.get("pid"), int):
                    watched.add(process["pid"])
    return result, watched


async def kitty_request(pid):
    reader, writer = await asyncio.open_unix_connection("\0kitty-" + str(pid), limit=8 * 1024 * 1024)
    try:
        writer.write(FRAME + json.dumps({"cmd": "ls", "version": [0, 1, 0], "no_response": False}).encode() + END)
        await writer.drain()
        response = await reader.readuntil(END)
        payload = json.loads(response.split(FRAME, 1)[1][:-len(END)])
        if not payload.get("ok"):
            raise ValueError("Kitty query rejected")
        return json.loads(payload["data"])
    finally:
        writer.close()
        await writer.wait_closed()


class Reader:
    def __init__(self):
        self.clients = []
        self.records = {}
        self.wake = asyncio.Event()
        self.closed = False

    def receive(self, message):
        if "windows" in message:
            self.clients = [c for c in message["windows"] if isinstance(c, dict)
                and isinstance(c.get("pid"), int) and c["pid"] > 0
                and re.fullmatch(r"[0-9a-f]+", c.get("address", ""))
                and isinstance(c.get("appId"), str)]
        pid = message.get("refresh")
        if pid in self.records:
            record = self.records[pid]
            # A changing title can be a spinner. Bound queries to four/second,
            # with a short trailing delay so the shell has launched its child.
            due = max(record["last"] + .25, time.monotonic() + .08)
            record["due"] = min(record["due"], due)
        self.wake.set()

    async def input(self):
        stream = asyncio.StreamReader()
        protocol = asyncio.StreamReaderProtocol(stream)
        transport, _ = await asyncio.get_running_loop().connect_read_pipe(lambda: protocol, sys.stdin)
        try:
            while line := await stream.readline():
                try:
                    message = json.loads(line)
                    if isinstance(message, dict): self.receive(message)
                except (ValueError, TypeError):
                    pass
        finally:
            transport.close()
            self.closed = True
            self.wake.set()

    async def refresh(self, pid, record):
        record["last"], record["due"] = time.monotonic(), float("inf")
        try:
            layout = await asyncio.wait_for(kitty_request(pid), timeout=.6)
            record["result"], watched = resolve_layout(layout, record["clients"])
            record["watched"] = {p: process_stat(p) for p in watched}
            record["failures"] = 0
        except (OSError, ValueError, KeyError, asyncio.TimeoutError, asyncio.IncompleteReadError, asyncio.LimitOverrunError):
            record["result"] = {c["address"]: {"kitty": True, "programs": []} for c in record["clients"]}
            record["watched"] = {}
            record["failures"] += 1
            # A newly opened Kitty can expose its socket slightly later.
            if record["failures"] <= 2: record["due"] = time.monotonic() + .4 * record["failures"]

    async def run(self):
        incoming = asyncio.create_task(self.input())
        previous = None
        next_check = time.monotonic()
        try:
            while not self.closed:
                self.wake.clear()
                groups = {}
                for client in self.clients: groups.setdefault(client["pid"], []).append(client)
                self.records = {pid: record for pid, record in self.records.items() if pid in groups}
                for pid, clients in groups.items():
                    if pid not in self.records:
                        stat = process_stat(pid)
                        self.records[pid] = dict(clients=clients, kitty=bool(stat and stat[2] == "kitty"),
                            start=stat[0] if stat else None, last=0, due=0, result={}, watched={}, failures=0)
                    record = self.records[pid]
                    if record["clients"] != clients:
                        record["clients"], record["due"] = clients, 0
                now = time.monotonic()
                if now >= next_check:
                    next_check = now + 1
                    for pid, record in self.records.items():
                        if not record["kitty"]: continue
                        current = process_stat(pid)
                        if not current or current[0] != record["start"]:
                            record["result"], record["watched"] = {}, {}
                            continue
                        if any(process_stat(p) != stat for p, stat in record["watched"].items()):
                            record["due"] = min(record["due"], max(now, record["last"] + .25))
                await asyncio.gather(*(self.refresh(pid, record) for pid, record in self.records.items()
                    if record["kitty"] and record["due"] <= time.monotonic()))
                result = {address: value for record in self.records.values() for address, value in record["result"].items()}
                if result != previous:
                    print(json.dumps({"windows": result}, separators=(",", ":")), flush=True)
                    previous = result
                pending = [record["due"] for record in self.records.values() if record["kitty"]]
                timeout = max(0, min([next_check, *pending]) - time.monotonic()) if pending else None
                try:
                    await asyncio.wait_for(self.wake.wait(), timeout)
                except asyncio.TimeoutError:
                    pass
        finally:
            incoming.cancel()


if __name__ == "__main__":
    try:
        asyncio.run(Reader().run())
    except (BrokenPipeError, KeyboardInterrupt):
        pass
