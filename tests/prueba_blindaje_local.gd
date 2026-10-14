extends Node
## Integración acotada contra Nakama propio en loopback: sin perfiles ni Main.
class Cliente extends "res://scripts/red.gd":
	var identidad := ""
	func _host() -> Array:
		return ["127.0.0.1", 7460, "colmadon-dev"]
	func conectar(_nombre: String) -> String:
		if socket != null and socket.is_connected_to_host(): return ""
		client = Nakama.create_client(CLAVE_LOCAL, HOST_LOCAL, 7460, "http", 5, NakamaLogger.LOG_LEVEL.NONE)
		session = await client.authenticate_device_async(identidad)
		if session.is_exception(): return "Autenticación de prueba falló"
		socket = Nakama.create_socket_from(client)
		var resultado = await socket.connect_async(session)
		if resultado.is_exception(): return "Socket de prueba falló"
		_atar_socket()
		return ""
	func _recordar_sala(_code: String) -> void: pass
var a: Cliente
var b: Cliente
var vista_a := {}
var vista_b := {}
var fallos := 0
var checks := 0
func check(ok: bool, texto: String) -> void:
	checks += 1
	if not ok:
		fallos += 1
		print("FALLO BLINDAJE LOCAL: ", texto)
func esperar(condicion: Callable) -> bool:
	var limite := Time.get_ticks_msec() + 10000
	while not condicion.call() and Time.get_ticks_msec() < limite:
		await get_tree().create_timer(0.1).timeout
	return condicion.call()
func crudo(op: int, texto: String) -> void:
	await a.socket.send_match_state_async(a.match_id, op, texto)
func _ready() -> void:
	get_tree().create_timer(75).timeout.connect(func(): get_tree().quit(1))
	call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--local"):
		get_tree().quit(1)
		return
	a = Cliente.new()
	b = Cliente.new()
	var token := str(Time.get_ticks_usec())
	a.identidad = "blindaje-local-a-" + token
	b.identidad = "blindaje-local-b-" + token
	add_child(a)
	add_child(b)
	a.estado.connect(func(v): vista_a = v)
	b.estado.connect(func(v): vista_b = v)
	check(await a.crear_sala("Prueba A", {}, "clasico", 200, false) == "", "crear sala privada local")
	if a.match_id.is_empty():
		get_tree().quit(1)
		return
	await get_tree().create_timer(1).timeout # índice eventual del código
	check(await b.unirse(a.codigo, "Prueba B", {}) == "", "segundo cliente")
	check(await esperar(func(): return vista_a.get("phase", "") == "lobby" and vista_b.get("phase", "") == "lobby"), "ambos reciben lobby")
	for op in [1,2,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,100,101,102,103,104,999]:
		for raiz in ["null", "[]", "42", "true", '"texto"', "{"]:
			await crudo(op, raiz)
			await get_tree().create_timer(0.02).timeout
	await crudo(1, JSON.stringify({"name":"NO APLICAR", "avatar":{"basura":"x".repeat(10000)}}))
	await get_tree().create_timer(1).timeout
	check(vista_a.get("phase", "") == "lobby", "raíces inválidas y payload grande no inician partida")
	check(vista_a.seats[0].name == "Prueba A", "payload enorme no cambia perfil")
	if not a.socket.is_connected_to_host():
		print("BLINDAJE LOCAL: transporte desconectó payload enorme; comprobando recuperación")
		check(await a.reconectar(1) == "", "reconecta después del límite del transporte")
		if not a.socket.is_connected_to_host():
			get_tree().quit(1)
			return
	# Ráfaga finita: comprueba supervivencia y progreso del compañero; la cuota
	# exacta por tick se verifica de forma determinista en sala.test.ts.
	for i in 200:
		await crudo(21 if i % 2 == 0 else 999, '{"st":2,"x":null,"z":0,"yaw":0}')
		await get_tree().create_timer(0.002).timeout
	b.enviar(b.OP_PERFIL, {"name":"Compañero activo", "avatar":{}})
	check(await esperar(func(): return not vista_b.get("seats", []).is_empty() and vista_b.seats[0].name == "Compañero activo"), "otro jugador responde tras ráfaga")
	await get_tree().create_timer(0.4).timeout
	a.enviar(a.OP_PERFIL, {"name":"Recuperado", "avatar":{"skin":"#aa7733", "invasor":{"hands":[[6,6]]}}})
	check(await esperar(func(): return vista_a.seats[0].name == "Recuperado"), "cliente válido funciona después de basura")
	check(not vista_a.seats[0].avatar.has("invasor"), "avatar no reenvía objetos arbitrarios")
	# En lobby el host pasa al compañero si el creador se desconecta.
	var host_actual := a if vista_a.get("me_host", false) else b
	check(vista_a.get("me_host", false) or vista_b.get("me_host", false), "sala conserva anfitrión activo")
	host_actual.enviar(a.OP_EMPEZAR)
	var empezada := await esperar(func(): return vista_a.get("phase", "lobby") != "lobby" and vista_b.get("phase", "lobby") != "lobby")
	check(empezada, "partida válida empieza para ambos")
	if not empezada:
		get_tree().quit(1)
		return
	# Las manos se asignan al terminar el reparto; no auditar arrays vacíos.
	for intento in 20:
		if vista_a.phase == "play" and vista_b.phase == "play": break
		for jugador in [a, b]:
			var v: Dictionary = vista_a if jugador == a else vista_b
			if v.phase != "draw" or v.pool_taken.values().count(0) >= 7: continue
			for idx in 28:
				if not v.pool_taken.has(str(idx)):
					jugador.enviar(a.OP_ROBAR, {"idx":idx})
					await get_tree().create_timer(0.2).timeout
					break
	var repartida := await esperar(func(): return vista_a.get("phase", "") == "play" and vista_b.get("phase", "") == "play")
	check(repartida, "reparto real completado")
	if not repartida:
		get_tree().quit(1)
		return
	for v in [vista_a, vista_b]:
		check(not v.has("pool"), "pozo no viaja")
		check(v.hands.size() == 4 and not v.hands[0].is_empty() and v.hands[0].all(func(t): return t != null), "mano propia visible")
		check(v.hands.slice(1).all(func(h): return h.all(func(t): return t == null)), "manos rivales ocultas")
	await a.salir()
	await b.salir()
	a.socket.close()
	b.socket.close()
	print("BLINDAJE LOCAL ", checks, " comprobaciones · ", "SIN FALLOS" if fallos == 0 else str(fallos) + " FALLOS")
	get_tree().quit(1 if fallos else 0)
