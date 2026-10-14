"""Analiza el recorrido grabado (tools/recorrido.sh) y hace el informe.

Por cada escena de capturas/recorrido/<escena>/:
  - pasa video.avi a video.mp4 (se ve en el navegador), conservando el original;
  - hojas de miniaturas (4 por segundo) con el segundo y la marca de cada momento;
  - parpadeos: píxeles que van y vuelven de un fotograma al siguiente (A→B→A)
    sin que la imagen en general se mueva;
  - errores del motor en log.txt (sin el ruido normal al cerrar Godot);
  - nodos y memoria (metricas.tsv): si crecen sin parar, es una fuga;
  - hallazgos de la auditoría del juego (auditoria.jsonl), con su fotograma.
Al final escribe capturas/recorrido/informe.html y un resumen en texto.

Uso: python tools/analizar_recorrido.py capturas/recorrido
"""
import argparse
import html
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

FPS = 30
RUIDO_LOG = ("BUG: Unreferenced static string", "leaked at exit", "Pages in use exist at exit", "ObjectDB instances leaked",
             "resources still in use at exit", "RID allocations of type", "Orphan StringName")


def leer_jsonl(p):
    if not os.path.exists(p):
        return []
    raw = Path(p).read_text(encoding="utf-8")
    lines = raw.splitlines()
    records = []
    for i, line in enumerate(lines):
        if not line.strip():
            continue
        try:
            records.append(json.loads(line))
        except json.JSONDecodeError:
            if i == len(lines) - 1 and not raw.endswith("\n"):
                continue  # escritura en curso; nunca descartar una línea corrupta intermedia
            raise
    return records


def ff(*args):
    return subprocess.run(["ffmpeg", "-loglevel", "error", "-y", *args], check=False)


def duracion(video):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", video],
                       capture_output=True, text=True)
    try:
        return float(r.stdout.strip())
    except ValueError:
        return 0.0


def leer_marcas(d):
    marcas = []
    p = os.path.join(d, "marcas.tsv")
    if os.path.exists(p):
        for linea in open(p, encoding="utf-8").read().splitlines()[1:]:
            partes = linea.split("\t")
            if len(partes) >= 3:
                marcas.append((float(partes[1]), partes[2]))
    return marcas


def marca_en(marcas, t):
    actual = ""
    for (s, txt) in marcas:
        if s <= t:
            actual = txt
    return actual


def fuente(tam):
    for f in ("C:/Windows/Fonts/verdanab.ttf", "C:/Windows/Fonts/arialbd.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, tam)
    return ImageFont.load_default()


def hojas(d, video, marcas):
    """Miniaturas a 4 por segundo, 6 columnas, 36 por hoja."""
    fr = os.path.join(d, "fotogramas")
    os.makedirs(fr, exist_ok=True)
    for f in os.listdir(fr):
        os.remove(os.path.join(fr, f))
    ff("-i", video, "-vf", "fps=4,scale=320:-1", os.path.join(fr, "%05d.jpg"))
    imgs = sorted(os.listdir(fr))
    out = []
    fnt = fuente(13)
    por_hoja = 36
    for h in range(0, len(imgs), por_hoja):
        lote = imgs[h:h + por_hoja]
        filas = (len(lote) + 5) // 6
        hoja = Image.new("RGB", (6 * 320, filas * 198), (20, 14, 10))
        dr = ImageDraw.Draw(hoja)
        for i, nombre in enumerate(lote):
            t = (h + i) / 4.0
            im = Image.open(os.path.join(fr, nombre))
            x, y = (i % 6) * 320, (i // 6) * 198
            hoja.paste(im, (x, y))
            dr.rectangle([x, y + 180, x + 320, y + 198], fill=(0, 0, 0))
            dr.text((x + 4, y + 181), "%.2fs  %s" % (t, marca_en(marcas, t)[:38]), fill=(255, 210, 60), font=fnt)
        p = os.path.join(d, "hoja_%02d.jpg" % (h // por_hoja + 1))
        hoja.save(p, quality=82)
        out.append(p)
    return out


def parpadeos(d, video):
    """Zonas que van y vuelven (A→B→A) muchas veces seguidas en el mismo sitio:
    caras que se pelean por el mismo plano (z-fighting), sombras o luces que
    tiemblan… Un ojo que parpadea o un botón que se pulsa pasan una vez: no cuentan.
    Se mira por bloques de 8×8 (en 320×180): un bloque «oscila» si en 1 s
    (30 fotogramas) tiene 8 o más A→B→A."""
    w, h, bl = 320, 180, 8
    proc = subprocess.Popen(["ffmpeg", "-loglevel", "error", "-i", video, "-vf", "scale=%d:%d" % (w, h),
                             "-f", "rawvideo", "-pix_fmt", "gray", "-"], stdout=subprocess.PIPE)
    tam = w * h
    prev2 = prev1 = None
    n = 0
    hist = []          # por fotograma: matriz de bloques con oscilación
    eventos = []
    abiertos = {}
    while True:
        buf = proc.stdout.read(tam)
        if len(buf) < tam:
            break
        f = np.frombuffer(buf, dtype=np.uint8).astype(np.int16).reshape(h, w)
        if prev2 is not None:
            d1 = prev1 - prev2
            d2 = f - prev1
            mask = (np.abs(d1) > 24) & (np.abs(d2) > 24) & (np.sign(d1) != np.sign(d2)) & (np.abs(f - prev2) < 10)
            hb = (h // bl) * bl
            bloques = mask[:hb].reshape(h // bl, bl, w // bl, bl).sum(axis=(1, 3)) >= 3
            # cámara moviéndose o sacudida: todo cambia, no es parpadeo
            mov = float(np.mean(np.abs(f - prev2)))
            if mov > 3.0 or bloques.mean() > 0.15:
                bloques = np.zeros_like(bloques)
            hist.append(bloques)
            if len(hist) > max(1, round(FPS)):
                hist.pop(0)
            veces = np.sum(hist, axis=0)
            malos = veces >= max(3, round(FPS * 8 / 30))   # casi cada fotograma: un ojo que parpadea o una animación no llegan
            if n < 3 * FPS:
                malos[:] = False      # pantalla de carga (la ficha que gira)
            if malos.any():
                for (by, bx) in np.argwhere(malos):
                    key = (int(by), int(bx))
                    last = abiertos.get(key)
                    if last is not None and n - 1 - last["hasta"] <= max(1, round(FPS / 2)):
                        last["hasta"] = n - 1
                        last["pixeles"] = max(last["pixeles"], int(veces[by, bx]))
                    else:
                        last = {"fotograma":n-1, "hasta":n-1, "segundo":round((n-1)/FPS, 2), "pixeles":int(veces[by,bx]), "zona":[int(bx)*bl*2,int(by)*bl*2,int(bx+1)*bl*2,int(by+1)*bl*2]}
                        abiertos[key] = last
                        eventos.append(last)
        prev2, prev1 = prev1, f
        n += 1
    proc.stdout.close()
    proc.wait()
    # Agregar al detectar, en vez de almacenar un evento por bloque/frame y compararlos todos.
    # Cada zona conserva su intervalo exacto; el coste de agrupación es lineal.
    return [e for e in eventos if e["hasta"] - e["fotograma"] >= max(1, round(FPS * 0.4))]


def errores_log(d):
    p = os.path.join(d, "log.txt")
    if not os.path.exists(p):
        return []
    out = {}
    lineas = open(p, encoding="utf-8", errors="replace").read().splitlines()
    for i, l in enumerate(lineas):
        if ("ERROR" in l or "WARNING" in l) and not any(r in l for r in RUIDO_LOG):
            donde = lineas[i + 1].strip() if i + 1 < len(lineas) and "at:" in lineas[i + 1] else ""
            k = l.strip() + " " + donde
            out[k] = out.get(k, 0) + 1
    return [{"texto": k, "veces": v} for k, v in out.items()]


def fugas(d):
    p = os.path.join(d, "metricas.tsv")
    if not os.path.exists(p):
        return None
    filas = [l.split("\t") for l in open(p, encoding="utf-8").read().splitlines()[1:] if l.strip()]
    if len(filas) < 6:
        return None
    nodos = [int(f[1]) for f in filas]
    mem = [float(f[3]) for f in filas]
    ms = [float(f[4]) for f in filas]
    # mitad final contra mitad inicial (las escenas cambian, así que solo avisa si crece mucho)
    a, b = np.mean(nodos[: len(nodos) // 3]), np.mean(nodos[-len(nodos) // 3:])
    return {"nodos_ini": int(a), "nodos_fin": int(b), "crece": bool(b > a * 1.35 and b - a > 300),
            "mem_max": float(max(mem)), "ms_max": float(max(ms)), "ms_med": round(float(np.median(ms)), 2)}


def extraer_frame(video, frame, salida):
    if frame < 0:
        raise ValueError("El fotograma debe ser positivo o cero")
    r = ff("-i", video, "-vf", "select=eq(n\\,%d)" % frame, "-frames:v", "1", "-vsync", "0", salida)
    if r.returncode or not os.path.exists(salida):
        raise RuntimeError("No se pudo extraer el fotograma exacto")
    return salida


def foto_de(d, video, segundo, nombre):
    p = os.path.join(d, nombre)
    ff("-ss", "%.2f" % segundo, "-i", video, "-frames:v", "1", "-vf", "scale=640:-1", p)
    return p


def cobertura_video(video, d):
    result = subprocess.run(["ffprobe", "-v", "error", "-count_frames", "-select_streams", "v:0", "-show_entries", "stream=nb_read_frames,avg_frame_rate,width,height", "-of", "json", video], capture_output=True, text=True, check=True)
    stream = json.loads(result.stdout)["streams"][0]
    num, den = stream["avg_frame_rate"].split("/")
    fps = float(num) / float(den)
    frames = int(stream["nb_read_frames"])
    trace = os.path.join(d, "frames.jsonl")
    records = leer_jsonl(trace)
    indices = [x["fotograma"] for x in records]
    continuous = indices == list(range(1, len(indices) + 1))
    return {"fps": fps, "fotogramas_video": frames, "fotogramas_auditados": len(records), "traza_continua": continuous, "ancho": stream["width"], "alto": stream["height"], "fases": sorted(set(x["fase"] for x in records)), "pantallas": sorted(set(x["pantalla"] for x in records)), "limite": "Cada fotograma se decodifica para parpadeos; composición y significado requieren revisión visual. La grabación incluye carga y cierre fuera de la vida del bot."}


def documentar_bugs(raiz, resumen):
    lines = ["# Hallazgos del recorrido", "", "Candidatos automáticos y recomendaciones de diseño; no son bugs confirmados sin inspección de la evidencia.", ""]
    proposals = {
        "texto": "Separar avisos, alinear texto y acciones, respetar margen seguro y probar textos ES/EN.",
        "boton": "Diferenciar acción principal, secundaria y volver mediante texto, ubicación y estilo; no depender solo del color.",
        "cabeza": "Separar la cabeza del colmadero de la tabla y revisar desde el punto de compra.",
        "flotante": "Alinear base, soporte y sombra; excluir vuelos y objetos colgados intencionados.",
        "solap": "Revisar profundidad y contornos desde la cámara que produjo el hallazgo.",
    }
    for r in resumen:
        lines += ["## " + r["escena"], "", "Bot: " + r["bot"].get("estado", "NO_REVISADO"), ""]
        lines += ["Cobertura: `" + json.dumps(r.get("cobertura", {}), ensure_ascii=False) + "`", ""]
        for i, item in enumerate(r.get("auditoria", []), 1):
            tipo = item["tipo"]
            recommendation = next((v for k, v in proposals.items() if k in tipo), "Reproducir el estado y revisar la captura antes de modificar el juego.")
            lines += [f"### {r['escena']}-{i:03d} · {tipo}", "", "Estado: CANDIDATO · categoría: diseño visual/usabilidad/espacio según el hallazgo.", "", f"Fotograma {item['fotograma']} · {item['segundo']:.2f} s · {item.get('momento', '')}", "", item["detalle"], "", "Recomendación: " + recommendation, "", "Evidencia: " + item.get("foto", "auditoria.jsonl"), ""]
        lines += ["Revisión de diseño pendiente: jerarquía de botones de Pizarra; alineación del cartel de turno y mensajes durante la mano; objetos y sombras; cabeza/tabla del mostrador. La ausencia de alertas geométricas no confirma que estos diseños sean claros.", ""]
    Path(raiz, "bugs.md").write_text("\n".join(lines), encoding="utf-8")


def analizar(raiz):
    global FPS
    escenas = sorted(e for e in os.listdir(raiz) if os.path.isdir(os.path.join(raiz, e)))
    resumen = []
    launch_path = Path(raiz, "sesion.json")
    launch = json.loads(launch_path.read_text(encoding="utf-8-sig")) if launch_path.exists() else []
    if isinstance(launch, dict):
        launch = [launch]
    external = {x["escena"]:x["estado"] for x in launch}
    for e in escenas:
        d = os.path.join(raiz, e)
        rb = os.path.join(d, "resultado_bot.json")
        bot = json.loads(Path(rb).read_text(encoding="utf-8")) if os.path.exists(rb) else {"estado": external.get(e, "NO_REVISADO"), "casos": [], "resultado_bot_ausente":True}
        avi = os.path.join(d, "video.avi")
        mp4 = os.path.join(d, "video.mp4")
        if os.path.exists(avi):
            ff("-i", avi, "-c:v", "libx264", "-preset", "veryfast", "-crf", "24", "-pix_fmt", "yuv420p", "-an", mp4)
            if not os.path.exists(mp4) or os.path.getsize(mp4) == 0:
                raise RuntimeError("La conversión no produjo vídeo: " + avi)
        if not os.path.exists(mp4):
            pa = os.path.join(d, "auditoria.jsonl")
            aud = leer_jsonl(pa)
            for item in aud:
                item["foto"] = ""
            records = leer_jsonl(os.path.join(d, "frames.jsonl"))
            coverage = {"fotogramas_auditados":len(records), "traza_continua":[x["fotograma"] for x in records] == list(range(1,len(records)+1)), "fotogramas_video":0, "estado_video":"NO_GRABADO", "fases":sorted(set(x["fase"] for x in records))}
            resumen.append({"escena": e, "sin_video": True, "bot": bot, "errores": errores_log(d), "auditoria": aud, "cobertura":coverage})
            continue
        marcas = leer_marcas(d)
        r = {"escena": e, "duracion": round(duracion(mp4), 1), "marcas": marcas, "bot": bot}
        r["cobertura"] = cobertura_video(mp4, d)
        FPS = r["cobertura"]["fps"]
        r["hojas"] = [os.path.relpath(h, raiz) for h in hojas(d, mp4, marcas)]
        r["parpadeos"] = parpadeos(d, mp4)
        for i, p in enumerate(r["parpadeos"][:12]):
            p["foto"] = os.path.relpath(foto_de(d, mp4, p["segundo"], "parpadeo_%02d.jpg" % i), raiz)
            p["momento"] = marca_en(marcas, p["segundo"])
        r["errores"] = errores_log(d)
        r["metricas"] = fugas(d)
        aud = []
        pa = os.path.join(d, "auditoria.jsonl")
        if os.path.exists(pa):
            for i, l in enumerate(open(pa, encoding="utf-8").read().splitlines()):
                h = json.loads(l)
                h["foto"] = os.path.relpath(foto_de(d, mp4, h["segundo"], "hallazgo_%02d.jpg" % i), raiz)
                h["momento"] = marca_en(marcas, h["segundo"])
                aud.append(h)
        r["auditoria"] = aud
        resumen.append(r)
    Path(raiz, "resumen.json").write_text(json.dumps(resumen, ensure_ascii=False, indent=1), encoding="utf-8")
    documentar_bugs(raiz, resumen)
    informe(raiz, resumen)
    for r in resumen:
        print("%-18s %6ss  auditoría %2d  parpadeos %2d  errores %2d  %s" % (
            r["escena"], r.get("duracion", "-"), len(r.get("auditoria", [])), len(r.get("parpadeos", [])),
            len(r.get("errores", [])), "FUGA" if (r.get("metricas") or {}).get("crece") else ""))


def revision():
    """La revisión escrita a mano (docs/recorrido.md, sección «Primera revisión»), en el informe."""
    p = os.path.join(os.path.dirname(__file__), "..", "docs", "recorrido.md")
    if not os.path.exists(p):
        return ""
    texto = Path(p).read_text(encoding="utf-8")
    if "## Primera revisión" not in texto:
        return ""
    texto = texto.split("## Primera revisión", 1)[1]
    out = ["<h2>Revisión</h2>"]
    for linea in texto.splitlines()[1:]:
        l = html.escape(linea.strip())
        l = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", l)
        l = re.sub(r"`(.+?)`", r"<code>\1</code>", l)
        if l.startswith("### "):
            out.append("<h3>%s</h3>" % l[4:])
        elif l.startswith("- "):
            out.append("<p>• %s</p>" % l[2:])
        elif l:
            out.append("<p>%s</p>" % l)
    return "\n".join(out)


def informe(raiz, resumen):
    e = html.escape
    h = ["""<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Recorrido de Colmadón</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{font-family:Verdana,sans-serif;background:#1b120b;color:#f6ead2;margin:0 auto;max-width:1100px;padding:16px}
h1{color:#ffcc38}h2{color:#ffcc38;border-bottom:2px solid #6b3f1d;padding-bottom:4px;margin-top:40px}
table{border-collapse:collapse;width:100%}td,th{border:1px solid #6b3f1d;padding:4px 8px;text-align:left}
.ok{color:#7fd88a}.mal{color:#ff7a6a}video,img{max-width:100%;border:2px solid #6b3f1d;border-radius:4px}
.h{display:grid;grid-template-columns:240px 1fr;gap:10px;margin:8px 0;background:#2a1b10;padding:8px;border-radius:6px}
code{color:#ffcc38}</style></head><body><h1>Recorrido de Colmadón</h1>
<p>Cada escena se grabó a 30 fotogramas por segundo fijos (no se pierde ninguno). La auditoría la hace el
propio juego mientras se graba; los parpadeos se buscan fotograma a fotograma en el vídeo.
Son alertas para revisar, no bugs confirmados. COMPLETADO indica que el bot terminó sus objetivos,
no que el juego esté libre de fallos. La revisión histórica siguiente no corresponde necesariamente a esta sesión.</p>""" + revision() + """<table>
<tr><th>Escena</th><th>Duración</th><th>Auditoría</th><th>Parpadeos</th><th>Errores del motor</th><th>Memoria</th></tr>"""]
    for r in resumen:
        met = r.get("metricas") or {}
        def n(k):
            v = len(r.get(k, []))
            return '<span class="%s">%d</span>' % ("mal" if v else "ok", v)
        h.append("<tr><td><a href='#%s'>%s</a></td><td>%ss</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>" % (
            e(r["escena"]), e(r["escena"]), r.get("duracion", "-"), n("auditoria"), n("parpadeos"), n("errores"),
            '<span class="mal">posible fuga</span>' if met.get("crece") else '<span class="ok">bien</span>'))
    h.append("</table>")
    for r in resumen:
        h.append("<h2 id='%s'>%s</h2>" % (e(r["escena"]), e(r["escena"])))
        bot = r.get("bot", {"estado": "NO_REVISADO"})
        h.append("<p><b>Resultado del bot:</b> %s</p>" % e(str(bot.get("estado", "NO_REVISADO"))))
        if bot.get("espacial"):
            h.append("<p><b>Auditoría espacial (candidatos, no bugs confirmados):</b> <code>%s</code></p>" % e(json.dumps(bot["espacial"], ensure_ascii=False)))
        for caso in bot.get("casos", []):
            h.append("<p>%s · %s · %s</p>" % (e(str(caso.get("caso", ""))), e(str(caso.get("estado", "NO_REVISADO"))), e(str(caso.get("detalle", "")))))
        if r.get("sin_video"):
            h.append("<p class='mal'>No se grabó vídeo (ver log.txt).</p>")
        else:
            fps = r.get("cobertura", {}).get("fps", FPS)
            h.append("<video id='video_%s' controls preload='metadata' src='%s/video.mp4'></video>" % (e(r["escena"]), e(r["escena"])))
            h.append("<p><button onclick=\"paso('video_%s',-1,%s)\">Fotograma anterior</button> <button onclick=\"paso('video_%s',1,%s)\">Fotograma siguiente</button> <input type='number' min='0' placeholder='Nº de fotograma' onchange=\"ir('video_%s',this.value,%s)\"></p>" % (e(r["escena"]), fps, e(r["escena"]), fps, e(r["escena"]), fps))
            h.append("<p><b>Cobertura medida:</b> <code>%s</code></p>" % e(json.dumps(r.get("cobertura", {}), ensure_ascii=False)))
        for x in r.get("auditoria", []):
            h.append("<div class='h'><img src='%s'><div><b>%s</b> · %.2f s · <i>%s</i><br>%s</div></div>" % (
                e(x["foto"]), e(x["tipo"]), x["segundo"], e(x.get("momento", "")), e(x["detalle"])))
        for x in r.get("parpadeos", []):
            if "foto" in x:
                h.append("<div class='h'><img src='%s'><div><b>parpadeo</b> · %.2f s (hasta %.2f s) · <i>%s</i><br>"
                         "%d píxeles van y vuelven en la zona %s (en 640×360)</div></div>" % (
                             e(x["foto"]), x["segundo"], x["hasta"] / FPS, e(x.get("momento", "")), x["pixeles"], x["zona"]))
        for x in r.get("errores", []):
            h.append("<p class='mal'><code>%s</code> × %d</p>" % (e(x["texto"]), x["veces"]))
        met = r.get("metricas")
        if met:
            h.append("<p>Nodos: %d al principio → %d al final · memoria máx. %.0f MB · proceso %.1f ms (máx. %.1f)</p>" % (
                met["nodos_ini"], met["nodos_fin"], met["mem_max"], met["ms_med"], met["ms_max"]))
        for hj in r.get("hojas", []):
            h.append("<p><img src='%s' loading='lazy'></p>" % e(hj))
    h.append("<script>function paso(id,n,fps){const v=document.getElementById(id);v.pause();v.currentTime=Math.max(0,Math.round(v.currentTime*fps)/fps+n/fps);}function ir(id,n,fps){const v=document.getElementById(id);v.pause();v.currentTime=Math.max(0,Number(n)/fps);}</script></body></html>")
    Path(raiz, "informe.html").write_text("\n".join(h), encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Audita vídeo completo y genera informe de bugs/diseño")
    parser.add_argument("raiz", nargs="?", default="capturas/recorrido")
    parser.add_argument("--video", help="Vídeo para extracción exacta")
    parser.add_argument("--fotograma", type=int)
    parser.add_argument("--salida", default="fotograma.png")
    args = parser.parse_args()
    if args.fotograma is not None:
        if not args.video:
            parser.error("--fotograma requiere --video")
        print(extraer_frame(args.video, args.fotograma, args.salida))
    else:
        analizar(args.raiz)
