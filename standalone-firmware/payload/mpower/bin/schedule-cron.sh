#!/bin/sh
# Compile NetRelayMP schedules into the stock BusyBox crond table.
# Device clock/crond run in UTC; UI clock rules are entered in configured local time.
ROOT=${MP_ROOT:-/etc/persistent/mpower}
DB=${MP_SCHEDULE_DB:-$ROOT/data/schedules.db}
LOC=$ROOT/location.conf
CRON=${MP_CRON_FILE:-/etc/crontabs/ubnt}
TMP=$CRON.tmp.$$
BODY=/tmp/mpower-cron-body.$$
LOG=/tmp/mpower-scheduler.log
BEGIN='# BEGIN NETRELAYMP SCHEDULES'
END='# END NETRELAYMP SCHEDULES'
FIRE=${MP_SCHEDULE_FIRE:-$ROOT/bin/schedule-fire.sh}
SUN_AWK=${MP_SUN_AWK:-$ROOT/bin/sun.awk}

cleanup() { rm -f "$TMP" "$BODY"; }
trap cleanup EXIT INT TERM

tz=$(sed -n 's/^tz=//p' "$LOC" 2>/dev/null | head -1)
lat=$(sed -n 's/^lat=//p' "$LOC" 2>/dev/null | head -1)
lon=$(sed -n 's/^lon=//p' "$LOC" 2>/dev/null | head -1)
case "$tz" in ''|*[!0-9+-]*|[+-]) tz=3;; esac
[ -n "$lat" ] || lat=41.1592
[ -n "$lon" ] || lon=27.8000
# Use the configured local calendar date for that day's solar calculation.
# POSIX TZ signs are reversed (GMT-3 means UTC+3).
case "$tz" in
  -*) TZ="GMT+${tz#-}" ;;
  +*) TZ="GMT-${tz#+}" ;;
  *)  TZ="GMT-$tz" ;;
esac
export TZ

days_csv() {
  pattern=$1; shift_days=$2
  [ -z "$pattern" ] && pattern='*'
  [ "$pattern" = '*' ] && { printf '*'; return; }
  out=; oldifs=$IFS; IFS=,
  for digit in 0 1 2 3 4 5 6; do
    case "$pattern" in *"$digit"*)
      shifted=$((digit + shift_days))
      while [ "$shifted" -lt 0 ]; do shifted=$((shifted+7)); done
      while [ "$shifted" -gt 6 ]; do shifted=$((shifted-7)); done
      [ -n "$out" ] && out="$out,"
      out="$out$shifted"
    esac
  done
  IFS=$oldifs
  [ -n "$out" ] && printf '%s' "$out" || printf '*'
}

emit_utc() {
  minute=$1; days=$2; id=$3; port=$4; state=$5; duration=$6; kind=$7
  shift_days=0
  while [ "$minute" -lt 0 ]; do minute=$((minute+1440)); shift_days=$((shift_days-1)); done
  while [ "$minute" -ge 1440 ]; do minute=$((minute-1440)); shift_days=$((shift_days+1)); done
  hour=$((minute/60)); min=$((minute%60))
  cron_days=$(days_csv "$days" "$shift_days")
  printf '%s %s * * %s %s %s %s %s %s %s\n' \
    "$min" "$hour" "$cron_days" "$FIRE" "$id" "$port" "$state" "$duration" "$kind" >> "$BODY"
}

sunrise=; sunset=
year=$(date +%Y 2>/dev/null)
if [ "$year" -ge 2020 ] 2>/dev/null; then
  set -- $(awk -f "$SUN_AWK" -- "$lat" "$lon" "$year" "$(date +%m)" "$(date +%d)")
  sunrise=$1; sunset=$2
fi

: > "$BODY"
[ -f "$DB" ] && while IFS='|' read a b c d e f g h; do
  [ -n "$a" ] || continue
  case "$b" in
    [01][0-9]:[0-5][0-9]|2[0-3]:[0-5][0-9])
      id=$a; kind=clock; time=$b; port=$c; state=$d; days='*'; duration=0; offset=0
      ;;
    *)
      id=$a; kind=$b; time=$c; port=$d; state=$e; days=$f; duration=$g; offset=$h
      ;;
  esac
  [ -n "$days" ] || days='*'
  [ -n "$duration" ] || duration=0
  [ -n "$offset" ] || offset=0
  case "$kind" in
    clock|pulse)
      hour=${time%:*}; minute=${time#*:}
      hour=$(printf '%s' "$hour" | sed 's/^0//'); minute=$(printf '%s' "$minute" | sed 's/^0//')
      [ -n "$hour" ] || hour=0; [ -n "$minute" ] || minute=0
      emit_utc $((hour*60 + minute - tz*60)) "$days" "$id" "$port" "$state" "$duration" "$kind"
      ;;
    sunrise|sunset)
      base=$sunrise; [ "$kind" = sunset ] && base=$sunset
      [ -n "$base" ] || continue
      emit_utc $((base + offset)) "$days" "$id" "$port" "$state" "$duration" "$kind"
      ;;
  esac
done < "$DB"

# Rebuild at 00:05 local time (converted to the UTC clock used by crond).
refresh=$((5 - tz*60))
while [ "$refresh" -lt 0 ]; do refresh=$((refresh+1440)); done
while [ "$refresh" -ge 1440 ]; do refresh=$((refresh-1440)); done
printf '%s %s * * * %s\n' "$((refresh%60))" "$((refresh/60))" "$0" >> "$BODY"

# Preserve stock jobs and replace only our marked block.
if [ -f "$CRON" ]; then
  awk -v begin="$BEGIN" -v end="$END" '
    $0==begin {skip=1; next}
    $0==end {skip=0; next}
    !skip {print}
  ' "$CRON" > "$TMP"
else
  : > "$TMP"
fi
printf '%s\n' "$BEGIN" >> "$TMP"
cat "$BODY" >> "$TMP"
printf '%s\n' "$END" >> "$TMP"
chmod 600 "$TMP"
mv "$TMP" "$CRON"
chmod 600 "$CRON"
# BusyBox 1.11 keeps the user's crontab cached. Explicitly request a reload;
# otherwise newly added/edited rules may not run until much later.
cron_pid=$(pidof crond 2>/dev/null | awk '{print $1}')
[ -n "$cron_pid" ] && kill -HUP "$cron_pid" 2>/dev/null || true
echo "$(date '+%Y-%m-%d %H:%M:%S') CRON rebuilt sunrise=${sunrise:-none} sunset=${sunset:-none}" >> "$LOG"
exit 0
