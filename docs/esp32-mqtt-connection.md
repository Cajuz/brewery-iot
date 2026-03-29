# Conexão do ESP32 com o Broker Mosquitto

O firmware do ESP32 é desenvolvido **separadamente** (Arduino IDE, PlatformIO, etc.).
Este documento define o **contrato de interface MQTT** que o firmware deve seguir.

---

## Dados de Conexão

Configure no firmware com base no `.env` do servidor:

| Parâmetro         | Variável no `.env`        | Valor padrão       |
|-------------------|---------------------------|--------------------|
| Broker Host       | `MQTT_BROKER_HOST`        | IP da máquina host |
| Porta TCP         | `MQTT_BROKER_PORT`        | `1883`             |
| Usuário           | `MQTT_ESP32_USER`         | `esp32`            |
| Senha             | `MQTT_ESP32_PASSWORD`     | (definido no .env) |
| QoS               | —                         | **1** (obrigatório)|
| Client ID         | —                         | ex: `esp32_brewery_01` |

> O ESP32 deve usar **QoS 1** para garantir entrega ao menos uma vez.

---

## Tópico de Publicação

```
brewery/sensor/temperature
```

Configurado via `MQTT_TOPIC_TEMPERATURE` no `.env`.

---

## Formato do Payload (JSON)

```json
{
  "temperature": 23.5,
  "unit": "C",
  "device_id": "esp32_01"
}
```

| Campo         | Tipo    | Obrigatório | Descrição                            |
|---------------|---------|-------------|--------------------------------------|
| `temperature` | float   | ✅           | Leitura do DS18B20 em graus Celsius  |
| `unit`        | string  | ✅           | Sempre `"C"` (Celsius)               |
| `device_id`   | string  | ✅           | Identificador único do dispositivo   |

**Range válido:** −55 °C a +125 °C (limite físico do DS18B20).
Leituras fora desse range são descartadas pelo Node-RED.

---

## Comportamento Esperado do Firmware

- **Intervalo de leitura:** configurável (recomendado 30s)
- **WiFi perdido:** armazenar leituras em SPIFFS (até 50 registros)
  e reenviar com backoff exponencial após reconexão
- **Reconexão MQTT:** usar backoff exponencial: 1s → 2s → 4s → ... → 60s
- **Last Will:** opcional, mas recomendado:
  ```
  Tópico: brewery/status/esp32
  Payload: {"status": "offline"}
  QoS: 1, Retain: true
  ```

---

## Testando a Conexão

Com o broker rodando, use o script Python disponível no repositório:

```bash
# Com Docker ativo
python scripts/test_mqtt_connection.py
```

Ou via mosquitto_pub na linha de comando:

```bash
mosquitto_pub \
  -h localhost -p 1883 \
  -u esp32 -P sua_senha \
  -t brewery/sensor/temperature \
  -m '{"temperature":23.5,"unit":"C","device_id":"esp32_01"}' \
  -q 1
```
