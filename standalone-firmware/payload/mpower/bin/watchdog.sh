#!/bin/sh
# NetRelayMP watchdog: Wi-Fi, NTP, MQTT, httpd.
ROOT=/etc/persistent/mpower
LOG=/tmp/mpower-watchdog.log
interval=30
MQTT_RETRY_SECONDS=30
WIFI_RETRY_SECONDS=60
wifi_fail=0
last_mqtt_attempt=0

log() { echo "$(date 2>/dev/null) $*" >> "$LOG"; tail -n 80 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"; }

ensure_httpd() {
  n=$(ps w 2>/dev/null | grep 'httpd -p 8088' | grep -v grep | wc -l)
  case "$n" in
    ''|0)
      log "httpd down — start"
      /sbin/httpd -p 8088 -h "$ROOT/www"
      return 0
      ;;
    *) return 0 ;;
  esac
  # Duplicates: replace the set with exactly one clean listener.
  log "httpd duplicates=$n — cleanup"
  ps w 2>/dev/null | grep 'httpd -p 8088' | grep -v grep | while read pid rest; do
    case "$pid" in ''|*[!0-9]*) continue ;; esac
    kill "$pid" 2>/dev/null
  done
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
  year=$(date +%Y 2>/dev/null)
  [ "$year" -ge 2020 ] 2>/dev/null && return 0
  # only try if default route exists
  route -n 2>/dev/null | grep -q '^0\.0\.0\.0' || return 0
  log "ntp attempt"
  /bin/sh "$ROOT/bin/time-sync.sh" >> /tmp/mpower-ntp.log 2>&1 || true
}

ensure_mqtt() {
  if [ ! -f "$ROOT/mqtt.conf" ] || ! grep -q '^enabled=1' "$ROOT/mqtt.conf"; then
    # MQTT is disabled: make sure no previously started client remains alive.
    if [ -f /tmp/mpower-mqtt.pid ]; then
      mqtt_pid=$(cat /tmp/mpower-mqtt.pid 2>/dev/null)
      case "$mqtt_pid" in ''|*[!0-9]*) ;; *) kill "$mqtt_pid" 2>/dev/null ;; esac
      rm -f /tmp/mpower-mqtt.pid
    fi
    return 0
  fi
  if ! ps w 2>/dev/null | grep 'mpower/bin/mqtt-client.sh' | grep -vq grep; then
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
  if ! ps w 2>/dev/null | grep '[c]rond' >/dev/null; then
    log "crond restart"
    /bin/crond -b -S
  fi
  if ! grep -q '^# BEGIN NETRELAYMP SCHEDULES$' /etc/crontabs/ubnt 2>/dev/null; then
    log "schedule cron rebuild"
    /bin/sh "$ROOT/bin/schedule-cron.sh" >> /tmp/mpower-scheduler.log 2>&1
  fi
}

ensure_pingwatch() {
  if ! grep -q '^enabled[123]=1$' "$ROOT/ping.conf" 2>/dev/null &&
     ! grep -q '^enabled=1$' "$ROOT/ping.conf" 2>/dev/null; then
    # No enabled rule: keep the worker stopped to save CPU and memory.
    ps w 2>/dev/null | grep 'mpower/bin/ping-watch.sh' | grep -v grep | while read pid rest; do
      case "$pid" in ''|*[!0-9]*) ;; *) kill "$pid" 2>/dev/null ;; esac
    done
    return 0
  fi
  if ! ps w 2>/dev/null | grep 'mpower/bin/ping-watch.sh' | grep -vq grep; then
    log "ping-watch restart"
    /bin/sh "$ROOT/bin/ping-watch.sh" >> /tmp/mpower-pingwatch.log 2>&1 &
  fi
}

ensure_udp_discover() {
  # udp-beacon only lives for one send; the long-lived process is udp-discover.sh.
  # Matching udp-beacon caused a new shell every 30s until the unit OOMed.
  if ! ps w 2>/dev/null | grep 'mpower/bin/udp-discover.sh' | grep -vq grep; then
    log "udp-discover restart"
    /bin/sh "$ROOT/bin/udp-discover.sh" >> /tmp/mpower-udp-discover.log 2>&1 &
  fi
}

ensure_button() {
  if ! ps w 2>/dev/null | grep 'mpower/bin/button-watch.sh' | grep -vq grep; then
    log "button-watch restart"
    /bin/sh "$ROOT/bin/button-watch.sh" >> /tmp/mpower-button.log 2>&1 &
  fi
}

log "watchdog start"
while true; do
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
