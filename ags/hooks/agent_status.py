"""Hook writer for the AGS agent pills.

Agent hooks (Claude Code, Kimi Code) pipe their event JSON into `main(agent)`,
which keeps ~/.cache/ags-agents/windows/<KITTY_PID>-<KITTY_WINDOW_ID>.json up to
date: the state of the agent running in that Kitty window. AGS decides which
windows run an agent from `kitty @ ls`, so this file only carries state and
details for the popover. Events outside Kitty are ignored.

Codex has no hook here: its sessions run in a shared app-server daemon whose
environment belongs to whichever window started it, so AGS reads Codex state
from the terminal title instead.

Hooks must never disturb the agent, so failures are logged and swallowed, and
nothing is written to stdout (agents may parse it as control output).
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

CACHE_DIR = Path.home() / ".cache" / "ags-agents"
WINDOWS_DIR = CACHE_DIR / "windows"
LOG_PATH = CACHE_DIR / "hook.log"
LOG_MAX_BYTES = 1_000_000

STATE_BY_EVENT = {
    "SessionStart": "idle",
    "UserPromptSubmit": "running",
    "PreToolUse": "running",
    "PostToolUse": "running",
    "PostToolUseFailure": "running",
    "PostToolBatch": "running",
    "PermissionResult": "running",
    "SubagentStart": "running",
    "PostCompact": "running",
    "PermissionRequest": "waiting",
    "PreCompact": "compacting",
    "Stop": "idle",
    "StopFailure": "idle",
    "Interrupt": "idle",
}

TOOL_DETAIL_KEYS = ("command", "file_path", "path", "pattern", "url", "query", "description")


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _log(line: str) -> None:
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        if LOG_PATH.exists() and LOG_PATH.stat().st_size > LOG_MAX_BYTES:
            LOG_PATH.replace(LOG_PATH.with_name(LOG_PATH.name + ".1"))
        with LOG_PATH.open("a", encoding="utf-8") as f:
            f.write(f"{_now()} {line}\n")
    except OSError:
        pass


def _one_line(value: str, limit: int) -> str:
    value = " ".join(value.split())
    return value[:limit] + "..." if len(value) > limit else value


def _prompt_text(prompt: Any) -> str:
    """Kimi sends the prompt as a string or a list of content parts."""
    if isinstance(prompt, str):
        return prompt
    if isinstance(prompt, list):
        return " ".join(
            part["text"] for part in prompt
            if isinstance(part, dict) and part.get("type") == "text" and isinstance(part.get("text"), str)
        )
    return ""


def _tool_detail(tool_input: Any) -> str:
    if not isinstance(tool_input, dict):
        return ""
    for key in TOOL_DETAIL_KEYS:
        value = tool_input.get(key)
        if isinstance(value, str) and value.strip():
            return _one_line(value, 160)
    return ""


def _git_branch(cwd: str) -> str | None:
    if not cwd:
        return None
    try:
        result = subprocess.run(
            ["git", "-C", cwd, "branch", "--show-current"],
            capture_output=True, text=True, timeout=0.5,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if result.returncode != 0:
        return None
    return result.stdout.strip() or None


def _next_state(event: str, data: dict[str, Any]) -> str | None:
    """New state for an event, or None to keep the current one."""
    if event == "Notification":
        ntype = data.get("notification_type")
        if ntype in ("permission_prompt", "elicitation_dialog"):
            return "waiting"
        return "idle" if ntype == "idle_prompt" else None
    if event == "PostToolUseFailure" and data.get("is_interrupt"):
        return "idle"
    # SubagentStop can arrive after the main turn stopped; never revive an idle pill.
    return STATE_BY_EVENT.get(event)


def _read(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def _write(path: Path, record: dict[str, Any]) -> None:
    WINDOWS_DIR.mkdir(parents=True, exist_ok=True)
    tmp_path = path.with_name(f"{path.name}.{os.getpid()}.tmp")
    with tmp_path.open("w", encoding="utf-8") as f:
        json.dump(record, f, indent=2)
    os.replace(tmp_path, path)


def _prune_dead_kitty_files() -> None:
    for path in WINDOWS_DIR.glob("*.json"):
        kitty_pid = path.stem.split("-", 1)[0]
        if kitty_pid.isdigit() and not Path(f"/proc/{kitty_pid}").exists():
            path.unlink(missing_ok=True)


def _update(existing: dict[str, Any], agent: str, event: str, data: dict[str, Any]) -> dict[str, Any]:
    session_id = str(data.get("session_id") or "")
    new_session = event == "SessionStart" or existing.get("session_id") != session_id or existing.get("agent") != agent
    record = {} if new_session else dict(existing)
    now = _now()

    state = _next_state(event, data) or record.get("state") or "idle"
    if state != record.get("state"):
        record["state_since"] = now
    record.update(agent=agent, session_id=session_id, state=state, updated_at=now)

    cwd = str(data.get("cwd") or record.get("cwd") or "")
    record["cwd"] = cwd
    if event in ("SessionStart", "UserPromptSubmit") or "git_branch" not in record:
        record["git_branch"] = _git_branch(cwd)

    if event == "SessionStart" and data.get("model"):
        record["model"] = str(data["model"])
    if event == "UserPromptSubmit":
        for key in ("tool_name", "tool_detail", "error", "approval_reason", "notification_message"):
            record.pop(key, None)
        record["prompt"] = _one_line(_prompt_text(data.get("prompt")), 500)
        record["tool_count"] = 0
    if event == "PreToolUse":
        record["tool_count"] = int(record.get("tool_count") or 0) + 1
    if data.get("tool_name"):
        record["tool_name"] = str(data["tool_name"])
        record["tool_detail"] = _tool_detail(data.get("tool_input"))
    if event == "PostToolUseFailure" and not data.get("is_interrupt"):
        error = data.get("error")
        record["error"] = str(error.get("message", "") if isinstance(error, dict) else error or "")
    if event == "StopFailure":
        record["error"] = str(data.get("error_message") or data.get("error_type") or "")
    if event == "PermissionRequest":
        display = data.get("display")
        summary = display.get("summary") if isinstance(display, dict) else None
        record["approval_reason"] = str(summary or data.get("action") or "")
    if event == "Notification" and data.get("message"):
        record["notification_message"] = str(data["message"])
    if event == "SubagentStart":
        record["agent_type"] = str(data.get("agent_type") or data.get("agent_name") or "subagent")
    if event == "Stop" and data.get("last_assistant_message"):
        record["last_assistant_message"] = _one_line(str(data["last_assistant_message"]), 500)

    return {key: value for key, value in record.items() if value not in (None, "")}


def _handle(agent: str, data: dict[str, Any]) -> None:
    kitty_pid = os.environ.get("KITTY_PID", "")
    window_id = os.environ.get("KITTY_WINDOW_ID", "")
    event = str(data.get("hook_event_name") or "")
    if not (kitty_pid.isdigit() and window_id.isdigit() and event):
        return

    key = f"{kitty_pid}-{window_id}"
    path = WINDOWS_DIR / f"{key}.json"
    existing = _read(path)

    if event == "SessionEnd":
        # Only the session that owns the window may clear it (not a nested agent).
        if existing.get("session_id") == data.get("session_id"):
            path.unlink(missing_ok=True)
            _log(f"[{agent} {key}] SessionEnd -> removed")
        return
    # Claude re-fires SessionStart after compaction; keep the compaction state instead.
    if event == "SessionStart" and data.get("source") == "compact":
        return
    # Subagent-internal events carry agent_id; the main session already shows running.
    if data.get("agent_id") and event != "SubagentStart":
        return

    record = _update(existing, agent, event, data)
    _write(path, record)
    if event == "SessionStart":
        _prune_dead_kitty_files()
    _log(f"[{agent} {key}] {event} -> {record['state']}")


def main(agent: str) -> None:
    try:
        data = json.load(sys.stdin)
        if isinstance(data, dict):
            _handle(agent, data)
    except Exception as error:  # noqa: BLE001 - a telemetry hook must never fail the agent
        _log(f"[{agent}] hook error: {error!r}")
