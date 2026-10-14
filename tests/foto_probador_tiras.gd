extends SceneTree
## Fotos de las tiras de opciones del probador (paso 4: paneles con retratos).
## Uso: godot --path . --script res://tests/foto_probador_tiras.gd → capturas/probador_tiras/*.png

func _init() -> void:
	_foto.call_deferred()


func _foto() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://capturas/probador_tiras"))
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	while main.menus.screen != "inicio":
		await process_frame
	await create_timer(0.5).timeout
	for par in [["cuerpo", "Cabeza"], ["cuerpo", "Piel"], ["cuerpo", "Cara"], ["cuerpo", "Cuerpo"], ["ropa", "Estampado"], ["ropa", "Camisa"], ["detalles", "Gafas"], ["detalles", "Cadena"]]:
		main.menus._mirror_tab = par[0]
		main.menus._fila_activa = par[1]
		main.menus.open("personaje")
		main.menus._enfocar_fila(par[1])
		await create_timer(2.5).timeout
		await _guardar(par[1].to_lower())
	# tocar una miniatura cambia al personaje
	main.menus._mirror_tab = "cuerpo"
	main.menus._fila_activa = "Cabeza"
	main.menus.open("personaje")
	await create_timer(1.0).timeout
	var antes: String = main.menus.profile.hat
	var tira := _buscar_tira(main.menus)
	var boton: Button = null
	if tira != null:
		for b in tira.get_children():
			if not b.button_pressed:
				boton = b
				break
	if boton != null:
		boton.pressed.emit()
	await create_timer(1.0).timeout
	print("TIRA cambio sombrero: ", antes, " → ", main.menus.profile.hat, " marcado=", boton != null and boton.button_pressed)
	print("TIRA miniaturas en caché: ", main.menus._minis.size())
	quit()


func _buscar_tira(n: Node) -> HFlowContainer:
	for c in n.get_children():
		if c is HFlowContainer and c.get_child_count() > 0 and c.get_child(0).has_meta("cambio"):
			return c
		var r := _buscar_tira(c)
		if r != null:
			return r
	return null


func _guardar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://capturas/probador_tiras/" + nombre + ".png"))
	print("FOTO ", nombre)
