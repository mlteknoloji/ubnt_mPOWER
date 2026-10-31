#!/bin/sh
# Polled by the UI every few seconds: keep process spawns to a minimum.
case "$0" in */*) CGI_DIR=${0%/*} ;; *) CGI_DIR=. ;; esac
. "$CGI_DIR/common.sh"
. "$CGI_DIR/auth.sh"
if ! rest_enabled && ! has_session && ! is_local_cgi; then
  deny_json "403 Forbidden" "rest api disabled"
  exit 0
fi
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'

# Values that only change on reinstall / rename are cached in RAM.
# install.sh and device.sh delete this file when they change.
STATIC=/tmp/mpower-static.cache
if [ ! -s "$STATIC" ]; then
  s_version=$(tr -cd 'A-Za-z0-9._-' 2>/dev/null < /etc/version)
  s_overlay=$(tr -cd 'A-Za-z0-9._-' 2>/dev/null < "$MP_ROOT/.installed")
  s_mac=$(ifconfig ath0 2>/dev/null | sed -n 's/.*HWaddr \([0-9A-Fa-f:]*\).*/\1/p' | tr -d ':' | tr 'A-F' 'a-f')
  [ -n "$s_mac" ] || s_mac=$(ifconfig br0 2>/dev/null | sed -n 's/.*HWaddr \([0-9A-Fa-f:]*\).*/\1/p' | tr -d ':' | tr 'A-F' 'a-f')
  s_hostname=$(uname -n 2>/dev/null | tr -cd 'A-Za-z0-9._-')
  s_name=$(sed -n 's/^name=//p' "$MP_ROOT/device.conf" 2>/dev/null | head -1 | tr -cd 'A-Za-z0-9 ._:-')
  [ -n "$s_name" ] || s_name=$s_hostname
  printf 'version=%s\noverlay=%s\nmac=%s\nhostname=%s\nname=%s\n' \
    "$s_version" "$s_overlay" "$s_mac" "$s_hostname" "$s_name" > "$STATIC.$$" && mv "$STATIC.$$" "$STATIC"
fi
while IFS= read line; do
  case "$line" in
    version=*) version=${line#*=} ;;
    overlay=*) overlay=${line#*=} ;;
    mac=*) mac=${line#*=} ;;
    hostname=*) hostname=${line#*=} ;;
    name=*) name=${line#*=} ;;
  esac
done < "$STATIC"

uptime=0; read uptime rest < /proc/uptime; uptime=${uptime%%.*}
ssid=$(iwconfig ath0 2>/dev/null | sed -n 's/.*ESSID:"\([^"]*\)".*/\1/p' | tr -cd 'A-Za-z0-9 ._:-')
now=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
synced=0; [ "${now%%-*}" -ge 2020 ] 2>/dev/null && synced=1
ip=$(ifconfig ath0 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p')
printf '{"version":"%s","overlay":"%s","uptime":%s,"ssid":"%s","ip":"%s","mac":"%s","hostname":"%s","name":"%s","now":"%s","synced":%s,"outlets":[' \
  "$version" "$overlay" "${uptime:-0}" "$ssid" "$ip" "$mac" "$hostname" "$name" "$now" "$synced"

# read builtin instead of cat: 18 fewer processes per request.
pv() { v=; [ -r "$1" ] && read v < "$1"; [ -n "$v" ] || v=null; }
sep=''
for port in 1 2 3; do
  pv /proc/power/relay$port; relay=$v
  pv /proc/power/active_pwr$port; watt=$v
  pv /proc/power/energy_sum$port; wh=$v
  pv /proc/power/v_rms$port; volt=$v
  pv /proc/power/i_rms$port; amp=$v
  pv /proc/power/pf$port; pf=$v
  printf '%s{"port":%s,"relay":%s,"watt":%s,"wh":%s,"volt":%s,"amp":%s,"pf":%s}' "$sep" "$port" "$relay" "$watt" "$wh" "$volt" "$amp" "$pf"
  sep=,
done
printf ']}'
