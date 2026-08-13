# NetRelayMP install (EN)

## Requirements

- mFi mPower, firmware **MF.v2.1.11** (installed with `-UpgradeStock` below)
- SSH `ubnt` / `ubnt`
- Windows PowerShell + OpenSSH
- Reachable device IP

## Connect to the device Wi‑Fi

1. Power the unit. Stock firmware broadcasts an **open** (no password) AP. That AP has no internet.
2. If you need stock **MF.v2.1.11**, `git clone` **while still online** (the `.bin` is in the repo).
3. SSID: `mFi` + last 6 of the MAC (e.g. `mFi D65475`). Join that network.
4. Device IP: **192.168.2.20**. If DHCP does not assign an address, set a temporary static IP: `192.168.2.10` / `255.255.255.0`.
5. SSH: `ubnt` / `ubnt` · stock UI `http://192.168.2.20` · overlay `http://192.168.2.20:8088`

## One device (Windows)

```powershell
git clone https://github.com/mlteknoloji/ubnt_mPOWER.git
cd ubnt_mPOWER\standalone-firmware
.\deploy.ps1 -Target 192.168.2.20 -KeepToken
```

UI: `http://IP:8088` · `admin` / `mltek`. Stock UI stays on `:8080`.  
If the unit is already **MF.v2.1.11**, this installs the overlay only.

## Stock mFi upgrade + NetRelayMP (MF.v2.1.11)

If the unit is on an older mFi build, official **MF.v2.1.11** is flashed first, then the overlay.  
Check version: SSH `cat /etc/version`

`git clone` already includes `firmware\MF.v2.1.11.bin`. The device AP has **no internet**; clone **while still online**, then join the AP.

Flash local Ubiquiti firmware with `deploy.ps1`:

```powershell
.\deploy.ps1 -Target 192.168.2.20 -UpgradeStock -StockBin .\firmware\MF.v2.1.11.bin -KeepToken
.\deploy.ps1 -Target 192.168.2.20 -UpgradeStock -KeepToken
.\deploy.ps1 -TargetsFile .\hosts.txt -UpgradeStock -KeepToken
```

- Local `.bin` present → no download
- Already `MF.v2.1.11` → stock flash skipped (`-ForceStockUpgrade` to force)
- Do not cut power during flash; script waits for SSH after reboot

Factory reset is available only from Settings. Hold the hardware button about **2 seconds** to reboot; a long hold triggers stock reset and erases the overlay.

If no DHCP server responds, the Wi-Fi client uses the emergency profile
`192.168.1.50/24`, gateway `192.168.1.1`, and DNS `1.1.1.1`, `8.8.8.8`.
The recovery AP **stays on** in that case (`http://192.168.2.20:8088`).

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

### Apply order

1. **Apply** the 2.4 GHz settings on the modem.
2. On the mPower panel: scan → pick SSID → password → **Connect**.
3. Recovery AP turns off only after a real LAN IP. On connect/DHCP errors it stays on.

## After login

Wi‑Fi → Network → Settings (name, NTP, MQTT) → optional Backup.

## Fleet settings clone

See [SAHA-EN.md](SAHA-EN.md) and `clone-config.ps1`.

## Related

- Features (screenshots): [FEATURES-EN.md](FEATURES-EN.md)
- [MQTT-EN.md](MQTT-EN.md) · [KURULUM-TR.md](KURULUM-TR.md)
- Repos: [REPOS-EN.md](REPOS-EN.md) · [ubnt_mPOWER](https://github.com/mlteknoloji/ubnt_mPOWER) · [mqttserver](https://github.com/mlteknoloji/mqttserver)
- Buy: [BUY-EN.md](BUY-EN.md) · [wifidepo](https://wifidepo.com/ubnt-mpower-521) · [wifianten](https://wifianten.com/ubnt-mpower-335)
