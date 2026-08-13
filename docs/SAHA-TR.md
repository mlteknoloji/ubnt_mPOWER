# Saha Kontrol Listesi (Türkçe) — 80 cihaz

NetRelayMP overlay v1.3+ için üretim / saha doğrulama.

Özellikler ve ekran görüntüleri: [OZELLIKLER-TR.md](OZELLIKLER-TR.md)

## 1. Fiziksel / ağ

- [ ] Cihaz fişte, LED yanıyor
- [ ] AP veya LAN üzerinden `http://IP:8088` açılıyor (~3 dk gecikme olabilir)
- [ ] Giriş: `admin` / (değiştirilmiş parola)
- [ ] Modem 2.4 GHz: WPA2-PSK + AES, 20 MHz, kanal 1/6/11, **ax yok**, WPS/11R kapalı ([KURULUM-TR.md](KURULUM-TR.md))
- [ ] **Kurulum / Wi‑Fi** ile hedef SSID’ye bağlandı
- [ ] **Yedek** sayfasında `wifi_ip` dolu, `net_ok: 1`

## 2. Saat

- [ ] NTP çalışıyor **veya** Panel → **Cihaz saatini düzelt**
- [ ] `time_synced: 1` (Yedek/sağlık)
- [ ] Zamanlama kullanılacaksa saat doğru olmalı

## 3. MQTT / Home Assistant

Önerilen broker: [mqttserver](https://github.com/mlteknoloji/mqttserver) (port **31883**). Depolar: [DEPOSLAR-TR.md](DEPOSLAR-TR.md).

- [ ] Ayarlar → MQTT broker IP/port/user
- [ ] Prefix `mpower`, HA discovery açık (isteniyorsa)
- [ ] Cihaz adı: örn. `NetRelayMP` veya oda adı
- [ ] MAC’i not edin (`status.sh` veya Panel)
- [ ] Dinleme: `mosquitto_sub -h BROKER -t 'mpower/MAC/#' -v`
- [ ] `.../state` JSON geliyor (relay, watt, volt, firmware, name)
- [ ] Komut: `mosquitto_pub -t 'mpower/MAC/cmd' -m '{"action":"on","port":1}'`
- [ ] Pulse: `{"action":"pulse","port":1,"delay":10,"to":1}`
- [ ] HA aynı broker’da switch/sensor görünüyor

## 4. Fleet (80 adet)

1. Master cihazda Wi‑Fi + MQTT ayarını yapın  
2. **Yedek → JSON indir** (gerekirse “secrets” işaretli)  
3. PC’de:

```bat
cd standalone-firmware
powershell -ExecutionPolicy Bypass -File .\clone-config.ps1 -Backup .\netrelaymp-backup.json -TargetsFile .\hosts.txt
```

4. Her cihaz için overlay:

```bat
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -TargetsFile .\hosts.txt -KeepToken
```

(İlk kurulumda KeepToken olmadan da olur; token CSV’de saklanır.)

## 5. Watchdog

Sağlıkta `watchdog: 1` olmalı. Otomatik:

- httpd :8088 düşerse yeniden başlar
- Wi‑Fi IP kaybında yeniden bağlanır
- MQTT process ölürse yeniden başlar
- NTP mümkünse dener

## Acil kurtarma

- AP / `192.168.2.20:8088`
- SSH `ubnt` / `ubnt`
- `cat /tmp/mpower-watchdog.log` / `cat /tmp/mpower-ntp.log` / `cat /tmp/mpower-mqtt.log`
