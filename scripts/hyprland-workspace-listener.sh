#!/usr/bin/env bash

# Hyprland event listener for workspace name updates
# Logs to systemd journal, viewable with: journalctl -t hyprland-workspace-listener

log() {
    echo "$@" | systemd-cat -t hyprland-workspace-listener -p info
}

log "Starting Hyprland workspace listener"

# Connect to Hyprland event socket
SOCKET="/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

if [[ ! -S "$SOCKET" ]]; then
    log "Error: Hyprland socket not found at $SOCKET"
    exit 1
fi

log "Connected to Hyprland socket: $SOCKET"

# Listen to events and trigger workspace name updates
socat -U - "UNIX-CONNECT:$SOCKET" | while read -r line; do
    event=$(echo "$line" | cut -d'>' -f1)

    case "$event" in
        "workspace"|"workspacev2"|"focusedmon"|"activewindow"|"activewindowv2"|"movewindow"|"movewindowv2")
            log "Event: $event - Updating workspace name"
            workspace-name-from-kitty &
            ;;
    esac
done
