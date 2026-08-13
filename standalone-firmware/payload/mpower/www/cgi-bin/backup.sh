#!/bin/sh
# Backup / restore NetRelayMP settings for fleet clone.
. "$(dirname "$0")/common.sh"
. "$(dirname "$0")/auth.sh"
action=$(query_get action)
[ -z "$action" ] && action=export

case "$action" in
  export)
    require_token || exit 0
    # JSON export (no secrets unless include_secrets=1)
    secrets=$(query_get secrets)
    name=$(sed -n 's/^name=//p' $MP_ROOT/device.conf 2>/dev/null | head -1)
    printf 'Content-Type: application/json\r\nContent-Disposition: attachment; filename="netrelaymp-backup.json"\r\nCache-Control: no-store\r\n\r\n'
    printf '{"format":"netrelaymp-backup","version":1,"overlay":"%s","exported_at":"%s","device_name":"%s",' \
      "$(cat $MP_ROOT/.installed 2>/dev/null | tr -cd 'A-Za-z0-9._-')" \
      "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)" \
      "$(printf '%s' "$name" | sed 's/"/\\"/g')"
    # wifi without psk unless secrets
    if [ -f $MP_ROOT/wifi.conf ]; then
      ssid=$(sed -n 's/^ssid=//p' $MP_ROOT/wifi.conf|head -1)
      sec=$(sed -n 's/^security=//p' $MP_ROOT/wifi.conf|head -1)
      wmode=$(sed -n 's/^mode=//p' $MP_ROOT/wifi.conf|head -1)
      case "$wmode" in station) ;; *) wmode=wds ;; esac
      psk=
      [ "$secrets" = 1 ] && psk=$(sed -n 's/^psk=//p' $MP_ROOT/wifi.conf|head -1)
      printf '"wifi":{"ssid":"%s","security":"%s","mode":"%s","psk":"%s"},' "$ssid" "$sec" "$wmode" "$(printf '%s' "$psk" | sed 's/"/\\"/g')"
    else
      printf '"wifi":null,'
    fi
    if [ -f $MP_ROOT/network.conf ]; then
      printf '"network":{'
      first=1
      for k in mode ip netmask gateway dns; do
        v=$(sed -n "s/^${k}=//p" $MP_ROOT/network.conf|head -1)
        [ $first -eq 1 ] || printf ','
        printf '"%s":"%s"' "$k" "$v"
        first=0
      done
      printf '},'
    else printf '"network":null,'; fi
    if [ -f $MP_ROOT/mqtt.conf ]; then
      printf '"mqtt":{'
      first=1
      for k in enabled host port user prefix interval ha_discovery custom; do
        v=$(sed -n "s/^${k}=//p" $MP_ROOT/mqtt.conf|head -1)
        [ $first -eq 1 ] || printf ','
        printf '"%s":"%s"' "$k" "$(printf '%s' "$v" | sed 's/"/\\"/g')"
        first=0
      done
      if [ "$secrets" = 1 ]; then
        v=$(sed -n 's/^pass=//p' $MP_ROOT/mqtt.conf|head -1)
        printf ',"pass":"%s"' "$(printf '%s' "$v" | sed 's/"/\\"/g')"
      else
        printf ',"pass":""'
      fi
      printf '},'
    else printf '"mqtt":null,'; fi
    if [ -f $MP_ROOT/location.conf ]; then
      lat=$(sed -n 's/^lat=//p' $MP_ROOT/location.conf|head -1)
      lon=$(sed -n 's/^lon=//p' $MP_ROOT/location.conf|head -1)
      tz=$(sed -n 's/^tz=//p' $MP_ROOT/location.conf|head -1)
      printf '"location":{"lat":"%s","lon":"%s","tz":"%s"},' "$lat" "$lon" "$tz"
    else printf '"location":null,'; fi
    ntp=$(sed -n 's/^ntp=//p' $MP_ROOT/time.conf 2>/dev/null|head -1)
    printf '"time":{"ntp":"%s"},' "${ntp:-pool.ntp.org}"
    if [ -f $MP_ROOT/ping.conf ]; then
      printf '"ping":{'
      first=1
      while IFS='=' read k v; do
        case "$k" in ''|\#*) continue ;; esac
        [ $first -eq 1 ] || printf ','
        printf '"%s":"%s"' "$k" "$(printf '%s' "$v" | sed 's/"/\\"/g')"
        first=0
      done < $MP_ROOT/ping.conf
      printf '},'
    else printf '"ping":null,'; fi
    rest_en=$(sed -n 's/^enabled=//p' $MP_ROOT/api.conf 2>/dev/null | head -1)
    [ "$rest_en" = 0 ] || rest_en=1
    printf '"rest_api":{"enabled":"%s"},' "$rest_en"
    printf '"schedules":['
    sep=
    [ -f $MP_DATA/schedules.db ] && while IFS= read line; do
      [ -z "$line" ] && continue
      esc=$(printf '%s' "$line" | sed 's/\\/\\\\/g;s/"/\\"/g')
      printf '%s"%s"' "$sep" "$esc"
      sep=,
    done < $MP_DATA/schedules.db
    printf '],'
    if [ "$secrets" = 1 ] && [ -f $MP_ROOT/api.token ]; then
      printf '"api_token":"%s"' "$(tr -d '\r\n' < $MP_ROOT/api.token)"
    else
      printf '"api_token":null'
    fi
    printf '}'
    ;;
  import)
    require_token || exit 0
    # Expect raw JSON body; use simple field extractors (BusyBox-friendly, limited)
    len=${CONTENT_LENGTH:-0}
    case "$len" in ''|*[!0-9]*|0) json_header; printf '{"ok":false,"error":"empty"}'; exit 0;; esac
    [ "$len" -gt 200000 ] && { json_header; printf '{"ok":false,"error":"too large"}'; exit 0; }
    dd bs=1 count="$len" of=/tmp/mpower-restore.json 2>/dev/null
    body=$(cat /tmp/mpower-restore.json)
    jget() { printf '%s' "$body" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1; }
    # network
    mode=$(jget mode); ip=$(jget ip); mask=$(printf '%s' "$body" | sed -n 's/.*"netmask"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'|head -1)
    gw=$(jget gateway); dns=$(jget dns)
    if [ -n "$mode" ]; then
      printf 'mode=%s\nip=%s\nnetmask=%s\ngateway=%s\ndns=%s\n' "$mode" "$ip" "$mask" "$gw" "$dns" > $MP_ROOT/network.conf
    fi
    ssid=$(jget ssid); security=$(jget security); psk=$(jget psk)
    wmode=$(printf '%s' "$body" | sed -n 's/.*"wifi"[[:space:]]*:[[:space:]]*{[^}]*"mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    case "$wmode" in station) ;; *) wmode=wds ;; esac
    if [ -n "$ssid" ]; then
      printf 'ssid=%s\nsecurity=%s\npsk=%s\nmode=%s\n' "$ssid" "${security:-wpa}" "$psk" "$wmode" > $MP_ROOT/wifi.conf
    fi
    host=$(jget host); port=$(jget port); user=$(jget user); prefix=$(jget prefix)
    interval=$(jget interval); ha=$(jget ha_discovery); enabled=$(jget enabled); pass=$(jget pass)
    custom=$(jget custom)
    if [ -n "$host" ] || [ -n "$enabled" ]; then
      {
        printf 'enabled=%s\n' "${enabled:-0}"
        printf 'host=%s\n' "$host"
        printf 'port=%s\n' "${port:-1883}"
        printf 'user=%s\n' "$user"
        printf 'pass=%s\n' "$pass"
        printf 'prefix=%s\n' "${prefix:-mpower}"
        printf 'interval=%s\n' "${interval:-15}"
        printf 'ha_discovery=%s\n' "${ha:-0}"
        printf 'custom=%s\n' "$custom"
      } > $MP_ROOT/mqtt.conf
    fi
    lat=$(jget lat); lon=$(jget lon); tz=$(jget tz)
    if [ -n "$lat" ]; then
      printf 'lat=%s\nlon=%s\ntz=%s\n' "$lat" "$lon" "${tz:-3}" > $MP_ROOT/location.conf
    fi
    ntp=$(jget ntp)
    [ -n "$ntp" ] && printf 'ntp=%s\n' "$ntp" > $MP_ROOT/time.conf
    rest_en=$(printf '%s' "$body" | sed -n 's/.*"rest_api"[[:space:]]*:[[:space:]]*{[^}]*"enabled"[[:space:]]*:[[:space:]]*"\?\([01]\)"\?.*/\1/p' | head -1)
    case "$rest_en" in 0|1) printf 'enabled=%s\n' "$rest_en" > $MP_ROOT/api.conf ;; esac
    # ping watch (nested object — avoid clashing with mqtt host/port)
    pping=$(printf '%s' "$body" | sed -n 's/.*"ping":{\([^}]*\)}.*/\1/p' | head -1)
    if [ -n "$pping" ]; then
      pj() { printf '%s' "$pping" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1; }
      if printf '%s' "$pping" | grep -q 'enabled1'; then
        {
          for p in 1 2 3; do
            printf 'enabled%s=%s\n' "$p" "$(pj enabled$p)"
            printf 'host%s=%s\n' "$p" "$(pj host$p)"
            printf 'interval%s=%s\n' "$p" "$(pj interval$p)"
            printf 'fail_count%s=%s\n' "$p" "$(pj fail_count$p)"
            printf 'fail_action%s=%s\n' "$p" "$(pj fail_action$p)"
            printf 'restore_sec%s=%s\n' "$p" "$(pj restore_sec$p)"
            printf 'cooldown%s=%s\n' "$p" "$(pj cooldown$p)"
          done
        } > $MP_ROOT/ping.conf
      else
        {
          printf 'enabled=%s\n' "$(pj enabled)"
          printf 'host=%s\n' "$(pj host)"
          printf 'interval=%s\n' "$(pj interval)"
          printf 'fail_count=%s\n' "$(pj fail_count)"
          printf 'port=%s\n' "$(pj port)"
          printf 'fail_action=%s\n' "$(pj fail_action)"
          printf 'restore_sec=%s\n' "$(pj restore_sec)"
          printf 'cooldown=%s\n' "$(pj cooldown)"
        } > $MP_ROOT/ping.conf
      fi
    fi
    # device name optional
    dname=$(printf '%s' "$body" | sed -n 's/.*"device_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'|head -1)
    [ -n "$dname" ] && printf 'name=%s\n' "$dname" > $MP_ROOT/device.conf
    cfgmtd -w -p /etc >/dev/null 2>&1
    # restart helpers
    [ -f $MP_ROOT/wifi.conf ] && /bin/sh $MP_ROOT/bin/wifi-client.sh >/tmp/mpower-wifi.log 2>&1 &
    [ -f $MP_ROOT/network.conf ] && /bin/sh $MP_ROOT/bin/network-apply.sh >/tmp/mpower-net.log 2>&1 &
    killall mqtt-client.sh 2>/dev/null
    [ -f $MP_ROOT/mqtt.conf ] && grep -q '^enabled=1' $MP_ROOT/mqtt.conf && \
      /bin/sh $MP_ROOT/bin/mqtt-client.sh >/tmp/mpower-mqtt.log 2>&1 &
    /bin/sh $MP_ROOT/bin/schedule-cron.sh >>/tmp/mpower-scheduler.log 2>&1
    ps w 2>/dev/null | grep 'mpower/bin/ping-watch.sh' | grep -v grep | while read pid rest; do
      case "$pid" in ''|*[!0-9]*) ;; *) kill "$pid" 2>/dev/null ;; esac
    done
    if grep -q '^enabled[123]=1$' $MP_ROOT/ping.conf 2>/dev/null ||
       grep -q '^enabled=1$' $MP_ROOT/ping.conf 2>/dev/null; then
      /bin/sh $MP_ROOT/bin/ping-watch.sh >/tmp/mpower-pingwatch.log 2>&1 &
    fi
    json_header; printf '{"ok":true}'
    ;;
  status)
    json_header
    wd=0; ps w 2>/dev/null | grep 'mpower/bin/watchdog.sh' | grep -vq grep && wd=1
    mqtt=0; ps w 2>/dev/null | grep 'mpower/bin/mqtt-client.sh' | grep -vq grep && mqtt=1
    pingw=0; ps w 2>/dev/null | grep 'mpower/bin/ping-watch.sh' | grep -vq grep && pingw=1
    wifi_ip=$(ifconfig ath0 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p')
    net_ok=0; route -n 2>/dev/null | grep -q '^0\.0\.0\.0' && net_ok=1
    year=$(date +%Y); synced=0; [ "$year" -ge 2020 ] 2>/dev/null && synced=1
    printf '{"ok":true,"watchdog":%s,"mqtt_running":%s,"ping_watch":%s,"wifi_ip":"%s","net_ok":%s,"time_synced":%s,"overlay":"%s"}' \
      "$wd" "$mqtt" "$pingw" "$wifi_ip" "$net_ok" "$synced" "$(cat $MP_ROOT/.installed 2>/dev/null | tr -cd 'A-Za-z0-9._-')"
    ;;
  *) json_header; printf '{"ok":false,"error":"unknown"}' ;;
esac
