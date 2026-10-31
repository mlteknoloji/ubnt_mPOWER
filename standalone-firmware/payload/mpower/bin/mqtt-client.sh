#!/bin/sh
# MQTT 3.1.1: JSON state publish + command subscribe (BusyBox nc + fifo).
MP_ROOT=/etc/persistent/mpower
cfg=$MP_ROOT/mqtt.conf
PIDFILE=/tmp/mpower-mqtt.pid
STATUS=/tmp/mpower-mqtt-status.json
LOG=/tmp/mpower-mqtt.log
# The MQTT page writes its uptime here while "live log" is on; then TX/RX
# traffic is logged too (normally only connection events are).
LIVE=/tmp/mpower-mqtt.live
NCPID=/tmp/mpower-mqtt.ncpid
# Local time for log stamps: the clock and crond run in UTC; location.conf
# tz is the whole-hour offset. POSIX TZ signs are reversed (GMT-3 = UTC+3).
ltz=3; [ -r "$MP_ROOT/location.conf" ] && while IFS= read l; do
  case "$l" in tz=*) ltz=${l#tz=} ;; esac
done < "$MP_ROOT/location.conf"
case "$ltz" in ''|*[!0-9+-]*) ltz=3 ;; esac
case "$ltz" in -*) LTZ="GMT+${ltz#-}" ;; *) LTZ="GMT-${ltz#+}" ;; esac
mlog() { echo "$(TZ=$LTZ date '+%Y-%m-%d %H:%M:%S' 2>/dev/null) $*" >> "$LOG"; }
# Keep the RAM log small: past 32 KB keep the last 200 lines (same inode,
# so nc's stderr redirect keeps writing into it).
trim_log() {
  sz=$(wc -c < "$LOG" 2>/dev/null)
  [ "${sz:-0}" -gt 32768 ] 2>/dev/null || return 0
  tail -n 200 "$LOG" > "$LOG.t" && cat "$LOG.t" > "$LOG"
  rm -f "$LOG.t"
}
[ -f "$cfg" ] || exit 0
enabled=$(sed -n 's/^enabled=//p' "$cfg" | head -1)
[ "$enabled" = 1 ] || exit 0

host=$(sed -n 's/^host=//p' "$cfg" | head -1)
port=$(sed -n 's/^port=//p' "$cfg" | head -1)
user=$(sed -n 's/^user=//p' "$cfg" | head -1)
pass=$(sed -n 's/^pass=//p' "$cfg" | head -1)
prefix=$(sed -n 's/^prefix=//p' "$cfg" | head -1)
interval=$(sed -n 's/^interval=//p' "$cfg" | head -1)
ha=$(sed -n 's/^ha_discovery=//p' "$cfg" | head -1)
custom=$(sed -n 's/^custom=//p' "$cfg" | head -1)
[ -n "$host" ] || { mlog "ERR broker address is empty"; exit 1; }
[ -n "$port" ] || port=1883
[ -n "$prefix" ] || prefix=mpower/mltek
# Migrate the short-lived default used by older overlay builds.
[ "$prefix" = netrelay/mltek ] && prefix=mpower/mltek
[ -n "$interval" ] || interval=15
[ -n "$ha" ] || ha=0

# Keep exactly one client instance. The CGI/service can reliably stop this PID.
if [ -f "$PIDFILE" ]; then
  oldpid=$(cat "$PIDFILE" 2>/dev/null)
  case "$oldpid" in ''|*[!0-9]*) ;; *) kill -0 "$oldpid" 2>/dev/null && exit 0 ;; esac
fi
echo $$ > "$PIDFILE"
rm -f "$NCPID" /tmp/mpower-mqtt.stopping
set_status() {
  state=$1; code=${2:-0}; message=$3
  printf '{"state":"%s","code":%s,"message":"%s"}\n' "$state" "$code" "$message" > "$STATUS.tmp"
  mv "$STATUS.tmp" "$STATUS"
}
# A newer client (started after a settings save) owns the shared files once
# it rewrote the PID file; an old instance must not touch them any more.
own() { op=; [ -r "$PIDFILE" ] && read op < "$PIDFILE"; [ "$op" = "$$" ]; }
# SIGKILL: BusyBox nc prints "punt!" on SIGTERM, which would land in the log.
kill_nc() { np=; [ -r "$NCPID" ] && read np < "$NCPID"; [ -n "$np" ] && kill -9 "$np" 2>/dev/null; }
cleanup() {
  [ -n "$WRITER" ] && kill "$WRITER" 2>/dev/null
  own && kill_nc
  exec 4>&- 4<&- 2>/dev/null
  own && rm -f "$FIFO" "$READY" "$PIDFILE" "$NCPID"
}
trap cleanup EXIT INT TERM
set_status connecting 0 connecting

mac=$(ifconfig ath0 2>/dev/null | sed -n 's/.*HWaddr \([0-9A-Fa-f:]*\).*/\1/p' | tr -d ':' | tr 'A-F' 'a-f')
[ -n "$mac" ] || mac=$(ifconfig br0 2>/dev/null | sed -n 's/.*HWaddr \([0-9A-Fa-f:]*\).*/\1/p' | tr -d ':' | tr 'A-F' 'a-f')
[ -n "$mac" ] || mac=unknown
id=$mac
cid=$(printf 'mp%s' "$id" | cut -c1-23)
hostname=$(uname -n 2>/dev/null)
name=$(sed -n 's/^name=//p' $MP_ROOT/device.conf 2>/dev/null | head -1)
[ -n "$name" ] || name=$hostname
trim_log
mlog "INFO connecting to $host:$port (user ${user:-none}, client id $cid)"

FIFO=/tmp/mpower-mqtt.fifo
NEED=/tmp/mpower-mqtt.needpub
READY=/tmp/mpower-mqtt.ready
rm -f "$FIFO" "$NEED" "$READY"
mkfifo "$FIFO"
# Open both ends in the parent so BusyBox does not deadlock while the writer
# and nc reader are opening the FIFO in separate background/pipeline jobs.
exec 4<>"$FIFO"
echo 1 > "$NEED"

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g;s/"/\\"/g'; }

# BusyBox awk on this device cannot emit NUL with printf("%c", 0), while MQTT
# uses NUL in every two-byte string length. Emit bytes through shell octal
# escapes so 00 bytes are preserved on the wire.
# Helpers below avoid $(...) subshells: on this MIPS CPU every fork costs
# milliseconds, and the old per-byte subshell added ~100 forks per publish.
# mqtt_oct N -> o='\NNN' (printf escape for byte N, computed arithmetically)
mqtt_oct() { o="\\$(( (($1) & 255) / 64 ))$(( (($1) & 255) / 8 % 8 ))$(( (($1) & 255) % 8 ))"; }
mqtt_byte() { mqtt_oct "$1"; printf "$o"; }
mqtt_u16() { mqtt_byte "$((($1) / 256))"; mqtt_byte "$((($1) % 256))"; }
mqtt_str() { mqtt_u16 "${#1}"; printf '%s' "$1"; }
# mqtt_remfmt N -> re = escapes for the MQTT variable-length "remaining length"
mqtt_remfmt() {
  mqtt_rem=$1; re=
  while true; do
    mqtt_digit=$((mqtt_rem % 128)); mqtt_rem=$((mqtt_rem / 128))
    [ "$mqtt_rem" -gt 0 ] && mqtt_digit=$((mqtt_digit + 128))
    mqtt_oct "$mqtt_digit"; re="$re$o"
    [ "$mqtt_rem" -eq 0 ] && break
  done
}
mqtt_remenc() { mqtt_remfmt "$1"; printf "$re"; }

# One printf per PUBLISH packet: header bytes as escapes, topic/payload as %s.
mqtt_pack_pub() {
  mqtt_topic=$1; mqtt_payload=$2
  mqtt_header=48; [ "$3" = 1 ] && mqtt_header=49
  mqtt_oct "$mqtt_header"; mqtt_fmt=$o
  mqtt_remfmt "$((2 + ${#mqtt_topic} + ${#mqtt_payload}))"; mqtt_fmt="$mqtt_fmt$re"
  mqtt_oct "$((${#mqtt_topic} / 256))"; mqtt_fmt="$mqtt_fmt$o"
  mqtt_oct "$((${#mqtt_topic} % 256))"; mqtt_fmt="$mqtt_fmt$o"
  printf "$mqtt_fmt%s%s" "$mqtt_topic" "$mqtt_payload"
}

mqtt_pack_ping() { printf '\300\000'; }

# Constant parts of the state JSON are computed once per connection.
fw=$(tr -cd 'A-Za-z0-9._-' 2>/dev/null < /etc/version)
ov=$(tr -cd 'A-Za-z0-9._-' 2>/dev/null < $MP_ROOT/.installed)
js_fixed=$(printf '"mac":"%s","hostname":"%s","name":"%s","firmware":"%s","overlay":"%s"' \
  "$id" "$(json_escape "$hostname")" "$(json_escape "$name")" "$fw" "$ov")
js_custom=$(json_escape "$custom")

# pv FILE -> v (read builtin, no cat fork); 0 when missing/empty
pv() { v=; [ -r "$1" ] && read v < "$1"; [ -n "$v" ] || v=0; }
uptime_s() { up=0; read up rest < /proc/uptime; up=${up%%.*}; case "$up" in ''|*[!0-9]*) up=0;; esac; }

# Relay states last sent to the broker. The writer loop compares them with
# /proc every ~0.5 s (3 read builtins, no fork) and publishes a change at
# once, whatever switched the relay (panel, MQTT, schedule, ping, button).
rs1=x; rs2=x; rs3=x
relays_now() { pv /proc/power/relay1; r1=$v; pv /proc/power/relay2; r2=$v; pv /proc/power/relay3; r3=$v; }
publish_relays() {
  relays_now
  for p in 1 2 3; do
    eval "r=\$r$p"
    [ "$r" = 1 ] && st=ON || st=OFF
    mqtt_pack_pub "${prefix}/${id}/relay/${p}" "$st" 1 >&3
  done
  rs1=$r1; rs2=$r2; rs3=$r3
  is_live && mlog "TX relay states $r1$r2$r3"
}
is_live() {
  lv=; [ -r "$LIVE" ] && read lv < "$LIVE"
  case "$lv" in ''|*[!0-9]*) return 1 ;; esac
  uptime_s; [ $((up - lv)) -lt 15 ]
}
net_t=-1000
publish_all() {
  uptime_s
  # iwconfig/ifconfig cost 5 forks; IP and SSID rarely change.
  if [ $((up - net_t)) -ge 60 ]; then
    net_t=$up
    ssid=$(iwconfig ath0 2>/dev/null | sed -n 's/.*ESSID:"\([^"]*\)".*/\1/p' | tr -cd 'A-Za-z0-9 ._:-')
    ip=$(ifconfig ath0 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p')
  fi
  now=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
  outs=; sep=
  # /proc/power is read once per publish (was twice, via 36 cat processes).
  for p in 1 2 3; do
    pv /proc/power/relay$p; relay=$v
    pv /proc/power/active_pwr$p; watt=$v
    pv /proc/power/energy_sum$p; wh=$v
    pv /proc/power/v_rms$p; volt=$v
    pv /proc/power/i_rms$p; amp=$v
    pv /proc/power/pf$p; pf=$v
    oj="{\"port\":$p,\"relay\":$relay,\"watt\":$watt,\"wh\":$wh,\"volt\":$volt,\"amp\":$amp,\"pf\":$pf}"
    outs="$outs$sep$oj"; sep=,
    [ "$relay" = 1 ] && st=ON || st=OFF
    eval "rs$p=\$relay"
    mqtt_pack_pub "${prefix}/${id}/relay/${p}" "$st" 1 >&3
    mqtt_pack_pub "${prefix}/${id}/outlet/${p}/watt" "$watt" 0 >&3
    mqtt_pack_pub "${prefix}/${id}/outlet/${p}/volt" "$volt" 0 >&3
    mqtt_pack_pub "${prefix}/${id}/outlet/${p}/amp" "$amp" 0 >&3
    mqtt_pack_pub "${prefix}/${id}/outlet/${p}/json" "$oj" 0 >&3
  done
  js="{$js_fixed,\"ip\":\"$ip\",\"ssid\":\"$ssid\",\"uptime\":$up,\"now\":\"$now\",\"custom\":\"$js_custom\",\"outlets\":[$outs]}"
  mqtt_pack_pub "${prefix}/${id}/state" "$js" 1 >&3
  mqtt_pack_pub "${prefix}/${id}/uptime" "$up" 1 >&3
  mqtt_pack_pub "${prefix}/${id}/custom" "$custom" 1 >&3
  is_live && mlog "TX ${prefix}/${id}/state $js"
}

apply_relay() {
  port=$1; value=$2
  if [ "$port" = all ]; then
    for p in 1 2 3; do
      printf '%s' "$value" > /proc/power/relay$p
    done
  else
    printf '%s' "$value" > /proc/power/relay$port
  fi
}

pulse_relay() {
  port=$1; delay=$2; to=$3
  [ -n "$delay" ] || delay=10
  ports=$port; [ "$port" = all ] && ports="1 2 3"
  for p in $ports; do
    prev=$(cat /proc/power/relay$p 2>/dev/null || echo 0)
    if [ "$to" = 0 ] || [ "$to" = 1 ]; then target=$to
    else [ "$prev" = 1 ] && target=0 || target=1; fi
    printf '%s' "$target" > /proc/power/relay$p
    ( sleep "$delay"; printf '%s' "$prev" > /proc/power/relay$p; echo 1 > "$NEED" ) &
  done
}

handle_cmd_json() {
  j=$1
  action=$(printf '%s' "$j" | sed -n 's/.*"action"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  port=$(printf '%s' "$j" | sed -n 's/.*"port"[[:space:]]*:[[:space:]]*"\?\([123all]*\)"\?.*/\1/p')
  [ -z "$port" ] && port=$(printf '%s' "$j" | sed -n 's/.*"port"[[:space:]]*:[[:space:]]*\([123]\).*/\1/p')
  delay=$(printf '%s' "$j" | sed -n 's/.*"delay"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p')
  to=$(printf '%s' "$j" | sed -n 's/.*"to"[[:space:]]*:[[:space:]]*\([01]\).*/\1/p')
  url=$(printf '%s' "$j" | sed -n 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  [ -z "$port" ] && port=1
  [ -z "$delay" ] && delay=10
  case "$action" in
    on|ON) apply_relay "$port" 1 ;;
    off|OFF) apply_relay "$port" 0 ;;
    cycle)
      ports=$port; [ "$port" = all ] && ports="1 2 3"
      for p in $ports; do
        prev=$(cat /proc/power/relay$p 2>/dev/null || echo 1)
        printf 0 > /proc/power/relay$p
        ( sleep "$delay"; printf '%s' "$prev" > /proc/power/relay$p; echo 1 > "$NEED" ) &
      done ;;
    pulse) pulse_relay "$port" "$delay" "$to" ;;
    update|firmware)
      [ -n "$url" ] || return 0
      (
        QUERY_STRING="action=url&url=$url&token=$(tr -d '\r\n' < $MP_ROOT/api.token)"
        export QUERY_STRING REQUEST_METHOD=POST
        /bin/sh $MP_ROOT/www/cgi-bin/update.sh
      ) >/tmp/mpower-mqtt-fw.log 2>&1 &
      ;;
  esac
  echo 1 > "$NEED"
}

handle_topic_payload() {
  topic=$1; payload=$2
  # Act first, log after: the relay switches before the date fork runs.
  case "$topic" in
    */cmd) handle_cmd_json "$payload" ;;
    */relay/*/set)
      port=${topic%/set}; port=${port##*/}
      case "$port" in 1|2|3|all) ;; *) port= ;; esac
      case "$payload" in
        ON|on|1) [ -n "$port" ] && apply_relay "$port" 1; echo 1 > "$NEED" ;;
        OFF|off|0) [ -n "$port" ] && apply_relay "$port" 0; echo 1 > "$NEED" ;;
        *'"action"'*) handle_cmd_json "$payload" ;;
      esac ;;
  esac
  mlog "RX $topic $payload"
}

CMD="${prefix}/${id}/cmd"
T1="${prefix}/${id}/relay/1/set"
T2="${prefix}/${id}/relay/2/set"
T3="${prefix}/${id}/relay/3/set"
TA="${prefix}/${id}/relay/all/set"

# Loop tick: 0.5 s when BusyBox has usleep, else 1 s.
if type usleep >/dev/null 2>&1; then tick() { usleep 500000; }; else tick() { sleep 1; }; fi

# Writer keeps fifo open on FD 3. It ends the TCP session (kills nc) whenever
# it gives up, so the reader loop ends and the watchdog can retry.
(
  wexit() { kill_nc; exit "$1"; }
  exec 3>"$FIFO"
  # CONNECT
  set_status sending_connect 0 sending_connect
  flags=2
  vl=$((2 + 4 + 1 + 1 + 2 + 2 + ${#cid}))
  if [ -n "$user" ]; then
    flags=$((flags + 128)); vl=$((vl + 2 + ${#user}))
    [ -n "$pass" ] && flags=$((flags + 64)) && vl=$((vl + 2 + ${#pass}))
  fi
  mqtt_byte 16 >&3; mqtt_remenc "$vl" >&3; mqtt_str MQTT >&3
  mqtt_byte 4 >&3; mqtt_byte "$flags" >&3; mqtt_u16 60 >&3; mqtt_str "$cid" >&3
  if [ -n "$user" ]; then
    mqtt_str "$user" >&3
    [ -n "$pass" ] && mqtt_str "$pass" >&3
  fi
  set_status waiting_connack 0 waiting_connack
  is_live && mlog "TX CONNECT"

  # MQTT 3.1.1: wait for successful CONNACK before any other packet.
  # The broker performs password verification asynchronously and disconnects
  # clients that send SUBSCRIBE/PUBLISH before authentication completes.
  tries=0
  while [ ! -f "$READY" ] && [ "$tries" -lt 15 ]; do
    sleep 1
    tries=$((tries + 1))
  done
  if [ ! -f "$READY" ]; then
    grep -q '"state":"failed"' "$STATUS" 2>/dev/null || {
      set_status failed 6 no_connack
      mlog "ERR no CONNACK from $host:$port within 15 s (host unreachable, port closed/filtered or broker not answering)"
    }
    wexit 1
  fi

  # SUBSCRIBE packet id 1: cmd + relays
  sub_rem=2
  for sub_topic in "$CMD" "$T1" "$T2" "$T3" "$TA"; do
    sub_rem=$((sub_rem + 2 + ${#sub_topic} + 1))
  done
  mqtt_byte 130 >&3; mqtt_remenc "$sub_rem" >&3; mqtt_u16 1 >&3
  for sub_topic in "$CMD" "$T1" "$T2" "$T3" "$TA"; do
    mqtt_str "$sub_topic" >&3; mqtt_byte 0 >&3
  done

  if [ "$ha" = 1 ]; then
    for p in 1 2 3; do
      payload=$(printf '{"name":"%s R%s","uniq_id":"%s_r%s","cmd_t":"%s/%s/relay/%s/set","stat_t":"%s/%s/relay/%s","json_attr_t":"%s/%s/state","pl_on":"ON","pl_off":"OFF","dev":{"ids":["%s"],"name":"%s","mf":"Ubiquiti","mdl":"mPower"}}' \
        "$name" "$p" "$id" "$p" "$prefix" "$id" "$p" "$prefix" "$id" "$p" "$prefix" "$id" "$id" "$name")
      mqtt_pack_pub "homeassistant/switch/${prefix}_${id}_${p}/config" "$payload" 1 >&3
      payload=$(printf '{"name":"%s W%s","uniq_id":"%s_w%s","stat_t":"%s/%s/outlet/%s/watt","unit_of_meas":"W","dev_cla":"power","stat_cla":"measurement","dev":{"ids":["%s"]}}' \
        "$name" "$p" "$id" "$p" "$prefix" "$id" "$p" "$id")
      mqtt_pack_pub "homeassistant/sensor/${prefix}_${id}_${p}_w/config" "$payload" 1 >&3
      payload=$(printf '{"name":"%s V%s","uniq_id":"%s_v%s","stat_t":"%s/%s/outlet/%s/volt","unit_of_meas":"V","dev_cla":"voltage","stat_cla":"measurement","dev":{"ids":["%s"]}}' \
        "$name" "$p" "$id" "$p" "$prefix" "$id" "$p" "$id")
      mqtt_pack_pub "homeassistant/sensor/${prefix}_${id}_${p}_v/config" "$payload" 1 >&3
    done
    payload=$(printf '{"name":"%s Uptime","uniq_id":"%s_uptime","stat_t":"%s/%s/uptime","unit_of_meas":"s","dev_cla":"duration","stat_cla":"measurement","icon":"mdi:timer-outline","dev":{"ids":["%s"],"name":"%s","mf":"Ubiquiti","mdl":"mPower"}}' \
      "$name" "$id" "$prefix" "$id" "$id" "$name")
    mqtt_pack_pub "homeassistant/sensor/${prefix}_${id}_uptime/config" "$payload" 1 >&3
  fi

  # Event loop: every tick it checks relay states (no fork) and the $NEED
  # flag, so any relay change reaches the broker within ~0.5 s. Full
  # telemetry still goes every $interval s. Config check, log trim and
  # PINGREQ run every ~30 s (keepalive is 60 s).
  last=-100000; last_ping=0; last_cfg=-100000
  while true; do
    uptime_s; t=$up
    if [ $((t - last_cfg)) -ge 30 ]; then
      last_cfg=$t
      enabled=0
      [ -f "$cfg" ] && while IFS= read line; do
        case "$line" in enabled=*) enabled=${line#enabled=}; break ;; esac
      done < "$cfg"
      if [ "$enabled" != 1 ]; then
        mlog "INFO MQTT disabled, stopping"
        : > /tmp/mpower-mqtt.stopping
        wexit 0
      fi
      trim_log
    fi
    force=0
    [ -f "$NEED" ] && force=1 && rm -f "$NEED"
    relays_now
    if [ "$r1$r2$r3" != "$rs1$rs2$rs3" ]; then
      publish_relays
      force=1
    fi
    if [ "$force" = 1 ] || [ $((t - last)) -ge "$interval" ]; then
      publish_all
      last=$t
    fi
    if [ $((t - last_ping)) -ge 30 ]; then
      mqtt_pack_ping >&3
      is_live && mlog "TX PINGREQ"
      last_ping=$t
    fi
    tick
  done
) &
WRITER=$!

# nc runs in a group so its PID can be saved: the writer and cleanup kill it
# to end a dead or stuck session instead of waiting for the TCP timeout.
{ nc "$host" "$port" < "$FIFO" & echo $! > "$NCPID"; wait; } | while true; do
  # Every MQTT packet has at least 2 header bytes: type + first length byte.
  # Read both with one dd/hexdump pair (was two of each).
  set -- $(dd bs=1 count=2 2>/dev/null | hexdump -v -e '/1 "%u "')
  [ -n "$2" ] || break
  b=$1; dig=$2
  mul=1; rl=0
  while true; do
    rl=$((rl + (dig % 128) * mul))
    mul=$((mul * 128))
    [ "$dig" -lt 128 ] && break
    dig=$(dd bs=1 count=1 2>/dev/null | hexdump -v -e '/1 "%u"')
    [ -n "$dig" ] || break 2
  done
  case "$b" in 208) is_live && mlog "RX PINGRESP" ;; esac
  [ "$rl" -gt 0 ] || continue
  [ "$rl" -gt 20000 ] && { dd bs=1 count="$rl" of=/dev/null 2>/dev/null; continue; }
  dd bs=1 count="$rl" of=/tmp/mpower-mqtt.frame 2>/dev/null
  case "$b" in
    32)
      # CONNACK: byte 2 is 0 on success, 1..5 explains broker rejection.
      rc=$(hexdump -v -e '/1 "%u"' -n 1 -s 1 /tmp/mpower-mqtt.frame)
      case "$rc" in
        0) set_status connected 0 connected; echo 1 > "$READY"
           mlog "OK connected to $host:$port" ;;
        1) set_status failed 1 unacceptable_protocol ;;
        2) set_status failed 2 identifier_rejected ;;
        3) set_status failed 3 server_unavailable ;;
        4) set_status failed 4 bad_credentials ;;
        5) set_status failed 5 not_authorized ;;
        *) set_status failed 255 invalid_connack ;;
      esac
      case "$rc" in
        0) ;;
        1) mlog "ERR broker rejected: unacceptable protocol version (code 1)" ;;
        2) mlog "ERR broker rejected: client id $cid refused (code 2)" ;;
        3) mlog "ERR broker rejected: server unavailable (code 3)" ;;
        4) mlog "ERR broker rejected: wrong username or password (code 4)" ;;
        5) mlog "ERR broker rejected: not authorized (code 5)" ;;
        *) mlog "ERR invalid CONNACK from broker (code $rc)" ;;
      esac
      # Rejected: drop the session now instead of waiting for the writer.
      [ "$rc" = 0 ] || kill_nc
      ;;
    144) mlog "OK subscribed to ${prefix}/${id}/cmd and relay/N/set" ;;
    48|49|50|51|52|53|54|55|56|57|58|59|60|61|62|63)
      set -- $(hexdump -v -e '/1 "%u "' -n 2 /tmp/mpower-mqtt.frame)
      tlen=$(($1*256+$2))
      topic=$(dd if=/tmp/mpower-mqtt.frame bs=1 skip=2 count="$tlen" 2>/dev/null)
      payload=$(dd if=/tmp/mpower-mqtt.frame bs=1 skip=$((2+tlen)) 2>/dev/null)
      handle_topic_payload "$topic" "$payload"
      ;;
  esac
done

# Only the current instance reports; an old one replaced by a settings save
# must not overwrite the new client's status.
if own; then
  if grep -q '"state":"failed"' "$STATUS" 2>/dev/null; then :
  elif [ -f /tmp/mpower-mqtt.stopping ]; then set_status stopped 0 stopped
  elif [ -f "$READY" ]; then
    set_status disconnected 0 connection_closed
    mlog "WARN connection to broker lost (closed by broker or network)"
  else
    set_status failed 7 tcp_failed
    mlog "ERR could not open TCP connection to $host:$port (refused or unreachable)"
  fi
fi
exit 0
