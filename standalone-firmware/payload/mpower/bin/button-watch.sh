#!/bin/sh
# Physical reset button (/dev/gpio_reset):
#   hold about 2s → reboot
# Never use a long hold for NetRelayMP factory reset: stock firmware can erase
# /etc/persistent before an overlay process can reliably intercept the event.
# Owning this device reduces chance of stock Ubiquiti wipe (yellow LED / :8080).
# Stock factory still deletes /etc/persistent if firmware runs restore-default.
ROOT=/etc/persistent/mpower
DEV=/dev/gpio_reset
LOG=/tmp/mpower-button.log
LOCK=/tmp/mpower-button.lock
NEED_REBOOT=2

log() { echo "$(date 2>/dev/null) $*" >> "$LOG"; tail -n 40 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"; }

[ -c "$DEV" ] || { log "no $DEV — exit"; exit 0; }

# Only one reader/guard may own the reset device.
if ! mkdir "$LOCK" 2>/dev/null; then
  owner=$(cat "$LOCK/pid" 2>/dev/null)
  if [ -n "$owner" ] && kill -0 "$owner" 2>/dev/null; then
    log "already running pid=$owner — exit"
    exit 0
  fi
  rm -rf "$LOCK" 2>/dev/null
  mkdir "$LOCK" 2>/dev/null || exit 0
fi
echo $$ > "$LOCK/pid"

# Exclusive reader: stock wevent may also watch reset; keep it stopped because
# mca-monitor can respawn it after the initial kill.
killall wevent 2>/dev/null || true
(
  while kill -0 $$ 2>/dev/null; do
    killall wevent 2>/dev/null || true
    killall mca-monitor 2>/dev/null || true
    sleep 1
  done
) &
GUARD_PID=$!
trap 'kill "$GUARD_PID" 2>/dev/null; rm -rf "$LOCK" 2>/dev/null' EXIT INT TERM

log "button watch start reboot>=${NEED_REBOOT}s; factory reset is web-only"

while true; do
  val=$(cat "$DEV" 2>/dev/null)
  val=$(printf '%s' "$val" | tr -cd '0-9')
  [ -n "$val" ] || continue
  log "button hold ${val}s"
  if [ "$val" -ge "$NEED_REBOOT" ] 2>/dev/null; then
    log "hold >= $NEED_REBOOT — reboot"
    sync
    reboot
    exit 0
  fi
done
