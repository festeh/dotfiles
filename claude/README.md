# Claude Code AGS Status Widget

Real-time Claude Code session tracker for the AGS (Astal/GTK4) top bar. Shows active Claude instances with color-coded, animated status pills.

## Architecture

```
┌─────────────────┐     hooks      ┌─────────────────────────┐     poll     ┌──────────────────┐
│  Claude Code    │ ─────────────► │  ~/.cache/ags-claude/   │ ───────────► │   AGS Widget     │
│  (N instances)  │   JSON stdin   │  sessions.json + hook.log│   1s         │  (top bar pills) │
└─────────────────┘                └─────────────────────────┘              └──────────────────┘
         ▲
         │
   ~/.claude/settings.json
   (hook commands configured here)
```

## Key Files

| File | Purpose |
|------|---------|
| `hooks/ags-status.py` | Claude Code hook script. Reads hook events from stdin and maintains the shared `sessions.json` database. |
| `../ags/service/ClaudeStatus.ts` | AGS service. Polls `sessions.json` every second, filters stale sessions, and exposes a reactive `Variable<ClaudeSession[]>`. Ignores `action` churn to avoid unnecessary widget rebuilds. |
| `../ags/widget/ClaudeStatus.ts` | AGS widget. Renders session pills in the bar. Running sessions get a custom Cairo arc spinner with global persistent animation state (no teleporting on rebuilds). |
| `../ags/widget/Bar.ts` | Bar layout. Imports and places `ClaudeStatus()` on the left side. |
| `../ags/style.css` | Styles. Color-coded pills with flash-on-state-change animations and smooth 400ms transitions. |

## Hook Events → States

| Event | State | Icon |
|-------|-------|------|
| `SessionStart` | `idle` | ✅ checkmark |
| `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PostToolBatch` | `running` | 🌀 spinning arc |
| `PermissionRequest`, `Notification:permission_prompt/elicitation_dialog` | `waiting` | ⚠️ warning |
| `Notification:idle_prompt`, `Stop` | `idle` | ✅ checkmark |
| `SessionEnd` | *(removed)* | — |
| Unknown event / notification | `unknown` | ❓ question |

## Colors

- **Running** — blue border + blue spinner arc
- **Idle** — green border + green checkmark
- **Waiting** — yellow border + yellow warning
- **Unknown** — gray border + gray question

Each pill briefly flashes its color on state change, then settles to a subtle tinted background.

## Requirements

- `python3` (for hook script)
- `jq` (only if you rewrite the hook in bash — current script is pure Python)
- AGS v2+ with Astal/GTK4
- Claude Code hooks enabled in `~/.claude/settings.json`

## Notes

- The hook script is symlinked from `~/.claude/hooks/ags-status.py` → `~/dotfiles/claude/hooks/ags-status.py`
- `~/.claude/settings.json` is **not** tracked in this repo — configure hooks there manually
- Idle sessions never go stale; running/waiting sessions are cleaned up after 60s of silence
