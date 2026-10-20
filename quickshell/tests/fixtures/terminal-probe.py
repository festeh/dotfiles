#!/usr/bin/env python3
"""Record QML reader requests on the private fixture transport."""

import json
import os
import sys

with open(os.environ["QS_KITTY_CHECK_LOG"], "a", buffering=1) as log:
    for line in sys.stdin:
        message = json.loads(line)
        log.write(json.dumps(message) + "\n")
        print(json.dumps({"windows": {}, "health": {}}), flush=True)
