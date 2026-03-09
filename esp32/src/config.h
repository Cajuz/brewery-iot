#pragma once

// ── Rede ─────────────────────────────────────────────
#define WIFI_SSID        "NOME_DO_HOTSPOT"
#define WIFI_PASSWORD    "SENHA_HOTSPOT"

// ── MQTT ─────────────────────────────────────────────
#define MQTT_BROKER      "192.168.137.1"
#define MQTT_PORT        1883
#define MQTT_CLIENT_ID   "esp32-brewery-01"
#define TOPIC_SENSORS    "brewery/sensors"

// ── Pinos ─────────────────────────────────────────────
#define DHT_PIN          4
#define DHT_TYPE         DHT22
#define FLOW_PIN         5

// ── Processo ──────────────────────────────────────────
#define PUBLISH_INTERVAL_MS  5000
#define FLOW_PULSES_PER_L    450.0f
#define STAGE                "fermentacao"

// ── Serial ────────────────────────────────────────────
#define SERIAL_BAUD      115200
