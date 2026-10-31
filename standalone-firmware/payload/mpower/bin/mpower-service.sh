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

is_running() {
  ps w 2>/dev/null | grep "$1" | grep -vq grep
}

start_script() {
  pattern=$1
  script=$2
  logfile=$3
  if ! is_running "$pattern"; then
    /bin/sh "$script" >>"$logfile" 2>&1 &
  fi
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

# Serve the UI before schedule compilation and network initialization.
is_running 'httpd -p 8088' || /sbin/httpd -p 8088 -h "$WWW"
[ -x "$ROOT/bin/boot-mark.sh" ] && "$ROOT/bin/boot-mark.sh" web.8088.full

# Build clock rules immediately. Rebuild solar rules once asynchronous time
# synchronization completes, so the web page is never required for schedules.
/bin/sh "$ROOT/bin/schedule-cron.sh" >>/tmp/mpower-scheduler.log 2>&1
if ! is_running 'mpower/bin/time-sync.sh'; then
  (
    /bin/sh "$ROOT/bin/time-sync.sh" >/tmp/mpower-ntp.log 2>&1
    /bin/sh "$ROOT/bin/schedule-cron.sh" >>/tmp/mpower-scheduler.log 2>&1
  ) &
fi
[ -f $ROOT/mqtt.conf ] && grep -q '^enabled=1' $ROOT/mqtt.conf && \
  start_script 'mpower/bin/mqtt-client.sh' "$ROOT/bin/mqtt-client.sh" /tmp/mpower-mqtt.log
# "boot": keep the link stock already made instead of reconnecting.
if [ -f $ROOT/wifi.conf ] && ! is_running 'mpower/bin/wifi-client.sh'; then
  /bin/sh "$ROOT/bin/wifi-client.sh" boot >>/tmp/mpower-wifi.log 2>&1 &
fi
start_script 'mpower/bin/watchdog.sh' "$ROOT/bin/watchdog.sh" /tmp/mpower-watchdog.log
pingwatch_enabled && start_script 'mpower/bin/ping-watch.sh' "$ROOT/bin/ping-watch.sh" /tmp/mpower-pingwatch.log
start_script 'mpower/bin/udp-discover.sh' "$ROOT/bin/udp-discover.sh" /tmp/mpower-udp-discover.log
[ -x "$ROOT/bin/boot-mark.sh" ] && "$ROOT/bin/boot-mark.sh" services.background.started
# Keep the rc.prestart button owner alive; start it only when missing.
start_script 'mpower/bin/button-watch.sh' "$ROOT/bin/button-watch.sh" /tmp/mpower-button.log
exit 0
