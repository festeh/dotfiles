# Codex status in Quickshell

Quickshell's terminal tracker follows interactive Codex panes in every Kitty tab,
including inactive tabs and splits. Internal app-server/exec-server processes do
not create status indicators. Kitty pane IDs identify terminals; the shared Codex
daemon PID does not identify individual windows.

Kitty pushes title changes directly to the tracker: a spinner means running,
`[ ! ] Action Required` (blinking with `[ . ]`) means needs action, and an unmarked
title means idle. Keep `activity` in `[tui].terminal_title`. The window's overline
combines all its agents: amber needs action, blue running, green all idle.

There are no Codex hooks: `hooks.json` contains an empty hook map. AGS and Herdr
hook scripts and obsolete hook trust entries have been removed. The tracker does
not read session indexes, rollouts, prompts or tool counts.

See [the Quickshell configuration](../quickshell/README.md) for tracking,
attachment and validation details.
