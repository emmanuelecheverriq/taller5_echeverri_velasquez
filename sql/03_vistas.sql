-- ============================================================================
-- 03_vistas.sql  |  Vistas utiles para el negocio
-- Reproducen los indicadores del libro Excel (pestanas prodMaquina, prodAnio, prodCodigo, etc.)
-- Productividad = 1 - (horas de paro / horas trabajadas), igual que la tabla dinamica del Excel.
-- ============================================================================
SET search_path TO paros, public;

-- V1. Horas de paro por registro (base de las demas vistas, evita multiplicar filas al unir con paro)
CREATE OR REPLACE VIEW v_registro_resumen AS
SELECT r.id_registro,
       r.fecha,
       CAST(EXTRACT(YEAR  FROM r.fecha) AS INTEGER) AS anio,
       CAST(EXTRACT(MONTH FROM r.fecha) AS INTEGER) AS mes,
       m.nombre  AS maquina,
       t.nombre  AS turno,
       p.codigo_seudonimo AS operaria,
       f.nombre  AS referencia,
       r.pacas_producidas,
       r.horas_trabajadas,
       COALESCE(pr.horas_paro, 0) AS horas_paro,
       r.es_sintetico
FROM registro_produccion r
JOIN maquina m ON m.id_maquina = r.id_maquina
JOIN turno   t ON t.id_turno   = r.id_turno
LEFT JOIN persona    p ON p.id_persona    = r.id_persona
LEFT JOIN referencia f ON f.id_referencia = r.id_referencia
LEFT JOIN (SELECT id_registro, SUM(minutos) / 60.0 AS horas_paro
           FROM paro GROUP BY id_registro) pr ON pr.id_registro = r.id_registro;

-- V2. Productividad por maquina, anio y mes (pestana prodMaquina / prodAnio)
CREATE OR REPLACE VIEW v_productividad_mensual AS
SELECT maquina, anio, mes,
       SUM(pacas_producidas)  AS pacas,
       SUM(horas_trabajadas)  AS horas_trabajadas,
       ROUND(SUM(horas_paro), 2) AS horas_paro,
       ROUND(100.0 * (1 - SUM(horas_paro) / NULLIF(SUM(horas_trabajadas), 0)), 2) AS productividad_pct
FROM v_registro_resumen
GROUP BY maquina, anio, mes;

-- V3. Detalle de cada paro con nombres de codigo, subcodigo y area (sin datos personales)
CREATE OR REPLACE VIEW v_paro_detalle AS
SELECT pa.id_paro,
       r.fecha,
       m.nombre AS maquina,
       t.nombre AS turno,
       c.id_codigo_paro,
       c.nombre AS codigo,
       a.nombre AS area_impacto,
       s.codigo_sub,
       s.descripcion AS subcodigo,
       pa.minutos,
       ROUND(pa.minutos / 60.0, 4) AS horas,
       pa.equipo_ejecutor,
       pe.codigo_seudonimo AS persona_involucrada
FROM paro pa
JOIN registro_produccion r ON r.id_registro = pa.id_registro
JOIN maquina m ON m.id_maquina = r.id_maquina
JOIN turno   t ON t.id_turno   = r.id_turno
JOIN codigo_paro c ON c.id_codigo_paro = pa.id_codigo_paro
LEFT JOIN area_impacto  a  ON a.id_area       = c.id_area
LEFT JOIN subcodigo_paro s ON s.id_subcodigo   = pa.id_subcodigo
LEFT JOIN persona       pe ON pe.id_persona    = pa.id_persona;

-- V4. Participacion de cada codigo de paro sobre las horas trabajadas (grafico "% Codigos de paro" del P-MTO-22)
CREATE OR REPLACE VIEW v_participacion_codigo AS
SELECT c.id_codigo_paro,
       c.nombre AS codigo,
       ROUND(SUM(pa.minutos) / 60.0, 2) AS horas_paro,
       ROUND(100.0 * (SUM(pa.minutos) / 60.0) / (SELECT SUM(horas_trabajadas) FROM registro_produccion), 2) AS pct_sobre_horas_trabajadas
FROM codigo_paro c
LEFT JOIN paro pa ON pa.id_codigo_paro = c.id_codigo_paro
GROUP BY c.id_codigo_paro, c.nombre;

-- V5. Horas no trabajadas por maquina, anio, mes y motivo
CREATE OR REPLACE VIEW v_horas_no_trabajadas AS
SELECT ma.nombre AS maquina,
       CAST(EXTRACT(YEAR  FROM pm.fecha) AS INTEGER) AS anio,
       CAST(EXTRACT(MONTH FROM pm.fecha) AS INTEGER) AS mes,
       mo.sistema_codificacion,
       mo.nombre AS motivo,
       COUNT(*) AS eventos,
       SUM(pm.horas_no_trabajadas) AS horas_no_trabajadas
FROM parada_maquina pm
JOIN maquina ma       ON ma.id_maquina = pm.id_maquina
JOIN motivo_parada mo ON mo.id_motivo  = pm.id_motivo
GROUP BY ma.nombre, CAST(EXTRACT(YEAR FROM pm.fecha) AS INTEGER), CAST(EXTRACT(MONTH FROM pm.fecha) AS INTEGER),
         mo.sistema_codificacion, mo.nombre;

-- V6. Control de calidad de datos: registros que se repiten exactamente (posibles duplicados del Excel)
CREATE OR REPLACE VIEW v_control_posibles_duplicados AS
SELECT fecha, maquina, turno, operaria, referencia, pacas_producidas, horas_trabajadas, horas_paro,
       COUNT(*) AS veces
FROM v_registro_resumen
GROUP BY fecha, maquina, turno, operaria, referencia, pacas_producidas, horas_trabajadas, horas_paro
HAVING COUNT(*) > 1;

-- V7. Control de calidad de datos: registros donde el paro supera las horas trabajadas
CREATE OR REPLACE VIEW v_control_paro_mayor_horas AS
SELECT id_registro, fecha, maquina, turno, horas_trabajadas, horas_paro, es_sintetico
FROM v_registro_resumen
WHERE horas_paro > horas_trabajadas AND NOT es_sintetico;
