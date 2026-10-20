"""Small, content-free terminal snapshots shared by the tracker and Kitty watcher."""

import os
from pathlib import Path
import re

SHELLS = {"sh", "bash", "zsh", "fish", "dash", "nu", "xonsh"}
STATES = {"idle", "running", "waiting"}


def process_identity(pid):
    try:
        text = Path(f"/proc/{pid}/stat").read_text()
        return text.rpartition(") ")[2].split()[19], text[text.index("(") + 1:text.rindex(")")]
    except (OSError, ValueError, IndexError):
        return None


def executable(argv):
    if not argv or not isinstance(argv[0], str):
        return ""
    name = os.path.basename(argv[0])
    if re.fullmatch(r"node(?:js)?|python(?:\d+(?:\.\d+)?)?|ruby|perl", name):
        if len(argv) > 1 and isinstance(argv[1], str) and not argv[1].startswith("-"):
            name = re.sub(r"\.(?:[cm]?js|py|rb|pl)$", "", os.path.basename(argv[1]))
    return name


def programs(pane):
    if pane.get("at_prompt"):
        return []
    result = []
    for process in sorted(pane.get("foreground_processes", []), key=lambda p: p.get("pid", 0)):
        name = executable(process.get("cmdline") or [])
        if name and name not in SHELLS and name not in result:
            result.append(name)
    return result


def agent_kind(pane):
    if pane.get("at_prompt"):
        return ""
    for process in pane.get("foreground_processes", []):
        argv = process.get("cmdline") or []
        name = executable(argv)
        if name in {"codex", "claude", "kimi"}:
            if name == "codex" and any(arg in {"app-server", "exec-server"} for arg in argv):
                continue
            return name
    return ""


def title_state(agent, title):
    title = str(title or "").lstrip()
    if agent == "codex":
        if re.match(r"\[\s*[!.]\s*\]\s*Action Required\b", title, re.I):
            return "waiting"
        return "running" if re.match(r"[\u2801-\u28ff]", title) else "idle"
    if agent == "claude":
        if re.match(r"[\u2801-\u28ff\u25d0-\u25d3]", title):
            return "running"
        if title.startswith("✳"):
            return "idle"
    return ""


def title_key(title):
    title = re.sub(r"^\s*\[\s*[!.]\s*\]\s*Action Required\s*(?:\|\s*)?", "", str(title or ""), flags=re.I)
    return re.sub(r"^[\s\u2800-\u28ff\u25d0-\u25d3\u2733\u2722\u2736-\u273d\u00b7\ufe0e\ufe0f]+", "", title).strip()


def snapshot(layout):
    """Discard arguments, paths, environment, session names and message text."""
    result = []
    for window in layout:
        panes = []
        for tab_number, tab in enumerate(window.get("tabs", []), 1):
            for pane in tab.get("windows", []):
                agent = agent_kind(pane)
                panes.append({"id": pane["id"], "tab": tab_number,
                    "active": bool(tab.get("is_active") and pane.get("is_active")),
                    "programs": programs(pane), "agent": agent,
                    "titleState": title_state(agent, pane.get("title", ""))})
        result.append({"id": window["id"], "class": window.get("wm_class", ""), "panes": panes})
    return result


def aggregate(agents):
    states = [agent["state"] for agent in agents]
    if "waiting" in states:
        return "waiting"
    if "running" in states:
        return "running"
    return "idle" if states and all(state == "idle" for state in states) else ""


def runtime_directory():
    return Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))


def socket_path():
    return str(runtime_directory() / "quickshell-terminals.sock")
