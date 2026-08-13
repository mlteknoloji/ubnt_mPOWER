#!/bin/sh
. "$(dirname "$0")/common.sh"
. "$(dirname "$0")/auth.sh"
CFG=$MP_ROOT/ping.conf
STATE=/tmp/mpower-pingwatch.state
action=$(query_get action)

cfg_get() { sed -n "s/^$1=//p" "$CFG" 2>/dev/null | head -1; }

migrate_cfg() {
  [ -f "$CFG" ] || {
    {
      for p in 1 2 3; do
        printf 'enabled%s=0\nhost%s=\ninterval%s=30\nfail_count%s=3\nfail_action%s=off\nrestore_sec%s=10\ncooldown%s=60\n' \
          "$p" "$p" "$p" "$p" "$p" "$p" "$p"
      done
    } > "$CFG"
    return 0
  }
  grep -q '^enabled1=' "$CFG" 2>/dev/null && return 0
  grep -q '^enabled=' "$CFG" 2>/dev/null || return 0
  en=$(cfg_get enabled); h=$(cfg_get host); iv=$(cfg_get interval); fc=$(cfg_get fail_count)
  po=$(cfg_get port); fa=$(cfg_get fail_action); rs=$(cfg_get restore_sec); cd=$(cfg_get cooldown)
  case "$po" in 1|2|3) ;; *) po=1;; esac
  {
    for p in 1 2 3; do
      if [ "$p" = "$po" ]; then
        printf 'enabled%s=%s\nhost%s=%s\ninterval%s=%s\nfail_count%s=%s\nfail_action%s=%s\nrestore_sec%s=%s\ncooldown%s=%s\n' \
          "$p" "${en:-0}" "$p" "$h" "$p" "${iv:-30}" "$p" "${fc:-3}" "$p" "${fa:-off}" "$p" "${rs:-10}" "$p" "${cd:-60}"
      else
        printf 'enabled%s=0\nhost%s=\ninterval%s=30\nfail_count%s=3\nfail_action%s=off\nrestore_sec%s=10\ncooldown%s=60\n' \
          "$p" "$p" "$p" "$p" "$p" "$p" "$p"
      fi
    done
  } > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
}

sanitize_host() { printf '%s' "$1" | tr -cd 'A-Za-z0-9._:-'; }

norm_rule() {
  # in: enabled host interval fail_count fail_action restore_sec cooldown
  case "$enabled" in 1) ;; *) enabled=0;; esac
  case "$interval" in ''|*[!0-9]*) interval=30;; esac
  [ "$interval" -lt 5 ] 2>/dev/null && interval=5
  case "$fail_count" in ''|*[!0-9]*) fail_count=3;; esac
  case "$fail_action" in on|off|toggle) ;; *) fail_action=off;; esac
  case "$restore_sec" in ''|*[!0-9]*) restore_sec=10;; esac
  case "$cooldown" in ''|*[!0-9]*) cooldown=60;; esac
  host=$(sanitize_host "$host")
}

json_escape() { printf '%s' "$1" | sed 's/"/\\"/g'; }

case "$action" in
  ''|get|status)
    migrate_cfg
    json_header
    running=0
    ps w 2>/dev/null | grep 'mpower/bin/ping-watch.sh' | grep -vq grep && running=1
    printf '{"ok":true,"running":%s,"rules":[' "$running"
    sep=
    for p in 1 2 3; do
      enabled=$(cfg_get "enabled$p"); host=$(cfg_get "host$p"); interval=$(cfg_get "interval$p")
      fail_count=$(cfg_get "fail_count$p"); fail_action=$(cfg_get "fail_action$p")
      restore_sec=$(cfg_get "restore_sec$p"); cooldown=$(cfg_get "cooldown$p")
      norm_rule
      fails=0; last_ok=0; last_fail=0; last_action=; busy=0
      [ -f "$STATE" ] && {
        fails=$(sed -n "s/^fails${p}=//p" "$STATE"|head -1)
        last_ok=$(sed -n "s/^last_ok${p}=//p" "$STATE"|head -1)
        last_fail=$(sed -n "s/^last_fail${p}=//p" "$STATE"|head -1)
        last_action=$(sed -n "s/^last_action${p}=//p" "$STATE"|head -1)
        busy=$(sed -n "s/^busy${p}=//p" "$STATE"|head -1)
      }
      printf '%s{"port":%s,"enabled":%s,"host":"%s","interval":%s,"fail_count":%s,"fail_action":"%s","restore_sec":%s,"cooldown":%s,"fails":%s,"last_ok":%s,"last_fail":%s,"last_action":"%s","busy":%s}' \
        "$sep" "$p" "$enabled" "$(json_escape "$host")" "$interval" "$fail_count" "$fail_action" "$restore_sec" "$cooldown" \
        "${fails:-0}" "${last_ok:-0}" "${last_fail:-0}" "$(json_escape "$last_action")" "${busy:-0}"
      sep=,
    done
    printf ']}'
    ;;
  set)
    require_token || exit 0
    migrate_cfg
    {
      for p in 1 2 3; do
        enabled=$(query_get "enabled$p")
        host=$(url_decode "$(query_get "host$p")")
        interval=$(query_get "interval$p")
        fail_count=$(query_get "fail_count$p")
        fail_action=$(query_get "fail_action$p")
        restore_sec=$(query_get "restore_sec$p")
        cooldown=$(query_get "cooldown$p")
        # allow saving a single rule: if enabled$p empty, keep existing
        if [ -z "$(query_get "enabled$p")" ] && [ -z "$(query_get "host$p")" ]; then
          enabled=$(cfg_get "enabled$p"); host=$(cfg_get "host$p"); interval=$(cfg_get "interval$p")
          fail_count=$(cfg_get "fail_count$p"); fail_action=$(cfg_get "fail_action$p")
          restore_sec=$(cfg_get "restore_sec$p"); cooldown=$(cfg_get "cooldown$p")
        fi
        norm_rule
        printf 'enabled%s=%s\n' "$p" "$enabled"
        printf 'host%s=%s\n' "$p" "$host"
        printf 'interval%s=%s\n' "$p" "$interval"
        printf 'fail_count%s=%s\n' "$p" "$fail_count"
        printf 'fail_action%s=%s\n' "$p" "$fail_action"
        printf 'restore_sec%s=%s\n' "$p" "$restore_sec"
        printf 'cooldown%s=%s\n' "$p" "$cooldown"
      done
    } > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
    # Reply immediately; flash and worker restart must not break the CGI socket.
    json_header; printf '{"ok":true}'
    (
      # Apply the service state first. cfgmtd can be slow on this device and
      # must not leave ping-watch running after the final rule is disabled.
      ps w 2>/dev/null | grep 'mpower/bin/ping-watch.sh' | grep -v grep | while read pid rest; do
        case "$pid" in ''|*[!0-9]*) ;; *) kill "$pid" 2>/dev/null ;; esac
      done
      i=0
      while [ -d /tmp/mpower-pingwatch.lock ] && [ "$i" -lt 10 ]; do i=$((i+1)); sleep 1; done
      rmdir /tmp/mpower-pingwatch.lock 2>/dev/null || true
      rm -f "$STATE" 2>/dev/null
      if grep -q '^enabled[123]=1$' "$CFG" 2>/dev/null; then
        /bin/sh $MP_ROOT/bin/ping-watch.sh >/tmp/mpower-pingwatch.log 2>&1 &
      fi
      cfgmtd -w -p /etc > /tmp/mpower-ping-cfgmtd.log 2>&1
    ) >/dev/null 2>&1 &
    ;;
  test)
    require_token || exit 0
    host=$(url_decode "$(query_get host)")
    host=$(sanitize_host "$host")
    p=$(query_get port)
    if [ -z "$host" ] && [ -n "$p" ]; then
      host=$(cfg_get "host$p")
    fi
    json_header
    if [ -z "$host" ]; then printf '{"ok":false,"error":"no host"}'; exit 0; fi
    if ping -c 1 -w 3 "$host" >/dev/null 2>&1 || ping -c 1 "$host" >/dev/null 2>&1; then
      printf '{"ok":true,"reachable":1,"host":"%s"}' "$(json_escape "$host")"
    else
      printf '{"ok":true,"reachable":0,"host":"%s"}' "$(json_escape "$host")"
    fi
    ;;
  *)
    json_header
    printf '{"ok":false,"error":"unknown"}'
    ;;
esac
