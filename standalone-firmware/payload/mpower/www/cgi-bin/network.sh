#!/bin/sh
. "$(dirname "$0")/common.sh"
. "$(dirname "$0")/auth.sh"
cfg=$MP_ROOT/network.conf
action=$(query_get action)

# Valid IPv4: a.b.c.d each 0-255
valid_ip() {
  echo "$1" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || return 1
  oldIFS=$IFS
  IFS=.
  set -- $1
  IFS=$oldIFS
  for o in "$1" "$2" "$3" "$4"; do
    case "$o" in ''|*[!0-9]*) return 1;; esac
    [ "$o" -le 255 ] 2>/dev/null || return 1
  done
  return 0
}

# Contiguous netmask (e.g. 255.255.255.0), not 0.0.0.0
valid_mask() {
  valid_ip "$1" || return 1
  oldIFS=$IFS
  IFS=.
  set -- $1
  IFS=$oldIFS
  # build hex via printf
  bits=$(printf '%02x%02x%02x%02x' "$1" "$2" "$3" "$4")
  [ "$bits" = "00000000" ] && return 1
  # check pattern: 1+ then 0+ in binary — use awk
  echo "$1 $2 $3 $4" | awk '{
    n=0
    for(i=1;i<=4;i++) n=n*256+$i
    # find first 0 bit from MSB, then rest must be 0
    seen0=0
    for(b=31;b>=0;b--){
      bit=int(n/2^b)%2
      if(bit==0) seen0=1
      else if(seen0){ print "bad"; exit }
    }
    print "ok"
  }' | grep -q ok
}

case "$action" in
  ''|get|status)
    json_header
    mode=dhcp; ip=; mask=; gw=; dns=; dns2=
    [ -f "$cfg" ] && {
      mode=$(sed -n 's/^mode=//p' "$cfg" | head -1)
      ip=$(sed -n 's/^ip=//p' "$cfg" | head -1)
      mask=$(sed -n 's/^netmask=//p' "$cfg" | head -1)
      gw=$(sed -n 's/^gateway=//p' "$cfg" | head -1)
      dns=$(sed -n 's/^dns=//p' "$cfg" | head -1)
      dns2=$(sed -n 's/^dns2=//p' "$cfg" | head -1)
    }
    cur=$(ifconfig ath0 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p')
    cmask=$(ifconfig ath0 2>/dev/null | sed -n 's/.*Mask:\([0-9.]*\).*/\1/p')
    cgw=$(route -n 2>/dev/null | awk '/^0.0.0.0/{print $2; exit}')
    cdns=$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf 2>/dev/null)
    cdns2=$(awk '/^nameserver/{c++; if(c==2){print $2; exit}}' /etc/resolv.conf 2>/dev/null)
    printf '{"ok":true,"mode":"%s","ip":"%s","netmask":"%s","gateway":"%s","dns":"%s","dns2":"%s","current":{"ip":"%s","netmask":"%s","gateway":"%s","dns":"%s","dns2":"%s","fallback":"192.168.2.20"}}' \
      "${mode:-dhcp}" "$ip" "$mask" "$gw" "$dns" "$dns2" "$cur" "$cmask" "$cgw" "$cdns" "$cdns2"
    ;;
  set)
    require_token || exit 0
    mode=$(query_get mode)
    ip=$(url_decode "$(query_get ip)")
    mask=$(url_decode "$(query_get netmask)")
    gw=$(url_decode "$(query_get gateway)")
    dns=$(url_decode "$(query_get dns)")
    dns2=$(url_decode "$(query_get dns2)")
    case "$mode" in dhcp|static) ;; *) json_header; printf '{"ok":false,"error":"mode"}'; exit 0;; esac
    if [ "$mode" = static ]; then
      valid_ip "$ip" || { json_header; printf '{"ok":false,"error":"invalid ip"}'; exit 0; }
      valid_mask "$mask" || { json_header; printf '{"ok":false,"error":"invalid netmask"}'; exit 0; }
      valid_ip "$gw" || { json_header; printf '{"ok":false,"error":"invalid gateway"}'; exit 0; }
      if [ -n "$dns" ]; then
        valid_ip "$dns" || { json_header; printf '{"ok":false,"error":"invalid dns"}'; exit 0; }
      else
        dns=1.1.1.1
      fi
      if [ -n "$dns2" ]; then
        valid_ip "$dns2" || { json_header; printf '{"ok":false,"error":"invalid dns2"}'; exit 0; }
      else
        dns2=8.8.8.8
      fi
    fi
    umask 077
    {
      printf 'mode=%s\n' "$mode"
      printf 'ip=%s\n' "$ip"
      printf 'netmask=%s\n' "$mask"
      printf 'gateway=%s\n' "$gw"
      printf 'dns=%s\n' "$dns"
      printf 'dns2=%s\n' "$dns2"
    } > "$cfg"
    cfgmtd -w -p /etc >/dev/null 2>&1
    /etc/persistent/mpower/bin/network-apply.sh >/tmp/mpower-net.log 2>&1 &
    json_header
    printf '{"ok":true,"message":"applied","fallback":"192.168.2.20"}'
    ;;
  *)
    json_header; printf '{"ok":false,"error":"unknown"}'
    ;;
esac
