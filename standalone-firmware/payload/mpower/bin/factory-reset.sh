#!/bin/sh
# Factory-reset NetRelayMP overlay *settings only* — never delete overlay code.
# Stock Ubiquiti factory (yellow LED / :8080 UI) wipes /etc/persistent and removes us.
#
# Scope: only files the overlay owns (settings under $ROOT, its two boot hooks,
# its own block in the crontab). It does NOT touch the stock firmware: no stock
# processes are killed, outlets are not switched, and /tmp/system.cfg (stock
# settings, incl. the Wi-Fi profile the overlay mirrored there) is left as is.
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

# Drop stock wipe flags so a long reset hold cannot erase /etc/persistent
# (the stock reset handler wevent stays frozen by button-watch; not killed here)
rm -f /etc/.reset_to_default /etc/persistent/.reset_to_default \
  /tmp/.reset_to_default /var/run/reset_to_default 2>/dev/null || true

# Clear sessions
rm -rf /tmp/mpower-sess /tmp/mpower-udp-peers.json /tmp/mpower-pingwatch.state 2>/dev/null

# Remove user configuration ONLY (never bin/ www/ seed / .installed)
rm -f "$ROOT/wifi.conf" "$ROOT/network.conf" "$ROOT/mqtt.conf" \
  "$ROOT/location.conf" "$ROOT/time.conf" "$ROOT/device.conf" \
  "$ROOT/safety.conf" "$ROOT/ping.conf" "$ROOT/led.conf" "$ROOT/api.conf" \
  "$ROOT/.setup_done" "$ROOT/api.token" "$ROOT/admin.pass" \
  "$ROOT/resolv.conf" /etc/persistent/mpower-update-status.json 2>/dev/null
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
printf 'enabled=0\n' > "$ROOT/api.conf"
printf 'enabled1=0\nhost1=\ninterval1=30\nfail_count1=3\nfail_action1=off\nrestore_sec1=10\ncooldown1=60\nenabled2=0\nhost2=\ninterval2=30\nfail_count2=3\nfail_action2=off\nrestore_sec2=10\ncooldown2=60\nenabled3=0\nhost3=\ninterval3=30\nfail_count3=3\nfail_action3=off\nrestore_sec3=10\ncooldown3=60\n' > "$ROOT/ping.conf"
/bin/sh "$ROOT/bin/schedule-cron.sh" >>/tmp/mpower-scheduler.log 2>&1

# Outlets are deliberately left alone: relay state is not an overlay setting,
# and cutting power to the loads would be a stock-side effect.

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

if ! cfgmtd -w -p /etc >>"$LOG" 2>&1; then
  log "ERROR: cfgmtd failed; keeping device running to avoid losing reset changes"
  /bin/sh "$ROOT/bin/mpower-service.sh" start >/tmp/mpower-standalone.log 2>&1 &
  exit 1
fi
log "cfgmtd done — reboot"

sync
sleep 1
reboot
