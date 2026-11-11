-- ============================================================================
-- 09_verificacion_integridad.sql  |  Demuestra que los datos del Excel llegaron completos
-- (generado por el ETL: los valores 'esperado' se calcularon sobre el Excel original)
-- Todas las filas deben decir OK.
-- ============================================================================
SET search_path TO paros, public;

-- 1. Cantidad de filas cargadas en cada tabla
SELECT control, esperado, obtenido, CASE WHEN ABS(obtenido - esperado) < 0.01 THEN 'OK' ELSE 'REVISAR' END AS resultado FROM (
SELECT 'filas registro_produccion' AS control, 4848 AS esperado, CAST(COUNT(*) AS NUMERIC) AS obtenido FROM registro_produccion
UNION ALL
SELECT 'filas paro' AS control, 16532 AS esperado, CAST(COUNT(*) AS NUMERIC) AS obtenido FROM paro
UNION ALL
SELECT 'filas parada_maquina' AS control, 2155 AS esperado, CAST(COUNT(*) AS NUMERIC) AS obtenido FROM parada_maquina
UNION ALL
SELECT 'filas persona' AS control, 44 AS esperado, CAST(COUNT(*) AS NUMERIC) AS obtenido FROM persona
UNION ALL
SELECT 'filas referencia' AS control, 50 AS esperado, CAST(COUNT(*) AS NUMERIC) AS obtenido FROM referencia
UNION ALL
SELECT 'filas subcodigo_paro' AS control, 47 AS esperado, CAST(COUNT(*) AS NUMERIC) AS obtenido FROM subcodigo_paro
UNION ALL
SELECT 'filas motivo_parada' AS control, 19 AS esperado, CAST(COUNT(*) AS NUMERIC) AS obtenido FROM motivo_parada
) x;

-- 2. Totales del Excel original contra la base (suma de columnas del Excel = suma en la BD)
SELECT control, esperado, ROUND(obtenido, 4) AS obtenido, CASE WHEN ABS(obtenido - esperado) < 0.01 THEN 'OK' ELSE 'REVISAR' END AS resultado FROM (
SELECT 'horas trabajadas (Excel: Horas trabajadas)' AS control, 38063.35 AS esperado, CAST((SELECT SUM(horas_trabajadas) FROM registro_produccion) AS NUMERIC) AS obtenido
UNION ALL
SELECT 'pacas producidas (Excel: Pacas producidas)' AS control, 378778.0 AS esperado, CAST((SELECT SUM(pacas_producidas) FROM registro_produccion) AS NUMERIC) AS obtenido
UNION ALL
SELECT 'horas de paro (Excel: Tiempo de Paro)' AS control, 8449.6517 AS esperado, CAST((SELECT SUM(minutos) / 60.0 FROM paro) AS NUMERIC) AS obtenido
UNION ALL
SELECT 'horas no trabajadas (Excel: Horas no trabajadas)' AS control, 41519.85 AS esperado, CAST((SELECT SUM(horas_no_trabajadas) FROM parada_maquina) AS NUMERIC) AS obtenido
) x;

-- 3. Horas de paro por codigo (Excel: columnas 'Codigo n en horas') contra la tabla paro
SELECT control, esperado, ROUND(obtenido, 4) AS obtenido, CASE WHEN ABS(obtenido - esperado) < 0.01 THEN 'OK' ELSE 'REVISAR' END AS resultado FROM (
SELECT 'horas paro codigo 01' AS control, 323.9 AS esperado, CAST(COALESCE(SUM(minutos), 0) / 60.0 AS NUMERIC) AS obtenido FROM paro WHERE id_codigo_paro = 1
UNION ALL
SELECT 'horas paro codigo 02' AS control, 32.5833 AS esperado, CAST(COALESCE(SUM(minutos), 0) / 60.0 AS NUMERIC) AS obtenido FROM paro WHERE id_codigo_paro = 2
UNION ALL
SELECT 'horas paro codigo 03' AS control, 87.1333 AS esperado, CAST(COALESCE(SUM(minutos), 0) / 60.0 AS NUMERIC) AS obtenido FROM paro WHERE id_codigo_paro = 3
UNION ALL
SELECT 'horas paro codigo 04' AS control, 8.5 AS esperado, CAST(COALESCE(SUM(minutos), 0) / 60.0 AS NUMERIC) AS obtenido FROM paro WHERE id_codigo_paro = 4
UNION ALL
SELECT 'horas paro codigo 05' AS control, 1819.3267 AS esperado, CAST(COALESCE(SUM(minutos), 0) / 60.0 AS NUMERIC) AS obtenido FROM paro WHERE id_codigo_paro = 5
UNION ALL
SELECT 'horas paro codigo 06' AS control, 1546.9 AS esperado, CAST(COALESCE(SUM(minutos), 0) / 60.0 AS NUMERIC) AS obtenido FROM paro WHERE id_codigo_paro = 6
UNION ALL
SELECT 'horas paro codigo 07' AS control, 620.8083 AS esperado, CAST(COALESCE(SUM(minutos), 0) / 60.0 AS NUMERIC) AS obtenido FROM paro WHERE id_codigo_paro = 7
UNION ALL
SELECT 'horas paro codigo 08' AS control, 68.1333 AS esperado, CAST(COALESCE(SUM(minutos), 0) / 60.0 AS NUMERIC) AS obtenido FROM paro WHERE id_codigo_paro = 8
UNION ALL
SELECT 'horas paro codigo 09' AS control, 182.1333 AS esperado, CAST(COALESCE(SUM(minutos), 0) / 60.0 AS NUMERIC) AS obtenido FROM paro WHERE id_codigo_paro = 9
UNION ALL
SELECT 'horas paro codigo 10' AS control, 356.3833 AS esperado, CAST(COALESCE(SUM(minutos), 0) / 60.0 AS NUMERIC) AS obtenido FROM paro WHERE id_codigo_paro = 10
UNION ALL
SELECT 'horas paro codigo 11' AS control, 9.05 AS esperado, CAST(COALESCE(SUM(minutos), 0) / 60.0 AS NUMERIC) AS obtenido FROM paro WHERE id_codigo_paro = 11
UNION ALL
SELECT 'horas paro codigo 12' AS control, 227.0167 AS esperado, CAST(COALESCE(SUM(minutos), 0) / 60.0 AS NUMERIC) AS obtenido FROM paro WHERE id_codigo_paro = 12
UNION ALL
SELECT 'horas paro codigo 13' AS control, 19.1333 AS esperado, CAST(COALESCE(SUM(minutos), 0) / 60.0 AS NUMERIC) AS obtenido FROM paro WHERE id_codigo_paro = 13
UNION ALL
SELECT 'horas paro codigo 14' AS control, 253.4667 AS esperado, CAST(COALESCE(SUM(minutos), 0) / 60.0 AS NUMERIC) AS obtenido FROM paro WHERE id_codigo_paro = 14
UNION ALL
SELECT 'horas paro codigo 15' AS control, 165.8333 AS esperado, CAST(COALESCE(SUM(minutos), 0) / 60.0 AS NUMERIC) AS obtenido FROM paro WHERE id_codigo_paro = 15
UNION ALL
SELECT 'horas paro codigo 16' AS control, 2002.55 AS esperado, CAST(COALESCE(SUM(minutos), 0) / 60.0 AS NUMERIC) AS obtenido FROM paro WHERE id_codigo_paro = 16
UNION ALL
SELECT 'horas paro codigo 17' AS control, 718.4333 AS esperado, CAST(COALESCE(SUM(minutos), 0) / 60.0 AS NUMERIC) AS obtenido FROM paro WHERE id_codigo_paro = 17
UNION ALL
SELECT 'horas paro codigo 18' AS control, 8.3667 AS esperado, CAST(COALESCE(SUM(minutos), 0) / 60.0 AS NUMERIC) AS obtenido FROM paro WHERE id_codigo_paro = 18
) x;

-- 4. Los indicadores de la base reproducen la tabla dinamica del Excel (hoja TD_prodMaq: productividad de Vinilos_2 en 2024)
SELECT control, esperado, obtenido, CASE WHEN ABS(obtenido - esperado) < 0.01 THEN 'OK' ELSE 'REVISAR' END AS resultado FROM (
SELECT 'productividad Vinilos_2 2024 mes 01' AS control, 67.9346 AS esperado, CAST((SELECT productividad_pct FROM v_productividad_mensual WHERE maquina = 'Vinilos_2' AND anio = 2024 AND mes = 1) AS NUMERIC) AS obtenido
UNION ALL
SELECT 'productividad Vinilos_2 2024 mes 02' AS control, 57.5719 AS esperado, CAST((SELECT productividad_pct FROM v_productividad_mensual WHERE maquina = 'Vinilos_2' AND anio = 2024 AND mes = 2) AS NUMERIC) AS obtenido
UNION ALL
SELECT 'productividad Vinilos_2 2024 mes 03' AS control, 59.2994 AS esperado, CAST((SELECT productividad_pct FROM v_productividad_mensual WHERE maquina = 'Vinilos_2' AND anio = 2024 AND mes = 3) AS NUMERIC) AS obtenido
UNION ALL
SELECT 'productividad Vinilos_2 2024 mes 04' AS control, 44.3915 AS esperado, CAST((SELECT productividad_pct FROM v_productividad_mensual WHERE maquina = 'Vinilos_2' AND anio = 2024 AND mes = 4) AS NUMERIC) AS obtenido
UNION ALL
SELECT 'productividad Vinilos_2 2024 mes 05' AS control, 48.6398 AS esperado, CAST((SELECT productividad_pct FROM v_productividad_mensual WHERE maquina = 'Vinilos_2' AND anio = 2024 AND mes = 5) AS NUMERIC) AS obtenido
UNION ALL
SELECT 'productividad Vinilos_2 2024 mes 06' AS control, 45.7205 AS esperado, CAST((SELECT productividad_pct FROM v_productividad_mensual WHERE maquina = 'Vinilos_2' AND anio = 2024 AND mes = 6) AS NUMERIC) AS obtenido
UNION ALL
SELECT 'productividad Vinilos_2 2024 mes 07' AS control, 76.2229 AS esperado, CAST((SELECT productividad_pct FROM v_productividad_mensual WHERE maquina = 'Vinilos_2' AND anio = 2024 AND mes = 7) AS NUMERIC) AS obtenido
UNION ALL
SELECT 'productividad Vinilos_2 2024 mes 08' AS control, 74.8773 AS esperado, CAST((SELECT productividad_pct FROM v_productividad_mensual WHERE maquina = 'Vinilos_2' AND anio = 2024 AND mes = 8) AS NUMERIC) AS obtenido
UNION ALL
SELECT 'productividad Vinilos_2 2024 mes 09' AS control, 70.1583 AS esperado, CAST((SELECT productividad_pct FROM v_productividad_mensual WHERE maquina = 'Vinilos_2' AND anio = 2024 AND mes = 9) AS NUMERIC) AS obtenido
UNION ALL
SELECT 'productividad Vinilos_2 2024 mes 10' AS control, 72.2104 AS esperado, CAST((SELECT productividad_pct FROM v_productividad_mensual WHERE maquina = 'Vinilos_2' AND anio = 2024 AND mes = 10) AS NUMERIC) AS obtenido
UNION ALL
SELECT 'productividad Vinilos_2 2024 mes 11' AS control, 62.2485 AS esperado, CAST((SELECT productividad_pct FROM v_productividad_mensual WHERE maquina = 'Vinilos_2' AND anio = 2024 AND mes = 11) AS NUMERIC) AS obtenido
UNION ALL
SELECT 'productividad Vinilos_2 2024 mes 12' AS control, 58.5909 AS esperado, CAST((SELECT productividad_pct FROM v_productividad_mensual WHERE maquina = 'Vinilos_2' AND anio = 2024 AND mes = 12) AS NUMERIC) AS obtenido
) x;

-- 5. Horas trabajadas 2023 por maquina contra la tabla dinamica del Excel (hoja Hoja4)
SELECT control, esperado, obtenido, CASE WHEN ABS(obtenido - esperado) < 0.01 THEN 'OK' ELSE 'REVISAR' END AS resultado FROM (
SELECT 'horas trabajadas 2023 Vinilos_1' AS control, 3390 AS esperado, CAST((SELECT SUM(horas_trabajadas) FROM v_registro_resumen WHERE maquina = 'Vinilos_1' AND anio = 2023) AS NUMERIC) AS obtenido
UNION ALL
SELECT 'horas trabajadas 2023 Vinilos_2' AS control, 1220.5 AS esperado, CAST((SELECT SUM(horas_trabajadas) FROM v_registro_resumen WHERE maquina = 'Vinilos_2' AND anio = 2023) AS NUMERIC) AS obtenido
UNION ALL
SELECT 'horas trabajadas 2023 Vinilos_3' AS control, 4221.3 AS esperado, CAST((SELECT SUM(horas_trabajadas) FROM v_registro_resumen WHERE maquina = 'Vinilos_3' AND anio = 2023) AS NUMERIC) AS obtenido
UNION ALL
SELECT 'horas trabajadas 2023 Vinilos_4' AS control, 4002.55 AS esperado, CAST((SELECT SUM(horas_trabajadas) FROM v_registro_resumen WHERE maquina = 'Vinilos_4' AND anio = 2023) AS NUMERIC) AS obtenido
) x;

-- 6. Integridad referencial: no debe haber paros ni registros huerfanos (todas deben dar 0)
SELECT 'paros sin registro' AS control, COUNT(*) AS cantidad FROM paro p LEFT JOIN registro_produccion r ON r.id_registro = p.id_registro WHERE r.id_registro IS NULL
UNION ALL SELECT 'registros con maquina inexistente', COUNT(*) FROM registro_produccion r LEFT JOIN maquina m ON m.id_maquina = r.id_maquina WHERE m.id_maquina IS NULL
UNION ALL SELECT 'paros con subcodigo de otro codigo', COUNT(*) FROM paro p JOIN subcodigo_paro s ON s.id_subcodigo = p.id_subcodigo WHERE s.id_codigo_paro <> p.id_codigo_paro;
