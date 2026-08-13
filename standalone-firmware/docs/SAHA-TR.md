# NetRelayMP — Saha kontrol listesi

Pilot UI: `http://CIHAZ_IP:8088` · giriş `admin` / `mltek` · stock UI `:8080`

Özellikler ve ekran görüntüleri: [OZELLIKLER-TR.md](OZELLIKLER-TR.md)

## 1. İlk kurulum (cihaz başına)

1. Cihazı aç; genelde ~1 dk içinde custom UI (`:8088`) ayağa kalkar (early-cron; yoksa stock ~3 dk `rc.poststart`).
2. Modem 2.4 GHz: WPA2-PSK + AES, 20 MHz, kanal 1/6/11, ax/WPS/11R kapalı ([KURULUM-TR.md](KURULUM-TR.md)).
3. Giriş yap → **Kurulum** (Wi‑Fi SSID/şifre) → bağlan.
4. **Ağ**: DHCP veya statik IP/GW/DNS.
5. **Ayarlar**: cihaz adı (`NetRelayMP-…`), NTP sunucusu; internet yoksa tarayıcıdan saat senkron.
6. **MQTT**: broker, kullanıcı, `prefix`, HA discovery açık. Önerilen broker: [mqttserver](https://github.com/mlteknoloji/mqttserver) (`31883`). Depolar: [DEPOSLAR-TR.md](DEPOSLAR-TR.md).
7. API token’ı not et: Ayarlar veya `cat /etc/persistent/mpower/api.token`.

Toplu paket: `deploy.ps1 -Target IP [-KeepToken]` · CSV sonuç üretir.

## 2. Fleet clone (aynı Wi‑Fi/MQTT profili)

1. Master cihazda **Yedek & Saha** → JSON indir (parola için “secrets” işaretle).
2. Diğer cihazlara:

```powershell
.\clone-config.ps1 -Backup master.json -TargetsFile hosts.txt
# veya
.\clone-config.ps1 -Backup master.json -Target 192.168.2.21
```

3. Statik IP kullanan sitede `network` alanını cihaz başına düzeltin; yedek aynı IP’yi herkese basmasın.

## 3. MQTT / Home Assistant

1. Sağlık panelinde: `watchdog=1`, `wifi_ip` dolu, `time_synced=1`, `mqtt_running=1`.
2. Dinleme: `mosquitto_sub -h BROKER -t 'mpower/mltek/#' -v`
3. Komut topic: `mpower/mltek/<MAC>/cmd`
   Örnek: `{"action":"on","port":1}` · `off` · `pulse` · `cycle` · `update` (URL).
4. HA: aynı broker’da MQTT discovery; entity’ler `mpower/mltek/<MAC>/...` altında görünür.
5. Apple Home için: [HOMEKIT-TR.md](HOMEKIT-TR.md) (HA HomeKit Bridge veya Homebridge).

## 4. Watchdog (otomatik)

`watchdog.sh` ~30 sn’de bir:

- `:8088` httpd yoksa yeniden başlatır
- Wi‑Fi IP kaybında `wifi-client.sh`
- Saat 1970’teyse ve default route varsa NTP
- MQTT açıksa client düşmüşse yeniden başlatır
- Scheduler düşmüşse yeniden başlatır

Log: `/tmp/mpower-watchdog.log`

## 5. Güncelleme

- UI **Ayarlar** → overlay paket yükle, veya MQTT `update` + URL.
- Sürüm: `/etc/persistent/mpower/.installed` (ör. `1.3.0`).

## 6. Yaygın sorunlar

| Belirti | Kontrol |
|--------|---------|
| `:8088` yok | 3 dk bekle; `ps \| grep httpd`; `cfgmtd` yazıldı mı |
| CGI 404 | Script’te CRLF — `install.sh` `\r` temizler; Windows’tan elle kopyalama |
| MQTT yok | Broker erişimi, saat, `mqtt.conf` `enabled=1` |
| 401/405 API | Token + **POST** (token’lı yazma işlemleri POST ister) |
| NTP fail | Cihazda internet/GW yok — tarayıcı saat senkron kullan |
| Wi‑Fi bağlanır, IP yok | Modem 2.4 GHz: WPA2+AES, 20 MHz, ax kapalı; misafir/izolasyon kapalı |
| cfg dolu | Overlay küçük tut; gereksiz log yazma |

## 7. SSH (Windows)

Eski Dropbear için `HostKeyAlgorithms=+ssh-rsa`, `KexAlgorithms=+diffie-hellman-group1-sha1`, `Ciphers=+aes128-cbc`. SCP: `-O`.
