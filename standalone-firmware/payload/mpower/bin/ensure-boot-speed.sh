#!/bin/sh
# Persist boot-acceleration hooks into stock system.cfg (survives reboot via cfgmtd).
# 1) cron every minute → early-cron.sh (kills sleep 180, starts overlay)
# 2) pwdog hook switched off (see below)
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

# pwdog hook removed: stock starts it as "pwdog -d 180" whatever pwdog.delay
# says, so it never fired before cron.9 did. It then pinged every 10 s and ran
# early-cron.sh on each failure for the whole uptime. cron.9 (every minute)
# remains the boot accelerator.
put pwdog.status disabled

if cfgmtd -w -p /etc -f "$CFG" > "$LOG" 2>&1; then
  echo "boot-speed hooks saved (cron.9, pwdog off)" >> "$LOG"
  exit 0
fi
echo "boot-speed save failed" >> "$LOG"
exit 1
