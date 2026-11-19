# Claude Code status in Quickshell

In Kitty 0.50+ Claude Code reports its state and background tasks to the terminal
itself (Program Status Protocol, OSC 7501), and the Quickshell tracker reads that
from Kitty. It needs no setting here and also covers Esc interrupts and idle
compaction. See `../quickshell/README.md`.

The hooks in `settings.json` call `../quickshell/agent-hook claude` and remain the
fallback for a pane that has not reported. They publish
only idle/running/needs-action state for the current Kitty pane, with no prompts,
Git commands, transcript scanning or Herdr integration. Repeated tool events in
the same state cause no file writes. The Quickshell tracker watches those files
and follows the state of every agent pane across tabs/splits.

Automatic labels use Claude Code's session name from its terminal title, with
activity markers removed. Generic startup titles keep the project fallback.
Actual session-name changes update the automatic label, while activity frames
do not. A manual label always takes priority; **Use automatic name** restores
the session name. Full names appear on hover in the workspace strip.

## Notes

- Former AGS and Herdr hook entries/scripts are removed. Existing sessions may need a restart to forget cached commands.
- `~/.claude/settings.json` is tracked in this repo at `claude/settings.json` and symlinked back (installer entry `symlinks.claude_settings` in `hosts/common/config.toml`). Note: Claude Code mutates this file at runtime (survey state, theme/effort toggles, etc.), so expect occasional diffs.
- Hooks cannot see an Esc interrupt. The program status report covers it; without one, a later idle terminal title settles the running state.
