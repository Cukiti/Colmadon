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
	main.g.phase = "pick"
	main.g.offers[0] = ["doble", "ojo", "bolsillo"]
	main.g.cards[0] = ["doble", "ojo", "bolsillo"]
	main._rebuild_cards()
	main._build_overlay()
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://capturas/aumentos_aseprite.png")
	print("Aumentos renderizados: selección y tres insignias pequeñas")
	quit()
