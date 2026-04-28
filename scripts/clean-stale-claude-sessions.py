#!/usr/bin/env python3
"""Clean stale Claude sessions from the AGS widget cache.

Removes per-session files whose claude_pid no longer has a Hyprland window
or no longer exists. Runs every minute via systemd timer.
"""

import json
import os
import subprocess
import sys


SESSIONS_DIR = os.path.expanduser("~/.cache/ags-claude/sessions")


def _get_clients() -> list[dict] | None:
    try:
        result = subprocess.run(
            ["hyprctl", "clients", "-j"],
            capture_output=True, text=True, check=True,
        )
        return json.loads(result.stdout)
    except (subprocess.SubprocessError, json.JSONDecodeError):
        return None


def _get_ppid(pid: int) -> int | None:
    try:
        with open(f"/proc/{pid}/status", "r") as f:
            for line in f:
                if line.startswith("PPid:"):
                    return int(line.split()[1])
    except (OSError, ValueError):
        pass
    return None


def _has_window(pid: int, clients: list[dict]) -> bool:
    client_pids = {c.get("pid") for c in clients}
    current = pid
    while current and current != 1:
        if current in client_pids:
            return True
        current = _get_ppid(current)
    return False


def main() -> int:
    if not os.path.isdir(SESSIONS_DIR):
        return 0

    clients = _get_clients()
    if clients is None:
        return 0

    for name in os.listdir(SESSIONS_DIR):
        if not name.endswith(".json"):
            continue
        path = os.path.join(SESSIONS_DIR, name)
        try:
            with open(path, "r", encoding="utf-8") as f:
                sess = json.load(f)
        except (json.JSONDecodeError, OSError):
            continue

        pid = sess.get("claude_pid")
        if pid is None:
            continue

        if not os.path.exists(f"/proc/{pid}"):
            try:
                os.unlink(path)
            except OSError:
                pass
            continue

        if not _has_window(pid, clients):
            try:
                os.unlink(path)
            except OSError:
                pass

    return 0


if __name__ == "__main__":
    sys.exit(main())
