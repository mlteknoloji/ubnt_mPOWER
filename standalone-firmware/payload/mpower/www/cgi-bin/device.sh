#!/bin/sh
. "$(dirname "$0")/common.sh"
. "$(dirname "$0")/auth.sh"
cfg=$MP_ROOT/device.conf
action=$(query_get action)
case "$action" in
  ''|get)
    json_header
    name=$(sed -n 's/^name=//p' "$cfg" 2>/dev/null | head -1)
    hostname=$(uname -n 2>/dev/null)
    mac=$(ifconfig ath0 2>/dev/null | sed -n 's/.*HWaddr \([0-9A-Fa-f:]*\).*/\1/p' | tr -d ':' | tr 'A-F' 'a-f')
    [ -n "$mac" ] || mac=$(ifconfig br0 2>/dev/null | sed -n 's/.*HWaddr \([0-9A-Fa-f:]*\).*/\1/p' | tr -d ':' | tr 'A-F' 'a-f')
    led_enabled=$(sed -n 's/^enabled=//p' "$MP_ROOT/led.conf" 2>/dev/null | head -1)
    [ "$led_enabled" = 0 ] || led_enabled=1
    printf '{"ok":true,"name":"%s","hostname":"%s","mac":"%s","led_enabled":%s}' "$name" "$hostname" "$mac" "$led_enabled"
    ;;
  set)
    require_token || exit 0
    name=$(url_decode "$(query_get name)" | tr -cd 'A-Za-z0-9 ._:-' | cut -c1-32)
    printf 'name=%s\n' "$name" > "$cfg"
    cfgmtd -w -p /etc >/dev/null 2>&1
    json_header; printf '{"ok":true,"name":"%s"}' "$name"
    ;;
  led)
    require_token || exit 0
    enabled=$(query_get enabled)
    [ "$enabled" = 0 ] || enabled=1
    printf 'enabled=%s\n' "$enabled" > "$MP_ROOT/led.conf"
    /bin/sh "$MP_ROOT/bin/ap-control.sh" sync >/tmp/mpower-ap.log 2>&1 || true
    cfgmtd -w -p /etc >/dev/null 2>&1
    json_header; printf '{"ok":true,"led_enabled":%s}' "$enabled"
    ;;
  *) json_header; printf '{"ok":false,"error":"unknown"}' ;;
esac
