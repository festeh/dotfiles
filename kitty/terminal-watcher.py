"""Push terminal events and cheaply sample Claude footer counters in-process."""

import json
import os
from pathlib import Path
import socket
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "quickshell"))
from terminal_protocol import claude_footer_counts, process_identity, semantic_title_key, snapshot, socket_path, title_state

_socket = None
_inventory = {}
_panes = {}
_title_keys = {}
_pending = False
_last = None
_activity_timer = None
_start = process_identity(os.getpid())[0]


def send(message):
    global _socket
    try:
        if _socket is None:
            _socket = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM | socket.SOCK_NONBLOCK)
        message.update(pid=os.getpid(), start=_start)
        _socket.sendto(json.dumps(message, separators=(",", ":")).encode(), socket_path())
    except OSError:
        # A stopped/reloading bar must never stall the terminal.
        pass


def signature(manager):
    return tuple((tab.id, tab is manager.active_tab,
        tuple((window.id, window is tab.active_window) for window in tab.windows)) for tab in manager.tabs)


def footer_counts(window):
    # Keep screen text inside Kitty. Soft-wrapped rows belong to one logical
    # line; skip a first row whose beginning falls outside the bounded sample.
    lines = []
    try:
        screen = window.screen
        for index in range(max(0, screen.lines - 8), screen.lines):
            text = str(screen.line(index))
            if screen.linebuf.is_continued(index):
                if lines:
                    lines[-1] += text
            else:
                lines.append(text)
    except (AttributeError, IndexError):
        return None
    return claude_footer_counts(lines)


def shutdown():
    global _activity_timer
    if _activity_timer is not None:
        from kitty.fast_data_types import remove_timer
        remove_timer(_activity_timer)
        _activity_timer = None


def sync_activity_timer(boss):
    global _activity_timer
    if any(pane["agent"] == "claude" for pane in _panes.values()):
        if _activity_timer is None:
            from kitty.fast_data_types import add_timer
            _activity_timer = add_timer(lambda _timer: sample_activity(boss), 2.0, True)
    else:
        shutdown()


def sample_activity(boss):
    for pane in list(_panes.values()):
        if pane["agent"] != "claude":
            continue
        window = boss.window_id_map.get(pane["id"])
        if window is None:
            continue
        activity = footer_counts(window)
        if activity != pane.get("activity"):
            pane["activity"] = activity
            send({"event": "activity", "pane": pane["id"],
                "agentPid": pane["agentPid"], "activity": activity})


def resync(boss, force=False):
    global _pending, _last, _inventory, _panes, _title_keys
    _pending = False
    layout = list(boss.list_os_windows())
    # A fixed/overridden window title must not hide the TUI's activity title.
    for window in layout:
        for tab in window["tabs"]:
            for pane in tab["windows"]:
                native = boss.window_id_map.get(pane["id"])
                if native is not None:
                    pane["title"] = native.child_title
    value = snapshot(layout)
    _panes = {pane["id"]: pane for window in value for pane in window["panes"]}
    for pane in _panes.values():
        if pane["agent"] == "claude":
            native = boss.window_id_map.get(pane["id"])
            pane["activity"] = footer_counts(native) if native is not None else None
    sync_activity_timer(boss)
    _title_keys = {pane["id"]: semantic_title_key(_panes[pane["id"]]["agent"], pane.get("title", ""))
        for window in layout for tab in window["tabs"] for pane in tab["windows"]}
    _inventory = {key: signature(manager) for key, manager in boss.os_window_map.items()}
    if force or value != _last:
        _last = value
        send({"event": "snapshot", "windows": value})


def schedule(boss, delay=0.04):
    global _pending
    if _pending:
        return
    from kitty.fast_data_types import add_timer
    _pending = True
    add_timer(lambda _timer: resync(boss), delay, False)


def on_load(boss, data):
    schedule(boss)


def on_resize(boss, window, data):
    if window.id not in _panes:
        schedule(boss)
    elif _panes[window.id]["agent"] == "claude":
        sample_activity(boss)


def on_tab_bar_dirty(boss, window, data):
    manager = data.get("tab_manager")
    if manager is not None and _inventory.get(manager.os_window_id) != signature(manager):
        schedule(boss)


def on_focus_change(boss, window, data):
    schedule(boss)


def on_cmd_startstop(boss, window, data):
    # Let the shell install its foreground process group before inspecting it.
    schedule(boss, 0.08)


def on_set_user_var(boss, window, data):
    if data.get("key") == "quickshell_agent_label":
        schedule(boss)


def on_title_change(boss, window, data):
    pane = _panes.get(window.id)
    if pane is None:
        schedule(boss, 0.08)
        return
    key = semantic_title_key(pane["agent"], data.get("title", ""))
    if key != _title_keys.get(window.id):
        _title_keys[window.id] = key
        # Also catches wrappers that exec an app after the shell's command-start
        # event. Spinner changes alone never re-read foreground processes.
        schedule(boss, 0.08)
    state = title_state(pane["agent"], data.get("title", ""))
    if state != pane["titleState"]:
        pane["titleState"] = state
        send({"event": "state", "pane": window.id, "state": state})


def on_close(boss, window, data):
    _panes.pop(window.id, None)
    _title_keys.pop(window.id, None)
    sync_activity_timer(boss)
    send({"event": "close", "pane": window.id})
    schedule(boss)
