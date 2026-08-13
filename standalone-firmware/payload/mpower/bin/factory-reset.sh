#!/bin/sh
# Factory-reset NetRelayMP overlay *settings only* — never delete overlay code.
# Stock Ubiquiti factory (yellow LED / :8080 UI) wipes /etc/persistent and removes us.
ROOT=/etc/persistent/mpower
LOG=/tmp/mpower-factory-reset.log

log() { echo "$(date 2>/dev/null) $*" >> "$LOG"; }

log "factory reset start reason=${1:-manual}"

# Abort if overlay missing (stock wipe already happened)
if [ ! -d "$ROOT/bin" ] || [ ! -d "$ROOT/www" ]; then
  log "ABORT: overlay code missing under $ROOT — cannot soft-reset"
  exit 1
fi

# Stop helpers first
[ -x "$ROOT/bin/mpower-service.sh" ] && /bin/sh "$ROOT/bin/mpower-service.sh" stop >/dev/null 2>&1 || true

# Best-effort: stop stock paths that wipe /etc/persistent on long reset
killall wevent 2>/dev/null || true
rm -f /etc/.reset_to_default /etc/persistent/.reset_to_default \
  /tmp/.reset_to_default /var/run/reset_to_default 2>/dev/null || true

# Clear sessions
rm -rf /tmp/mpower-sess /tmp/mpower-udp-peers.json /tmp/mpower-pingwatch.state 2>/dev/null

# Remove user configuration ONLY (never bin/ www/ seed / .installed)
rm -f "$ROOT/wifi.conf" "$ROOT/network.conf" "$ROOT/mqtt.conf" \
  "$ROOT/location.conf" "$ROOT/time.conf" "$ROOT/device.conf" \
  "$ROOT/safety.conf" "$ROOT/ping.conf" "$ROOT/led.conf" "$ROOT/api.conf" \
  "$ROOT/.setup_done" "$ROOT/api.token" "$ROOT/admin.pass" 2>/dev/null
rm -f "$ROOT/data/schedules.db" 2>/dev/null
mkdir -p "$ROOT/data"

# Defaults
printf 'mode=dhcp\nip=\nnetmask=\ngateway=\ndns=\ndns2=\n' > "$ROOT/network.conf"
printf '%s' "mpower:mltek" | md5sum | awk '{print $1}' > "$ROOT/admin.pass"
chmod 600 "$ROOT/admin.pass"
printf '%s\n' '6d6c74656b6e657472656c61796d70316d6c74656b6e657472656c61796d7031' > "$ROOT/api.token"
chmod 600 "$ROOT/api.token"
printf 'name=NetRelayMP\n' > "$ROOT/device.conf"
printf 'lat=41.1592\nlon=27.8000\ntz=3\n' > "$ROOT/location.conf"
printf 'ntp=pool.ntp.org\n' > "$ROOT/time.conf"
printf 'enabled=1\n' > "$ROOT/api.conf"
printf 'enabled1=0\nhost1=\ninterval1=30\nfail_count1=3\nfail_action1=off\nrestore_sec1=10\ncooldown1=60\nenabled2=0\nhost2=\ninterval2=30\nfail_count2=3\nfail_action2=off\nrestore_sec2=10\ncooldown2=60\nenabled3=0\nhost3=\ninterval3=30\nfail_count3=3\nfail_action3=off\nrestore_sec3=10\ncooldown3=60\n' > "$ROOT/ping.conf"
/bin/sh "$ROOT/bin/schedule-cron.sh" >>/tmp/mpower-scheduler.log 2>&1

# Relays off
for p in 1 2 3; do printf 0 > /proc/power/relay$p 2>/dev/null; done

# Re-assert boot hook from embedded copy (survives accidental rc.poststart loss)
if [ -f "$ROOT/share/rc.poststart" ]; then
  cp "$ROOT/share/rc.poststart" /etc/persistent/rc.poststart
  chmod 755 /etc/persistent/rc.poststart
  tr -d '\r' < /etc/persistent/rc.poststart > /etc/persistent/rc.poststart.lf 2>/dev/null \
    && mv /etc/persistent/rc.poststart.lf /etc/persistent/rc.poststart
  chmod 755 /etc/persistent/rc.poststart
  log "rc.poststart restored from share"
fi

if [ -f "$ROOT/share/rc.prestart" ]; then
  cp "$ROOT/share/rc.prestart" /etc/persistent/rc.prestart
  tr -d '\r' < /etc/persistent/rc.prestart > /etc/persistent/rc.prestart.lf 2>/dev/null \
    && mv /etc/persistent/rc.prestart.lf /etc/persistent/rc.prestart
  chmod 755 /etc/persistent/rc.prestart
  log "rc.prestart restored from share"
fi

# Refresh seed so partial wipe can self-heal on next boot
rm -f /etc/persistent/mpower-seed.tar /etc/persistent/mpower-seed.tar.tmp

# Safety: never persist if code vanished mid-run
if [ ! -f "$ROOT/bin/mpower-service.sh" ] || [ ! -f "$ROOT/www/index.html" ]; then
  log "ABORT before cfgmtd: overlay incomplete"
  exit 1
fi

cfgmtd -w -p /etc >/dev/null 2>&1
log "cfgmtd done — verify then reboot"

sync
sleep 1
reboot
