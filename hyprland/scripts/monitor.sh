#!/bin/bash
set -euo pipefail

# Check if DP-3 in hyprctl monitor list
sleep 1
if hyprctl monitors all -j | jq -e 'any(.[]; .name == "DP-3")' > /dev/null; then
  hyprctl eval 'hl.monitor({ output = "DP-3", mode = "preferred", position = "auto", scale = 2 })
hl.monitor({ output = "eDP-1", disabled = true })'
fi
