#!/bin/sh
# Persist boot-acceleration hooks into stock system.cfg (survives reboot via cfgmtd).
# 1) cron every minute → early-cron.sh (kills sleep 180, starts overlay)
# 2) optional pwdog → same script a few seconds after rc start (faster)
ROOT=/etc/persistent/mpower
CFG=/tmp/system.cfg
LOG=/tmp/mpower-boot-speed.log
EARLY=/etc/persistent/mpower/bin/early-cron.sh

[ -f "$CFG" ] || { echo "system.cfg missing" > "$LOG"; exit 1; }
[ -x "$EARLY" ] || chmod 755 "$EARLY" 2>/dev/null || true

put() {
  key=$1
  value=$2
  tmp=/tmp/system.cfg.mp.$$
  grep -v "^${key}=" "$CFG" > "$tmp" 2>/dev/null || true
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  mv "$tmp" "$CFG"
}

del() {
  key=$1
  tmp=/tmp/system.cfg.mp.$$
  grep -v "^${key}=" "$CFG" > "$tmp" 2>/dev/null || true
  mv "$tmp" "$CFG"
}

# Remove legacy cron.1 early-boot keys (older builds)
del cron.1.status
del cron.1.user
del cron.1.job.1.status
del cron.1.job.1.schedule
del cron.1.job.1.cmd

# Slot 9 — keep clear of typical mFi outlet schedule slots (1–3)
put cron.status enabled
put cron.9.status enabled
put cron.9.user ubnt
put cron.9.job.1.status enabled
put cron.9.job.1.schedule '* * * * *'
put cron.9.job.1.cmd "$EARLY"

# Faster path: pwdog runs ~seconds after inittab respawn (same window as SSH).
# Ping a non-routable address so the failure command fires once; early-cron is idempotent.
put pwdog.status enabled
put pwdog.host 169.254.255.254
put pwdog.delay 5
put pwdog.retry 1
put pwdog.period 10
put pwdog.command "$EARLY"

if cfgmtd -w -p /etc -f "$CFG" > "$LOG" 2>&1; then
  echo "boot-speed hooks saved (cron.9 + pwdog)" >> "$LOG"
  exit 0
fi
echo "boot-speed save failed" >> "$LOG"
exit 1
