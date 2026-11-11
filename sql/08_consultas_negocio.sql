-- ============================================================================
-- 08_consultas_negocio.sql  |  17 consultas que responden preguntas reales del negocio
-- Productividad = 1 - (horas de paro / horas trabajadas), igual que el Excel.
-- Cada consulta indica que tipos de JOIN, agregaciones, subconsultas y filtros usa.
-- ============================================================================
SET search_path TO paros, public;

-- ----------------------------------------------------------------------------
-- Q1. Porcentaje de productividad por maquina y por mes del 2024
-- Usa: vista (JOIN interno + LEFT JOIN + subconsulta), SUM, GROUP BY, filtro por rango de fechas
-- ----------------------------------------------------------------------------
SELECT maquina, mes,
       SUM(horas_trabajadas)                                                   AS horas_trabajadas,
       ROUND(SUM(horas_paro), 2)                                               AS horas_paro,
       ROUND(100.0 * (1 - SUM(horas_paro) / NULLIF(SUM(horas_trabajadas), 0)), 1) AS productividad_pct
FROM v_registro_resumen
WHERE fecha BETWEEN '2024-01-01' AND '2024-12-31'
GROUP BY maquina, mes
ORDER BY maquina, mes;

-- ----------------------------------------------------------------------------
-- Q2. Comparativo entre anios: productividad mensual de cada maquina, 2023 vs 2024
-- Usa: agregacion condicional (CASE), GROUP BY, columna calculada de diferencia
-- ----------------------------------------------------------------------------
SELECT maquina, mes,
       ROUND(100.0 * (1 - SUM(CASE WHEN anio = 2023 THEN horas_paro END)
                          / NULLIF(SUM(CASE WHEN anio = 2023 THEN horas_trabajadas END), 0)), 1) AS prod_2023,
       ROUND(100.0 * (1 - SUM(CASE WHEN anio = 2024 THEN horas_paro END)
                          / NULLIF(SUM(CASE WHEN anio = 2024 THEN horas_trabajadas END), 0)), 1) AS prod_2024,
       ROUND(100.0 * (1 - SUM(CASE WHEN anio = 2024 THEN horas_paro END)
                          / NULLIF(SUM(CASE WHEN anio = 2024 THEN horas_trabajadas END), 0))
           - 100.0 * (1 - SUM(CASE WHEN anio = 2023 THEN horas_paro END)
                          / NULLIF(SUM(CASE WHEN anio = 2023 THEN horas_trabajadas END), 0)), 1) AS diferencia_puntos
FROM v_registro_resumen
WHERE fecha BETWEEN '2023-01-01' AND '2024-12-31'
GROUP BY maquina, mes
ORDER BY maquina, mes;

-- ----------------------------------------------------------------------------
-- Q3. Participacion porcentual de cada codigo de paro (sobre las horas trabajadas totales)
-- Usa: LEFT JOIN (muestra codigos sin paros), SUM, GROUP BY, subconsulta escalar, funcion de ventana
-- ----------------------------------------------------------------------------
SELECT c.id_codigo_paro,
       c.nombre AS codigo_de_paro,
       ROUND(COALESCE(SUM(pa.minutos), 0) / 60.0, 1) AS horas_paro,
       ROUND(100.0 * COALESCE(SUM(pa.minutos), 0) / 60.0
             / (SELECT SUM(horas_trabajadas) FROM registro_produccion), 2) AS pct_sobre_horas_trabajadas,
       ROUND(100.0 * COALESCE(SUM(pa.minutos), 0) / SUM(COALESCE(SUM(pa.minutos), 0)) OVER (), 2) AS pct_del_total_de_paros
FROM codigo_paro c
LEFT JOIN paro pa ON pa.id_codigo_paro = c.id_codigo_paro
GROUP BY c.id_codigo_paro, c.nombre
ORDER BY horas_paro DESC;

-- ----------------------------------------------------------------------------
-- Q4a. Detalle por subcodigo del codigo 01 (Falla electromecanica), como el grafico del P-MTO-22
-- Usa: JOIN interno, JOIN a si misma (sistema padre), SUM, GROUP BY, ventana para el porcentaje
-- ----------------------------------------------------------------------------
SELECT COALESCE(padre.codigo_sub || ' ' || padre.descripcion, s.codigo_sub || ' ' || s.descripcion) AS sistema,
       s.codigo_sub, s.descripcion AS componente,
       COUNT(*)                                   AS eventos,
       ROUND(SUM(pa.minutos) / 60.0, 1)           AS horas,
       ROUND(100.0 * SUM(pa.minutos) / SUM(SUM(pa.minutos)) OVER (), 1) AS pct_del_codigo
FROM paro pa
JOIN subcodigo_paro s        ON s.id_subcodigo = pa.id_subcodigo
LEFT JOIN subcodigo_paro padre ON padre.id_subcodigo = s.id_subcodigo_padre
WHERE pa.id_codigo_paro = 1
GROUP BY padre.codigo_sub, padre.descripcion, s.codigo_sub, s.descripcion
ORDER BY horas DESC;

-- Q4b. Detalle por subcodigo del codigo 03 (Novedad en sistemas de potencia). Incluye "sin subcodigo".
-- Usa: LEFT JOIN, COALESCE, SUM, GROUP BY, ventana
SELECT COALESCE(s.codigo_sub || ' ' || s.descripcion, '(sin subcodigo registrado)') AS subcodigo,
       COUNT(*) AS eventos,
       ROUND(SUM(pa.minutos) / 60.0, 1) AS horas,
       ROUND(100.0 * SUM(pa.minutos) / SUM(SUM(pa.minutos)) OVER (), 1) AS pct_del_codigo
FROM paro pa
LEFT JOIN subcodigo_paro s ON s.id_subcodigo = pa.id_subcodigo
WHERE pa.id_codigo_paro = 3
GROUP BY s.codigo_sub, s.descripcion
ORDER BY horas DESC;

-- Q4c. Codigo 05 (Ajuste operativo): horas por subcodigo separadas por quien hizo el ajuste
-- Usa: agregacion condicional, GROUP BY, JOIN interno + LEFT JOIN
SELECT COALESCE(s.codigo_sub || ' ' || s.descripcion, 'Sin especificar') AS subcodigo,
       ROUND(SUM(CASE WHEN pa.equipo_ejecutor = 'OPERARIOS'      THEN pa.minutos ELSE 0 END) / 60.0, 1) AS horas_operarios,
       ROUND(SUM(CASE WHEN pa.equipo_ejecutor = 'MANTENIMIENTO'  THEN pa.minutos ELSE 0 END) / 60.0, 1) AS horas_mantenimiento,
       ROUND(SUM(CASE WHEN pa.equipo_ejecutor IS NULL            THEN pa.minutos ELSE 0 END) / 60.0, 1) AS horas_sin_dato,
       ROUND(SUM(pa.minutos) / 60.0, 1) AS horas_total
FROM paro pa
JOIN codigo_paro c         ON c.id_codigo_paro = pa.id_codigo_paro
LEFT JOIN subcodigo_paro s ON s.id_subcodigo   = pa.id_subcodigo
WHERE c.id_codigo_paro = 5
GROUP BY s.codigo_sub, s.descripcion
ORDER BY horas_total DESC;

-- ----------------------------------------------------------------------------
-- Q5. Comparacion del desempeno entre turnos (solo registros con turno conocido y horas trabajadas)
-- Usa: JOIN, SUM, GROUP BY, HAVING, filtro por rango de fechas
-- ----------------------------------------------------------------------------
SELECT turno,
       COUNT(*)                          AS registros,
       SUM(pacas_producidas)             AS pacas,
       SUM(horas_trabajadas)             AS horas_trabajadas,
       ROUND(1.0 * SUM(pacas_producidas) / NULLIF(SUM(horas_trabajadas), 0), 2) AS pacas_por_hora,
       ROUND(100.0 * (1 - SUM(horas_paro) / NULLIF(SUM(horas_trabajadas), 0)), 1) AS productividad_pct
FROM v_registro_resumen
WHERE fecha BETWEEN '2024-01-01' AND '2025-03-31'
  AND turno <> 'SIN ESPECIFICAR'
GROUP BY turno
HAVING SUM(horas_trabajadas) > 0
ORDER BY productividad_pct DESC;

-- ----------------------------------------------------------------------------
-- Q6. Las 10 referencias con mayor produccion y su rendimiento (pacas por hora)
-- Usa: JOIN interno, SUM, GROUP BY, HAVING (minimo de horas para que el promedio sea confiable)
-- ----------------------------------------------------------------------------
SELECT f.nombre AS referencia,
       COUNT(*)                     AS registros,
       SUM(r.pacas_producidas)      AS pacas,
       SUM(r.horas_trabajadas)      AS horas,
       ROUND(1.0 * SUM(r.pacas_producidas) / SUM(r.horas_trabajadas), 2) AS pacas_por_hora
FROM registro_produccion r
JOIN referencia f ON f.id_referencia = r.id_referencia
WHERE r.fecha >= '2024-01-01'
GROUP BY f.nombre
HAVING SUM(r.horas_trabajadas) >= 100
ORDER BY pacas DESC
LIMIT 10;

-- ----------------------------------------------------------------------------
-- Q7. Los 3 codigos de paro que mas tiempo quitan a cada maquina
-- Usa: CTE, JOINs, SUM, GROUP BY, funcion de ventana RANK() con PARTITION BY
-- ----------------------------------------------------------------------------
WITH horas_por_codigo AS (
    SELECT m.nombre AS maquina, c.nombre AS codigo, SUM(pa.minutos) / 60.0 AS horas
    FROM paro pa
    JOIN registro_produccion r ON r.id_registro = pa.id_registro
    JOIN maquina m             ON m.id_maquina  = r.id_maquina
    JOIN codigo_paro c         ON c.id_codigo_paro = pa.id_codigo_paro
    WHERE r.fecha BETWEEN '2024-01-01' AND '2024-12-31'
    GROUP BY m.nombre, c.nombre
), ranking AS (
    SELECT maquina, codigo, horas,
           RANK() OVER (PARTITION BY maquina ORDER BY horas DESC) AS posicion
    FROM horas_por_codigo
)
SELECT maquina, posicion, codigo, ROUND(horas, 1) AS horas
FROM ranking
WHERE posicion <= 3
ORDER BY maquina, posicion;

-- ----------------------------------------------------------------------------
-- Q8. Meses-maquina con productividad por debajo del promedio general
-- Usa: vista, GROUP BY, HAVING con subconsulta escalar
-- ----------------------------------------------------------------------------
SELECT maquina, anio, mes,
       ROUND(100.0 * (1 - SUM(horas_paro) / SUM(horas_trabajadas)), 1) AS productividad_pct
FROM v_registro_resumen
GROUP BY maquina, anio, mes
HAVING SUM(horas_trabajadas) > 0
   AND (1 - SUM(horas_paro) / SUM(horas_trabajadas))
       < (SELECT 1 - SUM(horas_paro) / SUM(horas_trabajadas) FROM v_registro_resumen)
ORDER BY productividad_pct
LIMIT 15;

-- ----------------------------------------------------------------------------
-- Q9. Ajustes operativos (codigo 05) por persona involucrada: quien interviene mas (solo seudonimos)
-- Usa: JOIN interno, SUM, GROUP BY, HAVING
-- ----------------------------------------------------------------------------
SELECT pe.codigo_seudonimo, pe.tipo_persona,
       COUNT(*) AS intervenciones,
       ROUND(SUM(pa.minutos) / 60.0, 1) AS horas
FROM paro pa
JOIN persona pe ON pe.id_persona = pa.id_persona
WHERE pa.id_codigo_paro = 5
GROUP BY pe.codigo_seudonimo, pe.tipo_persona
HAVING COUNT(*) >= 20
ORDER BY horas DESC;

-- ----------------------------------------------------------------------------
-- Q10. Horas en que las maquinas no trabajaron, por motivo y semestre del 2023 (parada_maquina)
-- Usa: JOIN, SUM, COUNT, GROUP BY, HAVING, rango de fechas
-- ----------------------------------------------------------------------------
SELECT mo.sistema_codificacion, mo.nombre AS motivo,
       COUNT(*) AS eventos,
       SUM(pm.horas_no_trabajadas) AS horas_no_trabajadas,
       ROUND(AVG(pm.horas_no_trabajadas), 1) AS promedio_por_evento
FROM parada_maquina pm
JOIN motivo_parada mo ON mo.id_motivo = pm.id_motivo
WHERE pm.fecha BETWEEN '2023-01-01' AND '2023-12-31'
GROUP BY mo.sistema_codificacion, mo.nombre
HAVING SUM(pm.horas_no_trabajadas) > 100
ORDER BY horas_no_trabajadas DESC;

-- ----------------------------------------------------------------------------
-- Q11. Registros de produccion sin ningun paro registrado (posible falta de digitacion)
-- Usa: NOT EXISTS (subconsulta correlacionada), JOINs, filtro por fechas
-- ----------------------------------------------------------------------------
SELECT m.nombre AS maquina, COUNT(*) AS registros_sin_paros, SUM(r.horas_trabajadas) AS horas_sin_paros
FROM registro_produccion r
JOIN maquina m ON m.id_maquina = r.id_maquina
WHERE r.fecha >= '2024-01-01'
  AND r.horas_trabajadas > 0
  AND NOT EXISTS (SELECT 1 FROM paro pa WHERE pa.id_registro = r.id_registro)
GROUP BY m.nombre
ORDER BY registros_sin_paros DESC;

-- ----------------------------------------------------------------------------
-- Q12. Subcodigos del catalogo que nunca se han usado (RIGHT JOIN desde paro hacia subcodigo_paro)
-- Usa: RIGHT JOIN, GROUP BY, HAVING
-- ----------------------------------------------------------------------------
SELECT s.codigo_sub, s.descripcion, COUNT(pa.id_paro) AS veces_usado
FROM paro pa
RIGHT JOIN subcodigo_paro s ON s.id_subcodigo = pa.id_subcodigo
GROUP BY s.codigo_sub, s.descripcion
HAVING COUNT(pa.id_paro) = 0
ORDER BY s.codigo_sub;

-- ----------------------------------------------------------------------------
-- Q13. Cobertura de datos: meses con registros de produccion vs meses con paradas de maquina
-- Usa: FULL OUTER JOIN entre dos agregaciones (CTE)
-- ----------------------------------------------------------------------------
WITH prod AS (
    SELECT anio, mes, COUNT(*) AS registros FROM v_registro_resumen GROUP BY anio, mes
), par AS (
    SELECT anio, mes, SUM(eventos) AS paradas FROM v_horas_no_trabajadas GROUP BY anio, mes
)
SELECT COALESCE(prod.anio, par.anio) AS anio, COALESCE(prod.mes, par.mes) AS mes,
       prod.registros, par.paradas
FROM prod
FULL OUTER JOIN par ON par.anio = prod.anio AND par.mes = prod.mes
ORDER BY 1, 2;

-- ----------------------------------------------------------------------------
-- Q14. Variacion mensual de la productividad de cada maquina contra el mes anterior
-- Usa: CTE, agregacion, funcion de ventana LAG
-- ----------------------------------------------------------------------------
WITH mensual AS (
    SELECT maquina, anio, mes,
           100.0 * (1 - SUM(horas_paro) / NULLIF(SUM(horas_trabajadas), 0)) AS prod
    FROM v_registro_resumen
    WHERE fecha BETWEEN '2024-01-01' AND '2024-12-31'
    GROUP BY maquina, anio, mes
)
SELECT maquina, anio, mes,
       ROUND(prod, 1) AS productividad_pct,
       ROUND(prod - LAG(prod) OVER (PARTITION BY maquina ORDER BY anio, mes), 1) AS cambio_vs_mes_anterior
FROM mensual
ORDER BY maquina, anio, mes;

-- ----------------------------------------------------------------------------
-- Q15. Paro por area de impacto (Mantenimiento, Produccion, Calidad, ...)
-- Usa: JOIN interno, LEFT JOIN, SUM, GROUP BY, rango de fechas
-- ----------------------------------------------------------------------------
SELECT COALESCE(a.nombre, '(sin area en el catalogo)') AS area_impacto,
       COUNT(DISTINCT c.id_codigo_paro) AS codigos,
       ROUND(SUM(pa.minutos) / 60.0, 1) AS horas_paro,
       ROUND(100.0 * SUM(pa.minutos) / SUM(SUM(pa.minutos)) OVER (), 1) AS pct_del_total
FROM paro pa
JOIN registro_produccion r ON r.id_registro = pa.id_registro
JOIN codigo_paro c         ON c.id_codigo_paro = pa.id_codigo_paro
LEFT JOIN area_impacto a   ON a.id_area = c.id_area
WHERE r.fecha BETWEEN '2024-01-01' AND '2025-03-31'
GROUP BY a.nombre
ORDER BY horas_paro DESC;

-- ----------------------------------------------------------------------------
-- Q16. Calidad de datos: registros donde el tiempo de paro supera las horas trabajadas (subconsulta en FROM)
-- Usa: vista de control + subconsulta + agregacion
-- ----------------------------------------------------------------------------
SELECT x.maquina, COUNT(*) AS registros_con_problema, ROUND(MAX(x.horas_paro - x.horas_trabajadas), 1) AS mayor_exceso_horas
FROM (SELECT * FROM v_control_paro_mayor_horas) x
GROUP BY x.maquina
ORDER BY registros_con_problema DESC;

-- ----------------------------------------------------------------------------
-- Q17. Productividad general por anio (comparativo anual, equivalente a la grafica "Produccion General")
-- Usa: agregacion, GROUP BY, filtro por rango de fechas
-- ----------------------------------------------------------------------------
SELECT anio,
       SUM(horas_trabajadas) AS horas_trabajadas,
       ROUND(SUM(horas_paro), 1) AS horas_paro,
       ROUND(100.0 * (1 - SUM(horas_paro) / SUM(horas_trabajadas)), 1) AS productividad_pct
FROM v_registro_resumen
WHERE fecha BETWEEN '2022-01-01' AND '2025-12-31'
GROUP BY anio
ORDER BY anio;
