#!/bin/sh
. "$(dirname "$0")/common.sh"
. "$(dirname "$0")/auth.sh"
action=$(query_get action)

case "$action" in
  reboot)
    require_token || exit 0
    json_header
    printf '{"ok":true,"msg":"rebooting"}'
    ( sleep 1; sync; reboot ) >/tmp/mpower-reboot.log 2>&1 &
    ;;
  factory)
    require_token || exit 0
    confirm=$(query_get confirm)
    [ "$confirm" = "RESET" ] || {
      json_header
      printf '{"ok":false,"error":"confirm=RESET required"}'
      exit 0
    }
    json_header
    printf '{"ok":true,"msg":"factory reset starting"}'
    ( sleep 1; /bin/sh $MP_ROOT/bin/factory-reset.sh web ) >/tmp/mpower-factory-reset.log 2>&1 &
    ;;
  *)
    json_header
    printf '{"ok":false,"error":"unknown"}'
    ;;
esac
