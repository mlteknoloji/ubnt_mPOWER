#!/bin/sh
LOG=/tmp/mpower-boot-timeline.log
up=$(cut -d. -f1 /proc/uptime 2>/dev/null)
[ -n "$up" ] || up=0
printf '%s\t%s\n' "$up" "$*" >> "$LOG"
exit 0
