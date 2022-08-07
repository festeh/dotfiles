#!/bin/zsh

take () {
    mkdir -p "$1" && cd "$1"
}

viman () { 
    text=$(man "$@") && echo "$text" | vim -R +":set ft=man" - ; 
}
