"""Install the event watcher in already-running Kitty panes without restarting."""

from pathlib import Path
import importlib
import sys
from kittens.tui.handler import result_handler


def main(args):
    pass


@result_handler(no_ui=True)
def handle_result(args, data, target_window_id, boss):
    from kitty.launch import load_watch_modules, watcher_modules
    from kitty.window import global_watchers
    from kitty.constants import config_dir
    candidate = Path(config_dir) / "terminal-watcher.py"
    if not candidate.exists():
        candidate = Path(args[0]).with_name("terminal-watcher.py")
    path = str(candidate)
    source = candidate.resolve().parents[1] / "quickshell"
    revision = tuple(item.stat().st_mtime_ns for item in (candidate,
        source / "terminal_protocol.py", source / "terminal_labels.py"))
    global_callbacks = global_watchers()
    previous = watcher_modules.get(path)
    if not isinstance(previous, dict) or previous.get("_quickshell_revision") != revision:
        # Replace our callbacks after an update; keep every other Kitty watcher.
        watchers_to_clean = [global_callbacks, *(window.watchers for window in boss.window_id_map.values())]
        for current in watchers_to_clean:
            for name, callbacks in vars(current).items():
                if name.startswith("on_"):
                    callbacks[:] = [callback for callback in callbacks
                        if not getattr(callback, "__code__", None)
                        or Path(callback.__code__.co_filename).resolve() != candidate.resolve()]
        watcher_modules.pop(path, None)
        for module in ("terminal_labels", "terminal_protocol"):
            if module in sys.modules:
                importlib.reload(sys.modules[module])
    watchers = load_watch_modules([path])
    if watchers is None:
        return False
    watcher_modules[path]["_quickshell_revision"] = revision
    global_watchers().add(watchers)
    for window in boss.window_id_map.values():
        window.watchers.add(watchers)
    watcher_modules[path]["resync"](boss, force=True)
    return True
