#!/bin/zsh
#
take () {
    mkdir -p "$1" && cd "$1"
}

viman () { 
    text=$(man "$@") && echo "$text" | vim -R +":set ft=man" - ; 
}

_poetry_exists() {
    command -v "poetry --version" >/dev/null 2>&1 || return 0
}

function chpwd() {
    if [[ -f "pyproject.toml" ]] && _poetry_exists; then
        poetry shell
    else
        if [[ $POETRY_ACTIVE == "1" ]]; then
        fi
    fi
}

function copypath() {
    # check if we are on wayland or xorg
    if [ -z "$WAYLAND_DISPLAY" ]
    then
        XSEL=$(which xsel)
        CMD="$XSEL --clipboard --input"
    else
      CMD=$(which wl-copy)
    fi 
    if [ -z "$1" ]
    then
        echo "No argument supplied. Please provide a file or directory name."
    else
        local filepath=$(realpath "$1")
        if [ -f "$filepath" ] || [ -d "$filepath" ]
        then
            FINAL_CMD="echo $filepath | $CMD 2>/dev/null"
            eval "$FINAL_CMD" && echo "Copied $filepath to clipboard."
        else
            echo "Error getting the real path. Please check the file or directory name."
        fi
    fi
}

function bgrun() {
    if [ -z "$1" ]
    then
        echo "No argument supplied. Please provide a command to run in the background."
    else
        nohup "$@" >/dev/null 2>&1 &
    fi
}
