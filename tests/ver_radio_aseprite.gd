extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(3.0).timeout
	main.set_process(false)
	main.playing = false
	main.overlay.hide()
	main.hud.hide()
	main.menus.open("ajustes")
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://capturas/radio_aseprite_ajustes.png")
	print("Radio en Ajustes renderizada")
	quit()
