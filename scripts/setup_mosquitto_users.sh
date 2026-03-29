#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
#  Setup: cria usuários no Mosquitto (ESP32 + Node-RED)
#  Uso: bash scripts/setup_mosquitto_users.sh
#  Pré-requisito: .env preenchido e Docker rodando
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

if [ ! -f .env ]; then
    echo "❌ Arquivo .env não encontrado. Copie .env.example → .env e preencha."
    exit 1
fi

source .env

PASSWD_FILE="./mosquitto/config/passwd"

echo "🔑 Criando usuário ESP32: ${MQTT_ESP32_USER}"
docker run --rm \
    -v "$(pwd)/mosquitto/config:/mosquitto/config" \
    eclipse-mosquitto:2.0 \
    mosquitto_passwd -b /mosquitto/config/passwd "${MQTT_ESP32_USER}" "${MQTT_ESP32_PASSWORD}"

echo "🔑 Criando usuário Node-RED: ${MQTT_NODERED_USER}"
docker run --rm \
    -v "$(pwd)/mosquitto/config:/mosquitto/config" \
    eclipse-mosquitto:2.0 \
    mosquitto_passwd -b /mosquitto/config/passwd "${MQTT_NODERED_USER}" "${MQTT_NODERED_PASSWORD}"

echo "✅ Usuários criados em ${PASSWD_FILE}"
echo "   Reinicie o Mosquitto: docker compose restart mosquitto"
