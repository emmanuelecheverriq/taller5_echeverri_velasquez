-- ============================================================================
-- 07_pruebas_restricciones.sql  |  INSERT, UPDATE y DELETE que muestran como actuan las restricciones
-- Cada sentencia lleva una etiqueta:
--   [OK]    la base debe aceptarla
--   [FALLA] la base debe RECHAZARLA (se indica la restriccion que actua)
-- En DBeaver ejecutar sentencia por sentencia (Ctrl+Enter). Si se ejecuta todo el script (Alt+X),
-- elegir "Ignorar" cuando aparezca un error esperado. Al final hay una limpieza que deja los datos como estaban.
-- ============================================================================
SET search_path TO paros, public;

-- ============================ A. INSERT ====================================

-- [OK] A1. Registro valido (maquina 1, turno 1, 1-ene-2030, fecha de prueba)
INSERT INTO registro_produccion (fecha, id_maquina, id_turno, secuencia, id_persona, id_referencia, pacas_producidas, horas_trabajadas)
VALUES ('2030-01-01', 1, 1, 1, 1, 1, 60, 8);

-- [OK] A2. Paro valido para ese registro: 30 min del codigo 05 con subcodigo 5.2 (pertenece al codigo 5)
INSERT INTO paro (id_registro, id_codigo_paro, id_subcodigo, minutos, equipo_ejecutor)
SELECT r.id_registro, 5, s.id_subcodigo, 30, 'OPERARIOS'
FROM registro_produccion r, subcodigo_paro s
WHERE r.fecha = '2030-01-01' AND r.id_maquina = 1 AND s.codigo_sub = '5.2' AND s.id_codigo_paro = 5;

-- [FALLA] A3. UNIQUE uq_registro_negocio: mismo dia, maquina, turno y secuencia
INSERT INTO registro_produccion (fecha, id_maquina, id_turno, secuencia, pacas_producidas, horas_trabajadas)
VALUES ('2030-01-01', 1, 1, 1, 10, 2);

-- [OK] A4. Mismo dia, maquina y turno pero secuencia 2 (segundo registro del turno, por ejemplo cambio de referencia)
INSERT INTO registro_produccion (fecha, id_maquina, id_turno, secuencia, pacas_producidas, horas_trabajadas)
VALUES ('2030-01-01', 1, 1, 2, 10, 2);

-- [FALLA] A5. FOREIGN KEY fk_registro_maquina: la maquina 99 no existe
INSERT INTO registro_produccion (fecha, id_maquina, id_turno, secuencia, pacas_producidas, horas_trabajadas)
VALUES ('2030-01-02', 99, 1, 1, 10, 2);

-- [FALLA] A6. CHECK ck_registro_horas: un turno no puede tener 30 horas trabajadas
INSERT INTO registro_produccion (fecha, id_maquina, id_turno, secuencia, pacas_producidas, horas_trabajadas)
VALUES ('2030-01-02', 1, 1, 1, 10, 30);

-- [FALLA] A7. CHECK ck_registro_pacas: pacas negativas
INSERT INTO registro_produccion (fecha, id_maquina, id_turno, secuencia, pacas_producidas, horas_trabajadas)
VALUES ('2030-01-02', 1, 1, 1, -5, 8);

-- [FALLA] A8. NOT NULL: la fecha es obligatoria
INSERT INTO registro_produccion (fecha, id_maquina, id_turno, secuencia, pacas_producidas, horas_trabajadas)
VALUES (NULL, 1, 1, 1, 10, 8);

-- [FALLA] A9. CHECK ck_registro_fecha: fecha anterior a 2020
INSERT INTO registro_produccion (fecha, id_maquina, id_turno, secuencia, pacas_producidas, horas_trabajadas)
VALUES ('1999-05-05', 1, 1, 1, 10, 8);

-- [FALLA] A10. CHECK ck_paro_minutos: un paro de 0 minutos no tiene sentido
INSERT INTO paro (id_registro, id_codigo_paro, minutos)
SELECT id_registro, 16, 0 FROM registro_produccion WHERE fecha = '2030-01-01' AND secuencia = 1;

-- [FALLA] A11. FOREIGN KEY compuesta fk_paro_subcodigo: el subcodigo 1.2.B pertenece al codigo 01, no al 05
INSERT INTO paro (id_registro, id_codigo_paro, id_subcodigo, minutos)
SELECT r.id_registro, 5, s.id_subcodigo, 15
FROM registro_produccion r, subcodigo_paro s
WHERE r.fecha = '2030-01-01' AND r.secuencia = 1 AND s.codigo_sub = '1.2.B';

-- [FALLA] A12. CHECK ck_paro_equipo: valor fuera de la lista permitida
INSERT INTO paro (id_registro, id_codigo_paro, minutos, equipo_ejecutor)
SELECT id_registro, 5, 10, 'GERENCIA' FROM registro_produccion WHERE fecha = '2030-01-01' AND secuencia = 1;

-- [FALLA] A13. CHECK ck_registro_sintetico: un registro sintetico no puede traer produccion
INSERT INTO registro_produccion (fecha, id_maquina, id_turno, secuencia, pacas_producidas, horas_trabajadas, es_sintetico)
VALUES ('2030-01-03', 1, 1, 1, 50, 4, TRUE);

-- [FALLA] A14. UNIQUE uq_persona_codigo: seudonimo repetido
INSERT INTO persona (codigo_seudonimo, tipo_persona) VALUES ('OPE-001', 'OPERARIO');

-- [FALLA] A15. CHECK ck_persona_tipo
INSERT INTO persona (codigo_seudonimo, tipo_persona) VALUES ('XXX-999', 'VISITANTE');

-- ============================ B. UPDATE ====================================

-- [OK] B1. Corregir las horas trabajadas del registro de prueba
UPDATE registro_produccion SET horas_trabajadas = 7.5 WHERE fecha = '2030-01-01' AND secuencia = 1;

-- [FALLA] B2. CHECK ck_registro_horas al actualizar
UPDATE registro_produccion SET horas_trabajadas = 25 WHERE fecha = '2030-01-01' AND secuencia = 1;

-- [FALLA] B3. FOREIGN KEY: cambiar un registro a una referencia que no existe
UPDATE registro_produccion SET id_referencia = 9999 WHERE fecha = '2030-01-01' AND secuencia = 1;

-- [OK] B4. ON UPDATE CASCADE: se cambia el id de un area y el cambio se propaga a codigo_paro.id_area
UPDATE area_impacto SET id_area = 50 WHERE nombre = 'Paro programado';
SELECT id_codigo_paro, id_area FROM codigo_paro WHERE id_area = 50;   -- deben salir los codigos 15, 16 y 17
UPDATE area_impacto SET id_area = 5 WHERE id_area = 50;               -- se devuelve al valor original

-- ============================ C. DELETE ====================================

-- [FALLA] C1. ON DELETE RESTRICT: el codigo 05 tiene paros asociados, no se puede borrar
DELETE FROM codigo_paro WHERE id_codigo_paro = 5;

-- [FALLA] C2. ON DELETE RESTRICT: la maquina 1 tiene registros
DELETE FROM maquina WHERE id_maquina = 1;

-- [FALLA] C3. ON DELETE RESTRICT: no se puede borrar un subcodigo padre que tiene hijos
DELETE FROM subcodigo_paro WHERE codigo_sub = '1.2' AND id_codigo_paro = 1;

-- [OK] C4. ON DELETE CASCADE: al borrar un registro se borran sus paros. Antes y despues:
SELECT COUNT(*) AS paros_del_registro_de_prueba
FROM paro WHERE id_registro IN (SELECT id_registro FROM registro_produccion WHERE fecha = '2030-01-01' AND secuencia = 1);
DELETE FROM registro_produccion WHERE fecha = '2030-01-01' AND secuencia = 1;
SELECT COUNT(*) AS paros_que_quedan_de_ese_registro
FROM paro WHERE id_registro NOT IN (SELECT id_registro FROM registro_produccion);   -- debe ser 0

-- [OK] C5. ON DELETE SET NULL: se crea una persona de prueba con un registro; al borrarla el registro se conserva sin persona
INSERT INTO persona (codigo_seudonimo, tipo_persona) VALUES ('TST-001', 'OPERARIO');
INSERT INTO registro_produccion (fecha, id_maquina, id_turno, secuencia, id_persona, pacas_producidas, horas_trabajadas)
SELECT '2030-01-05', 2, 2, 1, id_persona, 40, 8 FROM persona WHERE codigo_seudonimo = 'TST-001';
DELETE FROM persona WHERE codigo_seudonimo = 'TST-001';
SELECT id_registro, id_persona FROM registro_produccion WHERE fecha = '2030-01-05';   -- id_persona = NULL, el registro sigue

-- ============================ D. LIMPIEZA ==================================
DELETE FROM registro_produccion WHERE fecha >= '2030-01-01';
-- Verificacion: no deben quedar datos de prueba
SELECT (SELECT COUNT(*) FROM registro_produccion WHERE fecha >= '2030-01-01') AS registros_de_prueba,
       (SELECT COUNT(*) FROM persona WHERE codigo_seudonimo LIKE 'TST-%')     AS personas_de_prueba;
