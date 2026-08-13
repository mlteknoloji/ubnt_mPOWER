#!/bin/sh
# MQTT 3.1.1: JSON state publish + command subscribe (BusyBox nc + fifo).
MP_ROOT=/etc/persistent/mpower
cfg=$MP_ROOT/mqtt.conf
PIDFILE=/tmp/mpower-mqtt.pid
STATUS=/tmp/mpower-mqtt-status.json
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
[ -n "$host" ] || exit 1
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
set_status() {
  state=$1; code=${2:-0}; message=$3
  printf '{"state":"%s","code":%s,"message":"%s"}\n' "$state" "$code" "$message" > "$STATUS.tmp"
  mv "$STATUS.tmp" "$STATUS"
}
cleanup() {
  [ -n "$WRITER" ] && kill "$WRITER" 2>/dev/null
  exec 4>&- 4<&- 2>/dev/null
  rm -f "$FIFO" "$READY" "$PIDFILE"
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
mqtt_byte() {
  mqtt_oct=$(printf '%03o' "$((($1) & 255))")
  printf "\\$mqtt_oct"
}
mqtt_u16() { mqtt_byte "$((($1) / 256))"; mqtt_byte "$((($1) % 256))"; }
mqtt_str() { mqtt_u16 "${#1}"; printf '%s' "$1"; }
mqtt_remenc() {
  mqtt_rem=$1
  while true; do
    mqtt_digit=$((mqtt_rem % 128)); mqtt_rem=$((mqtt_rem / 128))
    [ "$mqtt_rem" -gt 0 ] && mqtt_digit=$((mqtt_digit + 128))
    mqtt_byte "$mqtt_digit"
    [ "$mqtt_rem" -eq 0 ] && break
  done
}

mqtt_pack_pub() {
  mqtt_topic=$1; mqtt_payload=$2; mqtt_retain=$3
  mqtt_header=48; [ "$mqtt_retain" = 1 ] && mqtt_header=49
  mqtt_byte "$mqtt_header"
  mqtt_remenc "$((2 + ${#mqtt_topic} + ${#mqtt_payload}))"
  mqtt_str "$mqtt_topic"
  printf '%s' "$mqtt_payload"
}

mqtt_pack_ping() { mqtt_byte 192; mqtt_byte 0; }

build_state_json() {
  fw=$(cat /etc/version 2>/dev/null | tr -cd 'A-Za-z0-9._-')
  ov=$(cat $MP_ROOT/.installed 2>/dev/null | tr -cd 'A-Za-z0-9._-')
  up=$(cut -d. -f1 /proc/uptime 2>/dev/null)
  ssid=$(iwconfig ath0 2>/dev/null | sed -n 's/.*ESSID:"\([^"]*\)".*/\1/p' | tr -cd 'A-Za-z0-9 ._:-')
  ip=$(ifconfig ath0 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p')
  now=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
  printf '{"mac":"%s","hostname":"%s","name":"%s","firmware":"%s","overlay":"%s","ip":"%s","ssid":"%s","uptime":%s,"now":"%s","custom":"%s","outlets":[' \
    "$id" "$(json_escape "$hostname")" "$(json_escape "$name")" "$fw" "$ov" "$ip" "$ssid" "${up:-0}" "$now" "$(json_escape "$custom")"
  sep=
  for p in 1 2 3; do
    relay=$(cat /proc/power/relay$p 2>/dev/null || echo 0)
    watt=$(cat /proc/power/active_pwr$p 2>/dev/null || echo 0)
    wh=$(cat /proc/power/energy_sum$p 2>/dev/null || echo 0)
    volt=$(cat /proc/power/v_rms$p 2>/dev/null || echo 0)
    amp=$(cat /proc/power/i_rms$p 2>/dev/null || echo 0)
    pf=$(cat /proc/power/pf$p 2>/dev/null || echo 0)
    printf '%s{"port":%s,"relay":%s,"watt":%s,"wh":%s,"volt":%s,"amp":%s,"pf":%s}' \
      "$sep" "$p" "$relay" "$watt" "$wh" "$volt" "$amp" "$pf"
    sep=,
  done
  printf ']}'
}

publish_all() {
  js=$(build_state_json)
  up=$(cut -d. -f1 /proc/uptime 2>/dev/null)
  case "$up" in ''|*[!0-9]*) up=0;; esac
  mqtt_pack_pub "${prefix}/${id}/state" "$js" 1 >&3
  mqtt_pack_pub "${prefix}/${id}/uptime" "$up" 1 >&3
  mqtt_pack_pub "${prefix}/${id}/custom" "$custom" 1 >&3
  for p in 1 2 3; do
    relay=$(cat /proc/power/relay$p 2>/dev/null || echo 0)
    watt=$(cat /proc/power/active_pwr$p 2>/dev/null || echo 0)
    volt=$(cat /proc/power/v_rms$p 2>/dev/null || echo 0)
    amp=$(cat /proc/power/i_rms$p 2>/dev/null || echo 0)
    wh=$(cat /proc/power/energy_sum$p 2>/dev/null || echo 0)
    pf=$(cat /proc/power/pf$p 2>/dev/null || echo 0)
    [ "$relay" = 1 ] && st=ON || st=OFF
    mqtt_pack_pub "${prefix}/${id}/relay/${p}" "$st" 1 >&3
    mqtt_pack_pub "${prefix}/${id}/outlet/${p}/watt" "$watt" 0 >&3
    mqtt_pack_pub "${prefix}/${id}/outlet/${p}/volt" "$volt" 0 >&3
    mqtt_pack_pub "${prefix}/${id}/outlet/${p}/amp" "$amp" 0 >&3
    mqtt_pack_pub "${prefix}/${id}/outlet/${p}/json" \
      "$(printf '{"port":%s,"relay":%s,"watt":%s,"wh":%s,"volt":%s,"amp":%s,"pf":%s}' "$p" "$relay" "$watt" "$wh" "$volt" "$amp" "$pf")" 0 >&3
  done
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
  echo "$(date 2>/dev/null) RX $topic $payload" >> /tmp/mpower-mqtt.log
  case "$topic" in
    */cmd) handle_cmd_json "$payload" ;;
    */relay/*/set|*/relay/all/set)
      port=$(printf '%s' "$topic" | sed -n 's|.*/relay/\([123all]*\)/set|\1|p')
      case "$payload" in
        ON|on|1) apply_relay "$port" 1; echo 1 > "$NEED" ;;
        OFF|off|0) apply_relay "$port" 0; echo 1 > "$NEED" ;;
        *) echo "$payload" | grep -q '"action"' && handle_cmd_json "$payload" ;;
      esac ;;
  esac
}

CMD="${prefix}/${id}/cmd"
T1="${prefix}/${id}/relay/1/set"
T2="${prefix}/${id}/relay/2/set"
T3="${prefix}/${id}/relay/3/set"
TA="${prefix}/${id}/relay/all/set"

# Writer keeps fifo open on FD 3
(
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

  # MQTT 3.1.1: wait for successful CONNACK before any other packet.
  # The broker performs password verification asynchronously and disconnects
  # clients that send SUBSCRIBE/PUBLISH before authentication completes.
  tries=0
  while [ ! -f "$READY" ] && [ "$tries" -lt 15 ]; do
    sleep 1
    tries=$((tries + 1))
  done
  [ -f "$READY" ] || exit 1

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

  last=0
  while true; do
    [ -f "$cfg" ] || exit 0
    enabled=$(sed -n 's/^enabled=//p' "$cfg" | head -1)
    [ "$enabled" = 1 ] || exit 0
    now=$(date +%s 2>/dev/null || echo 0)
    force=0
    [ -f "$NEED" ] && force=1 && rm -f "$NEED"
    if [ "$force" = 1 ] || [ $((now-last)) -ge "$interval" ]; then
      publish_all
      last=$now
    fi
    mqtt_pack_ping >&3
    sleep 2
  done
) &
WRITER=$!

nc "$host" "$port" < "$FIFO" | while true; do
  b=$(dd bs=1 count=1 2>/dev/null | hexdump -v -e '/1 "%02x"')
  [ -n "$b" ] || break
  mul=1; rl=0
  while true; do
    dig=$(dd bs=1 count=1 2>/dev/null | hexdump -v -e '/1 "%u"')
    [ -n "$dig" ] || break 2
    rl=$((rl + (dig % 128) * mul))
    mul=$((mul * 128))
    [ "$dig" -lt 128 ] && break
  done
  [ "$rl" -gt 0 ] || continue
  [ "$rl" -gt 20000 ] && { dd bs=1 count="$rl" of=/dev/null 2>/dev/null; continue; }
  dd bs=1 count="$rl" of=/tmp/mpower-mqtt.frame 2>/dev/null
  case "$b" in
    20)
      # CONNACK: byte 2 is 0 on success, 1..5 explains broker rejection.
      rc=$(hexdump -v -e '/1 "%u"' -n 1 -s 1 /tmp/mpower-mqtt.frame)
      case "$rc" in
        0) set_status connected 0 connected; echo 1 > "$READY" ;;
        1) set_status failed 1 unacceptable_protocol ;;
        2) set_status failed 2 identifier_rejected ;;
        3) set_status failed 3 server_unavailable ;;
        4) set_status failed 4 bad_credentials ;;
        5) set_status failed 5 not_authorized ;;
        *) set_status failed 255 invalid_connack ;;
      esac
      ;;
    30|31)
      hi=$(hexdump -v -e '/1 "%u"' -n 1 -s 0 /tmp/mpower-mqtt.frame)
      lo=$(hexdump -v -e '/1 "%u"' -n 1 -s 1 /tmp/mpower-mqtt.frame)
      tlen=$((hi*256+lo))
      topic=$(dd if=/tmp/mpower-mqtt.frame bs=1 skip=2 count="$tlen" 2>/dev/null)
      payload=$(dd if=/tmp/mpower-mqtt.frame bs=1 skip=$((2+tlen)) 2>/dev/null)
      handle_topic_payload "$topic" "$payload"
      ;;
  esac
done

grep -q '"state":"failed"' "$STATUS" 2>/dev/null || set_status disconnected 0 connection_closed
exit 0
