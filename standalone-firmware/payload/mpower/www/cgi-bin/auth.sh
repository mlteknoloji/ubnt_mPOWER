#!/bin/sh
# Auth: API token (REST) and/or web session cookie (UI).
. "$(dirname "$0")/common.sh"
token_file=$MP_ROOT/api.token
pass_file=$MP_ROOT/admin.pass

has_session() {
  sid=$(cookie_get MPOWERSESS)
  [ -n "$sid" ] && [ -f "/tmp/mpower-sess/$sid" ]
}

# Local /bin/sh CGI (MQTT update) has no REMOTE_ADDR.
is_local_cgi() {
  case "${REMOTE_ADDR:-}" in ''|127.0.0.1) return 0 ;; esac
  return 1
}

AUTH_CACHE=/tmp/mpower-auth.cache

write_auth_cache() {
  tok=$(tr -d '\r\n' < "$token_file" 2>/dev/null)
  v=$(sed -n 's/^enabled=//p' "$MP_ROOT/api.conf" 2>/dev/null | head -1)
  [ "$v" = 0 ] && r=0 || r=1
  printf 'token=%s\nrest=%s\n' "$tok" "$r" > "$AUTH_CACHE"
}

# api.conf enabled=0 turns off token REST. Missing file = on.
rest_enabled() {
  if [ -f "$AUTH_CACHE" ]; then
    v=$(sed -n 's/^rest=//p' "$AUTH_CACHE" | head -1)
    [ "$v" != 0 ]
    return $?
  fi
  v=$(sed -n 's/^enabled=//p' "$MP_ROOT/api.conf" 2>/dev/null | head -1)
  [ "$v" != 0 ]
}

deny_json() {
  code=$1; err=$2
  printf 'Status: %s\r\nContent-Type: application/json\r\nCache-Control: no-store\r\n\r\n{"ok":false,"error":"%s"}' "$code" "$err"
}

require_session_only() {
  if has_session; then return 0; fi
  deny_json "401 Unauthorized" "login required"
  return 1
}

require_token() {
  [ -f "$token_file" ] || return 0
  if [ "${REQUEST_METHOD:-GET}" != POST ]; then
    printf 'Status: 405 Method Not Allowed\r\nAllow: POST\r\nContent-Type: application/json\r\nCache-Control: no-store\r\n\r\n{"ok":false,"error":"POST required"}'
    return 1
  fi
  supplied=${HTTP_X_MPOWER_TOKEN:-}
  [ -n "$supplied" ] || supplied=$(query_get token)
  if [ -n "$supplied" ]; then
    [ -f "$AUTH_CACHE" ] || write_auth_cache
    expected=
    rest=1
    while IFS= read line; do
      case "$line" in
        token=*) expected=${line#token=} ;;
        rest=*) rest=${line#rest=} ;;
      esac
    done < "$AUTH_CACHE"
    if [ "$rest" != 0 ] && [ "$supplied" = "$expected" ]; then return 0; fi
  fi
  if has_session; then return 0; fi
  if ! rest_enabled && ! is_local_cgi; then
    deny_json "403 Forbidden" "rest api disabled"
    return 1
  fi
  deny_json "401 Unauthorized" "API token required"
  return 1
}

require_session_json() {
  if has_session; then return 0; fi
  if ! rest_enabled && ! is_local_cgi; then
    deny_json "401 Unauthorized" "login required"
    return 1
  fi
  expected=$(tr -d '\r\n' < "$token_file" 2>/dev/null)
  supplied=${HTTP_X_MPOWER_TOKEN:-}
  [ -n "$supplied" ] || supplied=$(query_get token)
  if [ -n "$expected" ] && [ "$supplied" = "$expected" ]; then return 0; fi
  deny_json "401 Unauthorized" "login required"
  return 1
}
