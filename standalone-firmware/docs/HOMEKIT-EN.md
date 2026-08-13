# NetRelayMP → Apple Home (HomeKit)

There is **no native HomeKit** on the mPower. Use a bridge:

1. **Home Assistant HomeKit Bridge** (recommended if you already use MQTT/HA)
2. **Homebridge** + MQTT plugin

On the device: enable **Settings → MQTT**, reachable broker, `ha_discovery` on (for HA path). Recommended broker: [mqttserver](https://github.com/mlteknoloji/mqttserver). Overlay: [ubnt_mPOWER](https://github.com/mlteknoloji/ubnt_mPOWER).

MAC example: `24a43cd75475` (lowercase, no colons). Prefix default: `mpower`.

---

## 1) Home Assistant → Apple Home

1. Point NetRelayMP MQTT at the HA broker (`ha_discovery=1`).
2. Confirm switches appear under HA **Devices**.
3. **Settings → Devices & services → Add → HomeKit Bridge**.
4. Include at least the `switch` domain.
5. In the Home app: **Add Accessory → More options** and enter the HA PIN.

### configuration.yaml example

```yaml
homekit:
  - name: NetRelayMP Bridge
    port: 21063
    filter:
      include_domains:
        - switch
```

For many devices, use multiple HomeKit Bridge instances (accessory limits apply in Apple Home).

---

## 2) Homebridge

Host must stay online (Pi/NAS/PC) with MQTT broker + [Homebridge](https://homebridge.io).

### mqttthing-style outlets

Replace `BROKER`, `USER`, `PASS`, `MAC`:

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
      "name": "NetRelay Outlet 1",
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
      "name": "NetRelay Outlet 2",
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
      "name": "NetRelay Outlet 3",
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

### Topic cheat sheet

| Role | Topic | Payload |
|------|--------|---------|
| State | `mpower/{MAC}/relay/N` | `ON` / `OFF` |
| Command | `mpower/{MAC}/relay/N/set` | `ON` / `OFF` |
| JSON cmd | `mpower/{MAC}/cmd` | `{"action":"on","port":1}` |

See [MQTT-EN.md](MQTT-EN.md).

TR: [HOMEKIT-TR.md](HOMEKIT-TR.md)
