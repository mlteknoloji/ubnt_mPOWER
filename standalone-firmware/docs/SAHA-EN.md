# NetRelayMP — Field checklist

Pilot UI: `http://DEVICE_IP:8088` · login `admin` / `mltek` · stock UI `:8080`

Features and screenshots: [FEATURES-EN.md](FEATURES-EN.md)

## 1. Per-device setup

1. Power on; custom UI on `:8088` in about ~1 minute (early-cron; else stock ~3 min `rc.poststart`).
2. Modem 2.4 GHz: WPA2-PSK + AES, 20 MHz, channel 1/6/11, no ax/WPS/11R ([KURULUM-EN.md](KURULUM-EN.md)).
3. Login → **Setup** (Wi‑Fi) → connect.
4. **Network**: DHCP or static IP/GW/DNS.
5. **Settings**: device name, NTP; if offline, sync clock from browser.
6. **MQTT**: broker, user, `prefix`, HA discovery on. Recommended broker: [mqttserver](https://github.com/mlteknoloji/mqttserver) (`31883`). Repos: [REPOS-EN.md](REPOS-EN.md).
7. Note API token from Settings or `cat /etc/persistent/mpower/api.token`.

Bulk install: `deploy.ps1 -Target IP [-KeepToken]`.

## 2. Fleet clone

1. On master: **Backup & Field** → download JSON (tick secrets for passwords).
2. Push:

```powershell
.\clone-config.ps1 -Backup master.json -TargetsFile hosts.txt
```

3. If using static IPs, fix `network` per device so you do not clone one IP to all units.

## 3. MQTT / Home Assistant

1. Health: `watchdog=1`, `wifi_ip` set, `time_synced=1`, `mqtt_running=1`.
2. Subscribe: `mosquitto_sub -h BROKER -t 'mpower/mltek/#' -v`
3. Command topic: `mpower/mltek/<MAC>/cmd` — `on` / `off` / `pulse` / `cycle` / `update`.
4. HA MQTT discovery on the same broker.

## 4. Watchdog

Every ~30s: httpd `:8088`, Wi‑Fi, NTP, MQTT client, scheduler.  
Log: `/tmp/mpower-watchdog.log`

## 5. Updates

Settings upload or MQTT `update` with URL. Version in `/etc/persistent/mpower/.installed`.

## 6. SSH from Windows

Legacy Dropbear: `HostKeyAlgorithms=+ssh-rsa`, `KexAlgorithms=+diffie-hellman-group1-sha1`, `Ciphers=+aes128-cbc`. SCP needs `-O`.
