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

setopt hist_ignore_all_dups
setopt hist_find_no_dups
unsetopt hist_ignore_space
setopt    appendhistory     #Append history to the history file (no overwriting)
setopt    sharehistory      #Share history across terminals
setopt    incappendhistory  #Immediately append to the history file, not just when a term is killed

fpath=($ZDOTDIR/external $fpath)

autoload -Uz cursor_mode && cursor_mode

zmodload zsh/complist
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history

autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line

bindkey '^_' undo

if [ -f "/etc/arch-release" ]; then
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

# Source zsh-system-clipboard
source "$XDG_CONFIG_HOME/zsh/plugins/zsh-system-clipboard/zsh-system-clipboard.zsh"

# Prefix autocomplete
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search # Up
bindkey "^[[B" down-line-or-beginning-search # Down


setxkbmap -option ctrl:nocaps     #Swap Left Control and Caps Lock

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/dlipin/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/dlipin/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/dlipin/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/dlipin/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

export PATH="$PATH:$HOME/.local/bin"
eval "$(starship init zsh)"

LOCAL_SETTINGS="$DOTFILES/zsh/local.sh"
if [ -f "$LOCAL_SETTINGS" ]; then
    source "$LOCAL_SETTINGS"
fi
