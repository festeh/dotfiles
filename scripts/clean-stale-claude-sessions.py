#!/usr/bin/env python3
"""Clean stale Claude sessions from the AGS widget.

Reads ~/.cache/ags-claude/sessions.json and removes sessions whose
claude_pid no longer has an associated Hyprland window (or whose
process no longer exists).

Intended to run every minute via systemd timer or cron.
"""

import json
import os
import subprocess
import sys


SESSIONS_PATH = os.path.expanduser("~/.cache/ags-claude/sessions.json")


def _get_clients() -> list[dict] | None:
    try:
        result = subprocess.run(
            ["hyprctl", "clients", "-j"],
            capture_output=True,
            text=True,
            check=True,
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
    """Walk up the pid tree and return True if any ancestor has a Hyprland window."""
    client_pids = {c.get("pid") for c in clients}
    current = pid
    while current and current != 1:
        if current in client_pids:
            return True
        current = _get_ppid(current)
    return False


def _read_db(path: str) -> dict:
    if not os.path.exists(path):
        return {"sessions": {}}
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return {"sessions": {}}


def _write_db(path: str, db: dict) -> None:
    tmp_path = path + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(db, f, indent=2)
    os.replace(tmp_path, path)


def main() -> int:
    db = _read_db(SESSIONS_PATH)
    sessions = db.get("sessions", {})
    if not sessions:
        return 0

    clients = _get_clients()
    if clients is None:
        # hyprctl failed; skip to avoid false removals
        return 0

    removed = []

    for sid, sess in list(sessions.items()):
        pid = sess.get("claude_pid")
        if pid is None:
            # Can't verify without a pid; leave it alone
            continue

        # Process is gone
        if not os.path.exists(f"/proc/{pid}"):
            removed.append(sid)
            continue

        # Process exists but no window found
        if not _has_window(pid, clients):
            removed.append(sid)
            continue

    if not removed:
        return 0

    for sid in removed:
        sessions.pop(sid, None)

    _write_db(SESSIONS_PATH, db)
    return 0


if __name__ == "__main__":
    sys.exit(main())
