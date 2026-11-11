# 9. Consultas de negocio y resultados

Las 19 sentencias estan en `sql/08_consultas_negocio.sql` (17 preguntas; la Q4 tiene tres variantes). Se muestran las primeras filas de cada resultado, obtenidas al ejecutar el script sobre la base cargada con los datos del Excel.

Resumen de tecnicas usadas: JOIN interno, LEFT JOIN, RIGHT JOIN y FULL OUTER JOIN; SUM, COUNT, AVG, MAX; GROUP BY y HAVING; subconsultas escalares, correlacionadas (`NOT EXISTS`) y en `FROM`; CTE; funciones de ventana (`RANK`, `LAG`, `SUM() OVER`); filtros por rangos de fechas con `BETWEEN`.


## Q1. Porcentaje de productividad por maquina y por mes del 2024

*Usa: vista (JOIN interno + LEFT JOIN + subconsulta), SUM, GROUP BY, filtro por rango de fechas*

Filas devueltas: 48 (se muestran 10)

| maquina | mes | horas_trabajadas | horas_paro | productividad_pct |
|---|---|---|---|---|
| Vinilos_1 | 1 | 334 | 117.92 | 64.7 |
| Vinilos_1 | 2 | 142.0 | 68.73 | 51.6 |
| Vinilos_1 | 3 | 184 | 45.83 | 75.1 |
| Vinilos_1 | 4 | 123.5 | 51.22 | 58.5 |
| Vinilos_1 | 5 | 107.5 | 51.05 | 52.5 |
| Vinilos_1 | 6 | 90.5 | 30.9 | 65.9 |
| Vinilos_1 | 7 | 170.5 | 54.97 | 67.8 |
| Vinilos_1 | 8 | 243.5 | 77.16 | 68.3 |
| Vinilos_1 | 9 | 302 | 83.22 | 72.4 |
| Vinilos_1 | 10 | 409 | 145.12 | 64.5 |

## Q2. Comparativo entre anios: productividad mensual de cada maquina, 2023 vs 2024

*Usa: agregacion condicional (CASE), GROUP BY, columna calculada de diferencia*

Filas devueltas: 48 (se muestran 10)

| maquina | mes | prod_2023 | prod_2024 | diferencia_puntos |
|---|---|---|---|---|
| Vinilos_1 | 1 | 88.4 | 64.7 | -23.7 |
| Vinilos_1 | 2 |  | 51.6 |  |
| Vinilos_1 | 3 | 86.3 | 75.1 | -11.2 |
| Vinilos_1 | 4 | 86.4 | 58.5 | -27.8 |
| Vinilos_1 | 5 | 90.4 | 52.5 | -37.9 |
| Vinilos_1 | 6 | 87.1 | 65.9 | -21.2 |
| Vinilos_1 | 7 | 77.1 | 67.8 | -9.3 |
| Vinilos_1 | 8 | 83.5 | 68.3 | -15.2 |
| Vinilos_1 | 9 | 85.7 | 72.4 | -13.3 |
| Vinilos_1 | 10 | 65.1 | 64.5 | -0.6 |

## Q3. Participacion porcentual de cada codigo de paro (sobre las horas trabajadas totales)

*Usa: LEFT JOIN (muestra codigos sin paros), SUM, GROUP BY, subconsulta escalar, funcion de ventana*

Filas devueltas: 18 (se muestran 10)

| id_codigo_paro | codigo_de_paro | horas_paro | pct_sobre_horas_trabajadas | pct_del_total_de_paros |
|---|---|---|---|---|
| 16 | Alimentación y aseo de la zona de trabajo y la máquina | 2002.5 | 5.26 | 23.7 |
| 5 | Ajuste operativo | 1819.3 | 4.78 | 21.53 |
| 6 | Limpieza por derrame operativo | 1546.9 | 4.06 | 18.31 |
| 17 | Pausa activa | 718.4 | 1.89 | 8.5 |
| 7 | Alistamiento de máquina / Cambio de referencia | 620.8 | 1.63 | 7.35 |
| 10 | Paro por ventaja/evacuación | 356.4 | 0.94 | 4.22 |
| 1 | Falla del sistema electromecánico y/o de control | 323.9 | 0.85 | 3.83 |
| 14 | Falta de materia prima | 253.5 | 0.67 | 3.0 |
| 12 | Materia prima defectuosa | 227.0 | 0.6 | 2.69 |
| 9 | Falta de operario | 182.1 | 0.48 | 2.16 |

## Q4a. Detalle por subcodigo del codigo 01 (Falla electromecanica), como el grafico del P-MTO-22

*Usa: JOIN interno, JOIN a si misma (sistema padre), SUM, GROUP BY, ventana para el porcentaje*

Filas devueltas: 28 (se muestran 10)

| sistema | codigo_sub | componente | eventos | horas | pct_del_codigo |
|---|---|---|---|---|---|
| 1.2 SISTEMA DE DOSIFICACIÓN | 1.2.C | Cambio de Valvula | 73 | 47.0 | 14.6 |
| 1.7 SISTEMA DE SUJECIÓN Y ROSCADORES | 1.7 | SISTEMA DE SUJECIÓN Y ROSCADORES | 34 | 40.8 | 12.7 |
| 1.6 SISTEMA VIDEO JET | 1.6 | SISTEMA VIDEO JET | 41 | 32.9 | 10.2 |
| 1.2 SISTEMA DE DOSIFICACIÓN | 1.2.B | Ajuste de sensor | 44 | 30.3 | 9.4 |
| 1.2 SISTEMA DE DOSIFICACIÓN | 1.2.D | Retenedores | 66 | 28.6 | 8.9 |
| 1.4 SISTEMA DE TAPADO | 1.4 | SISTEMA DE TAPADO | 32 | 27.7 | 8.6 |
| 1.1 SISTEMA ALIMENTADOR DE ENVASES | 1.1 | SISTEMA ALIMENTADOR DE ENVASES | 20 | 21.3 | 6.6 |
| 1.5 SISTEMA DE ALIMENTACIÓN DE TAPA | 1.5 | SISTEMA DE ALIMENTACIÓN DE TAPA | 29 | 16.4 | 5.1 |
| 1.7 SISTEMA DE SUJECIÓN Y ROSCADORES | 1.7.B | Roscadores | 11 | 15.0 | 4.6 |
| 1.5 SISTEMA DE ALIMENTACIÓN DE TAPA | 1.5.A | Banda | 13 | 11.3 | 3.5 |

## Q4b. Detalle por subcodigo del codigo 03 (Novedad en sistemas de potencia). Incluye "sin subcodigo".

*Usa: LEFT JOIN, COALESCE, SUM, GROUP BY, ventana*

Filas devueltas: 3

| subcodigo | eventos | horas | pct_del_codigo |
|---|---|---|---|
| (sin subcodigo registrado) | 93 | 62.7 | 71.9 |
| 3.3 Falla en la red neumática o el compresor | 46 | 16.1 | 18.5 |
| 3.2 Fallo en la red pública | 13 | 8.3 | 9.5 |

## Q4c. Codigo 05 (Ajuste operativo): horas por subcodigo separadas por quien hizo el ajuste

*Usa: agregacion condicional, GROUP BY, JOIN interno + LEFT JOIN*

Filas devueltas: 12 (se muestran 10)

| subcodigo | horas_operarios | horas_mantenimiento | horas_sin_dato | horas_total |
|---|---|---|---|---|
| 5.2 Sistema de dosificación de pintura, frontal posterior | 499.8 | 277.7 | 8.3 | 785.8 |
| 5.5 Transfer y pisador de tapa | 145.0 | 83.9 | 9.0 | 237.9 |
| 5.6 Sistema alimentador de tapa y tobogan | 126.1 | 38.5 | 0.0 | 164.6 |
| 5.9 Sistema de etiquetado | 87.3 | 70.7 | 0.7 | 158.7 |
| 5.7 Video Jet | 123.2 | 27.3 | 4.6 | 155.1 |
| 5.8 Banda de sujeción y roscadores | 36.2 | 54.7 | 8.0 | 99.0 |
| 5.11 Lavado de boquilla | 45.3 | 5.7 | 10.9 | 61.8 |
| 5.3 Banda transportadora de entrada | 27.1 | 23.4 | 4.2 | 54.7 |
| 5.1 Sistema alimentador de envases | 29.6 | 21.6 | 1.2 | 52.4 |
| 5.10 Purga de color | 21.4 | 2.4 | 7.0 | 30.8 |

## Q5. Comparacion del desempeno entre turnos (solo registros con turno conocido y horas trabajadas)

*Usa: JOIN, SUM, GROUP BY, HAVING, filtro por rango de fechas*

Filas devueltas: 5

| turno | registros | pacas | horas_trabajadas | pacas_por_hora | productividad_pct |
|---|---|---|---|---|---|
| Turno 3 (10pm-6am) | 591 | 32308 | 4509.5 | 7.16 | 76.0 |
| Turno 2 (2pm-10pm) | 684 | 40971 | 5145.0 | 7.96 | 74.0 |
| Jornada 6am-6pm | 1 | 510 | 12 | 42.5 | 73.8 |
| Turno 1 (6am-2pm) | 764 | 46219 | 5738.0 | 8.05 | 71.0 |
| Jornada 6am-4:30pm | 187 | 43002 | 1894.5 | 22.7 | 62.1 |

## Q6. Las 10 referencias con mayor produccion y su rendimiento (pacas por hora)

*Usa: JOIN interno, SUM, GROUP BY, HAVING (minimo de horas para que el promedio sea confiable)*

Filas devueltas: 10

| referencia | registros | pacas | horas | pacas_por_hora |
|---|---|---|---|---|
| Parchesitos 125cc | 199 | 56777 | 1826.0 | 31.09 |
| Torre 22cc (12 col) | 310 | 22129 | 2382 | 9.29 |
| Torre 22cc (6 col) | 297 | 16780 | 2285 | 7.34 |
| Parchesitos 22cc (6 col) | 368 | 16228 | 2793.0 | 5.81 |
| Kids 22cc (6 col) | 184 | 8627 | 1390 | 6.21 |
| Parchesitos 30cc (12 col) | 175 | 7490 | 1422.0 | 5.27 |
| Stanford 30cc (7 col) | 57 | 5156 | 433.5 | 11.89 |
| Pintorcitos 70cc (6 col) | 48 | 3787 | 429.5 | 8.82 |
| Parchesitos 15cc (6 col) | 74 | 2574 | 557.5 | 4.62 |
| Parchesitos 22cc (12 col) | 63 | 2550 | 452 | 5.64 |

## Q7. Los 3 codigos de paro que mas tiempo quitan a cada maquina

*Usa: CTE, JOINs, SUM, GROUP BY, funcion de ventana RANK() con PARTITION BY*

Filas devueltas: 12 (se muestran 10)

| maquina | posicion | codigo | horas |
|---|---|---|---|
| Vinilos_1 | 1 | Alimentación y aseo de la zona de trabajo y la máquina | 255.2 |
| Vinilos_1 | 2 | Ajuste operativo | 246.9 |
| Vinilos_1 | 3 | Limpieza por derrame operativo | 168.6 |
| Vinilos_2 | 1 | Alimentación y aseo de la zona de trabajo y la máquina | 229.5 |
| Vinilos_2 | 2 | Limpieza por derrame operativo | 136.0 |
| Vinilos_2 | 3 | Ajuste operativo | 115.8 |
| Vinilos_3 | 1 | Alimentación y aseo de la zona de trabajo y la máquina | 380.2 |
| Vinilos_3 | 2 | Ajuste operativo | 204.1 |
| Vinilos_3 | 3 | Limpieza por derrame operativo | 196.1 |
| Vinilos_4 | 1 | Alimentación y aseo de la zona de trabajo y la máquina | 440.9 |

## Q8. Meses-maquina con productividad por debajo del promedio general

*Usa: vista, GROUP BY, HAVING con subconsulta escalar*

Filas devueltas: 15 (se muestran 10)

| maquina | anio | mes | productividad_pct |
|---|---|---|---|
| Vinilos_2 | 2024 | 4 | 44.4 |
| Vinilos_2 | 2023 | 12 | 44.6 |
| Vinilos_2 | 2024 | 6 | 45.7 |
| Vinilos_2 | 2024 | 5 | 48.6 |
| Vinilos_2 | 2025 | 3 | 50.9 |
| Vinilos_2 | 2023 | 11 | 51.2 |
| Vinilos_1 | 2024 | 2 | 51.6 |
| Vinilos_1 | 2023 | 11 | 52.3 |
| Vinilos_1 | 2024 | 5 | 52.5 |
| Vinilos_4 | 2024 | 3 | 53.3 |

## Q9. Ajustes operativos (codigo 05) por persona involucrada: quien interviene mas (solo seudonimos)

*Usa: JOIN interno, SUM, GROUP BY, HAVING*

Filas devueltas: 19 (se muestran 10)

| codigo_seudonimo | tipo_persona | intervenciones | horas |
|---|---|---|---|
| MAN-007 | MANTENIMIENTO | 205 | 155.2 |
| MAN-002 | MANTENIMIENTO | 169 | 141.3 |
| MAN-004 | MANTENIMIENTO | 151 | 95.3 |
| MAN-010 | MANTENIMIENTO | 123 | 92.7 |
| OPE-012 | OPERARIO | 138 | 82.9 |
| OPE-001 | OPERARIO | 84 | 67.7 |
| MAN-003 | MANTENIMIENTO | 76 | 56.4 |
| OPE-002 | OPERARIO | 97 | 49.8 |
| OPE-006 | OPERARIO | 76 | 47.1 |
| OPE-009 | OPERARIO | 64 | 46.4 |

## Q10. Horas en que las maquinas no trabajaron, por motivo y semestre del 2023 (parada_maquina)

*Usa: JOIN, SUM, COUNT, GROUP BY, HAVING, rango de fechas*

Filas devueltas: 5

| sistema_codificacion | motivo | eventos | horas_no_trabajadas | promedio_por_evento |
|---|---|---|---|---|
| ANTERIOR | PARO DE MAQUINA | 709 | 14373 | 20.3 |
| ACTUAL | Paro de maquina por ventas | 162 | 2771.85 | 17.1 |
| ANTERIOR | PARO POR MATERIA PRIMA O MATERIAL DE EMPAQUE NO CONFORME | 26 | 472 | 18.2 |
| ANTERIOR | FALTA DE MATERIALES O MATERIAS PRIMAS | 17 | 336 | 19.8 |
| ANTERIOR | APROBACION DE LABORATORIO (MICROBIOLOGIA) | 12 | 224 | 18.7 |

## Q11. Registros de produccion sin ningun paro registrado (posible falta de digitacion)

*Usa: NOT EXISTS (subconsulta correlacionada), JOINs, filtro por fechas*

Filas devueltas: 3

| maquina | registros_sin_paros | horas_sin_paros |
|---|---|---|
| Vinilos_3 | 2 | 2 |
| Vinilos_1 | 2 | 10 |
| Vinilos_4 | 1 | 1 |

## Q12. Subcodigos del catalogo que nunca se han usado (RIGHT JOIN desde paro hacia subcodigo_paro)

*Usa: RIGHT JOIN, GROUP BY, HAVING*

Filas devueltas: 6

| codigo_sub | descripcion | veces_usado |
|---|---|---|
| 1.6.A | Fotocelda | 0 |
| 1.8.A | Banda | 0 |
| 1.8.B | Motor | 0 |
| 3.1 | Fallo en la subestación | 0 |
| 3.4 | Falla en la red de enfriamiento o el chiller | 0 |
| 3.5 | Falla en la red de vapor o la caldera | 0 |

## Q13. Cobertura de datos: meses con registros de produccion vs meses con paradas de maquina

*Usa: FULL OUTER JOIN entre dos agregaciones (CTE)*

Filas devueltas: 38 (se muestran 10)

| anio | mes | registros | paradas |
|---|---|---|---|
| 2022 | 1 | 103 | 108 |
| 2022 | 2 | 137 | 81 |
| 2022 | 3 | 94 | 104 |
| 2022 | 4 | 106 | 93 |
| 2022 | 5 | 82 | 63 |
| 2022 | 7 | 6 | 5 |
| 2022 | 8 | 6 |  |
| 2022 | 9 | 7 | 1 |
| 2022 | 10 | 147 | 90 |
| 2022 | 11 | 158 | 88 |

## Q14. Variacion mensual de la productividad de cada maquina contra el mes anterior

*Usa: CTE, agregacion, funcion de ventana LAG*

Filas devueltas: 48 (se muestran 10)

| maquina | anio | mes | productividad_pct | cambio_vs_mes_anterior |
|---|---|---|---|---|
| Vinilos_1 | 2024 | 1 | 64.7 |  |
| Vinilos_1 | 2024 | 2 | 51.6 | -13.1 |
| Vinilos_1 | 2024 | 3 | 75.1 | 23.5 |
| Vinilos_1 | 2024 | 4 | 58.5 | -16.6 |
| Vinilos_1 | 2024 | 5 | 52.5 | -6.0 |
| Vinilos_1 | 2024 | 6 | 65.9 | 13.3 |
| Vinilos_1 | 2024 | 7 | 67.8 | 1.9 |
| Vinilos_1 | 2024 | 8 | 68.3 | 0.6 |
| Vinilos_1 | 2024 | 9 | 72.4 | 4.1 |
| Vinilos_1 | 2024 | 10 | 64.5 | -7.9 |

## Q15. Paro por area de impacto (Mantenimiento, Produccion, Calidad, ...)

*Usa: JOIN interno, LEFT JOIN, SUM, GROUP BY, rango de fechas*

Filas devueltas: 6

| area_impacto | codigos | horas_paro | pct_del_total |
|---|---|---|---|
| Producción | 7 | 2725.8 | 56.6 |
| Paro programado | 3 | 1731.4 | 35.9 |
| Calidad | 2 | 138.8 | 2.9 |
| Almacén de materias primas | 1 | 108.8 | 2.3 |
| Mantenimiento | 4 | 104.6 | 2.2 |
| (sin area en el catalogo) | 1 | 8.4 | 0.2 |

## Q16. Calidad de datos: registros donde el tiempo de paro supera las horas trabajadas (subconsulta en FROM)

*Usa: vista de control + subconsulta + agregacion*

Filas devueltas: 4

| maquina | registros_con_problema | mayor_exceso_horas |
|---|---|---|
| Vinilos_3 | 16 | 1.4 |
| Vinilos_4 | 16 | 0.8 |
| Vinilos_2 | 11 | 7.7 |
| Vinilos_1 | 3 | 7.6 |

## Q17. Productividad general por anio (comparativo anual, equivalente a la grafica "Produccion General")

*Usa: agregacion, GROUP BY, filtro por rango de fechas*

Filas devueltas: 4

| anio | horas_trabajadas | horas_paro | productividad_pct |
|---|---|---|---|
| 2022 | 7894 | 970.0 | 87.7 |
| 2023 | 12834.35 | 2661.8 | 79.3 |
| 2024 | 14518.0 | 3977.2 | 72.6 |
| 2025 | 2817.0 | 840.7 | 70.2 |
