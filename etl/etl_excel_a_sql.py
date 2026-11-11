#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ETL del libro SEGUIMIENTO TEMPERAS Y VINILOS (.xlsm) hacia la base relacional.

Que hace:
  1. Lee la hoja "Base De Datos" (58 columnas, una fila por registro o por subcodigo)
     y la hoja "TABLA CODIGOS" (catalogo de codigos y subcodigos).
  2. Limpia y homologa los datos (turnos, referencias, subcodigos, personas, tipos de paro).
  3. Reparte cada fila en las tablas normalizadas.
  4. Pseudonimiza a las personas (los nombres reales NO salen en los archivos publicos).
  5. Escribe:
       sql/04_catalogos.sql          catalogos (maquinas, turnos, codigos, subcodigos, ...)
       sql/05_migracion_datos.sql    registros, paros y paradas (INSERT por lotes)
       data/*.csv                    los mismos datos en CSV (seudonimizados)
       docs/evidencia/estadisticas_migracion.json   cifras para la verificacion de integridad
       etl/salida_privada/*          identidades reales (NO se sube a GitHub, ver .gitignore)

Uso:
  python etl/etl_excel_a_sql.py --excel "SEGUIMIENTO TEMPERAS Y VINILOS Actividad.xlsm" \
         --alias etl/alias_personas.local.json

Requisitos: pandas, openpyxl (ver etl/requirements.txt)
"""
import argparse
import json
import re
import unicodedata
import warnings
from collections import OrderedDict, defaultdict
from pathlib import Path

import pandas as pd

warnings.filterwarnings("ignore")

RAIZ = Path(__file__).resolve().parent.parent

# --------------------------------------------------------------------------------------
# Utilidades
# --------------------------------------------------------------------------------------


def limpiar_texto(x):
    """Quita espacios repetidos y saltos de linea. Devuelve None si esta vacio."""
    if x is None or (isinstance(x, float) and pd.isna(x)):
        return None
    s = re.sub(r"\s+", " ", str(x)).strip()
    return s if s else None


def sin_tildes(s):
    return "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn")


def sql_val(v):
    if v is None or (isinstance(v, float) and pd.isna(v)):
        return "NULL"
    if isinstance(v, bool):
        return "TRUE" if v else "FALSE"
    if isinstance(v, (int,)):
        return str(v)
    if isinstance(v, float):
        if v == int(v):
            return str(int(v))
        return repr(round(v, 4))
    if hasattr(v, "strftime"):
        return "'" + v.strftime("%Y-%m-%d") + "'"
    return "'" + str(v).replace("'", "''") + "'"


def escribir_inserts(f, tabla, columnas, filas, lote=500):
    cols = ", ".join(columnas)
    for i in range(0, len(filas), lote):
        parte = filas[i:i + lote]
        f.write(f"INSERT INTO {tabla} ({cols}) VALUES\n")
        f.write(",\n".join("  (" + ", ".join(sql_val(v) for v in fila) + ")" for fila in parte))
        f.write(";\n")
    f.write("\n")


def num(x):
    v = pd.to_numeric(x, errors="coerce")
    return None if pd.isna(v) else float(v)


# --------------------------------------------------------------------------------------
# Catalogos fijos
# --------------------------------------------------------------------------------------

MAQUINAS = ["Vinilos_1", "Vinilos_2", "Vinilos_3", "Vinilos_4"]

# nombre, hora_inicio, hora_fin
TURNOS = OrderedDict([
    ("Turno 1 (6am-2pm)", ("06:00", "14:00")),
    ("Turno 2 (2pm-10pm)", ("14:00", "22:00")),
    ("Turno 3 (10pm-6am)", ("22:00", "06:00")),
    ("Jornada 6am-4:30pm", ("06:00", "16:30")),
    ("Jornada 6am-6pm", ("06:00", "18:00")),
    ("Jornada 6pm-6am", ("18:00", "06:00")),
    ("SIN ESPECIFICAR", (None, None)),
])


def canon_turno(x):
    s = limpiar_texto(x)
    if s is None:
        return "SIN ESPECIFICAR"
    t = sin_tildes(s).lower().replace(" ", "")
    if t.startswith("6am-2pm"):
        return "Turno 1 (6am-2pm)"
    if t.startswith("2pm-10pm"):
        return "Turno 2 (2pm-10pm)"
    if t.startswith("10pm-6am"):
        return "Turno 3 (10pm-6am)"
    if t == "6am-4:30pm":
        return "Jornada 6am-4:30pm"
    if t == "6am-6pm":
        return "Jornada 6am-6pm"
    if t == "6pm-6am":
        return "Jornada 6pm-6am"
    return "SIN ESPECIFICAR"  # incluye "No aplica"


AREAS = ["Mantenimiento", "Producción", "Calidad", "Almacén de materias primas", "Paro programado"]


def canon_area(x):
    t = sin_tildes(limpiar_texto(x) or "").lower()
    for a in AREAS:
        if sin_tildes(a).lower() == t:
            return a
    return None


# --------------------------------------------------------------------------------------
# Referencias (productos)
# --------------------------------------------------------------------------------------
RE_REF = re.compile(r"^(.*?)\s*(\d+)\s*cc\s*(?:\(\s*(\d+)\s*col\s*\))?\s*$", re.I)


def parse_referencia(raw):
    s = limpiar_texto(raw)
    if s is None or sin_tildes(s).lower() in ("no aplica", "no"):
        return None
    m = RE_REF.match(s)
    if m:
        marca = m.group(1).strip()
        vol = int(m.group(2))
        col = int(m.group(3)) if m.group(3) else None
        nombre = f"{marca} {vol}cc" + (f" ({col} col)" if col else "")
        return {"nombre": nombre, "marca": marca, "volumen_cc": vol, "num_colores": col}
    return {"nombre": s, "marca": s, "volumen_cc": None, "num_colores": None}


# --------------------------------------------------------------------------------------
# Codigos / subcodigos (hoja TABLA CODIGOS)
# --------------------------------------------------------------------------------------
RE_SUB = re.compile(r"^(\d+)\.(\d+)(?:\.?([A-Za-z0-9]))?\s*(.*)$")


def leer_catalogo_codigos(excel):
    t = pd.read_excel(excel, sheet_name="TABLA CODIGOS", header=None, engine="openpyxl")
    codigos = []
    for _, r in t.iterrows():
        nom = limpiar_texto(r[5])
        if nom and re.match(r"^\[\d+\]", nom):
            n = int(re.match(r"^\[(\d+)\]", nom).group(1))
            texto = re.sub(r"^\[\d+\]\s*", "", nom)
            codigos.append((n, texto, canon_area(r[4])))
    # [18] Desinfeccion no aparece en TABLA CODIGOS pero si en el libro "Registro" y en los graficos
    if not any(c[0] == 18 for c in codigos):
        codigos.append((18, "Desinfección", None))

    subs = OrderedDict()  # codigo_sub -> (codigo_paro, descripcion)
    def agregar(txt):
        txt = limpiar_texto(txt)
        if not txt or re.match(r"^\d+\.\s", txt):
            return
        m = RE_SUB.match(txt)
        if not m:
            return
        mayor, menor, letra, desc = int(m.group(1)), int(m.group(2)), m.group(3), m.group(4)
        if letra:
            letra = letra.upper()
            if letra.isdigit():  # "1.4.3 Sensor" es un error de digitacion de 1.4.C
                letra = {"1": "A", "2": "B", "3": "C"}[letra]
        cod = f"{mayor}.{menor}" + (f".{letra}" if letra else "")
        subs[cod] = (mayor, desc.strip())

    for _, r in t.iterrows():
        if limpiar_texto(r[5]) and not str(r[5]).startswith("["):
            agregar(r[5])
        if limpiar_texto(r[7]):
            agregar(r[7])
    # Correccion documentada: en TABLA CODIGOS el 1.1 aparece como "FALLA MECANICA", pero en los
    # datos y en los graficos del P-MTO-22 es "SISTEMA ALIMENTADOR DE ENVASES".
    subs["1.1"] = (1, "SISTEMA ALIMENTADOR DE ENVASES")
    return codigos, subs


def canon_sub(slot, raw, subs):
    """Devuelve el codigo_sub canonico (ej. '1.2.B') o None si no hay subcodigo."""
    s = limpiar_texto(raw)
    if s is None or sin_tildes(s).lower() in ("sin especificar", "no aplica"):
        return None
    u = sin_tildes(s).upper()
    if slot == 3:
        m = re.match(r"^3\.(\d+)", u)
        cod = f"3.{m.group(1)}" if m else None
    elif slot == 5:
        m = re.match(r"^([45])\.(\d+)", u)
        if not m:
            cod = None
        elif m.group(1) == "5":
            cod = f"5.{m.group(2)}"
        else:  # numeracion antigua 4.x -> 5.x (equivalencia por nombre del sistema)
            viejo = {1: "5.1", 2: "5.2", 3: "5.3", 4: "5.5", 5: "5.6", 6: "5.7", 7: "5.8", 8: "5.9"}
            cod = viejo.get(int(m.group(2)))
    elif slot == 1:
        if "ROSCADORES" in u and u.startswith("1.7A"):
            cod = "1.7.B"  # "1.7A CAMBIO DE ROSCADORES" -> 1.7.B Roscadores
        else:
            m = re.match(r"^1\.(\d+)\.?([A-Z0-9])?", u)
            if not m:
                cod = None
            else:
                letra = m.group(2)
                if letra and letra.isdigit():
                    letra = {"1": "A", "2": "B", "3": "C"}[letra]
                cod = f"1.{m.group(1)}" + (f".{letra}" if letra else "")
    else:
        cod = None
    if cod is None or cod not in subs:
        raise ValueError(f"Subcodigo sin equivalencia: slot={slot} valor={raw!r} -> {cod}")
    return cod


# --------------------------------------------------------------------------------------
# Tipos de paro de maquina (motivos)
# --------------------------------------------------------------------------------------

def parse_motivo(raw):
    s = limpiar_texto(raw)
    if s is None:
        return None
    m = re.match(r"^\[(\d+)\]\s*(.*)$", s)
    if m:
        return ("ACTUAL", int(m.group(1)), m.group(2).strip())
    m = re.match(r"^(\d+)\.\s*(.*)$", s)
    if m:
        return ("ANTERIOR", int(m.group(1)), m.group(2).strip())
    return None


def escribir_verificacion(ruta, est, excel):
    """Escribe sql/09_verificacion_integridad.sql con los valores del Excel como 'esperado'."""
    import openpyxl
    wb = openpyxl.load_workbook(excel, data_only=True, read_only=True)
    # Pivote del Excel: productividad mensual de Vinilos_2 en 2024 (hoja TD_prodMaq)
    pivot = []
    for fila in wb["TD_prodMaq"].iter_rows(min_row=3, max_row=14, values_only=True):
        pivot.append(fila[1])
    # Hoja4 (tabla dinamica 2023): suma de horas trabajadas por maquina
    h4 = {}
    for fila in wb["Hoja4"].iter_rows(min_row=4, max_row=19, values_only=True):
        if fila[0] == "Valores":
            cab = fila[1:5]
        if fila[0] == "Suma de Horas trabajadas":
            h4 = dict(zip(cab, fila[1:5]))
    eb = est["esperado_bd"]
    L = []
    L.append("-- ============================================================================")
    L.append("-- 09_verificacion_integridad.sql  |  Demuestra que los datos del Excel llegaron completos")
    L.append("-- (generado por el ETL: los valores 'esperado' se calcularon sobre el Excel original)")
    L.append("-- Todas las filas deben decir OK.")
    L.append("-- ============================================================================")
    L.append("SET search_path TO paros, public;")
    L.append("")
    L.append("-- 1. Cantidad de filas cargadas en cada tabla")
    partes = []
    for t in ["registro_produccion", "paro", "parada_maquina", "persona", "referencia", "subcodigo_paro", "motivo_parada"]:
        partes.append(f"SELECT 'filas {t}' AS control, {eb[t]} AS esperado, CAST(COUNT(*) AS NUMERIC) AS obtenido FROM {t}")
    L.append("SELECT control, esperado, obtenido, CASE WHEN ABS(obtenido - esperado) < 0.01 THEN 'OK' ELSE 'REVISAR' END AS resultado FROM (")
    L.append("\nUNION ALL\n".join(partes))
    L.append(") x;")
    L.append("")
    L.append("-- 2. Totales del Excel original contra la base (suma de columnas del Excel = suma en la BD)")
    tot = [
        ("horas trabajadas (Excel: Horas trabajadas)", est["suma_horas_trabajadas"], "SELECT SUM(horas_trabajadas) FROM registro_produccion"),
        ("pacas producidas (Excel: Pacas producidas)", est["suma_pacas"], "SELECT SUM(pacas_producidas) FROM registro_produccion"),
        ("horas de paro (Excel: Tiempo de Paro)", est["suma_horas_paro"], "SELECT SUM(minutos) / 60.0 FROM paro"),
        ("horas no trabajadas (Excel: Horas no trabajadas)", est["suma_horas_no_trabajadas"], "SELECT SUM(horas_no_trabajadas) FROM parada_maquina"),
    ]
    partes = [f"SELECT '{n}' AS control, {v} AS esperado, CAST(({q}) AS NUMERIC) AS obtenido" for n, v, q in tot]
    L.append("SELECT control, esperado, ROUND(obtenido, 4) AS obtenido, CASE WHEN ABS(obtenido - esperado) < 0.01 THEN 'OK' ELSE 'REVISAR' END AS resultado FROM (")
    L.append("\nUNION ALL\n".join(partes))
    L.append(") x;")
    L.append("")
    L.append("-- 3. Horas de paro por codigo (Excel: columnas 'Codigo n en horas') contra la tabla paro")
    partes = []
    for n in range(1, 19):
        v = est["horas_paro_por_codigo"][str(n)]
        partes.append(f"SELECT 'horas paro codigo {n:02d}' AS control, {v} AS esperado, "
                      f"CAST(COALESCE(SUM(minutos), 0) / 60.0 AS NUMERIC) AS obtenido FROM paro WHERE id_codigo_paro = {n}")
    L.append("SELECT control, esperado, ROUND(obtenido, 4) AS obtenido, CASE WHEN ABS(obtenido - esperado) < 0.01 THEN 'OK' ELSE 'REVISAR' END AS resultado FROM (")
    L.append("\nUNION ALL\n".join(partes))
    L.append(") x;")
    L.append("")
    L.append("-- 4. Los indicadores de la base reproducen la tabla dinamica del Excel (hoja TD_prodMaq: productividad de Vinilos_2 en 2024)")
    partes = []
    for i, v in enumerate(pivot, start=1):
        if v is None:
            continue
        partes.append(f"SELECT 'productividad Vinilos_2 2024 mes {i:02d}' AS control, {round(v * 100, 4)} AS esperado, "
                      f"CAST((SELECT productividad_pct FROM v_productividad_mensual WHERE maquina = 'Vinilos_2' AND anio = 2024 AND mes = {i}) AS NUMERIC) AS obtenido")
    L.append("SELECT control, esperado, obtenido, CASE WHEN ABS(obtenido - esperado) < 0.01 THEN 'OK' ELSE 'REVISAR' END AS resultado FROM (")
    L.append("\nUNION ALL\n".join(partes))
    L.append(") x;")
    L.append("")
    L.append("-- 5. Horas trabajadas 2023 por maquina contra la tabla dinamica del Excel (hoja Hoja4)")
    partes = []
    for maq, v in h4.items():
        partes.append(f"SELECT 'horas trabajadas 2023 {maq}' AS control, {v} AS esperado, "
                      f"CAST((SELECT SUM(horas_trabajadas) FROM v_registro_resumen WHERE maquina = '{maq}' AND anio = 2023) AS NUMERIC) AS obtenido")
    L.append("SELECT control, esperado, obtenido, CASE WHEN ABS(obtenido - esperado) < 0.01 THEN 'OK' ELSE 'REVISAR' END AS resultado FROM (")
    L.append("\nUNION ALL\n".join(partes))
    L.append(") x;")
    L.append("")
    L.append("-- 6. Integridad referencial: no debe haber paros ni registros huerfanos (todas deben dar 0)")
    L.append("SELECT 'paros sin registro' AS control, COUNT(*) AS cantidad FROM paro p LEFT JOIN registro_produccion r ON r.id_registro = p.id_registro WHERE r.id_registro IS NULL")
    L.append("UNION ALL SELECT 'registros con maquina inexistente', COUNT(*) FROM registro_produccion r LEFT JOIN maquina m ON m.id_maquina = r.id_maquina WHERE m.id_maquina IS NULL")
    L.append("UNION ALL SELECT 'paros con subcodigo de otro codigo', COUNT(*) FROM paro p JOIN subcodigo_paro s ON s.id_subcodigo = p.id_subcodigo WHERE s.id_codigo_paro <> p.id_codigo_paro;")
    L.append("")
    ruta.write_text("\n".join(L), encoding="utf-8")


# --------------------------------------------------------------------------------------
# Programa principal
# --------------------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--excel", required=True)
    ap.add_argument("--alias", default=None, help="JSON con equivalencias de nombres (archivo local, no se sube)")
    ap.add_argument("--salida", default=str(RAIZ))
    args = ap.parse_args()
    out = Path(args.salida)
    (out / "sql").mkdir(exist_ok=True)
    (out / "data").mkdir(exist_ok=True)
    (out / "docs" / "evidencia").mkdir(parents=True, exist_ok=True)
    priv = out / "etl" / "salida_privada"
    priv.mkdir(exist_ok=True)

    alias = {"MANTENIMIENTO": {}, "OPERARIO": {}}
    if args.alias and Path(args.alias).exists():
        alias.update(json.loads(Path(args.alias).read_text(encoding="utf-8")))

    # ---------------- lectura ----------------
    df = pd.read_excel(args.excel, sheet_name="Base De Datos", header=8, engine="openpyxl")
    df.columns = [re.sub(r"\s+", " ", str(c)).strip() for c in df.columns]
    df["fila_excel"] = df.index + 10  # numero de fila en la hoja (encabezado en la fila 9)
    n_filas = len(df)
    # una fila es "principal" si trae horas trabajadas o pacas (en el Excel hay 1 fila con pacas y sin horas)
    df["es_principal"] = df["Horas trabajadas"].notna() | df["Pacas producidas"].notna()

    codigos, subs = leer_catalogo_codigos(args.excel)
    cod_area = {c[0]: c[2] for c in codigos}

    # ---------------- estadisticas de origen (para la verificacion) ----------------
    horas_cols = [f"Codigo {n} en horas" for n in range(1, 19)]
    min_cols = [f"Codigo de paro {n}" for n in range(1, 19)]
    est = OrderedDict()
    est["filas_excel"] = int(n_filas)
    est["filas_principales"] = int(df["es_principal"].sum())
    est["filas_secundarias"] = int((~df["es_principal"]).sum())
    est["suma_horas_trabajadas"] = round(float(pd.to_numeric(df["Horas trabajadas"], errors="coerce").sum()), 4)
    est["suma_pacas"] = round(float(pd.to_numeric(df["Pacas producidas"], errors="coerce").sum()), 4)
    est["suma_horas_no_trabajadas"] = round(float(pd.to_numeric(df["Horas no trabajadas"], errors="coerce").sum()), 4)
    est["suma_horas_paro"] = round(float(pd.to_numeric(df["Tiempo de Paro"], errors="coerce").sum()), 4)
    est["horas_paro_por_codigo"] = {
        str(n): round(float(pd.to_numeric(df[f"Codigo {n} en horas"], errors="coerce").sum()), 4) for n in range(1, 19)
    }

    # ---------------- personas ----------------
    def canon_persona(nombre, tipo):
        s = limpiar_texto(nombre)
        if s is None or sin_tildes(s).lower() in ("no aplica", "no"):
            return None
        return alias.get(tipo, {}).get(s, s)

    personas_orden = OrderedDict()  # (tipo, nombre) -> primera fecha vista

    def registrar_persona(nombre, tipo, fecha):
        c = canon_persona(nombre, tipo)
        if c is None:
            return None
        k = (tipo, c)
        if k not in personas_orden or fecha < personas_orden[k]:
            personas_orden[k] = fecha
        return k

    # ---------------- referencias y motivos ----------------
    referencias = OrderedDict()
    motivos = OrderedDict()

    def id_referencia(raw):
        p = parse_referencia(raw)
        if p is None:
            return None
        if p["nombre"] not in referencias:
            referencias[p["nombre"]] = {**p, "id": len(referencias) + 1}
        return referencias[p["nombre"]]["id"]

    def id_motivo(raw):
        p = parse_motivo(raw)
        if p is None:
            return None
        k = (p[0], p[1])
        if k not in motivos:
            motivos[k] = {"id": len(motivos) + 1, "sistema": p[0], "codigo": p[1], "nombre": p[2]}
        return motivos[k]["id"]

    # ---------------- normalizacion de filas ----------------
    df = df.sort_values(["Fecha", "fila_excel"], ascending=[True, False]).reset_index(drop=True)  # cronologico

    filas = []
    equivalencias = OrderedDict()  # texto_origen -> codigo_sub (por slot)
    for r in df.to_dict("records"):
        fecha = pd.Timestamp(r["Fecha"]).date()
        op_raw = limpiar_texto(r["Operario"])
        es_no_aplica = op_raw is not None and sin_tildes(op_raw).lower() in ("no aplica", "no")
        op_key = registrar_persona(r["Operario"], "OPERARIO", fecha)
        r["_fecha"] = fecha
        r["_maquina"] = r["Maquina"]
        r["_turno"] = canon_turno(r["Turno"] if pd.notna(r["Turno"]) else r["Unidad por display"])
        r["_operario_key"] = op_key
        r["_no_aplica"] = es_no_aplica
        r["_ref_id"] = id_referencia(r["Referencia"])
        # paros de la fila (una fila Excel puede traer hasta 18 codigos)
        paros = []
        for n in range(1, 19):
            mins = num(r[f"Codigo de paro {n}"])
            if mins is None or mins <= 0:
                continue
            sub_id = None
            equipo = None
            pers_key = None
            if n in (1, 3, 5):
                col = {1: "Sub Codigo de paro 1", 3: "Subcodigo 3", 5: "Subcodigo 5"}[n]
                raw = r[col]
                cs = canon_sub(n, raw, subs)
                if cs:
                    sub_id = cs
                    equivalencias[(n, limpiar_texto(raw))] = cs
            if n == 5:
                a = limpiar_texto(r["Área involucrada en subcodigo 5"])
                if a:
                    equipo = "OPERARIOS" if a.lower().startswith("operario") else "MANTENIMIENTO"
                pi = limpiar_texto(r["Personal involucrado"])
                if pi:
                    tipo = "MANTENIMIENTO" if equipo == "MANTENIMIENTO" else "OPERARIO"
                    pers_key = registrar_persona(pi, tipo, fecha)
            paros.append({"codigo": n, "sub": sub_id, "min": mins, "equipo": equipo, "pers_key": pers_key})
        r["_paros"] = paros
        r["_min_total"] = sum(p["min"] for p in paros)
        filas.append(r)

    # personas -> ids y pseudonimos (orden de primera aparicion, no alfabetico)
    pers_ids = OrderedDict()
    cont = {"OPERARIO": 0, "MANTENIMIENTO": 0}
    for (tipo, nombre), _f in sorted(personas_orden.items(), key=lambda kv: (kv[1], kv[0][0], kv[0][1])):
        cont[tipo] += 1
        pref = "OPE" if tipo == "OPERARIO" else "MAN"
        pers_ids[(tipo, nombre)] = {"id": len(pers_ids) + 1, "codigo": f"{pref}-{cont[tipo]:03d}", "tipo": tipo}

    # ---------------- construccion de registros / paradas / paros ----------------
    registros = []
    paradas = []
    paros_out = []
    sec_por_clave = defaultdict(int)
    por_clave = defaultdict(list)  # llave de enlace -> [registro]
    log = defaultdict(int)

    def clave_enlace(r):
        return (r["_fecha"], r["_maquina"], r["_operario_key"], r["_ref_id"], r["_turno"])

    def nuevo_registro(r, pacas, horas, sintetico, obs):
        kt = (r["_fecha"], r["_maquina"], r["_turno"])
        sec_por_clave[kt] += 1
        reg = {
            "id": len(registros) + 1, "fecha": r["_fecha"], "maquina": r["_maquina"], "turno": r["_turno"],
            "secuencia": sec_por_clave[kt],
            "persona": pers_ids[r["_operario_key"]]["id"] if r["_operario_key"] else None,
            "ref": r["_ref_id"], "pacas": pacas, "horas": horas, "sintetico": sintetico, "obs": obs,
        }
        registros.append(reg)
        por_clave[clave_enlace(r)].append(reg)
        return reg

    def agregar_paradas(r):
        h = num(r["Horas no trabajadas"])
        if h is None or h <= 0:
            return False
        mid = id_motivo(r["Tipo de paro"]) or id_motivo("[19] No aplica")
        o = limpiar_texto(r["Observaciones de paro"])
        if o and sin_tildes(o).lower() == "no aplica":
            o = None
        paradas.append({"id": len(paradas) + 1, "fecha": r["_fecha"], "maquina": r["_maquina"],
                        "motivo": mid, "horas": h, "obs": o})
        return True

    def agregar_paros(reg, r):
        for p in r["_paros"]:
            paros_out.append({
                "id": len(paros_out) + 1, "registro": reg["id"], "codigo": p["codigo"], "sub": p["sub"],
                "min": p["min"], "equipo": p["equipo"],
                "persona": pers_ids[p["pers_key"]]["id"] if p["pers_key"] else None,
            })

    principales = [r for r in filas if r["es_principal"]]
    secundarias = [r for r in filas if not r["es_principal"]]
    obs_pendientes = defaultdict(list)

    # 1) filas principales
    for r in principales:
        pacas = num(r["Pacas producidas"])
        horas = num(r["Horas trabajadas"])
        sin_actividad = (not pacas) and (not horas) and r["_min_total"] == 0
        obs = limpiar_texto(r["Observaciones"])
        if r["_no_aplica"] and sin_actividad:
            # dia sin produccion de la maquina: solo genera parada de maquina
            agregar_paradas(r)
            log["principales_solo_parada"] += 1
            continue
        reg = nuevo_registro(r, int(pacas) if pacas is not None else 0, horas if horas is not None else 0.0, False, obs)
        agregar_paros(reg, r)
        if agregar_paradas(r):
            log["principales_con_parada"] += 1
        log["registros_desde_principales"] += 1

    # 2) filas secundarias
    for r in secundarias:
        h_no = num(r["Horas no trabajadas"])
        es_parada = h_no is not None and h_no > 0 and r["_min_total"] == 0
        if es_parada:
            agregar_paradas(r)
            log["secundarias_parada_maquina"] += 1
            continue
        if r["_min_total"] == 0:
            log["secundarias_sin_informacion"] += 1
            if limpiar_texto(r["Observaciones"]):
                log["secundarias_sin_paro_con_observacion"] += 1
            continue
        cands = por_clave.get(clave_enlace(r))
        obs = limpiar_texto(r["Observaciones"])
        if cands:
            reg = cands[0]  # primer registro (en el tiempo) con la misma llave
            log["secundarias_enlazadas"] += 1
            if len(cands) > 1:
                log["secundarias_enlace_ambiguo"] += 1
            if obs:
                reg["obs"] = (reg["obs"] + " | " + obs) if reg["obs"] else obs
        else:
            reg = nuevo_registro(r, 0, 0.0, True, obs)
            log["secundarias_registro_sintetico"] += 1
            por_clave[clave_enlace(r)] = [reg]
        agregar_paros(reg, r)
        if agregar_paradas(r):
            log["secundarias_con_parada_ademas"] += 1

    # ---------------- scrub de nombres en textos libres ----------------
    nombres_reales = set()
    for (tipo, nombre) in pers_ids:
        nombres_reales.add(nombre)
    for tipo in alias:
        for k, v in alias[tipo].items():
            nombres_reales.add(k)
            nombres_reales.add(v)
    for k in df["Operario"].dropna().unique():
        nombres_reales.add(str(k).strip())
    for k in df["Personal involucrado"].dropna().unique():
        nombres_reales.add(str(k).strip())
    nombres_reales = {n for n in nombres_reales if n and sin_tildes(n).lower() not in ("no aplica", "no")}
    # tambien cada palabra de cada nombre (nombres y apellidos sueltos)
    primeros = {w.rstrip(".") for n in nombres_reales for w in n.split() if len(w.rstrip(".")) > 3}
    patrones = sorted(nombres_reales | primeros, key=len, reverse=True)
    rx = re.compile(r"(?<!\w)(" + "|".join(re.escape(p) for p in patrones) + r")(?!\w)", re.I) if patrones else None
    n_scrub = 0

    def scrub(t):
        nonlocal n_scrub
        if t is None or rx is None:
            return t
        nuevo, k = rx.subn("[PERSONA]", t)
        n_scrub += k
        return nuevo

    for reg in registros:
        reg["obs"] = scrub(reg["obs"])
    for pa in paradas:
        pa["obs"] = scrub(pa["obs"])

    # ---------------- escritura: catalogos ----------------
    sql_cat = out / "sql" / "04_catalogos.sql"
    with open(sql_cat, "w", encoding="utf-8") as f:
        f.write("-- ============================================================================\n")
        f.write("-- 04_catalogos.sql  |  Carga de catalogos (generado por etl/etl_excel_a_sql.py)\n")
        f.write("-- Ejecutar DESPUES de 01_esquema.sql. Orden de carga respeta las llaves foraneas.\n")
        f.write("-- ============================================================================\n")
        f.write("SET search_path TO paros, public;\n\n")
        f.write("-- Maquinas (lineas de envasado)\n")
        escribir_inserts(f, "maquina", ["id_maquina", "nombre"],
                         [(i + 1, m) for i, m in enumerate(MAQUINAS)])
        f.write("-- Turnos\n")
        escribir_inserts(f, "turno", ["id_turno", "nombre", "hora_inicio", "hora_fin"],
                         [(i + 1, k, v[0], v[1]) for i, (k, v) in enumerate(TURNOS.items())])
        f.write("-- Areas de impacto\n")
        escribir_inserts(f, "area_impacto", ["id_area", "nombre"], [(i + 1, a) for i, a in enumerate(AREAS)])
        area_id = {a: i + 1 for i, a in enumerate(AREAS)}
        f.write("-- Codigos de paro (01 a 18)\n")
        escribir_inserts(f, "codigo_paro", ["id_codigo_paro", "nombre", "id_area"],
                         [(c[0], c[1], area_id.get(c[2])) for c in sorted(codigos)])
        f.write("-- Subcodigos (jerarquia: sistema -> componente)\n")
        sub_id = {}
        filas_sub = []
        for i, (cod, (mayor, desc)) in enumerate(subs.items(), start=1):
            sub_id[cod] = i
        for cod, (mayor, desc) in subs.items():
            partes = cod.split(".")
            padre = None
            nivel = 1
            if len(partes) == 3:
                padre = sub_id.get(f"{partes[0]}.{partes[1]}")
                nivel = 2
            filas_sub.append((sub_id[cod], mayor, cod, desc, padre, nivel))
        # los padres deben cargarse antes que los hijos
        filas_sub.sort(key=lambda x: (x[5], x[0]))
        escribir_inserts(f, "subcodigo_paro",
                         ["id_subcodigo", "id_codigo_paro", "codigo_sub", "descripcion", "id_subcodigo_padre", "nivel"],
                         filas_sub)
        f.write("-- Equivalencias: textos tal como estaban en el Excel -> subcodigo canonico\n")
        eq_rows = []
        vistos = set()
        for (slot, txt), cod in sorted(equivalencias.items(), key=lambda kv: (kv[1], kv[0][1] or "")):
            if txt in vistos:
                continue
            vistos.add(txt)
            eq_rows.append((txt[:120], sub_id[cod]))
        escribir_inserts(f, "equivalencia_subcodigo", ["texto_origen", "id_subcodigo"], eq_rows)
        f.write("-- Motivos de parada de maquina (campo 'Tipo de paro' del Excel, con sus dos numeraciones)\n")
        escribir_inserts(f, "motivo_parada", ["id_motivo", "sistema_codificacion", "codigo", "nombre"],
                         [(m["id"], m["sistema"], m["codigo"], m["nombre"]) for m in motivos.values()])
        f.write("-- Referencias (productos)\n")
        escribir_inserts(f, "referencia", ["id_referencia", "nombre", "marca", "volumen_cc", "num_colores"],
                         [(v["id"], v["nombre"], v["marca"], v["volumen_cc"], v["num_colores"]) for v in referencias.values()])
        f.write("-- Personas (SOLO seudonimos; los nombres reales estan en privado.persona_identidad)\n")
        escribir_inserts(f, "persona", ["id_persona", "codigo_seudonimo", "tipo_persona"],
                         [(p["id"], p["codigo"], p["tipo"]) for p in pers_ids.values()])

    # ---------------- escritura: migracion ----------------
    fid_t = {k: i + 1 for i, k in enumerate(TURNOS)}
    fid_m = {m: i + 1 for i, m in enumerate(MAQUINAS)}
    sql_mig = out / "sql" / "05_migracion_datos.sql"
    with open(sql_mig, "w", encoding="utf-8") as f:
        f.write("-- ============================================================================\n")
        f.write("-- 05_migracion_datos.sql  |  Datos historicos del Excel (generado por el ETL)\n")
        f.write("-- Ejecutar DESPUES de 04_catalogos.sql. Las personas estan seudonimizadas.\n")
        f.write("-- ============================================================================\n")
        f.write("SET search_path TO paros, public;\n\n")
        escribir_inserts(
            f, "registro_produccion",
            ["id_registro", "fecha", "id_maquina", "id_turno", "secuencia", "id_persona", "id_referencia",
             "pacas_producidas", "horas_trabajadas", "es_sintetico", "observaciones"],
            [(g["id"], g["fecha"], fid_m[g["maquina"]], fid_t[g["turno"]], g["secuencia"], g["persona"], g["ref"],
              g["pacas"], g["horas"], g["sintetico"], g["obs"]) for g in registros])
        escribir_inserts(
            f, "paro",
            ["id_paro", "id_registro", "id_codigo_paro", "id_subcodigo", "minutos", "equipo_ejecutor", "id_persona"],
            [(p["id"], p["registro"], p["codigo"], sub_id[p["sub"]] if p["sub"] else None, p["min"], p["equipo"],
              p["persona"]) for p in paros_out])
        escribir_inserts(
            f, "parada_maquina",
            ["id_parada", "fecha", "id_maquina", "id_motivo", "horas_no_trabajadas", "observacion"],
            [(p["id"], p["fecha"], fid_m[p["maquina"]], p["motivo"], p["horas"], p["obs"]) for p in paradas])
        f.write("-- Reiniciar las secuencias de identidad (PostgreSQL) para que los nuevos INSERT continuen la numeracion\n")
        for tabla, col in [("registro_produccion", "id_registro"), ("paro", "id_paro"), ("parada_maquina", "id_parada"),
                           ("persona", "id_persona"), ("referencia", "id_referencia"),
                           ("subcodigo_paro", "id_subcodigo"), ("motivo_parada", "id_motivo"),
                           ("maquina", "id_maquina"), ("turno", "id_turno"), ("area_impacto", "id_area")]:
            f.write(f"SELECT setval(pg_get_serial_sequence('{tabla}', '{col}'), (SELECT MAX({col}) FROM {tabla}));\n")

    # ---------------- escritura: identidades privadas ----------------
    with open(priv / "persona_identidad.sql", "w", encoding="utf-8") as f:
        f.write("-- PRIVADO: NO SUBIR A GITHUB. Identidad real de cada seudonimo.\n")
        f.write("SET search_path TO privado, paros, public;\n")
        escribir_inserts(f, "privado.persona_identidad", ["id_persona", "nombre_completo"],
                         [(p["id"], nombre) for (tipo, nombre), p in pers_ids.items()])
    pd.DataFrame([{"id_persona": p["id"], "codigo_seudonimo": p["codigo"], "nombre_completo": n}
                  for (t, n), p in pers_ids.items()]).to_csv(priv / "persona_identidad.csv", index=False, encoding="utf-8")

    # ---------------- CSV publicos ----------------
    pd.DataFrame([{
        "id_registro": g["id"], "fecha": g["fecha"], "id_maquina": fid_m[g["maquina"]], "id_turno": fid_t[g["turno"]],
        "secuencia": g["secuencia"], "id_persona": g["persona"], "id_referencia": g["ref"],
        "pacas_producidas": g["pacas"], "horas_trabajadas": g["horas"], "es_sintetico": g["sintetico"],
        "observaciones": g["obs"]} for g in registros]).to_csv(out / "data" / "registro_produccion.csv", index=False)
    pd.DataFrame([{
        "id_paro": p["id"], "id_registro": p["registro"], "id_codigo_paro": p["codigo"],
        "id_subcodigo": sub_id[p["sub"]] if p["sub"] else None, "minutos": p["min"],
        "equipo_ejecutor": p["equipo"], "id_persona": p["persona"]} for p in paros_out]).to_csv(
        out / "data" / "paro.csv", index=False)
    pd.DataFrame([{
        "id_parada": p["id"], "fecha": p["fecha"], "id_maquina": fid_m[p["maquina"]], "id_motivo": p["motivo"],
        "horas_no_trabajadas": p["horas"], "observacion": p["obs"]} for p in paradas]).to_csv(
        out / "data" / "parada_maquina.csv", index=False)

    # ---------------- estadisticas esperadas en la BD ----------------
    est["esperado_bd"] = {
        "registro_produccion": len(registros),
        "paro": len(paros_out),
        "parada_maquina": len(paradas),
        "persona": len(pers_ids),
        "referencia": len(referencias),
        "subcodigo_paro": len(subs),
        "motivo_parada": len(motivos),
        "suma_horas_trabajadas": round(sum(g["horas"] for g in registros), 4),
        "suma_pacas": sum(g["pacas"] for g in registros),
        "suma_horas_paro": round(sum(p["min"] for p in paros_out) / 60.0, 4),
        "suma_horas_no_trabajadas": round(sum(p["horas"] for p in paradas), 4),
        "horas_paro_por_codigo": {
            str(n): round(sum(p["min"] for p in paros_out if p["codigo"] == n) / 60.0, 4) for n in range(1, 19)},
    }
    est["log_migracion"] = dict(log)
    est["nombres_reemplazados_en_texto_libre"] = n_scrub
    est["filas_excel_clasificadas"] = {
        "registro_desde_fila_principal": log["registros_desde_principales"],
        "fila_principal_solo_parada_de_maquina": log["principales_solo_parada"],
        "fila_secundaria_parada_de_maquina": log["secundarias_parada_maquina"],
        "fila_secundaria_enlazada_a_registro": log["secundarias_enlazadas"],
        "fila_secundaria_con_registro_sintetico": log["secundarias_registro_sintetico"],
        "fila_secundaria_sin_informacion": log["secundarias_sin_informacion"],
    }
    est["suma_clasificadas"] = sum(est["filas_excel_clasificadas"].values())

    # ---------------- script de verificacion de integridad ----------------
    escribir_verificacion(out / "sql" / "09_verificacion_integridad.sql", est, args.excel)
    (out / "docs" / "evidencia" / "estadisticas_migracion.json").write_text(
        json.dumps(est, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(est, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
