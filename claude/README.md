# Claude Code AGS Status Widget

Claude Code hooks feed the AGS agent pills. `hooks/ags-status.py` is a thin entry point into the shared `../ags/hooks/agent_status.py`, which writes the state of the agent in the current Kitty window to `~/.cache/ags-agents/windows/<KITTY_PID>-<KITTY_WINDOW_ID>.json`. AGS (`../ags/service/Agents.ts`, `../ags/widget/AgentPill.ts`) shows a pill while a Kitty window's foreground process is `claude` and colors it from that file. The event-to-state mapping lives in `agent_status.py`.

## Notes

- The hook script is symlinked from `~/.claude/hooks/ags-status.py` → `~/dotfiles/claude/hooks/ags-status.py`; the hook commands are configured in `settings.json`.
- `~/.claude/settings.json` is tracked in this repo at `claude/settings.json` and symlinked back (installer entry `symlinks.claude_settings` in `hosts/common/config.toml`). Note: Claude Code mutates this file at runtime (survey state, theme/effort toggles, etc.), so expect occasional diffs.
- Claude Code has no hook for Esc interrupts during a response, so an interrupted pill stays "running" until the next event.
