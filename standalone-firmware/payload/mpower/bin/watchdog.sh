#!/bin/sh
# NetRelayMP watchdog: Wi-Fi, NTP, MQTT, httpd.
ROOT=/etc/persistent/mpower
LOG=/tmp/mpower-watchdog.log
interval=30
MQTT_RETRY_SECONDS=30
WIFI_RETRY_SECONDS=60
wifi_fail=0
last_mqtt_attempt=0

ntp_ok=0

log() { echo "$(date 2>/dev/null) $*" >> "$LOG"; tail -n 80 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"; }

# One `ps w` per tick (snapshot in $PS); checks below match it in the shell.
# Before: ~8 separate `ps w | grep | grep -v grep` pipelines every 30 s.
NL='
'
snap_ps() { PS=$(ps w 2>/dev/null); }
# Lines containing "grep" are skipped, exactly like the old `| grep -v grep`:
# a shell whose command line merely mentions a pattern (e.g. an SSH diagnostic
# running `grep 'httpd -p 8088'`) must never count as, or be killed as, httpd.
# count_ps PATTERN -> cnt
count_ps() {
  cnt=0; oldifs=$IFS; IFS=$NL; set -f
  for l in $PS; do
    case "$l" in *grep*) ;; *"$1"*) cnt=$((cnt + 1)) ;; esac
  done
  set +f; IFS=$oldifs
}
running() { count_ps "$1"; [ "$cnt" -gt 0 ]; }
# kill_ps PATTERN: kill every process in the snapshot whose line matches
kill_ps() {
  kpat=$1; oldifs=$IFS; IFS=$NL; set -f
  for l in $PS; do
    case "$l" in *grep*) ;; *"$kpat"*)
      IFS=' '; set -- $l; IFS=$NL
      case "$1" in ''|*[!0-9]*) ;; *) kill "$1" 2>/dev/null ;; esac
      ;;
    esac
  done
  set +f; IFS=$oldifs
}
# file_has FILE PATTERN [PATTERN2]: true if a whole line matches a shell
# pattern (read builtin, no grep fork). `|` does not work inside a variable
# pattern, so alternatives are passed as separate arguments.
file_has() {
  [ -f "$1" ] || return 1
  while IFS= read fl; do
    case "$fl" in $2) return 0 ;; esac
    [ -n "$3" ] && case "$fl" in $3) return 0 ;; esac
  done < "$1"
  return 1
}

# httpd_listeners -> hl_pids/hl_n: only daemonized listeners (PPID 1).
# BusyBox httpd forks one child per request with the same command line;
# counting those as "duplicates" made the watchdog kill httpd (and the
# request in flight) whenever a tick hit a running CGI.
httpd_listeners() {
  hl_pids=; hl_n=0; oldifs=$IFS; IFS=$NL; set -f
  for l in $PS; do
    case "$l" in *grep*) ;; *'httpd -p 8088'*)
      IFS=' '; set -- $l
      hp=$1; pp=
      if [ -r "/proc/$hp/stat" ]; then
        read hst < "/proc/$hp/stat"; set -- $hst; pp=$4
      fi
      IFS=$NL
      [ "$pp" = 1 ] && { hl_pids="$hl_pids $hp"; hl_n=$((hl_n + 1)); }
      ;;
    esac
  done
  set +f; IFS=$oldifs
}

ensure_httpd() {
  count_ps 'httpd -p 8088'; n=$cnt
  if [ "$n" = 0 ]; then
    log "httpd down — start"
    /sbin/httpd -p 8088 -h "$ROOT/www"
    return 0
  fi
  httpd_listeners
  [ "$hl_n" -le 1 ] && return 0
  # Real duplicate listeners: replace them with exactly one.
  log "httpd listeners=$hl_n — cleanup"
  for hp in $hl_pids; do kill "$hp" 2>/dev/null; done
  sleep 1
  /sbin/httpd -p 8088 -h "$ROOT/www"
}

ensure_wifi() {
  [ -f "$ROOT/wifi.conf" ] || {
    /bin/sh "$ROOT/bin/ap-control.sh" sync >/dev/null 2>&1 || true
    return 0
  }
  # Do not launch a second association/DHCP cycle while one is active.
  [ -d /tmp/mpower-wifi.lock ] && return 0
  # Invalid saved PSK length cannot succeed — keep AP, do not retry.
  if [ -f /tmp/mpower-wifi.hold ]; then
    hold_reason=$(cat /tmp/mpower-wifi.hold 2>/dev/null)
    if [ "$hold_reason" = bad_password ]; then
      wifi_fail=0
      /bin/sh "$ROOT/bin/ap-control.sh" sync >/dev/null 2>&1 || true
      return 0
    fi
  fi
  ip=$(ifconfig ath0 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p')
  ap=$(iwconfig ath0 2>/dev/null | sed -n 's/.*Access Point: \([^ ]*\).*/\1/p')
  associated=0
  case "$ap" in
    ''|Not-Associated|00:00:00:00:00:00) associated=0 ;;
    *) associated=1 ;;
  esac
  if [ "$associated" = 1 ] && [ -n "$ip" ] && [ "$ip" != "192.168.1.50" ]; then
    wifi_fail=0
    /bin/sh "$ROOT/bin/ap-control.sh" down >/dev/null 2>&1 || true
    return 0
  elif [ "$associated" = 1 ]; then
    # Associated but no real IP: renew DHCP only — do not tear down recovery AP.
    wifi_fail=0
    log "wifi associated, no DHCP lease — renew"
    /bin/sh "$ROOT/bin/network-apply.sh" >> /tmp/mpower-net.log 2>&1 || true
  else
    wifi_fail=$((wifi_fail + 1))
    # Recovery AP must stay up while STA is down. Retry in background so this
    # loop (httpd/MQTT) is not blocked for the association wait.
    /bin/sh "$ROOT/bin/ap-control.sh" sync >/dev/null 2>&1 || true
    now=$(date +%s 2>/dev/null || echo 0)
    last=0
    [ -f /tmp/mpower-wifi-result ] && last=$(sed -n 's/^ts=//p' /tmp/mpower-wifi-result | head -1)
    case "$now" in ''|*[!0-9]*) now=0 ;; esac
    case "$last" in ''|*[!0-9]*) last=0 ;; esac
    if [ "$last" -gt 0 ] && [ $((now - last)) -lt "$WIFI_RETRY_SECONDS" ]; then
      return 0
    fi
    log "wifi not associated (fail=$wifi_fail) — keep-ap retry"
    /bin/sh "$ROOT/bin/wifi-client.sh" keep-ap >> /tmp/mpower-wifi.log 2>&1 &
    wifi_fail=0
    return 0
  fi
  /bin/sh "$ROOT/bin/ap-control.sh" sync >/dev/null 2>&1 || true
}

ensure_ntp() {
  # Once the clock is valid it stays valid until reboot: stop checking.
  [ "$ntp_ok" = 1 ] && return 0
  year=$(date +%Y 2>/dev/null)
  if [ "$year" -ge 2020 ] 2>/dev/null; then
    ntp_ok=1
    # Sunrise/sunset rules are skipped while the clock is invalid; compile
    # them now instead of waiting for the 00:05 nightly rebuild.
    /bin/sh "$ROOT/bin/schedule-cron.sh" >> /tmp/mpower-scheduler.log 2>&1
    return 0
  fi
  # only try if default route exists
  route -n 2>/dev/null | grep -q '^0\.0\.0\.0' || return 0
  log "ntp attempt"
  /bin/sh "$ROOT/bin/time-sync.sh" >> /tmp/mpower-ntp.log 2>&1 || true
}

ensure_mqtt() {
  if ! file_has "$ROOT/mqtt.conf" 'enabled=1*'; then
    # MQTT is disabled: make sure no previously started client remains alive.
    if [ -f /tmp/mpower-mqtt.pid ]; then
      mqtt_pid=$(cat /tmp/mpower-mqtt.pid 2>/dev/null)
      case "$mqtt_pid" in ''|*[!0-9]*) ;; *) kill "$mqtt_pid" 2>/dev/null ;; esac
      rm -f /tmp/mpower-mqtt.pid
    fi
    return 0
  fi
  if ! running 'mpower/bin/mqtt-client.sh'; then
    now=$(date +%s 2>/dev/null || echo 0)
    case "$now" in ''|*[!0-9]*) now=0;; esac
    # Retry a failed or dropped MQTT connection at most once every 30 seconds.
    [ "$last_mqtt_attempt" -gt 0 ] && [ $((now-last_mqtt_attempt)) -lt "$MQTT_RETRY_SECONDS" ] && return 0
    last_mqtt_attempt=$now
    log "mqtt disconnected — retry connection"
    printf '{"state":"retrying","code":0,"message":"retrying"}\n' > /tmp/mpower-mqtt-status.json
    /bin/sh "$ROOT/bin/mqtt-client.sh" >> /tmp/mpower-mqtt.log 2>&1 &
  fi
}

ensure_schedule_cron() {
  if ! running 'crond'; then
    log "crond restart"
    /bin/crond -b -S
  fi
  if ! file_has /etc/crontabs/ubnt '# BEGIN NETRELAYMP SCHEDULES'; then
    log "schedule cron rebuild"
    /bin/sh "$ROOT/bin/schedule-cron.sh" >> /tmp/mpower-scheduler.log 2>&1
  fi
}

ensure_pingwatch() {
  if ! file_has "$ROOT/ping.conf" 'enabled[123]=1' 'enabled=1'; then
    # No enabled rule: keep the worker stopped to save CPU and memory.
    running 'mpower/bin/ping-watch.sh' && kill_ps 'mpower/bin/ping-watch.sh'
    return 0
  fi
  if ! running 'mpower/bin/ping-watch.sh'; then
    log "ping-watch restart"
    /bin/sh "$ROOT/bin/ping-watch.sh" >> /tmp/mpower-pingwatch.log 2>&1 &
  fi
}

ensure_udp_discover() {
  # udp-beacon only lives for one send; the long-lived process is udp-discover.sh.
  # Matching udp-beacon caused a new shell every 30s until the unit OOMed.
  if ! running 'mpower/bin/udp-discover.sh'; then
    log "udp-discover restart"
    /bin/sh "$ROOT/bin/udp-discover.sh" >> /tmp/mpower-udp-discover.log 2>&1 &
  fi
}

ensure_button() {
  if ! running 'mpower/bin/button-watch.sh'; then
    log "button-watch restart"
    /bin/sh "$ROOT/bin/button-watch.sh" >> /tmp/mpower-button.log 2>&1 &
  fi
}

log "watchdog start"
while true; do
  snap_ps
  ensure_httpd
  ensure_wifi
  ensure_ntp
  ensure_mqtt
  ensure_schedule_cron
  ensure_pingwatch
  ensure_udp_discover
  ensure_button
  sleep "$interval"
done
