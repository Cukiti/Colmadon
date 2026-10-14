extends SceneTree
## Fotos de un bot cogiendo y poniendo una ficha (¿se descoloca el cuerpo?).
## Uso: godot --path . --script res://tests/foto_coger_ficha.gd → capturas/coger_ficha/*.png

func _init() -> void:
	_foto.call_deferred()


func _foto() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://capturas/coger_ficha"))
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	while main.menus.screen != "inicio":
		await process_frame
	main.menus.profile["consejos"] = main.CONSEJOS.keys()
	main.menus.close()
	main.start_game(false, "clasico")
	var fotos := 0
	var t0 := Time.get_ticks_msec()
	while fotos < 2 and Time.get_ticks_msec() - t0 < 120000:
		await process_frame
		if main.g.phase == "draw" and not main.busy:
			main._finish_draw_auto()
		if main.g.phase == "play" and main.g.turn == 0 and not main.busy and not main.view.animating:
			var mv: Array = main.g.legal_moves(0)
			if mv.is_empty():
				main._pass_button()
			else:
				main._act_play(mv[0].tile, mv[0].side)
			await create_timer(0.5).timeout
			continue
		# un bot (silla 1 o 3, de lado) empieza a jugar: 8 fotos seguidas
		if main.g.phase == "play" and main.g.turn in [1, 3] and main.view.heads[main.g.turn].state == "think":
			var s: int = main.g.turn
			var cadena: int = main.g.chain.size()
			while main.g.chain.size() == cadena and Time.get_ticks_msec() - t0 < 120000:
				await process_frame
			for k in 8:
				await _guardar("silla%d_%d_%d" % [s, fotos, k])
				await create_timer(0.09).timeout
			fotos += 1
	quit()


func _guardar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://capturas/coger_ficha/" + nombre + ".png"))
