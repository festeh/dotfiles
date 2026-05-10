# Codex AGS Status Widget

Local Codex CLI session tracker for the AGS top bar. Codex hooks write one JSON file per active session under `~/.cache/ags-codex/sessions/`; AGS monitors that directory and renders Codex pills beside the Hyprland workspace that owns the terminal window.

## Files

| File | Purpose |
| --- | --- |
| `hooks/ags-status.py` | Codex hook script. Reads hook JSON from stdin and updates the session cache. |
| `hooks.json` | Hook configuration example for `~/.codex/hooks.json`. |
| `../ags/service/AgentStatus.ts` | Shared session cache monitor used by Claude and Codex. |
| `../ags/service/CodexStatus.ts` | Codex service adapter. |
| `../ags/widget/AgentStatus.ts` | Shared pill/detail renderer used by Claude and Codex. |
| `../ags/widget/CodexStatus.ts` | Codex widget adapter. |

## Install

Enable Codex hooks in `~/.codex/config.toml`:

```toml
[features]
hooks = true
```

Then symlink the hook configuration:

```sh
mkdir -p ~/.codex
ln -sf ~/dotfiles/codex/hooks.json ~/.codex/hooks.json
```

This repo does not overwrite the full Codex config because it also contains auth, model, MCP, and project trust settings.

## Event Mapping

| Codex event | State |
| --- | --- |
| `SessionStart` | `idle` |
| `UserPromptSubmit` | `running` |
| `PreToolUse` | `running` |
| `PermissionRequest` | `waiting` |
| `PostToolUse` | `running` |
| `Stop` | `idle` |
| unknown event | `unknown` |

The hook intentionally writes nothing to stdout. Codex treats stdout as hook output that can affect the session, while this hook is telemetry-only.
