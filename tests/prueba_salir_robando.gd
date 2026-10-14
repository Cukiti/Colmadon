extends SceneTree
## Salir al colmado mientras se roban las fichas y abrir el armario: la mesa
## tiene que quedar vacía (antes se volvían a barajar las 28 fichas).
## Uso: godot --path . --script res://tests/prueba_salir_robando.gd -- --prueba-sala-salir

func _init() -> void:
	_correr.call_deferred()


func _correr() -> void:
	var m: Node = load("res://main.tscn").instantiate()
	root.add_child(m)
	while m.menus.screen != "inicio":
		await process_frame
	var fallos := 0
	for modo in ["clasico", "aumentos"]:
		m.menus.close()
		m.start_game(false, modo)
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 20000:
			await process_frame
			if m.g.phase == "pick" and not m._card_nodes.is_empty():
				m._pick(m._card_nodes.keys()[0])
			if m.g.phase == "draw" and not m.view.pool_nodes.is_empty() and not m.view.animating:
				break
		await create_timer(0.5).timeout
		print("SALIR fase=", m.g.phase, " montón=", m.view.pool_nodes.size())
		m.quit_to_menu()
		await create_timer(1.0).timeout
		m.menus.open("armario")
		await create_timer(3.0).timeout
		var fichas := 0
		for n in m.view.hands_root.get_children():
			if n is Node3D and n.visible and not n.is_queued_for_deletion():
				fichas += 1
		# (las 5 fichas en fila del centro son la muestra del armario, no la partida)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://capturas/salir_robando_%s.png" % modo))
		print("SALIR ", modo, ": fichas en la mesa tras salir = ", fichas)
		if fichas > 0:
			fallos += 1
		m.menus.open("inicio")
		await create_timer(1.0).timeout
	print("SALIR ROBANDO ", "SIN FALLOS" if fallos == 0 else "%d FALLOS" % fallos)
	quit()
