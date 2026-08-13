# NetRelayMP kurulum (TR)

## Gereksinimler

- mFi mPower, firmware **MF.v2.1.11** (aşağıdaki `-UpgradeStock` ile yüklenir)
- SSH: `ubnt` / `ubnt`
- Windows: PowerShell + OpenSSH client
- Hedef ağda cihaza erişim (ör. `192.168.2.20`)

## Cihaza Wi‑Fi ile bağlanma

1. Cihazı fişe takın. Stok firmware **açık** (şifresiz) AP yayınlar. Bu AP’de internet yoktur.
2. Stok **MF.v2.1.11** yükleyecekseniz **önce** internetteyken `git clone` yapın (`.bin` repoda gelir).
3. SSID: `mFi` + MAC’in son 6 hanesi (ör. `mFi D65475`). Bu ağa bağlanın.
4. Cihaz IP: **192.168.2.20**. PC IP almazsa geçici statik: `192.168.2.10` / `255.255.255.0`.
5. SSH: `ubnt` / `ubnt` · stok UI `http://192.168.2.20` · overlay `http://192.168.2.20:8088`

## Tek cihaz (Windows)

```powershell
git clone https://github.com/mlteknoloji/ubnt_mPOWER.git
cd ubnt_mPOWER\standalone-firmware
.\deploy.ps1 -Target 192.168.2.20 -KeepToken
```

Zaten **MF.v2.1.11** ise yalnız overlay kurulur.

## Stok mFi yükselt + NetRelayMP (MF.v2.1.11)

Cihaz eski mFi sürümündeyse önce resmi **MF.v2.1.11** yazılır, sonra overlay kurulur.  
Sürüm: SSH `cat /etc/version`

`git clone` ile `firmware\MF.v2.1.11.bin` gelir. Cihaz AP’sinde internet **yoktur**; **önce** internetteyken klonlayın, sonra AP’ye geçin.

Yerel Ubiquiti firmware (`deploy.ps1`):

```powershell
cd ubnt_mPOWER\standalone-firmware
.\deploy.ps1 -Target 192.168.2.20 -UpgradeStock -StockBin .\firmware\MF.v2.1.11.bin -KeepToken
.\deploy.ps1 -Target 192.168.2.20 -UpgradeStock -KeepToken
.\deploy.ps1 -TargetsFile .\hosts.txt -UpgradeStock -KeepToken
```

- Yerel `.bin` varsa indirme yapılmaz.
- Cihaz zaten `MF.v2.1.11` ise stok flash atlanır (`-ForceStockUpgrade` zorlar).
- Flash sonrası SSH geri gelene kadar bekler (~ birkaç dakika); güç kesmeyin.

`-KeepToken`: mevcut API token korunur.  
Kurulum sonrası: `http://IP:8088` · `admin` / `mltek`

Fabrika ayarları yalnız Ayarlar sayfasından yapılır. Fiziksel düğme yaklaşık **2 saniye** ile yeniden başlatır; uzun basmak stock firmware'i tetikleyip overlay'i siler.

DHCP sunucusu yanıt vermezse Wi-Fi istemcisi `192.168.1.50/24`, ağ geçidi
`192.168.1.1`, DNS `1.1.1.1` ve `8.8.8.8` acil erişim profiline geçer.
Bu durumda kurtarma AP **kapanmaz** (`http://192.168.2.20:8088`).

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

### Uygulama sırası

1. Modemde yukarıdaki 2.4 GHz ayarlarını **Uygula**.
2. mPower panelinde ağı tara → SSID seç → parola → **Bağlan**.
3. Gerçek LAN IP görünce kurtarma AP kapanır. Hata veya DHCP yoksa AP açık kalır.

Paket `payload/` içeriğini BusyBox uyumlu USTAR tar ile atar; cihazda `install.sh` → `/etc/persistent` + `cfgmtd -w`.
Kurulum çıktısında `Flash persistence: OK` görülmeden cihazın elektriğini kesmeyin.
`cfgmtd` başarısız olursa kurulum artık başarılı sayılmaz; ayrıntı cihazda
`/tmp/mpower-cfgmtd.log` dosyasına yazılır.

## İlk giriş sonrası

1. Wi‑Fi bağlan (Kurulum / Wi‑Fi sayfası)
2. Ağ (DHCP veya statik)
3. Ayarlar: isim, NTP, MQTT
4. İsteğe bağlı: Yedek

## Sürüm

`standalone-firmware/VERSION` → cihazda `/etc/persistent/mpower/.installed`

## Güncelleme

Ayarlar → overlay yükle, veya MQTT `{"action":"update","url":"http://..."}`.

## Daha fazla

- Özellikler (ekran görüntüleri): [OZELLIKLER-TR.md](OZELLIKLER-TR.md)
- Saha: [SAHA-TR.md](SAHA-TR.md)
- MQTT: [MQTT-TR.md](MQTT-TR.md)
- Depolar: [DEPOSLAR-TR.md](DEPOSLAR-TR.md) · [ubnt_mPOWER](https://github.com/mlteknoloji/ubnt_mPOWER) · [mqttserver](https://github.com/mlteknoloji/mqttserver)
- Satın alma: [SATIN-AL-TR.md](SATIN-AL-TR.md) · [wifidepo](https://wifidepo.com/ubnt-mpower-521) · [wifianten](https://wifianten.com/ubnt-mpower-335)
- EN: [KURULUM-EN.md](KURULUM-EN.md)
