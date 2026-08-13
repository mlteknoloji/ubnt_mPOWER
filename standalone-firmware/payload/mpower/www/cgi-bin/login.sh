#!/bin/sh
. "$(dirname "$0")/common.sh"
. "$(dirname "$0")/auth.sh"
pass_file=$MP_ROOT/admin.pass
action=$(query_get action)
DEFAULT_PASS=mltek

case "$action" in
  status)
    json_header
    sid=$(cookie_get MPOWERSESS)
    authed=0
    [ -n "$sid" ] && [ -f "/tmp/mpower-sess/$sid" ] && authed=1
    setup=0
    if [ ! -f "$MP_ROOT/.setup_done" ]; then
      setup=1
      # Wi‑Fi already joined (wizard CGI never ran after AP drop) — leave setup.
      ap=$(iwconfig ath0 2>/dev/null | sed -n 's/.*Access Point: \([^ ]*\).*/\1/p')
      ip=$(ifconfig ath0 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p')
      case "$ap" in
        ''|Not-Associated|00:00:00:00:00:00) ;;
        *)
          if [ -n "$ip" ] && [ "$ip" != "192.168.1.50" ]; then
            setup=0
            touch "$MP_ROOT/.setup_done"
          fi
          ;;
      esac
    fi
    user=admin
    printf '{"ok":true,"authenticated":%s,"setup_required":%s,"user":"%s"}' "$authed" "$setup" "$user"
    ;;
  login)
    if [ "${REQUEST_METHOD:-GET}" != POST ]; then
      printf 'Status: 405 Method Not Allowed\r\nContent-Type: application/json\r\n\r\n{"ok":false,"error":"POST required"}'
      exit 0
    fi
    user=$(url_decode "$(query_get user)")
    pass=$(url_decode "$(query_get pass)")
    [ -z "$user" ] && user=admin
    expected=$DEFAULT_PASS
    [ -f "$pass_file" ] && expected=$(tr -d '\r\n' < "$pass_file")
    got=$(hash_pass "$pass")
    ok=0
    if [ -f "$pass_file" ]; then
      [ "$got" = "$expected" ] && ok=1
    else
      [ "$pass" = "$DEFAULT_PASS" ] && ok=1
    fi
    [ "$user" = admin ] || ok=0
    if [ "$ok" != 1 ]; then
      printf 'Status: 401 Unauthorized\r\nContent-Type: application/json\r\nCache-Control: no-store\r\n\r\n{"ok":false,"error":"invalid credentials"}'
      exit 0
    fi
    sid=$(hexdump -v -e '/1 "%02x"' -n 16 /dev/urandom)
    echo "admin $(date +%s)" > "/tmp/mpower-sess/$sid"
    printf 'Status: 200 OK\r\nSet-Cookie: MPOWERSESS=%s; Path=/; HttpOnly\r\nContent-Type: application/json\r\nCache-Control: no-store\r\n\r\n{"ok":true,"user":"admin"}' "$sid"
    ;;
  logout)
    sid=$(cookie_get MPOWERSESS)
    [ -n "$sid" ] && rm -f "/tmp/mpower-sess/$sid"
    printf 'Status: 200 OK\r\nSet-Cookie: MPOWERSESS=; Path=/; Max-Age=0\r\nContent-Type: application/json\r\nCache-Control: no-store\r\n\r\n{"ok":true}'
    ;;
  password)
    require_token || exit 0
    old=$(url_decode "$(query_get old)")
    new=$(url_decode "$(query_get new)")
    [ ${#new} -ge 4 ] || { json_header; printf '{"ok":false,"error":"password too short"}'; exit 0; }
    if [ -f "$pass_file" ]; then
      [ "$(hash_pass "$old")" = "$(tr -d '\r\n' < "$pass_file")" ] || { json_header; printf '{"ok":false,"error":"old password wrong"}'; exit 0; }
    else
      [ "$old" = "$DEFAULT_PASS" ] || { json_header; printf '{"ok":false,"error":"old password wrong"}'; exit 0; }
    fi
    hash_pass "$new" > "$pass_file"
    cfgmtd -w -p /etc >/dev/null 2>&1
    json_header
    printf '{"ok":true}'
    ;;
  *)
    json_header
    printf '{"ok":false,"error":"unknown action"}'
    ;;
esac
