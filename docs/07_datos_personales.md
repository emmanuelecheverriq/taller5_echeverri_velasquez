# 7. Datos personales: propuesta y justificacion

La base contiene nombres de 33 operarias/os y 11 tecnicos de mantenimiento (despues de unificar grafias distintas de una misma persona). Son datos personales (Ley 1581 de 2012 en Colombia: principios de finalidad y minimizacion) y no son necesarios para calcular ningun indicador de produccion.

## Propuesta
1. **Seudonimizacion**: cada persona recibe un codigo (`OPE-001`, `MAN-001`...). Todas las tablas de negocio (`registro_produccion`, `paro`) usan solo el codigo. Los codigos se asignaron por orden de aparicion en el historial, no alfabetico, para que no se pueda deducir el nombre por el orden.
2. **Separacion**: la identidad real vive en `privado.persona_identidad`, en un esquema distinto con `REVOKE ALL ... FROM PUBLIC`.
3. **Roles minimos** (`06_seguridad.sql`):
   - `rol_analista`: lee `paros`, no ve `privado`. Para jefes de area y analistas de productividad.
   - `rol_rrhh`: unico que puede unir seudonimo con nombre real.
4. **Supresion**: si una persona pide que se borre su dato, se borra su fila de `persona` y su identidad (`ON DELETE CASCADE`); los registros y paros se conservan sin persona (`ON DELETE SET NULL`), asi no se pierde historia de produccion.
5. **Texto libre**: las observaciones se revisaron y los nombres propios que aparecian se reemplazaron por `[PERSONA]` durante la migracion (2 reemplazos).
6. **Repositorio publico**: los nombres reales **no se suben a GitHub**. El ETL escribe la identidad en `etl/salida_privada/` (ignorada por `.gitignore`) y el Excel original tampoco se versiona. El repositorio solo contiene datos seudonimizados.

## Por que no cifrar o hashear el nombre
- Un hash sin sal de un nombre se reconstruye con un diccionario de nombres. Un seudonimo aleatorio con tabla de correspondencia separada es reversible solo por quien tiene acceso a esa tabla, y permite cumplir una peticion de supresion.
- El cifrado de columna (`pgcrypto`) es una mejora posible si la empresa lo exige; se omitio porque el control por esquema y roles ya cumple el objetivo del curso con menos complejidad.

## Limitaciones declaradas
- La unificacion de nombres (un tecnico escrito solo con nombre de pila y con nombre completo) se hizo con un archivo local de equivalencias que debe validar la empresa.
- Con pocos operarios por turno y fechas conocidas, una persona podria deducirse desde fuera del sistema; por eso `rol_analista` no debe exportar tablas con fecha + turno + seudonimo fuera de la empresa.
