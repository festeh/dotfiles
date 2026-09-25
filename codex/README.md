# Codex pills in AGS

AGS shows one pill for each Kitty window whose foreground process is an agent (`../ags/service/Agents.ts`, polling Kitty's remote-control `ls` every five seconds). Internal Codex workers, including memory jobs and the shared app-server daemon, have no foreground Kitty window and are therefore not shown.

Codex has no AGS hook. Codex TUIs share one app-server daemon (`daemon_auto_start`, on by default), and hooks run inside that daemon with its environment, so a hook cannot tell which Kitty window its session belongs to. The Codex pill color follows the terminal title the TUI maintains instead: a spinner means running, `[ ! ] Action Required` (blinking with `[ . ]`) means waiting, and an unmarked title means idle. This relies on the default `[tui].terminal_title`, which includes the `activity` item.

The time badge shows how long Codex has been idle or waiting, based on title transitions observed by AGS; it restarts when AGS restarts.

`hooks.json` keeps only the separate `herdr-agent-state.sh` SessionStart hook. `hooks/ags-status.py` is a no-op for Codex sessions that loaded the old AGS hook configuration.
