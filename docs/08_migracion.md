# 8. Estrategia de migracion y evidencia de integridad

## 8.1 Estrategia
Se uso un proceso **ETL en Python** (`etl/etl_excel_a_sql.py`, pandas + openpyxl) que lee el Excel y genera scripts SQL ejecutables desde DBeaver:

1. **Extraer**: lee la hoja `Base De Datos` (encabezado en la fila 9, 8.208 filas) y el catalogo de la hoja `TABLA CODIGOS`.
2. **Transformar** (reglas en el codigo, una por problema del diagnostico):
   - Turnos: 9 formas de escribir -> 7 turnos del catalogo (`No aplica` y vacio -> `SIN ESPECIFICAR`).
   - Referencias: se separa marca / volumen / colores con una expresion regular y se unifican grafias (`Tris 15cc (6col)` = `(6 col)`).
   - Subcodigos: 65 textos -> 47 subcodigos con una funcion de equivalencia; si un texto no tiene equivalencia el ETL se detiene (no se pierde nada en silencio).
   - Tipo de paro: se separa la numeracion `[nn]` (ACTUAL) de la `nn.` (ANTERIOR).
   - Personas: se unifican grafias, se asigna seudonimo y se separa la identidad real.
   - Cada fila se clasifica en una de seis categorias (ver 8.2) y se reparte en `registro_produccion`, `paro` y `parada_maquina`. Cada columna `Codigo de paro n` mayor que 0 se convierte en una fila de `paro` (grupo repetitivo -> filas).
3. **Cargar**: genera `sql/04_catalogos.sql` y `sql/05_migracion_datos.sql` (INSERT por lotes de 500 filas, con identificadores explicitos y reinicio de las secuencias al final) y CSV equivalentes en `data/`.
4. **Verificar**: `sql/09_verificacion_integridad.sql` compara la base contra cifras calculadas sobre el Excel original (48 controles; todos deben decir OK).

## 8.2 Que paso con cada una de las 8.208 filas del Excel

| Categoria | Filas | Destino |
|---|---:|---|
| Fila principal con actividad | 4.807 | `registro_produccion` (+ sus `paro`; 340 tambien generan `parada_maquina`) |
| Fila principal sin produccion ni paros y con operaria `No aplica` (maquina sin trabajar ese dia) | 353 | solo `parada_maquina` |
| Fila de parada de maquina (2022-2023) | 1.463 | `parada_maquina` |
| Fila de subcodigo enlazada a una fila principal con la misma fecha, maquina, operaria, referencia y turno | 1.313 | `paro` del registro (26 tenian varias candidatas: se uso la primera en el tiempo) |
| Fila de subcodigo sin fila principal | 41 | registro sintetico (`es_sintetico = TRUE`, 0 pacas y 0 horas) + `paro` |
| Fila de subcodigo sin ningun minuto (solo texto) | 231 | no aporta datos; se descarta |
| **Total** | **8.208** | |

Resultado: 4.848 registros (4.807 + 41 sinteticos), 16.532 paros, 2.155 paradas de maquina, 44 personas, 50 referencias, 47 subcodigos y 19 motivos de parada.

## 8.3 Evidencia de que los datos llegaron integros
El script `09_verificacion_integridad.sql` contrasta la base con el Excel:

| Control | Excel | Base de datos |
|---|---:|---:|
| Suma de `Horas trabajadas` | 38.063,35 | 38.063,35 |
| Suma de `Pacas producidas` | 378.778 | 378.778 |
| Suma de `Tiempo de Paro` (horas) | 8.449,65 | 8.449,65 |
| Suma de `Horas no trabajadas` | 41.519,85 | 41.519,85 |
| Horas de paro de cada codigo 01 a 18 (columnas `Codigo n en horas`) | 18 valores | 18 coincidencias |
| Productividad mensual de Vinilos_2 en 2024 (hoja `TD_prodMaq`) | 12 valores | 12 coincidencias |
| Horas trabajadas 2023 por maquina (hoja `Hoja4`) | 4 valores | 4 coincidencias |
| Paros sin registro, registros con maquina inexistente, subcodigos de otro codigo | - | 0 |

La coincidencia con las tablas dinamicas del Excel demuestra ademas que la formula de productividad de la base (`1 - horas de paro / horas trabajadas`) es la misma que usaba la empresa.

## 8.4 Supuestos que debe validar la empresa
1. El subcodigo 1.1 se llama "SISTEMA ALIMENTADOR DE ENVASES" (los datos y el P-MTO-22 lo usan asi) aunque la hoja `TABLA CODIGOS` diga "FALLA MECANICA".
2. `1.2D RETENEDORES Y ORING` se asigna a 1.2.D (Retenedores) y `1.7A CAMBIO DE ROSCADORES` a 1.7.B (Roscadores): la numeracion antigua de letras no coincide con la actual.
3. Los subcodigos del codigo 05 con numeracion antigua `4.n` equivalen a `5.n` segun el nombre del sistema (4.4 Transfer = 5.5, etc.). Los subcodigos 5.4, 5.10 y 5.11 no existian en la numeracion antigua.
4. Las grafias de nombre de personal de mantenimiento que se consideraron la misma persona (archivo local de equivalencias, no publicado).
5. Las 84 filas que pertenecen a grupos de filas identicas y las 11 filas con miles de "pacas" (julio de 2023, Vinilos_1) se conservaron tal cual para que los totales coincidan con el Excel; quedan visibles en las vistas de control.

## 8.5 Como repetirlo
```bash
pip install -r etl/requirements.txt
python etl/etl_excel_a_sql.py --excel "SEGUIMIENTO TEMPERAS Y VINILOS Actividad.xlsm" --alias etl/alias_personas.local.json
```
El Excel y el archivo de alias no estan en el repositorio (datos personales). El repositorio incluye los SQL y CSV ya generados.
