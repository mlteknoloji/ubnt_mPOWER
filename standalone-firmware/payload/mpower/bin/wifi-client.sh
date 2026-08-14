#!/bin/sh
# Connect ath0 as station. Hide recovery AP only after a real LAN IP.
# Stock :8080 (mFi) keeps ath1 AP up while ath0 STA associates; the radio may
# glitch briefly, then phones rejoin mFi… — same model here. Never ifconfig
# ath1 down during associate.
#   (no args)  — setup/boot: 2 association attempts, AP stays up
#   keep-ap    — watchdog retry: 1 short attempt, AP stays up
# Failure sets /tmp/mpower-wifi.hold (last result). Watchdog retries keep-ap
# every 60s unless the reason is bad_password.
# Writes /tmp/mpower-wifi-result for UI error reporting.
# mode=station (default) | wds  → Station / Station WDS
cfg=/etc/persistent/mpower/wifi.conf
RESULT=/tmp/mpower-wifi-result
HOLD=/tmp/mpower-wifi.hold
KEEP_AP=0
case "$1" in keep-ap) KEEP_AP=1 ;; esac
[ -f "$cfg" ] || exit 0
LOCK=/tmp/mpower-wifi.lock
if ! mkdir "$LOCK" 2>/dev/null; then
  [ -x /etc/persistent/mpower/bin/boot-mark.sh ] && /etc/persistent/mpower/bin/boot-mark.sh wifi.skipped.already_running
  exit 0
fi
# Always restore AP state on exit: hide only when sta_ok (real LAN IP),
# otherwise bring recovery AP back (associate fail / DHCP fail / give-up).
cleanup() {
  rmdir "$LOCK" 2>/dev/null
  if [ -f "$HOLD" ]; then
    killall wpa_supplicant 2>/dev/null || true
  fi
  /etc/persistent/mpower/bin/ap-control.sh sync >/tmp/mpower-ap.log 2>&1 || true
}
trap 'cleanup' EXIT INT TERM
[ -x /etc/persistent/mpower/bin/boot-mark.sh ] && /etc/persistent/mpower/bin/boot-mark.sh wifi.start

ssid=$(sed -n 's/^ssid=//p' "$cfg" | head -1)
security=$(sed -n 's/^security=//p' "$cfg" | head -1)
psk=$(sed -n 's/^psk=//p' "$cfg" | head -1)
mode=$(sed -n 's/^mode=//p' "$cfg" | head -1)
[ -n "$ssid" ] || exit 1
case "$mode" in wds) mode=wds ;; *) mode=station ;; esac
escape() { printf '%s' "$1" | sed 's/[\\"]/\\&/g'; }

write_result() {
  # state=running|ok|fail  reason=…  detail=…
  {
    printf 'state=%s\n' "$1"
    printf 'reason=%s\n' "${2:-}"
    printf 'detail=%s\n' "${3:-}"
    printf 'ssid=%s\n' "$ssid"
    printf 'attempt=%s\n' "${try:-0}"
    printf 'hold=%s\n' "${hold:-0}"
    printf 'ts=%s\n' "$(date +%s 2>/dev/null || echo 0)"
  } > "$RESULT"
}

try=0
hold=0

mark_hold() {
  hold=1
  printf '%s\n' "${1:-fail}" > "$HOLD"
}

clear_hold() {
  hold=0
  rm -f "$HOLD"
}

clear_hold
write_result running starting

# Ensure DHCP is the default addressing profile
netcfg=/etc/persistent/mpower/network.conf
if [ ! -f "$netcfg" ]; then
  printf 'mode=dhcp\nip=\nnetmask=\ngateway=\ndns=\ndns2=\n' > "$netcfg"
elif ! grep -q '^mode=' "$netcfg" 2>/dev/null; then
  printf 'mode=dhcp\nip=\nnetmask=\ngateway=\ndns=\ndns2=\n' > "$netcfg"
fi

set_sta_wds() {
  want=$1
  if [ "$want" = wds ]; then
    iwpriv ath0 wds 1 2>/dev/null || true
    wdsval=enabled
  else
    iwpriv ath0 wds 0 2>/dev/null || true
    wdsval=disabled
  fi
  if [ -f /tmp/system.cfg ]; then
    if grep -q '^wireless\.1\.wds=' /tmp/system.cfg 2>/dev/null; then
      sed "s/^wireless\\.1\\.wds=.*/wireless.1.wds=$wdsval/" /tmp/system.cfg > /tmp/system.cfg.mp.$$ 2>/dev/null \
        && mv /tmp/system.cfg.mp.$$ /tmp/system.cfg
    else
      printf 'wireless.1.wds=%s\n' "$wdsval" >> /tmp/system.cfg
    fi
  fi
}

# Same radio as stock :8080: leave recovery AP up while STA associates.
# Beacon may hitch; clients reconnect when ath1 is back. Hide AP only in
# cleanup → ap-control sync after a real LAN IP (sta_ok).
/etc/persistent/mpower/bin/ap-control.sh sync >/tmp/mpower-ap.log 2>&1 || true

if [ "$security" = wpa ]; then
  if [ ${#psk} -lt 8 ] || [ ${#psk} -gt 63 ]; then
    mark_hold bad_password
    write_result fail bad_password "WPA password length"
    exit 2
  fi
  umask 077
  {
    printf 'ctrl_interface=/var/run/wpa_supplicant\n'
    printf 'network={\n  ssid="%s"\n' "$(escape "$ssid")"
    printf '  key_mgmt=WPA-PSK\n  proto=WPA RSN\n  pairwise=CCMP TKIP\n'
    printf '  psk="%s"\n}\n' "$(escape "$psk")"
  } > /tmp/mpower-wpa.conf
fi

start_sta() {
  killall wpa_supplicant 2>/dev/null || true
  iwconfig ath0 mode Managed 2>/dev/null || true
  ifconfig ath0 up 2>/dev/null || true
  set_sta_wds "$mode"
  if [ "$security" = wpa ]; then
    /sbin/wpa_supplicant -B -Datheros -iath0 -c/tmp/mpower-wpa.conf -P/var/run/mpower-wpa.pid
    return $?
  fi
  /sbin/iwconfig ath0 essid "$ssid" key off
  return 0
}

wait_assoc() {
  assoc=
  i=0
  limit=${1:-25}
  while [ "$i" -lt "$limit" ]; do
    ap=$(iwconfig ath0 2>/dev/null | sed -n 's/.*Access Point: \([^ ]*\).*/\1/p')
    case "$ap" in
      ''|Not-Associated|00:00:00:00:00:00) ;;
      *) assoc=$ap; return 0 ;;
    esac
    sleep 1
    i=$((i + 1))
  done
  return 1
}

# keep-ap: one short try so recovery AP is not down for ~50s every minute.
max_try=2
assoc_wait=25
if [ "$KEEP_AP" = 1 ]; then
  max_try=1
  assoc_wait=10
fi

assoc=
try=0
while [ "$try" -lt "$max_try" ]; do
  try=$((try + 1))
  write_result running associating "attempt $try/$max_try"
  if ! start_sta; then
    [ "$try" -lt "$max_try" ] && sleep 2 && continue
    [ -x /etc/persistent/mpower/bin/boot-mark.sh ] && \
      /etc/persistent/mpower/bin/boot-mark.sh wifi.wpa_start.failed
    mark_hold wpa_start
    write_result fail wpa_start "wpa_supplicant failed after $try attempts"
    exit 3
  fi
  if wait_assoc "$assoc_wait"; then
    break
  fi
done

if [ -z "$assoc" ]; then
  [ -x /etc/persistent/mpower/bin/boot-mark.sh ] && \
    /etc/persistent/mpower/bin/boot-mark.sh wifi.associate.failed
  mark_hold associate
  write_result fail associate "SSID not found or wrong password ($try attempts)"
  exit 4
fi

[ -x /etc/persistent/mpower/bin/boot-mark.sh ] && /etc/persistent/mpower/bin/boot-mark.sh wifi.associated
write_result running dhcp

# One DHCP wait after associate. No fallback IP — stay on recovery AP.
/etc/persistent/mpower/bin/network-apply.sh >/tmp/mpower-net.log 2>&1 || true
j=0
gotip=
while [ "$j" -lt 15 ]; do
  ip=$(ifconfig ath0 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p')
  if [ -n "$ip" ] && [ "$ip" != "192.168.1.50" ]; then gotip=$ip; break; fi
  if [ $((j % 5)) -eq 4 ]; then
    /etc/persistent/mpower/bin/network-apply.sh >>/tmp/mpower-net.log 2>&1 || true
  fi
  sleep 1
  j=$((j + 1))
done

if [ -z "$gotip" ]; then
  mark_hold dhcp
  write_result fail dhcp "associated but no IP from DHCP"
  [ -x /etc/persistent/mpower/bin/boot-mark.sh ] && \
    /etc/persistent/mpower/bin/boot-mark.sh wifi.ip.dhcp.failed
  exit 5
fi

write_result ok linked "$gotip"
touch /etc/persistent/mpower/.setup_done
[ -x /etc/persistent/mpower/bin/boot-mark.sh ] && /etc/persistent/mpower/bin/boot-mark.sh "wifi.ip.dhcp $gotip"
exit 0
