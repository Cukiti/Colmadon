extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(3.0).timeout
	main.set_process(false)
	main.menus.close()
	main.playing = true
	main.g.phase = "shop"
	main.g.coins = [80, 20, 20, 20]
	main.g.last_result = {"seat": 0, "team": 0, "pts": 25, "reason": "dominó", "bonus": []}
	for id in main.DRINK_COLOR:
		main._icons["drink:" + id] = main._icon("glass", main.DRINK_COLOR[id])
	main._build_shop()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	for id in main.DRINK_COLOR:
		main._icons.erase("drink:" + id)
	main._build_shop()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var after := root.get_texture().get_image()
	after.save_png("res://capturas/tienda_bebidas_aseprite.png")
	var combined := Image.create(after.get_width(), after.get_height() * 2, false, Image.FORMAT_RGBA8)
	combined.blit_rect(before, Rect2i(Vector2i.ZERO, before.get_size()), Vector2i.ZERO)
	combined.blit_rect(after, Rect2i(Vector2i.ZERO, after.get_size()), Vector2i(0, after.get_height()))
	combined.save_png("res://capturas/bebidas_aseprite_comparativa.png")
	print("Tienda renderizada: anterior arriba, Aseprite abajo")
	quit()
