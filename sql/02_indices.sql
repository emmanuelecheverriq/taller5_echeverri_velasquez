-- ============================================================================
-- 02_indices.sql  |  Indices adicionales (PostgreSQL no indexa las llaves foraneas solo)
-- Las PK y los UNIQUE ya crean su propio indice; aqui van los que se justifican por las consultas.
-- ============================================================================
SET search_path TO paros, public;

-- Q1, Q2, Q5, Q6 y las vistas de productividad filtran por rangos de fecha y agrupan por maquina.
CREATE INDEX idx_registro_fecha_maquina ON registro_produccion (fecha, id_maquina);

-- Comparacion entre turnos (Q5): agrupar y unir por turno.
CREATE INDEX idx_registro_turno ON registro_produccion (id_turno);

-- Ranking por referencia (Q6) y integridad: evita recorrer toda la tabla al borrar/actualizar una referencia.
CREATE INDEX idx_registro_referencia ON registro_produccion (id_referencia);

-- Consultas por operaria (Q9) y para que ON DELETE SET NULL no recorra toda la tabla.
-- Indice parcial: solo indexa los registros que tienen persona (mas de la mitad de 2022-2023 no la tienen).
CREATE INDEX idx_registro_persona ON registro_produccion (id_persona) WHERE id_persona IS NOT NULL;

-- Union paro -> registro: es el JOIN mas frecuente y es la ruta del ON DELETE CASCADE.
CREATE INDEX idx_paro_registro ON paro (id_registro);

-- Participacion por codigo (Q3) y detalle por subcodigo (Q4): agrupar por codigo y subcodigo.
CREATE INDEX idx_paro_codigo_sub ON paro (id_codigo_paro, id_subcodigo);

-- Paros atendidos por una persona (Q9).
CREATE INDEX idx_paro_persona ON paro (id_persona) WHERE id_persona IS NOT NULL;

-- Horas no trabajadas por mes y maquina (Q10).
CREATE INDEX idx_parada_fecha_maquina ON parada_maquina (fecha, id_maquina);

-- Horas no trabajadas por motivo (Q10).
CREATE INDEX idx_parada_motivo ON parada_maquina (id_motivo);

-- Navegacion de la jerarquia de subcodigos (padre -> hijos).
CREATE INDEX idx_subcodigo_padre ON subcodigo_paro (id_subcodigo_padre) WHERE id_subcodigo_padre IS NOT NULL;
