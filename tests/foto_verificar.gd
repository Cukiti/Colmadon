extends SceneTree
## Fotos de la mesa como objeto: reacomodar la mano arrastrando (F10) y la
## verificación de la capicúa con VISTO ✓ / RECLAMAR (V1).
## Uso: godot --path . --script res://tests/foto_verificar.gd → capturas/verificar/*.png

func _init() -> void:
	_foto.call_deferred()


func _foto() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://capturas/verificar"))
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	while main.menus.screen != "inicio":
		await process_frame
	main.menus.profile["consejos"] = main.CONSEJOS.keys()
	main.menus.close()
	main.start_game(false, "clasico")
	var t0 := Time.get_ticks_msec()
	while not (main.g.phase == "play" and main.g.turn == 0 and not main.g.chain.is_empty() and not main.view.animating):
		if main.g.phase == "draw" and main.view.pool_nodes.size() == 28:
			var libres: Array = range(28).filter(func(x): return not main.view.pool_taken.has(x))
			if not libres.is_empty():
				main._draw_pick(libres.front())
		await create_timer(0.3).timeout
		if Time.get_ticks_msec() - t0 > 90000:
			print("FALLO no llegó mi turno"); quit(1); return
	await create_timer(0.5).timeout
	# F10: arrastrar la primera ficha hacia el hueco 4 de la bandeja
	var antes: Array = main.g.hands[0].duplicate()
	var r: Array = main.view.hand_rects()
	main.view.start_drag(0)
	for k in 20:
		main.view.drag_to(r[min(4, r.size() - 1)].get_center() + Vector2(6, 0))
		await process_frame
	await _guardar("arrastrando")
	var slot: int = main.view.drag_slot
	main.view.end_drag()
	main._acomodar(0, slot)
	main._refresh()
	await create_timer(0.4).timeout
	await _guardar("reacomodada")
	print("ORDEN ", antes, " -> ", main.g.hands[0], " hueco ", slot)
	# V1: capicúa forzada (las dos puntas iguales, una sola ficha en la mano)
	main.g.right_end = main.g.left_end
	var t := Vector2i(main.g.left_end, (main.g.left_end + 1) % 7)
	main.g.hands[0] = [t]
	main._act_play(t, -1)
	main._refresh()
	while main.g.phase == "play":
		await process_frame
	await create_timer(3.2).timeout
	await _guardar("verificar")
	print("VERIFICANDO ", main._ver_pending, " ", main.g.last_result)
	main._ver_mio = true   # VISTO
	var t1 := Time.get_ticks_msec()
	while not (main.view.counting and not main.view._count_order.is_empty()) and Time.get_ticks_msec() - t1 < 15000:
		await process_frame
	await create_timer(0.8).timeout
	await _guardar("cuenta_boca_abajo")
	# F13: contar tres a mano (se cogen y se voltean)
	for k in 3:
		var n: int = main.view._count_left[0]
		main.view.count_pick(main.view._u(main.view._count_order[n][0].global_position))
		await create_timer(0.12).timeout
	await _guardar("cuenta_volteando")
	await create_timer(0.6).timeout
	await _guardar("cuenta_tres")
	print("CUENTA quedan ", main.view._count_left.size(), " total ", main.view._count_total)
	quit()


func _guardar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://capturas/verificar/" + nombre + ".png"))
	print("FOTO ", nombre)
