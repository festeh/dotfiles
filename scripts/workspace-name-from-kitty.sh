#!/usr/bin/env bash

# Script to rename Hyprland workspace based on kitty tab's cwd

# Get active window info
active_window=$(hyprctl activewindow -j)
window_class=$(echo "$active_window" | jq -r '.class')
workspace_id=$(echo "$active_window" | jq -r '.workspace.id')

# Check if the active window is kitty
if [[ "$window_class" != "kitty" ]]; then
    echo "Active window is not kitty (class: $window_class)"
    exit 0
fi

# Get kitty tab information
kitty_data=$(kitty @ ls 2>/dev/null)
if [[ $? -ne 0 ]] || [[ -z "$kitty_data" ]]; then
    echo "Failed to get kitty data"
    exit 1
fi

# Find the cwd of the first window in the focused tab
cwd=$(echo "$kitty_data" | jq -r '.[0].tabs[] | select(.is_focused == true) | .windows[0].cwd')

if [[ -z "$cwd" ]] || [[ "$cwd" == "null" ]]; then
    echo "Could not find cwd for active tab"
    exit 1
fi

# Get just the directory name (basename)
dir_name=$(basename "$cwd")

echo "Renaming workspace $workspace_id to: $dir_name"

# Rename the workspace
hyprctl dispatch renameworkspace "$workspace_id" "$dir_name"
