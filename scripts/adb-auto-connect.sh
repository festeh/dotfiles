#!/bin/bash

# ADB Auto-Connect via mDNS
# Wrapper script that calls the Python implementation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/adb-auto-connect.py" "$@"