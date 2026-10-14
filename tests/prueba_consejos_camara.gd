extends SceneTree
## Consejos del colmadero con el modo cámara: mientras hay un consejo abierto el
## ratón queda libre (para pulsar «Entendido»), y al cerrarlo vuelve el modo cámara.
## Uso: godot --path . --script res://tests/prueba_consejos_camara.gd -- --con-consejos (con la ventana enfocada)
##   → capturas/consejos_camara/*.png

func _init() -> void:
	_prueba.call_deferred()


func _prueba() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://capturas/consejos_camara"))
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	while main.menus.screen != "inicio":
		await process_frame
	main.menus.profile["consejos"] = ["aumentos", "robar"]   # que el primero sea el del modo cámara
	main.menus.close()
	main.start_game(false, "clasico")
	var fallos := 0
	var vistos := []
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 90000 and vistos.size() < 2:
		await process_frame
		if main.g.phase == "draw" and not main.busy:
			main._finish_draw_auto()
		if not is_instance_valid(main._consejo_ui):
			continue
		var id: String = main._consejo_id
		if vistos.has(id):
			continue
		await create_timer(0.6).timeout
		if not is_instance_valid(main._consejo_ui):
			continue
		vistos.append(id)
		var ok_cam: bool = not main._cam_mode_ok()
		print("CONSEJO ", id, " · modo cámara apagado: ", ok_cam, " · cam_mode=", main.cam_mode)
		if not ok_cam or main.cam_mode:
			fallos += 1
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://capturas/consejos_camara/" + id + ".png"))
		# pulsar «Entendido»
		var b := _buscar(main._consejo_ui, "Entendido")
		if b == null:
			print("FALLO sin botón Entendido")
			fallos += 1
			break
		b.pressed.emit()
		await create_timer(0.5).timeout
		print("  cerrado · modo cámara posible: ", main._cam_mode_ok(), " (ventana enfocada: ", DisplayServer.window_is_focused(), ")")
	# sin consejos pendientes, en tu turno el modo cámara vuelve
	main.menus.profile["consejos"] = main.CONSEJOS.keys()
	var vuelve := false
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000 and not vuelve:
		await process_frame
		vuelve = main._cam_mode_ok() and not is_instance_valid(main._consejo_ui)
	print("  sin consejos · modo cámara vuelve: ", vuelve)
	if not vuelve and DisplayServer.window_is_focused():
		fallos += 1
	if vistos.is_empty() or vistos[0] != "camara":
		print("FALLO el primer consejo no fue el del modo cámara: ", vistos)
		fallos += 1
	print("CONSEJOS_CAMARA fallos=", fallos, " vistos=", vistos)
	quit(1 if fallos > 0 else 0)


func _buscar(n: Node, texto: String) -> Button:
	if n is Button and n.text == texto:
		return n
	for c in n.get_children():
		var r := _buscar(c, texto)
		if r != null:
			return r
	return null
