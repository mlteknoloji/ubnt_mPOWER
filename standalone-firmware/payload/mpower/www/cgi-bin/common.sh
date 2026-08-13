#!/bin/sh
# Shared helpers for mPower CGI/bin scripts.
MP_ROOT=/etc/persistent/mpower
MP_DATA=$MP_ROOT/data
MP_TMP=/tmp/mpower
[ -d /tmp/mpower-sess ] || mkdir -p "$MP_DATA" "$MP_TMP" /tmp/mpower-sess 2>/dev/null

json_header() {
  printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n'
}

html_header() {
  printf 'Content-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\n\r\n'
}

query_get() {
  printf '%s' "$QUERY_STRING" | sed -n "s/.*\(^\|&\)$1=\([^&]*\)\(&\|$\).*/\2/p"
}

url_decode() {
  # Do not use printf %b with \xHH here. Some device BusyBox versions consume
  # the character following the hex escape (for example %2Fmltek -> /ltek and
  # %21Qa -> !a). Decode each percent triplet explicitly with awk instead.
  printf '%s' "$1" | awk '
    function hex(c) { return index("0123456789ABCDEF", toupper(c)) - 1 }
    {
      gsub(/\+/, " ")
      out = ""
      while (match($0, /%[0-9A-Fa-f][0-9A-Fa-f]/)) {
        out = out substr($0, 1, RSTART - 1)
        hi = hex(substr($0, RSTART + 1, 1))
        lo = hex(substr($0, RSTART + 2, 1))
        out = out sprintf("%c", hi * 16 + lo)
        $0 = substr($0, RSTART + 3)
      }
      printf "%s%s", out, $0
    }'
}

cookie_get() {
  printf '%s' "${HTTP_COOKIE:-}" | sed -n "s/.*\(^\|; \)$1=\([^;]*\).*/\2/p"
}

hash_pass() {
  printf '%s' "mpower:$1" | md5sum | awk '{print $1}'
}

device_id() {
  # Prefer MAC of ath0/br0 for stable HA object_id
  mac=$(ifconfig ath0 2>/dev/null | sed -n 's/.*HWaddr //p' | tr -d ':\n' | tr 'A-F' 'a-f')
  [ -n "$mac" ] || mac=$(ifconfig br0 2>/dev/null | sed -n 's/.*HWaddr //p' | tr -d ':\n' | tr 'A-F' 'a-f')
  [ -n "$mac" ] || mac=mpower
  printf '%s' "$mac"
}
