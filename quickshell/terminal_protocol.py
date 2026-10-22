"""Small terminal snapshots with explicit project/label metadata and no message content."""

import os
from pathlib import Path
import re

from terminal_labels import LABEL_VARIABLE, clean_label, context as label_context

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


def agent_process(pane):
    if pane.get("at_prompt"):
        return "", 0
    for process in pane.get("foreground_processes", []):
        argv = process.get("cmdline") or []
        name = executable(argv)
        if name in {"agy", "antigravity"}:
            args = argv[2:] if executable(argv[:1]) != name else argv[1:]
            if (any(arg in {"-p", "--print", "--prompt"}
                    or arg.startswith(("--print=", "--prompt=")) for arg in args)
                    or args[:1] in (["remote-control"], ["mic-serve"])):
                continue
            return "antigravity", process.get("pid", 0)
        if name in {"codex", "claude", "kimi"}:
            if name == "codex" and any(arg in {"app-server", "exec-server"} for arg in argv):
                continue
            return name, process.get("pid", 0)
    return "", 0


def agent_kind(pane):
    return agent_process(pane)[0]


def antigravity_title(payload):
    data = payload if isinstance(payload, dict) else {}
    state = "unknown"
    if data.get("tool_confirmation_pending") is True:
        state = "waiting"
    elif data.get("agent_state") == "idle":
        state = "idle"
    elif data.get("agent_state") in ("initializing", "thinking", "working", "tool_use"):
        state = "running"
    workspace = data.get("workspace")
    directory = workspace.get("current_dir") if isinstance(workspace, dict) else None
    directory = directory or data.get("cwd")
    project = clean_label(os.path.basename(directory.rstrip("/"))) if isinstance(directory, str) else ""
    return f"[agy:{state}] {project or 'Antigravity'}"


def title_state(agent, title):
    title = str(title or "").lstrip()
    if agent == "antigravity":
        match = re.match(r"\[agy:(idle|running|waiting)\](?:\s|$)", title)
        return match[1] if match else ""
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


def codex_thread_name(title):
    # Codex's default title is: activity, thread-name | project-name.
    # An unnamed conversation has only the project, so keep its project label.
    value = title_key(title)
    if " | " not in value:
        return ""
    name = value.rsplit(" | ", 1)[0]
    # Name generation can add a second spinner after the thread name.
    return clean_label(re.sub(r"[\s\u2800-\u28ff]+$", "", name))


def session_name(agent, title):
    if agent == "codex":
        return codex_thread_name(title)
    if agent == "claude":
        name = clean_label(title_key(title))
        # The startup title is an application name, not a session name.
        if not re.fullmatch(r"claude(?: code)?(?: v?\d+(?:\.\d+){1,3})?", name, re.I):
            return name
    return ""


def semantic_title_key(agent, title):
    value = title_key(title)
    if agent == "antigravity":
        return re.sub(r"^\[agy:(?:idle|running|waiting|unknown)\]\s*", "", value)
    if agent == "codex" and " | " in value:
        return codex_thread_name(title) + " | " + value.rsplit(" | ", 1)[1]
    return value


def snapshot(layout):
    """Discard arguments, environment and message text.

    An unlabeled agent's directory goes only to the worker for one-time project
    discovery. Once labeled, the snapshot carries just that small context.
    """
    result = []
    for window in layout:
        panes = []
        for tab_number, tab in enumerate(window.get("tabs", []), 1):
            for pane in tab.get("windows", []):
                agent, pid = agent_process(pane)
                item = {"id": pane["id"], "tab": tab_number,
                    "active": bool(tab.get("is_active") and pane.get("is_active")),
                    "programs": programs(pane), "agent": agent,
                    "titleState": title_state(agent, pane.get("title", ""))}
                if agent:
                    item["agentPid"] = pid
                    if agent in {"codex", "claude"}:
                        item["threadName"] = session_name(agent, pane.get("title", ""))
                    item["context"] = label_context(pane.get("user_vars", {}).get(LABEL_VARIABLE), agent, pid)
                    if not item["context"]:
                        item["directory"] = pane.get("cwd", "")
                panes.append(item)
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
