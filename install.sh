#!/bin/bash

mkdir -p "$HOME/.config/nvim"
ln -sf "$HOME/dotfiles/nvim/init.vim" "$HOME/.config/nvim/init.vim"

rm -rf "$HOME/.config/X11"
ln -s "$HOME/dotfiles/X11" "$HOME/.config/X11"

rm -rf "$HOME/.config/i3"
ln -s "$HOME/dotfiles/i3" $HOME/.config/i3

mkdir -p $HOME/.config/zsh
ln -sf "$HOME/dotfiles/zsh/.zshenv" "$HOME"
ln -sf "$HOME/dotfiles/zsh/.zshrc" "$HOME/.config/zsh"
