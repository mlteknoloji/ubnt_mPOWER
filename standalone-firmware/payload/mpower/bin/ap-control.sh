#!/bin/sh
# Recovery AP (ath1/ath2 → br0 / 192.168.2.20):
#   STA associated + real LAN IP (DHCP/static, not 192.168.1.50) → hide AP
#   STA associated but no DHCP / emergency fallback               → keep AP
#   STA down / connect error / no wifi.conf                       → keep AP
ROOT=/etc/persistent/mpower
STATE=/tmp/mpower-ap.state
LOG=/tmp/mpower-ap.log
# Emergency STA address assigned when DHCP times out — not a real lease.
FALLBACK_IP=192.168.1.50

log() { echo "$(date 2>/dev/null) $*" >> "$LOG"; tail -n 60 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"; }

# mPower front LED: 1=blue, 2=yellow (reported by /proc/led/status).
set_led() {
  enabled=
  [ -f "$ROOT/led.conf" ] && while IFS= read l; do
    case "$l" in enabled=*) enabled=${l#enabled=}; break ;; esac
  done < "$ROOT/led.conf"
  [ "$enabled" = 0 ] && value=0 || value=$1
  [ -w /proc/led/status ] && echo "$value" > /proc/led/status 2>/dev/null || true
}

sta_ok() {
  ap=$(iwconfig ath0 2>/dev/null | sed -n 's/.*Access Point: \([^ ]*\).*/\1/p')
  case "$ap" in
    ''|Not-Associated|00:00:00:00:00:00) return 1 ;;
  esac
  ip=$(ifconfig ath0 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p')
  [ -n "$ip" ] || return 1
  # Fallback is only a placeholder until DHCP (or static) succeeds.
  [ "$ip" = "$FALLBACK_IP" ] && return 1
  return 0
}

ap_is_beaconing() {
  ap=$(iwconfig ath1 2>/dev/null | sed -n 's/.*Access Point: \([^ ]*\).*/\1/p')
  case "$ap" in
    ''|Not-Associated|00:00:00:00:00:00) return 1 ;;
  esac
  return 0
}

# iface_up IF: IFF_UP bit from sysfs (no fork). Unknown -> assume up.
iface_up() {
  [ -r "/sys/class/net/$1/flags" ] || return 0
  fl=0; read fl < "/sys/class/net/$1/flags"
  [ $((fl & 1)) -ne 0 ] 2>/dev/null
}

# init respawns "/bin/hostapd /etc/aaa1.cfg" from /etc/inittab. While ath1 is
# down it exits within a second and init restarts it at once: ~1 start/s at
# ~60% CPU each (seen 2026-10-30). A STOPPED process never exits, so freeze it
# while the AP is meant to be down; when the AP is needed again, kill the
# frozen one so init starts a fresh hostapd on the now-up interface.
proc_state() { pst=; read pst < "/proc/$1/stat" 2>/dev/null; set -- $pst; pst=$3; }
freeze_hostapd() {
  tries=0
  while [ "$tries" -lt 3 ]; do
    frozen=0
    for hp in $(pidof hostapd 2>/dev/null); do
      proc_state "$hp"
      [ "$pst" = T ] || kill -STOP "$hp" 2>/dev/null
      frozen=1
    done
    # Between two respawns no hostapd may exist; catch the next one.
    [ "$frozen" = 1 ] && return 0
    tries=$((tries + 1)); sleep 1
  done
}
thaw_hostapd() {
  for hp in $(pidof hostapd 2>/dev/null); do
    proc_state "$hp"
    [ "$pst" = T ] && kill -9 "$hp" 2>/dev/null && log "hostapd $hp restarted (AP needed)"
  done
}

ap_down() {
  was=; [ -f "$STATE" ] && read was < "$STATE"
  # Watchdog calls this every 30 s while linked: skip the ifconfig/LED work
  # when the AP is already down (only the LED is refreshed, fork-free).
  if [ "$was" = down ] && ! iface_up ath1 && ! iface_up ath2; then
    set_led 1
    freeze_hostapd
    return 0
  fi
  ifconfig ath1 down 2>/dev/null
  ifconfig ath2 down 2>/dev/null
  # Do not leave the recovery /24 active after joining a LAN.  When the
  # selected LAN is also 192.168.2.0/24, keeping 192.168.2.20 on br0 creates
  # two connected routes and replies for ath0 may leave through br0.
  ifconfig br0 0.0.0.0 2>/dev/null || true
  # Recovery AP is being hidden because the Wi-Fi client is linked.
  set_led 1
  echo down > "$STATE"
  freeze_hostapd
  [ "$was" = down ] || log "AP down (STA linked)"
}

ap_up() {
  ifconfig ath1 up 2>/dev/null
  ifconfig ath2 up 2>/dev/null
  thaw_hostapd
  # Restore the recovery address when the AP is needed again.
  bip=$(ifconfig br0 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p')
  [ "$bip" = 192.168.2.20 ] || ifconfig br0 192.168.2.20 netmask 255.255.255.0 2>/dev/null
  set_led 2
  echo up > "$STATE"
  log "AP up (recovery)"
}

sync_ap() {
  # No client profile → always keep recovery AP for setup
  # When the AP is wanted, a frozen hostapd must go even if ath1 already
  # beacons: without it clients cannot authenticate to the recovery AP.
  if [ ! -f "$ROOT/wifi.conf" ]; then
    ap_is_beaconing || ap_up
    thaw_hostapd
    echo up > "$STATE"
    return 0
  fi
  if sta_ok; then
    # A valid client link always wins. Recovery returns automatically if the
    # association or DHCP address is later lost.
    ap_down
  else
    ap_is_beaconing || ap_up
    thaw_hostapd
    echo up > "$STATE"
  fi
}

case "$1" in
  down) ap_down ;;
  up) ap_up ;;
  status)
    printf 'desired=%s sta_ok=' "$(cat "$STATE" 2>/dev/null)"
    if sta_ok; then echo 1; else echo 0; fi
    iwconfig ath0 2>/dev/null | head -3
    iwconfig ath1 2>/dev/null | head -3
    ;;
  sync|*) sync_ap ;;
esac
exit 0
