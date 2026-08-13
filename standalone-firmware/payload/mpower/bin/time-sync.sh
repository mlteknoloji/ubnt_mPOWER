#!/bin/sh
# Sync clock — needs a reachable NTP host (internet or LAN NTP).
# Without default route / DNS this will fail; use browser time set instead.
MP_ROOT=/etc/persistent/mpower
cfg=$MP_ROOT/time.conf
LOG=/tmp/mpower-ntp.log
: > "$LOG"

ntp=pool.ntp.org
[ -f "$cfg" ] && ntp=$(sed -n 's/^ntp=//p' "$cfg" | head -1)
[ -n "$ntp" ] || ntp=pool.ntp.org

echo "start $(date 2>/dev/null) ntp=$ntp" >> "$LOG"

# Old ntpclient/rdate builds can wait forever when DNS or UDP/123 is blocked.
# Keep service startup bounded so a failed clock sync never blocks the web UI.
run_limited() {
  "$@" >> "$LOG" 2>&1 &
  pid=$!
  left=8
  while kill -0 "$pid" 2>/dev/null && [ "$left" -gt 0 ]; do
    sleep 1
    left=$((left - 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null
    return 1
  fi
  wait "$pid"
}

# Quick network check
if ! route -n 2>/dev/null | grep -q '^0\.0\.0\.0'; then
  echo "no default route — Wi-Fi/internet required for NTP" >> "$LOG"
  # still try in case host is on local subnet
fi

try_ntp() {
  h=$1
  [ -n "$h" ] || return 1
  echo "try ntpclient $h" >> "$LOG"
  if run_limited /bin/ntpclient -s -h "$h"; then
    echo "ok ntpclient $h -> $(date)" >> "$LOG"
    return 0
  fi
  echo "try rdate $h" >> "$LOG"
  if run_limited /bin/rdate -s "$h"; then
    echo "ok rdate $h -> $(date)" >> "$LOG"
    return 0
  fi
  return 1
}

# Configured host first, then public IP fallbacks (no DNS needed)
try_ntp "$ntp" && exit 0
try_ntp 216.239.35.0 && exit 0
try_ntp 162.159.200.1 && exit 0
try_ntp 129.6.15.28 && exit 0

echo "time sync failed — set time from browser or connect Wi-Fi" >> "$LOG"
exit 1
