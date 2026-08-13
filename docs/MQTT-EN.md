# MQTT Documentation (English)

The mPower Standalone Overlay publishes **JSON telemetry** to your broker and accepts **relay / pulse / firmware** commands from the broker.

The device is an MQTT **client**. The broker is separate. Recommended: [mqttserver](https://github.com/mlteknoloji/mqttserver) (`31883` / panel `8082`). Repos: [REPOS-EN.md](REPOS-EN.md) · device overlay: [ubnt_mPOWER](https://github.com/mlteknoloji/ubnt_mPOWER).

Screenshots (dashboard, schedule, ping): [FEATURES-EN.md](FEATURES-EN.md)

## Device setup

![MQTT settings](../standalone-firmware/brochure/software_en_mqtt.png)

1. Open `http://DEVICE-IP:8088` and sign in (`admin` / `mltek`)
2. Go to **Settings → MQTT**
3. Enter broker host, port (`1883`), username/password if required
4. Prefix (default `mpower`), publish interval (seconds)
5. Optional: **HA discovery**
6. Click **Save MQTT**

Optional friendly name: **Settings → Device name**  
Topics use the device **MAC** (example `24a43cd75475`).

Read MAC from:

```text
http://DEVICE-IP:8088/cgi-bin/status.sh
```

## Topic layout

`{prefix}` default: `mpower`  
`{MAC}` example: `24a43cd75475`

### Telemetry (device → broker)

| Topic | Retain | Description |
|-------|--------|-------------|
| `{prefix}/{MAC}/state` | yes | Full device JSON |
| `{prefix}/{MAC}/relay/{1-3}` | yes | `ON` / `OFF` |
| `{prefix}/{MAC}/outlet/{n}/watt` | no | Power (W) |
| `{prefix}/{MAC}/outlet/{n}/volt` | no | Voltage (V) |
| `{prefix}/{MAC}/outlet/{n}/amp` | no | Current (A) |
| `{prefix}/{MAC}/outlet/{n}/json` | no | Per-outlet JSON |

#### Example `state` payload

```json
{
  "mac": "24a43cd75475",
  "hostname": "mFi-mPower-D65475",
  "name": "living-room-pdu",
  "firmware": "MF.v2.1.11",
  "overlay": "1.2.0",
  "ip": "192.168.1.50",
  "ssid": "HomeWifi",
  "uptime": 3600,
  "now": "2026-08-10 21:00:00",
  "outlets": [
    {"port": 1, "relay": 1, "watt": 12.3, "wh": 1.2, "volt": 230.1, "amp": 0.05, "pf": 0.9},
    {"port": 2, "relay": 0, "watt": 0.0, "wh": 0.0, "volt": 0.0, "amp": 0.0, "pf": 0.0},
    {"port": 3, "relay": 1, "watt": 5.1, "wh": 0.4, "volt": 229.8, "amp": 0.02, "pf": 0.8}
  ]
}
```

### Commands (broker → device)

#### 1) Primary command topic

`{prefix}/{MAC}/cmd`

| Action | JSON |
|--------|------|
| Turn on | `{"action":"on","port":1}` |
| Turn off | `{"action":"off","port":2}` |
| All ports | `{"action":"on","port":"all"}` |
| Pulse (restore after X s) | `{"action":"pulse","port":1,"delay":10,"to":1}` |
| Cycle (off → wait → restore) | `{"action":"cycle","port":1,"delay":10}` |
| Overlay update from URL | `{"action":"update","url":"http://192.168.1.10/pkg.tar"}` |

- `port`: `1`, `2`, `3`, or `all`  
- `delay`: seconds for pulse/cycle  
- `to`: pulse target `0` or `1` (omit to flip)

#### 2) Home Assistant compatible set topics

`{prefix}/{MAC}/relay/{n}/set`

Payload: `ON` or `OFF`  
`{prefix}/{MAC}/relay/all/set` affects all outlets.

## mosquitto examples

Subscribe:

```bat
mosquitto_sub -h 192.168.1.10 -t "mpower/24a43cd75475/#" -v
```

Turn relay 1 on:

```bat
mosquitto_pub -h 192.168.1.10 -t "mpower/24a43cd75475/cmd" -m "{\"action\":\"on\",\"port\":1}"
```

Pulse for 10 seconds then restore:

```bat
mosquitto_pub -h 192.168.1.10 -t "mpower/24a43cd75475/cmd" -m "{\"action\":\"pulse\",\"port\":1,\"delay\":10,\"to\":1}"
```

HA-style set:

```bat
mosquitto_pub -h 192.168.1.10 -t "mpower/24a43cd75475/relay/1/set" -m "OFF"
```

## Home Assistant

1. Enable **HA discovery** on the device.  
2. Point HA MQTT integration at the same broker.  
3. Switches and power/voltage sensors may appear automatically.  
4. You can also control via REST.

REST example:

```http
POST http://DEVICE-IP:8088/cgi-bin/action.sh?port=1&state=on&token=TOKEN
```

## Notes / limits

- Broker TCP **1883** (or your configured port) must be reachable from the device.
- Client uses BusyBox `nc` + shell MQTT 3.1.1; QoS 0.
- Firmware update over MQTT installs the overlay tarball URL — not an official Ubiquiti `.bin`.
- Schedules need NTP; live MQTT commands still work without a correct clock.
