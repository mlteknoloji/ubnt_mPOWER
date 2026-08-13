#!/bin/sh
# REST API v1 + enable/disable from api.html.
. "$(dirname "$0")/common.sh"
. "$(dirname "$0")/auth.sh"

action=$(query_get action)
resource=$(query_get resource)
port=$(query_get port)
state=$(query_get state)
delay=$(query_get delay)
token=$(query_get token)
to=$(query_get to)

case "$action" in
  get)
    json_header
    rest_enabled && en=1 || en=0
    printf '{"ok":true,"enabled":%s}' "$en"
    exit 0
    ;;
  set)
    require_session_only || exit 0
    enabled=$(query_get enabled)
    [ "$enabled" = 0 ] || enabled=1
    printf 'enabled=%s\n' "$enabled" > "$MP_ROOT/api.conf"
    write_auth_cache
    cfgmtd -w -p /etc >/dev/null 2>&1
    json_header
    printf '{"ok":true,"enabled":%s}' "$enabled"
    exit 0
    ;;
esac

if ! rest_enabled && ! has_session && ! is_local_cgi; then
  deny_json "403 Forbidden" "rest api disabled"
  exit 0
fi

case "$resource" in
  ''|status)
    exec "$(dirname "$0")/status.sh"
    ;;
  outlets)
    json_header
    printf '{"api":"v1","outlets":['
    sep=''
    for p in 1 2 3; do
      relay=$(cat /proc/power/relay"$p" 2>/dev/null || echo null)
      watt=$(cat /proc/power/active_pwr"$p" 2>/dev/null || echo null)
      wh=$(cat /proc/power/energy_sum"$p" 2>/dev/null || echo null)
      printf '%s{"id":%s,"relay":%s,"power_w":%s,"energy_wh":%s}' "$sep" "$p" "$relay" "$watt" "$wh"
      sep=,
    done
    printf ']}'
    ;;
  outlet)
    case "$port" in 1|2|3) ;;
      *) json_header; printf '{"ok":false,"error":"port must be 1, 2, or 3"}'; exit 0 ;;
    esac
    if [ -z "$state" ]; then
      json_header
      relay=$(cat /proc/power/relay"$port" 2>/dev/null || echo null)
      watt=$(cat /proc/power/active_pwr"$port" 2>/dev/null || echo null)
      wh=$(cat /proc/power/energy_sum"$port" 2>/dev/null || echo null)
      printf '{"api":"v1","id":%s,"relay":%s,"power_w":%s,"energy_wh":%s}' "$port" "$relay" "$watt" "$wh"
    else
      QUERY_STRING="port=$port&state=$state&delay=$delay&to=$to&token=$token" exec "$(dirname "$0")/action.sh"
    fi
    ;;
  all)
    if [ -z "$state" ]; then exec "$(dirname "$0")/status.sh"; fi
    QUERY_STRING="port=all&state=$state&delay=$delay&token=$token" exec "$(dirname "$0")/action.sh"
    ;;
  *)
    json_header
    printf '{"ok":false,"error":"unknown resource"}'
    ;;
esac
