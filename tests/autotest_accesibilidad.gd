extends SceneTree
## Partida automática completa, texto muy grande y paleta accesible, sin guardar.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	m.menus.settings.texto = 2
	m.menus.settings.daltonico = true
	m.menus.settings.menos_movimiento = true
	m.menus.settings.idioma = "en"
	m.apply_settings()
	print("AUTOTEST ACCESIBILIDAD: texto muy grande, paleta y menos movimiento")
