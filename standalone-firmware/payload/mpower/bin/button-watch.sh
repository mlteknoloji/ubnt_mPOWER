#!/bin/sh
# Physical reset button (/dev/gpio_reset):
#   hold ~2–9s  → reboot (settings kept)
#   hold >= ~10s → soft factory reset (clear NetRelayMP settings, keep overlay code)
# Never allow stock Ubiquiti wipe of /etc/persistent.
ROOT=/etc/persistent/mpower
DEV=/dev/gpio_reset
LOG=/tmp/mpower-button.log
LOCK=/tmp/mpower-button.lock
NEED_REBOOT=2
NEED_SOFT_FACTORY=10
GUARD_INTERVAL=2

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

clear_wipe_flags() {
  rm -f /etc/.reset_to_default /etc/persistent/.reset_to_default \
    /tmp/.reset_to_default /var/run/reset_to_default \
    /etc/persistent/.factory_reset /tmp/.factory_reset 2>/dev/null || true
}

# Stock wevent reboots on a long reset hold, and u-boot wipes cfg (the overlay)
# if the button is still down. init respawns it from /etc/inittab, so killing
# it (and mca-monitor) made init restart both every ~3 s: ~50-80% CPU on
# 2026-10-30. A STOPPED process never exits, so init leaves it alone and it
# cannot act. Do not SIGHUP init to reload inittab: on BusyBox 1.11 that
# runs the ::restart action, which shuts the whole system down.
freeze_wevent() {
  for wpid in $(pidof wevent 2>/dev/null); do
    wst=; read wst < "/proc/$wpid/stat" 2>/dev/null
    set -- $wst   # "pid (comm) STATE ..."
    if [ "$3" != T ]; then
      kill -STOP "$wpid" 2>/dev/null && log "stock wevent $wpid frozen (SIGSTOP)"
    fi
  done
}
freeze_wevent
clear_wipe_flags
(
  while kill -0 $$ 2>/dev/null; do
    if [ -f /etc/.reset_to_default ] || [ -f /etc/persistent/.reset_to_default ] || \
       [ -f /tmp/.reset_to_default ] || [ -f /var/run/reset_to_default ]; then
      log "stock wipe flag seen — clear + reboot to keep overlay"
      clear_wipe_flags
      sync
      reboot
      exit 0
    fi
    # A new wevent only appears if the frozen one died (e.g. factory-reset's
    # killall); freeze that one too. mca-monitor is left alone.
    freeze_wevent
    sleep "$GUARD_INTERVAL"
  done
) &
GUARD_PID=$!
trap 'kill "$GUARD_PID" 2>/dev/null; rm -rf "$LOCK" 2>/dev/null' EXIT INT TERM

log "button watch start reboot>=${NEED_REBOOT}s soft-factory>=${NEED_SOFT_FACTORY}s"

while true; do
  val=$(cat "$DEV" 2>/dev/null)
  val=$(printf '%s' "$val" | tr -cd '0-9')
  [ -n "$val" ] || continue
  log "button hold ${val}s"
  clear_wipe_flags
  if [ "$val" -ge "$NEED_SOFT_FACTORY" ] 2>/dev/null; then
    log "hold >= $NEED_SOFT_FACTORY — soft factory (settings cleared, overlay kept)"
    if [ -x "$ROOT/bin/factory-reset.sh" ]; then
      /bin/sh "$ROOT/bin/factory-reset.sh" button
    else
      log "factory-reset.sh missing — reboot only"
      sync
      reboot
    fi
    exit 0
  fi
  if [ "$val" -ge "$NEED_REBOOT" ] 2>/dev/null; then
    log "hold >= $NEED_REBOOT — reboot (keep overlay + settings)"
    sync
    reboot
    exit 0
  fi
done
