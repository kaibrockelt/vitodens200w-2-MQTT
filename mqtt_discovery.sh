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
  local name="$1"
  local command="$2"
  local unit="$3"
  local device_class="$4"
  local unique_id="${DEVICE_ID}_${command}"
  local topic="${DISCOVERY_PREFIX}/sensor/${DEVICE_ID}/${command}/config"

  local payload
  if [ -n "$device_class" ]; then
    payload=$(cat <<EOF
{
  "name": "${name}",
  "state_topic": "heizung/${command}",
  "value_template": "{{ value_json.value | round(1) }}",
  "unit_of_measurement": "${unit}",
  "device_class": "${device_class}",
  "state_class": "measurement",
  "unique_id": "${unique_id}",
  "device": {
    "identifiers": ["${DEVICE_ID}"],
    "name": "${DEVICE_NAME}",
    "model": "Vitodens 200W",
    "manufacturer": "Viessmann"
  }
}
EOF
)
  else
    payload=$(cat <<EOF
{
  "name": "${name}",
  "state_topic": "heizung/${command}",
  "value_template": "{{ value_json.value | round(1) }}",
  "unique_id": "${unique_id}",
  "device": {
    "identifiers": ["${DEVICE_ID}"],
    "name": "${DEVICE_NAME}",
    "model": "Vitodens 200W",
    "manufacturer": "Viessmann"
  }
}
EOF
)
  fi

  mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" \
    -t "$topic" \
    -m "$payload" \
    -r  # retain flag damit HA es auch nach Neustart kennt

  echo "  ✓ ${name} -> ${topic}"
}

# Temperatursensoren
publish_sensor "Außentemperatur"      "getTempA"      "°C" "temperature"
publish_sensor "Kesseltemperatur"     "getTempKessel" "°C" "temperature"
publish_sensor "Vorlauftemperatur"    "getTempVL"     "°C" "temperature"
publish_sensor "Rücklauftemperatur"   "getTempRL"     "°C" "temperature"
publish_sensor "Warmwassertemperatur" "getTempWW"     "°C" "temperature"
publish_sensor "Abgastemperatur"      "getTempAbgas"  "°C" "temperature"

# Status
publish_sensor "Betriebsart HK1"     "getBetriebArtHK1"    "" ""
publish_sensor "Störungsstatus"       "getStatusStoerung"   "" ""

echo ""
echo "Fertig! Sensoren sollten jetzt in HA unter Einstellungen → Geräte & Dienste → MQTT erscheinen."
echo "Gerät: '${DEVICE_NAME}'"
