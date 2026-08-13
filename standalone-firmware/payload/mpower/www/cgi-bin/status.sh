#!/bin/sh
. "$(dirname "$0")/common.sh"
. "$(dirname "$0")/auth.sh"
if ! rest_enabled && ! has_session && ! is_local_cgi; then
  deny_json "403 Forbidden" "rest api disabled"
  exit 0
fi
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
version=$(cat /etc/version 2>/dev/null | tr -cd 'A-Za-z0-9._-')
overlay=$(cat /etc/persistent/mpower/.installed 2>/dev/null | tr -cd 'A-Za-z0-9._-')
uptime=$(cut -d. -f1 /proc/uptime 2>/dev/null)
ssid=$(iwconfig ath0 2>/dev/null | sed -n 's/.*ESSID:"\([^"]*\)".*/\1/p' | tr -cd 'A-Za-z0-9 ._:-')
now=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
year=$(date +%Y 2>/dev/null)
synced=0; [ "$year" -ge 2020 ] 2>/dev/null && synced=1
ip=$(ifconfig ath0 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p')
mac=$(ifconfig ath0 2>/dev/null | sed -n 's/.*HWaddr \([0-9A-Fa-f:]*\).*/\1/p' | tr -d ':' | tr 'A-F' 'a-f')
[ -n "$mac" ] || mac=$(ifconfig br0 2>/dev/null | sed -n 's/.*HWaddr \([0-9A-Fa-f:]*\).*/\1/p' | tr -d ':' | tr 'A-F' 'a-f')
hostname=$(uname -n 2>/dev/null | tr -cd 'A-Za-z0-9._-')
name=$(sed -n 's/^name=//p' /etc/persistent/mpower/device.conf 2>/dev/null | head -1 | tr -cd 'A-Za-z0-9 ._:-')
[ -n "$name" ] || name=$hostname
printf '{"version":"%s","overlay":"%s","uptime":%s,"ssid":"%s","ip":"%s","mac":"%s","hostname":"%s","name":"%s","now":"%s","synced":%s,"outlets":[' \
  "$version" "$overlay" "${uptime:-0}" "$ssid" "$ip" "$mac" "$hostname" "$name" "$now" "$synced"
sep=''
for port in 1 2 3; do
  relay=$(cat /proc/power/relay"$port" 2>/dev/null || echo null)
  watt=$(cat /proc/power/active_pwr"$port" 2>/dev/null || echo null)
  wh=$(cat /proc/power/energy_sum"$port" 2>/dev/null || echo null)
  volt=$(cat /proc/power/v_rms"$port" 2>/dev/null || echo null)
  amp=$(cat /proc/power/i_rms"$port" 2>/dev/null || echo null)
  pf=$(cat /proc/power/pf"$port" 2>/dev/null || echo null)
  printf '%s{"port":%s,"relay":%s,"watt":%s,"wh":%s,"volt":%s,"amp":%s,"pf":%s}' "$sep" "$port" "$relay" "$watt" "$wh" "$volt" "$amp" "$pf"
  sep=,
done
printf ']}'
