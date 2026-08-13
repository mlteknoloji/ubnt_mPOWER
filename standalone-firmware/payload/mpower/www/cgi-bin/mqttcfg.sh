#!/bin/sh
. "$(dirname "$0")/common.sh"
. "$(dirname "$0")/auth.sh"
cfg=$MP_ROOT/mqtt.conf
PIDFILE=/tmp/mpower-mqtt.pid
STATUS=/tmp/mpower-mqtt-status.json
action=$(query_get action)

json_esc() { printf '%s' "$1" | sed 's/\\/\\\\/g;s/"/\\"/g'; }

case "$action" in
  status)
    json_header
    if [ -f "$STATUS" ]; then cat "$STATUS"
    elif [ -f "$PIDFILE" ]; then printf '{"state":"connecting","code":0,"message":"connecting"}'
    else printf '{"state":"stopped","code":0,"message":"stopped"}'
    fi
    ;;
  ''|get)
    json_header
    enabled=0; host=; port=1883; user=; prefix=mpower/mltek; interval=15; ha=0; custom=
    [ -f "$cfg" ] && {
      enabled=$(sed -n 's/^enabled=//p' "$cfg"|head -1)
      host=$(sed -n 's/^host=//p' "$cfg"|head -1)
      port=$(sed -n 's/^port=//p' "$cfg"|head -1)
      user=$(sed -n 's/^user=//p' "$cfg"|head -1)
      prefix=$(sed -n 's/^prefix=//p' "$cfg"|head -1)
      interval=$(sed -n 's/^interval=//p' "$cfg"|head -1)
      ha=$(sed -n 's/^ha_discovery=//p' "$cfg"|head -1)
      custom=$(sed -n 's/^custom=//p' "$cfg"|head -1)
    }
    printf '{"ok":true,"enabled":%s,"host":"%s","port":%s,"user":"%s","prefix":"%s","interval":%s,"ha_discovery":%s,"custom":"%s","has_password":%s}' \
      "${enabled:-0}" "$(json_esc "$host")" "${port:-1883}" "$(json_esc "$user")" "$(json_esc "${prefix:-mpower/mltek}")" "${interval:-15}" "${ha:-0}" \
      "$(json_esc "$custom")" \
      "$([ -f "$cfg" ] && grep -q '^pass=.' "$cfg" && echo true || echo false)"
    ;;
  set)
    require_token || exit 0
    enabled=$(query_get enabled)
    host=$(url_decode "$(query_get host)")
    port=$(query_get port)
    user=$(url_decode "$(query_get user)")
    pass=$(url_decode "$(query_get pass)")
    prefix=$(url_decode "$(query_get prefix)")
    interval=$(query_get interval)
    ha=$(query_get ha_discovery)
    custom=$(url_decode "$(query_get custom)")
    # single-line payload for conf + MQTT (strip CR/LF, trim length)
    custom=$(printf '%s' "$custom" | tr '\r\n' '  ' | cut -c1-240)
    [ -z "$port" ] && port=1883
    [ -z "$prefix" ] && prefix=mpower/mltek
    [ "$prefix" = netrelay/mltek ] && prefix=mpower/mltek
    [ -z "$interval" ] && interval=15
    [ -z "$ha" ] && ha=0
    case "$enabled" in 0|1) ;; *) json_header; printf '{"ok":false,"error":"invalid enabled"}'; exit 0;; esac
    if [ "$enabled" = 1 ] && [ -z "$host" ]; then
      json_header; printf '{"ok":false,"error":"broker required"}'; exit 0
    fi
    case "$port" in ''|*[!0-9]*) json_header; printf '{"ok":false,"error":"invalid port"}'; exit 0;; esac
    [ "$port" -ge 1 ] 2>/dev/null && [ "$port" -le 65535 ] 2>/dev/null || {
      json_header; printf '{"ok":false,"error":"invalid port"}'; exit 0
    }
    case "$interval" in ''|*[!0-9]*) json_header; printf '{"ok":false,"error":"invalid interval"}'; exit 0;; esac
    oldpass=
    [ -f "$cfg" ] && oldpass=$(sed -n 's/^pass=//p' "$cfg"|head -1)
    [ -z "$pass" ] && pass=$oldpass
    umask 077
    {
      printf 'enabled=%s\n' "$enabled"
      printf 'host=%s\n' "$host"
      printf 'port=%s\n' "$port"
      printf 'user=%s\n' "$user"
      printf 'pass=%s\n' "$pass"
      printf 'prefix=%s\n' "$prefix"
      printf 'interval=%s\n' "$interval"
      printf 'ha_discovery=%s\n' "$ha"
      printf 'custom=%s\n' "$custom"
    } > "$cfg"
    cfgmtd -w -p /etc >/dev/null 2>&1
    if [ -f "$PIDFILE" ]; then
      oldpid=$(cat "$PIDFILE" 2>/dev/null)
      case "$oldpid" in ''|*[!0-9]*) ;; *) kill "$oldpid" 2>/dev/null ;; esac
      rm -f "$PIDFILE"
      sleep 1
    fi
    # Stop clients started by older overlays that did not create a PID file.
    ps w 2>/dev/null | grep 'mpower/bin/mqtt-client.sh' | grep -v grep | while read oldpid rest; do
      case "$oldpid" in ''|*[!0-9]*) ;; *) kill "$oldpid" 2>/dev/null ;; esac
    done
    rm -f "$STATUS"
    [ "$enabled" = 1 ] && /bin/sh /etc/persistent/mpower/bin/mqtt-client.sh >/tmp/mpower-mqtt.log 2>&1 &
    json_header; printf '{"ok":true}'
    ;;
  *) json_header; printf '{"ok":false,"error":"unknown"}' ;;
esac
