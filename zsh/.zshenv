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

export ANDROID_HOME=$HOME/Android/Sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
export ANDROID_AVD_HOME=$XDG_CONFIG_HOME/.android/avd
export GOENV_ROOT="$HOME/.goenv"


pathadd() {
    if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
        PATH="${PATH:+"$PATH:"}$1"
    fi
}

try-source() {
    if [ -f "$1" ]; then
        source "$1"
    else
        echo "Couldn't source $1 - not found"
    fi
}

# To not add if already in path
pathadd "$HOME/.local/bin"
pathadd "$HOME/.cargo/bin"
pathadd "$HOME/go/bin"
pathadd "$ANDROID_HOME/cmdline-tools/latest/bin"
pathadd "$ANDROID_HOME/platform-tools"
# TODO: only work pc
pathadd "$HOME/Downloads/swift-5.7.3-RELEASE-ubuntu22.04"
pathadd "$GOENV_ROOT/bin"

try-source "$HOME/.cargo/env"
try-source "$HOME/dotfiles/.env"
