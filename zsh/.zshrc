setopt AUTO_CD # cd to directory without typing cd

source $DOTFILES/zsh/external/completion.zsh


# TODO: template
if [ -f "/etc/arch-release" ]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
else
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

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

if command -v mise &> /dev/null; then
    eval "$(mise activate zsh)"
else
    echo "WARN: mise is not found"
fi

_comp_options+=(globdots)
autoload -U compinit;
if [ "$(find $ZDOTDIR/.zcompdump -mtime +1)" ] ; then
    echo "zcompdump is older than a day. Regenerating..."
    compinit
fi
compinit -C

# scripts
export PATH="$DOTFILES/scripts:$PATH"

# pnpm
export PNPM_HOME="/home/dlipin/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Auto-attach to tmux session
auto_attach_tmux() {
  # Only proceed if:
  # - tmux is installed
  # - running interactively (PS1 is set)
  # - not already in tmux/screen
  [[ -z "$TMUX" ]] || return
  [[ -n "$PS1" ]] || return
  command -v tmux &>/dev/null || return
  [[ "$TERM" =~ (screen|tmux) ]] && return

  tmux attach -t projects || tmux new -s projects
}

auto_attach_tmux

# Tmux pane title management
if [[ -n "$TMUX" ]]; then
    # Function to set pane title
    _tmux_set_pane_title() {
        printf '\033]2;%s\033\\' "$1"
    }

    # Before showing prompt: reset to pane index
    _tmux_title_precmd() {
        local pane_index
        pane_index=$(tmux display-message -p "#{pane_index}")
        _tmux_set_pane_title "$pane_index"
    }

    # Before executing command: show command name
    _tmux_title_preexec() {
        local cmd="$1"

        # Extract just the command name (first word, no path)
        cmd="${cmd[(w)1]}"     # Get first word
        cmd="${cmd##*/}"       # Remove path prefix
        cmd="${cmd%% *}"       # Remove any arguments

        _tmux_set_pane_title "$cmd"
    }

    # Register the hooks
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _tmux_title_precmd
    add-zsh-hook preexec _tmux_title_preexec
fi

eval "$(zoxide init zsh)"
