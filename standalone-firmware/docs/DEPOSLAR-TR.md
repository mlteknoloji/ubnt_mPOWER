# İlgili GitHub depoları

NetRelayMP iki ayrı depodan oluşur: **cihaz yazılımı** ve **MQTT sunucusu**.

| Depo | Adres | Ne işe yarar |
|------|--------|----------------|
| **ubnt_mPOWER** | https://github.com/mlteknoloji/ubnt_mPOWER | mFi mPower cihazına kurulan overlay (bu depo) |
| **mqttserver** | https://github.com/mlteknoloji/mqttserver | LAN’da çalışan MQTT broker + web yönetim paneli |

## ubnt_mPOWER — cihaz overlay

https://github.com/mlteknoloji/ubnt_mPOWER

Ubiquiti mFi mPower (**MF.v2.1.11**) üzerine kurulan **NetRelayMP** yazılımıdır. Resmi `.bin` değildir; `/etc/persistent` altına yazılır, stok UI `:8080` kalır.

**Ne sağlar**

- Web panel `http://CIHAZ-IP:8088` (TR/EN) · giriş `admin` / `mltek`
- Üç priz: aç / kapa / pulse / cycle · güç / enerji
- MQTT **istemcisi** (broker’a bağlanır, `mpower/mltek/{MAC}/` topic)
- REST API, zamanlama, ping izleme, JSON yedek, overlay güncelleme

Kurulum: [KURULUM-TR.md](KURULUM-TR.md)

## mqttserver — MQTT broker

https://github.com/mlteknoloji/mqttserver

ML Teknoloji **MQTT sunucusu**: Node.js broker, web panel, kullanıcı/parola, Fail2Ban benzeri IP koruması. NetRelay kartları ve NetRelayMP (mPower) cihazları bu broker’a bağlanır.

**Ne sağlar**

- MQTT dinleyici (varsayılan **31883**, TLS varsa **38883**)
- Web panel **8082** — bağlı cihazlar, log, blacklist, test
- `users.json` ile MQTT kullanıcıları
- Docker: `ghcr.io/mlteknoloji/mqttserver:latest`

Kurulum özeti: [mqttserver README](https://github.com/mlteknoloji/mqttserver)

```powershell
git clone https://github.com/mlteknoloji/mqttserver.git
cd mqttserver
npm install
# .env ve users.json oluşturun; sonra:
npm start
```

Panel: `http://SUNUCU-IP:8082` · Broker: `mqtt://SUNUCU-IP:31883`

## Birlikte kullanım

1. PC / NAS / sunucuda **mqttserver** çalıştırın; güvenlik duvarında **31883** açık olsun.
2. `users.json` içine cihazın kullanacağı kullanıcı/parola yazın.
3. mPower topic’leri `mpower/mltek/{MAC}/` olduğu için mqttserver `.env` içinde **`MQTT_TOPIC_ENFORCEMENT=0`** yapın (varsayılan `1` yalnız `netrelay/…` topic’lerine izin verir).
4. Cihazda **Ayarlar → MQTT**:
   - açık
   - host = mqttserver’ın IP’si
   - port = **31883** (1883 değil)
   - user / pass = `users.json` kaydı
   - prefix = `mpower/mltek`
   - isteğe HA discovery
5. Kaydet; sağlıkta `mqtt_running=1` olsun. Panel veya `mosquitto_sub -p 31883 -t 'mpower/mltek/#' -v` ile doğrulayın.

Komutlar ve topic’ler: [MQTT-TR.md](MQTT-TR.md)

## Satın alma

mFi mPower donanımı: [SATIN-AL-TR.md](SATIN-AL-TR.md)

- https://wifidepo.com/ubnt-mpower-521
- https://wifianten.com/ubnt-mpower-335
