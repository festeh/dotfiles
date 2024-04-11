setopt AUTO_CD # cd to directory without typing cd

source $DOTFILES/zsh/external/completion.zsh


# TODO: template
if [ -f "/etc/arch-release" ]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
else
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
source /usr/share/autojump/autojump.zsh

bindkey -v
bindkey  "^?" backward-delete-char
bindkey  "^[L" forwar-word
bindkey  "^[[1;3C" forward-word
bindkey "^R" history-incremental-search-backward

export KEYTIMEOUT=1

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

# TODO: template
if [ -f "/etc/arch-release" ]; then
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
else 
    source /usr/share/zsh-syntax-highlighting
fi

if [ $(command -v "fzf") ]; then
    source /usr/share/fzf/completion.zsh
    source /usr/share/fzf/key-bindings.zsh
else
    echo "WARN: fzf is not found"
fi

# Source zsh-system-clipboard
source "$XDG_CONFIG_HOME/zsh/plugins/zsh-system-clipboard/zsh-system-clipboard.zsh"

# Prefix autocomplete
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search # Up
bindkey "^[[B" down-line-or-beginning-search # Down

eval "$(starship init zsh)"

LOCAL_SETTINGS="$ZDOTDIR/local.sh"
if [ -f "$LOCAL_SETTINGS" ]; then
    source "$LOCAL_SETTINGS"
fi

setopt hist_find_no_dups
unsetopt hist_ignore_space
setopt extended_history  # Record timestamp of command in HISTFILE
setopt hist_ignore_dups  # Do not record an entry that was just recorded again
setopt share_history      # Share command history across sessions

source $DOTFILES/zsh/scripts.sh
source $DOTFILES/zsh/aliases.sh

. $HOME/.asdf/asdf.sh
fpath=(${ASDF_DIR}/completions $fpath)
. ~/.asdf/plugins/golang/set-env.zsh

_comp_options+=(globdots)
autoload -U compinit;
if [ "$(find $ZDOTDIR/.zcompdump -mtime +1)" ] ; then
    echo "zcompdump is older than a day. Regenerating..."
    compinit
fi
compinit -C

# pnpm
export PNPM_HOME="/home/dlipin/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
#
if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  exec tmux
fi
