#! /usr/bin/zsh

autoload -U compinit; compinit
# Autocomplete hidden files
_comp_options+=(globdots)
source ~/dotfiles/zsh/external/completion.zsh
