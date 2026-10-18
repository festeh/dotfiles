#!/usr/bin/env python3
"""Change the text width and font size of Zed's Markdown preview.

Usage: preview.py wider|narrower|width-reset|bigger|smaller|font-reset

Edits markdown_preview.max_width and markdown_preview.font_size in
settings.json. Zed watches that file's inode, not its directory, so a write
through a temp file and rename (what Zed's own "persist" font actions do)
silently ends the watching until Zed restarts. This script therefore writes
the file in place, and Zed's font keys are not used.

The preview reads max_width only when it redraws and doesn't redraw on a
settings change, so afterwards the script nudges the preview font +1/-1
(Zed's unsaved ctrl-= / ctrl--) through Hyprland to make it redraw.

Zed runs one task per key press and the presses may overlap, so the edit
holds a lock, and the redraw happens once, in the background, after the last
press of a burst.
"""
import fcntl
import os
import re
import subprocess
import sys
import time

SETTINGS = os.path.realpath(os.path.expanduser("~/.config/zed/settings.json"))
RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
LOCK = os.path.join(RUNTIME, "zed-preview.lock")
LAST_PRESS = os.path.join(RUNTIME, "zed-preview.last")
REDRAW_DELAY = 0.4  # Zed reloads settings 100 ms after a change

WIDTH = re.compile(r'("max_width"\s*:\s*)(\d+)')
FONT = re.compile(r'("font_size"\s*:\s*)(\d+(?:\.\d+)?)')
WIDTH_DEFAULT, WIDTH_STEP, WIDTH_MIN, WIDTH_MAX = 1100, 100, 400, 3000
FONT_DEFAULT, FONT_MIN, FONT_MAX = 16, 10, 40

CHANGES = {
    "wider": (WIDTH, lambda v: v + WIDTH_STEP),
    "narrower": (WIDTH, lambda v: v - WIDTH_STEP),
    "width-reset": (WIDTH, lambda v: WIDTH_DEFAULT),
    "bigger": (FONT, lambda v: v + 1),
    "smaller": (FONT, lambda v: v - 1),
    "font-reset": (FONT, lambda v: FONT_DEFAULT),
}
LIMITS = {WIDTH: (WIDTH_MIN, WIDTH_MAX), FONT: (FONT_MIN, FONT_MAX)}


def redraw_preview():
    for key in ("equal", "minus"):
        shortcut = f'hl.dsp.send_shortcut({{mods="CTRL", key="{key}", window="class:dev.zed.Zed"}})'
        subprocess.run(["hyprctl", "dispatch", shortcut], capture_output=True)


def redraw_after_last_press():
    """Return at once; a detached child redraws unless a newer press came."""
    press = str(time.time_ns())
    with open(LAST_PRESS, "w") as f:
        f.write(press)
    if os.fork():
        return
    os.setsid()  # outlive the task's terminal
    if os.fork():
        os._exit(0)
    time.sleep(REDRAW_DELAY)
    with open(LAST_PRESS) as f:
        if f.read() == press:
            redraw_preview()
    os._exit(0)


def main():
    action = sys.argv[1] if len(sys.argv) == 2 else ""
    if action not in CHANGES:
        sys.exit(f"usage: preview.py {'|'.join(CHANGES)}")
    pattern, change = CHANGES[action]
    low, high = LIMITS[pattern]

    def replace(m):
        value = change(int(float(m[2])))
        return m[1] + str(min(max(value, low), high))

    # The file holds comments and trailing commas, so it is edited as text.
    with open(LOCK, "w") as lock, open(SETTINGS, "r+") as f:
        fcntl.flock(lock, fcntl.LOCK_EX)
        text, count = pattern.subn(replace, f.read())
        if count != 1:
            sys.exit(f"{SETTINGS}: expected one {pattern.pattern}, found {count}")
        f.seek(0)
        f.write(text)
        f.truncate()

    redraw_after_last_press()


if __name__ == "__main__":
    main()
