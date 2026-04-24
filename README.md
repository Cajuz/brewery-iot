# 🍺 Brewery IoT — Guia Completo Passo a Passo

> Pipeline de monitoramento de temperatura para cervejaria artesanal.
> Captura leituras do sensor DS18B20 via ESP32, processa no Node-RED e salva no Google Sheets.

```
ESP32 (DS18B20) → Mosquitto MQTT → Node-RED → Google Sheets
                      [Docker]        [Docker]
```

---

## Índice

1. [O que é este projeto?](#1-o-que-é-este-projeto)
2. [Pré-requisitos](#2-pré-requisitos)
3. [Passo 1 — Clonar o repositório](#passo-1--clonar-o-repositório)
4. [Passo 2 — Configurar variáveis de ambiente (.env)](#passo-2--configurar-variáveis-de-ambiente-env)
5. [Passo 3 — Configurar Google Sheets (Service Account)](#passo-3--configurar-google-sheets-service-account)
6. [Passo 4 — Criar usuários MQTT](#passo-4--criar-usuários-mqtt)
7. [Passo 5 — Subir os serviços com Docker](#passo-5--subir-os-serviços-com-docker)
8. [Passo 6 — Importar o Flow no Node-RED](#passo-6--importar-o-flow-no-node-red)
9. [Passo 7 — Configurar credenciais do Google no Node-RED](#passo-7--configurar-credenciais-do-google-no-node-red)
10. [Passo 8 — Testar a pipeline](#passo-8--testar-a-pipeline)
11. [Passo 9 — Conectar o ESP32 (firmware)](#passo-9--conectar-o-esp32-firmware)
12. [Verificando no Google Sheets](#verificando-no-google-sheets)
13. [Comandos úteis de operação](#comandos-úteis-de-operação)
14. [Solução de problemas comuns](#solução-de-problemas-comuns)
15. [Glossário](#glossário)

---

## 1. O que é este projeto?

Este projeto cria um **pipeline de dados IoT** para monitorar temperatura de fermentação em uma cervejaria artesanal.

| Componente | Função |
|---|---|
| **ESP32 + DS18B20** | Sensor de temperatura. Lê a temp. e publica via MQTT. |
| **Mosquitto** | Broker MQTT. Recebe os dados do ESP32 e repassa ao Node-RED. |
| **Node-RED** | Orquestrador. Valida, enfileira e grava os dados no Sheets. |
| **Google Sheets** | Banco de dados e visualização dos dados históricos. |

O Mosquitto e o Node-RED rodam via **Docker** na sua máquina ou servidor. O ESP32 é configurado separadamente.

---

## 2. Pré-requisitos

Instale antes de começar:

| Software | Versão mínima | Download |
|---|---|---|
| **Docker Desktop** (Win/Mac) ou **Docker Engine** (Linux) | 24.x | https://docs.docker.com/get-docker/ |
| **Docker Compose** | v2.x | Incluído no Docker Desktop |
| **Git** | qualquer | https://git-scm.com/ |
| **Python** (opcional, só para testes) | 3.10 | https://python.org |

### Verificar se o Docker está funcionando

Abra um terminal e rode:

```bash
docker --version
docker compose version
```

Você deve ver algo como:
```
Docker version 24.0.6
Docker Compose version v2.21.0
```

Se der erro, o Docker não está instalado corretamente.

---

## Passo 1 — Clonar o repositório

Abra o terminal (CMD, PowerShell, Terminal, bash) e rode:

```bash
git clone https://github.com/Cajuz/brewery-iot.git
cd brewery-iot
```

Você terá esta estrutura de pastas:

```
brewery-iot/
├── .env.example              ← template de configuração
├── docker-compose.yml        ← define os serviços Docker
├── mosquitto/
│   └── config/
│       └── mosquitto.conf    ← configuração do broker MQTT
├── node-red/
│   ├── flows/
│   │   └── brewery_flow.json ← flow principal do Node-RED
│   └── data/
│       └── settings.js       ← configuração do Node-RED
├── scripts/
│   ├── setup_mosquitto_users.sh  ← cria usuários MQTT
│   └── test_mqtt_connection.py   ← simula o ESP32
└── docs/
    └── esp32-mqtt-connection.md  ← contrato para o firmware
```

---

## Passo 2 — Configurar variáveis de ambiente (.env)

O arquivo `.env` guarda todas as senhas e configurações. Nunca commite ele no Git.

### 2.1 — Copiar o template

```bash
cp .env.example .env
```

### 2.2 — Editar o .env

Abra o arquivo com qualquer editor:

```bash
# VS Code
code .env

# Ou no terminal
nano .env
```

### 2.3 — Preencher os campos

O arquivo tem esta estrutura. Preencha **todos** os campos marcados com ⚠️:

```env
# ─── MOSQUITTO ──────────────────────────────────────────
MQTT_BROKER_HOST=localhost
MQTT_BROKER_PORT=1883
MQTT_WS_PORT=9001

# ⚠️ Senha do ESP32 no broker — crie uma senha forte
MQTT_ESP32_USER=esp32
MQTT_ESP32_PASSWORD=MinhaS3nhaForte!

# ⚠️ Senha do Node-RED no broker — crie uma senha forte diferente
MQTT_NODERED_USER=nodered
MQTT_NODERED_PASSWORD=OutraS3nha!

# Tópico MQTT — não altere, combina com o flow
MQTT_TOPIC_TEMPERATURE=brewery/sensors/temperature

# ─── NODE-RED ───────────────────────────────────────────
NODERED_PORT=1880

# ⚠️ Login do painel web do Node-RED
NODERED_ADMIN_USER=admin
NODERED_ADMIN_PASSWORD=AdminS3nha!

# ⚠️ Chave de criptografia interna — qualquer string longa e aleatória
NODERED_CREDENTIAL_SECRET=brewery_chave_super_secreta_2026

# ─── GOOGLE SHEETS ──────────────────────────────────────
# ⚠️ ID da planilha — veja como obter no Passo 3
SHEETS_SPREADSHEET_ID=1AbCdEfGhIjKlMnOpQrStUvWxYz1234567890
SHEETS_CREDENTIALS_PATH=/data/credentials/service-account.json
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

> **Como obter o ID da planilha:** Abra sua planilha no Google Sheets.
> A URL é `https://docs.google.com/spreadsheets/d/`**`1AbCd...`**`/edit`.
> O trecho em negrito é o ID.

---

## Passo 3 — Configurar Google Sheets (Service Account)

Este passo autoriza o Node-RED a escrever dados na sua planilha.

### 3.1 — Criar projeto no Google Cloud

1. Acesse https://console.cloud.google.com
2. Clique em **Select a project** (canto superior esquerdo) → **New Project**
3. Dê um nome (ex: `brewery-iot`) → clique **Create**

### 3.2 — Ativar a Google Sheets API

1. No menu lateral, vá em **APIs & Services** → **Library**
2. Pesquise `Google Sheets API`
3. Clique nela → clique **Enable**

### 3.3 — Criar a Service Account

1. Vá em **APIs & Services** → **Credentials**
2. Clique em **+ Create Credentials** → **Service Account**
3. Preencha o nome (ex: `brewery-nodered`) → clique **Create and continue**
4. Em **Role**, selecione **Editor** → clique **Continue** → **Done**

### 3.4 — Baixar a chave JSON

1. Na lista de Service Accounts, clique na que você criou
2. Vá na aba **Keys** → **Add Key** → **Create new key**
3. Selecione **JSON** → clique **Create**
4. O arquivo será baixado automaticamente (ex: `brewery-iot-abc123.json`)

### 3.5 — Salvar a chave no projeto

Crie a pasta e mova o arquivo:

```bash
mkdir -p node-red/data/credentials
cp ~/Downloads/brewery-iot-abc123.json node-red/data/credentials/service-account.json
```

> ⚠️ **Importante:** O nome do arquivo deve ser exatamente `service-account.json`.

### 3.6 — Criar a planilha e compartilhar

1. Acesse https://sheets.google.com → crie uma nova planilha
2. **⚠️ Renomeie a aba padrão "Página1" (ou "Sheet1") para `sensor_readings`:**
   - Clique duas vezes no nome da aba na parte inferior da tela
   - Apague o nome atual e digite exatamente `sensor_readings`
   - Pressione **Enter** para confirmar

   > ⚠️ **Atenção:** O nome da aba deve ser exatamente `sensor_readings` (sem maiúsculas, sem espaços, sem acentos). O Node-RED usa esse nome para saber onde gravar os dados. Se estiver errado, a gravação falhará silenciosamente.

3. Copie o ID da planilha da URL e cole no `.env` no campo `SHEETS_SPREADSHEET_ID`
4. Clique em **Share** (Compartilhar)
5. No campo de e-mail, cole o `client_email` do JSON da Service Account
   - Parece com: `brewery-nodered@brewery-iot-xxxxx.iam.gserviceaccount.com`
6. Defina permissão como **Editor** → clique **Send**

> **Por que isso?** O Node-RED vai usar a Service Account para escrever na planilha.
> Sem o compartilhamento, ele receberá erro 403 (Permission Denied).

---

## Passo 4 — Criar usuários MQTT

Este script cria as senhas criptografadas para o broker Mosquitto.

### No Linux/macOS:

```bash
bash scripts/setup_mosquitto_users.sh
```

### No Windows (PowerShell):

```powershell
# Primeiro usuário — flag -c CRIA o arquivo
docker run --rm -v "${PWD}/mosquitto/config:/mosquitto/config" `
  eclipse-mosquitto:2.0 `
  mosquitto_passwd -b -c /mosquitto/config/passwd esp32 SUA_SENHA_ESP32

# Segundo usuário — sem -c, apenas ADICIONA ao arquivo existente
docker run --rm -v "${PWD}/mosquitto/config:/mosquitto/config" `
  eclipse-mosquitto:2.0 `
  mosquitto_passwd -b /mosquitto/config/passwd nodered SUA_SENHA_NODERED
```

> ⚠️ **Importante:** Use `-c` apenas no primeiro comando. O `-c` cria o arquivo do zero — se usado no segundo comando, apaga o primeiro usuário.

Substitua `SUA_SENHA_ESP32` e `SUA_SENHA_NODERED` pelas mesmas senhas do `.env`. Use senhas simples **sem caracteres especiais** (`!`, `@`, `#`) para evitar problemas de escape no PowerShell.

Verifique que o arquivo foi criado:

```bash
ls -la mosquitto/config/passwd
# Deve existir e ter conteúdo
```

---

## Passo 5 — Subir os serviços com Docker

```bash
docker compose up -d
```

Este comando baixa as imagens (só na primeira vez) e sobe os containers em background.

### Verificar se está tudo rodando:

```bash
docker compose ps
```

Você deve ver:

```
NAME                 STATUS          PORTS
brewery_mosquitto    Up (healthy)    0.0.0.0:1883->1883/tcp
brewery_nodered      Up (healthy)    0.0.0.0:1880->1880/tcp
```

Ambos precisam mostrar **healthy**. Se mostrar **starting**, espere 30 segundos e rode novamente.

### Ver os logs em tempo real:

```bash
docker compose logs -f
```

Para parar de ver os logs: `Ctrl+C`

---

## Passo 6 — Importar o Flow no Node-RED

### 6.1 — Acessar o painel

Abra o browser em: **http://localhost:1880**

Faça login com `NODERED_ADMIN_USER` e `NODERED_ADMIN_PASSWORD` definidos no `.env`.

### 6.2 — Instalar o pacote Google Sheets

Antes de importar o flow, instale o pacote necessário:

1. Clique no ≡ (menu hambúrguer) → **Gerenciar paleta**
2. Vá na aba **Instalar**
3. Pesquise `node-red-contrib-google-sheets-advance`
4. Clique **Instalar** e aguarde 1-2 minutos

### 6.3 — Importar o flow

1. No canto superior direito, clique no ≡ (menu hambúrguer)
2. Clique em **Import**
3. Clique em **select a file to import**
4. Navegue até `node-red/flows/brewery_flow.json` na pasta do projeto
5. Clique **Import**

Você verá o flow `Brewery IoT` aparecer na tela com os nós conectados.

---

## Passo 7 — Configurar credenciais do Google no Node-RED

### 7.1 — Abrir as configurações do nó Sheets

1. No flow importado, clique duas vezes no nó **`sensor_readings`** (verde, no meio do flow)
2. Na janela que abrir, clique no ícone de lápis ✏️ ao lado do campo **Credentials**

### 7.2 — Preencher os campos da Service Account

Abra o arquivo `node-red/data/credentials/service-account.json` e copie os valores para os campos correspondentes:

```powershell
# No PowerShell, para ver o conteúdo formatado:
$json = Get-Content "node-red\data\credentials\service-account.json" | ConvertFrom-Json
$json.project_id
$json.client_email
$json.private_key
```

| Campo no Node-RED | Campo no JSON |
|---|---|
| `project_id` | `"project_id"` |
| `private_key` | `"private_key"` (incluindo `-----BEGIN PRIVATE KEY-----`) |
| `client_email` | `"client_email"` |

> ⚠️ **Atenção:** A chave deve começar com `-----BEGIN PRIVATE KEY-----` (sem `RSA`). Se começar com `-----BEGIN RSA PRIVATE KEY-----`, gere uma nova chave no Google Cloud Console.

4. Clique **Update** → **Done**

### 7.3 — Configurar o broker MQTT no nó DS18B20

1. Clique duas vezes no nó **DS18B20** (roxo, à esquerda)
2. Clique no lápis ✏️ ao lado do campo **Servidor**
3. Na aba **Conexão**, preencha **Servidor** com `mosquitto`
4. Na aba **Segurança**, preencha:
   - **Usuário:** `nodered`
   - **Senha:** a senha definida no Passo 4
5. Clique **Atualizar** → **Done**

### 7.4 — Fazer Deploy

Clique no botão vermelho **Implementar** no canto superior direito.

Você deve ver a mensagem `Implementado com sucesso` e o nó DS18B20 mostrando **"conectado"**.

---

## Passo 8 — Testar a pipeline

### Opção A — Script Python (recomendado)

```bash
# Instalar dependências (só na primeira vez)
pip install -r requirements.txt

# Rodar o simulador
python scripts/test_mqtt_connection.py
```

A saída deve ser:

```
=======================================================
  BREWERY IoT — Teste de Conexão MQTT
  Broker : localhost:1883
  Usuário: esp32
  Tópico : brewery/sensors/temperature
=======================================================
✅ Conectado ao broker localhost:1883
📡 Subscrito em: brewery/sensors/temperature
📤 Publicando payload de teste...
✅ Publicação confirmada (mid=1)
⏳ Aguardando mensagem de volta por 3s...
📥 Mensagem recebida:
   Tópico : brewery/sensors/temperature
   QoS    : 1
   Payload: {
         "temperature": 23.5,
         "unit": "C",
         "device_id": "esp32_test"
      }
✅ Teste concluído! 1 mensagem(ns) recebida(s).
```

### Opção B — Linha de comando (PowerShell)

```powershell
$payload = '23.5'
docker run --rm eclipse-mosquitto:2.0 mosquitto_pub `
  -h host.docker.internal -p 1883 `
  -u esp32 -P SUA_SENHA_ESP32 `
  -t brewery/sensors/temperature `
  -m $payload `
  -q 1
```

> ⚠️ O flow espera receber **apenas o número** da temperatura (ex: `23.5`), não um objeto JSON completo.

### Verificar no Node-RED

Após publicar, no painel http://localhost:1880:

- O nó **DS18B20** deve mostrar badge com a temperatura
- O nó **Validar DS18B20** deve mostrar badge verde com `23.5°C`
- O nó **Enfileirar** deve mostrar `fila: 0` (já processou)
- O nó **sensor_readings** deve mostrar status verde

---

## Passo 9 — Conectar o ESP32 (firmware)

O firmware do ESP32 é desenvolvido separadamente no Arduino IDE ou PlatformIO. Configure com os valores do seu `.env`:

| Parâmetro no firmware | Valor |
|---|---|
| `MQTT_SERVER` | IP da máquina onde o Docker está rodando |
| `MQTT_PORT` | `1883` |
| `MQTT_USER` | valor de `MQTT_ESP32_USER` no .env |
| `MQTT_PASSWORD` | valor de `MQTT_ESP32_PASSWORD` no .env |
| `MQTT_TOPIC` | `brewery/sensors/temperature` |

### Formato do payload que o ESP32 deve publicar

```
23.5
```

> ⚠️ O flow espera receber **apenas o valor numérico** da temperatura, não um objeto JSON.

### Descobrir o IP da máquina host

```bash
# Linux/macOS
hostname -I | awk '{print $1}'

# Windows
ipconfig
# Procure por "IPv4 Address"
```

---

## Verificando no Google Sheets

Após o teste, abra a planilha no Google Sheets.
Na aba `sensor_readings`, uma nova linha deve aparecer:

| timestamp | temperature | sensor |
|---|---|---|
| 2026-04-20T21:30:00Z | 23.5 | DS18B20 |

Se a linha não aparecer em até 30 segundos, veja a seção [Solução de problemas](#solução-de-problemas-comuns).

---

## Comandos úteis de operação

```bash
# Ver status dos containers
docker compose ps

# Ver logs em tempo real (todos os serviços)
docker compose logs -f

# Ver logs só do Node-RED
docker compose logs -f nodered

# Ver logs só do Mosquitto
docker compose logs -f mosquitto

# Reiniciar apenas o Node-RED
docker compose restart nodered

# Parar tudo
docker compose down

# Parar e apagar volumes (CUIDADO: apaga dados)
docker compose down -v

# Ver logs das últimas 50 linhas
docker compose logs --tail=50
```

---

## Solução de problemas comuns

### ❌ `docker compose ps` mostra status `unhealthy`

**Causa:** o container subiu mas o health check falhou.

```bash
docker compose logs mosquitto
docker compose logs nodered
```

Verifique se o arquivo `mosquitto/config/passwd` existe (Passo 4 não foi executado).

---

### ❌ Node-RED mostra "Waiting for missing types"

**Causa:** pacote npm não instalado.

Instale via **Gerenciar paleta** → aba **Instalar** → pesquise `node-red-contrib-google-sheets-advance` → clique **Instalar**.

---

### ❌ Erro 403 no Google Sheets

**Causa:** planilha não compartilhada com a Service Account.

1. Abra o arquivo `node-red/data/credentials/service-account.json`
2. Copie o valor do campo `client_email`
3. Abra a planilha no Google Sheets → Share → cole o e-mail → Editor → Send

---

### ❌ Erro 401 / JWT authorization failed

**Causa:** chave privada em formato incorreto ou corrompida.

1. Acesse o Google Cloud Console → Service Accounts → sua conta
2. Aba **Keys** → **Add Key** → **Create new key** → **JSON**
3. Substitua o arquivo `node-red/data/credentials/service-account.json`
4. Reconfigure os campos no nó `sensor_readings` do Node-RED
5. Adicione `NODE_OPTIONS=--openssl-legacy-provider` nas variáveis de ambiente do `docker-compose.yml`

---

### ❌ Dados não aparecem na planilha (fallback CSV)

**Causa:** nome da aba da planilha incorreto.

Verifique se a aba se chama exatamente `sensor_readings` (sem maiúsculas, sem espaços).

---

### ❌ Script Python falha com "Bad credentials"

**Causa:** senha no `.env` não bate com o `mosquitto/config/passwd`.

Refaça o Passo 4 com a mesma senha. Use senhas sem caracteres especiais no PowerShell.

---

### ❌ Script Python falha com "Connection refused"

**Causa:** Mosquitto não está rodando.

```bash
docker compose up -d
docker compose ps
```

---

### ❌ No Windows: `bash scripts/setup_mosquitto_users.sh` não funciona

Use o Git Bash (instalado junto com o Git) ou siga a Opção B do Passo 4 com PowerShell.

---

## Glossário

| Termo | Definição |
|---|---|
| **MQTT** | Protocolo de mensagens leve para IoT. Funciona no modelo publish/subscribe. |
| **Broker** | Servidor MQTT que recebe e distribui as mensagens. Aqui é o Mosquitto. |
| **Topic (Tópico)** | Endereço da mensagem no MQTT. Ex: `brewery/sensors/temperature`. |
| **QoS 1** | Nível de qualidade MQTT: garante entrega ao menos uma vez. |
| **Node-RED** | Plataforma visual de automação. Os "flows" são os programas visuais. |
| **Flow** | Conjunto de nós conectados no Node-RED que processam os dados. |
| **Service Account** | Conta do Google usada por aplicações (não humanos) para acessar APIs. |
| **Docker Compose** | Ferramenta que sobe múltiplos containers Docker com um único comando. |
| **Container** | Ambiente isolado onde um serviço roda (Mosquitto, Node-RED). |
| **DS18B20** | Sensor de temperatura digital da Dallas/Maxim. Range: −55°C a +125°C. |
| **ESP32** | Microcontrolador com WiFi da Espressif. Lê o sensor e publica via MQTT. |
