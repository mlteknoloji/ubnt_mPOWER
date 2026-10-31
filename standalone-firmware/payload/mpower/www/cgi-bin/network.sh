#!/bin/sh
case "$0" in */*) CGI_DIR=${0%/*} ;; *) CGI_DIR=. ;; esac
. "$CGI_DIR/common.sh"
. "$CGI_DIR/auth.sh"
cfg=$MP_ROOT/network.conf
action=$(query_get action)

# Same rules as network.html. Error codes map to netErr_* texts in i18n.js.
# Octets 0-255 without leading zeros: Linux reads "010" as octal (= 8).
oct_ok() {
  case "$1" in 0|[1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5]) return 0 ;; esac
  return 1
}
valid_ip() {
  case "$1" in ''|*[!0-9.]*|.*|*.|*..*|*.*.*.*.*) return 1 ;; esac
  oldIFS=$IFS; IFS=.; set -- $1; IFS=$oldIFS
  [ $# = 4 ] || return 1
  for o; do oct_ok "$o" || return 1; done
}
# split PREFIX A.B.C.D -> PREFIX1..PREFIX4 (input already validated)
split4() {
  sp=$1
  oldIFS=$IFS; IFS=.; set -- $2; IFS=$oldIFS
  eval "${sp}1=$1 ${sp}2=$2 ${sp}3=$3 ${sp}4=$4"
}
# Contiguous mask /8../30 (/31 and /32 leave no room for a gateway).
valid_mask() {
  valid_ip "$1" || return 1
  split4 m "$1"
  pre=0; zero=0
  for o in $m1 $m2 $m3 $m4; do
    [ "$zero" = 1 ] && [ "$o" != 0 ] && return 1
    case "$o" in
      255) pre=$((pre + 8)) ;; 254) pre=$((pre + 7)); zero=1 ;; 252) pre=$((pre + 6)); zero=1 ;;
      248) pre=$((pre + 5)); zero=1 ;; 240) pre=$((pre + 4)); zero=1 ;; 224) pre=$((pre + 3)); zero=1 ;;
      192) pre=$((pre + 2)); zero=1 ;; 128) pre=$((pre + 1)); zero=1 ;; 0) zero=1 ;;
      *) return 1 ;;
    esac
  done
  [ "$pre" -ge 8 ] && [ "$pre" -le 30 ]
}
# host_err PREFIX ADDR -> prints "" when ADDR is a usable host in mask m*,
# else reserved|network|broadcast. Needs split4 m done.
host_err() {
  split4 h "$2"
  if [ "$h1" = 0 ] || [ "$h1" = 127 ] || [ "$h1" -ge 224 ]; then echo reserved; return; fi
  hz=1; hb=1
  for i in 1 2 3 4; do
    eval "o=\$h$i; mm=\$m$i"
    inv=$((255 - mm))
    [ $((o & inv)) = 0 ] || hz=0
    [ $((o & inv)) = "$inv" ] || hb=0
  done
  [ "$hz" = 1 ] && { echo network; return; }
  [ "$hb" = 1 ] && echo broadcast
}
# Public resolver or LAN host; not 0.x, 127.x or multicast.
valid_dns() {
  valid_ip "$1" || return 1
  split4 d "$1"
  [ "$d1" != 0 ] && [ "$d1" != 127 ] && [ "$d1" -lt 224 ]
}
net_err() { json_header; printf '{"ok":false,"error":"%s"}' "$1"; exit 0; }

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
      valid_ip "$ip" || net_err ip_invalid
      valid_mask "$mask" || net_err mask_invalid
      e=$(host_err h "$ip"); [ -n "$e" ] && net_err "ip_$e"
      valid_ip "$gw" || net_err gw_invalid
      e=$(host_err h "$gw"); [ -n "$e" ] && net_err "gw_$e"
      [ "$gw" = "$ip" ] && net_err gw_equals_ip
      split4 a "$ip"; split4 g "$gw"
      for i in 1 2 3 4; do
        eval "x=\$a$i; y=\$g$i; mm=\$m$i"
        [ $((x & mm)) = $((y & mm)) ] || net_err gw_subnet
      done
      if [ -n "$dns" ]; then valid_dns "$dns" || net_err dns_invalid; else dns=1.1.1.1; fi
      if [ -n "$dns2" ]; then valid_dns "$dns2" || net_err dns2_invalid; else dns2=8.8.8.8; fi
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
