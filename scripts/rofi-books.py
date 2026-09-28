#!/usr/bin/env python3
"""Rofi script mode for the pCloud book library.

Lists ~/pCloudDrive/Library/Books, opens each file with the reader that fits its
format, and keeps recently opened books at the top. Cover thumbnails are
rendered lazily into ~/.cache/rofi-books/covers by a background pass.

Usage:
    rofi -show books -modes "books:rofi-books" -show-icons
    rofi-books --covers     # refresh cover thumbnails (normally automatic)
"""

import fcntl
import hashlib
import html
import os
import subprocess
import sys
import zipfile
from pathlib import Path

LIBRARY = Path.home() / "pCloudDrive" / "Library" / "Books"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "rofi-books"
COVERS = CACHE / "covers"
RECENT = CACHE / "recent"
LOCK = CACHE / "covers.lock"
RECENT_LIMIT = 20
COVER_WIDTH = 160

# Book extensions, longest-match first so ".fb2.zip" wins over ".fb2".
EXTENSIONS = [".pdf", ".epub", ".fb2.zip", ".fb2", ".mobi", ".azw3", ".cbz", ".djvu"]

READERS = {
    ".pdf": ["zathura"],
    ".djvu": ["zathura"],
}
DEFAULT_READER = ["foliate"]

FALLBACK_ICONS = {
    ".pdf": "org.pwmt.zathura",
    ".djvu": "org.pwmt.zathura",
}
DEFAULT_ICON = "com.github.johnfactotum.Foliate"

SEP = "\x1f"


def extension_of(path):
    name = path.name.lower()
    for ext in EXTENSIONS:
        if name.endswith(ext):
            return ext
    return path.suffix.lower()


def stem_of(path, ext):
    return path.name[: -len(ext)] if ext and path.name.lower().endswith(ext) else path.stem


def split_author_title(stem):
    author, sep, title = stem.partition(" - ")
    return (author.strip(), title.strip()) if sep else ("", stem.strip())


# Shelves whose name starts with "_" carry reading status; order them by intent
# rather than alphabetically.
SHELF_RANK = {"_Priority": 0, "_Review": 2, "_Archive": 3}
DEFAULT_SHELF_RANK = 1


def shelf_of(path):
    rel = str(path.parent.relative_to(LIBRARY))
    return "" if rel == "." else rel


def shelf_sort_key(path):
    shelf = shelf_of(path)
    top = shelf.split(os.sep)[0]
    return (SHELF_RANK.get(top, DEFAULT_SHELF_RANK), shelf.lower())


def find_books():
    books = []
    for root, dirs, files in os.walk(LIBRARY):
        dirs.sort()
        for name in sorted(files):
            path = Path(root) / name
            if extension_of(path) in EXTENSIONS:
                books.append(path)
    return books


def read_recent():
    try:
        return [line for line in RECENT.read_text().splitlines() if line]
    except OSError:
        return []


def record_recent(path):
    recent = [p for p in read_recent() if p != str(path)]
    recent.insert(0, str(path))
    CACHE.mkdir(parents=True, exist_ok=True)
    RECENT.write_text("\n".join(recent[:RECENT_LIMIT]) + "\n")


def cover_path(path):
    try:
        stat = path.stat()
        key = f"{path}:{stat.st_mtime_ns}:{stat.st_size}"
    except OSError:
        key = str(path)
    return COVERS / f"{hashlib.sha1(key.encode()).hexdigest()}.png"


def render_cover(path, target):
    """Render page one of a book into target. Returns True on success."""
    import fitz  # PyMuPDF, loaded only by the background pass.

    source = path
    scratch = None
    if extension_of(path) == ".fb2.zip":
        with zipfile.ZipFile(path) as archive:
            inner = next((n for n in archive.namelist() if n.lower().endswith(".fb2")), None)
            if inner is None:
                return False
            scratch = COVERS / f"{target.stem}.fb2"
            scratch.write_bytes(archive.read(inner))
            source = scratch
    try:
        with fitz.open(source) as doc:
            if doc.page_count == 0:
                return False
            page = doc.load_page(0)
            zoom = COVER_WIDTH / max(page.rect.width, 1)
            pixmap = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), alpha=False)
            pixmap.save(target)
        return True
    finally:
        if scratch is not None:
            scratch.unlink(missing_ok=True)


def refresh_covers():
    COVERS.mkdir(parents=True, exist_ok=True)
    lock = LOCK.open("w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return  # Another pass is already rendering.
    live = set()
    for path in find_books():
        target = cover_path(path)
        live.add(target.name)
        if target.exists():
            continue
        try:
            if not render_cover(path, target):
                target.write_bytes(b"")  # Mark as attempted so we stop retrying.
        except Exception:
            target.write_bytes(b"")
    for stale in COVERS.glob("*.png"):
        if stale.name not in live:
            stale.unlink(missing_ok=True)
    fcntl.flock(lock, fcntl.LOCK_UN)


def spawn_detached(argv):
    subprocess.Popen(
        argv,
        start_new_session=True,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def emit(line):
    sys.stdout.write(line + "\n")


def option(key, value):
    """A mode-wide option line: starts with NUL, so rofi reads it as a setting."""
    return f"\0{key}{SEP}{value}"


def row(text, **options):
    """A row: the text, then one NUL and the options joined by the separator."""
    if not options:
        return text
    fields = SEP.join(f"{key.replace('_', '-')}{SEP}{value}" for key, value in options.items())
    return f"{text}\0{fields}"


def print_list():
    emit(option("prompt", "Books"))
    emit(option("markup-rows", "true"))
    emit(option("no-custom", "true"))

    if not LIBRARY.is_dir():
        emit(row("pCloud library not mounted", nonselectable="true"))
        return

    books = find_books()
    order = {path: index for index, path in enumerate(read_recent())}
    books.sort(key=lambda p: (order.get(str(p), len(order)), shelf_sort_key(p), p.name.lower()))

    missing_covers = False
    for path in books:
        ext = extension_of(path)
        author, title = split_author_title(stem_of(path, ext))
        shelf = shelf_of(path).replace("_", "")
        cover = cover_path(path)
        if cover.exists():
            icon = str(cover) if cover.stat().st_size else FALLBACK_ICONS.get(ext, DEFAULT_ICON)
        else:
            icon = FALLBACK_ICONS.get(ext, DEFAULT_ICON)
            missing_covers = True

        detail = " · ".join(filter(None, [author, shelf, ext.lstrip(".")]))
        display = f"{html.escape(title)}   <span alpha='55%'>{html.escape(detail)}</span>"
        emit(row(
            f"{title} — {detail}",
            display=display,
            icon=icon,
            info=str(path),
            active="true" if str(path) in order else "false",
        ))

    if missing_covers:
        spawn_detached(["nice", "-n", "19", sys.argv[0], "--covers"])


def open_book(path):
    ext = extension_of(Path(path))
    reader = READERS.get(ext, DEFAULT_READER)
    try:
        spawn_detached(reader + [path])
    except FileNotFoundError:
        spawn_detached(["xdg-open", path])
    record_recent(path)


def main():
    if "--covers" in sys.argv[1:]:
        refresh_covers()
        return

    selected = os.environ.get("ROFI_INFO")
    if os.environ.get("ROFI_RETV") == "1" and selected:
        open_book(selected)
        return  # No output: rofi closes.

    print_list()


if __name__ == "__main__":
    main()
