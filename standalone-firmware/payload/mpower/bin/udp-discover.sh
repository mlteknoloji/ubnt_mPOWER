#!/bin/sh
# UDP announce for NetRelay Bulucu (NRfinder.py) on :5555.
# Format: netRelay is here, {name}, {device_id}, {mac}, {serial}
# device_id always starts with NetRelayMP so finder opens :8088.
ROOT=/etc/persistent/mpower
BIN=$ROOT/bin/udp-beacon
PORT=5555
INTERVAL=5
LOG=/tmp/mpower-udp-discover.log

[ -x "$BIN" ] || chmod 755 "$BIN" 2>/dev/null

build_msg() {
  mac=$(ifconfig ath0 2>/dev/null | sed -n 's/.*HWaddr \([0-9A-Fa-f:]*\).*/\1/p' | tr -d ':' | tr 'A-F' 'a-f')
  [ -n "$mac" ] || mac=$(ifconfig br0 2>/dev/null | sed -n 's/.*HWaddr \([0-9A-Fa-f:]*\).*/\1/p' | tr -d ':' | tr 'A-F' 'a-f')
  [ -n "$mac" ] || mac=unknown
  hostname=$(uname -n 2>/dev/null | tr -cd 'A-Za-z0-9._-')
  name=$(sed -n 's/^name=//p' $ROOT/device.conf 2>/dev/null | head -1 | tr -cd 'A-Za-z0-9 ._:-')
  [ -n "$name" ] || name=NetRelayMP
  [ -n "$hostname" ] || hostname=mpower
  fw=$(cat $ROOT/.installed 2>/dev/null | tr -cd 'A-Za-z0-9._-')
  [ -n "$fw" ] || fw=unknown
  # Keep NetRelayMP in id so NRfinder always uses http://IP:8088
  printf 'netRelay is here, %s, NetRelayMP/%s, %s, %s' "$name" "$fw" "$mac" "$hostname"
}

# Collect directed broadcast addresses (BusyBox ifconfig)
list_bcasts() {
  ifconfig 2>/dev/null | sed -n 's/.*Bcast:\([0-9.]*\).*/\1/p' | sort | uniq
}

# Shell fallback when native udp-beacon is missing / fails
send_nc() {
  msg=$1
  port=$2
  command -v nc >/dev/null 2>&1 || return 1
  for dest in 255.255.255.255 $(list_bcasts); do
    [ -n "$dest" ] || continue
    printf '%s' "$msg" | nc -u -b -w1 "$dest" "$port" >/dev/null 2>&1 || \
    printf '%s' "$msg" | nc -u -w1 "$dest" "$port" >/dev/null 2>&1 || true
  done
  return 0
}

send_once() {
  msg=$1
  ok=0
  if [ -x "$BIN" ]; then
    if "$BIN" send "$PORT" "$msg" >> "$LOG" 2>&1; then
      ok=1
    fi
  fi
  if [ "$ok" != 1 ]; then
    send_nc "$msg" "$PORT" >> "$LOG" 2>&1 || true
  fi
}

echo "$(date 2>/dev/null) announce port=$PORT interval=$INTERVAL beacon=$([ -x "$BIN" ] && echo yes || echo no)" >> "$LOG"
[ -x "$ROOT/bin/boot-mark.sh" ] && "$ROOT/bin/boot-mark.sh" udp.5555.started

# Prefer one long-lived native socket for both broadcast and discovery replies.
# Keep this wrapper alive so watchdog can identify exactly one managed service.
if [ -x "$BIN" ]; then
  msg=$(build_msg)
  "$BIN" both "$PORT" /tmp/mpower-udp-peers.json "$INTERVAL" "$msg" >> "$LOG" 2>&1 &
  beacon_pid=$!
  trap 'kill "$beacon_pid" 2>/dev/null; exit 0' INT TERM EXIT
  wait "$beacon_pid"
  trap - INT TERM EXIT
  echo "$(date 2>/dev/null) native beacon stopped; using shell fallback" >> "$LOG"
fi

# Fallback for devices where the native helper cannot stay running.
while true; do
  msg=$(build_msg)
  send_nc "$msg" "$PORT" >> "$LOG" 2>&1 || true
  sleep "$INTERVAL"
done
