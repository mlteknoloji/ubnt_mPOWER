# MQTT Dokümantasyonu (Türkçe)

mPower Standalone Overlay, broker’a **JSON telemetri** basar ve broker’dan **röle / pulse / firmware** komutları alır.

Cihaz MQTT **istemcisidir**. Broker ayrıdır. Önerilen: [mqttserver](https://github.com/mlteknoloji/mqttserver) (`31883` / panel `8082`). Depolar: [DEPOSLAR-TR.md](DEPOSLAR-TR.md) · cihaz overlay: [ubnt_mPOWER](https://github.com/mlteknoloji/ubnt_mPOWER).

Ekran görüntüleri ve panel/zamanlama/ping: [OZELLIKLER-TR.md](OZELLIKLER-TR.md)

## Kurulum (cihaz)

![MQTT ayarları](../standalone-firmware/brochure/software_tr_mqtt.png)

1. `http://CIHAZ-IP:8088` → giriş (`admin` / `mltek`)
2. **Ayarlar → MQTT**
3. Broker host, port (`1883`), kullanıcı/parola (varsa)
4. Prefix (varsayılan `mpower`), yayın aralığı (sn)
5. İsteğe bağlı: **HA discovery**
6. **MQTT kaydet**

Cihaz adı (opsiyonel): **Ayarlar → Cihaz adı**  
MAC adresi topic’lerde kullanılır (ör. `24a43cd75475`).

Durum JSON’da MAC’i görmek için:

```text
http://CIHAZ-IP:8088/cgi-bin/status.sh
```

## Topic yapısı

`{prefix}` varsayılan: `mpower`  
`{MAC}` örnek: `24a43cd75475`

### Telemetri (cihaz → broker)

| Topic | Retain | Açıklama |
|-------|--------|----------|
| `{prefix}/{MAC}/state` | evet | Tüm cihaz durumu (tek JSON) |
| `{prefix}/{MAC}/relay/{1-3}` | evet | `ON` / `OFF` |
| `{prefix}/{MAC}/outlet/{n}/watt` | hayır | Anlık güç (W) |
| `{prefix}/{MAC}/outlet/{n}/volt` | hayır | Voltaj (V) |
| `{prefix}/{MAC}/outlet/{n}/amp` | hayır | Akım (A) |
| `{prefix}/{MAC}/outlet/{n}/json` | hayır | Priz JSON özeti |

#### `state` örneği

```json
{
  "mac": "24a43cd75475",
  "hostname": "mFi-mPower-D65475",
  "name": "salon-pdu",
  "firmware": "MF.v2.1.11",
  "overlay": "1.2.0",
  "ip": "192.168.1.50",
  "ssid": "EvWifi",
  "uptime": 3600,
  "now": "2026-08-10 21:00:00",
  "outlets": [
    {"port": 1, "relay": 1, "watt": 12.3, "wh": 1.2, "volt": 230.1, "amp": 0.05, "pf": 0.9},
    {"port": 2, "relay": 0, "watt": 0.0, "wh": 0.0, "volt": 0.0, "amp": 0.0, "pf": 0.0},
    {"port": 3, "relay": 1, "watt": 5.1, "wh": 0.4, "volt": 229.8, "amp": 0.02, "pf": 0.8}
  ]
}
```

### Komutlar (broker → cihaz)

#### 1) Ana komut topic’i

`{prefix}/{MAC}/cmd`

| Komut | JSON |
|-------|------|
| Aç | `{"action":"on","port":1}` |
| Kapat | `{"action":"off","port":2}` |
| Tümü | `{"action":"on","port":"all"}` |
| Pulse (X sn sonra eski konum) | `{"action":"pulse","port":1,"delay":10,"to":1}` |
| Cycle (kapat → bekle → eski) | `{"action":"cycle","port":1,"delay":10}` |
| Firmware (overlay tar URL) | `{"action":"update","url":"http://192.168.1.10/pkg.tar"}` |

- `port`: `1`, `2`, `3` veya `all`  
- `delay`: saniye (pulse/cycle)  
- `to`: pulse hedefi `0` veya `1` (boşsa mevcut durumun tersi)

#### 2) Home Assistant uyumlu set

`{prefix}/{MAC}/relay/{n}/set`

Payload: `ON` veya `OFF`  
`{prefix}/{MAC}/relay/all/set` → tüm prizler

## mosquitto örnekleri

Dinle:

```bat
mosquitto_sub -h 192.168.1.10 -t "mpower/24a43cd75475/#" -v
```

Röle 1 aç:

```bat
mosquitto_pub -h 192.168.1.10 -t "mpower/24a43cd75475/cmd" -m "{\"action\":\"on\",\"port\":1}"
```

10 sn pulse (1 konumuna al, sonra eskiye dön):

```bat
mosquitto_pub -h 192.168.1.10 -t "mpower/24a43cd75475/cmd" -m "{\"action\":\"pulse\",\"port\":1,\"delay\":10,\"to\":1}"
```

HA set:

```bat
mosquitto_pub -h 192.168.1.10 -t "mpower/24a43cd75475/relay/1/set" -m "OFF"
```

## Home Assistant

1. Cihazda **HA discovery** açık olsun.  
2. HA MQTT entegrasyonu aynı broker’ı kullansın.  
3. Switch + güç/voltaj sensörleri otomatik görünebilir.  
4. Komut için discovery `cmd_t` veya REST de kullanılabilir.

REST alternatifi:

```http
POST http://CIHAZ-IP:8088/cgi-bin/action.sh?port=1&state=on&token=TOKEN
```

## Notlar / sınırlar

- Broker TCP **1883** (veya ayarladığınız port) cihaza açık olmalı.
- İstemci BusyBox `nc` + shell MQTT 3.1.1 kullanır; QoS 0.
- Overlay flash güncellemesi URL ile yapılır; resmi Ubiquiti `.bin` değildir.
- Saat senkron değilse zamanlama etkilenir; MQTT anlık komutlar yine çalışır.
