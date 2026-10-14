extends Node
## UI aislada: datos simulados, sin solicitudes de red ni perfiles reales.
class RedSimulada extends "res://scripts/red.gd":
	func listar_salas(_nombre: String, filtros := {}) -> Dictionary:
		await get_tree().process_frame
		var salas := []
		for i in range(12):
			var r := {"code":"TEST%02d" % i, "anfitrion":"Anfitrión con nombre bastante largo", "modo":"clasico" if i % 2 == 0 else "aumentos", "meta":200, "jugadores":2, "estado":"esperando" if i % 2 == 0 else "jugando", "mano":3, "puede_entrar":i % 2 == 0}
			if filtros.get("modo", "") != "" and filtros.modo != r.modo: continue
			if filtros.get("estado", "") != "" and filtros.estado != r.estado: continue
			salas.append(r)
		return {"salas":salas}
var m
var fallos := 0
func _ready() -> void:
	call_deferred("run")
func controles(n: Node) -> Array:
	var out := [n] if n is Control else []
	for c in n.get_children(): out.append_array(controles(c))
	return out
func run() -> void:
	if not OS.get_cmdline_user_args().has("--autotest"):
		get_tree().quit(1)
		return
	m = load("res://main.tscn").instantiate()
	get_tree().root.add_child(m)
	await get_tree().create_timer(2).timeout
	m.autotest = false
	m.set_process(false)
	m.quit_to_menu("amigos")
	m.red.set_script(RedSimulada)
	var salida := "res://capturas/recorrido/integracion_salas/ui_%dx%d" % [get_tree().root.size.x, get_tree().root.size.y]
	DirAccess.make_dir_recursive_absolute(salida)
	for idioma in ["es", "en"]:
		for tam in range(3):
			m.menus.settings.idioma = idioma
			m.menus.settings.texto = tam
			m.apply_settings()
			m.menus.open("publicas")
			await get_tree().create_timer(1).timeout
			for c in controles(m.menus._page):
				if not (c is Button or c is Label) or not c.is_visible_in_tree(): continue
				var padre = c.get_parent()
				var recortado := false
				while padre != null:
					if padre is ScrollContainer:
						recortado = true
						if c.get_global_rect().end.x > padre.get_global_rect().end.x + 2:
							fallos += 1
							print("FALLO BUSCADOR FILA ", idioma, tam, " ", c.text)
					padre = padre.get_parent()
				if not recortado and not Rect2(-2,-2,644,364).encloses(c.get_global_rect()):
					fallos += 1
					print("FALLO BUSCADOR UI ", idioma, tam, " ", c.text, " ", c.get_global_rect())
			get_tree().root.get_texture().get_image().save_png(salida + "/%s_%d.png" % [idioma,tam])
	print("BUSCADOR UI ", fallos, " FALLOS")
	m.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if fallos else 0)
