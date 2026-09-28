# Codex pills in AGS

AGS shows one pill for each Kitty window whose foreground process is an agent (`../ags/service/Agents.ts`, polling Kitty's remote-control `ls` every five seconds). Internal Codex workers, including memory jobs and the shared app-server daemon, have no foreground Kitty window and are therefore not shown.

Codex has no AGS hook. Codex TUIs share one app-server daemon (`daemon_auto_start`, on by default), and hooks run inside that daemon with its environment, so a hook cannot tell which Kitty window its session belongs to. The Codex pill color follows the terminal title the TUI maintains instead: a spinner means running, `[ ! ] Action Required` (blinking with `[ . ]`) means waiting, and an unmarked title means idle. This relies on the default `[tui].terminal_title`, which includes the `activity` item.

The time badge shows how long Codex has been idle or waiting, based on title transitions observed by AGS; it restarts when AGS restarts.

While running, the badge shows the tool calls in the current turn, like the Claude and Kimi pills (`../ags/service/CodexToolCount.ts`). The title's thread name is looked up in `~/.codex/session_index.jsonl`, and the thread's rollout file under `~/.codex/sessions/` is counted from its last `task_started` event, then read incrementally. A new thread has no count until Codex names it.

`hooks.json` keeps only the separate `herdr-agent-state.sh` SessionStart hook. `hooks/ags-status.py` is a no-op for Codex sessions that loaded the old AGS hook configuration.
