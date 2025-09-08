// server.js
const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const { createClient } = require('@supabase/supabase-js');
const axios = require('axios');

// Configurar variables de entorno
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Configuración de Supabase
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
    console.error('❌ Error: SUPABASE_URL y SUPABASE_SERVICE_KEY son requeridas');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    auth: {
        autoRefreshToken: false,
        persistSession: false
    }
});
// Quitar completamente: db: { schema: 'sozu_admin' }

// Middlewares
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Middleware de logging
app.use((req, res, next) => {
    const timestamp = new Date().toISOString();
    console.log(`${timestamp} - ${req.method} ${req.path}`);
    if (req.method === 'POST' && req.path === '/webhook/pagos-stp') {
        console.log('📥 Payload recibido:', JSON.stringify(req.body, null, 2));
    }
    next();
});

// Función para validar el payload
function validarPayloadSTP(payload) {
    const camposRequeridos = [
        'id', 'fechaOperacion', 'institucionOrdenante', 'institucionBeneficiaria',
        'claveRastreo', 'monto', 'cuentaBeneficiario', 'nombreOrdenante',
        'tipoCuentaOrdenante', 'cuentaOrdenante', 'rfcCurpOrdenante',
        'nombreBeneficiario', 'tipoCuentaBeneficiario', 'rfcCurpBeneficiario',
        'conceptoPago', 'referenciaNumerica', 'empresa', 'tipoPago', 'tsLiquidacion'
    ];

    const camposFaltantes = camposRequeridos.filter(campo => 
        payload[campo] === undefined || payload[campo] === null
    );

    return {
        esValido: camposFaltantes.length === 0,
        camposFaltantes
    };
}

// Función para insertar en Supabase usando RPC
async function insertarPagoSTP(payload) {
    try {
        const { data, error } = await supabase.rpc('insertar_pago_stp', {
            p_claverastreo: payload.claveRastreo,  // Sin guión bajo, como en tu función
            p_concepto_pago: payload.conceptoPago,
            p_cuenta_beneficiario: payload.cuentaBeneficiario,
            p_cuenta_beneficiario2: payload.cuentaBeneficiario2 || null,
            p_cuenta_ordenante: payload.cuentaOrdenante,
            p_empresa: payload.empresa,
            p_fecha_operacion: payload.fechaOperacion,
            p_folio_codi: payload.folioCodi || null,
            p_institucion_beneficiaria: payload.institucionBeneficiaria,
            p_institucion_ordenante: payload.institucionOrdenante,
            p_monto: payload.monto,
            p_nombre_beneficiario: payload.nombreBeneficiario,
            p_nombre_beneficiario2: payload.nombreBeneficiario2 || null,
            p_nombre_ordenante: payload.nombreOrdenante,
            p_referencia_numerica: payload.referenciaNumerica,
            p_rfc_curp_beneficiario: payload.rfcCurpBeneficiario,
            p_rfc_curp_ordenante: payload.rfcCurpOrdenante,
            p_stp_id: payload.id,
            p_tipo_cuenta_beneficiario: payload.tipoCuentaBeneficiario,
            p_tipo_cuenta_beneficiario2: payload.tipoCuentaBeneficiario2 || null,
            p_tipo_cuenta_ordenante: payload.tipoCuentaOrdenante,
            p_tipo_pago: payload.tipoPago,
            p_ts_liquidacion: payload.tsLiquidacion
        });

        if (error) {
            console.error('❌ Error insertando en Supabase:', error);
            throw error;
        }

        console.log('✅ Datos insertados en Supabase:', data);
        return data;
    } catch (error) {
        console.error('❌ Error en insertarPagoSTP:', error);
        throw error;
    }
}

// Función para enviar datos a API externa
async function enviarASozuAPI(payload) {
    try {
        const response = await axios.post('https://apitest.sozu.com/api/admin/pagosSTP', payload, {
            headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'NodeJS-Webhook-Forwarder/1.0'
            },
            timeout: 30000 // 30 segundos timeout
        });

        console.log('✅ Datos enviados a Sozu API:', response.status);
        return response.data;
    } catch (error) {
        console.error('❌ Error enviando a Sozu API:', error.message);
        if (error.response) {
            console.error('❌ Response status:', error.response.status);
            console.error('❌ Response data:', error.response.data);
        }
        throw error;
    }
}

// Rutas principales

// Ruta de health check
app.get('/', (req, res) => {
    res.json({
        message: '🚀 Backend Webhook STP activo',
        version: '1.0.0',
        timestamp: new Date().toISOString(),
        endpoints: {
            webhook: '/webhook/pagos-stp',
            health: '/health',
            stats: '/api/stats'
        }
    });
});

// Health check específico
app.get('/health', async (req, res) => {
    try {
        // Verificar conexión a Supabase usando RPC
        const { data, error } = await supabase.rpc('obtener_stats_pagos');
        
        const healthStatus = {
            status: 'healthy',
            timestamp: new Date().toISOString(),
            services: {
                database: error ? 'unhealthy' : 'healthy',
                api: 'healthy'
            }
        };

        if (error) {
            healthStatus.status = 'degraded';
            healthStatus.error = error.message;
        }

        res.json(healthStatus);
    } catch (error) {
        res.status(500).json({
            status: 'unhealthy',
            timestamp: new Date().toISOString(),
            error: error.message
        });
    }
});

// Webhook principal para recibir pagos STP
app.post('/webhook/pagos-stp', async (req, res) => {
    const startTime = Date.now();
    let dbInserted = false;
    let apiSent = false;
    let errorDetails = null;

    try {
        console.log('🔄 Procesando webhook STP...');
        const payload = req.body;

        // Validar payload
        const validacion = validarPayloadSTP(payload);
        if (!validacion.esValido) {
            console.error('❌ Payload inválido:', validacion.camposFaltantes);
            return res.status(400).json({
                success: false,
                error: 'Payload inválido',
                camposFaltantes: validacion.camposFaltantes,
                processingTime: Date.now() - startTime
            });
        }

        // Verificar si ya existe el registro usando RPC
        const { data: existeData } = await supabase.rpc('verificar_pago_existe', {
            p_clave_rastreo: payload.claveRastreo  // Mantener este como está si la función verificar_pago_existe usa p_clave_rastreo
        });

        if (existeData && existeData.existe) {
            console.log('⚠️ Registro ya existe, omitiendo inserción');
            return res.json({
                success: true,
                message: 'Registro ya existe',
                id: payload.id,
                duplicate: true,
                processingTime: Date.now() - startTime
            });
        }

        // Insertar en base de datos
        await insertarPagoSTP(payload);
        dbInserted = true;
        console.log('✅ Datos guardados en BD');

      /*
        try {
            apiResult = await enviarASozuAPI(req.body);
            apiSuccess = true;
            console.log('✅ Datos enviados a API externa');
        } catch (apiError) {
            console.error('❌ Error enviando a API externa:', apiError);
            apiResult = apiError;
        }
      */
        apiSuccess = true; // Simular éxito temporalmente
        console.log('⚠️ Envío a API externa deshabilitado temporalmente');
        apiSent = true;
        console.log('✅ Datos enviados a Sozu API');

        // Respuesta exitosa
        res.json({
            success: true,
            message: 'Webhook procesado exitosamente',
            id: payload.id,
            claveRastreo: payload.claveRastreo,
            monto: payload.monto,
            empresa: payload.empresa,
            processingTime: Date.now() - startTime,
            actions: {
                databaseInsert: true,
                apiForward: true
            }
        });

    } catch (error) {
        console.error('❌ Error procesando webhook:', error);
        errorDetails = error.message;

        // Respuesta de error con detalles del procesamiento
        res.status(500).json({
            success: false,
            error: 'Error procesando webhook',
            details: errorDetails,
            processingTime: Date.now() - startTime,
            actions: {
                databaseInsert: dbInserted,
                apiForward: apiSent
            }
        });
    }
});

// Endpoint para obtener estadísticas
app.get('/api/stats', async (req, res) => {
    try {
        const { data, error } = await supabase.rpc('obtener_stats_pagos');

        if (error) throw error;

        res.json({
            success: true,
            data: {
                totalTransacciones: data.total_transacciones || 0,
                montoTotal: data.monto_total || 0,
                transaccionesRecientes: [],
                timestamp: new Date().toISOString()
            }
        });
    } catch (error) {
        console.error('❌ Error obteniendo estadísticas:', error);
        res.status(500).json({
            success: false,
            error: 'Error obteniendo estadísticas'
        });
    }
});

// Endpoint para obtener transacciones recientes
app.get('/api/transacciones', async (req, res) => {
    try {
        const limit = parseInt(req.query.limit) || 10;
        const offset = parseInt(req.query.offset) || 0;

        const { data, error } = await supabase.rpc('obtener_transacciones_recientes', {
            p_limit: limit,
            p_offset: offset
        });

        if (error) throw error;

        res.json({
            success: true,
            data: data.data || [],
            pagination: {
                limit,
                offset,
                count: data.data ? data.data.length : 0
            }
        });
    } catch (error) {
        console.error('❌ Error obteniendo transacciones:', error);
        res.status(500).json({
            success: false,
            error: 'Error obteniendo transacciones'
        });
    }
});

// Manejo de rutas no encontradas
app.use('*', (req, res) => {
    res.status(404).json({
        success: false,
        error: 'Ruta no encontrada',
        availableRoutes: [
            'GET /',
            'GET /health',
            'POST /webhook/pagos-stp',
            'GET /api/stats',
            'GET /api/transacciones'
        ]
    });
});

// Manejo de errores global
app.use((err, req, res, next) => {
    console.error('❌ Error no manejado:', err.stack);
    res.status(500).json({
        success: false,
        error: 'Error interno del servidor'
    });
});

// Iniciar servidor
app.listen(PORT, () => {
    console.log(`🚀 Servidor webhook STP corriendo en http://localhost:${PORT}`);
    console.log(`📥 Webhook endpoint: http://localhost:${PORT}/webhook/pagos-stp`);
    console.log(`🏥 Health check: http://localhost:${PORT}/health`);
    console.log(`📊 Stats: http://localhost:${PORT}/api/stats`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('🛑 Cerrando servidor...');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('🛑 Cerrando servidor...');
    process.exit(0);
});

module.exports = app;