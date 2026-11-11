# 1. Analisis: entidades, atributos y reglas de negocio

Fuentes: libro `SEGUIMIENTO TEMPERAS Y VINILOS Actividad.xlsm` (21 hojas, 4 ocultas; la hoja "Base De Datos" tiene 8.208 filas y 58 columnas, de enero de 2022 a marzo de 2025) y el procedimiento **P-MTO-22 V1**.

## 1.1 Como funciona el proceso hoy
1. En cada turno la operaria diligencia a mano el formato "hora a hora" de su maquina (Vinilos_1 a Vinilos_4): pacas por hora, codigos de paro y duracion de cada paro.
2. Produccion entrega los formatos a Mantenimiento.
3. Mantenimiento los transcribe al Excel con macros (botones *Ingreso total*, *Ingreso subcodigo* y *Limpiar*).
4. El Excel alimenta tablas dinamicas y graficos; el coordinador de mantenimiento presenta un informe mensual a la alta direccion.

## 1.2 Entidades identificadas

| Entidad | Que representa | Atributos principales | Origen |
|---|---|---|---|
| MAQUINA | Linea de envasado (Vinilos_1..4) | nombre | columna `Maquina` |
| TURNO | Franja de trabajo | nombre, hora inicio, hora fin | columna `Turno` |
| PERSONA | Operaria/o o tecnico de mantenimiento | seudonimo, tipo | `Operario`, `Personal involucrado` |
| REFERENCIA | Producto que se envasa | nombre, marca, volumen (cc), numero de colores | `Referencia` |
| REGISTRO_PRODUCCION | Lo que se anota para una maquina, turno y referencia | fecha, secuencia, pacas, horas trabajadas, observaciones | fila principal del Excel |
| CODIGO_PARO | Causa de paro 01 a 18 | numero, nombre | hoja `TABLA CODIGOS`, PDF |
| AREA_IMPACTO | Area de la empresa afectada por el codigo | nombre | `TABLA CODIGOS` |
| SUBCODIGO_PARO | Sistema o componente de la maquina (codigos 01, 03 y 05) | codigo, descripcion, nivel, padre | `TABLA CODIGOS`, columnas de subcodigo |
| PARO | Tiempo perdido por un codigo dentro de un registro | minutos, equipo ejecutor | columnas `Codigo de paro 1..18` |
| PARADA_MAQUINA | Horas del dia que la maquina no trabajo | fecha, horas no trabajadas, observacion | `Horas no trabajadas`, `Tipo de paro` |
| MOTIVO_PARADA | Razon de la parada de maquina | sistema de codificacion, codigo, nombre | `Tipo de paro` |

## 1.3 Reglas de negocio
- **RN1.** Una maquina trabaja en un turno y produce una referencia: un registro identifica fecha + maquina + turno (+ secuencia si en el mismo turno hay mas de un registro, por ejemplo un cambio de referencia).
- **RN2.** Las horas trabajadas de un registro estan entre 0 y 24; las pacas no son negativas.
- **RN3.** Cada paro se clasifica con un codigo de paro (01 a 18) y dura mas de 0 minutos. Un registro puede tener varios paros, incluso del mismo codigo.
- **RN4.** Solo los codigos 01, 03 y 05 llevan subcodigo, y el subcodigo debe pertenecer a ese codigo (el 1.2.B solo vale para el codigo 01).
- **RN5.** Los subcodigos forman una jerarquia de dos niveles: sistema (1.2 Sistema de dosificacion) y componente (1.2.B Ajuste de sensor).
- **RN6.** Para el codigo 05 se registra si el ajuste lo hizo personal de operarios o de mantenimiento y, cuando se sabe, quien.
- **RN7.** Cada codigo de paro pertenece a un area de impacto (Mantenimiento, Produccion, Calidad, Almacen de materias primas, Paro programado).
- **RN8.** Las horas que la maquina no trabajo en el dia (por ejemplo por falta de demanda) se registran aparte con su motivo.
- **RN9.** Productividad = 1 - (horas de paro / horas trabajadas). Se calcula agrupando por maquina, mes, anio o codigo; **no** se guarda como dato.
- **RN10.** El personal se identifica solo por seudonimo; el nombre real esta separado y con acceso restringido.
- **RN11.** El procedimiento habla de "codigos del 1 al 18" pero el listado del PDF llega hasta el 17. El codigo 18 (Desinfeccion) existe en el formulario del Excel y en los graficos, por eso se incluye.
