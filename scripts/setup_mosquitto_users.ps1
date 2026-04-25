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

$ESP32_USER  = $envVars["MQTT_ESP32_USER"]
$ESP32_PASS  = $envVars["MQTT_ESP32_PASSWORD"]
$NR_USER     = $envVars["MQTT_NODERED_USER"]
$NR_PASS     = $envVars["MQTT_NODERED_PASSWORD"]

if (-not $ESP32_USER -or -not $ESP32_PASS -or -not $NR_USER -or -not $NR_PASS) {
    Write-Error "Variaveis MQTT_ESP32_USER, MQTT_ESP32_PASSWORD, MQTT_NODERED_USER ou MQTT_NODERED_PASSWORD nao encontradas no .env"
    exit 1
}

# ─── Montar caminho absoluto para o volume ──────────────────────────
$configPath = (Resolve-Path ".\mosquitto\config").Path

Write-Host ""
Write-Host "=== Brewery IoT - Setup Mosquitto Users ==="
Write-Host "Pasta de config: $configPath"
Write-Host ""

# ─── Criar usuário ESP32 ──────────────────────────────────────────
Write-Host "Criando usuario ESP32: $ESP32_USER"
docker run --rm `
    -v "${configPath}:/mosquitto/config" `
    eclipse-mosquitto:2.0 `
    mosquitto_passwd -b /mosquitto/config/passwd $ESP32_USER $ESP32_PASS

if ($LASTEXITCODE -ne 0) { Write-Error "Falha ao criar usuario ESP32"; exit 1 }
Write-Host "OK: usuario ESP32 criado."

# ─── Criar usuário Node-RED ───────────────────────────────────────
Write-Host "Criando usuario Node-RED: $NR_USER"
docker run --rm `
    -v "${configPath}:/mosquitto/config" `
    eclipse-mosquitto:2.0 `
    mosquitto_passwd -b /mosquitto/config/passwd $NR_USER $NR_PASS

if ($LASTEXITCODE -ne 0) { Write-Error "Falha ao criar usuario Node-RED"; exit 1 }
Write-Host "OK: usuario Node-RED criado."

# ─── Resultado ───────────────────────────────────────────────────
Write-Host ""
Write-Host "Usuarios criados com sucesso em mosquitto/config/passwd"
Write-Host "Conteudo do arquivo passwd:"
Get-Content ".\mosquitto\config\passwd"
Write-Host ""
Write-Host "Proximo passo: docker compose up -d"
