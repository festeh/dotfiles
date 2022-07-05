source "$XDG_CONFIG_HOME/zsh/aliases"

unsetopt CASE_GLOB
#If a command is issued that can’t be executed as a normal command, and the command is the name of a directory, perform the cd command to that directory
setopt AUTO_CD

autoload -U compinit; compinit
# Autocomplete hidden files
_comp_options+=(globdots)
source ~/dotfiles/zsh/external/completion.zsh

if [ -f "/etc/arch-release" ]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
else
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
source /usr/share/autojump/autojump.zsh

bindkey -v
bindkey  "^?" backward-delete-char
bindkey  "^[L" forward-word
bindkey  "^[[1;3C" forward-word
bindkey "^R" history-incremental-search-backward

export KEYTIMEOUT=1

setopt hist_ignore_dups
unsetopt hist_ignore_space

fpath=($ZDOTDIR/external $fpath)
autoload -Uz prompt_purification_setup; prompt_purification_setup
autoload -Uz cursor_mode && cursor_mode

zmodload zsh/complist
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history

autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line

if [ -f "/etc/arch/release" ]; then
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
else 
    source /usr/share/zsh-syntax-highlighting
fi

source $DOTFILES/zsh/scripts.sh

if [ $(command -v "fzf") ]; then
    source /usr/share/fzf/completion.zsh
    source /usr/share/fzf/key-bindings.zsh
else
    echo "WARN: fzf is not found"
fi

setxkbmap -option caps:escape
