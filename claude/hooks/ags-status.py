#!/usr/bin/env python3
"""Claude Code hook script for AGS status widget.

Reads hook JSON from stdin and maintains ~/.cache/ags-claude/sessions.json
Logs all received events to ~/.cache/ags-claude/hook.log for debugging.
"""

import json
import os
import sys
from datetime import datetime, timezone


def log_event(data: dict, state: str | None, action: str | None) -> None:
    cache_dir = os.path.expanduser("~/.cache/ags-claude")
    os.makedirs(cache_dir, exist_ok=True)
    log_path = os.path.join(cache_dir, "hook.log")

    event = data.get("hook_event_name", "unknown")
    session_id = data.get("session_id", "no-session")
    ntype = data.get("notification_type", "")
    tool = data.get("tool_name", "")

    extras = []
    if ntype:
        extras.append(f"ntype={ntype}")
    if tool:
        extras.append(f"tool={tool}")
    extra_str = " ".join(extras)

    result = f"state={state} action={action}" if state else "ignored"
    line = f"{datetime.now(timezone.utc).isoformat()} [{session_id}] {event} {extra_str} -> {result}\n"

    with open(log_path, "a", encoding="utf-8") as f:
        f.write(line)


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        return

    event = data.get("hook_event_name")
    session_id = data.get("session_id")
    if not event or not session_id:
        return

    cache_dir = os.path.expanduser("~/.cache/ags-claude")
    os.makedirs(cache_dir, exist_ok=True)
    file_path = os.path.join(cache_dir, "sessions.json")

    cwd = data.get("cwd", "")
    transcript = data.get("transcript_path", "")
    now = datetime.now(timezone.utc).isoformat()

    state: str | None = None
    action: str | None = None

    if event == "SessionStart":
        state = "idle"
        action = "started"
    elif event in ("UserPromptSubmit", "PostToolBatch"):
        state = "running"
        action = "thinking..."
    elif event == "PreToolUse":
        tool = data.get("tool_name", "running")
        state = "running"
        action = tool
    elif event == "PostToolUse":
        state = "running"
        action = "running"
    elif event == "PermissionRequest":
        state = "waiting"
        action = "needs permission"
    elif event == "Notification":
        ntype = data.get("notification_type", "")
        if ntype in ("permission_prompt", "elicitation_dialog"):
            state = "waiting"
            action = "needs input"
        elif ntype == "idle_prompt":
            state = "idle"
            action = "finished"
        else:
            # Unknown notification type — show as unknown for visibility
            state = "unknown"
            action = f"ntype: {ntype}"
    elif event == "Stop":
        state = "idle"
        action = "finished"
    elif event == "SessionEnd":
        log_event(data, None, "removed")
        _remove_session(file_path, session_id)
        return
    else:
        # Unknown event type — show as unknown for visibility
        state = "unknown"
        action = f"event: {event}"

    log_event(data, state, action)
    _upsert_session(file_path, session_id, state, action, cwd, transcript, now)


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


def _upsert_session(
    path: str,
    session_id: str,
    state: str,
    action: str,
    cwd: str,
    transcript: str,
    now: str,
) -> None:
    db = _read_db(path)
    db["sessions"][session_id] = {
        "session_id": session_id,
        "state": state,
        "action": action,
        "cwd": cwd,
        "transcript": transcript,
        "updated_at": now,
    }
    _write_db(path, db)


def _remove_session(path: str, session_id: str) -> None:
    if not os.path.exists(path):
        return
    db = _read_db(path)
    db["sessions"].pop(session_id, None)
    _write_db(path, db)


if __name__ == "__main__":
    main()
