# 🍺 Brewery IoT — Guia Completo Passo a Passo

> Pipeline de monitoramento de temperatura para cervejaria artesanal.
> Captura leituras do sensor DS18B20 via ESP32, processa no Node-RED e salva no Google Sheets.

```
ESP32 (DS18B20) → Mosquitto MQTT → Node-RED → Google Sheets
                      [Docker]        [Docker]
```

---

## Índice

1. [O que é este projeto?](#1-o-que-%C3%A9-este-projeto)
2. [Pré-requisitos](#2-pré-requisitos)
3. [Passo 1 — Clonar o repositório](#passo-1--clonar-o-repositório)
4. [Passo 2 — Configurar variáveis de ambiente (.env)](#passo-2--configurar-vari%C3%A1veis-de-ambiente-env)
5. [Passo 3 — Configurar Google Sheets](#passo-3--configurar-google-sheets)
6. [Passo 4 — Criar usuários MQTT](#passo-4--criar-usu%C3%A1rios-mqtt)
7. [Passo 5 — Subir os serviços com Docker](#passo-5--subir-os-servi%C3%A7os-com-docker)
8. [Passo 6 — Restaurar o Node-RED](#passo-6--restaurar-o-node-red)
9. [Passo 7 — Verificar o painel Node-RED](#passo-7--verificar-o-painel-node-red)
10. [Passo 8 — Configurar credenciais do Google (se necessário)](#passo-8--configurar-credenciais-do-google-se-necess%C3%A1rio)
11. [Passo 9 — Testar a pipeline](#passo-9--testar-a-pipeline)
12. [Passo 10 — Conectar o ESP32](#passo-10--conectar-o-esp32)
13. [Verificando no Google Sheets](#verificando-no-google-sheets)
14. [Comandos úteis de operação](#comandos-%C3%BAteis-de-opera%C3%A7%C3%A3o)
15. [Solução de problemas comuns](#solu%C3%A7%C3%A3o-de-problemas-comuns)
16. [Glossário](#gloss%C3%A1rio)

---

## 1. O que é este projeto?

Este projeto cria um **pipeline de dados IoT** para monitorar temperatura de fermentação em uma cervejaria artesanal.

| Componente | Função |
|---|---|
| **ESP32 + DS18B20** | Lê a temperatura e publica JSON via MQTT a cada 800ms. |
| **Mosquitto** | Broker MQTT. Recebe os dados do ESP32 e repassa ao Node-RED. |
| **Node-RED** | Faz parse do JSON, valida, enfileira e grava no Google Sheets. |
| **Google Sheets** | Banco de dados com 3 abas: leituras, eventos e health check. |

O Mosquitto e o Node-RED rodam via **Docker** na sua máquina. O ESP32 é configurado separadamente.

### Pipeline de dados

```
ESP32 publica JSON
  → Mosquitto (broker)
  → Node-RED: DS18B20 → Parse JSON → Validar → Enfileirar → sensor_readings (Sheets)
                                                           → event_logs (Sheets)
                                       → Heartbeat 5min  → health_logs (Sheets)
```

### Payload publicado pelo ESP32

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

---

## 2. Pré-requisitos

Instale antes de começar:

| Software | Versão mínima | Download |
|---|---|---|
| **Docker Desktop** (Win/Mac) ou **Docker Engine** (Linux) | 24.x | https://docs.docker.com/get-docker/ |
| **Docker Compose** | v2.x | Incluído no Docker Desktop |
| **Git** | qualquer | https://git-scm.com/ |
| **Python** | 3.10+ | https://python.org |
| **Arduino IDE** ou **PlatformIO** | qualquer | Para gravar o ESP32 |

### Verificar Docker

```powershell
docker --version
docker compose version
```

Esperado:
```
Docker version 24.x.x
Docker Compose version v2.x.x
```

---

## Passo 1 — Clonar o repositório

```powershell
git clone https://github.com/Cajuz/brewery-iot.git
cd brewery-iot
```

Estrutura do projeto:

```
brewery-iot/
├── .env.example                  ← template de configuração
├── docker-compose.yml            ← define Mosquitto + Node-RED
├── mosquitto/
│   └── config/
│       ├── mosquitto.conf        ← configuração do broker
│       └── passwd                ← usuários MQTT (gerado no Passo 4)
├── node-red/
│   ├── flows/
│   │   ├── brewery_flow.json     ← flow principal
│   │   ├── credentials_flow.json ← credenciais criptografadas
│   │   └── settings.js           ← configurações do Node-RED
│   └── data/
│       └── credentials/
│           └── brewery-iot/
│               └── service-account.json ← chave Google (não versionada em prod)
├── codigo esp32/
│   └── codigo esp32.txt          ← firmware do ESP32
├── scripts/
│   ├── setup_mosquitto_users.sh  ← cria usuários MQTT
│   └── test_mqtt_connection.py   ← simula o ESP32
└── docs/
    └── esp32-mqtt-connection.md  ← contrato do firmware
```

---

## Passo 2 — Configurar variáveis de ambiente (.env)

### 2.1 — Copiar o template

```powershell
Copy-Item .env.example .env
```

### 2.2 — Abrir e preencher

```powershell
code .env   # VS Code
# ou
notepad .env
```

### 2.3 — Campos obrigatórios (⚠️)

```env
# ─── MOSQUITTO ──────────────────────────────────────────
MQTT_BROKER_HOST=localhost
MQTT_BROKER_PORT=1883

# ⚠️ Senha do ESP32 no broker
MQTT_ESP32_USER=esp32
MQTT_ESP32_PASSWORD=belezafatal

# ⚠️ Senha do Node-RED no broker
MQTT_NODERED_USER=nodered
MQTT_NODERED_PASSWORD=victoria321

MQTT_TOPIC_TEMPERATURE=brewery/sensors/temperature

# ─── NODE-RED ──────────────────────────────────────────
NODERED_PORT=1880
NODERED_ADMIN_USER=admin
NODERED_ADMIN_PASSWORD=admin123

# ⚠️ Chave de criptografia — qualquer string longa e aleatória
NODERED_CREDENTIAL_SECRET=brewery_chave_super_secreta_2026

# ─── GOOGLE SHEETS ─────────────────────────────────────
# ⚠️ ID da planilha (da URL do Google Sheets)
SHEETS_SPREADSHEET_ID=1AbCdEfGhIjKlMnOpQrStUvWxYz1234567890
SHEETS_CREDENTIALS_PATH=/data/credentials/brewery-iot/service-account.json
SHEETS_TAB_READINGS=sensor_readings
SHEETS_TAB_EVENTS=event_logs
SHEETS_TAB_HEALTH=health_logs

# ─── PIPELINE ───────────────────────────────────────────
QUEUE_MAX_SIZE=500
RETRY_DELAY_MS=60000
RETRY_MAX_ATTEMPTS=5
BUFFER_CSV_PATH=/data/buffer.csv

# ─── SENSOR DS18B20 ─────────────────────────────────────
SENSOR_TEMP_MIN=-55
SENSOR_TEMP_MAX=125
```

> **Como obter o ID da planilha:** Abra o Google Sheets e veja a URL:
> `https://docs.google.com/spreadsheets/d/`**`SEU_ID_AQUI`**`/edit`

---

## Passo 3 — Configurar Google Sheets

### 3.1 — Criar projeto no Google Cloud

1. Acesse https://console.cloud.google.com
2. **Select a project** → **New Project** → nome: `brewery-iot` → **Create**

### 3.2 — Ativar Google Sheets API

1. **APIs & Services** → **Library**
2. Pesquise `Google Sheets API` → **Enable**

### 3.3 — Criar Service Account

1. **APIs & Services** → **Credentials** → **+ Create Credentials** → **Service Account**
2. Nome: `brewery-nodered` → **Create and continue**
3. Role: **Editor** → **Continue** → **Done**

### 3.4 — Baixar chave JSON

1. Clique na Service Account criada → aba **Keys** → **Add Key** → **Create new key** → **JSON**
2. Salve o arquivo baixado como `service-account.json`

### 3.5 — Mover chave para o projeto

```powershell
New-Item -ItemType Directory -Force -Path .\node-red\data\credentials\brewery-iot
Copy-Item C:\Users\SEU_USUARIO\Downloads\brewery-iot-*.json `
  .\node-red\data\credentials\brewery-iot\service-account.json
```

### 3.6 — Criar planilha e abas

1. Acesse https://sheets.google.com → crie uma nova planilha
2. Crie **3 abas** com exatamente esses nomes:
   - `sensor_readings`
   - `event_logs`
   - `health_logs`
3. Adicione os cabeçalhos (linha 1) em cada aba:

**sensor_readings** (A:G):

| timestamp | temperatura | sensor | temperatura_alvo | ssr_state | potencia_esp_w | energia_esp_wh |
|---|---|---|---|---|---|---|

**event_logs** (A:D):

| timestamp | event_type | detail | source |
|---|---|---|---|

**health_logs** (A:H):

| timestamp | queue_size | last_temp | last_reading_age_s | broker_status | total_readings | total_errors | csv_buffer_lines |
|---|---|---|---|---|---|---|---|

4. Copie o ID da planilha da URL e cole no `.env` (`SHEETS_SPREADSHEET_ID`)
5. **Share** (Compartilhar) → cole o `client_email` do JSON → **Editor** → **Send**

---

## Passo 4 — Criar usuários MQTT

Este passo cria o arquivo `mosquitto/config/passwd` com as senhas criptografadas.

> ⚠️ **Execute os dois comandos na ordem.** O `-c` no primeiro comando **cria** o arquivo.
> Se você rodar o segundo com `-c`, apaga o primeiro usuário.

```powershell
# 1º — cria o arquivo e adiciona esp32
docker run --rm -v "${PWD}/mosquitto/config:/mosquitto/config" `
  eclipse-mosquitto:2.0 `
  mosquitto_passwd -b -c /mosquitto/config/passwd esp32 belezafatal

# 2º — adiciona nodered ao arquivo existente (sem -c)
docker run --rm -v "${PWD}/mosquitto/config:/mosquitto/config" `
  eclipse-mosquitto:2.0 `
  mosquitto_passwd -b /mosquitto/config/passwd nodered victoria321
```

Confirmar que o arquivo foi criado:

```powershell
Get-Content .\mosquitto\config\passwd
```

Deve mostrar duas linhas iniciando com `esp32:` e `nodered:`.

> ⚠️ Use as **mesmas senhas** do `.env`. Para recriar, rode os dois comandos novamente.

---

## Passo 5 — Subir os serviços com Docker

```powershell
docker compose up -d
```

Aguarde ~30 segundos e verifique:

```powershell
docker compose ps
```

Esperado:

```
NAME                STATUS          PORTS
brewery_mosquitto   Up (healthy)    0.0.0.0:1883->1883/tcp
brewery_nodered     Up (healthy)    0.0.0.0:1880->1880/tcp
```

Se algum mostrar `unhealthy`, veja os logs:

```powershell
docker compose logs mosquitto --tail 20
docker compose logs nodered --tail 20
```

---

## Passo 6 — Restaurar o Node-RED

Com os arquivos já versionados no repositório, basta copiar para o volume e reiniciar:

```powershell
# Copia flow, credenciais e settings para o volume do Node-RED
Copy-Item .\node-red\flows\brewery_flow.json    .\node-red\data\flows.json
Copy-Item .\node-red\flows\credentials_flow.json .\node-red\data\flows_cred.json
Copy-Item .\node-red\flows\settings.js          .\node-red\data\settings.js

# Reinicia o Node-RED para carregar os arquivos
docker compose restart nodered
```

Aguarde ~30 segundos e veja os logs:

```powershell
docker compose logs --tail 30 nodered
```

Resultado esperado:

```
Started flows
[mqtt-broker:Mosquitto Docker] Connected to broker: nodered-brewery@mqtt://mosquitto:1883
```

> ⚠️ Se aparecer `Failed to decrypt credentials`, o `credentialSecret` no `settings.js` está diferente do que foi usado para gerar o `credentials_flow.json`. Nesse caso siga o Passo 8 para reconfigurar manualmente.

---

## Passo 7 — Verificar o painel Node-RED

1. Abra o navegador em: **http://localhost:1880**
2. Faça login com `NODERED_ADMIN_USER` / `NODERED_ADMIN_PASSWORD` do `.env`
3. Confirme que a aba **Brewery IoT** está visível com os nós:

```
DS18B20 → Parse JSON ESP32 → Validar DS18B20 → Enfileirar → sensor_readings
                                                            → event_logs
Heartbeat 5min → Health Check → health_logs
```

4. O nó **DS18B20** deve mostrar badge `conectado`
5. Nenhum nó deve ter triângulo de erro ⚠️

Se houver erro nos nós do Google Sheets, siga o Passo 8.

---

## Passo 8 — Configurar credenciais do Google (se necessário)

> Pule este passo se o restore do Passo 6 funcionou sem erros nos nós Sheets.

### 8.1 — Abrir configurações da Service Account

1. No flow, clique duas vezes no nó **sensor_readings**
2. Clique no lápis ✏️ ao lado do campo **Credentials**

### 8.2 — Preencher com os dados do JSON

No PowerShell, para ver os valores:

```powershell
$json = Get-Content ".\node-red\data\credentials\brewery-iot\service-account.json" | ConvertFrom-Json
Write-Host "client_email: " $json.client_email
Write-Host "project_id:   " $json.project_id
# private_key é longa, copie diretamente do arquivo
```

| Campo no Node-RED | Campo no JSON |
|---|---|
| `project_id` | `"project_id"` |
| `private_key` | `"private_key"` (inclui `-----BEGIN PRIVATE KEY-----`) |
| `client_email` | `"client_email"` |

3. Clique **Update** → **Done**

### 8.3 — Configurar broker MQTT (se necessário)

1. Clique duas vezes no nó **DS18B20**
2. Lápis ✏️ ao lado de **Servidor**
3. Aba **Conexão**: Servidor = `mosquitto`, Porta = `1883`
4. Aba **Segurança**: Usuário = `nodered`, Senha = `victoria321`
5. **Atualizar** → **Done** → **Implementar** (botão vermelho)

---

## Passo 9 — Testar a pipeline

### Opção A — Script Python

```powershell
pip install -r requirements.txt
python .\scripts\test_mqtt_connection.py
```

### Opção B — mosquitto_pub com JSON completo

```powershell
$payload = '{"sensor":"temperatura","tempoAtivo":120,"temperatura":23.5,"temperatura_alvo":25,"erros_de_conexao":0,"saida_pid":1500.0,"ssr_state":0,"potencia_esp_w":0.792,"energia_esp_wh":0.026}'

docker run --rm eclipse-mosquitto:2.0 mosquitto_pub `
  -h host.docker.internal -p 1883 `
  -u esp32 -P belezafatal `
  -t brewery/sensors/temperature `
  -m $payload `
  -q 1
```

Verifique no Node-RED (`http://localhost:1880`):

- Nó **Parse JSON ESP32** — sem erro
- Nó **Validar DS18B20** — badge verde `23.5°C | ssr:0`
- Nó **Enfileirar** — badge `fila: 0`
- Nó **sensor_readings** — badge verde

---

## Passo 10 — Conectar o ESP32

Veja o contrato completo em [`docs/esp32-mqtt-connection.md`](docs/esp32-mqtt-connection.md).

### Configurações rápidas no firmware

1. Descubra o IP do host:

```powershell
ipconfig
# Procure IPv4 Address do Wi-Fi ou Ethernet
```

2. No arquivo `codigo esp32/codigo esp32.txt`, altere:

```cpp
const char* WIFI_SSID     = "NOME_DA_SUA_REDE";
const char* WIFI_PASSWORD = "SENHA_DA_SUA_REDE";
const char* MQTT_BROKER   = "192.168.x.x";   // IPv4 do host
const char* MQTT_USER     = "esp32";
const char* MQTT_PASSWORD = "belezafatal";
```

3. Compile e grave no ESP32 (Arduino IDE ou PlatformIO)
4. Abra o Serial Monitor (115200 baud) e confirme:

```
WiFi conectado — IP: 192.168.x.x
Conectando ao MQTT... OK
{"sensor":"temperatura","temperatura":25.5,...}
MQTT publish [brewery/sensors/temperature]: OK
```

---

## Verificando no Google Sheets

Abra a planilha e confira as 3 abas:

**sensor_readings** — linha a cada leitura do ESP32:

| timestamp | temperatura | sensor | temperatura_alvo | ssr_state | potencia_esp_w | energia_esp_wh |
|---|---|---|---|---|---|---|
| 2026-04-27T20:00:00Z | 25.5 | temperatura | 25 | 0 | 0.792 | 0.026 |

**event_logs** — eventos do sistema:

| timestamp | event_type | detail | source |
|---|---|---|---|
| 2026-04-27T20:00:05Z | MQTT_CONNECTED | nodered-brewery@mosquitto:1883 | mqtt-broker |

**health_logs** — heartbeat a cada 5 minutos:

| timestamp | queue_size | last_temp | last_reading_age_s | broker_status | total_readings | total_errors | csv_buffer_lines |
|---|---|---|---|---|---|---|---|
| 2026-04-27T20:05:00Z | 0 | 25.5 | 10 | connected | 42 | 0 | 0 |

---

## Comandos úteis de operação

```powershell
# Status dos containers
docker compose ps

# Logs em tempo real
docker compose logs -f
docker compose logs -f nodered
docker compose logs -f mosquitto

# Reiniciar serviço específico
docker compose restart nodered
docker compose restart mosquitto

# Parar tudo
docker compose down

# Parar e apagar volumes (CUIDADO: apaga dados do Node-RED)
docker compose down -v

# Salvar estado atual do Node-RED no repositório
Copy-Item .\node-red\data\flows.json       .\node-red\flows\brewery_flow.json
Copy-Item .\node-red\data\flows_cred.json  .\node-red\flows\credentials_flow.json
Copy-Item .\node-red\data\settings.js      .\node-red\flows\settings.js
git add node-red/flows/
git commit -m "chore: salva estado atual do Node-RED"
git push
```

---

## Solução de problemas comuns

### ❌ `docker compose ps` mostra `unhealthy`

```powershell
docker compose logs mosquitto --tail 20
```

Provavelmente o `mosquitto/config/passwd` não existe. Refaz o Passo 4.

---

### ❌ Node-RED: `Waiting for missing types`

Pacote npm não instalado. No painel http://localhost:1880:

**Menu (≡) → Gerenciar paleta → Instalar →** pesquise `node-red-contrib-google-spreadsheet` → **Instalar**

---

### ❌ Erro 403 no Google Sheets

Planilha não compartilhada com a Service Account.

1. Abra `node-red/data/credentials/brewery-iot/service-account.json`
2. Copie o `client_email`
3. Na planilha: **Share** → cole o e-mail → **Editor** → **Send**

---

### ❌ JWT authorization failed / Headers is not defined

Versão do Node.js abaixo do 18. Atualize a imagem no `docker-compose.yml`:

```yaml
image: nodered/node-red:3.1-18
```

```powershell
docker compose down
docker compose pull
docker compose up -d
```

---

### ❌ ESP32 Serial: `MQTT não conectado — publicação ignorada`

A task de MQTT ainda não completou a conexão. Aguarde 15–20 segundos. Se persistir:

```powershell
# Teste a conexão do broker com as mesmas credenciais do ESP32
docker run --rm eclipse-mosquitto:2.0 mosquitto_pub `
  -h 192.168.x.x -p 1883 `
  -u esp32 -P belezafatal `
  -t brewery/sensors/temperature `
  -m "teste" -q 1
```

- Se **funcionar** → problema de rede entre o ESP32 e o PC (redes diferentes?)
- Se **falhar** → problema no Mosquitto ou nas credenciais → refaz o Passo 4

Consulte o diagnóstico completo em [`docs/esp32-mqtt-connection.md`](docs/esp32-mqtt-connection.md).

---

### ❌ Dados não aparecem na planilha (fallback CSV)

Nome da aba incorreto. Confirme que as abas se chamam exatamente:
`sensor_readings`, `event_logs`, `health_logs`

---

### ❌ Após restore, credenciais não carregam

O `credentialSecret` no `settings.js` restaurado diverge do original.
Solucione recobrindo as credenciais manualmente no Passo 8.

---

## Glossário

| Termo | Definição |
|---|---|
| **MQTT** | Protocolo leve de mensagens IoT (publish/subscribe). |
| **Broker** | Servidor que recebe e distribui mensagens MQTT. Aqui é o Mosquitto. |
| **Tópico** | Endereço da mensagem. Ex: `brewery/sensors/temperature`. |
| **QoS 1** | Garante entrega ao menos uma vez. |
| **Node-RED** | Plataforma visual de automação. |
| **Flow** | Conjunto de nós conectados que processam dados. |
| **Service Account** | Conta do Google para aplicações acessarem APIs. |
| **Docker Compose** | Sobe múltiplos containers com um comando. |
| **DS18B20** | Sensor de temperatura digital. Range: −55°C a +125°C. |
| **ESP32** | Microcontrolador WiFi da Espressif. Lê o sensor e publica via MQTT. |
| **SSR** | Solid State Relay. Controla aquecimento via sinal do PID. |
| **PID** | Algoritmo de controle (Proporcional-Integral-Derivativo). |
| **credentialSecret** | Chave de criptografia do Node-RED para o `flows_cred.json`. |
