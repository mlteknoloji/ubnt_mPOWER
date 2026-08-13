#!/bin/sh
ROOT=/etc/persistent/mpower
WWW=$ROOT/www

pingwatch_enabled() {
  [ -f "$ROOT/ping.conf" ] || return 1
  grep -q '^enabled[123]=1$' "$ROOT/ping.conf" 2>/dev/null ||
    grep -q '^enabled=1$' "$ROOT/ping.conf" 2>/dev/null
}

# BusyBox killall only matches argv0 (often "sh"), not the script name.
kill_pat() {
  pat=$1
  ps w 2>/dev/null | grep "$pat" | grep -v grep | while read pid rest; do
    case "$pid" in
      ''|*[!0-9]*) ;;
      *) kill "$pid" 2>/dev/null ;;
    esac
  done
}

stop_helpers() {
  kill_pat 'mpower/bin/watchdog.sh'
  kill_pat 'mpower/bin/ping-watch.sh'
  kill_pat 'mpower/bin/udp-discover.sh'
  kill_pat 'mpower/bin/udp-beacon'
  kill_pat 'mpower/bin/button-watch.sh'
  kill_pat 'mpower/bin/mqtt-client.sh'
  kill_pat 'cgi-bin/scheduler.sh'
  # only our port-8088 httpd (stock uses lighttpd)
  ps w 2>/dev/null | grep 'httpd -p 8088' | grep -v grep | while read pid rest; do
    case "$pid" in ''|*[!0-9]*) ;; *) kill "$pid" 2>/dev/null ;; esac
  done
  sleep 1
}

case "$1" in
  stop)
    stop_helpers
    exit 0
    ;;
  start|'') ;;
  *) echo "usage: $0 {start|stop}" >&2; exit 2 ;;
esac

[ -d "$WWW" ] || exit 1
[ -x "$ROOT/bin/boot-mark.sh" ] && "$ROOT/bin/boot-mark.sh" service.start
stop_helpers

# Build clock rules immediately. Rebuild solar rules once asynchronous time
# synchronization completes, so the web page is never required for schedules.
/bin/sh "$ROOT/bin/schedule-cron.sh" >>/tmp/mpower-scheduler.log 2>&1
(
  /bin/sh "$ROOT/bin/time-sync.sh" >/tmp/mpower-ntp.log 2>&1
  /bin/sh "$ROOT/bin/schedule-cron.sh" >>/tmp/mpower-scheduler.log 2>&1
) &
/sbin/httpd -p 8088 -h "$WWW"
[ -x "$ROOT/bin/boot-mark.sh" ] && "$ROOT/bin/boot-mark.sh" web.8088.full
[ -f $ROOT/mqtt.conf ] && grep -q '^enabled=1' $ROOT/mqtt.conf && \
  /bin/sh $ROOT/bin/mqtt-client.sh >/tmp/mpower-mqtt.log 2>&1 &
[ -f $ROOT/wifi.conf ] && /bin/sh $ROOT/bin/wifi-client.sh >/tmp/mpower-wifi.log 2>&1 &
/bin/sh $ROOT/bin/watchdog.sh >/tmp/mpower-watchdog.log 2>&1 &
pingwatch_enabled && /bin/sh $ROOT/bin/ping-watch.sh >/tmp/mpower-pingwatch.log 2>&1 &
/bin/sh $ROOT/bin/udp-discover.sh >/tmp/mpower-udp-discover.log 2>&1 &
[ -x "$ROOT/bin/boot-mark.sh" ] && "$ROOT/bin/boot-mark.sh" services.background.started
# Own gpio_reset (stock wevent killed inside button-watch) so yellow-LED wipe is less likely
/bin/sh $ROOT/bin/button-watch.sh >/tmp/mpower-button.log 2>&1 &
exit 0
