# Neovim configuration

This configuration currently targets Neovim 0.12 and uses its native LSP and
Treesitter APIs. The experimental `vim._core.ui2` UI is still enabled.

## Where things live

| Location | Responsibility |
| --- | --- |
| `init.lua` | Ordered startup entry point |
| `lua/config/options.lua`, `keymaps.lua`, `autocmds.lua` | Editor settings and shared behavior |
| `lua/config/lazy.lua` | Plugin bootstrap and lockfile location |
| `lua/plugins/{editing,ui,git,languages,debugging,ai}.lua` | Plugin specs, dependencies, short options, and lazy keys |
| `lua/config/lsp.lua` | Shared completion capabilities and one `LspAttach` mapping handler |
| `after/lsp/*.lua` | Overrides merged with upstream server defaults |
| `lua/config/tools.lua` | Server activation, Mason packages, and formatter/filetype assignments |
| Other `lua/config/*.lua` files | Substantial setup for individual plugins |
| `lazy-lock.json` | Exact plugin revisions, including Lazy itself |

Lazy [discovers the spec files automatically](https://lazy.folke.io/usage/structuring).
Each spec module passes its table
through `config.keymap-check.track_specs` so duplicate and prefix mappings remain
visible before Lazy replaces them with temporary callbacks. Use `opts` for small
setup tables and `config = require("config.lazy").config("module")` for longer setup.

Shared LSP mappings are installed once per buffer, including when several servers
attach. Rust keeps its hover actions. Diagnostic navigation is global, and native
`grr` shows references. The workspace mappings are consistent across languages:
`<leader>wa` adds, `<leader>wr` removes, and `<leader>wl` displays workspace folders.
`<C-k>` shows signature help in an LSP buffer.

## Installation and updates

Link this directory to `~/.config/nvim`, or use the dotfiles installer. Existing
installations with links for individual files must include new files and `after/`.
Lazy reads and writes the lockfile in this repository, including through symlinks.

1. Start Neovim. A new installation bootstraps Lazy at its locked revision and
   installs the plugins. Use `:Lazy restore` to restore the recorded plugin versions.
2. Run `:ToolsInstall` to install missing declared Mason packages. It delegates to
   Mason, skips installed packages, and does not run during startup.
3. Use `:Lazy update` for intentional plugin updates, then review and commit the
   lockfile diff. Update language tools separately through `:Mason`.

Mason package names are declared, but their versions are **not pinned**. Project
environments and SDKs remain external: Node/npm for web tooling, the Rust and Go
toolchains, Flutter/FVM, and `uv` for Python debugging. `nvim-dap-python` uses `uv`
to run debugpy; a separate Mason debugpy installation is unnecessary. Python tests
need pytest in the project's environment. Other feature dependencies include
Git, ripgrep, lazygit, CMake, the Tree-sitter CLI/compiler, and the optional Aider
and Molten/Jupyter environments.

Formatting is manual with `<leader>m`: Ruff for Python, StyLua for Lua, and Prettier
for configured web filetypes, with LSP fallback. `:ConformInfo` shows availability.
`<leader>tm` toggles Markdown rendering. `:KeymapCheck` shows mapping conflicts.

## Checks

Run from this directory:

```sh
nvim --headless -u NONE -i NONE -l tests/keymap-check.lua
nvim --headless -u NONE -i NONE -l tests/resession.lua
nvim --headless -u NONE -i NONE -l tests/lsp.lua
nvim --headless -u NONE -i NONE -l tests/tools.lua
```

The isolated checks do not load plugins, install tools, or modify saved sessions.
