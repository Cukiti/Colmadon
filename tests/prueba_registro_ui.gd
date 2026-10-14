extends SceneTree
var m
var fallos := 0

func _initialize() -> void:
	call_deferred("run")

func buscar(n: Node, texto: String) -> Button:
	if n is Button and n.text == texto:
		return n
	for c in n.get_children():
		var b := buscar(c, texto)
		if b != null:
			return b
	return null

func comprobar(n: Node) -> void:
	if n is CanvasItem and not n.is_visible_in_tree():
		return
	if n is Button and not Rect2(-2, -2, 644, 364).encloses(n.get_global_rect()):
		fallos += 1
		print("FALLO UI FUERA: ", n.text)
	for c in n.get_children():
		comprobar(c)

func run() -> void:
	m = load("res://main.tscn").instantiate()
	root.add_child(m)
	m.set_process(false)
	m.autotest = false
	m.menus.settings.fullscreen = false
	m.menus.settings.ventana = ""
	m.apply_settings()
	await create_timer(2).timeout
	m.quit_to_menu()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://capturas/recorrido/registro_fallos"))
	var resolucion := DisplayServer.window_get_size()
	for idioma in ["es", "en"]:
		m.menus.settings.idioma = idioma
		m.apply_settings()
		for radio in ["off", "mia"]:
			m.radio.emisora = radio
			m.menus.open("ajustes")
			await create_timer(0.6).timeout
			var b := buscar(m.menus, "Copiar registro de fallos")
			if b == null:
				fallos += 1
				continue
			b.pressed.emit()
			await create_timer(0.2).timeout
			var copia := DisplayServer.clipboard_get()
			if not copia.begins_with("COLMADON") or copia.to_utf8_buffer().size() > 32768:
				fallos += 1
				print("FALLO UI PORTAPAPELES")
			m.menus._delete_ask.pressed.emit()  # solo confirmación, nunca borrar
			await create_timer(0.2).timeout
			comprobar(m.menus)
			m.get_viewport().get_texture().get_image().save_png("res://capturas/recorrido/registro_fallos/ajustes_%s_%s_%dx%d.png" % [idioma, radio, resolucion.x, resolucion.y])
	print("REGISTRO UI ", "SIN FALLOS" if fallos == 0 else str(fallos) + " FALLOS")
	quit(1 if fallos else 0)
