# Kurulum Kılavuzu (Türkçe)

mPower Standalone Overlay — bağımsız web arayüzü (port **8088**).

## Gereksinimler

- Cihaz firmware: **MF.v2.1.11** (önerilen) — aşağıdaki `-UpgradeStock` ile yüklenir
- Windows PC (deploy.ps1) veya Linux/macOS + SSH/SCP
- Aynı ağda erişim (ilk kurulumda genelde `192.168.2.20`)
- SSH: kullanıcı `ubnt`, parola `ubnt` (fabrika)

## Ne kurulur?

Resmi Ubiquiti flash (`.bin`) **değildir**.  
`/etc/persistent/mpower` altına web arayüzü, CGI, MQTT istemcisi ve zamanlayıcı yazılır. Reboot sonrası da kalır (`cfgmtd`).

Stock arayüz (`:8080` / `:80`) yerinde kalır.

## 1) Tek cihaz (Windows)

Önce depoyu klonlayın (internetteyken). Cihazın kendi Wi‑Fi AP’sinde internet **yoktur**.

```bat
git clone https://github.com/mlteknoloji/ubnt_mPOWER.git
cd ubnt_mPOWER\standalone-firmware
```

PowerShell komutlarını çalıştırmadan **önce** mPower Wi‑Fi’sine bağlanın (`mFi` + MAC son 6, ör. `mFi D65475`, IP **192.168.2.20**).  
`192.168.2.20` adresine ping atabilmelisiniz:

```bat
ping 192.168.2.20
```

### Cihaz firmware (yerel MF.v2.1.11.bin)

```bat
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -Target 192.168.2.20 -UpgradeStock -StockBin .\firmware\MF.v2.1.11.bin -KeepToken
```

### Overlay

```bat
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -Target 192.168.2.20 -KeepToken
```

- Yerel `.bin` varsa indirme yapılmaz (cihaz AP’sinde internet gerekmez).
- Dosya yoksa [GitHub](https://github.com/mlteknoloji/ubnt_mPOWER/raw/main/standalone-firmware/firmware/MF.v2.1.11.bin) / Ubiquiti CDN’den iner.
- Cihaz zaten `MF.v2.1.11` ise stok flash atlanır (`-ForceStockUpgrade` zorlar).
- Flash sırasında **güç kesmeyin**; SSH geri gelene kadar birkaç dakika bekler.

`-KeepToken` : mevcut API anahtarını korur.  
Parametresiz: yeni rastgele token üretir (CSV’ye yazar).

Kurulum çıktısı:

```
OK installed
UI=http://192.168.2.20:8088
TOKEN=...
```

Tarayıcı: `http://192.168.2.20:8088` · giriş `admin` / `mltek`.  
**API anahtarı** düğmesine basın ve token’ı yapıştırın (varsayılan / `-KeepToken`):

```
6d6c74656b6e657472656c61796d70316d6c74656b6e657472656c61796d7031
```

Cihazda: `cat /etc/persistent/mpower/api.token`

## 2) Çoklu cihaz (80 adet)

`hosts.txt`:

```
192.168.2.20
192.168.2.21
192.168.2.22
```

```bat
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -TargetsFile .\hosts.txt
```

Sonuç: `deploy-results-YYYYMMDD-HHMMSS.csv` (IP, UI, TOKEN).

## 3) İlk açılış (AP modu)

1. Cihazı fişe takın. Stok firmware **açık** (şifresiz) AP yayınlar.
2. Bu AP’de internet yoktur. Stok **MF.v2.1.11** yükleyecekseniz **önce** internetteyken `git clone` yapın (`.bin` repoda gelir).
3. Wi‑Fi listesinde SSID: `mFi` + MAC’in son 6 hanesi (ör. `mFi D65475`). Bu ağa bağlanın.
4. Cihaz IP: **192.168.2.20**. PC IP almazsa geçici statik: `192.168.2.10` / `255.255.255.0`.
5. Tarayıcı: `http://192.168.2.20:8088`  
   - Arayüz bazen boot’tan **~3 dakika** sonra gelir (`rc.poststart` gecikmesi).
6. **Kurulum** sihirbazı (`/setup.html`):
   - Wi‑Fi ağlarını tara → SSID seç → parola → Bağlan
   - İsteğe bağlı: statik IP / Subnet / Gateway / DNS
   - Admin parolasını değiştirin (varsayılan `admin` / `mltek`)
7. API anahtarını tarayıcıya girin (**API anahtarı** düğmesi) veya web ile giriş yapın.

Kurtarma IP’si: AP / `br0` üzerinden **192.168.2.20** genelde erişilebilir kalır.

## Modem 2.4 GHz Wi‑Fi ayarları

mPower yalnızca **2.4 GHz** bağlanır (eski Atheros 802.11n). Ev/iş modeminde hedef hız değil **uyumluluk** olmalıdır. Ayarları **mPower’ı ağa almadan önce** kaydedin.

### Temel (WLAN → 2.4G)

| Ayar | Olması gereken |
|------|----------------|
| SSID yayını | Açık |
| WMM | Açık |
| 11R / 802.11r Fast Roaming | **Kapalı** (mPower desteklemez) |
| Kimlik doğrulama | **Yalnızca WPA2-PSK** — WPA/WPA2 karışık mod kullanmayın |
| Şifreleme | **Yalnızca AES (CCMP)** — `TKIP&AES` kullanmayın |
| WPS | **Kapalı** |

`WPA/WPA2` + `TKIP&AES` karışık mod, mPower’da bağlanır gibi görünüp DHCP vermeme veya kopma yapabilir.

### Gelişmiş (2.4G)

| Ayar | Olması gereken |
|------|----------------|
| TX gücü | %100 |
| Kanal | **Sabit 1, 6 veya 11** (en az kalabalık). Otomatik kanal önermeyiz |
| Kanal genişliği | **20 MHz** (40 MHz açmayın) |
| Mod | **802.11b/g/n**. **ax / Wi‑Fi 6 karışık moda almayın**. Listede `b/g/n` yoksa `802.11b/g` bırakın; `b/g/n/ax`’ten daha güvenlidir |
| Adil dağıtım / Airtime Fairness | Kapalı |
| Beacon, DTIM, RTS, Fragmentation | Varsayılan (100 / 1 / 2346 / 2346) |

### DHCP ve izolasyon

- mPower’ı **misafir / guest** SSID’ye bağlamayın.
- **AP isolation / istemci izolasyonu** kapalı olsun.
- DHCP havuzu dolu olmasın; cihazın IP alması gerekir.

DHCP gelmezse kurtarma AP kapanmaz: `http://192.168.2.20:8088`. Acil STA profili: `192.168.1.50/24`, GW `192.168.1.1`.

### Uygulama sırası

1. Modemde yukarıdaki 2.4 GHz ayarlarını **Uygula**.
2. mPower panelinde ağı tara → SSID seç → parola → **Bağlan**.
3. Gerçek LAN IP görünce kurtarma AP kapanır. Hata veya DHCP yoksa AP açık kalır.

## 4) Web giriş

| Alan | Değer |
|------|--------|
| URL | `http://CIHAZ-IP:8088` |
| Kullanıcı | `admin` |
| Parola | `mltek` (değiştirin) |
| API token | `cat /etc/persistent/mpower/api.token` |

Röle yazma işlemleri: web oturumu **veya** API token ister.

Panel, zamanlama, REST/MQTT ve ping ekran görüntüleri: [OZELLIKLER-TR.md](OZELLIKLER-TR.md)

## 5) Menü (v1.2+)

- Masaüstü: sol menü  
- Mobil: ☰ sandviç menü  
- Panel, Wi‑Fi, Ağ, Zamanlama, Ayarlar, Kurulum, API

## 6) Overlay güncelleme

### PC’den

```bat
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -Target 192.168.2.20 -KeepToken
```

### Tarayıcıdan

**Ayarlar → Firmware update**: USTAR `.tar` paket yükleyin veya HTTP URL verin.

### MQTT ile

```json
{"action":"update","url":"http://PC-IP/mpower-pkg.tar"}
```

## 7) Saat / NTP

Cihaz saati 1970 ise zamanlama ve gün doğumu/batımı çalışmaz.  
**Ayarlar → Konum & Saat → NTP sync** (cihazın internete/NTP’ye erişimi olmalı).

## 8) Sorun giderme

| Belirti | Çözüm |
|---------|--------|
| `:8088` açılmıyor | ~3 dk bekleyin; SSH ile `ps \| grep httpd` |
| 401 API token | Token’ı tarayıcıya yapıştırın |
| CGI 404 | Script’lerde CRLF olmamalı; yeniden deploy edin |
| Wi‑Fi koptu | `192.168.2.20` AP üzerinden bağlanın |
| Bağlanır ama IP yok (DHCP) | Modem 2.4 GHz ayarlarını yukarıdaki tabloya çekin; WPA2+AES, 20 MHz, ax kapalı; misafir/izolasyon kapalı |
| MQTT yok | Ayarlar’da MQTT açın; broker’a UDP/TCP 1883 açık olsun |

## 9) Manuel kurulum (SSH)

```sh
# Paketi /tmp/mpower-pkg olarak kopyalayın, sonra:
cd /tmp/mpower-pkg
tar xf pkg.tar
chmod +x install.sh
sh ./install.sh
```

## Güvenlik

- Arayüz **HTTP** (şifreleme yok); yalnızca güvenilir LAN/VLAN’da kullanın.
- Varsayılan SSH ve web parolasını değiştirin.
- Token’ı GitHub’a / CSV’yi public repo’ya koymayın.

## Depolar

- Overlay (bu proje): [ubnt_mPOWER](https://github.com/mlteknoloji/ubnt_mPOWER)
- MQTT broker: [mqttserver](https://github.com/mlteknoloji/mqttserver) (port **31883**, panel **8082**)
- Ayrıntı: [DEPOSLAR-TR.md](DEPOSLAR-TR.md)

## Satın alma

mFi mPower donanımı: [SATIN-AL-TR.md](SATIN-AL-TR.md)

- https://wifidepo.com/ubnt-mpower-521
- https://wifianten.com/ubnt-mpower-335
