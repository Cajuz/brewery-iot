# =================================================================
#  BREWERY IoT — Setup usuários Mosquitto (Windows PowerShell)
#  Uso: .\scripts\setup_mosquitto_users.ps1
#  Pré-requisito: .env preenchido e Docker Desktop rodando
# =================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── Verificar .env ───────────────────────────────────────────
if (-not (Test-Path ".env")) {
    Write-Error "Arquivo .env nao encontrado. Copie .env.example -> .env e preencha."
    exit 1
}

# ─── Ler variáveis do .env ──────────────────────────────────────
$envVars = @{}
Get-Content ".env" | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#")) {
        $parts = $line -split "=", 2
        if ($parts.Length -eq 2) {
            $envVars[$parts[0].Trim()] = $parts[1].Trim()
        }
    }
}

$ESP32_USER = $envVars["MQTT_ESP32_USER"]
$ESP32_PASS = $envVars["MQTT_ESP32_PASSWORD"]
$NR_USER    = $envVars["MQTT_NODERED_USER"]
$NR_PASS    = $envVars["MQTT_NODERED_PASSWORD"]

if (-not $ESP32_USER -or -not $ESP32_PASS -or -not $NR_USER -or -not $NR_PASS) {
    Write-Error "Variaveis MQTT_ESP32_USER/PASSWORD ou MQTT_NODERED_USER/PASSWORD nao encontradas no .env"
    exit 1
}

# ─── Caminho absoluto do volume ──────────────────────────────────
$configPath = (Resolve-Path ".\mosquitto\config").Path
$passwdFile = Join-Path $configPath "passwd"

Write-Host ""
Write-Host "=== Brewery IoT - Setup Mosquitto Users ==="
Write-Host "Config: $configPath"
Write-Host ""

# ─── Remover passwd antigo se existir (re-cria do zero) ─────────────
if (Test-Path $passwdFile) {
    Remove-Item $passwdFile -Force
    Write-Host "Arquivo passwd antigo removido."
}

# ─── Passo 1: criar arquivo passwd com o 1o usuario (flag -c = create) ──
Write-Host "[1/2] Criando arquivo passwd + usuario ESP32: $ESP32_USER"
docker run --rm `
    -v "${configPath}:/mosquitto/config" `
    eclipse-mosquitto:2.0 `
    mosquitto_passwd -b -c /mosquitto/config/passwd $ESP32_USER $ESP32_PASS

if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha ao criar usuario ESP32"
    exit 1
}
Write-Host "OK"

# ─── Passo 2: adicionar 2o usuario (sem -c para nao sobrescrever) ──────
Write-Host "[2/2] Adicionando usuario Node-RED: $NR_USER"
docker run --rm `
    -v "${configPath}:/mosquitto/config" `
    eclipse-mosquitto:2.0 `
    mosquitto_passwd -b /mosquitto/config/passwd $NR_USER $NR_PASS

if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha ao criar usuario Node-RED"
    exit 1
}
Write-Host "OK"

# ─── Resultado ───────────────────────────────────────────────────
Write-Host ""
Write-Host "Usuarios criados com sucesso!"
Write-Host "Conteudo de mosquitto/config/passwd:"
Get-Content $passwdFile
Write-Host ""
Write-Host "Proximo passo: docker compose up -d"
