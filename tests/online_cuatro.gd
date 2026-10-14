extends SceneTree
## Cuatro clientes reales; crea/entra y deja las ventanas para prueba manual.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var slot := 0
	var codigo_archivo := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--slot="):
			slot = int(arg.trim_prefix("--slot="))
		if arg.begins_with("--codigo-online="):
			codigo_archivo = arg.trim_prefix("--codigo-online=")
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(2.0).timeout
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_title("Colmadón online · Jugador %d" % (slot + 1))
	var nombre := "Prueba %d" % (slot + 1)
	var look: Dictionary = main.menus.aspecto()
	var error := ""
	if slot == 0:
		error = await main.red.crear_sala(nombre, look)
		if error == "":
			FileAccess.open(codigo_archivo, FileAccess.WRITE).store_string(main.red.codigo)
	else:
		var inicio := Time.get_ticks_msec()
		while not FileAccess.file_exists(codigo_archivo) and Time.get_ticks_msec() - inicio < 60000:
			await create_timer(0.2).timeout
		if not FileAccess.file_exists(codigo_archivo):
			print("ONLINE4 ERROR: no apareció código de sala")
			return
		var code := FileAccess.get_file_as_string(codigo_archivo).strip_edges()
		error = await main.red.unirse(code, nombre, look)
	if error != "":
		print("ONLINE4 ERROR: ", error)
		return
	main.start_online()
	print("ONLINE4 CONECTADO jugador=", slot + 1, " sala=", main.red.codigo)
	if slot == 0:
		var inicio := Time.get_ticks_msec()
		while Time.get_ticks_msec() - inicio < 60000:
			var humanos := 0
			for s in main.online_v.get("seats", []):
				if not s.bot:
					humanos += 1
			if humanos == 4:
				print("ONLINE4 CUATRO HUMANOS; comienza partida")
				main.red.enviar(main.red.OP_EMPEZAR)
				break
			await create_timer(0.3).timeout
	await create_timer(3.0).timeout
	print("ONLINE4 ESTADO jugador=", slot + 1, " fase=", main.g.phase, " asientos=", main.online_v.get("seats", []).size())
