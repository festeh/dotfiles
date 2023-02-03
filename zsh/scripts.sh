#!/bin/zsh

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
            exit
        fi
    fi
}
