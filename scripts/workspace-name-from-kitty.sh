#!/usr/bin/env bash

# Script to rename Hyprland workspace based on kitty tab's cwd
# Logs to systemd journal, viewable with: journalctl -t workspace-name-from-kitty

log() {
    echo "$@" | systemd-cat -t workspace-name-from-kitty -p info
}

# Get active window info
active_window=$(hyprctl activewindow -j)
window_class=$(echo "$active_window" | jq -r '.class')
workspace_id=$(echo "$active_window" | jq -r '.workspace.id')

log "Active window class: $window_class, workspace: $workspace_id"

# Check if the active window is kitty
if [[ "$window_class" != "kitty" ]]; then
    log "Active window is not kitty, clearing workspace name to ID"
    # Reset workspace name to its ID
    hyprctl dispatch renameworkspace "$workspace_id" "$workspace_id"
    exit 0
fi

# Get kitty PID from the active window
kitty_pid=$(echo "$active_window" | jq -r '.pid')
log "Connecting to kitty instance with PID: $kitty_pid"

# Get kitty tab information from this specific instance
# Capture both stdout and stderr
kitty_output=$(kitty @ --to unix:@kitty-$kitty_pid ls 2>&1)
kitty_exit_code=$?

if [[ $kitty_exit_code -ne 0 ]] || [[ -z "$kitty_output" ]]; then
    log "Failed to get kitty data from PID $kitty_pid (exit code: $kitty_exit_code)"
    log "Error output: $kitty_output"
    hyprctl dispatch renameworkspace "$workspace_id" "$workspace_id"
    exit 1
fi

kitty_data="$kitty_output"

# Find the cwd of the first window in the focused tab
cwd=$(echo "$kitty_data" | jq -r '.[0].tabs[] | select(.is_focused == true) | .windows[0].cwd')

if [[ -z "$cwd" ]] || [[ "$cwd" == "null" ]]; then
    log "Could not find cwd for active tab, clearing workspace name"
    hyprctl dispatch renameworkspace "$workspace_id" "$workspace_id"
    exit 1
fi

# Get just the directory name (basename)
dir_name=$(basename "$cwd")

log "Renaming workspace $workspace_id to: $dir_name (from cwd: $cwd)"

# Rename the workspace
hyprctl dispatch renameworkspace "$workspace_id" "$dir_name"
