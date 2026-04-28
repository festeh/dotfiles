#!/bin/bash
set -euo pipefail

# Virtual monitor management script for Hyprland
# Note: Hyprland auto-names headless monitors as HEADLESS-1, HEADLESS-2, etc.

usage() {
    echo "Usage: $(basename "$0") <add|remove|toggle|list> [options]"
    echo ""
    echo "Commands:"
    echo "  add [resolution] [refresh]  - Create a virtual monitor (default: 1920x1080@60Hz)"
    echo "  remove [name]               - Remove a virtual monitor by name"
    echo "  toggle                      - Toggle virtual monitor on/off"
    echo "  list                        - List all headless monitors"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") add"
    echo "  $(basename "$0") add 2560x1440 60"
    echo "  $(basename "$0") remove HEADLESS-1"
    echo "  $(basename "$0") toggle"
    echo "  $(basename "$0") list"
    exit 1
}

get_headless_monitors() {
    hyprctl monitors -j | jq -r '.[] | select(.name | startswith("HEADLESS")) | .name'
}

list_monitors() {
    local monitors
    monitors=$(get_headless_monitors)
    if [[ -z "$monitors" ]]; then
        echo "No headless monitors found"
    else
        echo "Headless monitors:"
        echo "$monitors"
    fi
}

add_monitor() {
    local resolution="${1:-1920x1080}"
    local refresh="${2:-60}"

    # Get current headless monitors before creation
    local before
    before=$(get_headless_monitors)

    hyprctl output create headless

    # Find the newly created monitor
    local after new_monitor
    after=$(get_headless_monitors)
    new_monitor=$(comm -13 <(echo "$before" | sort) <(echo "$after" | sort) | head -1)

    if [[ -n "$new_monitor" ]]; then
        # Configure with proper resolution and refresh rate (important for screen sharing)
        hyprctl keyword monitor "$new_monitor,${resolution}@${refresh},auto,1"
        echo "Created virtual monitor: $new_monitor (${resolution}@${refresh}Hz)"
    else
        echo "Created virtual monitor"
    fi
    list_monitors
}

remove_monitor() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        # Remove the first headless monitor found
        name=$(get_headless_monitors | head -1)
        if [[ -z "$name" ]]; then
            echo "No headless monitors to remove"
            exit 1
        fi
    fi
    hyprctl output remove "$name"
    echo "Removed virtual monitor: $name"
}

toggle_monitor() {
    local monitors
    monitors=$(get_headless_monitors)
    if [[ -z "$monitors" ]]; then
        add_monitor
    else
        remove_monitor "$(echo "$monitors" | head -1)"
    fi
}

case "${1:-}" in
    add)
        add_monitor "${2:-}" "${3:-}"
        ;;
    remove)
        remove_monitor "${2:-}"
        ;;
    toggle)
        toggle_monitor
        ;;
    list)
        list_monitors
        ;;
    *)
        usage
        ;;
esac
