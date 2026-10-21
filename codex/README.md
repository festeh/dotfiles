# Codex status in Quickshell

Quickshell's terminal tracker follows interactive Codex panes in every Kitty tab,
including inactive tabs and splits. Internal app-server/exec-server processes do
not create status indicators. Kitty pane IDs identify terminals; the shared Codex
daemon PID does not identify individual windows.

Kitty pushes title changes directly to the tracker: a spinner means running,
`[ ! ] Action Required` (blinking with `[ . ]`) means needs action, and an unmarked
title means idle. Keep `activity` in `[tui].terminal_title`. Each agent pane has
its own overline: amber needs action, blue running, green idle.

Automatic labels use Codex's thread name from its default terminal title
(`activity`, `thread-name`, `project-name`), the same name shown by the TUI.
Activity and name-generation spinners are removed. Unnamed conversations use
the project until a name arrives; a manual label always wins. Full names appear
on hover while the bar elides them to its compact width. An actual thread-name
change updates an automatic label; activity frames do not.

There are no Codex hooks: `hooks.json` contains an empty hook map. AGS and Herdr
hook scripts and obsolete hook trust entries have been removed. The tracker does
not read session indexes, rollouts, prompts or tool counts.

See [the Quickshell configuration](../quickshell/README.md) for tracking,
attachment and validation details.
