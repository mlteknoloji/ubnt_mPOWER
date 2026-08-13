# Related GitHub repositories

NetRelayMP is two repos: **device overlay** and **MQTT broker**.

| Repo | URL | What it is for |
|------|-----|----------------|
| **ubnt_mPOWER** | https://github.com/mlteknoloji/ubnt_mPOWER | Overlay installed on the mFi mPower (this repo) |
| **mqttserver** | https://github.com/mlteknoloji/mqttserver | LAN MQTT broker + web admin panel |

## ubnt_mPOWER — device overlay

https://github.com/mlteknoloji/ubnt_mPOWER

**NetRelayMP** software for Ubiquiti mFi mPower (**MF.v2.1.11**). Not an official `.bin`; it lives under `/etc/persistent`. Stock UI stays on `:8080`.

**Provides**

- Web UI `http://DEVICE-IP:8088` (TR/EN) · login `admin` / `mltek`
- Three outlets: on / off / pulse / cycle · power / energy
- MQTT **client** (connects to a broker, topics `mpower/mltek/{MAC}/`)
- REST API, schedules, ping watch, JSON backup, overlay update

Install: [KURULUM-EN.md](KURULUM-EN.md)

## mqttserver — MQTT broker

https://github.com/mlteknoloji/mqttserver

ML Teknoloji **MQTT server**: Node.js broker, web panel, username/password, Fail2Ban-style IP protection. NetRelay boards and NetRelayMP (mPower) units connect here.

**Provides**

- MQTT listener (default **31883**, TLS **38883** if enabled)
- Web panel **8082** — live devices, logs, blacklist, test client
- MQTT users in `users.json`
- Docker: `ghcr.io/mlteknoloji/mqttserver:latest`

See [mqttserver README](https://github.com/mlteknoloji/mqttserver).

```powershell
git clone https://github.com/mlteknoloji/mqttserver.git
cd mqttserver
npm install
# create .env and users.json, then:
npm start
```

Panel: `http://SERVER-IP:8082` · Broker: `mqtt://SERVER-IP:31883`

## Using them together

1. Run **mqttserver** on a PC / NAS / server; allow **31883** on the firewall.
2. Add the device username/password in `users.json`.
3. mPower topics are `mpower/mltek/{MAC}/`, so set **`MQTT_TOPIC_ENFORCEMENT=0`** in mqttserver `.env` (default `1` only allows `netrelay/…`).
4. On the device **Settings → MQTT**:
   - enabled
   - host = mqttserver IP
   - port = **31883** (not 1883)
   - user / pass = `users.json` entry
   - prefix = `mpower/mltek`
   - optional HA discovery
5. Save; health should show `mqtt_running=1`. Confirm in the panel or with `mosquitto_sub -p 31883 -t 'mpower/mltek/#' -v`.

Topics and commands: [MQTT-EN.md](MQTT-EN.md)

## Buy hardware

mFi mPower: [BUY-EN.md](BUY-EN.md)

- https://wifidepo.com/ubnt-mpower-521
- https://wifianten.com/ubnt-mpower-335
