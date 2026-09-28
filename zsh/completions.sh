# Auto-generate & cache completions in the background (updates automatically when binaries change)

ZSH_CACHE_COMPLETIONS="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completions"
mkdir -p "$ZSH_CACHE_COMPLETIONS"

_auto_cache_completion() {
    local cmd="$1"
    local gen="$2"
    local target="$ZSH_CACHE_COMPLETIONS/_$cmd"
    if command -v "$cmd" >/dev/null 2>&1; then
        local bin
        bin="$(command -v "$cmd")"
        if [[ ! -f "$target" ]]; then
            eval "$gen" > "$target" 2>/dev/null
            rm -f "$ZDOTDIR"/.zcompdump*(N) 2>/dev/null
        elif [[ "$bin" -nt "$target" ]]; then
            eval "$gen" > "$target" 2>/dev/null &!
        fi
    fi
}

_auto_cache_completion "omp" "omp completions zsh"
_auto_cache_completion "kubectl" "kubectl completion zsh"
_auto_cache_completion "glab" "glab completion -s zsh"
_auto_cache_completion "uv" "uv --generate-shell-completion zsh"
