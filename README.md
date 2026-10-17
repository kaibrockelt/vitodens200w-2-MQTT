# ProjektHeizhorst

Lokale Anbindung einer Viessmann Vitodens 200W Gastherme an Home Assistant via MQTT – ohne Cloud, ohne Vitoconnect-App.

## Basiert auf

Dieses Projekt ist eine Anpassung und Konfiguration auf Basis von:

- **[michelde/openv-vcontrold-docker](https://github.com/michelde/openv-vcontrold-docker)** – Docker-Image mit vcontrold Daemon und MQTT-Publisher. Die eigentliche Arbeit liegt dort.
- **[openv/vcontrold](https://github.com/openv/vcontrold)** – vcontrold Daemon, Basis für alles.
- **[openv/openv Wiki](https://github.com/openv/openv/wiki)** – Protokoll-Dokumentation und Community-Wissen.
- **[philippoo66/ViessData21](https://github.com/philippoo66/ViessData21)** – Datenpunktlisten, entscheidend für die korrekten Adressen.

Dieses Repo enthält ausschließlich die lokale Konfiguration für meine spezifische Anlage.

---

## Meine Anlage

| | |
|---|---|
| Heizung | Viessmann Vitodens 200W, Baujahr 2018 |
| Regelung | Vitotronic 200 HO1B |
| Device-ID | `20 CB 28 CB 00 00 01 0A` (VScotHO1-Variante) |
| Protokoll | P300 |
| Adapter | Vitoconnect 100 USB-Optik-Kabel (Silicon Labs CP2102) |
| Hardware | Raspberry Pi Zero 2W |

---

## Wichtigste Erkenntnis für diese Anlage

Die Vitodens 200W mit Device-ID `20CB 28CB` nutzt für Temperaturen den Adressbereich **`0x0800` ff**, nicht `0x0101` wie in den meisten Beispiel-Configs im Internet. Ohne diese Information antwortet die Heizung auf alle Standard-Befehle mit Fehlercode `03` (Adresse unbekannt).

Quelle: [philippoo66/ViessData21 README](https://github.com/philippoo66/ViessData21#dp_listen_2zip)

---

## Funktionsweise

```
Vitodens 200W
  → Optische Schnittstelle (P300)
  → Vitoconnect USB-Kabel (CP2102)
  → Raspberry Pi Zero 2W "heizhorst"
  → Docker: vcontrold Container
  → MQTT (JSON) alle 60 Sekunden
  → Mosquitto auf Home Assistant Host
  → HA Sensoren via MQTT Discovery
```

---

## Ausgelesene Datenpunkte

| Befehl | Adresse | Beschreibung |
|--------|---------|--------------|
| `getTempA` | `0800` | Außentemperatur |
| `getTempKessel` | `0802` | Kesseltemperatur |
| `getTempVL` | `0804` | Vorlauftemperatur |
| `getTempRL` | `083E` | Rücklauftemperatur (nicht im Heizungsmenü sichtbar, Backup-Kandidat: `0842`) |
| `getTempWW` | `0808` | Warmwassertemperatur |
| `getTempAbgas` | `0810` | Abgastemperatur |
| `getBetriebArtHK1` | `B000` | Betriebsart (0=Aus, 1=WW, 2=Heizen+WW) |
| `getStatusStoerung` | `0A82` | Störungsstatus (0=OK, 1=Störung) |

> **Hinweis:** Die Adressen `0806` (RL) und `080A` (Abgas) liefern bei dieser Anlage immer 20°C und sind **nicht** nutzbar. Die korrekten Adressen wurden durch systematischen Scan am 17.10.2026 ermittelt.

---

## Setup

### Voraussetzungen
- Raspberry Pi mit Docker
- Mosquitto MQTT-Broker erreichbar im Netz
- Home Assistant mit MQTT-Integration (UI)

### Konfiguration

`.env` anlegen (nicht im Repo):
```bash
cp .env.example .env  # falls vorhanden, sonst manuell
```

```env
MQTTACTIVE=true
MQTTHOST=192.168.178.37
MQTTPORT=1883
MQTTTOPIC=heizung/
MQTTUSER=
MQTTPASSWORD=
INTERVAL=60
COMMANDS=getTempA,getTempKessel,getTempVL,getTempRL,getTempWW,getTempAbgas,getBetriebArtHK1,getStatusStoerung
```

USB-Device-Pfad in `docker-compose.yml` ggf. anpassen:
```yaml
devices:
  - /dev/serial/by-id/usb-Silicon_Labs_CP2102_...-if00-port0:/dev/vitocal:rwm
```

### Starten

```bash
docker compose up -d
docker compose logs -f
```

### Home Assistant Discovery (einmalig)

```bash
docker cp mqtt_discovery.sh vcontrold:/tmp/
docker exec -it vcontrold bash /tmp/mqtt_discovery.sh
```

Danach erscheint in HA unter **Einstellungen → Geräte & Dienste → MQTT** das Gerät "Vitodens 200W".

---

## Lizenz

Eigene Konfigurationsdateien: MIT  
Verwendete Projekte haben ihre eigenen Lizenzen – siehe jeweilige Repos.
