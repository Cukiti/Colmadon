extends SceneTree
## Fotos de la recogida de fichas: apuntar una ficha de la mesa y las que ya
## cogiste en tu bandeja (¿se ven de cara?).
## Uso: godot --path . --script res://tests/foto_robar.gd → capturas/robar/*.png

func _init() -> void:
	_foto.call_deferred()


func _foto() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://capturas/robar"))
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	while main.menus.screen != "inicio":
		await process_frame
	main.menus.profile["consejos"] = main.CONSEJOS.keys()
	main.menus.close()
	main.start_game(false, "clasico")
	while main.g.phase != "draw" or main.view.pool_nodes.size() != 28 or main.view.animating:
		await process_frame
	await create_timer(0.8).timeout
	# apuntar una ficha libre (sin cogerla)
	var libre: int = range(28).filter(func(x): return not main.view.pool_taken.has(x)).front()
	var p: Vector2 = main.view._u(main.view.pool_nodes[libre].global_position)
	for k in 12:
		main.view.pool_hover(p)
		await process_frame
	await _guardar("apuntando")
	for k in 3:
		var l: int = range(28).filter(func(x): return not main.view.pool_taken.has(x)).front()
		main._draw_pick(l)
		await create_timer(0.6).timeout
	await _guardar("tres_cogidas")
	quit()


func _guardar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://capturas/robar/" + nombre + ".png"))
	print("FOTO ", nombre)
