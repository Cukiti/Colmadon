extends SceneTree
## Fotos del peso de los personajes (muelles): empujón en el probador y golpe en la mesa.
## Uso: godot --path . --script res://tests/foto_peso.gd  → capturas/peso/*.png

func _init() -> void:
	_foto.call_deferred()


func _foto() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://capturas/peso"))
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	while main.menus.screen != "inicio":
		await process_frame
	await create_timer(0.5).timeout
	main.menus.open("personaje")
	await create_timer(3.0).timeout
	var ch: Node3D = main.view.mirror_char
	await _guardar("probador_quieto")
	# empujón de lado: el tronco se va, la cabeza y el pelo se pasan y vuelven
	ch.empujar(ch.global_transform.basis.x, 1.6)
	for i in 5:
		await create_timer(0.08).timeout
		await _guardar("probador_empujon_%d" % i)
	await create_timer(1.5).timeout
	ch.act("stagger")
	await create_timer(0.12).timeout
	await _guardar("probador_trastabilla")
	main.menus.close()
	main.start_game(false, "clasico")
	await create_timer(4.0).timeout
	main.view.bump_table(2.5)
	await create_timer(0.1).timeout
	await _guardar("mesa_golpe")
	await create_timer(1.5).timeout
	await _guardar("mesa_quieta")
	quit()


func _guardar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://capturas/peso/" + nombre + ".png"))
	print("FOTO ", nombre)
