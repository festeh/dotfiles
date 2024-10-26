# For dotfiles
export XDG_CONFIG_HOME="$HOME/.config"
# For specific data
export XDG_DATA_HOME="$HOME/.local/share"
# For cached files
export XDG_CACHE_HOME="$HOME/.cache"


export EDITOR="nvim"
export MANPAGER='nvim +Man!'

export VISUAL="nvim"

export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
# History filepath
export HISTFILE="$ZDOTDIR/.zhistory"
# Maximum events for internal history
export HISTSIZE=500000
# Maximum events in history file
export SAVEHIST=500000

export DOTFILES="$HOME/dotfiles"

export FZF_DEFAULT_COMMAND="rg --files --hidden --glob '!.git'"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS="--bind 'tab:down,btab:up'"

export CHROME_EXECUTABLE=google-chrome-stable

export OPPO_BUDS_MAC="2C:FD:B3:75:E4:F7"

export ANDROID_HOME=$HOME/Android/sdk


pathadd() {
    if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
        PATH="${PATH:+"$PATH:"}$1"
    fi
}

# To not add if already in path
pathadd "$HOME/.local/bin"
pathadd "$HOME/.cargo/bin"
pathadd "$HOME/go/bin"
pathadd "$HOME/Android/Sdk/cmdline-tools/latest/bin"
# TODO: only work pc
pathadd "$HOME/Downloads/swift-5.7.3-RELEASE-ubuntu22.04"
export GOENV_ROOT="$HOME/.goenv"
export PATH="$GOENV_ROOT/bin:$PATH"
. "$HOME/.cargo/env"
