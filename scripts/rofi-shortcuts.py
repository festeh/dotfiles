#!/usr/bin/env python3
"""Rofi script mode for Hyprland shortcuts.

Lists every bind that has a description (see `shortcut()` in the Hyprland
config) and runs the selected one after rofi closes, so window actions apply to
the window that was focused before the launcher opened.

Usage:
    rofi -show shortcuts -modes "shortcuts:rofi-shortcuts"
"""

import html
import json
import os
import shlex
import subprocess
import sys

SEP = "\x1f"

MODIFIERS = [(64, "Super"), (4, "Ctrl"), (8, "Alt"), (1, "Shift")]

KEY_NAMES = {
    "slash": "/",
    "Return": "Enter",
    "left": "←",
    "right": "→",
    "up": "↑",
    "down": "↓",
}


def emit(line):
    sys.stdout.write(line + "\n")


def option(key, value):
    """A mode-wide option line: starts with NUL, so rofi reads it as a setting."""
    return f"\0{key}{SEP}{value}"


def row(text, **options):
    """A row: the text, then one NUL and the options joined by the separator."""
    fields = SEP.join(f"{key.replace('_', '-')}{SEP}{value}" for key, value in options.items())
    return f"{text}\0{fields}"


def keys_of(bind):
    names = [name for mask, name in MODIFIERS if bind["modmask"] & mask]
    key = bind["key"]
    names.append(KEY_NAMES.get(key, key.removeprefix("XF86")))
    return " + ".join(names)


def print_list():
    emit(option("prompt", "Shortcuts"))
    emit(option("markup-rows", "true"))
    emit(option("no-custom", "true"))

    binds = json.loads(subprocess.run(["hyprctl", "-j", "binds"], capture_output=True, text=True, check=True).stdout)
    # Several keys can share one action (Super+C and Super+Shift+Q both close a window).
    grouped = {}
    for bind in binds:
        if bind["has_description"] and not bind["mouse"]:
            grouped.setdefault(bind["description"], []).append(keys_of(bind))

    for description, keys in grouped.items():
        detail = ", ".join(keys)
        emit(row(
            f"{description} — {detail}",
            display=f"{html.escape(description)}   <span alpha='55%'>{html.escape(detail)}</span>",
            info=description,
        ))


def run_after_rofi(description):
    """Dispatch once rofi exits, so the action sees the previous focus and may open rofi again."""
    code = f"hl.dispatch(shortcuts[{json.dumps(description, ensure_ascii=False)}])"
    script = f"while kill -0 {os.getppid()} 2>/dev/null; do sleep 0.05; done; exec hyprctl eval {shlex.quote(code)}"
    subprocess.Popen(["sh", "-c", script], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


def main():
    selected = os.environ.get("ROFI_INFO")
    if os.environ.get("ROFI_RETV") == "1" and selected:
        run_after_rofi(selected)
        return  # No output: rofi closes.

    print_list()


if __name__ == "__main__":
    main()
