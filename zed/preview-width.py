#!/usr/bin/env python3
"""Widen, narrow or reset the text column of Zed's Markdown preview.

Changes markdown_preview.max_width in settings.json. The preview reads that
setting only when it redraws and doesn't redraw on settings changes, so the
script then nudges the preview font one step up and back down through
Hyprland, which makes it redraw with the new width. Run from the tasks in
tasks.json, which keymap.json binds to keys in the preview.
"""
import os
import re
import subprocess
import sys
import tempfile
import time

SETTINGS = os.path.realpath(os.path.expanduser("~/.config/zed/settings.json"))
DEFAULT, STEP, MIN, MAX = 800, 100, 400, 2400

# settings.json may hold comments and trailing commas, so it is edited as text.
WIDTH = re.compile(r'("max_width"\s*:\s*)(\d+)')


def redraw_preview():
    # ctrl-= / ctrl-- are Zed's own font size keys; in the preview they change
    # its font without saving it, so +1 then -1 leaves the size as it was.
    for key in ("equal", "minus"):
        shortcut = f'hl.dsp.send_shortcut({{mods="CTRL", key="{key}", window="class:dev.zed.Zed"}})'
        subprocess.run(["hyprctl", "dispatch", shortcut], capture_output=True)


def main():
    action = sys.argv[1] if len(sys.argv) == 2 else ""
    if action not in ("wider", "narrower", "reset"):
        sys.exit("usage: preview-width.py wider|narrower|reset")

    def width(m):
        if action == "reset":
            value = DEFAULT
        else:
            value = int(m[2]) + (STEP if action == "wider" else -STEP)
        return m[1] + str(min(max(value, MIN), MAX))

    with open(SETTINGS) as f:
        text = f.read()
    text, count = WIDTH.subn(width, text)
    if count != 1:
        sys.exit(f"{SETTINGS}: expected one max_width, found {count}")

    # Write next to the file and rename over it, so Zed never reads half a file.
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(SETTINGS), prefix=".settings.")
    with os.fdopen(fd, "w") as f:
        f.write(text)
    os.chmod(tmp, 0o644)
    os.replace(tmp, SETTINGS)

    time.sleep(0.4)  # let Zed reload the settings first
    redraw_preview()


if __name__ == "__main__":
    main()
