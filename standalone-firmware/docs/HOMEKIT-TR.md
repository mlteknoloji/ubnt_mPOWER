# NetRelayMP → Apple Home (HomeKit)

mPower üzerinde **doğrudan HomeKit yok**. Apple Ev / Siri için köprü gerekir:

1. **Home Assistant HomeKit Bridge** (önerilen — MQTT zaten var)
2. **Homebridge** + MQTT eklentisi

Cihaz tarafı: **Ayarlar → MQTT** açık, broker erişilebilir, `ha_discovery` işaretli (HA yolu için). Önerilen broker: [mqttserver](https://github.com/mlteknoloji/mqttserver). Overlay: [ubnt_mPOWER](https://github.com/mlteknoloji/ubnt_mPOWER).

MAC örneği: `24a43cd75475` (küçük harf, `:` yok). Kendi MAC’iniz: panel altı veya `cat` ile cihazdan / Ayarlar.

Prefix varsayılan: `mpower`.

---

## 1) Home Assistant → Apple Home

### Adımlar

1. NetRelayMP MQTT’yi HA’nın broker’ına bağlayın (`ha_discovery=1`).
2. HA → **Ayarlar → Cihazlar ve hizmetler**: `NetRelayMP` / priz switch’leri görünmeli.
3. HA → **Ayarlar → Cihazlar ve hizmetler → Ekle → HomeKit Bridge**.
4. Dahil edilecek domain: en azından `switch` (isteğe `sensor`).
5. Ev uygulamasında **Aksesuar ekle → Daha fazla seçenek → Kod** ile HA’nın verdiği PIN’i girin.

### configuration.yaml (manuel HomeKit Bridge örneği)

```yaml
# MQTT genelde UI’dan eklenir; discovery açıksa entity’ler otomatik gelir.

homekit:
  - name: NetRelayMP Bridge
    port: 21063
    filter:
      include_domains:
        - switch
      # İsteğe bağlı: sadece bu cihazlar
      # include_entities:
      #   - switch.netrelaymp_r1
      #   - switch.netrelaymp_r2
      #   - switch.netrelaymp_r3
```

Entity isimleri HA discovery’ye göre değişebilir (`switch.*_r1` vb.). HA UI’da Cihazlar listesinden doğrulayın.

### Birden fazla cihaz

Tek HA + tek MQTT broker yeter. Her mPower ayrı MAC ile discovery yayınlar; HomeKit Bridge’de `switch` domain’ini açın veya alan/etiket ile filtreleyin. Apple Home’da bir köprüde aksesuar limiti vardır (~150); çok sayıda priz için birden fazla HomeKit Bridge entegrasyonu (farklı `port` / `name`) kullanın.

---

## 2) Homebridge (HA yoksa)

Gereken: her zaman açık bir host (Raspberry Pi, NAS, PC) + MQTT broker + [Homebridge](https://homebridge.io).

### Plugin

Örnek: `homebridge-mqttthing` veya halefi `homebridge-mqttthing-ex` / `homebridge-easy-mqtt`.

Aşağıdaki örnek **mqttthing** tarzı outlet (ON/OFF) içindir.

### config.json (3 priz)

`BROKER`, `USER`, `PASS`, `MAC` değerlerini değiştirin.

```json
{
  "bridge": {
    "name": "NetRelayMP Homebridge",
    "username": "CC:22:3D:E3:CE:30",
    "port": 51826,
    "pin": "031-45-154"
  },
  "accessories": [
    {
      "accessory": "mqttthing",
      "type": "outlet",
      "name": "NetRelay Priz 1",
      "url": "mqtt://BROKER:1883",
      "username": "USER",
      "password": "PASS",
      "topics": {
        "getOn": "mpower/MAC/relay/1",
        "setOn": "mpower/MAC/relay/1/set"
      },
      "onValue": "ON",
      "offValue": "OFF"
    },
    {
      "accessory": "mqttthing",
      "type": "outlet",
      "name": "NetRelay Priz 2",
      "url": "mqtt://BROKER:1883",
      "username": "USER",
      "password": "PASS",
      "topics": {
        "getOn": "mpower/MAC/relay/2",
        "setOn": "mpower/MAC/relay/2/set"
      },
      "onValue": "ON",
      "offValue": "OFF"
    },
    {
      "accessory": "mqttthing",
      "type": "outlet",
      "name": "NetRelay Priz 3",
      "url": "mqtt://BROKER:1883",
      "username": "USER",
      "password": "PASS",
      "topics": {
        "getOn": "mpower/MAC/relay/3",
        "setOn": "mpower/MAC/relay/3/set"
      },
      "onValue": "ON",
      "offValue": "OFF"
    }
  ]
}
```

`MAC` yerine gerçek değer: örn. `24a43cd75475` → topic `mpower/24a43cd75475/relay/1`.

### homebridge-mqttswitch (alternatif)

```json
{
  "accessory": "mqttswitch",
  "name": "NetRelay Priz 1",
  "url": "mqtt://BROKER:1883",
  "username": "USER",
  "password": "PASS",
  "caption": "Priz 1",
  "topics": {
    "statusGet": "mpower/MAC/relay/1",
    "statusSet": "mpower/MAC/relay/1/set"
  },
  "onValue": "ON",
  "offValue": "OFF"
}
```

### Ev uygulamasına ekleme

Homebridge QR / PIN ile **Aksesuar ekle**. iPhone ile Homebridge aynı LAN’da olmalı (mDNS).

### Birden fazla cihaz

Her mPower için 3 outlet bloğu kopyalayın; `MAC` ve `name` değiştirin. Veya platform tipi plugin kullanıp `devices[]` listesi tutun.

---

## Topic özeti (HomeKit köprüsü için)

| Amaç | Topic | Payload |
|------|--------|---------|
| Durum oku | `mpower/{MAC}/relay/{1\|2\|3}` | `ON` / `OFF` (retain) |
| Komut yaz | `mpower/{MAC}/relay/{1\|2\|3}/set` | `ON` / `OFF` |
| JSON komut | `mpower/{MAC}/cmd` | `{"action":"on","port":1}` |
| Tam durum | `mpower/{MAC}/state` | JSON |

Detay: [MQTT-TR.md](MQTT-TR.md)

---

## Sorun giderme

| Belirti | Kontrol |
|--------|---------|
| HA’da cihaz yok | MQTT broker, `enabled=1`, `ha_discovery=1`, saat/NTP, aynı VLAN |
| Home’da “yanıt vermiyor” | iPhone ↔ köprü aynı Wi‑Fi; misafir/AP izolasyonu kapalı; mDNS |
| Aç/kapa gitmiyor | `mosquitto_sub -t 'mpower/#' -v` ile set topic’i izle |
| Yanlış MAC | MQTT `state` içindeki `mac` veya UDP 5555 yayını |

---

## Ne yapılmaz

Cihaza native HomeKit (HAP) binary eklemeyin: RAM (~29 MB) ve flash yetersiz; MFi yok. Köprü modeli filo için doğru çözümdür.

EN: [HOMEKIT-EN.md](HOMEKIT-EN.md)
