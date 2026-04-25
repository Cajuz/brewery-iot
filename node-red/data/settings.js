module.exports = {
    // URL base do editor
    httpAdminRoot: '/',
    httpNodeRoot: '/api',

    // Diretório de flows e dados
    userDir: '/data',
    flowFile: 'flows/brewery_flow.json',   // /data/flows/brewery_flow.json via volume

    // Autenticação do editor (opcional — deixe NODERED_ADMIN_USER vazio no .env para desabilitar)
    adminAuth: process.env.NODERED_ADMIN_USER ? {
        type: "credentials",
        users: [{
            username: process.env.NODERED_ADMIN_USER,
            password: require('bcryptjs').hashSync(process.env.NODERED_ADMIN_PASSWORD || 'admin', 8),
            permissions: "*"
        }]
    } : null,

    // Chave de criptografia de credenciais
    credentialSecret: process.env.NODE_RED_CREDENTIAL_SECRET || process.env.NODERED_CREDENTIAL_SECRET || "brewery-iot-secret",

    // Timezone
    functionGlobalContext: {
        env: process.env
    },

    // Nível de log
    logging: {
        console: {
            level: "info",
            metrics: false,
            audit: false
        }
    },

    // Editor ativo
    disableEditor: false,

    // Timeout de execução de funções (ms)
    functionTimeout: 10000,

    exportGlobalContextKeys: false,
};
