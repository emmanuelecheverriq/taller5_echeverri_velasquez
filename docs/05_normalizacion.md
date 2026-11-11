# 5. Normalizacion: del Excel a la 3FN (y BCNF)

## 5.0 Punto de partida (relacion no normalizada, UNF)
Hoja `Base De Datos` vista como una relacion:

```
BASE_DATOS(Fecha, Mes, Anio, Maquina, Operario, Referencia, Unidades_cada_minuto, Unidad_por_display,
  Display_por_paca, Pacas, Horas_trabajadas, Turno, Horas_no_trabajadas, Tipo_de_paro, Obs_de_paro,
  Codigo_1, Subcodigo_1, Codigo_1_horas, Codigo_2, Codigo_2_horas, Codigo_3, Subcodigo_3, Codigo_3_horas, ...,
  Codigo_5, Subcodigo_5, Codigo_5_horas, Area_involucrada, Personal_involucrado, ..., Codigo_18, Codigo_18_horas,
  Tiempo_de_Paro, Observaciones)
```
Dependencias funcionales detectadas:
- DF1: `Fecha -> Mes, Anio`
- DF2: `Codigo_n_horas = Codigo_n / 60` y `Tiempo_de_Paro = suma de Codigo_n_horas` (derivados)
- DF3: `Codigo -> nombre del codigo, area de impacto`
- DF4: `Subcodigo -> descripcion, codigo al que pertenece, sistema padre`
- DF5: `Referencia -> marca, volumen, numero de colores`
- DF6: `Turno -> hora de inicio, hora de fin`
- DF7: `(Fecha, Maquina, Turno, Operario, Referencia) -> Pacas, Horas_trabajadas, Observaciones`
- DF8: `(Fecha, Maquina) -> Horas_no_trabajadas, Tipo_de_paro, Obs_de_paro`
- DF9: `Personal_involucrado -> tipo de personal (operarios / mantenimiento)`

## 5.1 Primera forma normal (1FN): valores atomicos y sin grupos repetitivos
**Problema (anomalia de insercion):** los pares `Codigo_n / Codigo_n_horas` (n = 1..18) y los subcodigos 1, 3, 5 son un **grupo repetitivo** codificado en columnas. Para registrar un paro nuevo hay que ocupar la columna que corresponde al codigo; no se puede registrar dos veces el mismo codigo en una fila; y la mayoria de las celdas queda vacia.

**Solucion:** una fila por cada paro.
```
REGISTRO(Fecha, Maquina, Turno, Operario, Referencia, Secuencia, Pacas, Horas_trabajadas, Observaciones, ...)
PARO(Fecha, Maquina, Turno, Secuencia, Codigo, Subcodigo, Minutos, Area_involucrada, Personal_involucrado)
```
Ademas se eliminan las columnas vacias (`Unidades_cada_minuto`, `Display_por_paca`) y se corrige la columna `Unidad_por_display`, que contenia el turno. Llave de PARO: (Fecha, Maquina, Turno, Secuencia, Codigo, Subcodigo).

## 5.2 Segunda forma normal (2FN): sin dependencias parciales
Con llaves compuestas, ningun atributo no clave debe depender de una parte de la llave.

| Dependencia parcial | Anomalia | Solucion |
|---|---|---|
| En PARO, `nombre del codigo` y `area` dependen solo de `Codigo` (DF3) | Si se cambia el nombre de un codigo hay que actualizarlo en miles de filas (anomalia de actualizacion) | Tabla `codigo_paro` (+ `area_impacto`) |
| En PARO, `descripcion del subcodigo` depende solo de `Subcodigo` (DF4) | Igual | Tabla `subcodigo_paro` |
| En REGISTRO, marca, volumen y colores dependen solo de `Referencia` (DF5) | Repeticion; "Tris 15cc (6col)" y "Tris 15cc (6 col)" aparecen como dos productos | Tabla `referencia` |
| En REGISTRO, hora de inicio/fin dependen solo de `Turno` (DF6) | Turno escrito de 9 formas | Tabla `turno` |
| `Horas_no_trabajadas`, `Tipo_de_paro` dependen solo de (Fecha, Maquina) (DF8), no del turno ni de la referencia | Si no hubo registro de produccion ese dia no hay donde guardarlas (anomalia de insercion); si se borra el registro se pierde la parada (anomalia de borrado) | Tabla `parada_maquina` |
| `Pacas`, `Horas_trabajadas` dependen del registro, no de cada codigo de paro | Repetidas en cada fila de paro | Separacion REGISTRO / PARO con llave sustituta `id_registro` |

Se reemplazan las llaves compuestas largas por llaves sustitutas (`id_*`) conservando la llave natural como `UNIQUE (fecha, id_maquina, id_turno, secuencia)`.

## 5.3 Tercera forma normal (3FN): sin dependencias transitivas
| Dependencia transitiva / derivada | Anomalia | Solucion |
|---|---|---|
| `Fecha -> Mes, Anio` (DF1) | `Mes` y `Año` pueden contradecir la fecha; `Año` esta guardado como texto | Se eliminan; se calculan con `EXTRACT` en las vistas |
| `Codigo_n_horas`, `Tiempo_de_Paro` (DF2) | Si se corrige el minuto y no la hora, el indicador queda mal | Solo se guardan `minutos`; las horas se calculan |
| `id_codigo_paro -> id_area -> nombre del area` | Nombre del area repetido por codigo | `area_impacto` aparte |
| `id_subcodigo -> id_codigo_paro`; `componente -> sistema` | El codigo del subcodigo se repetia en cada paro y podia contradecirse | FK compuesta `(id_subcodigo, id_codigo_paro)` y jerarquia con `id_subcodigo_padre` |
| `Tipo_de_paro` como texto libre con dos numeraciones | Mismo motivo escrito de formas distintas | Catalogo `motivo_parada` |
| `Personal_involucrado` como texto (nombre de pila en unas filas, nombre completo en otras) | Una persona, varias grafias; datos personales en cada fila | Tabla `persona` (seudonimo) + `privado.persona_identidad` |

## 5.4 BCNF
Se verifico que en cada tabla todo determinante es una llave candidata: en `subcodigo_paro` los determinantes `id_subcodigo` y `(id_codigo_paro, codigo_sub)` son ambos llaves candidatas (UNIQUE); en `motivo_parada`, `id_motivo` y `(sistema_codificacion, codigo)`; en `registro_produccion`, `id_registro` y `(fecha, id_maquina, id_turno, secuencia)`. No quedan dependencias cuyo determinante no sea llave, por lo que el modelo esta en **BCNF**.

## 5.5 Desnormalizaciones intencionales (justificadas)
1. **`paro.equipo_ejecutor`** repite informacion de `persona.tipo_persona`. Se conserva porque en 1.150 de los 3.088 paros del codigo 05 (37 %) el Excel sabe si fue operarios o mantenimiento pero **no** quien (no hay `id_persona`). Controlada por `CHECK`.
2. **`registro_produccion.es_sintetico`**: marca los 41 registros creados en la migracion para no perder paros de subcodigo sin fila principal. Es metadato de calidad de datos, no un dato de negocio.
3. **`equivalencia_subcodigo`**: tabla de apoyo de migracion (no es parte del dominio); documenta la limpieza.
4. **Sin columnas de total** (productividad, horas de paro): se calculan en vistas para evitar inconsistencias.
