import subprocess
# ---------------- modelo logico (pata de gallo) ----------------
T = {
 "maquina": [("PK","id_maquina","SMALLINT"),("","nombre","VARCHAR(20)"),("","activa","BOOLEAN")],
 "turno": [("PK","id_turno","SMALLINT"),("","nombre","VARCHAR(30)"),("","hora_inicio","TIME"),("","hora_fin","TIME")],
 "area_impacto": [("PK","id_area","SMALLINT"),("","nombre","VARCHAR(40)")],
 "codigo_paro": [("PK","id_codigo_paro","SMALLINT"),("","nombre","VARCHAR(100)"),("FK","id_area","SMALLINT")],
 "subcodigo_paro": [("PK","id_subcodigo","SMALLINT"),("FK","id_codigo_paro","SMALLINT"),("","codigo_sub","VARCHAR(10)"),("","descripcion","VARCHAR(100)"),("FK","id_subcodigo_padre","SMALLINT"),("","nivel","SMALLINT")],
 "equivalencia_subcodigo": [("PK","texto_origen","VARCHAR(120)"),("FK","id_subcodigo","SMALLINT")],
 "motivo_parada": [("PK","id_motivo","SMALLINT"),("","sistema_codificacion","VARCHAR(10)"),("","codigo","SMALLINT"),("","nombre","VARCHAR(120)")],
 "referencia": [("PK","id_referencia","SMALLINT"),("","nombre","VARCHAR(60)"),("","marca","VARCHAR(50)"),("","volumen_cc","SMALLINT"),("","num_colores","SMALLINT")],
 "persona": [("PK","id_persona","SMALLINT"),("","codigo_seudonimo","VARCHAR(10)"),("","tipo_persona","VARCHAR(13)"),("","activa","BOOLEAN")],
 "privado.persona_identidad": [("PK/FK","id_persona","SMALLINT"),("","nombre_completo","VARCHAR(120)"),("","fecha_carga","TIMESTAMP")],
 "registro_produccion": [("PK","id_registro","INTEGER"),("","fecha","DATE"),("FK","id_maquina","SMALLINT"),("FK","id_turno","SMALLINT"),("","secuencia","SMALLINT"),("FK","id_persona","SMALLINT"),("FK","id_referencia","SMALLINT"),("","pacas_producidas","INTEGER"),("","horas_trabajadas","NUMERIC(5,2)"),("","es_sintetico","BOOLEAN"),("","observaciones","VARCHAR(500)")],
 "paro": [("PK","id_paro","INTEGER"),("FK","id_registro","INTEGER"),("FK","id_codigo_paro","SMALLINT"),("FK","id_subcodigo","SMALLINT"),("","minutos","NUMERIC(7,2)"),("","equipo_ejecutor","VARCHAR(13)"),("FK","id_persona","SMALLINT")],
 "parada_maquina": [("PK","id_parada","INTEGER"),("","fecha","DATE"),("FK","id_maquina","SMALLINT"),("FK","id_motivo","SMALLINT"),("","horas_no_trabajadas","NUMERIC(5,2)"),("","observacion","VARCHAR(200)")],
}
def node(n, cols):
    rows = "".join(f'<TR><TD ALIGN="LEFT" WIDTH="38"><FONT POINT-SIZE="9" COLOR="#b00020">{k or "&nbsp;"}</FONT></TD><TD ALIGN="LEFT">{c}</TD><TD ALIGN="LEFT"><FONT POINT-SIZE="9" COLOR="#555555">{t}</FONT></TD></TR>' for k,c,t in cols)
    color = "#d9ead3" if n in ("registro_produccion","paro","parada_maquina") else ("#fce5cd" if n.startswith("privado") else "#dae8fc")
    return f'  "{n}" [label=<<TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0" CELLPADDING="3"><TR><TD COLSPAN="3" BGCOLOR="{color}"><B>{n}</B></TD></TR>{rows}</TABLE>>];\n'
# (padre, hijo, cardinalidad del lado padre, etiqueta)  crow's foot: hijo siempre 'muchos'
E = [
 ("maquina","registro_produccion","1","tiene"),("turno","registro_produccion","1","en"),
 ("persona","registro_produccion","0..1","opera"),("referencia","registro_produccion","0..1","produce"),
 ("registro_produccion","paro","1","pierde tiempo en"),("codigo_paro","paro","1","clasifica"),
 ("subcodigo_paro","paro","0..1","detalla"),("persona","paro","0..1","interviene"),
 ("area_impacto","codigo_paro","0..1","impacta"),("codigo_paro","subcodigo_paro","1","se divide en"),
 ("subcodigo_paro","subcodigo_paro","0..1","contiene"),("subcodigo_paro","equivalencia_subcodigo","1","homologa"),
 ("maquina","parada_maquina","1","se detiene"),("motivo_parada","parada_maquina","1","explica"),
]
def logico():
    d='digraph G {\n rankdir=LR; splines=true; nodesep=0.45; ranksep=1.0; node [shape=plain, fontname="Helvetica", fontsize=10]; edge [fontname="Helvetica", fontsize=8, color="#444444"];\n'
    for n,c in T.items(): d+=node(n,c)
    for p,h,card,lab in E:
        tail = "teeodot" if card=="0..1" else "teetee"
        d+=f'  "{p}" -> "{h}" [arrowtail={tail}, arrowhead=crowodot, dir=both, label="{lab}"];\n' if False else f'  "{p}" -> "{h}" [dir=both, arrowtail={"teeodot" if card=="0..1" else "tee"}, arrowhead={"crow" if True else ""}, label="{lab}"];\n'
    d+='  "persona" -> "privado.persona_identidad" [dir=both, arrowtail=tee, arrowhead=teeodot, label="identidad (1:1)", style=dashed];\n}\n'
    return d
open("modelo_logico.dot","w").write(logico())
subprocess.run(["dot","-Tpng","-Gdpi=130","modelo_logico.dot","-o","modelo_logico.png"],check=True)
# ---------------- modelo conceptual (entidades, atributos, relaciones, cardinalidades) ----------------
def concep():
    ent = {
     "MAQUINA":["nombre"],
     "TURNO":["nombre","hora_inicio","hora_fin"],
     "PERSONA":["codigo_seudonimo","tipo_persona"],
     "REFERENCIA":["nombre","marca","volumen_cc","num_colores"],
     "REGISTRO_PRODUCCION":["fecha","secuencia","pacas_producidas","horas_trabajadas","observaciones"],
     "PARO":["minutos","equipo_ejecutor"],
     "CODIGO_PARO":["numero","nombre"],
     "SUBCODIGO_PARO":["codigo_sub","descripcion","nivel"],
     "AREA_IMPACTO":["nombre"],
     "PARADA_MAQUINA":["fecha","horas_no_trabajadas","observacion"],
     "MOTIVO_PARADA":["sistema_codificacion","codigo","nombre"],
    }
    d='graph G {\n layout=neato; overlap=false; splines=true; sep="+12"; node [fontname="Helvetica", fontsize=10]; edge [fontname="Helvetica", fontsize=9];\n'
    for e,a in ent.items():
        rows="".join(f'<TR><TD ALIGN="LEFT">{x}</TD></TR>' for x in a)
        d+=f'  {e} [shape=plain, label=<<TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0" CELLPADDING="3"><TR><TD BGCOLOR="#dae8fc"><B>{e}</B></TD></TR>{rows}</TABLE>>];\n'
    rel=[("MAQUINA","REGISTRO_PRODUCCION","1","N","tiene","total (1,1)"),("TURNO","REGISTRO_PRODUCCION","1","N","ocurre en",""),
         ("PERSONA","REGISTRO_PRODUCCION","0..1","N","opera",""),("REFERENCIA","REGISTRO_PRODUCCION","0..1","N","se produce en",""),
         ("REGISTRO_PRODUCCION","PARO","1","N","registra",""),("CODIGO_PARO","PARO","1","N","clasifica",""),
         ("SUBCODIGO_PARO","PARO","0..1","N","detalla",""),("CODIGO_PARO","SUBCODIGO_PARO","1","N","se divide en",""),
         ("AREA_IMPACTO","CODIGO_PARO","0..1","N","impacta",""),("MAQUINA","PARADA_MAQUINA","1","N","se detiene",""),
         ("MOTIVO_PARADA","PARADA_MAQUINA","1","N","explica",""),("PERSONA","PARO","0..1","N","interviene","")]
    for i,(a,b,ca,cb,lab,_) in enumerate(rel):
        r=f"R{i}"
        d+=f'  {r} [shape=diamond, style=filled, fillcolor="#fff2cc", label="{lab}", fontsize=9];\n'
        d+=f'  {a} -- {r} [label="{ca}", headlabel="", len=1.6];\n  {r} -- {b} [label="{cb}", len=1.6];\n'
    return d+"}\n"
open("modelo_conceptual.dot","w").write(concep())
subprocess.run(["neato","-Tpng","-Gdpi=110","modelo_conceptual.dot","-o","modelo_conceptual.png"],check=True)
