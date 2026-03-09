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
```bash
cp .env.example .env
docker-compose up -d
```

## Acesso
| Serviço     | URL                        |
|-------------|----------------------------|
| Grafana     | http://localhost:3000       |
| Node-RED    | http://localhost:1880       |
| Healthcheck | http://localhost:8080/health|
