#!/bin/sh
case "$0" in */*) CGI_DIR=${0%/*} ;; *) CGI_DIR=. ;; esac
. "$CGI_DIR/common.sh"
. "$CGI_DIR/auth.sh"
action=$(query_get action)
loc=$MP_ROOT/location.conf

# Same rules as settings.html; error codes map to locErr_* in i18n.js.
# coord_ok VALUE MAX: decimal with a dot, |value| <= MAX, at most 6 decimals.
coord_ok() {
  cv=${1#-}
  case "$cv" in ''|*[!0-9.]*|.*|*.|*.*.*) return 1 ;; esac
  ci=${cv%%.*}; cf=; case "$cv" in *.*) cf=${cv#*.} ;; esac
  [ ${#ci} -le 3 ] && [ ${#cf} -le 6 ] || return 1
  [ "$ci" -le "$2" ] || return 1
  # exactly MAX is allowed only with a zero fraction (90.0 yes, 90.5 no)
  if [ "$ci" -eq "$2" ]; then case "$cf" in *[1-9]*) return 1 ;; esac; fi
  return 0
}
# Whole-hour UTC offset -12..+14 (rules use tz*60 minutes).
tz_ok() {
  case "$1" in ''|*[!0-9+-]*|?*[+-]*|[+-]) return 1 ;; esac
  tv=${1#[+-]}
  [ ${#tv} -le 2 ] || return 1
  case "$1" in -*) [ "$tv" -le 12 ] ;; *) [ "$tv" -le 14 ] ;; esac
}
# Hostname or IPv4: letters, digits, dot, dash; 1..64 chars.
ntp_ok() {
  case "$1" in ''|*[!A-Za-z0-9.-]*|.*|-*|*..*) return 1 ;; esac
  [ ${#1} -le 64 ]
}
loc_err() { json_header; printf '{"ok":false,"error":"%s"}' "$1"; exit 0; }

net_ok=0
route -n 2>/dev/null | grep -q '^0\.0\.0\.0' && net_ok=1
has_dns=0
grep -q nameserver /etc/resolv.conf 2>/dev/null && has_dns=1

case "$action" in
  ''|get)
    json_header
  lat=41.1592; lon=27.8000; tz=3; ntp=pool.ntp.org
    [ -f "$loc" ] && {
      lat=$(sed -n 's/^lat=//p' "$loc"|head -1)
      lon=$(sed -n 's/^lon=//p' "$loc"|head -1)
      tz=$(sed -n 's/^tz=//p' "$loc"|head -1)
    }
    [ -f $MP_ROOT/time.conf ] && ntp=$(sed -n 's/^ntp=//p' $MP_ROOT/time.conf|head -1)
    now=$(date '+%Y-%m-%d %H:%M:%S')
    year=$(date +%Y)
    synced=0; [ "$year" -ge 2020 ] && synced=1
    # The schedule page supplies the browser's calendar date so the selected
    # location can be previewed even while the device clock is not synced yet.
    sun_y=$(query_get year); sun_m=$(query_get month); sun_d=$(query_get day)
    sun_date_ok=1
    case "$sun_y" in [0-9][0-9][0-9][0-9]) :;; *) sun_date_ok=0;; esac
    case "$sun_m" in ''|*[!0-9]*) sun_date_ok=0;; esac
    case "$sun_d" in ''|*[!0-9]*) sun_date_ok=0;; esac
    if [ "$sun_date_ok" = 1 ]; then
      [ "$sun_m" -ge 1 ] && [ "$sun_m" -le 12 ] &&
        [ "$sun_d" -ge 1 ] && [ "$sun_d" -le 31 ] || sun_date_ok=0
    fi
    if [ "$sun_date_ok" = 0 ] && [ "$synced" = 1 ]; then
      sun_y=$(date +%Y); sun_m=$(date +%m); sun_d=$(date +%d); sun_date_ok=1
    fi
    sunrise="--:--"; sunset="--:--"
    if [ "$sun_date_ok" = 1 ]; then
      set -- $(awk -f "$MP_ROOT/bin/sun.awk" -- "$lat" "$lon" "$sun_y" "$sun_m" "$sun_d")
      sr=$1; ss=$2
      case "$tz" in ''|*[!0-9+-]*|[+-]) tz=3;; esac
      if [ -n "$sr" ] && [ -n "$ss" ]; then
        sr=$((sr + tz * 60)); ss=$((ss + tz * 60))
        while [ "$sr" -lt 0 ]; do sr=$((sr+1440)); done
        while [ "$sr" -ge 1440 ]; do sr=$((sr-1440)); done
        while [ "$ss" -lt 0 ]; do ss=$((ss+1440)); done
        while [ "$ss" -ge 1440 ]; do ss=$((ss-1440)); done
        sunrise=$(printf '%02d:%02d' $((sr/60)) $((sr%60)))
        sunset=$(printf '%02d:%02d' $((ss/60)) $((ss%60)))
      fi
    fi
    reason=
    [ "$synced" = 1 ] || {
      [ "$net_ok" = 0 ] && reason="no_internet"
      [ "$net_ok" = 1 ] && [ "$has_dns" = 0 ] && reason="no_dns"
      [ -z "$reason" ] && reason="ntp_failed"
    }
    log=$(tail -c 400 /tmp/mpower-ntp.log 2>/dev/null | tr '\n' '|' | tr -cd 'A-Za-z0-9 ._:/|=-')
    printf '{"ok":true,"lat":"%s","lon":"%s","tz":"%s","ntp":"%s","now":"%s","sunrise":"%s","sunset":"%s","synced":%s,"net_ok":%s,"has_dns":%s,"reason":"%s","log":"%s"}' \
      "$lat" "$lon" "$tz" "$ntp" "$now" "$sunrise" "$sunset" "$synced" "$net_ok" "$has_dns" "$reason" "$log"
    ;;
  sun)
    # Sunrise/sunset table for any coordinates and start date, using the
    # same sun.awk as the scheduler (so it matches what the rules fire on).
    # ?lat=&lon=&tz=&year=&month=&day=&days=1..14  (empty lat/lon/tz = saved)
    json_header
    s_lat=41.1592; s_lon=27.8000; s_tz=3
    [ -f "$loc" ] && {
      s_lat=$(sed -n 's/^lat=//p' "$loc"|head -1)
      s_lon=$(sed -n 's/^lon=//p' "$loc"|head -1)
      s_tz=$(sed -n 's/^tz=//p' "$loc"|head -1)
    }
    v=$(url_decode "$(query_get lat)"); [ -n "$v" ] && s_lat=$v
    v=$(url_decode "$(query_get lon)"); [ -n "$v" ] && s_lon=$v
    v=$(url_decode "$(query_get tz)"); [ -n "$v" ] && s_tz=$v
    coord_ok "$s_lat" 90 || { printf '{"ok":false,"error":"lat_invalid"}'; exit 0; }
    coord_ok "$s_lon" 180 || { printf '{"ok":false,"error":"lon_invalid"}'; exit 0; }
    tz_ok "$s_tz" || { printf '{"ok":false,"error":"tz_invalid"}'; exit 0; }
    s_tz=${s_tz#+}
    y=$(query_get year); m=$(query_get month); d=$(query_get day); n=$(query_get days)
    case "$y" in [12][0-9][0-9][0-9]) ;; *) printf '{"ok":false,"error":"date"}'; exit 0;; esac
    case "$m$d" in ''|*[!0-9]*) printf '{"ok":false,"error":"date"}'; exit 0;; esac
    m=${m#0}; d=${d#0}
    [ "$m" -ge 1 ] && [ "$m" -le 12 ] && [ "$d" -ge 1 ] && [ "$d" -le 31 ] || { printf '{"ok":false,"error":"date"}'; exit 0; }
    case "$n" in ''|*[!0-9]*) n=1;; esac
    [ "$n" -lt 1 ] && n=1; [ "$n" -gt 14 ] && n=14
    hm() { printf '%02d:%02d' $(($1/60)) $(($1%60)); }
    wrap() { w=$1; while [ "$w" -lt 0 ]; do w=$((w+1440)); done; while [ "$w" -ge 1440 ]; do w=$((w-1440)); done; }
    printf '{"ok":true,"lat":"%s","lon":"%s","tz":"%s","days":[' "$s_lat" "$s_lon" "$s_tz"
    i=0; sep=
    while [ "$i" -lt "$n" ]; do
      set -- $(awk -f "$MP_ROOT/bin/sun.awk" -- "$s_lat" "$s_lon" "$y" "$m" "$d")
      sr=$1; ss=$2
      if [ -z "$sr" ] || [ "$sr$ss" = 00 ]; then
        # Polar day/night: sun.awk returns "0 0".
        printf '%s{"date":"%04d-%02d-%02d","sunrise":"--:--","sunset":"--:--","length":"--:--"}' "$sep" "$y" "$m" "$d"
      else
        len=$((ss - sr)); [ "$len" -lt 0 ] && len=$((len + 1440))
        wrap $((sr + s_tz * 60)); lr=$w
        wrap $((ss + s_tz * 60)); ls=$w
        printf '%s{"date":"%04d-%02d-%02d","sunrise":"%s","sunset":"%s","length":"%s"}' \
          "$sep" "$y" "$m" "$d" "$(hm $lr)" "$(hm $ls)" "$(hm $len)"
      fi
      sep=,
      # next calendar day
      case "$m" in 4|6|9|11) dim=30 ;; 2) dim=28
        if [ $((y % 4)) = 0 ] && { [ $((y % 100)) != 0 ] || [ $((y % 400)) = 0 ]; }; then dim=29; fi ;;
        *) dim=31 ;; esac
      d=$((d + 1))
      if [ "$d" -gt "$dim" ]; then d=1; m=$((m + 1)); [ "$m" -gt 12 ] && { m=1; y=$((y + 1)); }; fi
      i=$((i + 1))
    done
    printf ']}'
    ;;
  set)
    require_token || exit 0
    lat=$(url_decode "$(query_get lat)")
    lon=$(url_decode "$(query_get lon)")
    tz=$(url_decode "$(query_get tz)")
    ntp=$(url_decode "$(query_get ntp)")
    [ -z "$tz" ] && tz=3
    [ -z "$ntp" ] && ntp=pool.ntp.org
    coord_ok "$lat" 90 || loc_err lat_invalid
    coord_ok "$lon" 180 || loc_err lon_invalid
    tz_ok "$tz" || loc_err tz_invalid
    ntp_ok "$ntp" || loc_err ntp_invalid
    tz=${tz#+}
    printf 'lat=%s\nlon=%s\ntz=%s\n' "$lat" "$lon" "$tz" > "$loc"
    printf 'ntp=%s\n' "$ntp" > $MP_ROOT/time.conf
    /bin/sh "$MP_ROOT/bin/schedule-cron.sh" >>/tmp/mpower-scheduler.log 2>&1
    cfgmtd -w -p /etc >/dev/null 2>&1
    /etc/persistent/mpower/bin/time-sync.sh >/tmp/mpower-ntp.log 2>&1 &
    json_header; printf '{"ok":true}'
    ;;
  sync)
    require_token || exit 0
    /etc/persistent/mpower/bin/time-sync.sh >/tmp/mpower-ntp.log 2>&1
    code=$?
    /bin/sh "$MP_ROOT/bin/schedule-cron.sh" >>/tmp/mpower-scheduler.log 2>&1
    year=$(date +%Y)
    synced=0; [ "$year" -ge 2020 ] && synced=1
    json_header
    printf '{"ok":%s,"synced":%s,"now":"%s","net_ok":%s}' \
      "$([ $code -eq 0 ] && echo true || echo false)" "$synced" "$(date '+%Y-%m-%d %H:%M:%S')" "$net_ok"
    ;;
  set_browser)
    # Set clock from browser local time (works without internet).
    require_token || exit 0
    # epoch seconds OR "YYYY-MM-DD HH:MM:SS"
    epoch=$(query_get epoch)
    stamp=$(url_decode "$(query_get stamp)")
    if [ -n "$epoch" ]; then
      case "$epoch" in *[!0-9]*|'') json_header; printf '{"ok":false,"error":"bad epoch"}'; exit 0;; esac
      # busybox date -s @epoch may not exist; convert via awk if needed
      if date -s "@$epoch" >/tmp/mpower-ntp.log 2>&1; then
        :
      else
        # fallback: expect stamp
        [ -n "$stamp" ] || { json_header; printf '{"ok":false,"error":"date -s @epoch unsupported; send stamp"}'; exit 0; }
      fi
    fi
    if [ -n "$stamp" ]; then
      # Try ISO then BusyBox MMDDhhmmYYYY.ss
      if ! date -s "$stamp" >/tmp/mpower-ntp.log 2>&1; then
        y=$(printf '%s' "$stamp" | cut -c1-4)
        mo=$(printf '%s' "$stamp" | cut -c6-7)
        d=$(printf '%s' "$stamp" | cut -c9-10)
        h=$(printf '%s' "$stamp" | cut -c12-13)
        mi=$(printf '%s' "$stamp" | cut -c15-16)
        s=$(printf '%s' "$stamp" | cut -c18-19)
        [ -z "$s" ] && s=00
        bb="${mo}${d}${h}${mi}${y}.${s}"
        date -s "$bb" >/tmp/mpower-ntp.log 2>&1 || {
          json_header; printf '{"ok":false,"error":"date set failed"}'; exit 0
        }
      fi
    fi
    year=$(date +%Y)
    synced=0; [ "$year" -ge 2020 ] && synced=1
    /bin/sh "$MP_ROOT/bin/schedule-cron.sh" >>/tmp/mpower-scheduler.log 2>&1
    echo "browser set -> $(date)" >> /tmp/mpower-ntp.log
    json_header
    printf '{"ok":true,"synced":%s,"now":"%s"}' "$synced" "$(date '+%Y-%m-%d %H:%M:%S')"
    ;;
  *) json_header; printf '{"ok":false,"error":"unknown"}' ;;
esac
