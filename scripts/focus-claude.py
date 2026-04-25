#!/usr/bin/env python3
"""Focus the Hyprland window containing a Claude Code session.

Usage: focus-claude.py <claude_pid> <cwd>

Walks up the process tree from the stored claude_pid (or falls back to
matching by cwd) to find a window and focuses it via hyprctl.
"""

import json
import os
import subprocess
import sys


def find_window_for_pid(pid: int) -> int | None:
    """Check if a pid has a Hyprland window; return the pid if found."""
    try:
        result = subprocess.run(
            ["hyprctl", "clients", "-j"],
            capture_output=True,
            text=True,
            check=True,
        )
        clients = json.loads(result.stdout)
        for client in clients:
            if client.get("pid") == pid:
                return pid
    except (subprocess.SubprocessError, json.JSONDecodeError):
        pass
    return None


def get_ppid(pid: int) -> int | None:
    try:
        with open(f"/proc/{pid}/status", "r") as f:
            for line in f:
                if line.startswith("PPid:"):
                    return int(line.split()[1])
    except (OSError, ValueError):
        pass
    return None


def focus_window(pid: int) -> bool:
    try:
        subprocess.run(
            ["hyprctl", "dispatch", "focuswindow", f"pid:{pid}"],
            capture_output=True,
            check=True,
        )
        return True
    except subprocess.SubprocessError:
        return False


def find_claude_pid_by_cwd(cwd: str) -> int | None:
    """Find a claude process whose cwd matches or contains the given cwd."""
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        pid = int(entry)
        try:
            with open(f"/proc/{pid}/comm", "r") as f:
                comm = f.read().strip()
            if comm != "claude":
                continue
            proc_cwd = os.readlink(f"/proc/{pid}/cwd")
            if proc_cwd == cwd:
                return pid
            # Allow prefix match: e.g. claude cwd=/a/b, session cwd=/a/b/c
            if cwd.startswith(proc_cwd + "/") or proc_cwd.startswith(cwd + "/"):
                return pid
        except (OSError, ValueError):
            continue
    return None


def focus_by_pid_tree(pid: int) -> bool:
    """Walk up from pid, focus the first ancestor that has a Hyprland window."""
    current = pid
    while current and current != 1:
        if find_window_for_pid(current):
            return focus_window(current)
        current = get_ppid(current)
    return False


def main() -> int:
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <claude_pid> <cwd>", file=sys.stderr)
        return 1

    claude_pid_str = sys.argv[1]
    cwd = sys.argv[2]

    # Try stored claude pid first
    if claude_pid_str and claude_pid_str not in ("null", "None", ""):
        try:
            pid = int(claude_pid_str)
            if pid > 0:
                # Verify process still exists
                if os.path.exists(f"/proc/{pid}"):
                    if focus_by_pid_tree(pid):
                        return 0
        except ValueError:
            pass

    # Fallback: find by cwd
    pid = find_claude_pid_by_cwd(cwd)
    if pid and focus_by_pid_tree(pid):
        return 0

    # Nothing found — notify user
    try:
        subprocess.run(
            ["notify-send", "Claude", f"Could not find window for {cwd}"],
            capture_output=True,
            check=True,
        )
    except subprocess.SubprocessError:
        pass

    return 1


if __name__ == "__main__":
    sys.exit(main())
