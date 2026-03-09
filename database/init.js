// Executado automaticamente ao subir o container MongoDB
db = db.getSiblingDB('brewery');

// ── Collection: sensor_readings ───────────────────────
db.createCollection('sensor_readings');
db.sensor_readings.createIndex({ collected_at: -1 });
db.sensor_readings.createIndex({ stage: 1, collected_at: -1 });
db.sensor_readings.createIndex({ device_id: 1, collected_at: -1 });

// ── Collection: event_logs ────────────────────────────
db.createCollection('event_logs');
db.event_logs.createIndex({ timestamp: -1 });
db.event_logs.createIndex({ level: 1, timestamp: -1 });
db.event_logs.createIndex({ service: 1, timestamp: -1 });

// ── Collection: health_logs ───────────────────────────
db.createCollection('health_logs');
db.health_logs.createIndex({ collected_at: -1 });
db.health_logs.createIndex({ name: 1, collected_at: -1 });

print('✅ Brewery DB inicializado com sucesso.');
