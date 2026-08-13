#!/bin/sh
# Schedule DB format (pipe):
# id|kind|time|port|state|days|duration|offset
# kind: clock|pulse|sunrise|sunset
# time: HH:MM (clock/pulse) or ignored for sun
# days: * or subset of 0-6 (0=Sun) e.g. 12345
# duration: seconds for pulse (on then restore/off)
# offset: minutes relative to sunrise/sunset (e.g. -30, +30)
. "$(dirname "$0")/common.sh"
. "$(dirname "$0")/auth.sh"
file=$MP_DATA/schedules.db
mkdir -p "$MP_DATA"
persist() {
  (
    i=0
    while ! mkdir /tmp/mpower-schedules-cfgmtd.lock 2>/dev/null; do
      i=$((i + 1)); [ "$i" -ge 30 ] && exit 0; sleep 1
    done
    trap 'rmdir /tmp/mpower-schedules-cfgmtd.lock 2>/dev/null' EXIT
    cfgmtd -w -p /etc
    sync
  ) > /tmp/mpower-schedules-cfgmtd.log 2>&1 &
}
rebuild_cron() {
  /bin/sh "$MP_ROOT/bin/schedule-cron.sh" >> /tmp/mpower-scheduler.log 2>&1
}
action=$(query_get action)

json_list() {
  json_header
  printf '{"schedules":['
  sep=
  [ -f "$file" ] || { printf ']}'; return; }
  while IFS='|' read a b c d e f g h; do
    [ -z "$a" ] && continue
    case "$b" in
      [01][0-9]:[0-5][0-9]|2[0-3]:[0-5][0-9])
        id=$a; kind=clock; time=$b; port=$c; state=$d; days='*'; duration=0; offset=0 ;;
      *)
        id=$a; kind=$b; time=$c; port=$d; state=$e; days=$f; duration=$g; offset=$h
        [ -z "$kind" ] && kind=clock
        [ -z "$days" ] && days='*'
        [ -z "$duration" ] && duration=0
        [ -z "$offset" ] && offset=0
        ;;
    esac
    printf '%s{"id":%s,"kind":"%s","time":"%s","port":"%s","state":"%s","days":"%s","duration":%s,"offset":%s}' \
      "$sep" "$id" "$kind" "$time" "$port" "$state" "$days" "$duration" "$offset"
    sep=,
  done < "$file"
  printf ']}'
}

case "$action" in
  ''|list) json_list ;;
  add|update)
    op=$action
    require_token || exit 0
    id=$(query_get id)
    if [ "$op" = update ]; then
      case "$id" in *[!0-9]*|'') json_header; printf '{"ok":false,"error":"id"}'; exit 0;; esac
      grep -q "^$id|" "$file" 2>/dev/null || { json_header; printf '{"ok":false,"error":"not found"}'; exit 0; }
    fi
    kind=$(query_get kind); [ -z "$kind" ] && kind=clock
    # BusyBox 1.11 printf does not support the common \\xHH URL decoder.
    # Schedule time only needs encoded colon; days may contain encoded '*'.
    time=$(query_get time | sed 's/%3[Aa]/:/g')
    port=$(query_get port)
    state=$(query_get state)
    days=$(query_get days | sed 's/%2[Aa]/*/g')
    duration=$(query_get duration)
    offset=$(query_get offset)
    [ -z "$days" ] && days='*'
    [ -z "$duration" ] && duration=0
    [ -z "$offset" ] && offset=0
    case "$kind" in clock|pulse|sunrise|sunset) ;; *) json_header; printf '{"ok":false,"error":"kind"}'; exit 0;; esac
    case "$port" in 1|2|3|all) ;; *) json_header; printf '{"ok":false,"error":"port"}'; exit 0;; esac
    case "$state" in on|off) ;; *) json_header; printf '{"ok":false,"error":"state"}'; exit 0;; esac
    if [ "$kind" = clock ] || [ "$kind" = pulse ]; then
      case "$time" in [01][0-9]:[0-5][0-9]|2[0-3]:[0-5][0-9]) ;; *) json_header; printf '{"ok":false,"error":"time"}'; exit 0;; esac
    else
      time=sun
    fi
    case "$duration" in ''|*[!0-9]*) duration=0;; esac
    case "$offset" in ''|*[!0-9+-]*|[+-]|[+-]*[!0-9]*) offset=0;; esac
    row="$id|$kind|$time|$port|$state|$days|$duration|$offset"
    if [ "$op" = add ]; then
      id=1
      [ -s "$file" ] && id=$(($(awk -F'|' 'END{print $1+0}' "$file")+1))
      echo "$id|$kind|$time|$port|$state|$days|$duration|$offset" >> "$file"
    else
      awk -F'|' -v id="$id" -v row="$row" '$1==id {print row; next} {print}' "$file" > "$file.new" && mv "$file.new" "$file"
    fi
    rebuild_cron
    persist
    json_header; printf '{"ok":true,"id":%s,"action":"%s"}' "$id" "$op"
    ;;
  delete)
    require_token || exit 0
    id=$(query_get id)
    case "$id" in *[!0-9]*|'') json_header; printf '{"ok":false,"error":"id"}'; exit 0;; esac
    if [ -f "$file" ]; then
      awk -F'|' -v id="$id" '$1 != id {print}' "$file" > "$file.new" && mv "$file.new" "$file"
    fi
    rebuild_cron
    persist
    json_header; printf '{"ok":true}'
    ;;
  *) json_header; printf '{"ok":false,"error":"unknown"}' ;;
esac
