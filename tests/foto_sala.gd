extends SceneTree
## Foto de la pizarra «Sala con amigos» (y con las opciones cambiadas) para revisarla.
## Uso: godot --path . --script res://tests/foto_sala.gd -- --prueba-sala-foto  → capturas/sala_*.png

func _init() -> void:
	_foto.call_deferred()


func _foto() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	while main.menus.screen != "inicio":
		await process_frame
	await create_timer(1.0).timeout
	main.menus.open("amigos")
	await create_timer(3.0).timeout
	await _guardar("sala_amigos")
	# cambiar las cuatro opciones y repetir
	main.menus._sala_modo = "clasico"
	main.menus._sala_armas = true
	main.menus.open("amigos")
	main.view.cam_set("pizarra")
	await create_timer(3.0).timeout
	await _guardar("sala_amigos_cambiada")
	main.menus._sala_publica = true
	main.menus.open("amigos")
	main.view.cam_set("pizarra")
	await create_timer(3.0).timeout
	await _guardar("sala_amigos_publica")
	# buscar salas: vacía (lo que diga el servidor) y con salas de ejemplo
	main.menus._sala_publica = false
	main.menus.open("publicas")
	await create_timer(4.0).timeout
	await _guardar("buscar_salas")
	var rows: VBoxContainer = main.menus._page.find_children("*", "VBoxContainer", true, false).filter(func(v): return v.get_parent() is ScrollContainer)[0]
	for t in main.menus._page.find_children("*", "Timer", true, false):
		t.stop()
	for c in rows.get_children():
		c.queue_free()
	var ancho: float = rows.get_parent().size.x - 4
	for room in [{"anfitrion": "Potito", "jugadores": 2, "modo": "aumentos", "meta": 100, "estado": "esperando", "mano": 0, "code": "AAA111", "puede_entrar": true},
		{"anfitrion": "La Yeya del barrio", "jugadores": 3, "modo": "clasico", "meta": 200, "estado": "jugando", "mano": 4, "code": "BBB222", "puede_entrar": true},
		{"anfitrion": "Chichí", "jugadores": 4, "modo": "aumentos", "meta": 200, "estado": "jugando", "mano": 2, "code": "CCC333", "puede_entrar": false}]:
		rows.add_child(main.menus._sala_tarjeta(room, ancho, main.menus._page, Label.new()))
	await create_timer(1.0).timeout
	await _guardar("buscar_salas_lista")
	quit()


func _guardar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://capturas/")
	root.get_viewport().get_texture().get_image().save_png(dir + nombre + ".png")
	print("FOTO ", dir + nombre + ".png")
