-- ============================================================================
-- 06_seguridad.sql  |  Proteccion de datos personales (ver docs/07_datos_personales.md)
-- Los nombres reales del personal estan en privado.persona_identidad.
-- Todo el esquema "paros" usa solo seudonimos (OPE-001, MAN-001, ...).
-- ============================================================================

-- Roles (sin login): se asignan despues a los usuarios reales
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_analista') THEN
        CREATE ROLE rol_analista NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_rrhh') THEN
        CREATE ROLE rol_rrhh NOLOGIN;
    END IF;
END
$$;

-- Nadie ve el esquema privado por defecto
REVOKE ALL ON SCHEMA privado FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA privado FROM PUBLIC;

-- Analistas: leen el esquema de negocio (solo seudonimos), no tocan el esquema privado
GRANT USAGE ON SCHEMA paros TO rol_analista;
GRANT SELECT ON ALL TABLES IN SCHEMA paros TO rol_analista;

-- Recursos humanos (o quien autorice la empresa): unico rol que puede unir seudonimo con nombre real
GRANT USAGE ON SCHEMA paros, privado TO rol_rrhh;
GRANT SELECT ON ALL TABLES IN SCHEMA paros TO rol_rrhh;
GRANT SELECT, INSERT, UPDATE, DELETE ON privado.persona_identidad TO rol_rrhh;

-- Comprobacion rapida (como superusuario): lista los permisos del esquema privado
SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'privado'
ORDER BY grantee, privilege_type;
