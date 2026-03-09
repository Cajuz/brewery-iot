# 🍺 Brewery IoT Monitor

Sistema de monitoramento em tempo real para fabricação de cerveja artesanal.

## Stack
- **Edge**: ESP32 + DHT22 + YF-S201
- **Broker**: Eclipse Mosquitto (MQTT)
- **ETL**: Node-RED
- **Banco**: MongoDB
- **Dashboard**: Grafana
- **Health**: FastAPI
- **Logs**: Grafana Loki + Promtail
- **Infra**: Docker Compose

## Quick Start
1.  **No Notebook (uma vez só)**

    | O que          | Onde baixar                            | Por quê                 |
    |----------------|----------------------------------------|-------------------------|
    | Docker Desktop | docker.com/products/docker-desktop     | Roda todos os containers|
    | Arduino IDE 2  | arduino.cc/en/software                 | Programar o ESP32       |
    | Git (opcional) | git-scm.com                            | Versionar o projeto     |

2.  **Dentro do Arduino IDE (uma vez só)**

    **Instalar o board ESP32:**

    1.  `File` → `Preferences` → `Additional Board URLs` → colar:
        ```text
        https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
        ```
    2.  `Tools` → `Board Manager` → buscar `esp32` → instalar `Espressif Systems`

    **Instalar as 3 libraries:**

    `Tools` → `Manage Libraries` → instalar:
    - `PubSubClient` — Nick O'Leary
    - `DHT sensor library` — Adafruit
    - `ArduinoJson` — Benoit Blanchon

3.  **Configurar o Projeto**

    **Passo 1** —  copie o projeto do repositório e entre na pasta (no terminal):
    ```bash
    git clone https://github.com/Cajuz/brewery-iot.git
    cd brewery-iot
    ```

    **Passo 2** — Copiar e editar o `.env`:
    ```bash
    cp .env.example .env
    ```
    Abrir o `.env` e preencher apenas esses campos:
    ```dotenv
    WIFI_SSID=nome_do_seu_hotspot
    WIFI_PASSWORD=senha_do_seu_hotspot
    GRAFANA_ADMIN_PASSWORD=uma_senha_forte
    ```

    **Passo 3** — Editar o `esp32/src/config.h` com os mesmos dados:
    ```cpp
    #define WIFI_SSID     "nome_do_seu_hotspot"
    #define WIFI_PASSWORD "senha_do_seu_hotspot"
    #define MQTT_BROKER   "192.168.137.1"   // IP fixo do hotspot Windows
    ```

4.  **Configurar o Hotspot no Windows**

    `Configurações` → `Rede e Internet` → `Ponto de Acesso Móvel` → `Ativar`

    Liberar a porta MQTT no Firewall (PowerShell como admin):
    ```powershell
    New-NetFirewallRule -DisplayName "MQTT 1883" `
      -Direction Inbound -Protocol TCP `
      -LocalPort 1883 -Action Allow
    ```

5.  **Gravar o Firmware no ESP32**

    1.  Conectar o ESP32 via USB no notebook
    2.  Arduino IDE → selecionar board: `ESP32 Dev Module`
    3.  Selecionar porta: a `COM` que aparecer
    4.  Abrir `esp32/src/main.cpp`
    5.  Clicar `Upload` (→)
    6.  Abrir `Serial Monitor` (115200 baud) para ver os logs

6.  **Subir o Stack Docker**
    ```bash
    docker-compose up -d
    ```
    Aguardar ~1 minuto e acessar:

    | Serviço | URL                   | Login                  |
    |---------|-----------------------|------------------------|
    | Grafana | http://localhost:3000 | admin / senha do .env  |
    | Node-RED| http://localhost:1880 | —                      |


## Acesso
| Serviço     | URL                        |
|-------------|----------------------------|
| Grafana     | http://localhost:3000       |
| Node-RED    | http://localhost:1880       |
| Healthcheck | http://localhost:8080/health|
