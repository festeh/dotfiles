#!/bin/bash

mkdir -p "$HOME/.config/nvim"
ln -sf "$HOME/dotfiles/nvim/init.vim" "$HOME/.config/nvim/init.vim"

rm -rf "$HOME/.config/X11"
ln -s "$HOME/dotfiles/X11" "$HOME/.config/X11"

rm -rf "$HOME/.config/i3"
ln -s "$HOME/dotfiles/i3" $HOME/.config/i3
mkdir -p $XDG_CONFIG_HOME/i3status-rust/
ln -sf "$HOME/dotfiles/i3/status_config.toml" $XDG_CONFIG_HOME/i3status-rust/config.toml
$HOME/dotfiles/i3/install_i3_bar.sh


mkdir -p $HOME/.config/zsh
ln -sf "$HOME/dotfiles/zsh/.zshenv" "$HOME"
ln -sf "$HOME/dotfiles/zsh/.zshrc" "$HOME/.config/zsh"
ln -sf "$HOME/dotfiles/zsh/aliases" "$HOME/.config/zsh/aliases"

rm -rf "$HOME/.config/zsh/external"
ln -sf "$HOME/dotfiles/zsh/external" "$HOME/.config/zsh"
