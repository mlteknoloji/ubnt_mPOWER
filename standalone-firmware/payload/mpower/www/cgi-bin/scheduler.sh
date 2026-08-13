#!/bin/sh
# Background scheduler: clock/pulse/sunrise/sunset with weekday mask.
MP_ROOT=/etc/persistent/mpower
file=$MP_ROOT/data/schedules.db
last=/tmp/mpower-sched.last
loc=$MP_ROOT/location.conf
mkdir -p /tmp/mpower-pilot "$MP_ROOT/data"
touch "$last"
set_timezone() {
  tz=$(sed -n 's/^tz=//p' "$loc" 2>/dev/null | head -1)
  case "$tz" in ''|*[!0-9+-]*|[+-]) tz=3;; esac
  # POSIX TZ signs are reversed: GMT-3 means UTC+3.
  case "$tz" in
    -*) TZ="GMT+${tz#-}" ;;
    +*) TZ="GMT-${tz#+}" ;;
    *)  TZ="GMT-$tz" ;;
  esac
  export TZ
}

set_timezone

apply_port() {
  port=$1; value=$2
  if [ "$port" = all ]; then
    for p in 1 2 3; do
      printf '%s' "$value" > /proc/power/relay"$p"
    done
  else
    printf '%s' "$value" > /proc/power/relay"$port"
  fi
}

pulse_port() {
  port=$1; state=$2; duration=$3
  [ "$duration" -gt 0 ] 2>/dev/null || duration=10
  if [ "$state" = on ]; then v=1; rv=0; else v=0; rv=1; fi
  # capture current for restore if pulse-to-opposite-then-restore preferred:
  # here: set to state for duration, then invert
  apply_port "$port" "$v"
  ( sleep "$duration"; apply_port "$port" "$rv" ) &
}

SUN_CACHE_KEY=
SUN_TIMES=

refresh_sun_times() {
  lat=41.1592; lon=27.8000; tz=3
  [ -f "$loc" ] && {
    lat=$(sed -n 's/^lat=//p' "$loc" | head -1)
    lon=$(sed -n 's/^lon=//p' "$loc" | head -1)
    tz=$(sed -n 's/^tz=//p' "$loc" | head -1)
  }
  [ -n "$lat" ] || lat=41.1592
  [ -n "$lon" ] || lon=27.8000
  case "$tz" in ''|*[!0-9+-]*|[+-]) tz=3;; esac
  y=$(date +%Y); m=$(date +%m); d=$(date +%d)
  # reject epoch-year
  if [ "$y" -lt 2020 ]; then SUN_TIMES=; return; fi

  # Recalculate once per local day, and immediately after location/timezone
  # changes. This runs entirely on the device; schedule.html need not be open.
  sun_key="${y}${m}${d}|${lat}|${lon}|${tz}"
  [ "$sun_key" = "$SUN_CACHE_KEY" ] && return
  set -- $(awk -f "$MP_ROOT/bin/sun.awk" -- "$lat" "$lon" "$y" "$m" "$d")
  sr=$1; ss=$2
  if [ -z "$sr" ] || [ -z "$ss" ]; then
    SUN_TIMES=
    SUN_CACHE_KEY=$sun_key
    echo "$(date '+%Y-%m-%d %H:%M:%S') SUN calculation failed lat=$lat lon=$lon tz=$tz"
    return
  fi
  # convert UTC minutes to local
  sr=$((sr + tz*60)); ss=$((ss + tz*60))
  while [ "$sr" -lt 0 ]; do sr=$((sr+1440)); done
  while [ "$sr" -ge 1440 ]; do sr=$((sr-1440)); done
  while [ "$ss" -lt 0 ]; do ss=$((ss+1440)); done
  while [ "$ss" -ge 1440 ]; do ss=$((ss-1440)); done
  SUN_TIMES="$sr $ss"
  SUN_CACHE_KEY=$sun_key
  echo "$(date '+%Y-%m-%d %H:%M:%S') SUN daily lat=$lat lon=$lon tz=$tz sunrise=$sr sunset=$ss"
}

day_ok() {
  days=$1
  [ "$days" = '*' ] && return 0
  [ -z "$days" ] && return 0
  dow=$(date +%w)
  echo "$days" | grep -q "$dow"
}

while true; do
  set_timezone
  # wait until clock looks sane
  year=$(date +%Y)
  if [ "$year" -lt 2020 ]; then
    /etc/persistent/mpower/bin/time-sync.sh >/dev/null 2>&1 || true
    sleep 30
    continue
  fi
  now=$(date +%H:%M)
  nh=$(date +%H | sed 's/^0//'); nm=$(date +%M | sed 's/^0//')
  [ -n "$nh" ] || nh=0; [ -n "$nm" ] || nm=0
  nowm=$((nh*60 + nm))
  key=$(date +%Y%m%d%H%M)
  refresh_sun_times
  sun=$SUN_TIMES

  [ -f "$file" ] && while IFS='|' read a b c d e f g h; do
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
    day_ok "$days" || continue
    fire=
    case "$kind" in
      clock|pulse)
        [ "$now" = "$time" ] && fire=1
        ;;
      sunrise|sunset)
        [ -n "$sun" ] || continue
        set -- $sun; sr=$1; ss=$2
        base=$sr; [ "$kind" = sunset ] && base=$ss
        target=$((base + offset))
        while [ "$target" -lt 0 ]; do target=$((target+1440)); done
        while [ "$target" -ge 1440 ]; do target=$((target-1440)); done
        [ "$nowm" -eq "$target" ] && fire=1
        ;;
    esac
    [ "$fire" = 1 ] || continue
    grep -q "^$key-$id$" "$last" 2>/dev/null && continue
    if [ "$kind" = pulse ] || [ "$duration" -gt 0 ] 2>/dev/null; then
      pulse_port "$port" "$state" "$duration"
    else
      [ "$state" = on ] && apply_port "$port" 1 || apply_port "$port" 0
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') FIRE id=$id kind=$kind port=$port state=$state"
    echo "$key-$id" >> "$last"
  done < "$file"

  tail -n 400 "$last" > "$last.new" 2>/dev/null && mv "$last.new" "$last"
  sleep 15
done
