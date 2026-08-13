# Field Checklist (English) — 80 units

NetRelayMP overlay v1.3+ production / field validation.

Features and screenshots: [FEATURES-EN.md](FEATURES-EN.md)

## 1. Physical / network

- [ ] Powered on, LED OK
- [ ] `http://IP:8088` loads (~3 min boot delay possible)
- [ ] Login: `admin` / (changed password)
- [ ] Modem 2.4 GHz: WPA2-PSK + AES, 20 MHz, channel 1/6/11, **no ax**, WPS/11R off ([KURULUM-EN.md](KURULUM-EN.md))
- [ ] Connected to target SSID via **Setup / Wi‑Fi**
- [ ] **Backup** page shows `wifi_ip` and `net_ok: 1`

## 2. Clock

- [ ] NTP works **or** Dashboard → **Fix device time**
- [ ] `time_synced: 1`
- [ ] Required if schedules / sunrise-sunset are used

## 3. MQTT / Home Assistant

Recommended broker: [mqttserver](https://github.com/mlteknoloji/mqttserver) (port **31883**). Repos: [REPOS-EN.md](REPOS-EN.md).

- [ ] Settings → MQTT broker configured
- [ ] Prefix `mpower`, HA discovery on (if desired)
- [ ] Device name set
- [ ] Note MAC from `status.sh` / Dashboard
- [ ] Subscribe: `mosquitto_sub -h BROKER -t 'mpower/MAC/#' -v`
- [ ] `.../state` JSON received
- [ ] Command: `mosquitto_pub -t 'mpower/MAC/cmd' -m '{"action":"on","port":1}'`
- [ ] Pulse: `{"action":"pulse","port":1,"delay":10,"to":1}`
- [ ] HA discovers switches/sensors on same broker

## 4. Fleet (80 units)

1. Configure master (Wi‑Fi, MQTT)  
2. **Backup → Download JSON** (optionally with secrets)  
3. On PC:

```bat
cd standalone-firmware
powershell -ExecutionPolicy Bypass -File .\clone-config.ps1 -Backup .\netrelaymp-backup.json -TargetsFile .\hosts.txt
```

4. Overlay to all:

```bat
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -TargetsFile .\hosts.txt -KeepToken
```

## 5. Watchdog

Health should show `watchdog: 1`. Auto-recovers httpd, Wi‑Fi, MQTT, NTP attempts.

## Recovery

- AP / `192.168.2.20:8088`
- SSH `ubnt` / `ubnt`
- Logs: `/tmp/mpower-watchdog.log`, `mpower-ntp.log`, `mpower-mqtt.log`
