#!/bin/sh
# Wi-Fi CGI — always emit valid JSON (BusyBox-safe).
# Connect: write conf + reply FIRST, then start radio in background
# (STA associate can drop recovery AP mid-response → browser "Failed to fetch").
. "$(dirname "$0")/common.sh"
header() { printf 'Content-Type: application/json; charset=utf-8\r\nCache-Control: no-store\r\n\r\n'; }
raw() { query_get "$1"; }

json_esc() {
  printf '%s' "$1" | tr -d '\r\n\t' | sed 's/\\/\\\\/g;s/"/\\"/g'
}

action=$(raw action)

if [ "$action" = scan ]; then
  header
  tmp=/tmp/mpower-wifi-scan.$$
  /sbin/iwlist ath0 scanning 2>/dev/null \
    | awk '
      /ESSID:/ {
        s=$0; sub(/^.*ESSID:"/,"",s); sub(/".*$/,"",s)
      }
      /\(Channel [0-9]/ {
        ch=$0; sub(/^.*\(Channel /,"",ch); sub(/\).*$/,"",ch)
      }
      /Quality=/ {
        q=$0; sub(/^.*Quality=/,"",q); sub(/ .*/,"",q)
        sig=$0; sub(/^.*Signal level=/,"",sig); sub(/ .*/,"",sig)
        if (s != "") print s "|" ch "|" sig "|" q
        s=""; ch=""; sig=""; q=""
      }
    ' > "$tmp" 2>/dev/null
  printf '{"ok":true,"networks":['
  first=1
  while IFS='|' read -r ssid channel signal quality; do
    [ -n "$ssid" ] || continue
    esc=$(json_esc "$ssid")
    [ -n "$esc" ] || continue
    channel=$(printf '%s' "$channel" | tr -cd '0-9')
    signal=$(printf '%s' "$signal" | tr -cd '0-9-')
    [ -n "$channel" ] || channel=0
    case "$signal" in ''|-) signal=0;; esac
    qesc=$(json_esc "$quality")
    if [ "$first" = 1 ]; then first=0; else printf ','; fi
    printf '{"ssid":"%s","channel":%s,"signal":%s,"quality":"%s"}' \
      "$esc" "$channel" "$signal" "$qesc"
  done < "$tmp"
  printf ']}'
  rm -f "$tmp"
  exit 0
fi

if [ "$action" = status ]; then
  header
  ssid=$(iwconfig ath0 2>/dev/null | sed -n 's/.*ESSID:"\([^"]*\)".*/\1/p')
  ip=$(ifconfig ath0 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p')
  ap=$(iwconfig ath0 2>/dev/null | sed -n 's/.*Access Point: \([^ ]*\).*/\1/p')
  rap=$(iwconfig ath1 2>/dev/null | sed -n 's/.*Access Point: \([^ ]*\).*/\1/p')
  mode=station
  [ -f /etc/persistent/mpower/wifi.conf ] && mode=$(sed -n 's/^mode=//p' /etc/persistent/mpower/wifi.conf|head -1)
  case "$mode" in wds) mode=wds ;; *) mode=station ;; esac
  case "$ssid" in ''|off|any) ssid= ;; esac
  recovery=0
  case "$rap" in ''|Not-Associated|00:00:00:00:00:00) recovery=0 ;; *) recovery=1 ;; esac
  linked=0
  case "$ap" in ''|Not-Associated|00:00:00:00:00:00) linked=0 ;; *) linked=1 ;; esac

  # Last connect attempt result (written by wifi-client.sh)
  rstate=; rreason=; rdetail=; rattempt=0; rhold=0
  if [ -f /tmp/mpower-wifi-result ]; then
    rstate=$(sed -n 's/^state=//p' /tmp/mpower-wifi-result | head -1)
    rreason=$(sed -n 's/^reason=//p' /tmp/mpower-wifi-result | head -1)
    rdetail=$(sed -n 's/^detail=//p' /tmp/mpower-wifi-result | head -1)
    rattempt=$(sed -n 's/^attempt=//p' /tmp/mpower-wifi-result | head -1)
  fi
  [ -f /tmp/mpower-wifi.hold ] && rhold=1
  case "$rattempt" in ''|*[!0-9]*) rattempt=0 ;; esac

  printf '{"ok":true,"ssid":"%s","ip":"%s","ap":"%s","mode":"%s","linked":%s,"fallback_ip":"192.168.2.20","recovery_ap":%s,"hold":%s,"result":{"state":"%s","reason":"%s","detail":"%s","attempt":%s,"hold":%s}}' \
    "$(json_esc "$ssid")" "$(json_esc "$ip")" "$(json_esc "$ap")" "$(json_esc "$mode")" "$linked" "$recovery" "$rhold" \
    "$(json_esc "$rstate")" "$(json_esc "$rreason")" "$(json_esc "$rdetail")" "$rattempt" "$rhold"
  exit 0
fi

. "$(dirname "$0")/auth.sh"
require_token || exit 0
[ "$action" = connect ] || { header; printf '{"ok":false,"error":"unknown action"}'; exit 0; }
ssid=$(url_decode "$(raw ssid)")
security=$(raw security)
psk=$(url_decode "$(raw psk)")
mode=$(raw mode)
case "$mode" in wds) mode=wds ;; *) mode=station ;; esac
case "$security" in open|wpa) ;; *) header; printf '{"ok":false,"error":"invalid security"}'; exit 0;; esac
case "$ssid" in ''|*'\n'*|*'\r'*) header; printf '{"ok":false,"error":"invalid SSID"}'; exit 0;; esac
[ ${#ssid} -le 32 ] || { header; printf '{"ok":false,"error":"SSID too long"}'; exit 0; }
if [ "$security" = wpa ] && { [ ${#psk} -lt 8 ] || [ ${#psk} -gt 63 ]; }; then
  header; printf '{"ok":false,"error":"WPA password must be 8-63 characters"}'; exit 0
fi
case "$psk" in *'\n'*|*'\r'*) header; printf '{"ok":false,"error":"invalid password"}'; exit 0;; esac

umask 077
mkdir -p /etc/persistent/mpower
reuse=0
prev=/tmp/mpower-wifi-prev
if [ -f /etc/persistent/mpower/wifi.conf ]; then
  old_ssid=$(sed -n 's/^ssid=//p' /etc/persistent/mpower/wifi.conf | head -1)
  old_security=$(sed -n 's/^security=//p' /etc/persistent/mpower/wifi.conf | head -1)
  old_psk=$(sed -n 's/^psk=//p' /etc/persistent/mpower/wifi.conf | head -1)
  old_mode=$(sed -n 's/^mode=//p' /etc/persistent/mpower/wifi.conf | head -1)
  cp /etc/persistent/mpower/wifi.conf "$prev"
  [ "$ssid" = "$old_ssid" ] && [ "$security" = "$old_security" ] && \
    [ "$psk" = "$old_psk" ] && [ "$mode" = "${old_mode:-station}" ] && reuse=1
else
  rm -f "$prev"
fi
{ printf 'ssid=%s\nsecurity=%s\npsk=%s\nmode=%s\n' "$ssid" "$security" "$psk" "$mode"; } > /etc/persistent/mpower/wifi.conf

# First connect / setup: default to DHCP so ath0 gets an address after associate
if [ ! -f /etc/persistent/mpower/network.conf ]; then
  printf 'mode=dhcp\nip=\nnetmask=\ngateway=\ndns=\ndns2=\n' > /etc/persistent/mpower/network.conf
fi

rm -f /tmp/mpower-wifi.hold
# Mark connect in progress for UI polling
{
  printf 'state=running\n'
  printf 'reason=queued\n'
  printf 'detail=waiting to start\n'
  printf 'ssid=%s\n' "$ssid"
  printf 'attempt=0\n'
  printf 'hold=0\n'
  printf 'ts=%s\n' "$(date +%s 2>/dev/null || echo 0)"
} > /tmp/mpower-wifi-result

# Reply before radio work — keep recovery AP TCP session alive for the browser
header
printf '{"ok":true,"message":"connection started","mode":"%s","ip_mode":"dhcp","fallback_ip":"192.168.2.20","poll":true}' "$mode"

# Flush CGI output, then persist + connect after a short delay
(
  sleep 3
  # Same saved credentials + live link: do not tear down a working station.
  live_ssid=$(iwconfig ath0 2>/dev/null | sed -n 's/.*ESSID:"\([^"]*\)".*/\1/p')
  live_ip=$(ifconfig ath0 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p')
  if [ "$reuse" = 1 ] && [ "$live_ssid" = "$ssid" ] && \
     [ -n "$live_ip" ] && [ "$live_ip" != "192.168.1.50" ]; then
    touch /etc/persistent/mpower/.setup_done
    if /bin/sh /etc/persistent/mpower/bin/stock-wifi-sync.sh >/tmp/mpower-stock-wifi.log 2>&1; then
      printf 'state=ok\nreason=linked\ndetail=%s\nssid=%s\nts=%s\n' \
        "$live_ip" "$ssid" "$(date +%s 2>/dev/null || echo 0)" > /tmp/mpower-wifi-result
    else
      printf 'state=fail\nreason=persist\ndetail=flash save failed\nssid=%s\nts=%s\n' \
        "$ssid" "$(date +%s 2>/dev/null || echo 0)" > /tmp/mpower-wifi-result
    fi
    rm -f "$prev"
    exit 0
  fi

  # Changed credentials: prove association + IP first, persist only on success.
  if /bin/sh /etc/persistent/mpower/bin/wifi-client.sh >/tmp/mpower-wifi.log 2>&1; then
    touch /etc/persistent/mpower/.setup_done
    /bin/sh /etc/persistent/mpower/bin/stock-wifi-sync.sh >/tmp/mpower-stock-wifi.log 2>&1 || \
      printf 'state=fail\nreason=persist\ndetail=flash save failed\nssid=%s\nts=%s\n' \
        "$ssid" "$(date +%s 2>/dev/null || echo 0)" > /tmp/mpower-wifi-result
    rm -f "$prev"
  else
    # Wrong SSID/password must not replace the last known-good profile.
    if [ -f "$prev" ]; then mv "$prev" /etc/persistent/mpower/wifi.conf; else rm -f /etc/persistent/mpower/wifi.conf; fi
  fi
) >/dev/null 2>&1 &

exit 0
