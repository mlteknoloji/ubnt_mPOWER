#!/bin/sh
# mPower Standalone overlay installer (runs ON the device).
# Expects payload/ next to this script, or /tmp/mpower-pkg/payload.
set -e

PKG_ROOT=$(cd "$(dirname "$0")" && pwd)
PAYLOAD="$PKG_ROOT/payload"
[ -d "$PAYLOAD/mpower" ] || PAYLOAD=/tmp/mpower-pkg/payload
[ -d "$PAYLOAD/mpower" ] || {
  echo "payload/mpower not found" >&2
  exit 1
}

VERSION=$(cat "$PKG_ROOT/VERSION" 2>/dev/null || echo unknown)
echo "Installing mPower Standalone $VERSION ..."

# Keep existing Wi-Fi client config and schedules if present.
KEEP_WIFI=
KEEP_SCHED=
KEEP_TOKEN=
KEEP_PASS=
KEEP_MQTT=
KEEP_NET=
KEEP_LOC=
KEEP_TIME=
KEEP_SETUP=
KEEP_DEV=
KEEP_PING=
KEEP_LED=
KEEP_API=
[ -f /etc/persistent/mpower/wifi.conf ] && KEEP_WIFI=/tmp/mpower-keep-wifi.conf && cp /etc/persistent/mpower/wifi.conf "$KEEP_WIFI"
[ -f /etc/persistent/mpower/data/schedules.db ] && KEEP_SCHED=/tmp/mpower-keep-schedules.db && cp /etc/persistent/mpower/data/schedules.db "$KEEP_SCHED"
[ -f /etc/persistent/mpower/api.token ] && KEEP_TOKEN=/tmp/mpower-keep-token && cp /etc/persistent/mpower/api.token "$KEEP_TOKEN"
[ -f /etc/persistent/mpower/admin.pass ] && KEEP_PASS=/tmp/mpower-keep-pass && cp /etc/persistent/mpower/admin.pass "$KEEP_PASS"
[ -f /etc/persistent/mpower/mqtt.conf ] && KEEP_MQTT=/tmp/mpower-keep-mqtt && cp /etc/persistent/mpower/mqtt.conf "$KEEP_MQTT"
[ -f /etc/persistent/mpower/network.conf ] && KEEP_NET=/tmp/mpower-keep-net && cp /etc/persistent/mpower/network.conf "$KEEP_NET"
[ -f /etc/persistent/mpower/location.conf ] && KEEP_LOC=/tmp/mpower-keep-loc && cp /etc/persistent/mpower/location.conf "$KEEP_LOC"
[ -f /etc/persistent/mpower/time.conf ] && KEEP_TIME=/tmp/mpower-keep-time && cp /etc/persistent/mpower/time.conf "$KEEP_TIME"
[ -f /etc/persistent/mpower/device.conf ] && KEEP_DEV=/tmp/mpower-keep-dev && cp /etc/persistent/mpower/device.conf "$KEEP_DEV"
[ -f /etc/persistent/mpower/ping.conf ] && KEEP_PING=/tmp/mpower-keep-ping && cp /etc/persistent/mpower/ping.conf "$KEEP_PING"
[ -f /etc/persistent/mpower/led.conf ] && KEEP_LED=/tmp/mpower-keep-led && cp /etc/persistent/mpower/led.conf "$KEEP_LED"
[ -f /etc/persistent/mpower/api.conf ] && KEEP_API=/tmp/mpower-keep-api && cp /etc/persistent/mpower/api.conf "$KEEP_API"
[ -f /etc/persistent/mpower/.setup_done ] && KEEP_SETUP=1

# Stop custom service (stock lighttpd on 80/443/8080 stays up).
[ -x /etc/persistent/mpower/bin/mpower-service.sh ] && /etc/persistent/mpower/bin/mpower-service.sh stop || true
# BusyBox killall misses "sh script.sh" — also pattern-kill leftovers
for pat in 'mpower/bin/watchdog.sh' 'mpower/bin/ping-watch.sh' 'mpower/bin/udp-discover.sh' 'mpower/bin/udp-beacon' 'mpower/bin/button-watch.sh' 'mpower/bin/mqtt-client.sh' 'cgi-bin/scheduler.sh' 'httpd -p 8088'; do
  ps w 2>/dev/null | grep "$pat" | grep -v grep | while read pid rest; do
    case "$pid" in ''|*[!0-9]*) ;; *) kill "$pid" 2>/dev/null || true ;; esac
  done
done
sleep 1

mkdir -p /etc/persistent
rm -rf /etc/persistent/mpower
cp -a "$PAYLOAD/mpower" /etc/persistent/mpower
cp "$PAYLOAD/rc.poststart" /etc/persistent/rc.poststart
cp "$PAYLOAD/rc.prestart" /etc/persistent/rc.prestart
chmod 755 /etc/persistent/rc.poststart
chmod 755 /etc/persistent/rc.prestart
chmod 755 /etc/persistent/mpower/bin/*.sh
chmod 755 /etc/persistent/mpower/www/cgi-bin/*.sh
# Strip Windows CRLF if present (BusyBox shebang breaks on \r -> CGI 404)
# Only text scripts — never touch native binaries (udp-beacon).
for f in /etc/persistent/mpower/bin/*.sh /etc/persistent/mpower/www/cgi-bin/*.sh /etc/persistent/rc.prestart /etc/persistent/rc.poststart; do
  [ -f "$f" ] || continue
  tr -d '\r' < "$f" > "$f.lf" && mv "$f.lf" "$f"
done
chmod 755 /etc/persistent/rc.poststart
chmod 755 /etc/persistent/rc.prestart
chmod 755 /etc/persistent/mpower/bin/*.sh /etc/persistent/mpower/www/cgi-bin/*.sh
[ -f /etc/persistent/mpower/bin/udp-beacon ] && chmod 755 /etc/persistent/mpower/bin/udp-beacon
mkdir -p /etc/persistent/mpower/data

[ -n "$KEEP_WIFI" ] && cp "$KEEP_WIFI" /etc/persistent/mpower/wifi.conf && rm -f "$KEEP_WIFI"
[ -n "$KEEP_SCHED" ] && cp "$KEEP_SCHED" /etc/persistent/mpower/data/schedules.db && rm -f "$KEEP_SCHED"
[ -n "$KEEP_MQTT" ] && cp "$KEEP_MQTT" /etc/persistent/mpower/mqtt.conf && rm -f "$KEEP_MQTT"
[ -n "$KEEP_NET" ] && cp "$KEEP_NET" /etc/persistent/mpower/network.conf && rm -f "$KEEP_NET"
[ -n "$KEEP_LOC" ] && cp "$KEEP_LOC" /etc/persistent/mpower/location.conf && rm -f "$KEEP_LOC"
[ -n "$KEEP_TIME" ] && cp "$KEEP_TIME" /etc/persistent/mpower/time.conf && rm -f "$KEEP_TIME"
[ -n "$KEEP_DEV" ] && cp "$KEEP_DEV" /etc/persistent/mpower/device.conf && rm -f "$KEEP_DEV"
[ -n "$KEEP_PING" ] && cp "$KEEP_PING" /etc/persistent/mpower/ping.conf && rm -f "$KEEP_PING"
[ -n "$KEEP_LED" ] && cp "$KEEP_LED" /etc/persistent/mpower/led.conf && rm -f "$KEEP_LED"
[ -n "$KEEP_API" ] && cp "$KEEP_API" /etc/persistent/mpower/api.conf && rm -f "$KEEP_API"
[ -n "$KEEP_SETUP" ] && touch /etc/persistent/mpower/.setup_done

if [ -n "$KEEP_TOKEN" ]; then
  cp "$KEEP_TOKEN" /etc/persistent/mpower/api.token
  rm -f "$KEEP_TOKEN"
else
  # Fleet-wide static token (same on every fresh install)
  printf '%s\n' '6d6c74656b6e657472656c61796d70316d6c74656b6e657472656c61796d7031' > /etc/persistent/mpower/api.token
fi
chmod 600 /etc/persistent/mpower/api.token

if [ -n "$KEEP_PASS" ]; then
  cp "$KEEP_PASS" /etc/persistent/mpower/admin.pass
  rm -f "$KEEP_PASS"
fi

printf '%s\n' "$VERSION" > /etc/persistent/mpower/.installed
date > /etc/persistent/mpower/.installed.at 2>/dev/null || true

# Default admin password hash for "mltek" if missing; migrate legacy "ubnt"
UBNT_HASH=$(printf '%s' "mpower:ubnt" | md5sum | awk '{print $1}')
MLTEK_HASH=$(printf '%s' "mpower:mltek" | md5sum | awk '{print $1}')
if [ ! -f /etc/persistent/mpower/admin.pass ]; then
  printf '%s\n' "$MLTEK_HASH" > /etc/persistent/mpower/admin.pass
elif [ "$(tr -d '\r\n' < /etc/persistent/mpower/admin.pass)" = "$UBNT_HASH" ]; then
  printf '%s\n' "$MLTEK_HASH" > /etc/persistent/mpower/admin.pass
fi
chmod 600 /etc/persistent/mpower/admin.pass 2>/dev/null
# Default location Çorlu / Tekirdağ if missing
if [ ! -f /etc/persistent/mpower/location.conf ]; then
  printf 'lat=41.1592\nlon=27.8000\ntz=3\n' > /etc/persistent/mpower/location.conf
fi
if [ ! -f /etc/persistent/mpower/time.conf ]; then
  printf 'ntp=pool.ntp.org\n' > /etc/persistent/mpower/time.conf
fi
if [ ! -f /etc/persistent/mpower/device.conf ]; then
  printf 'name=NetRelayMP\n' > /etc/persistent/mpower/device.conf
fi
if [ ! -f /etc/persistent/mpower/network.conf ]; then
  printf 'mode=dhcp\nip=\nnetmask=\ngateway=\ndns=\ndns2=\n' > /etc/persistent/mpower/network.conf
fi
rm -f /etc/persistent/mpower/safety.conf
if [ ! -f /etc/persistent/mpower/ping.conf ]; then
  printf 'enabled=0\nhost=\ninterval=30\nfail_count=3\nport=1\nfail_action=off\nrestore_sec=10\ncooldown=60\n' > /etc/persistent/mpower/ping.conf
fi
if [ ! -f /etc/persistent/mpower/api.conf ]; then
  printf 'enabled=1\n' > /etc/persistent/mpower/api.conf
fi

chmod 755 /etc/persistent/mpower/bin/* /etc/persistent/mpower/www/cgi-bin/* 2>/dev/null
chmod 644 /etc/persistent/mpower/bin/sun.awk 2>/dev/null
# native MIPS helper (not a .sh)
[ -f /etc/persistent/mpower/bin/udp-beacon ] && chmod 755 /etc/persistent/mpower/bin/udp-beacon

# Keep a copy of rc.poststart inside overlay for soft factory restore
mkdir -p /etc/persistent/mpower/share
cp /etc/persistent/rc.poststart /etc/persistent/mpower/share/rc.poststart
cp /etc/persistent/rc.prestart /etc/persistent/mpower/share/rc.prestart
chmod 755 /etc/persistent/mpower/share/rc.poststart
chmod 755 /etc/persistent/mpower/share/rc.prestart

# Seed tarball is optional (self-heal). Build in /tmp first — never abort install on OOM/bus error.
# Previous builds sometimes SIGBUS'd here on small /etc/persistent + BusyBox tar.
# cfgmtd already archives /etc/persistent. A second complete tar copy can
# overflow the mPower config flash and cause "Invalid Head" / "Bus error".
rm -f /etc/persistent/mpower-seed.tar /etc/persistent/mpower-seed.tar.tmp

# Persist overlay to flash (critical for reboot/power-loss survival).
# Never hide this error: without a successful cfgmtd write the files only live
# in the RAM-backed /etc tree and disappear at the next cold boot.
if ! command -v cfgmtd >/dev/null 2>&1; then
  echo "ERROR: cfgmtd not found; overlay was NOT persisted to flash" >&2
  exit 1
fi
# Existing installations already have wifi.conf. Mirror it into the stock
# profile now so the next cold boot can associate before rc.poststart.
if [ -f /etc/persistent/mpower/wifi.conf ]; then
  /bin/sh /etc/persistent/mpower/bin/stock-wifi-sync.sh >/tmp/mpower-stock-wifi.log 2>&1 || true
fi
# Cut stock sleep-180 boot delay via cron/pwdog → early-cron.sh
/bin/sh /etc/persistent/mpower/bin/ensure-boot-speed.sh >/tmp/mpower-boot-speed.log 2>&1 || true
sync
if ! cfgmtd -w -p /etc >/tmp/mpower-cfgmtd.log 2>&1; then
  echo "ERROR: cfgmtd flash write failed; overlay is running from RAM only" >&2
  cat /tmp/mpower-cfgmtd.log >&2 2>/dev/null || true
  df -h /etc/persistent >&2 2>/dev/null || true
  exit 1
fi
sync
echo "Flash persistence: OK"

# Own reset button ASAP (reduces stock factory wiping /etc/persistent)
/bin/sh /etc/persistent/mpower/bin/button-watch.sh >>/tmp/mpower-button.log 2>&1 &

# Start immediately (also starts again via rc.poststart after boot delay).
/etc/persistent/mpower/bin/mpower-service.sh start >/tmp/mpower-standalone.log 2>&1 || true

TOKEN=$(tr -d '\r\n' < /etc/persistent/mpower/api.token)
IP=$(ifconfig br0 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p')
[ -n "$IP" ] || IP=192.168.2.20

echo "OK installed"
echo "UI=http://$IP:8088"
echo "TOKEN=$TOKEN"
echo "Note: stock UI remains on http://$IP:8080"
