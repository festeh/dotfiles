#!/bin/sh
# idlehint makes swayidle connect to logind and honor idle inhibitors,
# including the Quickshell Stay awake widget. A timeout alone does not.
exec swayidle -w idlehint 1500 timeout 1500 'systemctl suspend'
