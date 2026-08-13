#!/bin/sh
# Ping watchdog: up to 3 independent rules (one per outlet).
ROOT=/etc/persistent/mpower
CFG=$ROOT/ping.conf
LOG=/tmp/mpower-pingwatch.log
STATE=/tmp/mpower-pingwatch.state
LOCK=/tmp/mpower-pingwatch.lock

if ! mkdir "$LOCK" 2>/dev/null; then exit 0; fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT INT TERM

log() { echo "$(date 2>/dev/null) $*" >> "$LOG"; tail -n 120 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"; }

do_ping() {
  h=$1
  [ -n "$h" ] || return 1
  if ping -c 1 -w 3 "$h" >/dev/null 2>&1; then return 0; fi
  if ping -c 1 "$h" >/dev/null 2>&1; then return 0; fi
  return 1
}

cfg_get() {
  # cfg_get KEY → value from CFG
  sed -n "s/^$1=//p" "$CFG" 2>/dev/null | head -1
}

# Migrate legacy single-rule ping.conf → per-port keys
migrate_cfg() {
  [ -f "$CFG" ] || return 0
  grep -q '^enabled1=' "$CFG" 2>/dev/null && return 0
  grep -q '^enabled=' "$CFG" 2>/dev/null || return 0
  en=$(cfg_get enabled); h=$(cfg_get host); iv=$(cfg_get interval); fc=$(cfg_get fail_count)
  po=$(cfg_get port); fa=$(cfg_get fail_action); rs=$(cfg_get restore_sec); cd=$(cfg_get cooldown)
  case "$po" in 1|2|3) ;; *) po=1;; esac
  {
    for p in 1 2 3; do
      if [ "$p" = "$po" ]; then
        printf 'enabled%s=%s\n' "$p" "${en:-0}"
        printf 'host%s=%s\n' "$p" "$h"
        printf 'interval%s=%s\n' "$p" "${iv:-30}"
        printf 'fail_count%s=%s\n' "$p" "${fc:-3}"
        printf 'fail_action%s=%s\n' "$p" "${fa:-off}"
        printf 'restore_sec%s=%s\n' "$p" "${rs:-10}"
        printf 'cooldown%s=%s\n' "$p" "${cd:-60}"
      else
        printf 'enabled%s=0\n' "$p"
        printf 'host%s=\n' "$p"
        printf 'interval%s=30\n' "$p"
        printf 'fail_count%s=3\n' "$p"
        printf 'fail_action%s=off\n' "$p"
        printf 'restore_sec%s=10\n' "$p"
        printf 'cooldown%s=60\n' "$p"
      fi
    done
  } > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
  log "migrated legacy ping.conf → 3 rules (active port=$po)"
}

load_rule() {
  # sets: enabled host interval fail_count fail_action restore_sec cooldown  for port $1
  p=$1
  enabled=$(cfg_get "enabled$p")
  host=$(cfg_get "host$p")
  interval=$(cfg_get "interval$p")
  fail_count=$(cfg_get "fail_count$p")
  fail_action=$(cfg_get "fail_action$p")
  restore_sec=$(cfg_get "restore_sec$p")
  cooldown=$(cfg_get "cooldown$p")
  case "$enabled" in 1) ;; *) enabled=0;; esac
  case "$interval" in ''|*[!0-9]*) interval=30;; esac
  [ "$interval" -lt 5 ] && interval=5
  [ "$interval" -gt 3600 ] && interval=3600
  case "$fail_count" in ''|*[!0-9]*) fail_count=3;; esac
  [ "$fail_count" -lt 1 ] && fail_count=1
  [ "$fail_count" -gt 20 ] && fail_count=20
  case "$fail_action" in on|off|toggle) ;; *) fail_action=off;; esac
  case "$restore_sec" in ''|*[!0-9]*) restore_sec=10;; esac
  [ "$restore_sec" -lt 1 ] && restore_sec=1
  [ "$restore_sec" -gt 600 ] && restore_sec=600
  case "$cooldown" in ''|*[!0-9]*) cooldown=60;; esac
  [ "$cooldown" -gt 3600 ] && cooldown=3600
  host=$(printf '%s' "$host" | tr -cd 'A-Za-z0-9._:-')
}

# Per-rule runtime (BusyBox: use files under /tmp)
RDIR=/tmp/mpower-pingrules
mkdir -p "$RDIR"

rget() { # rget PORT KEY
  cat "$RDIR/$1.$2" 2>/dev/null || echo 0
}
rset() { # rset PORT KEY VAL
  printf '%s' "$3" > "$RDIR/$1.$2"
}

write_state() {
  stmp="$STATE.tmp.$$"
  {
    printf 'running=1\n'
    for p in 1 2 3; do
      printf 'fails%s=%s\n' "$p" "$(rget $p fails)"
      printf 'last_ok%s=%s\n' "$p" "$(rget $p last_ok)"
      printf 'last_fail%s=%s\n' "$p" "$(rget $p last_fail)"
      printf 'last_action%s=%s\n' "$p" "$(rget $p last_action)"
      printf 'busy%s=%s\n' "$p" "$(rget $p busy)"
      printf 'host%s=%s\n' "$p" "$(cfg_get host$p)"
    done
  } > "$stmp" && mv "$stmp" "$STATE"
}

start_action() {
  p=$1
  load_rule "$p"
  prev=$(cat /proc/power/relay"$p" 2>/dev/null || echo 0)
  case "$fail_action" in
    on) target=1 ;;
    off) target=0 ;;
    toggle) [ "$prev" = 1 ] && target=0 || target=1 ;;
  esac
  now=$(date +%s 2>/dev/null || echo 0)
  rset "$p" prev "$prev"
  rset "$p" busy 1
  rset "$p" restore_until $((now + restore_sec))
  rset "$p" cool_until $((now + restore_sec + cooldown))
  rset "$p" last_action "port${p}_${fail_action}_from_${prev}"
  log "r$p FAIL host=$host → $fail_action (prev=$prev) restore=${restore_sec}s"
  printf '%s' "$target" > /proc/power/relay"$p"
  rset "$p" fails 0
}

finish_restore() {
  p=$1
  prev=$(rget "$p" prev)
  printf '%s' "$prev" > /proc/power/relay"$p"
  log "r$p restored to $prev"
  rset "$p" busy 0
  rset "$p" restore_until 0
}

process_rule() {
  p=$1
  load_rule "$p"
  now=$(date +%s 2>/dev/null || echo 0)

  # complete restore if due
  busy=$(rget "$p" busy)
  ru=$(rget "$p" restore_until)
  if [ "$busy" = 1 ] && [ "$ru" -gt 0 ] 2>/dev/null && [ "$now" -ge "$ru" ] 2>/dev/null; then
    finish_restore "$p"
  fi

  if [ "$enabled" != 1 ] || [ -z "$host" ]; then
    rset "$p" fails 0
    return 0
  fi

  busy=$(rget "$p" busy)
  if [ "$busy" = 1 ]; then
    return 0
  fi

  cu=$(rget "$p" cool_until)
  if [ "$cu" -gt 0 ] 2>/dev/null && [ "$now" -lt "$cu" ] 2>/dev/null; then
    return 0
  fi

  lp=$(rget "$p" last_ping)
  if [ "$lp" -gt 0 ] 2>/dev/null && [ $((now - lp)) -lt "$interval" ] 2>/dev/null; then
    return 0
  fi
  rset "$p" last_ping "$now"

  if do_ping "$host"; then
    rset "$p" fails 0
    rset "$p" last_ok "$now"
  else
    fails=$(rget "$p" fails)
    fails=$((fails + 1))
    rset "$p" fails "$fails"
    rset "$p" last_fail "$now"
    log "r$p ping fail $fails/$fail_count host=$host"
    if [ "$fails" -ge "$fail_count" ]; then
      start_action "$p"
    fi
  fi
}

migrate_cfg
if ! grep -q '^enabled[123]=1$' "$CFG" 2>/dev/null; then
  rm -f "$STATE" 2>/dev/null
  exit 0
fi
for p in 1 2 3; do
  [ -f "$RDIR/$p.fails" ] || rset "$p" fails 0
  [ -f "$RDIR/$p.busy" ] || rset "$p" busy 0
done

log "ping-watch start (3 rules)"
write_state

while true; do
  migrate_cfg
  for p in 1 2 3; do
    process_rule "$p"
  done
  write_state
  # This device has a slow MIPS CPU; reloading three rules every second
  # creates excessive sed/cat processes and can starve SSH/deploy.
  sleep 5
done
