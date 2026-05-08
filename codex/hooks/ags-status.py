#!/usr/bin/env python3
"""Codex hook script for the AGS status widget.

Reads Codex hook JSON from stdin and maintains
~/.cache/ags-codex/sessions/<id>.json (one file per session). Logs events to
~/.cache/ags-codex/hook.log. The script intentionally writes nothing to stdout
because Codex interprets hook stdout as control data or extra context.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


CACHE_DIR = Path(os.path.expanduser("~/.cache/ags-codex"))
SESSIONS_DIR = CACHE_DIR / "sessions"
NON_IDLE_STALE_SECONDS = 300
PIDLESS_IDLE_STALE_SECONDS = 24 * 60 * 60


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _session_path(session_id: str) -> Path:
    return SESSIONS_DIR / f"{session_id}.json"


def _log(line: str) -> None:
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        with (CACHE_DIR / "hook.log").open("a", encoding="utf-8") as f:
            f.write(f"{_now()} {line}\n")
    except OSError:
        pass


def _log_event(data: dict[str, Any], state: str | None, action: str | None) -> None:
    event = data.get("hook_event_name", "unknown")
    session_id = data.get("session_id", "no-session")
    turn_id = data.get("turn_id", "")
    tool = data.get("tool_name") or data.get("tool", "")
    extras = []
    if turn_id:
        extras.append(f"turn={turn_id}")
    if tool:
        extras.append(f"tool={tool}")
    result = f"state={state} action={action}" if state else "ignored"
    _log(f"[{session_id}] {event} {' '.join(extras)} -> {result}")


def _read_session(session_id: str) -> dict[str, Any]:
    path = _session_path(session_id)
    if not path.exists():
        return {}
    try:
        with path.open("r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (json.JSONDecodeError, OSError):
        return {}


def _write_session(session_id: str, session: dict[str, Any]) -> None:
    SESSIONS_DIR.mkdir(parents=True, exist_ok=True)
    path = _session_path(session_id)
    tmp_path = path.with_name(f"{path.name}.{os.getpid()}.tmp")
    with tmp_path.open("w", encoding="utf-8") as f:
        json.dump(session, f, indent=2)
    os.replace(tmp_path, path)


def _basename(path: str) -> str:
    if not path:
        return ""
    return os.path.basename(path.rstrip("/")) or path


def _truncate(value: str, limit: int) -> str:
    return value[:limit] + "..." if len(value) > limit else value


def _sanitize_tool_input(tool_input: Any, tool_name: str) -> dict[str, Any]:
    if not isinstance(tool_input, dict):
        return {}

    if tool_name == "Bash":
        cmd = str(tool_input.get("command", ""))
        return {"command": _truncate(cmd, 160)}

    if tool_name == "apply_patch":
        # Patches can be very large and may contain sensitive file contents.
        return {"patch": "apply_patch"}

    if tool_name in ("Edit", "Write", "Read", "LS"):
        return {
            "path": tool_input.get("path") or tool_input.get("file_path") or "",
        }

    if tool_name == "Glob":
        return {"pattern": _truncate(str(tool_input.get("pattern", "")), 160)}

    if tool_name == "Grep":
        return {
            "pattern": _truncate(str(tool_input.get("pattern", "")), 160),
            "path": tool_input.get("path", "."),
        }

    result: dict[str, Any] = {}
    for key, value in tool_input.items():
        if key.lower() in ("token", "api_key", "apikey", "authorization", "password", "secret"):
            continue
        if isinstance(value, str):
            result[key] = _truncate(value, 160)
        elif isinstance(value, (bool, int, float)):
            result[key] = value
    return result


def _tool_detail(tool_input: dict[str, Any], tool_name: str) -> str:
    if not tool_input:
        return ""
    if tool_name == "Bash":
        return str(tool_input.get("command", ""))[:60]
    if tool_name == "apply_patch":
        return "patch"
    if tool_name in ("Edit", "Write", "Read", "LS"):
        return _basename(str(tool_input.get("path", "")))
    if tool_name == "Glob":
        return str(tool_input.get("pattern", ""))[:60]
    if tool_name == "Grep":
        pat = str(tool_input.get("pattern", ""))
        path = str(tool_input.get("path", "."))
        return f"{_basename(path)}: {pat}"[:60]
    for value in tool_input.values():
        if isinstance(value, str) and value:
            return value[:60]
    return ""


def _read_ppid(pid: int) -> int | None:
    try:
        with open(f"/proc/{pid}/status", "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("PPid:"):
                    return int(line.split()[1])
    except (OSError, ValueError):
        pass
    return None


def _proc_names(pid: int) -> tuple[str, str]:
    comm = ""
    cmd = ""
    try:
        with open(f"/proc/{pid}/comm", "r", encoding="utf-8") as f:
            comm = f.read().strip()
    except OSError:
        pass
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            parts = [p.decode(errors="ignore") for p in f.read().split(b"\0") if p]
            cmd = os.path.basename(parts[0]) if parts else ""
    except OSError:
        pass
    return comm, cmd


def _find_codex_pid(start_pid: int) -> int | None:
    pid: int | None = start_pid
    for _ in range(25):
        if pid is None or pid <= 1:
            break
        comm, cmd = _proc_names(pid)
        if "codex" in comm.lower() or "codex" in cmd.lower():
            return pid
        pid = _read_ppid(pid)
    if start_pid > 1:
        _log(f"could not find codex ancestor, using ppid={start_pid}")
        return start_pid
    _log("could not find codex ancestor or usable parent pid")
    return None


def _resolve_window_address(codex_pid: int | None) -> str | None:
    if codex_pid is None:
        return None
    try:
        result = subprocess.run(
            ["hyprctl", "clients", "-j"],
            capture_output=True,
            text=True,
            timeout=2,
        )
        if result.returncode != 0:
            return None
        clients = json.loads(result.stdout)
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError):
        return None

    pid_to_addr: dict[int, str] = {}
    for client in clients:
        if isinstance(client, dict):
            pid = client.get("pid")
            address = client.get("address")
            if isinstance(pid, int) and isinstance(address, str):
                pid_to_addr[pid] = address

    pid: int | None = codex_pid
    for _ in range(25):
        if pid is None or pid <= 1:
            return None
        if pid in pid_to_addr:
            return pid_to_addr[pid]
        pid = _read_ppid(pid)
    return None


def _format_action(event: str, data: dict[str, Any]) -> tuple[str, dict[str, Any]]:
    extras: dict[str, Any] = {}

    if event == "SessionStart":
        source = data.get("source", "")
        extras["source"] = source
        return ("resumed" if source == "resume" else "started", extras)

    if event == "UserPromptSubmit":
        prompt = str(data.get("prompt", ""))
        extras["prompt"] = prompt
        return (_truncate(prompt, 35) or "thinking...", extras)

    if event in ("PreToolUse", "PostToolUse", "PermissionRequest"):
        tool = str(data.get("tool_name") or data.get("tool") or "")
        tool_input = _sanitize_tool_input(data.get("tool_input") or data.get("input"), tool)
        extras["tool_name"] = tool
        extras["tool_input"] = tool_input
        detail = _tool_detail(tool_input, tool)

        if event == "PostToolUse":
            return ("", extras)

        if event == "PermissionRequest":
            reason = str(data.get("reason") or data.get("description") or data.get("message") or "")
            extras["approval_reason"] = reason
            return (f"Allow {tool}?" if tool else "needs approval", extras)

        return (f"{tool}: {detail}" if detail else tool or "tool use", extras)

    if event == "Stop":
        extras["last_assistant_message"] = data.get("last_assistant_message", "")
        return ("finished", extras)

    return (f"event: {event}", extras)


def _state_for_event(event: str) -> str:
    if event == "SessionStart":
        return "idle"
    if event in ("UserPromptSubmit", "PreToolUse", "PostToolUse"):
        return "running"
    if event == "PermissionRequest":
        return "waiting"
    if event == "Stop":
        return "idle"
    return "unknown"


def _update_tool_count(existing: dict[str, Any], event: str) -> int:
    try:
        current = int(existing.get("tool_count", 0))
    except (TypeError, ValueError):
        current = 0
    if event == "UserPromptSubmit":
        return 0
    if event == "PreToolUse":
        return current + 1
    return current


def _upsert_session(
    session_id: str,
    state: str,
    action: str,
    data: dict[str, Any],
    extras: dict[str, Any],
) -> None:
    existing = _read_session(session_id)
    event = str(data.get("hook_event_name", ""))
    prompt = extras.get("prompt") if event == "UserPromptSubmit" else existing.get("prompt", "")

    if event == "UserPromptSubmit":
        tool_name = None
        tool_input = None
        approval_reason = None
    else:
        tool_name = extras.get("tool_name") or existing.get("tool_name")
        tool_input = extras.get("tool_input") or existing.get("tool_input")
        approval_reason = extras.get("approval_reason") or existing.get("approval_reason")

    codex_pid = _find_codex_pid(os.getppid())
    window_address = _resolve_window_address(codex_pid) or existing.get("window_address")
    effective_action = action if action else existing.get("action", "")

    session = {
        "session_id": session_id,
        "turn_id": data.get("turn_id") or existing.get("turn_id"),
        "state": state,
        "action": effective_action,
        "cwd": data.get("cwd", ""),
        "transcript": data.get("transcript_path") or "",
        "updated_at": _now(),
        "prompt": prompt,
        "tool_name": tool_name,
        "tool_input": tool_input,
        "tool_count": _update_tool_count(existing, event),
        "model": data.get("model") or existing.get("model"),
        "source": extras.get("source") or existing.get("source"),
        "approval_reason": approval_reason,
        "last_assistant_message": extras.get("last_assistant_message") or existing.get("last_assistant_message"),
        "codex_pid": codex_pid,
        "window_address": window_address,
    }

    session = {k: v for k, v in session.items() if v not in (None, "")}
    _write_session(session_id, session)


def _is_pid_alive(pid: Any) -> bool:
    return isinstance(pid, int) and Path(f"/proc/{pid}").is_dir()


def _prune_sessions() -> None:
    if not SESSIONS_DIR.is_dir():
        return
    now_ts = datetime.now(timezone.utc).timestamp()
    for path in SESSIONS_DIR.glob("*.json"):
        try:
            with path.open("r", encoding="utf-8") as f:
                session = json.load(f)
        except (json.JSONDecodeError, OSError):
            continue
        if not isinstance(session, dict):
            continue
        pid = session.get("codex_pid")
        if _is_pid_alive(pid):
            continue
        if isinstance(pid, int):
            try:
                path.unlink()
            except OSError:
                pass
            continue

        try:
            updated_ts = datetime.fromisoformat(str(session.get("updated_at"))).timestamp()
        except (TypeError, ValueError):
            updated_ts = 0
        stale_after = PIDLESS_IDLE_STALE_SECONDS if session.get("state") == "idle" else NON_IDLE_STALE_SECONDS
        if now_ts - updated_ts > stale_after:
            try:
                path.unlink()
            except OSError:
                pass


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        return

    if not isinstance(data, dict):
        return

    event = data.get("hook_event_name")
    session_id = data.get("session_id")
    if not event or not session_id:
        return

    event = str(event)
    session_id = str(session_id)
    action, extras = _format_action(event, data)
    state = _state_for_event(event)

    _log_event(data, state, action)
    _upsert_session(session_id, state, action, data, extras)
    _prune_sessions()


if __name__ == "__main__":
    main()
