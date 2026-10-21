"""Push terminal inventory and state transitions; never spawn commands or poll."""

import json
import os
from pathlib import Path
import socket
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "quickshell"))
from terminal_protocol import process_identity, semantic_title_key, snapshot, socket_path, title_state

_socket = None
_inventory = {}
_panes = {}
_title_keys = {}
_pending = False
_last = None
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
    send({"event": "close", "pane": window.id})
    schedule(boss)
