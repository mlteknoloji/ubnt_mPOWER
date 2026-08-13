# mPower Standalone Overlay


Ubiquiti mFi mPower (MF.v2.1.11) için bağımsız web arayüzü + MQTT/Home Assistant desteği.  
Independent web UI + MQTT/Home Assistant support for Ubiquiti mFi mPower (MF.v2.1.11).

> Bu paket resmi Ubiquiti `.bin` firmware değildir. Cihazın `/etc/persistent` alanına kurulan overlay’dir.  
> This is **not** an official Ubiquiti `.bin` firmware. It is a persistent overlay under `/etc/persistent`.

## Dokümantasyon / Documentation

| TR | EN |
|----|----|
| [Kurulum (TR)](docs/KURULUM-TR.md) | [Setup (EN)](docs/KURULUM-EN.md) |
| [MQTT (TR)](docs/MQTT-TR.md) | [MQTT (EN)](docs/MQTT-EN.md) |
| [Saha (TR)](docs/SAHA-TR.md) | [Field (EN)](docs/SAHA-EN.md) |
| [Depolar (TR)](docs/DEPOSLAR-TR.md) | [Repos (EN)](docs/REPOS-EN.md) |
| [Satın alma (TR)](docs/SATIN-AL-TR.md) | [Buy (EN)](docs/BUY-EN.md) |
| [Özellikler (TR)](docs/OZELLIKLER-TR.md) | [Features (EN)](docs/FEATURES-EN.md) |

## GitHub depoları / Repositories

| Depo / Repo | Ne işe yarar / What it is for |
|-------------|-------------------------------|
| [ubnt_mPOWER](https://github.com/mlteknoloji/ubnt_mPOWER) | Cihaz overlay: NetRelayMP panel, REST, MQTT **istemcisi** (bu depo). Device overlay: UI, REST, MQTT **client** (this repo). |
| [mqttserver](https://github.com/mlteknoloji/mqttserver) | LAN MQTT **broker** + web panel (`31883` / `8082`). Cihazlar buraya bağlanır. Devices connect here. |

Ayrıntı: [DEPOSLAR-TR.md](docs/DEPOSLAR-TR.md) · [REPOS-EN.md](docs/REPOS-EN.md)

## Satın alma / Buy

mFi mPower donanımı:

- https://wifidepo.com/ubnt-mpower-521
- https://wifianten.com/ubnt-mpower-335

## Cihaza Wi‑Fi ile bağlanma / Connect to the device Wi‑Fi

Cihazı fişe takın. Stok firmware **açık** (şifresiz) bir AP yayınlar. Bu AP’de internet yoktur.  
Power the unit. Stock firmware broadcasts an **open** (no password) AP. That AP has no internet.

Stok **MF.v2.1.11** için önce internetteyken `git clone` yapın (`.bin` repoda gelir), sonra bu AP’ye geçin.  
For stock **MF.v2.1.11**, `git clone` while still online (the `.bin` is in the repo), then join this AP.

SSID: `mFi` + MAC’in son 6 hanesi (ör. `mFi D65475`).  
SSID: `mFi` + last 6 of the MAC (e.g. `mFi D65475`).

1. Telefon / PC ile bu ağa bağlanın. / Join that AP from your phone or PC.
2. Cihaz IP: **192.168.2.20**
3. SSH: `ubnt` / `ubnt`
4. Stok UI: `http://192.168.2.20` · Overlay UI: `http://192.168.2.20:8088`

PC IP almazsa geçici statik: `192.168.2.10` / `255.255.255.0`.  
If DHCP does not assign an address, set a temporary static IP: `192.168.2.10` / `255.255.255.0`.

## Hızlı başlangıç / Quick start

```bat
git clone https://github.com/mlteknoloji/ubnt_mPOWER.git
cd ubnt_mPOWER\standalone-firmware
```

PowerShell komutlarını çalıştırmadan **önce** mPower Wi‑Fi’sine bağlanın (`mFi` + MAC son 6, ör. `mFi D65475`, IP **192.168.2.20**).  
**Before** running the PowerShell commands, join the mPower Wi‑Fi (`mFi` + last 6 of MAC, e.g. `mFi D65475`, IP **192.168.2.20**).

`192.168.2.20` adresine ping atabilmelisiniz. / You must be able to ping `192.168.2.20`.

```bat
ping 192.168.2.20
```

Cihaz firmware (yerel `firmware\MF.v2.1.11.bin`) / Device firmware (local `firmware\MF.v2.1.11.bin`):

```bat
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -Target 192.168.2.20 -UpgradeStock -StockBin .\firmware\MF.v2.1.11.bin -KeepToken
```

Overlay:

```bat
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -Target 192.168.2.20 -KeepToken
```

Arayüz / UI: `http://192.168.2.20:8088`  
Web login: `admin` / `mltek`

Tarayıcıda **API anahtarı / API token** düğmesine basın ve token’ı yapıştırın:  
In the browser click **API token** and paste:

```
6d6c74656b6e657472656c61796d70316d6c74656b6e657472656c61796d7031
```

Cihazdaki token: `cat /etc/persistent/mpower/api.token`  
Token on the device: `cat /etc/persistent/mpower/api.token`

## Lisans notu / License note

Donanım ve stok firmware Ubiquiti’ye aittir. Overlay betikleri bu depoda paylaşılır; kendi sorumluluğunuzda kullanın.  
Hardware/stock firmware belong to Ubiquiti. Overlay scripts are provided as-is; use at your own risk.
