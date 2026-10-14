extends SceneTree
## Las once cartas de aumento, de tres en tres, para comprobar que el texto cabe.
## Uso: godot --path . --resolution 1280x720 --script res://tests/cartas_aumentos.gd
func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(3.0).timeout
	main.menus.close()
	var en := OS.get_cmdline_user_args().has("--en")
	if en:
		TranslationServer.set_locale("en")
	main.start_game(false, "aumentos")
	await create_timer(2.5).timeout
	main.set_process(false)
	var ids: Array = main.g.CARDS.keys()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://capturas/cartas"))
	var tanda := 0
	for i in range(0, ids.size(), 3):
		main.g.offers[0] = ids.slice(i, i + 3)
		main._build_overlay()
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://capturas/cartas/tanda_%s%d.png" % ["en_" if en else "", tanda])
		tanda += 1
	print("CARTAS ", ids.size(), " en ", tanda, " tandas")
	quit()
