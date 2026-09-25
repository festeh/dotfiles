#!/usr/bin/env python3
"""Kimi Code hook entry point for the AGS agent pills (see ags/hooks/agent_status.py)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path.home() / "dotfiles/ags/hooks"))
from agent_status import main  # noqa: E402

main("kimi")
