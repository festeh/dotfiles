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


def _basename(path: str) -> str:
    if not path:
        return ""
    return os.path.basename(path.rstrip("/")) or path


def _sanitize_tool_input(tool_input: dict | None, tool_name: str) -> dict:
    """Extract only the interesting fields from tool_input to keep JSON small."""
    if not tool_input:
        return {}
    if tool_name == "Bash":
        cmd = tool_input.get("command", "")
        return {"command": cmd[:120] + "..." if len(cmd) > 120 else cmd}
    if tool_name in ("Edit", "Read", "LS"):
        return {"path": tool_input.get("path", "")}
    if tool_name == "Glob":
        pat = tool_input.get("pattern", "")
        return {"pattern": pat[:120] + "..." if len(pat) > 120 else pat}
    if tool_name == "Grep":
        return {
            "pattern": tool_input.get("pattern", ""),
            "path": tool_input.get("path", "."),
        }
    # Generic fallback: keep short string/bool/int values only
    result: dict = {}
    for k, v in tool_input.items():
        if isinstance(v, str):
            result[k] = v[:120] + "..." if len(v) > 120 else v
        elif isinstance(v, (bool, int, float)):
            result[k] = v
    return result


def _tool_detail(tool_input: dict | None, tool_name: str) -> str:
    """Human-readable one-liner for what a tool is doing."""
    if not tool_input:
        return ""
    if tool_name == "Bash":
        return tool_input.get("command", "")[:60]
    if tool_name in ("Edit", "Read", "LS"):
        return _basename(tool_input.get("path", ""))
    if tool_name == "Glob":
        return tool_input.get("pattern", "")[:60]
    if tool_name == "Grep":
        pat = tool_input.get("pattern", "")
        path = tool_input.get("path", ".")
        return f"{_basename(path)}: {pat}"[:60]
    return ""


def _format_action(event: str, data: dict) -> tuple[str, dict]:
    """Return (action_text, extra_fields) for a given event."""
    extras: dict = {}

    if event == "SessionStart":
        extras["model"] = data.get("model", "")
        extras["claude_pid"] = os.getppid()
        return ("started", extras)

    if event == "UserPromptSubmit":
        prompt = data.get("prompt", "")
        extras["prompt"] = prompt
        return (prompt[:35] + "..." if len(prompt) > 35 else prompt or "thinking...", extras)

    if event == "PreToolUse":
        tool = data.get("tool_name", "")
        tool_input = _sanitize_tool_input(data.get("tool_input"), tool)
        extras["tool_name"] = tool
        extras["tool_input"] = tool_input
        detail = _tool_detail(tool_input, tool)
        return (f"{tool}: {detail}" if detail else tool, extras)

    if event == "PostToolUse":
        tool = data.get("tool_name", "")
        extras["tool_name"] = tool
        extras["tool_input"] = _sanitize_tool_input(data.get("tool_input"), tool)
        return ("running", extras)

    if event == "PostToolUseFailure":
        tool = data.get("tool_name", "")
        err = data.get("error", {})
        extras["tool_name"] = tool
        extras["tool_input"] = _sanitize_tool_input(data.get("tool_input"), tool)
        extras["error"] = err.get("message", "") if isinstance(err, dict) else str(err)
        return (f"Error: {tool}", extras)

    if event == "PermissionRequest":
        tool = data.get("tool_name", "")
        extras["tool_name"] = tool
        extras["tool_input"] = _sanitize_tool_input(data.get("tool_input"), tool)
        return (f"Allow {tool}?", extras)

    if event == "SubagentStart":
        agent_type = data.get("agent_type", "subagent")
        extras["agent_type"] = agent_type
        return (f"{agent_type}...", extras)

    if event == "SubagentStop":
        agent_type = data.get("agent_type", "")
        extras["agent_type"] = agent_type
        extras["last_assistant_message"] = data.get("last_assistant_message", "")
        return ("subagent done", extras)

    if event == "Notification":
        ntype = data.get("notification_type", "")
        message = data.get("message", "")
        extras["notification_message"] = message
        if ntype in ("permission_prompt", "elicitation_dialog"):
            return ("needs input", extras)
        if ntype == "idle_prompt":
            return ("finished", extras)
        return (message[:40] or f"ntype: {ntype}", extras)

    if event == "Stop":
        extras["last_assistant_message"] = data.get("last_assistant_message", "")
        return ("finished", extras)

    if event == "SessionEnd":
        return ("", extras)

    # Unknown event
    return (f"event: {event}", extras)


def _update_tool_count(db: dict, session_id: str, event: str) -> int:
    session = db["sessions"].get(session_id, {})
    if event == "UserPromptSubmit":
        return 0
    if event == "PreToolUse":
        return session.get("tool_count", 0) + 1
    return session.get("tool_count", 0)


def _upsert_session(
    path: str,
    session_id: str,
    state: str,
    action: str,
    cwd: str,
    transcript: str,
    now: str,
    extras: dict,
    event: str,
) -> None:
    db = _read_db(path)
    existing = db["sessions"].get(session_id, {})

    tool_count = _update_tool_count(db, session_id, event)

    # Preserve prompt across the turn unless a new one arrives
    prompt = extras.get("prompt") or existing.get("prompt", "")
    # Clear prompt on new user submission
    if event == "UserPromptSubmit":
        prompt = extras.get("prompt", "")

    # Start of a new turn: clear stale tool/error state
    if event == "UserPromptSubmit":
        tool_name = extras.get("tool_name")
        tool_input = extras.get("tool_input")
        error = extras.get("error")
    else:
        tool_name = extras.get("tool_name") or existing.get("tool_name")
        tool_input = extras.get("tool_input") or existing.get("tool_input")
        error = extras.get("error") or existing.get("error")

    session = {
        "session_id": session_id,
        "state": state,
        "action": action,
        "cwd": cwd,
        "transcript": transcript,
        "updated_at": now,
        "prompt": prompt,
        "tool_name": tool_name,
        "tool_input": tool_input,
        "tool_count": tool_count,
        "agent_type": extras.get("agent_type") or existing.get("agent_type"),
        "error": error,
        "notification_message": extras.get("notification_message") or existing.get("notification_message"),
        "last_assistant_message": extras.get("last_assistant_message") or existing.get("last_assistant_message"),
    }

    # Clean None values
    session = {k: v for k, v in session.items() if v is not None}

    db["sessions"][session_id] = session
    _write_db(path, db)


def _remove_session(path: str, session_id: str) -> None:
    if not os.path.exists(path):
        return
    db = _read_db(path)
    db["sessions"].pop(session_id, None)
    _write_db(path, db)


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

    if event == "SessionEnd":
        log_event(data, None, "removed")
        _remove_session(file_path, session_id)
        return

    action, extras = _format_action(event, data)

    # Map event to state
    state: str
    if event == "SessionStart":
        state = "idle"
    elif event in ("UserPromptSubmit", "PostToolBatch", "PreToolUse", "PostToolUse"):
        state = "running"
    elif event in ("PermissionRequest",):
        state = "waiting"
    elif event == "SubagentStart":
        state = "running"
    elif event == "SubagentStop":
        state = "running"
    elif event == "Notification":
        ntype = data.get("notification_type", "")
        if ntype in ("permission_prompt", "elicitation_dialog"):
            state = "waiting"
        elif ntype == "idle_prompt":
            state = "idle"
        else:
            state = "unknown"
    elif event == "Stop":
        state = "idle"
    elif event == "PostToolUseFailure":
        state = "unknown"
    else:
        state = "unknown"

    log_event(data, state, action)
    _upsert_session(file_path, session_id, state, action, cwd, transcript, now, extras, event)


if __name__ == "__main__":
    main()
