#!/usr/bin/env python3
"""Launcher providers. Private data stays in memory/local state; JSON stdio UI transport.

No user command evaluation: only catalog IDs and explicit, allowlisted actions.
Slow filesystem/desktop operations run off the GLib thread. Search lives in QML.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import threading
import time

import gi
gi.require_version("Gio", "2.0")
gi.require_version("GioUnix", "2.0")
from gi.repository import Gio, GioUnix, GLib

EXTENSIONS = (".fb2.zip", ".pdf", ".epub", ".fb2", ".mobi", ".azw3", ".cbz", ".djvu")
COVER_CACHE_VERSION = 2
PROFILES = {"low-power": "Low power", "quiet": "Quiet", "balanced": "Balanced", "performance": "Performance"}
PROFILE_PATH = Path("/sys/firmware/acpi/platform_profile")
KEEP_AWAKE = "quickshell-keep-awake.service"
INHIBITOR = "quickshell-keep-awake"


def run(argv, **kwargs):
    return subprocess.run(argv, stdin=subprocess.DEVNULL, capture_output=True, timeout=kwargs.pop("timeout", 5), **kwargs)


def book_extension(path):
    return next((ext for ext in EXTENSIONS if str(path).lower().endswith(ext)), "")


def book_record(path, library, covers):
    ext = book_extension(path)
    if not ext:
        return None
    stat = path.stat()
    key = hashlib.sha256(os.fsencode(path)).hexdigest()
    cover_key = hashlib.sha256(os.fsencode(f"{COVER_CACHE_VERSION}:{path}:{stat.st_mtime_ns}:{stat.st_size}")).hexdigest()
    cover = covers / f"{cover_key}.png"
    stem = path.name[:-len(ext)]
    author, sep, title = stem.partition(" - ")
    if not sep:
        author, title = "", stem
    shelf = str(path.parent.relative_to(library))
    if shelf == ".":
        shelf = ""
    row = {"id": "book:" + key, "title": title.strip(),
           "detail": " · ".join(filter(None, (author.strip(), shelf.replace("_", ""), ext.lstrip(".")))),
           "icon": "org.pwmt.zathura" if ext in (".pdf", ".djvu") else "com.github.johnfactotum.Foliate",
           "cover": cover.as_uri() if cover.exists() else "", "keywords": shelf}
    rank = {"_Priority": 0, "_Review": 2, "_Archive": 3}.get(shelf.split(os.sep)[0], 1)
    return {"row": row, "path": path, "cover": cover, "order": (rank, shelf.casefold(), title.casefold())}


def clipboard_rows(data):
    rows = []
    for line in data.splitlines():
        number, sep, preview = line.partition("\t")
        if sep and number.isascii() and number.isdecimal():
            image = "[[ binary data" in preview
            rows.append({"id": "clip:" + number, "title": preview,
                         "detail": "", "clipboardKind": "image" if image else "text"})
    return rows


def shortcut_rows(binds):
    grouped = {}
    for bind in binds:
        if not bind.get("has_description") or bind.get("mouse"):
            continue
        keys = [label for mask, label in ((64, "Super"), (4, "Ctrl"), (8, "Alt"), (1, "Shift")) if bind.get("modmask", 0) & mask]
        keys.append({"slash": "/", "Return": "Enter"}.get(bind.get("key"), bind.get("key", "")))
        grouped.setdefault(bind["description"], []).append(" + ".join(keys))
    return [{"id": "shortcut:" + description, "title": description,
             "detail": ", ".join(keys), "icon": "preferences-desktop-keyboard-shortcuts"}
            for description, keys in grouped.items()]


def focused_window(address):
    if not re.fullmatch(r"0x[0-9a-fA-F]+", address or ""):
        return None
    # Bounded, action-only wait for the compositor to restore the previous focus.
    for _ in range(20):
        result = run(["hyprctl", "-j", "activewindow"])
        if result.returncode == 0:
            window = json.loads(result.stdout or b"{}")
            if window.get("address") == address:
                return window
        time.sleep(0.02)
    return None


def kitty_window(window):
    if any(window.get(field, "").lower() in {"kitty", "net.kovidgoyal.kitty"}
            for field in ("class", "initialClass")):
        return True
    # Custom Kitty app IDs (for example, book terminals) still use Kitty paste.
    try:
        return Path(f"/proc/{window.get('pid', 0)}/comm").read_text().strip() == "kitty"
    except OSError:
        return False


def copy_clipboard(number):
    if not re.fullmatch(r"[0-9]+", number):
        raise ValueError("Invalid clipboard entry")
    # Preserve binary bytes and MIME inference; never decode through Unicode/QML.
    data = run(["cliphist", "decode", number], timeout=10)
    if data.returncode:
        raise RuntimeError("Clipboard entry is no longer available")
    # The forked clipboard owner inherits stderr. A captured pipe would keep
    # communicate() waiting until the selection is replaced, despite success.
    copied = subprocess.run(["wl-copy"], input=data.stdout, stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL, timeout=5)
    if copied.returncode:
        raise RuntimeError("Could not copy the selected item")


class Backend:
    def __init__(self, emit, loop):
        self.emit, self.loop = emit, loop
        self.visible = False
        self.category = "apps"
        self.rows, self.messages, self.loading = {}, {}, set()
        self.apps, self.books = {}, {}
        self.book_dirs, self.book_monitors = set(), {}
        self.book_pending, self.book_busy, self.book_timer = set(), False, 0
        self.book_loaded = False
        self.library = Path(os.environ.get("QS_BOOK_LIBRARY", str(Path.home() / "pCloudDrive/Library/Books")))
        self.cache = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "quickshell/launcher"
        self.covers = self.cache / "covers"
        self.state_path = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "quickshell/launcher.json"
        try:
            self.usage = json.loads(self.state_path.read_text())
            if not isinstance(self.usage, dict): self.usage = {}
        except (OSError, ValueError):
            self.usage = {}
        self.cover_queue, self.cover_busy = [], False
        self.widget_busy = False
        self.profile_fd = None
        self.widget_timer = 0
        self.widgets_loaded = False
        self.clip_monitor = None
        self.clip_timer = 0
        self.system_bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        self.user_bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.system_bus.signal_subscribe("org.freedesktop.login1", "org.freedesktop.DBus.Properties",
            "PropertiesChanged", "/org/freedesktop/login1", None, Gio.DBusSignalFlags.NONE,
            self.system_changed)
        self.system_bus.signal_subscribe("org.freedesktop.login1", "org.freedesktop.login1.Manager",
            "PrepareForSleep", "/org/freedesktop/login1", None, Gio.DBusSignalFlags.NONE,
            self.resume)
        self.user_bus.signal_subscribe("org.freedesktop.systemd1", "org.freedesktop.DBus.Properties",
            "PropertiesChanged", None, None, Gio.DBusSignalFlags.NONE, self.unit_changed)
        # systemd emits unit property signals only for subscribed clients.
        try:
            self.user_bus.call_sync("org.freedesktop.systemd1", "/org/freedesktop/systemd1",
                "org.freedesktop.systemd1.Manager", "Subscribe", None, None, Gio.DBusCallFlags.NONE, 2000, None)
        except GLib.Error:
            pass
        self.app_monitor = Gio.AppInfoMonitor.get()
        self.app_timer = 0
        self.app_monitor.connect("changed", self.apps_changed)
        self.load_apps()

    def background(self, work, done, error=None):
        def thread():
            try:
                value = work()
            except Exception as exception:
                # Only deliberate user messages cross the transport, never an
                # OS exception containing a private filename/command argument.
                message = str(exception) if isinstance(exception, RuntimeError) else "This action could not be completed."
                GLib.idle_add(lambda message=message: error(message) if error else self.fail(message))
            else:
                GLib.idle_add(lambda: (done(value), GLib.SOURCE_REMOVE)[1])
        threading.Thread(target=thread, daemon=True).start()

    def publish(self, category):
        rows = []
        for original in self.rows.get(category, []):
            row = dict(original)
            usage = self.usage.get(row["id"], {})
            if isinstance(usage, dict):
                age = max(0, time.time() - usage.get("last", 0)) / 86400
                row["usage"] = min(8, usage.get("count", 0)) + max(0, 8 - age)
            rows.append(row)
        if category in ("apps", "shortcuts"):
            rows.sort(key=lambda row: (-row.get("usage", 0), row["title"].casefold()))
        elif category == "books":
            rows.sort(key=lambda row: -self.usage.get(row["id"], {}).get("last", 0))
        self.emit({"type": "catalog", "category": category, "rows": rows,
                   "loading": category in self.loading, "message": self.messages.get(category, "")})

    def fail(self, message):
        self.emit({"type": "error", "message": message})
        return GLib.SOURCE_REMOVE

    def remember(self, identity):
        old = self.usage.get(identity, {})
        self.usage[identity] = {"count": min(old.get("count", 0) + 1, 10000), "last": time.time()}
        # Bound local history and keep it outside the repository.
        self.usage = dict(sorted(self.usage.items(), key=lambda pair: pair[1].get("last", 0), reverse=True)[:2000])
        try:
            self.state_path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            temporary = self.state_path.with_suffix(".tmp")
            fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(fd, "w") as output:
                json.dump(self.usage, output)
            temporary.replace(self.state_path)
        except OSError:
            pass  # Failure to store ranking must not turn a successful launch into an error.

    def apps_changed(self, *_args):
        if not self.app_timer:
            self.app_timer = GLib.timeout_add(120, self.load_apps)

    def load_apps(self):
        self.app_timer = 0
        apps, rows = {}, []
        for app in Gio.AppInfo.get_all():
            if not app.should_show() or not app.get_id():
                continue
            identity = "app:" + app.get_id()
            apps[identity] = app
            icon = app.get_icon()
            if isinstance(icon, Gio.ThemedIcon):
                icon = icon.get_names()[0] if icon.get_names() else ""
            elif isinstance(icon, Gio.FileIcon):
                icon = icon.get_file().get_path() or ""
            else:
                icon = ""
            keywords = " ".join(app.get_keywords() or []) if hasattr(app, "get_keywords") else ""
            rows.append({"id": identity, "title": app.get_display_name() or app.get_name(),
                         "detail": app.get_description() or "", "icon": icon,
                         "keywords": " ".join((keywords, app.get_executable() or "", app.get_id()))})
        self.apps, self.rows["apps"] = apps, rows
        self.publish("apps")
        return GLib.SOURCE_REMOVE

    def refresh_books(self):
        self.book_timer = 0
        if self.book_busy:
            return GLib.SOURCE_REMOVE
        initial = not self.book_loaded
        pending = self.book_pending or {self.library}
        self.book_pending = set()
        known_dirs = set(self.book_dirs)
        old_records = dict(self.books)
        self.book_busy = True
        self.loading.add("books")
        self.publish("books")
        def scan():
            records = {} if initial else old_records
            directories = set() if initial else known_dirs
            if not self.library.is_dir():
                return {}, set(), "Book library is unavailable. Mount it, then refresh."
            for root in pending:
                if not root.is_dir():
                    records = {key: item for key, item in records.items() if not item["path"].is_relative_to(root)}
                    directories = {path for path in directories if not path.is_relative_to(root)}
                    continue
                # Only new subtrees recurse; ordinary file changes rescan one directory.
                roots = []
                if initial or root not in known_dirs:
                    roots = [Path(directory) for directory, _, _ in os.walk(root)]
                else:
                    roots = [root]
                    for entry in root.iterdir():
                        if entry.is_dir() and entry not in known_dirs:
                            roots.extend(Path(directory) for directory, _, _ in os.walk(entry))
                    missing = [path for path in directories if path.parent == root and not path.is_dir()]
                    for removed in missing:
                        records = {key: item for key, item in records.items() if not item["path"].is_relative_to(removed)}
                        directories = {path for path in directories if not path.is_relative_to(removed)}
                for directory in roots:
                    records = {key: item for key, item in records.items() if item["path"].parent != directory}
                    directories.add(directory)
                    for path in directory.iterdir():
                        if book_extension(path) and path.is_file():
                            try:
                                item = book_record(path, self.library, self.covers)
                                records[item["row"]["id"]] = item
                            except OSError:
                                continue
            return records, directories, ""
        def done(result):
            records, directories, message = result
            self.books, self.book_dirs = records, directories
            if initial:
                # Import existing book recency locally, without importing Rofi
                # implementation or exposing filenames through the transport.
                legacy = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "rofi-books/recent"
                try:
                    recent = legacy.read_text().splitlines()[:20]
                    for index, path in enumerate(recent):
                        identity = "book:" + hashlib.sha256(os.fsencode(path)).hexdigest()
                        if identity in records and identity not in self.usage:
                            self.usage[identity] = {"count": 1, "last": time.time() - index - 1}
                except OSError:
                    pass
            self.book_busy = False
            self.book_loaded = True
            self.loading.discard("books")
            self.messages["books"] = message
            self.rows["books"] = [item["row"] for item in sorted(records.values(), key=lambda item: item["order"])]
            self.watch_books(directories)
            self.publish("books")
            if self.book_pending:
                self.schedule_books()
        def error(_message=None):
            self.book_busy = False
            self.loading.discard("books")
            self.messages["books"] = "Could not read the book library. Refresh to retry."
            self.publish("books")
        self.background(scan, done, error)
        return GLib.SOURCE_REMOVE

    def schedule_books(self):
        if not self.book_timer:
            self.book_timer = GLib.timeout_add(250, self.refresh_books)

    def watch_books(self, directories):
        # Watch the library's parent as well, so unmount/rename is noticed.
        wanted = set(directories) | {self.library.parent}
        for path in set(self.book_monitors) - wanted:
            self.book_monitors.pop(path).cancel()
        for path in wanted - set(self.book_monitors):
            try:
                monitor = Gio.File.new_for_path(str(path)).monitor_directory(Gio.FileMonitorFlags.WATCH_MOVES, None)
                def changed(_monitor, file, _other, _event, directory=path):
                    if directory == self.library.parent and Path(file.get_path()) != self.library:
                        return
                    self.book_pending.add(self.library if directory == self.library.parent else directory)
                    self.schedule_books()
                monitor.connect("changed", changed)
                self.book_monitors[path] = monitor
            except GLib.Error:
                pass

    def request_covers(self, identities):
        self.cover_queue = [identity for identity in identities[:24] if identity in self.books
                            and not self.books[identity]["cover"].exists()
                            and not self.books[identity]["cover"].with_suffix(".failed").exists()]
        self.next_cover()

    def next_cover(self):
        if self.cover_busy or not self.visible or self.category != "books" or not self.cover_queue:
            return
        identity = self.cover_queue.pop(0)
        item = self.books.get(identity)
        if not item: return self.next_cover()
        self.cover_busy = True
        def render():
            self.covers.mkdir(parents=True, exist_ok=True, mode=0o700)
            result = run(["nice", "-n", "19", sys.executable, __file__, "--cover", str(item["path"]), str(item["cover"])], timeout=8)
            return result.returncode == 0 and item["cover"].exists()
        def done(success):
            self.cover_busy = False
            if success and self.books.get(identity) is item:
                item["row"]["cover"] = item["cover"].as_uri()
                self.emit({"type": "cover", "id": identity, "source": item["row"]["cover"]})
            elif not success:
                item["cover"].with_suffix(".failed").touch()
            self.next_cover()
        self.background(render, done, lambda _message: done(False))

    def load_clipboard(self):
        if "clipboard" in self.loading: return
        self.loading.add("clipboard")
        self.publish("clipboard")
        def work():
            result = run(["cliphist", "list"], timeout=8)
            if result.returncode: raise RuntimeError()
            return clipboard_rows(result.stdout.decode("utf-8", errors="replace"))
        def done(rows):
            self.loading.discard("clipboard")
            self.rows["clipboard"] = rows
            self.messages["clipboard"] = ""
            self.publish("clipboard")
        def error(_message=None):
            self.loading.discard("clipboard")
            self.messages["clipboard"] = "Clipboard history is unavailable."
            self.publish("clipboard")
        self.background(work, done, error)
        if self.clip_monitor is None:
            location = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "cliphist"
            try:
                self.clip_monitor = Gio.File.new_for_path(str(location)).monitor_directory(Gio.FileMonitorFlags.NONE, None)
                self.clip_monitor.connect("changed", self.clip_changed)
            except GLib.Error:
                pass

    def clip_changed(self, *_args):
        if self.visible and self.category == "clipboard" and not self.clip_timer:
            def refresh():
                self.clip_timer = 0
                if self.visible and self.category == "clipboard": self.load_clipboard()
                return GLib.SOURCE_REMOVE
            self.clip_timer = GLib.timeout_add(100, refresh)

    def load_shortcuts(self):
        def work():
            result = run(["hyprctl", "-j", "binds"])
            if result.returncode: raise RuntimeError()
            return shortcut_rows(json.loads(result.stdout))
        def done(rows):
            self.rows["shortcuts"] = rows
            self.messages["shortcuts"] = ""
            self.publish("shortcuts")
        self.background(work, done, lambda _message: self.fail("Could not read Hyprland shortcuts."))

    def login_call(self, method, signature=None, args=()):
        return self.system_bus.call_sync("org.freedesktop.login1", "/org/freedesktop/login1",
            "org.freedesktop.login1.Manager", method, GLib.Variant(signature, args) if signature else None,
            None, Gio.DBusCallFlags.NONE, 2000, None).unpack()

    def load_power(self):
        def work():
            rows = []
            for identity, title, icon, method in (
                ("lock", "Lock screen", "system-lock-screen", None),
                ("suspend", "Suspend", "system-suspend", "CanSuspend"),
                ("hibernate", "Hibernate", "system-hibernate", "CanHibernate"),
                ("logout", "Log out", "system-log-out", None),
                ("reboot", "Restart", "system-reboot", "CanReboot"),
                ("shutdown", "Shut down", "system-shutdown", "CanPowerOff")):
                enabled = True
                if method:
                    try: enabled = self.login_call(method)[0] in ("yes", "challenge")
                    except GLib.Error: enabled = False
                # A lock request with no locker would silently do nothing.
                if identity == "lock":
                    enabled = any(shutil.which(name) for name in ("hyprlock", "swaylock", "gtklock", "waylock"))
                detail = "" if enabled else ("Screen locker is not configured" if identity == "lock" else "Unavailable on this system")
                rows.append({"id": "power:" + identity, "title": title, "icon": icon,
                             "detail": detail, "enabled": enabled, "danger": identity in ("logout", "reboot", "shutdown")})
            return rows
        def done(rows):
            self.rows["power"] = rows
            self.publish("power")
        self.background(work, done)

    def system_changed(self, *_args):
        self.schedule_widgets()

    def unit_changed(self, _bus, _sender, path, *_args):
        if "quickshell_2dkeep_2dawake" in path:
            self.schedule_widgets()

    def resume(self, _bus, _sender, _path, _interface, _signal, parameters):
        if not parameters.unpack()[0]: self.schedule_widgets()

    def schedule_widgets(self):
        if self.widgets_loaded and not self.widget_timer:
            self.widget_timer = GLib.timeout_add(80, self.load_widgets)

    def load_widgets(self):
        self.widget_timer = 0
        self.widgets_loaded = True
        if self.profile_fd is None:
            try:
                self.profile_fd = os.open(PROFILE_PATH, os.O_RDONLY | os.O_NONBLOCK)
                os.read(self.profile_fd, 1024)
                def changed(fd, condition):
                    try:
                        os.lseek(fd, 0, os.SEEK_SET)
                        os.read(fd, 1024)
                        self.schedule_widgets()
                        return GLib.SOURCE_CONTINUE
                    except OSError:
                        self.profile_fd = None
                        return GLib.SOURCE_REMOVE
                GLib.io_add_watch(self.profile_fd, GLib.IO_PRI | GLib.IO_ERR, changed)
            except OSError:
                pass
        def work():
            try:
                choices = PROFILE_PATH.with_name("platform_profile_choices").read_text().split()
                current = PROFILE_PATH.read_text().strip()
            except OSError:
                choices, current = [], ""
            try:
                leases = self.login_call("ListInhibitors")[0]
                idle = [lease for lease in leases if "idle" in lease[0].split(":") and lease[3] == "block"]
                ours = any(lease[1] == INHIBITOR and lease[4] == os.getuid() for lease in idle)
                other = any(lease[1] != INHIBITOR or lease[4] != os.getuid() for lease in idle)
                known = True
            except GLib.Error:
                ours, other, known = False, False, False
            rows = [{"id": "profile:" + value, "title": label, "detail": "Power profile",
                     "icon": "power-profile-" + ("power-saver" if value in ("low-power", "quiet") else value),
                     "selected": value == current, "enabled": not self.widget_busy}
                    for value, label in PROFILES.items() if value in choices]
            for mode, title, detail, selected in (
                ("auto", "Sleep after 25 min", "Suspend after 25 minutes of inactivity.", not ours),
                ("awake", "Stay awake", "Pause automatic sleep until you switch back or log out.", ours),
            ):
                rows.append({"id": "idle:" + mode, "title": title, "detail": detail,
                             "selected": known and selected, "known": known,
                             "blockedByOther": other, "enabled": known and not self.widget_busy})
            return rows
        def done(rows):
            self.rows["widgets"] = rows
            self.publish("widgets")
        self.background(work, done)
        return GLib.SOURCE_REMOVE

    def activate(self, command):
        identity = command.get("id", "")
        category = command.get("category", "")
        row = next((row for row in self.rows.get(category, []) if row["id"] == identity), None)
        if not row or row.get("enabled") is False:
            return self.fail("This item is no longer available.")
        if category == "widgets":
            if self.widget_busy: return
            self.widget_busy = True
            self.messages["widgets"] = "Applying…"
            self.load_widgets()
        def work():
            if category == "apps":
                if identity not in self.apps or not self.apps[identity].launch([], None):
                    raise RuntimeError("Could not launch this app")
            elif category == "books":
                book = self.books.get(identity)
                if not book or not book["path"].is_file():
                    raise RuntimeError("This book is no longer available")
                reader = "zathura" if book_extension(book["path"]) in (".pdf", ".djvu") else "foliate"
                subprocess.Popen([shutil.which(reader) or "xdg-open", str(book["path"])],
                    stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            elif category == "clipboard":
                copy_clipboard(identity.removeprefix("clip:"))
                if command.get("paste"):
                    address = command.get("target", "")
                    window = focused_window(address)
                    if not window:
                        raise RuntimeError("Copied. Previous window is unavailable for paste.")
                    # Ctrl+V reaches the TUI (Codex uses it for image paste).
                    # Text must use Kitty's own clipboard paste binding instead.
                    modifiers = "CTRL SHIFT" if row.get("clipboardKind") == "text" and kitty_window(window) else "CTRL"
                    selector = json.dumps("address:" + address)
                    code = 'hl.dispatch(hl.dsp.send_shortcut({mods="' + modifiers + '",key="v",window=' + selector + '}))'
                    if run(["hyprctl", "eval", code]).returncode:
                        raise RuntimeError("Copied, but could not paste into the previous window.")
            elif category == "shortcuts":
                address = command.get("target", "")
                if address and not focused_window(address):
                    raise RuntimeError("Previous window is no longer focused. Try the shortcut again.")
                description = identity.removeprefix("shortcut:")
                code = "assert(shortcuts[" + json.dumps(description, ensure_ascii=False) + "], 'Shortcut changed'); hl.dispatch(shortcuts[" + json.dumps(description, ensure_ascii=False) + "])"
                if run(["hyprctl", "eval", code]).returncode:
                    raise RuntimeError("Could not run this shortcut")
            elif category == "power":
                action = identity.removeprefix("power:")
                if action == "lock":
                    locker = next((shutil.which(name) for name in ("hyprlock", "swaylock", "gtklock", "waylock") if shutil.which(name)), None)
                    argv = [locker] if locker else None
                elif action == "logout":
                    session = os.environ.get("XDG_SESSION_ID")
                    argv = ["loginctl", "terminate-session", session] if session else None
                else:
                    verb = {"suspend": "suspend", "hibernate": "hibernate", "reboot": "reboot", "shutdown": "poweroff"}.get(action)
                    argv = ["systemctl", verb] if verb else None
                if not argv: raise RuntimeError("Action is unavailable")
                subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL, start_new_session=True)
            elif category == "widgets":
                if identity.startswith("profile:"):
                    value = identity.removeprefix("profile:")
                    if value not in PROFILES: raise RuntimeError("Invalid power profile")
                    if value != PROFILE_PATH.read_text().strip():
                        result = run(["pkexec", "--disable-internal-agent", "/usr/local/libexec/ags-set-power-profile", value], timeout=90)
                        if result.returncode: raise RuntimeError("Could not change power profile. Authorization may have been cancelled.")
                    if PROFILE_PATH.read_text().strip() != value:
                        raise RuntimeError("Firmware did not apply this power profile")
                elif identity in ("idle:auto", "idle:awake"):
                    # Explicit choices are idempotent, including repeated or
                    # delayed activation of an already selected mode.
                    verb = "start" if identity == "idle:awake" else "stop"
                    if run(["systemctl", "--user", verb, KEEP_AWAKE]).returncode:
                        raise RuntimeError("Could not change Keep awake. Check the graphical session service.")
                    # Wait briefly for inhibitor acquisition, not merely systemd's Exec state.
                    for _ in range(20):
                        leases = self.login_call("ListInhibitors")[0]
                        acquired = any(lease[1] == INHIBITOR and lease[4] == os.getuid() for lease in leases)
                        if acquired == (verb == "start"): break
                        time.sleep(0.025)
                    else: raise RuntimeError("Keep awake did not reach the requested state")
            else:
                raise RuntimeError("Unknown action")
        def done(_result):
            if category in ("apps", "books", "shortcuts"):
                self.remember(identity)
                self.publish(category)
            if category == "widgets":
                self.widget_busy = False
                self.messages["widgets"] = ""
                self.load_widgets()
            self.emit({"type": "activated", "id": identity})
        def error(message="Could not apply the change."):
            if category == "widgets":
                self.widget_busy = False
                self.messages["widgets"] = message
                self.load_widgets()
            else:
                self.fail(message)
        self.background(work, done, error)

    def command(self, command):
        action = command.get("action")
        if action == "show":
            category = command.get("category", "apps")
            if category not in ("apps", "books", "widgets", "shortcuts", "clipboard", "power"): return
            self.visible, self.category = True, category
            self.messages[category] = ""
            # Apps is already published at startup, on desktop catalog changes
            # and after usage changes. Reopening must not replace its QML model
            # and recreate delegates/icons for an unchanged catalog.
            if category != "apps":
                self.publish(category)
            if category == "books" and not self.book_loaded: self.refresh_books()
            elif category == "clipboard": self.load_clipboard()
            elif category == "shortcuts": self.load_shortcuts()
            elif category == "power": self.load_power()
            elif category == "widgets": self.load_widgets()
        elif action == "hide":
            self.visible = False
            self.cover_queue = []
        elif action == "covers" and self.visible and self.category == "books":
            self.request_covers(command.get("ids", []))
        elif action == "activate":
            self.activate(command)
        elif action == "refresh":
            if self.category == "apps":
                self.load_apps()
            elif self.category == "books":
                self.book_loaded = False
                self.book_pending = {self.library}
                self.refresh_books()
            else:
                self.command({"action": "show", "category": self.category})


def render_cover(source, target):
    import base64
    import pymupdf as fitz
    import xml.etree.ElementTree as ET
    import zipfile
    if book_extension(source) in (".fb2", ".fb2.zip"):
        if book_extension(source) == ".fb2.zip":
            with zipfile.ZipFile(source) as archive:
                info = next(info for info in archive.infolist() if info.filename.lower().endswith(".fb2"))
                if info.file_size > 32 * 1024 * 1024: raise ValueError("Cover source too large")
                data = archive.read(info)
        else:
            if Path(source).stat().st_size > 32 * 1024 * 1024: raise ValueError("Cover source too large")
            data = Path(source).read_bytes()
        # FB2 layout may start with a blank page even when it embeds a cover.
        root = ET.fromstring(data)
        image = root.find("./{*}description/{*}title-info/{*}coverpage/{*}image")
        href = image.get("{http://www.w3.org/1999/xlink}href", "") if image is not None else ""
        binary = next((node for node in root.findall("./{*}binary")
                       if href.startswith("#") and node.get("id") == href[1:]), None)
        document = None
        if binary is not None:
            try:
                document = fitz.open(stream=base64.b64decode(binary.text or ""))
            except (ValueError, RuntimeError):
                pass
        if document is None:
            document = fitz.open(stream=data, filetype="fb2")
    else:
        document = fitz.open(source)
    with document:
        page = document.load_page(0)
        zoom = 120 / max(page.rect.width, 1)
        # Bound pathological page aspect ratios and memory consumption.
        if page.rect.height * zoom > 240: zoom = 240 / page.rect.height
        pixmap = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), alpha=False)
        if pixmap.color_topusage()[0] == 1:
            raise ValueError("Blank cover; use the book icon instead")
        temporary = str(target) + ".tmp.png"
        pixmap.save(temporary)
        os.replace(temporary, target)


def main():
    if len(sys.argv) == 4 and sys.argv[1] == "--cover":
        try: render_cover(sys.argv[2], sys.argv[3])
        except Exception: raise SystemExit(1)
        return
    loop = GLib.MainLoop()
    def emit(value):
        try: print(json.dumps(value, ensure_ascii=True), flush=True)
        except BrokenPipeError: loop.quit()
    backend = Backend(emit, loop)
    os.set_blocking(sys.stdin.fileno(), False)
    buffer = bytearray()
    def receive(fd, condition):
        nonlocal buffer
        chunk = os.read(fd, 65536)
        if not chunk:
            loop.quit()
            return GLib.SOURCE_REMOVE
        buffer.extend(chunk)
        while b"\n" in buffer:
            line, _, buffer = buffer.partition(b"\n")
            try:
                message = json.loads(line)
                if isinstance(message, dict): backend.command(message)
            except (ValueError, TypeError, GLib.Error):
                backend.fail("Invalid launcher request.")
        return GLib.SOURCE_CONTINUE
    GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP, receive)
    loop.run()


if __name__ == "__main__":
    main()
