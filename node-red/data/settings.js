module.exports = {
    // URL base do editor
    httpAdminRoot: '/',
    httpNodeRoot: '/api',

    // Diretório de flows e dados
    userDir: '/data',
    flowFile: 'flows/brewery_flow.json',

    // Autenticação do editor
    adminAuth: process.env.NODERED_ADMIN_USER ? {
        type: "credentials",
        users: [{
            username: process.env.NODERED_ADMIN_USER,
            password: process.env.NODERED_ADMIN_PASSWORD,
            permissions: "*"
        }]
    } : null,

    // Chave de criptografia de credenciais
    credentialSecret: process.env.NODERED_CREDENTIAL_SECRET || "brewery-iot-secret",

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

    // Editor — desabilita em produção
    disableEditor: false,

    // Timeout de execução de funções (ms)
    functionTimeout: 10000,

    // Exportar variáveis de ambiente para nodes
    exportGlobalContextKeys: false,
};
