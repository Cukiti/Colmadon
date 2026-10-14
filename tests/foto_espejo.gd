extends SceneTree
## Foto del espejo (pantalla «Tu personaje») para revisar el reflejo.
## Uso: godot --path . --script res://tests/foto_espejo.gd -- --prueba-sala-espejo  → capturas/espejo*.png

func _init() -> void:
	_foto.call_deferred()


func _foto() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	while main.menus.screen != "inicio":
		await process_frame
	await create_timer(0.5).timeout
	main.menus.open("personaje")
	await create_timer(3.0).timeout
	await _guardar("espejo")
	main.view.mirror_react("dance")
	await create_timer(0.8).timeout
	await _guardar("espejo_bailando")
	# lo que se ve al cambiar cada cosa
	for e in ["cara", "torso", "piernas"]:
		main.view.cam_to("probador_" + e, 0.5)
		await create_timer(1.2).timeout
		await _guardar("espejo_" + e)
	main.view.probador_girar(PI * 0.75)
	main.view.cam_to("probador_cuerpo", 0.5)
	await create_timer(1.2).timeout
	await _guardar("espejo_girado")
	main.menus._mirror_tab = "arma"
	main.menus.open("personaje")
	await create_timer(1.5).timeout
	await _guardar("espejo_arma")
	main.menus._mirror_tab = "cuerpo"
	# en partida no hay nadie en el probador
	main.menus.close()
	main.start_game(false, "clasico")
	await create_timer(3.0).timeout
	print("PROBADOR en partida visible = ", main.view.probador.visible)
	main.view.cam_set("espejo")
	await create_timer(0.3).timeout
	await _guardar("espejo_en_partida")
	quit()


func _guardar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://capturas/" + nombre + ".png"))
	print("FOTO ", nombre)
