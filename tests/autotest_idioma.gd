extends SceneTree
## --script res://tests/autotest_idioma.gd -- --autotest --idioma=en (o es)
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var loc := "es"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--idioma="):
			loc = arg.get_slice("=", 1)
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	m.menus.settings.idioma = loc
	m.apply_settings()
	assert(TranslationServer.get_locale().begins_with(loc))
	print("AUTOTEST IDIOMA ", loc)
