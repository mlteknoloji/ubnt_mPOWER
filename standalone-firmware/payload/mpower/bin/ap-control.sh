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
  enabled=$(sed -n 's/^enabled=//p' "$ROOT/led.conf" 2>/dev/null | head -1)
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

ap_down() {
  was=$(cat "$STATE" 2>/dev/null)
  ifconfig ath1 down 2>/dev/null
  ifconfig ath2 down 2>/dev/null
  # Do not leave the recovery /24 active after joining a LAN.  When the
  # selected LAN is also 192.168.2.0/24, keeping 192.168.2.20 on br0 creates
  # two connected routes and replies for ath0 may leave through br0.
  ifconfig br0 0.0.0.0 2>/dev/null || true
  # Recovery AP is being hidden because the Wi-Fi client is linked.
  set_led 1
  echo down > "$STATE"
  [ "$was" = down ] || log "AP down (STA linked)"
}

ap_up() {
  ifconfig ath1 up 2>/dev/null
  ifconfig ath2 up 2>/dev/null
  # Restore the recovery address when the AP is needed again.
  bip=$(ifconfig br0 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p')
  [ "$bip" = 192.168.2.20 ] || ifconfig br0 192.168.2.20 netmask 255.255.255.0 2>/dev/null
  set_led 2
  echo up > "$STATE"
  log "AP up (recovery)"
}

sync_ap() {
  # No client profile → always keep recovery AP for setup
  if [ ! -f "$ROOT/wifi.conf" ]; then
    ap_is_beaconing || ap_up
    echo up > "$STATE"
    return 0
  fi
  if sta_ok; then
    # A valid client link always wins. Recovery returns automatically if the
    # association or DHCP address is later lost.
    ap_down
    set_led 1
  else
    ap_is_beaconing || ap_up
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
