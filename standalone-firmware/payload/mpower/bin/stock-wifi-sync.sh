#!/bin/sh
# Mirror NetRelayMP Wi-Fi settings into the stock mFi system.cfg so ath0 can
# associate during the normal stock boot, before delayed rc.poststart runs.
ROOT=/etc/persistent/mpower
WIFI=$ROOT/wifi.conf
CFG=/tmp/system.cfg
LOG=/tmp/mpower-stock-wifi.log

[ -f "$WIFI" ] || exit 0
[ -f "$CFG" ] || { echo "system.cfg missing" > "$LOG"; exit 1; }

ssid=$(sed -n 's/^ssid=//p' "$WIFI" | head -1)
security=$(sed -n 's/^security=//p' "$WIFI" | head -1)
psk=$(sed -n 's/^psk=//p' "$WIFI" | head -1)
[ -n "$ssid" ] || exit 1

# Replace one flat key without using the value in a sed expression.
put() {
  key=$1
  value=$2
  tmp=/tmp/system.cfg.mp.$$
  grep -v "^${key}=" "$CFG" > "$tmp" 2>/dev/null || true
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  mv "$tmp" "$CFG"
}

del() {
  key=$1
  tmp=/tmp/system.cfg.mp.$$
  grep -v "^${key}=" "$CFG" > "$tmp" 2>/dev/null || true
  mv "$tmp" "$CFG"
}

put wireless.1.mode managed
put wireless.1.devname ath0
put wireless.1.status enabled
put wireless.1.ssid "$ssid"
put wireless.1.wds disabled
put dhcpc.status enabled
put dhcpc.1.status enabled
put dhcpc.1.devname ath0
put netconf.1.devname ath0
put netconf.1.status enabled
put netconf.1.up enabled

if [ "$security" = wpa ]; then
  put wireless.1.security wpa2
  put aaa.status enabled
  put aaa.1.status enabled
  put aaa.1.devname ath0
  put aaa.1.driver madwifi
  put aaa.1.ssid "$ssid"
  put aaa.1.wpa 2
  put aaa.1.wpa.mode 2
  put aaa.1.wpa.1.pairwise CCMP
  put aaa.1.wpa.key.1.mgmt WPA-PSK
  put aaa.1.wpa.psk "$psk"
else
  put wireless.1.security none
  put aaa.1.status disabled
fi

# cfgmtd stores both system.cfg and /etc/persistent in the config MTD.
if cfgmtd -w -p /etc -f "$CFG" > "$LOG" 2>&1; then
  sync
  echo "stock Wi-Fi profile saved" >> "$LOG"
  # Keep boot-acceleration cron/pwdog in sync (does its own cfgmtd)
  [ -x "$ROOT/bin/ensure-boot-speed.sh" ] && \
    /bin/sh "$ROOT/bin/ensure-boot-speed.sh" >> "$LOG" 2>&1 || true
  exit 0
fi
echo "stock Wi-Fi profile save failed" >> "$LOG"
exit 1
