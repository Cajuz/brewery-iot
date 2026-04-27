# 🔌 Conexão do ESP32 com o Broker Mosquitto

Este documento define o **contrato de interface MQTT** entre o firmware do ESP32 e a pipeline Node-RED.
O firmware é desenvolvido separadamente (Arduino IDE ou PlatformIO).

---

## Dados de Conexão

Configure no firmware com base no `.env` do servidor:

| Parâmetro | Variável no `.env` | Valor no ambiente de teste |
|---|---|---|
| Broker Host | `MQTT_BROKER_HOST` | IP do host (veja abaixo como descobrir) |
| Porta TCP | `MQTT_BROKER_PORT` | `1883` |
| Usuário | `MQTT_ESP32_USER` | `esp32` |
| Senha | `MQTT_ESP32_PASSWORD` | `belezafatal` |
| QoS | — | **1** (obrigatório) |
| Client ID | — | `esp32-brewery` |

> ⚠️ O ESP32 **não** deve usar `localhost` como broker — ele precisa do **IP real da máquina** onde o Docker está rodando.

### Como descobrir o IP do host (Windows)

No PowerShell:

```powershell
ipconfig
```

Procure o bloco da interface ativa:
- **Wi-Fi:** `Wireless LAN adapter Wi-Fi`
- **Cabo:** `Ethernet adapter Ethernet`

Copie a linha `IPv4 Address`, ex: `192.168.18.7`. Esse é o `MQTT_BROKER` no firmware.

> ⚠️ O ESP32 e o PC precisam estar na **mesma rede Wi-Fi** para se comunicarem.

---

## Tópico de Publicação

```
brewery/sensors/temperature
```

Configurado via `MQTT_TOPIC_TEMPERATURE` no `.env`.

---

## Formato do Payload (JSON completo)

O ESP32 publica um **objeto JSON** a cada leitura do sensor DS18B20:

```json
{
  "sensor":           "temperatura",
  "tempoAtivo":       120,
  "temperatura":      25.5,
  "temperatura_alvo": 26,
  "erros_de_conexao": 0,
  "saida_pid":        1500.0,
  "ssr_state":        1,
  "potencia_esp_w":   0.792,
  "energia_esp_wh":   0.0264
}
```

| Campo | Tipo | Descrição |
|---|---|---|
| `sensor` | string | Sempre `"temperatura"` |
| `tempoAtivo` | int | Segundos desde o boot do ESP32 |
| `temperatura` | float | Leitura do DS18B20 em °C |
| `temperatura_alvo` | int | Setpoint atual do PID |
| `erros_de_conexao` | int | Total de erros de sensor desde o boot |
| `saida_pid` | float | Saída calculada pelo PID (0–5000) |
| `ssr_state` | int | Estado do SSR: `1` = ligado, `0` = desligado |
| `potencia_esp_w` | float | Potência consumida pelo ESP32 (W) |
| `energia_esp_wh` | float | Energia acumulada desde o boot (Wh) |

**Range válido para temperatura:** −55 °C a +125 °C (limite físico do DS18B20).
Leituras fora desse range são descartadas pelo Node-RED com evento `SENSOR_INVALID`.

---

## O que o Node-RED faz com o JSON

A pipeline no Node-RED segue este fluxo:

```
DS18B20 (MQTT in)
  → Parse JSON ESP32     ← extrai todos os campos
  → Validar DS18B20      ← checa se temperatura está no range
  → Enfileirar           ← fila com retry e fallback CSV
  → sensor_readings      ← grava no Google Sheets (colunas A:G)
```

O que é gravado na aba `sensor_readings` do Google Sheets:

| A | B | C | D | E | F | G |
|---|---|---|---|---|---|---|
| timestamp | temperatura | sensor | temperatura_alvo | ssr_state | potencia_esp_w | energia_esp_wh |

---

## Configuração do Firmware

No arquivo `codigo esp32/codigo esp32.txt`, ajuste os campos:

```cpp
// ─── WiFi ────────────────────────────────────────────────────────
const char* WIFI_SSID     = "NOME_DA_SUA_REDE";   // ⚠️ seu SSID
const char* WIFI_PASSWORD = "SENHA_DA_SUA_REDE";  // ⚠️ sua senha WiFi

// ─── MQTT ────────────────────────────────────────────────────────
const char* MQTT_BROKER    = "192.168.18.7";       // ⚠️ IPv4 do host (ipconfig)
const int   MQTT_PORT      = 1883;
const char* MQTT_USER      = "esp32";              // MQTT_ESP32_USER do .env
const char* MQTT_PASSWORD  = "belezafatal";        // MQTT_ESP32_PASSWORD do .env
const char* MQTT_CLIENT_ID = "esp32-brewery";
const char* MQTT_TOPIC     = "brewery/sensors/temperature";
```

O resto do código (PID, SSR, LCD, sensor) **não precisa ser alterado**.

---

## Testando a Conexão (sem o ESP32)

Com os containers rodando, teste via linha de comando no PowerShell:

```powershell
# Publica um JSON no mesmo formato do ESP32
$payload = '{"sensor":"temperatura","tempoAtivo":120,"temperatura":23.5,"temperatura_alvo":25,"erros_de_conexao":0,"saida_pid":1500.0,"ssr_state":0,"potencia_esp_w":0.792,"energia_esp_wh":0.026}'

docker run --rm eclipse-mosquitto:2.0 mosquitto_pub `
  -h host.docker.internal -p 1883 `
  -u esp32 -P belezafatal `
  -t brewery/sensors/temperature `
  -m $payload `
  -q 1
```

Ou usando o script Python do repositório:

```powershell
pip install -r requirements.txt
python scripts/test_mqtt_connection.py
```

Após publicar, verifique no Node-RED (`http://localhost:1880`) se os nós mostram status verde.

---

## Diagnóstico de Problemas

### ❌ ESP32 Serial: `falhou, rc=-2`

**Causa:** IP do broker inacessível ou porta bloqueada.

- Confirme o IP com `ipconfig` no Windows e verifique se é o mesmo que está no firmware.
- Confirme que ESP32 e PC estão na **mesma rede** (mesmo roteador).
- Testa o `mosquitto_pub` acima — se funcionar do PC mas não do ESP32, é rede.

### ❌ ESP32 Serial: `falhou, rc=4` ou `rc=5`

**Causa:** Credenciais incorretas (usuário/senha).

- Confirme que `MQTT_USER=esp32` e `MQTT_PASSWORD=belezafatal` batem com o `mosquitto/config/passwd`.
- Recrie os usuários:

```powershell
docker run --rm -v "${PWD}/mosquitto/config:/mosquitto/config" `
  eclipse-mosquitto:2.0 `
  mosquitto_passwd -b -c /mosquitto/config/passwd esp32 belezafatal

docker run --rm -v "${PWD}/mosquitto/config:/mosquitto/config" `
  eclipse-mosquitto:2.0 `
  mosquitto_passwd -b /mosquitto/config/passwd nodered victoria321
```

Depois reinicie o Mosquitto:

```powershell
docker compose restart mosquitto
```

### ❌ Serial: `MQTT não conectado — publicação ignorada`

**Causa:** A task `taskManterMQTT` ainda não completou a conexão quando a primeira leitura chegou.

Isso é normal nos primeiros segundos após o boot. Se persistir por mais de 15–20 segundos, é um dos casos acima.

### ❌ Mosquitto aparece como `unhealthy`

```powershell
docker compose logs mosquitto --tail 30
```

Verifique se `mosquitto/config/passwd` existe e não está vazio.
