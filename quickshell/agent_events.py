"""State-only agent hook output. No prompts, transcripts, Git calls or subprocesses."""

import fcntl
import json
import os
from pathlib import Path
import time

from terminal_protocol import process_identity, runtime_directory

EVENTS = {
    "SessionStart": "idle", "UserPromptSubmit": "running", "PreToolUse": "running",
    "PostToolUse": "running", "PostToolBatch": "running", "PostToolUseFailure": "running",
    "PermissionRequest": "waiting", "PermissionResult": "running",
    "Elicitation": "waiting", "ElicitationResult": "running",
    "PreCompact": "running", "PostCompact": "running",
    "Stop": "idle", "StopFailure": "idle", "Interrupt": "idle",
}


def record_event(agent, data):
    """Called in the already-running hook process; repeated states do no writes."""
    try:
        _record(agent, data)
    except (OSError, ValueError, TypeError, KeyError):
        # Status reporting must not affect agent execution or its stdout protocol.
        pass


def _record(agent, data):
    if agent not in {"claude", "kimi"} or not isinstance(data, dict) or data.get("agent_id"):
        return
    pid, pane = os.environ.get("KITTY_PID", ""), os.environ.get("KITTY_WINDOW_ID", "")
    if not (pid.isdigit() and pane.isdigit()):
        return
    identity = process_identity(int(pid))
    if identity is None or identity[1] != "kitty":
        return
    event = data.get("hook_event_name")
    if event == "SessionStart" and data.get("source") == "compact":
        return
    state = EVENTS.get(event)
    if event == "Notification":
        kind = data.get("notification_type")
        state = "waiting" if kind in {"permission_prompt", "elicitation_dialog"} else "idle" if kind == "idle_prompt" else None
    if event == "PostToolUseFailure" and data.get("is_interrupt"):
        state = "idle"
    if event == "PreToolUse" and data.get("tool_name") in {"AskUserQuestion", "ask_user_question"}:
        state = "waiting"
    if state is None and event != "SessionEnd":
        return
    directory = runtime_directory() / "quickshell-agents"
    directory.mkdir(mode=0o700, exist_ok=True)
    path = directory / f"{pid}-{pane}.json"
    with (directory / f".{pid}-{pane}.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            previous = json.loads(path.read_text())
        except (OSError, ValueError):
            previous = {}
        session = str(data.get("session_id") or "")
        same_instance = previous.get("start") == identity[0] and previous.get("agent") == agent
        if same_instance and previous.get("session") != session and event != "SessionStart":
            return
        if event == "SessionEnd":
            if same_instance and previous.get("session") == session:
                path.unlink(missing_ok=True)
            return
        if same_instance and previous.get("session") == session and previous.get("state") == state:
            return
        value = {"agent": agent, "state": state, "start": identity[0], "session": session,
            "at": time.monotonic_ns()}
        temporary = path.with_suffix(f".{os.getpid()}.tmp")
        descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(descriptor, "w") as output:
            json.dump(value, output, separators=(",", ":"))
        temporary.replace(path)
