create table
  sozu_admin.pagos_stp_raw (
    id integer generated always as identity not null,
    claverastreo text not null,
    stp_id text null,
    fecha_operacion timestamp without time zone not null,
    monto numeric(16, 2) not null,
    cuenta_beneficiario text not null,
    institucion_ordenante text null,
    institucion_beneficiaria text null,
    nombre_ordenante text null,
    tipo_cuenta_ordenante text null,
    cuenta_ordenante text null,
    rfc_curp_ordenante text null,
    nombre_beneficiario text null,
    tipo_cuenta_beneficiario text null,
    nombre_beneficiario2 text null,
    tipo_cuenta_beneficiario2 text null,
    cuenta_beneficiario2 text null,
    rfc_curp_beneficiario text null,
    concepto_pago text null,
    referencia_numerica text null,
    empresa text null,
    tipo_pago text null,
    ts_liquidacion text null,
    folio_codi text null,
    es_pago_aplicado boolean not null default false,
    razon_rechazo text null,
    activo boolean not null default true,
    fecha_creacion timestamp without time zone not null default current_timestamp,
    fecha_actualizacion timestamp without time zone not null default current_timestamp,
    constraint pagos_stp_raw_pkey primary key (id),
    constraint pagos_stp_raw_claverastreo_key unique (claverastreo),
    constraint pagos_stp_raw_stp_id_key unique (stp_id),
    constraint chk_pagos_fecha_no_futuro check ((fecha_operacion <= current_timestamp)),
    constraint chk_pagos_inst_benef check (
      (
        (institucion_beneficiaria is null)
        or (institucion_beneficiaria ~ '^[0-9]{3}$'::text)
      )
    ),
    constraint chk_pagos_inst_ordenante check (
      (
        (institucion_ordenante is null)
        or (institucion_ordenante ~ '^[0-9]{3}$'::text)
      )
    ),
    constraint chk_pagos_aplicado_rechazo check (
      (
        (es_pago_aplicado = false)
        or (razon_rechazo is null)
      )
    ),
    constraint chk_pagos_referencia_numerica check (
      (
        (referencia_numerica is null)
        or (referencia_numerica ~ '^[0-9]{1,20}$'::text)
      )
    ),
    constraint chk_pagos_rfc_benef check (
      (
        (rfc_curp_beneficiario is null)
        or (
          (
            upper(rfc_curp_beneficiario) = rfc_curp_beneficiario
          )
          and (
            rfc_curp_beneficiario ~ '^[A-Z&Ñ]{3,4}[0-9]{6}[A-Z0-9]{3}$'::text
          )
        )
      )
    ),
    constraint chk_pagos_rfc_ordenante check (
      (
        (rfc_curp_ordenante is null)
        or (
          (upper(rfc_curp_ordenante) = rfc_curp_ordenante)
          and (
            rfc_curp_ordenante ~ '^[A-Z&Ñ]{3,4}[0-9]{6}[A-Z0-9]{3}$'::text
          )
        )
      )
    ),
    constraint chk_pagos_monto_nonneg check (
      (
        (monto >= (0)::numeric)
        and (monto = round(monto, 2))
      )
    ),
    constraint chk_pagos_cuenta_benef_formato check ((cuenta_beneficiario ~ '^[0-9]{10,18}$'::text)),
    constraint chk_pagos_cuenta_ord_formato check (
      (
        (cuenta_ordenante is null)
        or (cuenta_ordenante ~ '^[0-9]{10,18}$'::text)
      )
    )
  ) tablespace pg_default;