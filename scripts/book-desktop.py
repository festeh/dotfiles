#!/usr/bin/env python3
"""A reversible, config-driven pair of reading and Codex workspaces."""

import argparse
import fcntl
import filecmp
import hashlib
import json
import os
from pathlib import Path
import re
import select
import shlex
import shutil
import sqlite3
import subprocess
import sys
import time
import tomllib
import zipfile
from xml.etree import ElementTree

CONFIG = Path(os.environ.get("BOOK_DESKTOP_CONFIG", "~/.config/book-desktop/books.toml")).expanduser()
STATE = Path(os.environ.get("XDG_STATE_HOME", "~/.local/state")).expanduser() / "book-desktop"
CODEX_HOME = Path(os.environ.get("CODEX_HOME", "~/.codex")).expanduser()


def atomic(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(text)
    temporary.replace(path)


def lua(value):
    if isinstance(value, int):
        return str(value)
    return '"' + "".join("\\" + c if c in '\\"' else f"\\{ord(c):03}" if ord(c) < 32 else c for c in str(value)) + '"'


def hypr(*args, as_json=False):
    result = subprocess.run(["hyprctl", *( ["-j"] if as_json else []), *args], capture_output=True, text=True, check=True)
    if as_json:
        return json.loads(result.stdout)
    if result.stdout.strip() not in ("ok", "") and args[0] in ("dispatch", "eval", "reload"):
        raise RuntimeError(result.stdout.strip())
    return result.stdout


def dispatch(expression):
    hypr("dispatch", expression)


def load_config():
    config = {"root": "~/tmp/books", "codex_workspace": 11, "books_workspace": 12, "books": []}
    if CONFIG.exists():
        config.update(tomllib.loads(CONFIG.read_text()))
    if config["books_workspace"] != config["codex_workspace"] + 1 or config["codex_workspace"] < 1:
        raise ValueError("The books workspace must immediately follow the positive Codex workspace.")
    return config


def selected_book(config, source=None):
    # Keep existing folders, reader settings and conversations for configured books.
    legacy = config["books"]
    selection = STATE / "selected.json"
    if source is None:
        if selection.exists():
            source = json.loads(selection.read_text())
        elif legacy:
            active = STATE / "active"
            previous = active.read_text().strip() if active.exists() else None
            source = next((b for b in legacy if b["id"] == previous), legacy[0])["source"]
        else:
            return None
    path = Path(source).expanduser().absolute()
    if not path.name.lower().endswith((".pdf", ".djvu", ".epub", ".fb2", ".fb2.zip", ".mobi", ".azw3", ".cbz")):
        raise ValueError("Unsupported book format.")
    book = next((b.copy() for b in legacy if Path(b["source"]).expanduser().absolute() == path), {})
    if not book:
        reader, app = {
            ".pdf": ("alpha", "alpha"), ".djvu": ("zathura", "org.pwmt.zathura"),
        }.get(path.suffix.lower(), ("foliate", "com.github.johnfactotum.Foliate"))
        book = {"id": "book-" + hashlib.sha256(os.fsencode(path)).hexdigest(),
                "title": path.name[:-8] if path.name.lower().endswith(".fb2.zip") else path.stem,
                "reader": [reader], "reader_class": app}
    if not re.fullmatch(r"[a-z0-9-]+", book["id"]):
        raise ValueError("Invalid book ID in settings.")
    book["source"] = path
    book["folder"] = Path(config["root"]).expanduser().absolute() / book["id"]
    book["file"] = book["folder"] / path.name
    return book


class Codex:
    """Use the installed CLI's documented stdio protocol; never edit its database."""
    def __init__(self):
        self.process = subprocess.Popen(["codex", "app-server", "--stdio"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=0)
        self.buffer = b""
        self.number = 0
        try:
            self.call("initialize", {"clientInfo": {"name": "book_desktop", "version": "1"}, "capabilities": {"experimentalApi": True}})
            self.process.stdin.write(b'{"method":"initialized","params":{}}\n')
        except BaseException:
            self.close()
            raise

    def call(self, method, params):
        self.number += 1
        self.process.stdin.write((json.dumps({"id": self.number, "method": method, "params": params}) + "\n").encode())
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            if b"\n" not in self.buffer:
                if not select.select([self.process.stdout], [], [], 1)[0]:
                    continue
                chunk = os.read(self.process.stdout.fileno(), 65536)
                if not chunk:
                    raise RuntimeError("Codex app-server exited unexpectedly")
                self.buffer += chunk
            while b"\n" in self.buffer:
                line, self.buffer = self.buffer.split(b"\n", 1)
                message = json.loads(line)
                if message.get("id") == self.number:
                    if "error" in message:
                        raise RuntimeError(f"{method}: {message['error']}")
                    return message["result"]
        raise TimeoutError(method)

    def close(self):
        self.process.stdin.close()
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait()


def existing_session(folder):
    database = CODEX_HOME / "state_5.sqlite"
    if not database.exists():
        return None
    with sqlite3.connect(database.as_uri() + "?mode=ro", uri=True) as connection:
        row = connection.execute("SELECT id FROM threads WHERE cwd=? AND archived=0 ORDER BY updated_at DESC LIMIT 1", (str(folder),)).fetchone()
    return row[0] if row else None


def prepare(book):
    folder, target = book["folder"], book["file"]
    folder.mkdir(parents=True, exist_ok=True)
    if not target.exists():
        temporary = target.with_name(target.name + ".copying")
        shutil.copy2(book["source"], temporary)
        temporary.replace(target)
    elif book["source"].exists() and not filecmp.cmp(target, book["source"], shallow=False):
        raise RuntimeError(f"Local book differs from pCloud; preserved it: {target}")
    extract = folder / "book.txt"
    if not extract.exists():
        if target.suffix.lower() == ".pdf":
            temporary = folder / "book.txt.tmp"
            subprocess.run(["pdftotext", "-layout", str(target), str(temporary)], check=True)
            temporary.replace(extract)
        elif target.suffix.lower() == ".fb2" or target.name.lower().endswith(".fb2.zip"):
            if target.suffix.lower() == ".zip":
                with zipfile.ZipFile(target) as archive:
                    name = next((n for n in archive.namelist() if n.lower().endswith(".fb2")), None)
                    if not name:
                        raise ValueError("No FB2 document in the selected archive.")
                    with archive.open(name) as stream:
                        root = ElementTree.parse(stream).getroot()
            else:
                root = ElementTree.parse(target).getroot()
            lines = [" ".join(node.itertext()).strip() for body in root.findall("{*}body")
                     for node in body.iter() if node.tag.rsplit("}", 1)[-1] in ("p", "v", "subtitle")]
            atomic(extract, "\n\n".join(lines) + "\n")
    instructions = folder / "AGENTS.md"
    if not instructions.exists():
        atomic(instructions, f"# Reading companion for {book['title']}\n\n"
               f"The source book is `{target.name}`. "
               + ("Use `book.txt` to search for passages. " if extract.exists() else "")
               + "Ground explanations in the text and cite the chapter or page when useful. "
               "Ask which passage the reader means when needed. Avoid spoilers beyond their position. "
               "Answer concisely in the reader's language.\n" + book.get("note", "") + "\n")
    marker = folder / "session.id"
    session = marker.read_text().strip() if marker.exists() else book.get("existing_session") or existing_session(folder)
    server = Codex()
    try:
        if session:
            thread = server.call("thread/read", {"threadId": session, "includeTurns": False})["thread"]
            if Path(thread["cwd"]) != folder:
                raise RuntimeError("Saved conversation belongs to another folder.")
        else:
            result = server.call("thread/start", {"cwd": str(folder), "ephemeral": False, "threadSource": "cli", "serviceName": "book_desktop"})
            session = result["thread"]["id"]
            server.call("thread/name/set", {"threadId": session, "name": f"Read {book['title']}"})
        atomic(marker, session + "\n")
        return session
    finally:
        server.close()


def read_state():
    path = STATE / "windows.json"
    if path.exists():
        state = json.loads(path.read_text())
        if state.get("instance") and state["instance"] == os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
            return state
    return {}


def save_state(state):
    atomic(STATE / "windows.json", json.dumps(state) + "\n")


def valid(window, clients):
    return next((c for c in clients if c["address"] == window.get("address") and c["pid"] == window.get("pid")), None)


def owned(state):
    # Older installations recorded multiple pairs. Retire those by the same identity checks.
    return [entry[pane] for entry in state.get("windows", [state])
            for pane in ("reader", "codex") if pane in entry]


def close_windows(state):
    windows = owned(state)
    for window in windows:
        if valid(window, hypr("clients", as_json=True)):
            dispatch(f"hl.dsp.window.close({{ window = {lua('address:' + window['address'])} }})")
    deadline = time.monotonic() + 8
    while windows:
        clients = hypr("clients", as_json=True)
        if not any(valid(window, clients) for window in windows):
            return
        if time.monotonic() >= deadline:
            raise RuntimeError("A managed window is still open. Its identity was retained; retry Stop Reading Desktop.")
        time.sleep(0.1)


def enable(state):
    path = STATE / "enabled.lua"
    rules = ("return { instance = " + lua(state["instance"])
             + f", codex_workspace = {state['codex_workspace']}, books_workspace = {state['books_workspace']} }}\n")
    if not path.exists() or path.read_text() != rules:
        atomic(path, rules)
        hypr("reload")
        errors = hypr("configerrors").strip()
        if errors:
            raise RuntimeError(errors)


def launch(argv, workspace, expected_class, title=""):
    before = {client["address"] for client in hypr("clients", as_json=True)}
    hypr("eval", f"hl.exec_cmd({lua(shlex.join(argv))}, {{ workspace = {lua(str(workspace) + ' silent')} }})")
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        for client in hypr("clients", as_json=True):
            if (client["address"] not in before and client["workspace"]["id"] == workspace
                    and client["class"].casefold() == expected_class.casefold() and title.casefold() in client["title"].casefold()):
                return {"address": client["address"], "pid": client["pid"]}
        time.sleep(0.15)
    raise RuntimeError(f"No new {expected_class} window appeared; check the reader or terminal.")


def ensure_window(state, key, workspace, argv, app, title=""):
    window = valid(state.get(key, {}), hypr("clients", as_json=True))
    if not window:
        state[key] = launch(argv, workspace, app, title)
        save_state(state)
    elif window["workspace"]["id"] != workspace:
        dispatch(f"hl.dsp.window.move({{ window = {lua('address:' + window['address'])}, workspace = {workspace}, follow = false }})")


def up(config, state, book, pane):
    chat_ws, read_ws = config["codex_workspace"], config["books_workspace"]
    clients = hypr("clients", as_json=True)
    managed = {(w["address"], w["pid"]) for w in owned(state)}
    for client in clients:
        if client["workspace"]["id"] in (chat_ws, read_ws) and (client["address"], client["pid"]) not in managed:
            raise RuntimeError(f"Workspace {client['workspace']['id']} contains an unrelated window.")
    same_book = state.get("id") == book["id"]
    marker = book["folder"] / "session.id"
    if same_book and marker.exists() and all(valid(state.get(k, {}), clients) for k in ("reader", "codex")):
        session = marker.read_text().strip()
    else:
        session = prepare(book)
    previous = state.get("return_workspace")
    if not state:
        workspace = hypr("activeworkspace", as_json=True)["id"]
        if workspace not in (chat_ws, read_ws):
            previous = workspace
    if not same_book:
        close_windows(state)
        state = {"id": book["id"]}
    state.update(instance=os.environ["HYPRLAND_INSTANCE_SIGNATURE"], return_workspace=previous,
                 codex_workspace=chat_ws, books_workspace=read_ws)
    save_state(state)
    enable(state)
    ensure_window(state, "reader", read_ws, [*book["reader"], str(book["file"])],
                  book["reader_class"], book.get("reader_title", ""))
    window_class = "book-codex-" + book["id"]
    terminal = ["kitty", "--class", window_class, "--override", "confirm_os_window_close=0",
                "--title", book["title"] + " · Codex", "--directory", str(book["folder"]),
                "--", "codex", "resume", "--cd", str(book["folder"]), session]
    ensure_window(state, "codex", chat_ws, terminal, window_class)
    dispatch(f"hl.dsp.focus({{ window = {lua('address:' + state[pane]['address'])} }})")


def down(state):
    active = hypr("activeworkspace", as_json=True)["id"]
    close_windows(state)
    rules = STATE / "enabled.lua"
    if rules.exists() or state:
        rules.unlink(missing_ok=True)
        hypr("reload")
    workspaces = (state.get("codex_workspace", 11), state.get("books_workspace", 12))
    if active in workspaces:
        available = {w["id"] for w in hypr("workspaces", as_json=True) if w["id"] > 0 and w["id"] not in workspaces}
        previous = state.get("return_workspace")
        if available:
            dispatch(f"hl.dsp.focus({{ workspace = {previous if previous in available else min(available)} }})")
    (STATE / "windows.json").unlink(missing_ok=True)
    print("Stopped")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["select", "prepare", "up", "down", "toggle", "status", "read", "chat"])
    parser.add_argument("file", nargs="?")
    args = parser.parse_args()
    if (args.command == "select") != bool(args.file):
        parser.error("select requires a book file; other commands take no file")
    os.umask(0o077)
    STATE.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (STATE / "lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state = read_state()
        command = args.command
        if command == "toggle":
            command = "down" if state else "up"
        if command == "down":
            down(state)
        elif command == "status":
            clients = hypr("clients", as_json=True)
            count = sum(bool(valid(window, clients)) for window in owned(state))
            print("Stopped" if not state else "Running" if count == 2 and "id" in state else "Incomplete")
            print(f"Managed windows open: {count}")
        else:
            config = load_config()
            book = selected_book(config, args.file)
            if book is None:
                if command == "prepare":
                    raise ValueError("Choose a book in the Books widget (Super+B).")
                subprocess.run(["shell-launcher", "books"], check=True)
                return
            if command == "prepare":
                prepare(book)
            else:
                up(config, state, book, "codex" if command == "chat" else "reader")
                atomic(STATE / "selected.json", json.dumps(str(book["source"])) + "\n")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError, sqlite3.Error, zipfile.BadZipFile, ElementTree.ParseError) as error:
        print(f"book-desktop: {error}", file=sys.stderr)
        sys.exit(1)
