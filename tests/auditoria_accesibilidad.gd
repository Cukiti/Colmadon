extends "res://tests/revisar_ingles.gd"
## Reutiliza los estados preparados, sin conexión online. --qa-estaticas --autotest.
class Auditor extends Node:
	var m
	var frame := 0
	var vistos := {}
	var archivo: FileAccess
	func _process(_dt: float) -> void:
		frame += 1
		if frame % 30 == 0:
			inspeccionar(m.ui)
	func inspeccionar(n: Node) -> void:
		if n is CanvasItem and not n.is_visible_in_tree():
			return
		if n is ScrollContainer:
			return  # filas fuera del área visible están recortadas y son desplazables
		if n is Label or n is Button:
			var texto: String = n.text if n.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED else n.tr(n.text)
			var tipo := ""
			if texto != "" and not Rect2(-2, -2, 644, 364).encloses(n.get_global_rect()):
				tipo = "fuera"
			elif texto != "" and not (n is Label and (n.autowrap_mode != TextServer.AUTOWRAP_OFF or n.clip_text)):
				for linea in texto.split("\n"):
					if n.get_theme_font("font").get_string_size(linea, HORIZONTAL_ALIGNMENT_LEFT, -1, n.get_theme_font_size("font_size")).x > n.size.x + 2:
						tipo = "ancho"
			if tipo != "":
				var key: String = texto + tipo + m.menus.screen
				if not vistos.has(key):
					vistos[key] = true
					archivo.store_line(JSON.stringify({"texto": texto, "tipo": tipo, "menu": m.menus.screen, "rect": str(n.get_global_rect())}))
					archivo.flush()
		for c in n.get_children():
			inspeccionar(c)

func estaticas(idioma: String) -> bool:
	observador.set_process(false)
	var auditor := Auditor.new()
	auditor.m = m
	auditor.archivo = FileAccess.open(salida + "/accesibilidad.jsonl", FileAccess.WRITE)
	root.add_child(auditor)
	var antes: Dictionary = m.menus.settings.duplicate(true)
	m.menus._settings_path = "user://ajustes_auditoria_accesibilidad_prueba.cfg"
	m.menus._profile_path = "user://perfil_auditoria_accesibilidad_prueba.cfg"
	m.menus.settings.texto = 2
	m.menus.settings.daltonico = true
	m.menus.settings.menos_movimiento = true
	m.apply_settings()
	var resultado: bool = await super.estaticas(idioma)
	m.menus.settings = antes
	m.apply_settings()
	print("AUDITORIA ACCESIBILIDAD: ", auditor.vistos.size(), " incidencias")
	return resultado and auditor.vistos.is_empty()
