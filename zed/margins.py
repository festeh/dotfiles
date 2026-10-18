#!/usr/bin/env python3
"""Widen, narrow or reset the margins in Zed.

Changes the markdown preview's text width and the side padding of the
centered layout in settings.json. Zed reloads the file on change, so the new
margins show at once. Run from the tasks in tasks.json, which keymap.json
binds to keys.
"""
import os
import re
import sys
import tempfile

SETTINGS = os.path.realpath(os.path.expanduser("~/.config/zed/settings.json"))

WIDTH_DEFAULT, WIDTH_STEP, WIDTH_MIN, WIDTH_MAX = 800, 100, 400, 2400
PADDING_DEFAULT, PADDING_STEP, PADDING_MAX = 0.2, 0.05, 0.4

# settings.json may hold comments and trailing commas, so it is edited as
# text: one markdown_preview.max_width and two centered_layout paddings.
WIDTH = re.compile(r'("max_width"\s*:\s*)(\d+)')
PADDING = re.compile(r'("(?:left|right)_padding"\s*:\s*)([\d.]+)')


def clamp(value, low, high):
    return min(max(value, low), high)


def main():
    action = sys.argv[1] if len(sys.argv) == 2 else ""
    if action not in ("wider", "narrower", "reset"):
        sys.exit("usage: margins.py wider|narrower|reset")
    sign = 1 if action == "wider" else -1

    def width(m):
        value = WIDTH_DEFAULT if action == "reset" else int(m[2]) - sign * WIDTH_STEP
        return m[1] + str(clamp(value, WIDTH_MIN, WIDTH_MAX))

    def padding(m):
        value = PADDING_DEFAULT if action == "reset" else float(m[2]) + sign * PADDING_STEP
        return m[1] + f"{round(clamp(value, 0, PADDING_MAX), 2):g}"

    with open(SETTINGS) as f:
        text = f.read()
    text, widths = WIDTH.subn(width, text)
    text, paddings = PADDING.subn(padding, text)
    if widths != 1 or paddings != 2:
        sys.exit(f"{SETTINGS}: expected one max_width and two paddings, found {widths} and {paddings}")

    # Write next to the file and rename over it, so Zed never reads half a file.
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(SETTINGS), prefix=".settings.")
    with os.fdopen(fd, "w") as f:
        f.write(text)
    os.chmod(tmp, 0o644)
    os.replace(tmp, SETTINGS)


if __name__ == "__main__":
    main()
