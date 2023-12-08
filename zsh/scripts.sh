#!/bin/bash

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
    export XSEL=$(which xsel)
    if [ -z "$1" ]
    then
        echo "No argument supplied. Please provide a file or directory name."
    else
        local path=$(realpath "$1")
        if [ $? -eq 0 ]
        then
            echo "$path" | $XSEL --clipboard --input
            echo "The path has been copied to the clipboard."
        else
            echo "Error getting the real path. Please check the file or directory name."
        fi
    fi
}
