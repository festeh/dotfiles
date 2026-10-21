#!/usr/bin/env python3
"""Record QML reader requests on the private fixture transport."""

import json
import os
import sys

with open(os.environ["QS_KITTY_CHECK_LOG"], "a", buffering=1) as log:
    for line in sys.stdin:
        message = json.loads(line)
        log.write(json.dumps(message) + "\n")
        if 'rename' in message:
            ok = message['rename']['label'] != 'fail'
            reply = {'renamed': dict(message['rename'], ok=ok, error='' if ok else 'Could not save label.')}
        else:
            reply = {"activated": dict(message["activate"], ok=True)} if "activate" in message else {"windows": {}, "health": {}}
        print(json.dumps(reply), flush=True)
