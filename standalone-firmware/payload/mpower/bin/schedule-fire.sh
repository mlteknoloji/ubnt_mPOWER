#!/bin/sh
# Execute one cron schedule without requiring the web UI.
ROOT=/etc/persistent/mpower
LOG=/tmp/mpower-scheduler.log

id=$1; port=$2; state=$3; duration=$4; kind=$5
case "$id" in ''|*[!0-9]*) exit 2;; esac
case "$port" in 1|2|3|all) ;; *) exit 2;; esac
case "$state" in on|off) ;; *) exit 2;; esac
case "$duration" in ''|*[!0-9]*) duration=0;; esac

apply_port() {
  ap=$1; av=$2
  if [ "$ap" = all ]; then
    for outlet in 1 2 3; do
      printf '%s' "$av" > /proc/power/relay"$outlet"
    done
  else
    printf '%s' "$av" > /proc/power/relay"$ap"
  fi
}

[ "$state" = on ] && value=1 || value=0
apply_port "$port" "$value" || exit 0
echo "$(date '+%Y-%m-%d %H:%M:%S') FIRE id=$id kind=$kind port=$port state=$state" >> "$LOG"

if [ "$duration" -gt 0 ] 2>/dev/null; then
  [ "$value" = 1 ] && restore=0 || restore=1
  (
    sleep "$duration"
    apply_port "$port" "$restore"
    echo "$(date '+%Y-%m-%d %H:%M:%S') RESTORE id=$id port=$port" >> "$LOG"
  ) >/dev/null 2>&1 &
fi
exit 0
