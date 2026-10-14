import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
spec = importlib.util.spec_from_file_location("analizador", Path(__file__).parents[1] / "tools/analizar_recorrido.py")
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)
class Pruebas(unittest.TestCase):
    def test_sin_video_conserva_alertas_y_recomendaciones(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "menus"
            p.mkdir()
            (p / "resultado_bot.json").write_text(json.dumps({"estado":"COMPLETADO"}))
            (p / "auditoria.jsonl").write_text(json.dumps({"fotograma":12,"segundo":0.4,"tipo":"texto_solapado_candidato","detalle":"Aviso tapa una acción"}) + "\n")
            a.analizar(tmp)
            r = json.loads((Path(tmp)/"resumen.json").read_text())
            self.assertEqual(len(r[0]["auditoria"]), 1)
            self.assertIn("Recomendación", (Path(tmp)/"bugs.md").read_text(encoding="utf-8"))
            self.assertIn("No se grabó vídeo", (Path(tmp)/"informe.html").read_text(encoding="utf-8"))
    def test_traza_parcial_no_oculta_corrupcion_intermedia(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)/"frames.jsonl"
            p.write_text('{"fotograma":1}\n{"fotograma":')
            self.assertEqual(a.leer_jsonl(p), [{"fotograma":1}])
            p.write_text('{"fotograma":1}\ncorrupta\n{"fotograma":2}\n')
            with self.assertRaises(json.JSONDecodeError):
                a.leer_jsonl(p)
    def test_video_completo_y_extraccion_exacta(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)
            video = str(p/"video.mp4")
            result = a.ff("-f", "lavfi", "-i", "testsrc=size=160x90:rate=30:duration=1", "-pix_fmt", "yuv420p", video)
            self.assertEqual(result.returncode, 0)
            (p/"frames.jsonl").write_text("\n".join(json.dumps({"fotograma":i,"fase":"play","pantalla":"mesa"}) for i in range(1,31)) + "\n")
            c = a.cobertura_video(video, tmp)
            self.assertEqual(c["fotogramas_video"], 30)
            self.assertEqual(c["fotogramas_auditados"], 30)
            self.assertTrue(c["traza_continua"])
            output = str(p/"exacto.png")
            a.extraer_frame(video, 17, output)
            self.assertTrue(Path(output).exists())
    def test_parpadeo_persistente_agregado_sin_perder_frames(self):
        with tempfile.TemporaryDirectory() as tmp:
            video = str(Path(tmp)/"parpadeo.mkv")
            filt = "nullsrc=size=320x180:rate=30:duration=4,geq=lum='if(lt(X,20)*lt(Y,20),if(mod(N,2),255,0),0)':cb=128:cr=128"
            result = a.ff("-f", "lavfi", "-i", filt, "-c:v", "ffv1", video)
            self.assertEqual(result.returncode, 0)
            items = a.parpadeos(tmp, video)
            self.assertTrue(items)
            self.assertTrue(all(x["fotograma"] >= 89 for x in items))
            self.assertTrue(all(x["hasta"] < 120 for x in items))
            self.assertLess(len(items), 15)
    def test_frame_negativo_rechazado(self):
        with self.assertRaises(ValueError):
            a.extraer_frame("no_existe.mp4", -1, "salida.png")
if __name__ == "__main__":
    unittest.main()
