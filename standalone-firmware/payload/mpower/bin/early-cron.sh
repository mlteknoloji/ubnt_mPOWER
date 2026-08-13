#!/bin/sh
# Run once per boot (from stock crond / optional pwdog).
# Cuts the stock /usr/etc/delaystart.sh "sleep 180" so overlay starts
# ~1 minute after power-on instead of ~4–5 minutes.
ROOT=/etc/persistent/mpower
MARK=/tmp/mpower-early-cron.done
LOG=/tmp/mpower-early-cron.log

log() { echo "$(date 2>/dev/null) $*" >> "$LOG"; }

[ -f "$MARK" ] && exit 0
touch "$MARK"

[ -x "$ROOT/bin/boot-mark.sh" ] && "$ROOT/bin/boot-mark.sh" cron.early

# Stop stock fail-safe wait (delaystart.sh: sleep 180; rc.poststart)
# Match BusyBox ps lines carefully.
pkill -f '/usr/etc/delaystart.sh' 2>/dev/null || true
# Kill long sleep left behind by delaystart (typical "sleep 180")
ps w 2>/dev/null | grep '[s]leep 180' | while read pid rest; do
  case "$pid" in ''|*[!0-9]*) ;; *) kill "$pid" 2>/dev/null || true ;; esac
done
ps w 2>/dev/null | grep '[s]leep 1[0-9][0-9]' | while read pid rest; do
  case "$pid" in ''|*[!0-9]*) ;; *) kill "$pid" 2>/dev/null || true ;; esac
done

log "delaystart interrupted — starting overlay"

# Full services (httpd :8088, wifi, discovery, …)
if [ -x "$ROOT/bin/mpower-service.sh" ]; then
  /bin/sh "$ROOT/bin/mpower-service.sh" start >/tmp/mpower-standalone.log 2>&1 &
else
  /bin/sh "$ROOT/bin/early-web.sh" >/tmp/mpower-early-web.log 2>&1 &
  [ -f "$ROOT/wifi.conf" ] && /bin/sh "$ROOT/bin/wifi-client.sh" >/tmp/mpower-wifi.log 2>&1 &
fi

[ -x "$ROOT/bin/boot-mark.sh" ] && "$ROOT/bin/boot-mark.sh" cron.early.services
exit 0
