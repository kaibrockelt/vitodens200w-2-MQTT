#!/bin/bash
# MQTT Discovery Messages für Home Assistant
# Einmalig ausführen - HA erkennt die Sensoren danach automatisch
#
# Ausführen auf dem Pi:
#   bash /home/kai/heizhorst-deploy/mqtt_discovery.sh

MQTT_HOST="${MQTTHOST:-192.168.178.37}"
MQTT_PORT="${MQTTPORT:-1883}"
DISCOVERY_PREFIX="homeassistant"
DEVICE_ID="vitodens200w"
DEVICE_NAME="Vitodens 200W"

echo "Publishing MQTT Discovery messages to ${MQTT_HOST}:${MQTT_PORT}..."

publish_sensor() {
  # publish_sensor "Name" "command" "unit" "device_class" ["state_class"]
  # state_class: Standard "measurement", wenn device_class gesetzt ist; sonst nur wenn angegeben
  local name="$1"
  local command="$2"
  local unit="$3"
  local device_class="$4"
  local state_class="${5:-}"
  if [ -z "$state_class" ] && [ -n "$device_class" ]; then
    state_class="measurement"
  fi
  local unique_id="${DEVICE_ID}_${command}"
  local topic="${DISCOVERY_PREFIX}/sensor/${DEVICE_ID}/${command}/config"

  local extra=""
  [ -n "$unit" ]         && extra="${extra}  \"unit_of_measurement\": \"${unit}\",\n"
  [ -n "$device_class" ] && extra="${extra}  \"device_class\": \"${device_class}\",\n"
  [ -n "$state_class" ]  && extra="${extra}  \"state_class\": \"${state_class}\",\n"

  local payload
  payload=$(printf '{\n  "name": "%s",\n  "state_topic": "heizung/%s",\n  "value_template": "{{ value_json.value | round(1) }}",\n%b  "unique_id": "%s",\n  "device": {\n    "identifiers": ["%s"],\n    "name": "%s",\n    "model": "Vitodens 200W",\n    "manufacturer": "Viessmann"\n  }\n}' \
    "$name" "$command" "$extra" "$unique_id" "$DEVICE_ID" "$DEVICE_NAME")

  mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" \
    -t "$topic" \
    -m "$payload" \
    -r  # retain flag damit HA es auch nach Neustart kennt

  echo "  ✓ ${name} -> ${topic}"
}

remove_sensor() {
  # Leere retained Discovery-Message -> HA entfernt die Entität
  local command="$1"
  local topic="${DISCOVERY_PREFIX}/sensor/${DEVICE_ID}/${command}/config"
  mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "$topic" -n -r
  echo "  ✗ entfernt: ${command}"
}

# Temperatursensoren
publish_sensor "Außentemperatur"        "getTempA"      "°C" "temperature"
publish_sensor "Kesseltemperatur"       "getTempKessel" "°C" "temperature"
publish_sensor "Rücklauftemperatur"     "getTempRL"     "°C" "temperature"
publish_sensor "Warmwassertemperatur"   "getTempWW"     "°C" "temperature"
publish_sensor "WW-Solltemperatur"      "getTempWWsoll" "°C" "temperature"

# Heizkurve / Brenner (ergänzt 24.11.2026)
publish_sensor "Vorlauf-Soll HK1"       "getTempVLsollHK1"   "°C" "temperature"
publish_sensor "Neigung HK1"            "getNeigungHK1"      ""   ""
publish_sensor "Niveau HK1"             "getNiveauHK1"       "K"  ""
publish_sensor "Brennerstarts"          "getBrennerStarts"   ""   ""         "total_increasing"
publish_sensor "Brennerstunden"         "getBrennerStunden"  "h"  "duration" "total_increasing"
publish_sensor "Brennerleistung"        "getBrennerLeistung" "%"  ""         "measurement"

# Entfernt (24.11.2026): getTempVL war nur ein Alias auf die Kesseltemperatur
remove_sensor "getTempVL"

# Pumpen
publish_sensor "Speicherladepumpe"      "getPumpeStatusSp"     "" ""
publish_sensor "Zirkulationspumpe"      "getPumpeStatusZirku"  "" ""
publish_sensor "Interne Pumpe"          "getPumpeStatusIntern" "" ""

# Status
publish_sensor "Betriebsart HK1"        "getBetriebArtHK1"   "" ""
publish_sensor "Störungsstatus"         "getStatusStoerung"  "" ""

echo ""
echo "Fertig! Sensoren sollten jetzt in HA unter Einstellungen → Geräte & Dienste → MQTT erscheinen."
echo "Gerät: '${DEVICE_NAME}'"
