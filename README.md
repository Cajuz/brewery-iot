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
8. [Passo 6 — Restaurar o Node-RED (flow + credenciais)](#passo-6--restaurar-o-node-red-flow--credenciais)
9. [Passo 7 — Importar o Flow no Node-RED (alternativa manual)](#passo-7--importar-o-flow-no-node-red-alternativa-manual)
10. [Passo 8 — Configurar credenciais do Google no Node-RED](#passo-8--configurar-credenciais-do-google-no-node-red)
11. [Passo 9 — Testar a pipeline](#passo-9--testar-a-pipeline)
12. [Passo 10 — Conectar o ESP32 (firmware)](#passo-10--conectar-o-esp32-firmware)
13. [Verificando no Google Sheets](#verificando-no-google-sheets)
14. [Comandos úteis de operação](#comandos-úteis-de-operação)
15. [Solução de problemas comuns](#solução-de-problemas-comuns)
16. [Glossário](#glossário)

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
│   │   ├── brewery_flow.json     ← flow principal do Node-RED
│   │   ├── credentials_flow.json ← credenciais criptografadas
│   │   └── settings.js           ← configuração do Node-RED
│   └── data/
│       └── credentials/
│           └── brewery-iot/
│               └── service-account.json ← chave Google (não versionada em prod)
├── scripts/
│   ├── setup_mosquitto_users.sh  ← cria usuários MQTT
│   └── test_mqtt_connection.py   ← simula o ESP32
└── docs/
    └── esp32-mqtt-connection.md  ← contrato para o firmware
```

---

## Passo 2 — Configurar variáveis de ambiente (.env)

O arquivo `.env` guarda todas as senhas e configurações. Nunca commite ele no Git em produção.

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
mkdir -p node-red/data/credentials/brewery-iot
cp ~/Downloads/brewery-iot-abc123.json node-red/data/credentials/brewery-iot/service-account.json
```

> ⚠️ **Importante:** O nome do arquivo deve ser exatamente `service-account.json`.

### 3.6 — Criar a planilha, abas e compartilhar

1. Acesse https://sheets.google.com → crie uma nova planilha
2. **Crie as três abas** com exatamente esses nomes:
   - `sensor_readings`
   - `event_logs`
   - `health_logs`
3. **Adicione os cabeçalhos** em cada aba (linha 1):

   **sensor_readings** — colunas A:C
   | timestamp | temperature | device_id |
   |---|---|---|

   **event_logs** — colunas A:D
   | timestamp | event_type | detail | source |
   |---|---|---|---|

   **health_logs** — colunas A:H
   | timestamp | queue_size | last_temp | last_reading_age_s | broker_status | total_readings | total_errors | csv_buffer_lines |
   |---|---|---|---|---|---|---|---|

4. Copie o ID da planilha da URL e cole no `.env` no campo `SHEETS_SPREADSHEET_ID`
5. Clique em **Share** (Compartilhar)
6. No campo de e-mail, cole o `client_email` do JSON da Service Account
   - Parece com: `brewery-nodered@brewery-iot-xxxxx.iam.gserviceaccount.com`
7. Defina permissão como **Editor** → clique **Send**

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

## Passo 6 — Restaurar o Node-RED (flow + credenciais)

> Este é o método **rápido** para recriar o Node-RED exatamente como estava configurado,
> usando os arquivos versionados no repositório.
> Se preferir configurar tudo manualmente do zero, pule para o Passo 7.

### 6.1 — Copiar os arquivos do repositório para o volume

No PowerShell, na raiz do projeto:

```powershell
# Flow principal
Copy-Item .\node-red\flows\brewery_flow.json .\node-red\data\flows.json

# Credenciais criptografadas dos nós
Copy-Item .\node-red\flows\credentials_flow.json .\node-red\data\flows_cred.json

# Settings do Node-RED (porta, chave de criptografia, etc.)
Copy-Item .\node-red\flows\settings.js .\node-red\data\settings.js
```

### 6.2 — Restaurar os pacotes npm (nodes extras)

Se o repositório contiver `node-red/data/package.json`, os nodes extras (como `node-red-contrib-google-spreadsheet`) serão reinstalados automaticamente na próxima subida do container.

Confirma se o arquivo existe:

```powershell
dir .\node-red\data\package.json
```

Se existir, o Node-RED instala os pacotes sozinho ao subir. Se não existir, instale manualmente conforme o Passo 7.

### 6.3 — Reiniciar o Node-RED

```powershell
docker compose restart nodered
```

Aguarde 30 segundos e verifique os logs:

```powershell
docker compose logs --tail 30 nodered
```

Resultado esperado (sem erros):

```
Starting flows
Started flows
[mqtt-broker:Mosquitto Docker] Connected to broker: nodered-brewery@mqtt://mosquitto:1883
```

### 6.4 — Verificar o flow no painel

Abra **http://localhost:1880** e confirme:

- A aba **Brewery IoT** aparece com os 3 pipelines (sensor_readings, event_logs, health_logs)
- O nó **DS18B20** mostra badge **"conectado"**
- Os nós Google Sheets não mostram badge de erro

> ⚠️ **Atenção:** O arquivo `flows_cred.json` é criptografado com a chave definida em `settings.js`
> (`credentialSecret`). Se você trocar o `settings.js` ou o `credentialSecret`, as credenciais
> dos nós serão invalidadas e você precisará reconfigurar manualmente os campos de
> usuário/senha no Node-RED.

---

## Passo 7 — Importar o Flow no Node-RED (alternativa manual)

> Siga este passo apenas se **não** fez o Passo 6 (restore automático).

### 7.1 — Acessar o painel

Abra o browser em: **http://localhost:1880**

Faça login com `NODERED_ADMIN_USER` e `NODERED_ADMIN_PASSWORD` definidos no `.env`.

### 7.2 — Instalar o pacote Google Sheets

Antes de importar o flow, instale o pacote necessário:

1. Clique no ≡ (menu hambúrguer) → **Gerenciar paleta**
2. Vá na aba **Instalar**
3. Pesquise `node-red-contrib-google-spreadsheet`
4. Clique **Instalar** e aguarde 1-2 minutos

### 7.3 — Importar o flow

1. No canto superior direito, clique no ≡ (menu hambúrguer)
2. Clique em **Import**
3. Clique em **select a file to import**
4. Navegue até `node-red/flows/brewery_flow.json` na pasta do projeto
5. Clique **Import**

Você verá o flow `Brewery IoT` aparecer na tela com os nós conectados.

---

## Passo 8 — Configurar credenciais do Google no Node-RED

> Se você fez o restore do Passo 6 com sucesso e não aparece erro nos nós Sheets, pode pular este passo.

### 8.1 — Abrir as configurações do nó Sheets

1. No flow importado, clique duas vezes no nó **`sensor_readings`** (verde, no meio do flow)
2. Na janela que abrir, clique no ícone de lápis ✏️ ao lado do campo **Credentials**

### 8.2 — Preencher os campos da Service Account

Abra o arquivo `node-red/data/credentials/brewery-iot/service-account.json` e copie os valores:

```powershell
# No PowerShell, para ver o conteúdo formatado:
$json = Get-Content ".\node-red\data\credentials\brewery-iot\service-account.json" | ConvertFrom-Json
$json.client_email
$json.private_key
```

| Campo no Node-RED | Campo no JSON |
|---|---|
| `project_id` | `"project_id"` |
| `private_key` | `"private_key"` (incluindo `-----BEGIN PRIVATE KEY-----`) |
| `client_email` | `"client_email"` |

> ⚠️ **Atenção:** A chave deve começar com `-----BEGIN PRIVATE KEY-----` (sem `RSA`).

4. Clique **Update** → **Done**

### 8.3 — Configurar o broker MQTT no nó DS18B20

1. Clique duas vezes no nó **DS18B20** (roxo, à esquerda)
2. Clique no lápis ✏️ ao lado do campo **Servidor**
3. Na aba **Conexão**, preencha **Servidor** com `mosquitto` e **Porta** com `1883`
4. Na aba **Segurança**, preencha:
   - **Usuário:** `nodered`
   - **Senha:** a senha definida no Passo 4
5. Clique **Atualizar** → **Done**

### 8.4 — Fazer Deploy

Clique no botão vermelho **Implementar** no canto superior direito.

Você deve ver a mensagem `Implementado com sucesso` e o nó DS18B20 mostrando **"conectado"**.

---

## Passo 9 — Testar a pipeline

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
   Payload: 23.5
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

## Passo 10 — Conectar o ESP32 (firmware)

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

**Aba `sensor_readings`** — nova linha a cada leitura do ESP32:

| timestamp | temperature | device_id |
|---|---|---|
| 2026-04-25T23:21:00Z | 23.5 | DS18B20 |

**Aba `event_logs`** — registra eventos do sistema:

| timestamp | event_type | detail | source |
|---|---|---|---|
| 2026-04-25T23:21:15Z | MQTT_CONNECTED | nodered-brewery@mosquitto:1883 | mqtt-broker |
| 2026-04-25T23:22:00Z | SENSOR_INVALID | Valor fora do range: 999 | n-validate |

**Aba `health_logs`** — heartbeat a cada 5 minutos:

| timestamp | queue_size | last_temp | last_reading_age_s | broker_status | total_readings | total_errors | csv_buffer_lines |
|---|---|---|---|---|---|---|---|
| 2026-04-25T23:25:00Z | 0 | 23.5 | 10 | connected | 42 | 0 | 0 |

Se os dados não aparecerem em até 30 segundos, veja a seção [Solução de problemas](#solução-de-problemas-comuns).

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

# Salvar estado atual do Node-RED no repositório
Copy-Item .\node-red\data\flows.json        .\node-red\flows\brewery_flow.json
Copy-Item .\node-red\data\flows_cred.json   .\node-red\flows\credentials_flow.json
Copy-Item .\node-red\data\settings.js       .\node-red\flows\settings.js
git add node-red/flows/
git commit -m "chore: salva estado atual do Node-RED"
git push
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

Instale via **Gerenciar paleta** → aba **Instalar** → pesquise `node-red-contrib-google-spreadsheet` → clique **Instalar**.

---

### ❌ Erro 403 no Google Sheets

**Causa:** planilha não compartilhada com a Service Account.

1. Abra o arquivo `node-red/data/credentials/brewery-iot/service-account.json`
2. Copie o valor do campo `client_email`
3. Abra a planilha no Google Sheets → Share → cole o e-mail → Editor → Send

---

### ❌ Erro 401 / JWT authorization failed / Headers is not defined

**Causa:** versão do Node.js incompatível (abaixo do 18) com a biblioteca JWT.

Atualize a imagem do Node-RED no `docker-compose.yml`:

```yaml
image: nodered/node-red:3.1-18
```

Depois:

```powershell
docker compose down
docker compose pull
docker compose up -d
```

---

### ❌ Dados não aparecem na planilha (fallback CSV)

**Causa:** nome da aba da planilha incorreto.

Verifique se as abas se chamam exatamente `sensor_readings`, `event_logs` e `health_logs` (sem maiúsculas, sem espaços).

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

### ❌ Após restore, Node-RED não carrega as credenciais

**Causa:** o `credentialSecret` no `settings.js` restaurado é diferente do que foi usado para criptografar o `flows_cred.json`.

Solução: reconfigure as credenciais manualmente seguindo o Passo 8.

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
| **flows_cred.json** | Arquivo com credenciais dos nós Node-RED, criptografado com o `credentialSecret`. |
| **credentialSecret** | Chave de criptografia definida no `settings.js` do Node-RED. |
