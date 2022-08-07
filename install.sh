#!/bin/bash

mkdir -p "$XDG_CONFIG_HOME/nvim"
mkdir -p "$XDG_CONFIG_HOME/nvim/lua/"
rm -rf "$XDG_CONFIG_HOME/nvim/lua/plugins"

ln -sf "$DOTFILES/nvim/init.vim" "$XDG_CONFIG_HOME/nvim/init.vim"
ln -sf "$DOTFILES/nvim/lua/options.lua" "$XDG_CONFIG_HOME/nvim/lua/options.lua"
ln -sf "$DOTFILES/nvim/lua/utils.lua" "$XDG_CONFIG_HOME/nvim/lua/utils.lua"
ln -sf "$DOTFILES/nvim/lua/keymap.lua" "$XDG_CONFIG_HOME/nvim/lua/keymap.lua"
ln -sf "$DOTFILES/nvim/lua/plugins" "$XDG_CONFIG_HOME/nvim/lua"

rm -rf "$XDG_CONFIG_HOME/X11"
ln -s "$DOTFILES/X11" "$XDG_CONFIG_HOME/X11"

rm -rf "$XDG_CONFIG_HOME/i3"
ln -s "$DOTFILES/i3" $XDG_CONFIG_HOME/i3
mkdir -p $XDG_CONFIG_HOME/i3status-rust/
ln -sf "$DOTFILES/i3/status_config.toml" $XDG_CONFIG_HOME/i3status-rust/config.toml
$DOTFILES/i3/install_i3_bar.sh


mkdir -p $XDG_CONFIG_HOME/zsh
ln -sf "$DOTFILES/zsh/.zshenv" "$HOME"
ln -sf "$DOTFILES/zsh/.zshrc" "$XDG_CONFIG_HOME/zsh"
ln -sf "$DOTFILES/zsh/aliases" "$XDG_CONFIG_HOME/zsh/aliases"

rm -rf "$XDG_CONFIG_HOME/zsh/external"
ln -sf "$DOTFILES/zsh/external" "$XDG_CONFIG_HOME/zsh"

# Install plugin manager for nvim
[ ! -f "$DOTFILES/nvim/autoload/plug.vim" ] \
    &&  curl -fLo "$DOTFILES/nvim/autoload/plug.vim" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

mkdir -p "$XDG_CONFIG_HOME/nvim/autoload"
ln -sf "$DOTFILES/nvim/autoload/plug.vim" "$XDG_CONFIG_HOME/nvim/autoload/plug.vim"

# Install (or update) nvim plugins
nvim --noplugin +PlugUpdate +qa

# Install clipboard manager
[ ! -d "$XDG_CONFIG_HOME/zsh/plugins/zsh-system-clipboard" ] \
    && mkdir -p "$XDG_CONFIG_HOME/zsh/plugins" \
    && git clone https://github.com/kutsan/zsh-system-clipboard $XDG_CONFIG_HOME/zsh/plugins/zsh-system-clipboard

mkdir -p "$XDG_CONFIG_HOME/tmux"
ln -sf "$DOTFILES/tmux/tmux.conf" "$XDG_CONFIG_HOME/tmux/tmux.conf"

# tmux plugins
[ ! -d "$XDG_CONFIG_HOME/tmux/plugins" ] \
    && mkdir "$XDG_CONFIG_HOME/tmux/plugins" \
    && git clone https://github.com/tmux-plugins/tpm "$XDG_CONFIG_HOME/tmux/plugins/tpm" 
