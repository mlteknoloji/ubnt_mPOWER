# NetRelayMP (mPower standalone overlay)

Custom web UI and services for EOL Ubiquiti mFi mPower (**MF.v2.1.11**). Runs beside stock firmware; does **not** replace the official `.bin`.

- UI: `http://IP:8088` · login `admin` / `mltek`
- Stock UI remains on `:8080`
- Branding: **NetRelayMP**
- Factory reset: use the Settings UI only. Hardware reset: hold about **2 seconds** to reboot; never long-hold (stock firmware erases the overlay).

## Quick start

```powershell
cd standalone-firmware
# Overlay only
.\deploy.ps1 -Target 192.168.2.20 -KeepToken

# Local Ubiquiti MF.v2.1.11.bin, then overlay
.\deploy.ps1 -Target 192.168.2.20 -UpgradeStock -StockBin .\firmware\MF.v2.1.11.bin -KeepToken
.\deploy.ps1 -Target 192.168.2.20 -UpgradeStock -KeepToken

# Fleet: stock then overlay
.\deploy.ps1 -TargetsFile .\hosts.txt -UpgradeStock -KeepToken
```

Build only (for **Settings -> Firmware update**):

```powershell
.\build.ps1
# dist\mpower-overlay-latest.tar
```

## Features (1.3.0)

- Wi‑Fi setup, static IP, schedules (clock / pulse / sun)
- REST + MQTT (+ HA discovery) with cmd topic
- Overlay update from browser or MQTT URL
- **Watchdog**: httpd, Wi-Fi, NTP, MQTT, scheduler

Default MQTT topic root for the `mltek` user is `mpower/mltek/{MAC}/`.
For example: `mpower/mltek/24a43cd750b5/state` and
`mpower/mltek/24a43cd750b5/cmd`.
- **Backup/restore** JSON + `clone-config.ps1` for fleet
- **Ping watch**: unreachable host → relay on/off/toggle → restore after X sec

## Docs

| Doc | |
|-----|--|
| [docs/KURULUM-TR.md](docs/KURULUM-TR.md) / [EN](docs/KURULUM-EN.md) | Install |
| [docs/MQTT-TR.md](docs/MQTT-TR.md) / [EN](docs/MQTT-EN.md) | MQTT / HA |
| [docs/HOMEKIT-TR.md](docs/HOMEKIT-TR.md) / [EN](docs/HOMEKIT-EN.md) | Apple Home (HA Bridge / Homebridge) |
| [docs/SAHA-TR.md](docs/SAHA-TR.md) / [EN](docs/SAHA-EN.md) | Field checklist |
| [docs/DEPOSLAR-TR.md](docs/DEPOSLAR-TR.md) / [EN](docs/REPOS-EN.md) | GitHub repos |
| [docs/SATIN-AL-TR.md](docs/SATIN-AL-TR.md) / [EN](docs/BUY-EN.md) | Buy hardware |
| [docs/OZELLIKLER-TR.md](docs/OZELLIKLER-TR.md) / [EN](docs/FEATURES-EN.md) | Features + screenshots |
| [brochure/index.html](brochure/index.html) | Sales / product brochure |

## Buy

- https://wifidepo.com/ubnt-mpower-521
- https://wifianten.com/ubnt-mpower-335

## GitHub

- [ubnt_mPOWER](https://github.com/mlteknoloji/ubnt_mPOWER) — this overlay (device UI + MQTT client)
- [mqttserver](https://github.com/mlteknoloji/mqttserver) — companion MQTT broker (port **31883**, panel **8082**)

## Layout

- `payload/mpower/` — overlay (www, bin, conf)
- `payload/rc.poststart` — delayed start
- `install.sh` — on-device install into `/etc/persistent`
- `deploy.ps1` — build USTAR tar + SCP + install
- `clone-config.ps1` — push backup JSON to many IPs
