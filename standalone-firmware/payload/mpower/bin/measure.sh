#!/bin/sh
# Performance baseline: process spawn rate, load and free RAM.
# Usage: measure.sh [seconds=60] [label]
# Run it before and after a change with the same device state (MQTT/ping-watch
# on/off, web page open/closed) and compare "forks/min".
secs=${1:-60}
label=${2:-run}
case "$secs" in ''|*[!0-9]*|0) secs=60 ;; esac

forks() { while read k v; do [ "$k" = processes ] && { echo "$v"; return; }; done < /proc/stat; }
mem() { while read k v u; do [ "$k" = "$1:" ] && { echo "$v"; return; }; done < /proc/meminfo; }

f0=$(forks)
read u0 i0 < /proc/uptime
sleep "$secs"
f1=$(forks)
read u1 i1 < /proc/uptime
read l1 l5 l15 rest < /proc/loadavg

n=$((f1 - f0))
# Integer idle percentage from /proc/uptime idle seconds (centiseconds math).
du=$(( ${u1%.*}${u1#*.} - ${u0%.*}${u0#*.} ))
di=$(( ${i1%.*}${i1#*.} - ${i0%.*}${i0#*.} ))
[ "$du" -gt 0 ] && idle=$((di * 100 / du)) || idle=?

printf '%s label=%s secs=%s forks=%s forks/min=%s cpu_idle=%s%% load=%s/%s/%s memfree_kb=%s cached_kb=%s\n' \
  "$(date '+%Y-%m-%d %H:%M:%S')" "$label" "$secs" "$n" "$((n * 60 / secs))" "$idle" \
  "$l1" "$l5" "$l15" "$(mem MemFree)" "$(mem Cached)" | tee -a /tmp/mpower-measure.log

# Our long-lived processes and their memory (VSZ column from BusyBox ps).
# [8] keeps this grep's own command line from matching the watchdog's patterns.
ps w 2>/dev/null | grep -e 'mpower/' -e 'httpd -p 80[8]8' | grep -v grep
