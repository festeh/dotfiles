# Claude Code status in Quickshell

In Kitty 0.50+ Claude Code reports its state and background tasks to the terminal
itself (Program Status Protocol, OSC 7501), and the Quickshell tracker reads that
from Kitty. It needs no setting here and also covers Esc interrupts and idle
compaction. See `../quickshell/README.md`.

`settings.json` therefore registers no status hooks. The former entries called
`../quickshell/agent-hook claude` on fourteen events and only mattered for a
pane that cannot report (tmux, `CLAUDE_CODE_DISABLE_TERMINAL_TITLE`); such a
pane now shows no state. `git revert claude-hooks-removed` restores them, and
the tracker still reads their state files.

Automatic labels use Claude Code's session name from its terminal title, with
activity markers removed. Generic startup titles keep the project fallback.
Actual session-name changes update the automatic label, while activity frames
do not. A manual label always takes priority; **Use automatic name** restores
the session name. Full names appear on hover in the workspace strip.

## Notes

- Sessions started before the hooks were removed keep running them until restarted.
- `~/.claude/settings.json` is tracked in this repo at `claude/settings.json` and symlinked back (installer entry `symlinks.claude_settings` in `hosts/common/config.toml`). Note: Claude Code mutates this file at runtime (survey state, theme/effort toggles, etc.), so expect occasional diffs.
