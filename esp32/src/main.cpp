#include <WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <ArduinoJson.h>
#include "config.h"

// ── Objetos ───────────────────────────────────────────
DHT          dht(DHT_PIN, DHT_TYPE);
WiFiClient   espClient;
PubSubClient mqtt(espClient);

// ── Sensor de fluxo ───────────────────────────────────
volatile uint32_t pulseCount = 0;
float totalLiters = 0.0f;

void IRAM_ATTR onFlowPulse() { pulseCount++; }

// ══════════════════════════════════════════════════════
// LOGGER
// ══════════════════════════════════════════════════════
void logInfo(const String& msg)  { Serial.println("[INFO]  " + msg); }
void logWarn(const String& msg)  { Serial.println("[WARN]  " + msg); }
void logError(const String& msg) { Serial.println("[ERROR] " + msg); }

// ══════════════════════════════════════════════════════
// WIFI
// ══════════════════════════════════════════════════════
void connectWiFi() {
    logInfo("Conectando ao WiFi: " + String(WIFI_SSID));
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    uint8_t attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20) {
        delay(500);
        Serial.print(".");
        attempts++;
    }
    if (WiFi.status() == WL_CONNECTED) {
        logInfo("WiFi conectado! IP: " + WiFi.localIP().toString());
    } else {
        logError("Falha ao conectar ao WiFi. Reiniciando...");
        ESP.restart();
    }
}

void checkWiFi() {
    if (WiFi.status() != WL_CONNECTED) {
        logWarn("WiFi perdido — reconectando...");
        connectWiFi();
    }
}

// ══════════════════════════════════════════════════════
// MQTT
// ══════════════════════════════════════════════════════
void connectMQTT() {
    logInfo("Conectando ao MQTT: " + String(MQTT_BROKER));
    while (!mqtt.connected()) {
        if (mqtt.connect(MQTT_CLIENT_ID)) {
            logInfo("MQTT conectado!");
        } else {
            logWarn("Falha MQTT (rc=" + String(mqtt.state()) + ") — tentando em 3s...");
            delay(3000);
        }
    }
}

void checkMQTT() {
    if (!mqtt.connected()) {
        logWarn("MQTT desconectado — reconectando...");
        connectMQTT();
    }
}

// ══════════════════════════════════════════════════════
// SENSORES
// ══════════════════════════════════════════════════════
void setupSensors() {
    dht.begin();
    pinMode(FLOW_PIN, INPUT_PULLUP);
    attachInterrupt(digitalPinToInterrupt(FLOW_PIN), onFlowPulse, FALLING);
    logInfo("Sensores inicializados.");
}

struct SensorData {
    float temperature;
    float humidity;
    float volume;
    bool  valid;
};

SensorData readSensors() {
    SensorData data;
    data.temperature = dht.readTemperature();
    data.humidity    = dht.readHumidity();

    noInterrupts();
    uint32_t pulses = pulseCount;
    pulseCount = 0;
    interrupts();

    totalLiters    += (pulses / FLOW_PULSES_PER_L);
    data.volume     = totalLiters;
    data.valid      = !isnan(data.temperature) && !isnan(data.humidity);

    if (!data.valid) logWarn("Leitura invalida do DHT22 (NaN)");
    return data;
}

// ══════════════════════════════════════════════════════
// PUBLISH
// ══════════════════════════════════════════════════════
void publishData(const SensorData& data) {
    StaticJsonDocument<256> doc;
    doc["device_id"]     = MQTT_CLIENT_ID;
    doc["timestamp"]     = millis();
    doc["stage"]         = STAGE;
    doc["temperature_c"] = serialized(String(data.temperature, 2));
    doc["humidity_pct"]  = serialized(String(data.humidity, 2));
    doc["volume_liters"] = serialized(String(data.volume, 3));

    char payload[256];
    serializeJson(doc, payload);

    if (mqtt.publish(TOPIC_SENSORS, payload)) {
        logInfo("Publicado: " + String(payload));
    } else {
        logError("Falha ao publicar no MQTT.");
    }
}

// ══════════════════════════════════════════════════════
// SETUP & LOOP
// ══════════════════════════════════════════════════════
void setup() {
    Serial.begin(SERIAL_BAUD);
    delay(1000);
    logInfo("=== Brewery IoT Monitor v1.0 ===");
    setupSensors();
    connectWiFi();
    mqtt.setServer(MQTT_BROKER, MQTT_PORT);
    connectMQTT();
}

void loop() {
    checkWiFi();
    checkMQTT();
    mqtt.loop();

    static unsigned long lastPublish = 0;
    if (millis() - lastPublish >= PUBLISH_INTERVAL_MS) {
        lastPublish = millis();
        SensorData data = readSensors();
        if (data.valid) publishData(data);
    }
}
