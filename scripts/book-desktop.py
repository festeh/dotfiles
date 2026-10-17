#!/usr/bin/env python3
"""A reversible, config-driven pair of reading and Codex workspaces."""

import argparse
import fcntl
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
    config = tomllib.loads(CONFIG.read_text())
    if config["books_workspace"] != config["codex_workspace"] + 1 or config["codex_workspace"] < 1:
        raise ValueError("The books workspace must immediately follow the positive Codex workspace.")
    ids = [book["id"] for book in config["books"]]
    if not ids or len(set(ids)) != len(ids) or any(not re.fullmatch(r"[a-z0-9-]+", value) for value in ids):
        raise ValueError("Book IDs must be unique lowercase slugs.")
    for book in config["books"]:
        book["source"] = Path(book["source"]).expanduser()
        book["folder"] = Path(config["root"]).expanduser() / book["id"]
        book["file"] = book["folder"] / book["source"].name
    return config


class Codex:
    """Use the installed CLI's documented stdio protocol; never edit its database."""
    def __init__(self):
        self.process = subprocess.Popen(["codex", "app-server", "--stdio"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=0)
        self.buffer = b""
        self.number = 0
        self.call("initialize", {"clientInfo": {"name": "book_desktop", "version": "1"}, "capabilities": {"experimentalApi": True}})
        self.process.stdin.write(b'{"method":"initialized","params":{}}\n')

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
        self.process.terminate()
        self.process.wait(timeout=5)


def existing_session(folder):
    database = CODEX_HOME / "state_5.sqlite"
    if not database.exists():
        return None
    with sqlite3.connect(database.as_uri() + "?mode=ro", uri=True) as connection:
        row = connection.execute("SELECT id FROM threads WHERE cwd=? AND archived=0 ORDER BY updated_at DESC LIMIT 1", (str(folder),)).fetchone()
    return row[0] if row else None


def prepare(config):
    server = Codex()
    try:
        for book in config["books"]:
            folder, target = book["folder"], book["file"]
            folder.mkdir(parents=True, exist_ok=True)
            if not target.exists():
                temporary = target.with_name(target.name + ".copying")
                shutil.copy2(book["source"], temporary)
                temporary.replace(target)
            elif book["source"].exists() and hashlib.sha256(target.read_bytes()).digest() != hashlib.sha256(book["source"].read_bytes()).digest():
                raise RuntimeError(f"Local book differs from pCloud; preserved it: {target}")
            instructions = folder / "AGENTS.md"
            if not instructions.exists():
                instructions.write_text(f"# Reading companion: {book['title']}\n\n"
                    f"- The source book is `{target.name}`; `book.txt` is a searchable local extract.\n"
                    "- Read the relevant local passage before explaining it; cite its chapter or PDF page when useful.\n"
                    "- Answer concisely in the user's language, with simple explanations and concrete examples.\n"
                    "- Do not assume the current page; ask for a passage if the reference is ambiguous.\n"
                    "- Avoid spoilers beyond the user's stated reading position.\n"
                    f"- {book['note']}\n")
            extract = folder / "book.txt"
            if not extract.exists():
                if target.suffix.lower() == ".fb2":
                    root = ElementTree.parse(target).getroot()
                    ns = {"f": "http://www.gribuser.ru/xml/fictionbook/2.0"}
                    lines = [" ".join(element.itertext()).strip() for body in root.findall("f:body", ns) for element in body.iter() if element.tag.rsplit("}", 1)[-1] in ("p", "v", "subtitle")]
                    atomic(extract, "\n\n".join(lines) + "\n")
                elif target.suffix.lower() == ".pdf":
                    subprocess.run(["pdftotext", "-layout", str(target), str(extract)], check=True)
            marker = folder / "session.id"
            session = marker.read_text().strip() if marker.exists() else book.get("existing_session") or existing_session(folder)
            if session:
                thread = server.call("thread/read", {"threadId": session, "includeTurns": False})["thread"]
                if Path(thread["cwd"]) != folder:
                    raise RuntimeError(f"Session {session} belongs to {thread['cwd']}, expected {folder}")
            else:
                result = server.call("thread/start", {"cwd": str(folder), "ephemeral": False, "threadSource": "cli", "serviceName": "book_desktop"})
                session = result["thread"]["id"]
                server.call("thread/name/set", {"threadId": session, "name": f"Read {book['title']}"})
            atomic(marker, session + "\n")
            book["session"] = session
            print(f"{book['id']}: {session}", flush=True)
    finally:
        server.close()


def read_state():
    path = STATE / "windows.json"
    return json.loads(path.read_text()) if path.exists() else {"windows": []}


def running():
    return (STATE / "enabled.lua").exists() and read_state().get("instance") == os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")


def save_state(state):
    atomic(STATE / "windows.json", json.dumps(state, indent=2) + "\n")


def valid(window, clients):
    return next((client for client in clients if client["address"] == window.get("address") and client["pid"] == window.get("pid")), None)


def enable(config, state):
    rows = []
    for book in state["windows"]:
        parts = [f"id = {lua(book['id'])}"]
        for pane in ("reader",):
            if pane in book:
                parts.append(f"{pane} = {lua(book[pane]['address'])}")
        rows.append("    { " + ", ".join(parts) + " },")
    atomic(STATE / "enabled.lua", "return {\n" + f"instance = {lua(state['instance'])},\ncodex_workspace = {config['codex_workspace']},\nbooks_workspace = {config['books_workspace']},\nwindows = {{\n" + "\n".join(rows) + "\n},\n}\n")
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
            if client["address"] not in before and client["class"].casefold() == expected_class.casefold() and title.casefold() in client["title"].casefold():
                dispatch(f"hl.dsp.window.move({{ window = {lua('address:' + client['address'])}, workspace = {workspace}, follow = false }})")
                return {"address": client["address"], "pid": client["pid"]}
        time.sleep(0.15)
    raise RuntimeError(f"No new {expected_class} window appeared; check the reader or terminal.")


def focus(config, state, pane):
    active = active_book(config)["id"]
    book = next((book for book in state["windows"] if book["id"] == active), {})
    window = book.get(pane, {})
    if not valid(window, hypr("clients", as_json=True)):
        raise RuntimeError("That book window is closed; run book-desktop up to reopen it.")
    dispatch(f"hl.dsp.focus({{ window = {lua('address:' + window['address'])} }})")


def active_book(config):
    active_file = STATE / "active"
    active = active_file.read_text().strip() if active_file.exists() else config["books"][0]["id"]
    return next((book for book in config["books"] if book["id"] == active), config["books"][0])


def close_window(window):
    if not valid(window, hypr("clients", as_json=True)):
        return
    dispatch(f"hl.dsp.window.close({{ window = {lua('address:' + window['address'])} }})")
    deadline = time.monotonic() + 8
    while valid(window, hypr("clients", as_json=True)):
        if time.monotonic() > deadline:
            raise RuntimeError("The previous Codex terminal is still closing; no second terminal was opened.")
        time.sleep(0.05)


def sync_codex(config, state):
    """Serialize switches and close the previous terminal before resuming another."""
    while True:
        book = active_book(config)
        selected = next((entry for entry in state["windows"] if entry["id"] == book["id"]), None)
        if selected is None:
            raise RuntimeError("The selected reader is not set up; run book-desktop up.")
        clients = hypr("clients", as_json=True)
        for entry in state["windows"]:
            window = entry.get("codex")
            if window is None:
                continue
            if entry is selected and valid(window, clients):
                continue
            close_window(window)
            del entry["codex"]
            save_state(state)

        # A newer reader focus may have arrived while the previous terminal closed.
        if active_book(config)["id"] != book["id"]:
            continue
        current = valid(selected.get("codex", {}), hypr("clients", as_json=True))
        if current is None:
            session = (book["folder"] / "session.id").read_text().strip()
            window_class = "book-codex-" + book["id"]
            argv = ["kitty", "--class", window_class, "--override", "confirm_os_window_close=0", "--title", book["title"] + " · Codex", "--directory", str(book["folder"]), "--", "codex", "resume", "--cd", str(book["folder"]), session]
            selected["codex"] = launch(argv, config["codex_workspace"], window_class)
            save_state(state)
        elif current["workspace"]["id"] != config["codex_workspace"]:
            dispatch(f"hl.dsp.window.move({{ window = {lua('address:' + current['address'])}, workspace = {config['codex_workspace']}, follow = false }})")
        if active_book(config)["id"] == book["id"]:
            return


def up(config):
    prepare(config)
    state = read_state()
    if not running():
        workspace = hypr("activeworkspace", as_json=True)["id"]
        if workspace not in (config["codex_workspace"], config["books_workspace"]):
            state["return_workspace"] = workspace
    state["instance"] = os.environ["HYPRLAND_INSTANCE_SIGNATURE"]
    clients = hypr("clients", as_json=True)
    owned = {(entry[pane]["address"], entry[pane]["pid"]) for entry in state["windows"] for pane in ("reader", "codex") if pane in entry}
    for client in clients:
        if client["workspace"]["id"] in (config["codex_workspace"], config["books_workspace"]) and (client["address"], client["pid"]) not in owned:
            raise RuntimeError(f"Workspace {client['workspace']['id']} contains an unrelated window; choose free workspaces in {CONFIG}.")
    save_state(state)
    enable(config, state)
    try:
        for book in config["books"]:
            entry = next((entry for entry in state["windows"] if entry["id"] == book["id"]), None)
            if entry is None:
                entry = {"id": book["id"]}
                state["windows"].append(entry)
            workspace = config["books_workspace"]
            if not valid(entry.get("reader", {}), hypr("clients", as_json=True)):
                argv = [*book["reader"], str(book["file"])]
                entry["reader"] = launch(argv, workspace, book["reader_class"], book["reader_title"])
                save_state(state)
            else:
                dispatch(f"hl.dsp.window.move({{ window = {lua('address:' + entry['reader']['address'])}, workspace = {workspace}, follow = false }})")
        sync_codex(config, state)
        save_state(state)
        enable(config, state)
        focus(config, state, "reader")
    except Exception:
        save_state(state)
        raise


def down(config):
    state = read_state()
    active_workspace = hypr("activeworkspace", as_json=True)["id"]
    (STATE / "enabled.lua").unlink(missing_ok=True)
    hypr("reload")
    for book in state["windows"]:
        for pane in ("reader", "codex"):
            window = book.get(pane, {})
            if valid(window, hypr("clients", as_json=True)):
                dispatch(f"hl.dsp.window.close({{ window = {lua('address:' + window['address'])} }})")
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        clients = hypr("clients", as_json=True)
        if not any(valid(book.get(pane, {}), clients) for book in state["windows"] for pane in ("reader", "codex")):
            break
        time.sleep(0.1)
    else:
        raise RuntimeError("Some book windows are still closing; their identities were retained for another down.")
    if active_workspace in (config["codex_workspace"], config["books_workspace"]):
        previous = state.get("return_workspace")
        workspaces = hypr("workspaces", as_json=True)
        available = {workspace["id"] for workspace in workspaces if workspace["id"] > 0 and workspace["id"] not in (config["codex_workspace"], config["books_workspace"])}
        if previous not in available:
            previous = min(available) if available else None
        if previous:
            dispatch(f"hl.dsp.focus({{ workspace = {previous} }})")
    save_state({"windows": []})
    print("Stopped; book files, reading progress, and Codex conversations are preserved.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["prepare", "up", "down", "toggle", "status", "read", "chat", "sync"])
    args = parser.parse_args()
    config = load_config()
    STATE.mkdir(parents=True, exist_ok=True)
    with (STATE / "lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        command = args.command
        if command == "toggle":
            command = "down" if running() else "up"
        if command == "prepare":
            prepare(config)
        elif command == "up":
            up(config)
        elif command == "down":
            down(config)
        elif command == "sync":
            # Events already queued before teardown must not reopen the desktop.
            if running():
                state = read_state()
                sync_codex(config, state)
                if hypr("activeworkspace", as_json=True)["id"] == config["codex_workspace"]:
                    focus(config, state, "codex")
        elif command in ("read", "chat"):
            if not running():
                up(config)
            state = read_state()
            if command == "chat":
                sync_codex(config, state)
            focus(config, state, "reader" if command == "read" else "codex")
        else:
            state = read_state()
            clients = hypr("clients", as_json=True)
            print("Running" if running() else "Stopped")
            print(f"Codex: workspace {config['codex_workspace']}; books: workspace {config['books_workspace']}")
            for book in config["books"]:
                entry = next((entry for entry in state["windows"] if entry["id"] == book["id"]), {})
                print(book["id"], ", ".join(f"{pane}: {'open' if valid(entry.get(pane, {}), clients) else 'closed'}" for pane in ("reader", "codex")))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"book-desktop: {error}", file=sys.stderr)
        sys.exit(1)
