# Kimi Code status in Quickshell

Kimi hooks call `../quickshell/agent-hook kimi`. The hook writes only pane identity
and normalized state to private runtime files, and only when the state changes.
Quickshell combines all agents in a Kitty window, including inactive tabs/splits:
amber needs action, blue running, green all idle. No AGS or Herdr hooks remain.

## Install

Kimi Code hooks live in `~/.kimi-code/config.toml`. Remove the former AGS/Herdr hook
blocks, then append this repo's snippet once, preserving provider/account settings:

```sh
cat ~/dotfiles/kimi/hooks.toml >> ~/.kimi-code/config.toml
```

This repo does not overwrite the full Kimi Code config because it also contains
provider, model, and OAuth settings. Restart existing Kimi sessions after changing
hooks so they stop using cached commands.
