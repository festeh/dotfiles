# Kimi Code AGS Status Widget

Kimi Code hooks feed the AGS agent pills. `hooks/ags-status.py` is a thin entry point into the shared `../ags/hooks/agent_status.py`, which writes the state of the agent in the current Kitty window to `~/.cache/ags-agents/windows/<KITTY_PID>-<KITTY_WINDOW_ID>.json`. AGS (`../ags/service/Agents.ts`) shows a pill while a Kitty window's foreground process is `kimi` and colors it from that file. The event-to-state mapping lives in `agent_status.py`.

## Install

Kimi Code hooks only live in `~/.kimi-code/config.toml` (there is no separate hooks file), so append the snippet:

```sh
cat ~/dotfiles/kimi/hooks.toml >> ~/.kimi-code/config.toml
```

This repo does not overwrite the full Kimi Code config because it also contains provider, model, and OAuth settings. Hook changes apply to newly started sessions.
