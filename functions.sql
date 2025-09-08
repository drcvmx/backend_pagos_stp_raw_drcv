-- Crear funciones RPC para acceder al esquema sozu_admin desde Supabase
-- Estas funciones deben ejecutarse en el esquema public para ser accesibles
-- Eliminar función existente si existe
DROP FUNCTION IF EXISTS public.insertar_pago_stp;

-- Crear función proxy en public que llama a sozu_admin
CREATE OR REPLACE FUNCTION public.insertar_pago_stp(
    p_stp_id text, 
    p_monto numeric, 
    p_nombre_ordenante text, 
    p_concepto_pago text, 
    p_institucion_beneficiaria text, 
    p_nombre_beneficiario text, 
    p_ts_liquidacion text, 
    p_cuenta_beneficiario text, 
    p_tipo_pago text, 
    p_tipo_cuenta_beneficiario text, 
    p_cuenta_ordenante text, 
    p_claverastreo text, 
    p_institucion_ordenante text, 
    p_rfc_curp_beneficiario text, 
    p_tipo_cuenta_ordenante text, 
    p_fecha_operacion timestamp without time zone, 
    p_empresa text, 
    p_referencia_numerica text, 
    p_rfc_curp_ordenante text, 
    p_nombre_beneficiario2 text DEFAULT NULL::text, 
    p_tipo_cuenta_beneficiario2 text DEFAULT NULL::text, 
    p_cuenta_beneficiario2 text DEFAULT NULL::text, 
    p_folio_codi text DEFAULT NULL::text
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
BEGIN
    -- Insertar directamente en la tabla de sozu_admin
    INSERT INTO sozu_admin.pagos_stp_raw (
        stp_id, monto, nombre_ordenante, concepto_pago, institucion_beneficiaria,
        nombre_beneficiario, ts_liquidacion, cuenta_beneficiario, tipo_pago,
        tipo_cuenta_beneficiario, cuenta_ordenante, claverastreo,
        institucion_ordenante, rfc_curp_beneficiario, tipo_cuenta_ordenante,
        fecha_operacion, empresa, referencia_numerica, rfc_curp_ordenante,
        nombre_beneficiario2, tipo_cuenta_beneficiario2, cuenta_beneficiario2, folio_codi,
        es_pago_aplicado, activo
    ) VALUES (
        p_stp_id, p_monto, p_nombre_ordenante, p_concepto_pago, p_institucion_beneficiaria,
        p_nombre_beneficiario, p_ts_liquidacion, p_cuenta_beneficiario, p_tipo_pago,
        p_tipo_cuenta_beneficiario, p_cuenta_ordenante, p_claverastreo,
        p_institucion_ordenante, p_rfc_curp_beneficiario, p_tipo_cuenta_ordenante,
        p_fecha_operacion, p_empresa, p_referencia_numerica, p_rfc_curp_ordenante,
        p_nombre_beneficiario2, p_tipo_cuenta_beneficiario2, p_cuenta_beneficiario2, p_folio_codi,
        false, true
    );
    
    result := json_build_object(
        'success', true,
        'message', 'Pago STP insertado correctamente',
        'stp_id', p_stp_id,
        'claverastreo', p_claverastreo
    );
    
    RETURN result;
EXCEPTION
    WHEN unique_violation THEN
        result := json_build_object(
            'success', false,
            'error', 'duplicate',
            'message', 'El pago con este ID ya existe'
        );
        RETURN result;
    WHEN OTHERS THEN
        result := json_build_object(
            'success', false,
            'error', SQLSTATE,
            'message', SQLERRM
        );
        RETURN result;
END;
$$;

-- Otorgar permisos
GRANT EXECUTE ON FUNCTION public.insertar_pago_stp TO anon, authenticated;

-- 1. Función para insertar pago STP
CREATE OR REPLACE FUNCTION sozu_admin.insertar_pago_stp(
    p_id BIGINT,
    p_monto NUMERIC(15,2),
    p_nombre_ordenante TEXT,
    p_concepto_pago TEXT,
    p_institucion_beneficiaria BIGINT,
    p_nombre_beneficiario TEXT,
    p_ts_liquidacion BIGINT,
    p_cuenta_beneficiario TEXT,
    p_tipo_pago BIGINT,
    p_tipo_cuenta_beneficiario BIGINT,
    p_cuenta_ordenante TEXT,
    p_clave_rastreo TEXT,  -- Cambiar a claveRastreo
    p_institucion_ordenante BIGINT,
    p_rfc_curp_beneficiario TEXT,
    p_tipo_cuenta_ordenante BIGINT,
    p_fecha_operacion TEXT,
    p_empresa TEXT,
    p_referencia_numerica BIGINT,
    p_rfc_curp_ordenante TEXT
)
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    INSERT INTO sozu_admin.pagos_stp_raw (
        id, monto, nombreOrdenante, conceptoPago, institucionBeneficiaria,
        nombreBeneficiario, tsLiquidacion, cuentaBeneficiario, tipoPago,
        tipoCuentaBeneficiario, cuentaOrdenante, claveRastreo,  -- Usar claveRastreo
        institucionOrdenante, rfcCurpBeneficiario, tipoCuentaOrdenante,
        fechaOperacion, empresa, referenciaNumerica, rfcCurpOrdenante
    ) VALUES (
        p_id, p_monto, p_nombre_ordenante, p_concepto_pago, p_institucion_beneficiaria,
        p_nombre_beneficiario, p_ts_liquidacion, p_cuenta_beneficiario, p_tipo_pago,
        p_tipo_cuenta_beneficiario, p_cuenta_ordenante, p_clave_rastreo,
        p_institucion_ordenante, p_rfc_curp_beneficiario, p_tipo_cuenta_ordenante,
        p_fecha_operacion, p_empresa, p_referencia_numerica, p_rfc_curp_ordenante
    );
    
    result := json_build_object(
        'success', true,
        'message', 'Pago STP insertado correctamente',
        'id', p_id,
        'claveRastreo', p_clave_rastreo
    );
    
    RETURN result;
EXCEPTION
    WHEN OTHERS THEN
        result := json_build_object(
            'success', false,
            'error', SQLSTATE,
            'message', SQLERRM
        );
        RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 2. Función para verificar si existe un pago
CREATE OR REPLACE FUNCTION public.verificar_pago_existe(p_clave_rastreo VARCHAR)
RETURNS JSON AS $$
DECLARE
    resultado JSON;
    existe BOOLEAN := FALSE;
    pago_id BIGINT;
BEGIN
    SELECT id INTO pago_id 
    FROM sozu_admin.pagos_stp_raw 
    WHERE clave_rastreo = p_clave_rastreo 
    LIMIT 1;

    IF FOUND THEN
        existe := TRUE;
    END IF;

    resultado := json_build_object(
        'existe', existe,
        'id', pago_id,
        'clave_rastreo', p_clave_rastreo
    );

    RETURN resultado;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Función para obtener estadísticas
CREATE OR REPLACE FUNCTION public.obtener_stats_pagos()
RETURNS JSON AS $$
DECLARE
    resultado JSON;
    total_transacciones INTEGER;
    monto_total DECIMAL;
BEGIN
    SELECT 
        COUNT(*), 
        COALESCE(SUM(monto), 0)
    INTO total_transacciones, monto_total
    FROM sozu_admin.pagos_stp_raw
    WHERE activo = true;

    resultado := json_build_object(
        'total_transacciones', total_transacciones,
        'monto_total', monto_total,
        'timestamp', EXTRACT(EPOCH FROM NOW())
    );

    RETURN resultado;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Función para obtener transacciones recientes
CREATE OR REPLACE FUNCTION public.obtener_transacciones_recientes(p_limit INTEGER DEFAULT 10, p_offset INTEGER DEFAULT 0)
RETURNS JSON AS $$
DECLARE
    resultado JSON;
    transacciones JSON;
BEGIN
    SELECT json_agg(
        json_build_object(
            'id', id,
            'clave_rastreo', clave_rastreo,
            'stp_id', stp_id,
            'monto', monto,
            'empresa', empresa,
            'fecha_operacion', fecha_operacion,
            'fecha_creacion', fecha_creacion,
            'nombre_ordenante', nombre_ordenante,
            'nombre_beneficiario', nombre_beneficiario
        )
    ) INTO transacciones
    FROM (
        SELECT *
        FROM sozu_admin.pagos_stp_raw
        WHERE activo = true
        ORDER BY fecha_creacion DESC
        LIMIT p_limit OFFSET p_offset
    ) t;

    resultado := json_build_object(
        'success', true,
        'data', COALESCE(transacciones, '[]'::json),
        'limit', p_limit,
        'offset', p_offset
    );

    RETURN resultado;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Otorgar permisos para que puedan ser ejecutadas
GRANT EXECUTE ON FUNCTION public.insertar_pago_stp TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.verificar_pago_existe TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.obtener_stats_pagos TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.obtener_transacciones_recientes TO anon, authenticated, service_role;