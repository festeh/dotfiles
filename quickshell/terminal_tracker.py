#!/usr/bin/env python3
"""One shared event-driven Kitty inventory and agent state tracker."""

import asyncio
import ctypes
import json
import os
from pathlib import Path
import re
import socket
import stat
import struct
import sys
import time

from terminal_protocol import aggregate, process_identity, runtime_directory, snapshot, socket_path, STATES

FRAME, END = b"\x1bP@kitty-cmd", b"\x1b\\"
ATTACHER = Path(__file__).resolve().parents[1] / "kitty/attach-terminal-watcher.py"


async def kitty_request(pid, command="ls", payload=None):
    reader, writer = await asyncio.open_unix_connection("\0kitty-" + str(pid), limit=8 * 1024 * 1024)
    try:
        writer.write(FRAME + json.dumps({"cmd": command, "version": [0, 1, 0],
            "no_response": False, "payload": payload or {}}).encode() + END)
        await writer.drain()
        response = await reader.readuntil(END)
        value = json.loads(response.split(FRAME, 1)[1][:-len(END)])
        if not value.get("ok"):
            raise ValueError("Kitty query rejected: " + str(value.get("error", "")))
        return value.get("data")
    finally:
        writer.close()
        await writer.wait_closed()


class Tracker:
    def __init__(self):
        self.clients, self.instances = [], {}
        self.closed = False
        self.previous = None
        self.publication = None
        self.requests = 0
        self.tasks = set()
        self.agent_directory = runtime_directory() / "quickshell-agents"

    def task(self, coroutine):
        task = asyncio.create_task(coroutine)
        self.tasks.add(task)
        task.add_done_callback(self.tasks.discard)
        return task

    def schedule_publish(self):
        if self.publication is None:
            self.publication = asyncio.get_running_loop().call_later(.02, self.publish)

    def receive(self, message):
        if "windows" in message:
            self.clients = [client for client in message["windows"] if isinstance(client, dict)
                and isinstance(client.get("pid"), int) and client["pid"] > 0
                and re.fullmatch(r"[0-9a-f]+", client.get("address", ""))
                and isinstance(client.get("appId"), str)]
            present = {client["pid"] for client in self.clients}
            for pid in list(self.instances):
                identity = process_identity(pid) if pid in present else None
                if identity is None or identity[0] != self.instances[pid]["start"]:
                    self.instances.pop(pid)["task"].cancel()
            for pid in present - self.instances.keys():
                identity = process_identity(pid)
                if identity and identity[1] == "kitty":
                    self.instances[pid] = {"start": identity[0], "windows": [], "watched": False,
                        "titles": {}, "hooks": {}, "task": self.task(self.attach(pid))}
            self.schedule_publish()
    async def attach(self, pid):
        record = self.instances[pid]
        for attempt in range(3):
            try:
                self.requests += 1
                success = await asyncio.wait_for(kitty_request(pid, "kitten",
                    {"kitten": str(ATTACHER), "args": []}), 1.2)
                if success is not True:
                    raise ValueError("Watcher did not attach")
                record["watched"] = True
                self.schedule_publish()
                return
            except (OSError, ValueError, asyncio.TimeoutError, asyncio.IncompleteReadError,
                    asyncio.LimitOverrunError):
                if attempt < 2:
                    await asyncio.sleep(.4 * (attempt + 1))
        # A compatibility fallback is restricted to unsupported Kitty instances.
        # There is no timer or /proc polling for successfully watched instances.
        while pid in self.instances and not record["watched"]:
            try:
                self.requests += 1
                value = await asyncio.wait_for(kitty_request(pid), .8)
                record["windows"] = snapshot(json.loads(value) if isinstance(value, str) else value)
                self.schedule_publish()
            except (OSError, ValueError, TypeError, asyncio.TimeoutError, asyncio.IncompleteReadError,
                    asyncio.LimitOverrunError):
                pass
            await asyncio.sleep(5)

    def event(self, message):
        pid = message.get("pid")
        record = self.instances.get(pid)
        if not record or record["start"] != message.get("start"):
            return
        kind = message.get("event")
        if kind == "snapshot" and isinstance(message.get("windows"), list):
            record["watched"] = True
            record["windows"] = message["windows"]
            present = {pane["id"] for window in record["windows"] for pane in window["panes"] if pane["agent"]}
            record["hooks"] = {key: value for key, value in record["hooks"].items() if key in present}
            for pane_id in present - record["hooks"].keys():
                record["hooks"][pane_id] = self.read_hook(pid, pane_id, record)
        elif kind in {"state", "close"}:
            pane_id = message.get("pane")
            for window in record["windows"]:
                if kind == "close":
                    window["panes"] = [pane for pane in window["panes"] if pane["id"] != pane_id]
                else:
                    for pane in window["panes"]:
                        if pane["id"] == pane_id and message.get("state") in STATES | {""}:
                            pane["titleState"] = message["state"]
                            record["titles"][pane_id] = time.monotonic_ns()
        else:
            return
        self.schedule_publish()

    def read_hook(self, pid, pane_id, record):
        name = f"{pid}-{pane_id}.json"
        path = self.agent_directory / name
        try:
            value = json.loads(path.read_text())
            if value.get("start") != record["start"]:
                return {}
        except (OSError, ValueError):
            return {}
        return value

    def hook_state(self, pid, pane, record):
        if pane["agent"] == "codex":
            return pane["titleState"]
        value = record["hooks"].get(pane["id"], {})
        state = value.get("state", "")
        if state == "compacting":
            state = "running"
        if value.get("agent") != pane["agent"] or state not in STATES:
            return pane["titleState"]
        # Claude's Esc interrupt has no hook. A later definitive title change
        # can settle a stale running state without periodic reconciliation.
        if (pane["agent"] == "claude" and pane["titleState"]
                and (record["titles"].get(pane["id"], 0) > value.get("at", 0)
                    or state == "running" and pane["titleState"] == "idle"
                    and time.monotonic_ns() - value.get("at", 0) > 10_000_000_000)
                and (state == "running" or pane["titleState"] == "running")):
            return pane["titleState"]
        return state

    def windows(self):
        result = {}
        for pid, record in self.instances.items():
            clients = [client for client in self.clients if client["pid"] == pid]
            for client in clients:
                matches = record["windows"] if len(record["windows"]) == len(clients) == 1 else [
                    window for window in record["windows"] if window["class"] == client["appId"]]
                unique = sum(item["appId"] == client["appId"] for item in clients) == 1
                panes = matches[0]["panes"] if len(matches) == 1 and unique else []
                active = next((pane for pane in panes if pane["active"]), None)
                agents = [{"agent": pane["agent"], "pane": pane["id"], "tab": pane["tab"],
                    "active": pane["active"], "state": self.hook_state(pid, pane, record)}
                    for pane in panes if pane["agent"]]
                result[client["address"]] = {"kitty": True, "programs": active["programs"] if active else [],
                    "agents": agents, "agentState": aggregate(agents)}
        return result

    def publish(self):
        self.publication = None
        windows = self.windows()
        states = {state or "unknown": sum(agent["state"] == state for window in windows.values() for agent in window["agents"])
            for state in ("idle", "running", "waiting", "")}
        value = {"windows": windows, "health": {"instances": len(self.instances),
            "watched": sum(record["watched"] for record in self.instances.values()),
            "panes": sum(len(window["panes"]) for record in self.instances.values() for window in record["windows"]),
            "agents": sum(len(window["agents"]) for window in windows.values()), "requests": self.requests,
            "states": states}}
        if value != self.previous:
            print(json.dumps(value, separators=(",", ":")), flush=True)
            self.previous = value

    async def activate(self, target):
        if (not isinstance(target, dict) or not isinstance(target.get("address"), str)
                or type(target.get("pane")) is not int or target["pane"] <= 0):
            return
        address, pane = target["address"], target["pane"]
        ok = False
        client = next((client for client in self.clients if client["address"] == address), None)
        record = self.instances.get(client["pid"]) if client else None
        identity = process_identity(client["pid"]) if record else None
        agents = self.windows().get(address, {}).get("agents", [])
        if identity and identity[0] == record["start"] and any(agent["pane"] == pane for agent in agents):
            try:
                self.requests += 1
                await asyncio.wait_for(kitty_request(client["pid"], "focus-window", {"match": f"id:{pane}"}), 1)
                ok = True
            except (OSError, ValueError, asyncio.TimeoutError, asyncio.IncompleteReadError,
                    asyncio.LimitOverrunError):
                pass
            self.schedule_publish()
        print(json.dumps({"activated": {"address": address, "pane": pane, "ok": ok}}), flush=True)

    async def input(self):
        reader = asyncio.StreamReader()
        transport, _ = await asyncio.get_running_loop().connect_read_pipe(
            lambda: asyncio.StreamReaderProtocol(reader), sys.stdin)
        try:
            while line := await reader.readline():
                try:
                    value = json.loads(line)
                    if isinstance(value, dict):
                        if "activate" in value:
                            await self.activate(value["activate"])
                        else:
                            self.receive(value)
                except (ValueError, TypeError):
                    pass
        finally:
            transport.close()

    async def run(self):
        loop = asyncio.get_running_loop()
        path = Path(socket_path())
        if path.exists():
            if not stat.S_ISSOCK(path.lstat().st_mode):
                raise RuntimeError("Terminal event path is not a socket")
            path.unlink()
        channel = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM | socket.SOCK_NONBLOCK)
        channel.bind(str(path))
        os.chmod(path, 0o600)
        inode = path.stat().st_ino

        def incoming():
            while True:
                try:
                    data = channel.recv(1024 * 1024)
                    value = json.loads(data)
                    if isinstance(value, dict): self.event(value)
                except BlockingIOError:
                    return
                except (ValueError, TypeError, KeyError):
                    continue

        # One inotify descriptor; changed filenames select the affected state
        # file. A hook write never rescans all agents or wakes a poll timer.
        self.agent_directory.mkdir(mode=0o700, exist_ok=True)
        libc = ctypes.CDLL(None, use_errno=True)
        descriptor = libc.inotify_init1(os.O_NONBLOCK | os.O_CLOEXEC)
        if descriptor < 0:
            raise OSError(ctypes.get_errno(), "inotify_init1")
        if libc.inotify_add_watch(descriptor, os.fsencode(self.agent_directory),
                0x00000008 | 0x00000080 | 0x00000200) < 0:
            raise OSError(ctypes.get_errno(), "inotify_add_watch")

        def files_changed():
            changed = False
            try:
                raw = os.read(descriptor, 65536)
            except BlockingIOError:
                return
            offset = 0
            while offset + 16 <= len(raw):
                _watch, _mask, _cookie, length = struct.unpack_from("iIII", raw, offset)
                name = raw[offset + 16:offset + 16 + length].split(b"\0", 1)[0].decode(errors="replace")
                offset += 16 + length
                match = re.fullmatch(r"(\d+)-(\d+)\.json", name)
                if match and int(match[1]) in self.instances:
                    pid, pane_id = int(match[1]), int(match[2])
                    record = self.instances[pid]
                    record["hooks"][pane_id] = self.read_hook(pid, pane_id, record)
                    changed = True
            if changed:
                self.schedule_publish()

        loop.add_reader(channel.fileno(), incoming)
        loop.add_reader(descriptor, files_changed)
        try:
            await self.input()
        finally:
            self.closed = True
            for task in self.tasks: task.cancel()
            if self.tasks: await asyncio.gather(*self.tasks, return_exceptions=True)
            if self.publication is not None: self.publication.cancel()
            loop.remove_reader(channel.fileno())
            loop.remove_reader(descriptor)
            os.close(descriptor)
            channel.close()
            if path.exists() and path.stat().st_ino == inode: path.unlink()


if __name__ == "__main__":
    try:
        asyncio.run(Tracker().run())
    except (BrokenPipeError, KeyboardInterrupt):
        pass
