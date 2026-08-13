# Setup Guide (English)

mPower Standalone Overlay — independent web UI on port **8088**.

## Requirements

- Device firmware: **MF.v2.1.11** (recommended) — installed with `-UpgradeStock` below
- Windows PC (`deploy.ps1`) or Linux/macOS with SSH/SCP
- Network reachability (factory recovery often `192.168.2.20`)
- SSH: user `ubnt`, password `ubnt` (factory)

## What gets installed?

This is **not** an official Ubiquiti flash image (`.bin`).  
It writes a web UI, CGI scripts, MQTT client and scheduler under `/etc/persistent/mpower` and persists via `cfgmtd`.

The stock UI (`:8080` / `:80`) remains available.

## 1) Single device (Windows)

Clone the repo first **while the PC is online**. The device’s own Wi‑Fi AP has **no internet**.

```bat
git clone https://github.com/mlteknoloji/ubnt_mPOWER.git
cd ubnt_mPOWER\standalone-firmware
```

**Before** running the PowerShell commands, join the mPower Wi‑Fi (`mFi` + last 6 of MAC, e.g. `mFi D65475`, IP **192.168.2.20**).  
You must be able to ping `192.168.2.20`:

```bat
ping 192.168.2.20
```

### Device firmware (local MF.v2.1.11.bin)

```bat
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -Target 192.168.2.20 -UpgradeStock -StockBin .\firmware\MF.v2.1.11.bin -KeepToken
```

### Overlay

```bat
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -Target 192.168.2.20 -KeepToken
```

- Local `.bin` present → no download (no internet needed on the device AP).
- Missing file → download from [GitHub](https://github.com/mlteknoloji/ubnt_mPOWER/raw/main/standalone-firmware/firmware/MF.v2.1.11.bin) / Ubiquiti CDN.
- Already `MF.v2.1.11` → stock flash is skipped (`-ForceStockUpgrade` to force).
- **Do not cut power** during flash; the script waits a few minutes for SSH to return.

`-KeepToken` keeps the existing API token.  
Without it, a new random token is generated (written to CSV).

Output:

```
OK installed
UI=http://192.168.2.20:8088
TOKEN=...
```

Browser: `http://192.168.2.20:8088` · login `admin` / `mltek`.  
Click **API token** and paste (default / `-KeepToken`):

```
6d6c74656b6e657472656c61796d70316d6c74656b6e657472656c61796d7031
```

On the device: `cat /etc/persistent/mpower/api.token`

## 2) Fleet install

`hosts.txt`:

```
192.168.2.20
192.168.2.21
192.168.2.22
```

```bat
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -TargetsFile .\hosts.txt
```

Results: `deploy-results-YYYYMMDD-HHMMSS.csv` (IP, UI, TOKEN).

## 3) First boot (AP mode)

1. Power the unit. Stock firmware broadcasts an **open** (no password) AP.
2. This AP has no internet. If you need stock **MF.v2.1.11**, `git clone` **while still online** (the `.bin` is in the repo).
3. Join the SSID `mFi` + last 6 of the MAC (e.g. `mFi D65475`).
4. Device IP: **192.168.2.20**. If DHCP does not assign an address, set a temporary static IP: `192.168.2.10` / `255.255.255.0`.
5. Open `http://192.168.2.20:8088`  
   - UI may appear ~**3 minutes** after boot (`rc.poststart` delay).
6. Use **Setup** (`/setup.html`):
   - Scan Wi‑Fi → pick SSID → password → Connect
   - Optional static IP / Subnet / Gateway / DNS
   - Change admin password (default `admin` / `mltek`)
7. Enter the API token in the browser (**API token** button) or sign in.

Recovery IP: **192.168.2.20** on the AP/`br0` side usually stays reachable.

## Modem 2.4 GHz Wi‑Fi settings

mPower joins **2.4 GHz only** (legacy Atheros 802.11n). On the home/office router, optimize for **compatibility**, not speed. Save these settings **before** connecting mPower to the LAN.

### Basic (WLAN → 2.4G)

| Setting | Required |
|---------|----------|
| SSID broadcast | On |
| WMM | On |
| 11R / 802.11r Fast Roaming | **Off** (mPower does not support it) |
| Authentication | **WPA2-PSK only** — do not use mixed WPA/WPA2 |
| Encryption | **AES (CCMP) only** — do not use `TKIP&AES` |
| WPS | **Off** |

Mixed `WPA/WPA2` + `TKIP&AES` can look associated on mPower while DHCP fails or the link drops.

### Advanced (2.4G)

| Setting | Required |
|---------|----------|
| TX power | 100% |
| Channel | **Fixed 1, 6, or 11** (least crowded). Avoid Auto |
| Channel width | **20 MHz** (do not enable 40 MHz) |
| Mode | **802.11b/g/n**. **Do not use mixed ax / Wi‑Fi 6**. If `b/g/n` is missing, leave `802.11b/g` — safer than `b/g/n/ax` |
| Airtime fairness | Off |
| Beacon, DTIM, RTS, Fragmentation | Defaults (100 / 1 / 2346 / 2346) |

### DHCP and isolation

- Do not put mPower on a **guest** SSID.
- Turn **AP isolation / client isolation** off.
- Leave room in the DHCP pool so the unit can get an address.

If DHCP fails, the recovery AP stays up: `http://192.168.2.20:8088`. Emergency STA profile: `192.168.1.50/24`, GW `192.168.1.1`.

### Apply order

1. **Apply** the 2.4 GHz settings on the modem.
2. On the mPower panel: scan → pick SSID → password → **Connect**.
3. Recovery AP turns off only after a real LAN IP. On connect/DHCP errors it stays on.

## 4) Web login

| Field | Value |
|------|--------|
| URL | `http://DEVICE-IP:8088` |
| User | `admin` |
| Password | `mltek` (change it) |
| API token | `cat /etc/persistent/mpower/api.token` |

Relay write operations require a web session **or** API token.

Dashboard, schedule, REST/MQTT and ping screenshots: [FEATURES-EN.md](FEATURES-EN.md)

## 5) Navigation (v1.2+)

- Desktop: left sidebar  
- Mobile: ☰ hamburger menu  
- Dashboard, Wi‑Fi, Network, Schedules, Settings, Setup, API

## 6) Updating the overlay

### From PC

```bat
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -Target 192.168.2.20 -KeepToken
```

### From browser

**Settings → Firmware update**: upload a USTAR `.tar` package or provide an HTTP URL.

### Via MQTT

```json
{"action":"update","url":"http://PC-IP/mpower-pkg.tar"}
```

## 7) Clock / NTP

If the clock shows 1970, schedules and sunrise/sunset will not work.  
Use **Settings → Location & Time → NTP sync** (device needs NTP reachability).

## 8) Troubleshooting

| Symptom | Fix |
|---------|-----|
| `:8088` not opening | Wait ~3 min; SSH `ps \| grep httpd` |
| 401 API token | Paste token in the browser |
| CGI 404 | CRLF in scripts; redeploy with LF |
| Lost Wi‑Fi | Rejoin via `192.168.2.20` AP |
| Associates but no IP (DHCP) | Match the 2.4 GHz table above: WPA2+AES, 20 MHz, no ax; guest/isolation off |
| No MQTT | Enable MQTT in Settings; open TCP 1883 to broker |

## 9) Manual install (SSH)

```sh
cd /tmp/mpower-pkg
tar xf pkg.tar
chmod +x install.sh
sh ./install.sh
```

## Security

- UI is plain **HTTP**; use only on trusted LAN/VLAN.
- Change default SSH and web passwords.
- Do not commit tokens or deploy CSV files to a public repo.

## Repositories

- Overlay (this project): [ubnt_mPOWER](https://github.com/mlteknoloji/ubnt_mPOWER)
- MQTT broker: [mqttserver](https://github.com/mlteknoloji/mqttserver) (port **31883**, panel **8082**)
- Details: [REPOS-EN.md](REPOS-EN.md)

## Buy

mFi mPower hardware: [BUY-EN.md](BUY-EN.md)

- https://wifidepo.com/ubnt-mpower-521
- https://wifianten.com/ubnt-mpower-335
