extends Node
## Dos procesos gráficos: -- --prueba-buscador --local --cuenta=... --rol=host|amigo --sesion=...
class RedPrueba extends "res://scripts/red.gd":
	func _host() -> Array:
		# Puerto alternativo exclusivo del fixture; siempre loopback y clave local.
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--puerto-local-prueba="):
				var puerto := int(arg.get_slice("=", 1))
				assert(puerto >= 1024 and puerto <= 65535)
				return [HOST_LOCAL, puerto, CLAVE_LOCAL]
		return super._host()
	func _recordar_sala(_code: String) -> void:
		pass # No modifica ultima_sala.cfg del jugador.
	func ultima_sala() -> Dictionary:
		return {}
	func olvidar_sala() -> void:
		pass

var m
var dir := ""
var rol := "host"

var root: Window
func _ready() -> void:
	root = get_tree().root
	create_timer(240).timeout.connect(func(): quit(1))
	call_deferred("run")

func create_timer(seconds: float) -> SceneTreeTimer:
	return get_tree().create_timer(seconds)

func quit(code := 0) -> void:
	get_tree().quit(code)

func wait_for(cond: Callable, seconds := 90.0) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while not cond.call():
		if Time.get_ticks_msec() > end:
			push_error("TIEMPO AGOTADO " + rol)
			quit(1)
			return
		await get_tree().process_frame

func signal_file(name: String, data: Dictionary = {}) -> void:
	var f := FileAccess.open(dir + "/" + name + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	print(rol, " señal ", name)

func read_signal(name: String) -> Dictionary:
	await wait_for(func(): return FileAccess.file_exists(dir + "/" + name + ".json"))
	return JSON.parse_string(FileAccess.get_file_as_string(dir + "/" + name + ".json"))

func buttons(n: Node, text: String) -> Array:
	var found := []
	if n is Button and n.text.contains(text):
		found.append(n)
	for c in n.get_children():
		found.append_array(buttons(c, text))
	return found

func capture(name: String) -> void:
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png(dir + "/" + rol + "_" + name + ".png")

func create_room(publica: bool) -> void:
	m.menus._sala_publica = publica
	m.menus._sala_modo = "clasico"
	m.menus.settings.meta = 200
	m.menus.open("amigos")
	buttons(m.menus._page, "CREAR")[0].pressed.emit()
	await wait_for(func(): return m.online and m.g.phase == "lobby")
	# El índice de etiquetas es eventual. Publica la señal cuando el código
	# ya puede resolverse; no confundir latencia del índice con privacidad.
	var indexed := false
	for attempt in 40:
		var response = await m.red.client.rpc_async(m.red.session, "unirse_sala", JSON.stringify({"code":m.red.codigo}))
		if not response.is_exception():
			var data = JSON.parse_string(response.payload)
			if data is Dictionary and data.has("match_id"):
				indexed = true
				break
		await create_timer(0.2).timeout
	assert(indexed)

func run() -> void:
	assert(OS.get_cmdline_user_args().has("--local"))
	var sesion := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rol="): rol = arg.get_slice("=", 1)
		if arg.begins_with("--sesion="): sesion = arg.get_slice("=", 1)
	assert(not sesion.is_empty())
	dir = "res://capturas/recorrido/" + sesion
	DirAccess.make_dir_recursive_absolute(dir)
	m = load("res://main.tscn").instantiate()
	root.add_child(m)
	await create_timer(1).timeout
	m.red.set_script(RedPrueba)
	assert(m.red._host()[0] == "127.0.0.1")
	m.menus.profile.nombre = "Buscador " + rol
	m.menus.settings.idioma = "es"
	m.apply_settings()
	m.quit_to_menu("amigos")
	if rol == "host":
		await create_room(true)
		signal_file("publica", {"code": m.red.codigo})
		await capture("publica")
		await read_signal("publica_ok")
		m.red.enviar(m.red.OP_EMPEZAR)
		await wait_for(func(): return m.g.phase != "lobby")
		signal_file("jugando")
		await read_signal("jugando_ok")
		m.quit_to_menu("amigos")
		await create_timer(1).timeout
		await create_room(false)
		signal_file("privada", {"code": m.red.codigo})
		await read_signal("privada_ok")
		await capture("privada")
	else:
		var pub: Dictionary = await read_signal("publica")
		m.menus.open("publicas")
		await wait_for(func(): return not m.menus._salas_cargando and not buttons(m.menus._page, "Entrar").is_empty())
		await capture("lista_publica")
		var filtradas: Dictionary = await m.red.listar_salas("Buscador amigo", {"modo":"clasico", "meta":200, "solo_libres":true, "estado":"esperando"})
		assert(filtradas.salas.any(func(r): return r.code == pub.code))
		var excluidas: Dictionary = await m.red.listar_salas("Buscador amigo", {"modo":"aumentos", "meta":100})
		assert(excluidas.salas.all(func(r): return r.code != pub.code))
		var unchanged = buttons(m.menus._page, "Entrar")[0]
		buttons(m.menus._page, "Actualizar")[0].pressed.emit()
		await create_timer(1).timeout
		assert(buttons(m.menus._page, "Entrar")[0] == unchanged)
		var entrar: Button = buttons(m.menus._page, "Entrar").filter(func(b): return b.get_meta("room_code", "") == pub.code)[0]
		entrar.pressed.emit()
		await wait_for(func(): return m.online)
		assert(m.online and m.red.codigo == pub.code)
		signal_file("publica_ok")
		await read_signal("jugando")
		m.quit_to_menu("amigos")
		await create_timer(1).timeout
		m.menus.open("publicas")
		await wait_for(func(): return not buttons(m.menus._page, "En curso").is_empty())
		assert(buttons(m.menus._page, "En curso")[0].disabled)
		await capture("jugando")
		var err: String = await m.red.unirse(pub.code, "Buscador amigo", m.menus.aspecto())
		assert(err == "") # Una cuenta ya sentada conserva su reconexión.
		await m.red.salir()
		signal_file("jugando_ok")
		var priv: Dictionary = await read_signal("privada")
		var list: Dictionary = await m.red.listar_salas("Buscador amigo")
		assert(not list.has("error"))
		assert(list.salas.all(func(r): return r.code != priv.code))
		await capture("privada_oculta")
		err = await m.red.unirse(priv.code, "Buscador amigo", m.menus.aspecto())
		if err != "": print("ERROR UNION PRIVADA ", err)
		assert(err == "")
		m.start_online()
		await capture("privada_codigo")
		signal_file("privada_ok")
	m.quit_to_menu()
	print("BUSCADOR LOCAL ", rol, " SIN FALLOS")
	m.queue_free()
	await get_tree().process_frame
	quit()
