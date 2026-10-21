"""Small per-agent labels persisted in Kitty, independent of activity titles."""

import json
from pathlib import Path
import unicodedata

LABEL_VARIABLE = "quickshell_agent_label"


def clean_label(value):
    if not isinstance(value, str):
        return ""
    return " ".join("".join(" " if ch.isspace() else ch for ch in value
        if ch.isspace() or not unicodedata.category(ch).startswith("C")).split())[:48]


def identity(agent, pid):
    return f"{agent}:{pid}"


def context(value, agent, pid):
    try:
        data = json.loads(value) if isinstance(value, str) and len(value) <= 2048 else value
        if (not isinstance(data, dict) or data.get("identity") != identity(agent, pid)
                or type(data.get("number")) is not int or not 1 <= data["number"] <= 100000):
            return None
        label, project = clean_label(data.get("label")), clean_label(data.get("project"))
        if label and project:
            source = data.get("source", "custom" if data.get("custom") else "project")
            if source not in {"project", "thread", "custom"}:
                return None
            return dict(identity=data["identity"], label=label, project=project,
                number=data["number"], custom=source == "custom", source=source)
    except (ValueError, TypeError):
        pass
    return None


def project_name(directory):
    path = Path(directory) if isinstance(directory, str) and directory else None
    if path is None or not path.is_absolute():
        return "terminal"
    # A worktree's .git file counts as its root too. No git subprocesses.
    for parent in (path, *path.parents):
        try:
            if (parent / ".git").exists():
                return clean_label(parent.name) or "project"
        except OSError:
            break
    return "home" if path == Path.home() else clean_label(path.name) or "terminal"


def make_context(agent, pid, project, label, others, source=None):
    source = source or ("custom" if clean_label(label) and clean_label(label) != project else "project")
    label = clean_label(label) or project
    occupied = {item["number"] for item in others if item["label"].casefold() == label.casefold()}
    number = 1
    while number in occupied:
        number += 1
    return dict(identity=identity(agent, pid), label=label, project=project,
        number=number, custom=source == "custom", source=source)


def display_label(data):
    suffix = f"·{data['number']}" if data["number"] > 1 else ""
    available = 12 - len(suffix)
    text = data["label"]
    if data.get("source") == "thread":
        # QML elides the end to its pixel budget, retaining the task's prefix.
        return text + suffix
    return (text if len(text) <= available else text[:available - 1] + "…") + suffix
