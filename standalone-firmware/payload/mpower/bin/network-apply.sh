#!/bin/sh
# Apply DHCP or static IPv4 on ath0 (station).
# No network.conf → DHCP (first setup / after Wi‑Fi connect).
# Recovery AP (ath1/br0 192.168.2.20) is managed by ap-control.sh.
cfg=/etc/persistent/mpower/network.conf
LOG=/tmp/mpower-net.log

log() { echo "$(date 2>/dev/null) $*" >> "$LOG"; }

mode=dhcp
ip=; mask=; gw=; dns=; dns2=
if [ -f "$cfg" ]; then
  mode=$(sed -n 's/^mode=//p' "$cfg" | head -1)
  ip=$(sed -n 's/^ip=//p' "$cfg" | head -1)
  mask=$(sed -n 's/^netmask=//p' "$cfg" | head -1)
  gw=$(sed -n 's/^gateway=//p' "$cfg" | head -1)
  dns=$(sed -n 's/^dns=//p' "$cfg" | head -1)
  dns2=$(sed -n 's/^dns2=//p' "$cfg" | head -1)
fi
[ -n "$mode" ] || mode=dhcp
case "$mode" in static) ;; *) mode=dhcp ;; esac

start_dhcp() {
  log "DHCP start on ath0"
  ifconfig ath0 up 2>/dev/null || true
  # Prefer an already-running stock udhcpc (inittab respawn). Killing it on
  # every connect races the lease and often forces the 192.168.1.50 fallback.
  if ps w 2>/dev/null | grep '[u]dhcpc' | grep -q ath0; then
    log "stock udhcpc already running — leave it"
    # Nudge renew if the binary supports USR1
    pid=$(sed -n 's/[^0-9]//g;p' /var/run/udhcpc.ath0.pid 2>/dev/null)
    [ -n "$pid" ] && kill -USR1 "$pid" 2>/dev/null || true
    return 0
  fi
  udhcpc -i ath0 -b -p /var/run/udhcpc.ath0.pid -R >/tmp/mpower-udhcpc.log 2>&1 &
  log "udhcpc spawned pid=$!"
}

if [ "$mode" = static ] && [ -n "$ip" ] && [ -n "$mask" ]; then
  log "static $ip/$mask gw=$gw"
  killall udhcpc 2>/dev/null || true
  ifconfig ath0 "$ip" netmask "$mask" up
  if [ -n "$gw" ]; then
    route del default 2>/dev/null
    route add default gw "$gw" 2>/dev/null
  fi
  {
    [ -n "$dns" ] && printf 'nameserver %s\n' "$dns"
    [ -n "$dns2" ] && [ "$dns2" != "$dns" ] && printf 'nameserver %s\n' "$dns2"
  } > /etc/resolv.conf
  cp /etc/resolv.conf /etc/persistent/mpower/resolv.conf 2>/dev/null
else
  start_dhcp
fi
exit 0
