#!/bin/sh
# Fast relay CGI: one query parse, RAM auth cache, write /proc before JSON.
CACHE=/tmp/mpower-auth.cache
TOKEN_FILE=/etc/persistent/mpower/api.token
API_CONF=/etc/persistent/mpower/api.conf

fail() {
  printf 'Status: %s\r\nContent-Type: application/json\r\nCache-Control: no-store\r\n\r\n{"ok":false,"error":"%s"}' "$1" "$2"
  exit 0
}

[ "${REQUEST_METHOD:-GET}" = POST ] || fail "405 Method Not Allowed" "POST required"

port=; state=; delay=; to=; token=
oldifs=$IFS
IFS='&'
set -f
for kv in $QUERY_STRING; do
  k=${kv%%=*}
  v=${kv#*=}
  case "$k" in
    port) port=$v ;;
    state) state=$v ;;
    delay) delay=$v ;;
    to) to=$v ;;
    token) token=$v ;;
  esac
done
set +f
IFS=$oldifs
[ -n "$token" ] || token=${HTTP_X_MPOWER_TOKEN:-}

tok=; rest=1
if [ -f "$CACHE" ]; then
  while IFS= read line; do
    case "$line" in
      token=*) tok=${line#token=} ;;
      rest=*) rest=${line#rest=} ;;
    esac
  done < "$CACHE"
else
  tok=$(tr -d '\r\n' < "$TOKEN_FILE" 2>/dev/null)
  [ -f "$API_CONF" ] && grep -q '^enabled=0$' "$API_CONF" && rest=0
  printf 'token=%s\nrest=%s\n' "$tok" "$rest" > "$CACHE"
fi

ok=0
if [ "$rest" != 0 ] && [ -n "$token" ] && [ -n "$tok" ] && [ "$token" = "$tok" ]; then
  ok=1
elif [ "$rest" != 0 ] && [ ! -f "$TOKEN_FILE" ]; then
  ok=1
else
  sid=
  case "${HTTP_COOKIE:-}" in
    *MPOWERSESS=*)
      sid=${HTTP_COOKIE#*MPOWERSESS=}
      sid=${sid%%;*}
      sid=${sid%% *}
      ;;
  esac
  [ -n "$sid" ] && [ -f "/tmp/mpower-sess/$sid" ] && ok=1
fi
if [ "$ok" != 1 ]; then
  [ "$rest" = 0 ] && fail "403 Forbidden" "rest api disabled"
  fail "401 Unauthorized" "API token required"
fi

case "$port" in 1|2|3|all) ;; *) printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n{"ok":false,"error":"invalid request"}'; exit 0 ;; esac
case "$state" in on|off|cycle|pulse) ;; *) printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n{"ok":false,"error":"invalid request"}'; exit 0 ;; esac
case "$delay" in ''|*[!0-9]*) delay=10 ;; esac
[ "$delay" -gt 600 ] && delay=600
ports=$port
[ "$port" = all ] && ports="1 2 3"

# Relay first — physical switch must not wait on JSON/httpd flush.
if [ "$state" = cycle ]; then
  for p in $ports; do
    prev=$(cat /proc/power/relay"$p" 2>/dev/null || echo 1)
    printf 0 > /proc/power/relay"$p"
    ( sleep "$delay"; printf '%s' "$prev" > /proc/power/relay"$p" ) &
  done
  printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n{"ok":true,"action":"cycle","port":"%s","delay":%s}' "$port" "$delay"
  exit 0
fi

if [ "$state" = pulse ]; then
  for p in $ports; do
    prev=$(cat /proc/power/relay"$p" 2>/dev/null || echo 0)
    if [ "$to" = 0 ] || [ "$to" = 1 ]; then target=$to
    else
      [ "$prev" = 1 ] && target=0 || target=1
    fi
    printf '%s' "$target" > /proc/power/relay"$p"
    ( sleep "$delay"; printf '%s' "$prev" > /proc/power/relay"$p" ) &
  done
  printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n{"ok":true,"action":"pulse","port":"%s","delay":%s}' "$port" "$delay"
  exit 0
fi

[ "$state" = on ] && value=1 || value=0
for p in $ports; do
  printf '%s' "$value" > /proc/power/relay"$p"
done
printf 'Content-Type: application/json\r\nCache-Control: no-store\r\n\r\n{"ok":true,"port":"%s","relay":%s}' "$port" "$value"
