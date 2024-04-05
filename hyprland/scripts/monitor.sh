#!/bin/bash

# Check if DP-3 in hyprctl monitor list
if echo `hyprctl monitors all` | grep "DP-3 connected"; then
  hyprctl keyword monitor DP-3,preferred,auto,2
  hyprctl keyword monitor eDP-1,disable
else
fi
