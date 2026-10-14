extends SceneTree
## Prueba del modo online contra el servidor local (bash servidor/arrancar.sh):
## dos jugadores crean y se unen a una sala por código y juegan una partida
## completa con 2 bots, enviando jugadas por el servidor.
## Uso: godot --headless --path . --script res://tests/prueba_online.gd

const OP_EMPEZAR := 2
const OP_CARTA := 10
const OP_ROBAR := 11
const OP_JUGAR := 12
const OP_PASAR := 13
const OP_LISTO := 18
const OP_ESTADO := 101
const OP_AVISO := 102

var nakama: Node
var jugadores: Array = []
var avisos := 0
var manos := 0
var terminado := false
var resultado := ""


func _init() -> void:
	nakama = load("res://addons/com.heroiclabs.nakama/Nakama.gd").new()
	nakama.logger._level = NakamaLogger.LOG_LEVEL.ERROR
	root.add_child.call_deferred(nakama)
	_prueba.call_deferred()


func _prueba() -> void:
	await process_frame
	# por defecto el servidor local; --servidor=IP --clave=CLAVE para la nube
	var host := "127.0.0.1"
	var clave := "colmadon-dev"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--servidor="):
			host = a.trim_prefix("--servidor=")
		if a.begins_with("--clave="):
			clave = a.trim_prefix("--clave=")
	var client: NakamaClient = nakama.create_client(clave, host, 7350, "http")
	for i in 2:
		var session: NakamaSession = await client.authenticate_device_async("prueba-online-%d-%d" % [i, Time.get_ticks_msec()], "Prueba%d_%d" % [i, Time.get_ticks_msec()])
		if session.is_exception():
			_fin("NO SE PUDO ENTRAR: %s" % session)
			return
		var socket: NakamaSocket = nakama.create_socket_from(client)
		var con = await socket.connect_async(session)
		if con.is_exception():
			_fin("SIN SOCKET: %s" % con)
			return
		var j := {"i": i, "socket": socket, "session": session, "match": "", "v": {}}
		socket.received_match_state.connect(_mensaje.bind(j))
		jugadores.append(j)
	# el primero crea la sala; el segundo entra con el código
	var r = await client.rpc_async(jugadores[0].session, "crear_sala", "{}")
	var sala: Dictionary = JSON.parse_string(r.payload)
	print("SALA ", sala.code)
	# Nakama indexa las etiquetas de las salas cada segundo, más o menos
	await create_timer(1.5).timeout
	r = await client.rpc_async(jugadores[1].session, "unirse_sala", JSON.stringify({"code": sala.code.to_lower()}))
	var union: Dictionary = JSON.parse_string(r.payload)
	if union.get("match_id", "") != sala.match_id:
		_fin("EL CÓDIGO NO ENCUENTRA LA SALA: %s" % union)
		return
	for j in jugadores:
		var m = await j.socket.join_match_async(sala.match_id)
		if m.is_exception():
			_fin("NO ENTRA EN LA SALA: %s" % m)
			return
		j.match = sala.match_id
	await create_timer(0.5).timeout
	jugadores[0].socket.send_match_state_async(sala.match_id, OP_EMPEZAR, "{}")
	var limite := Time.get_ticks_msec() + 240000
	while not terminado and Time.get_ticks_msec() < limite:
		await create_timer(0.2).timeout
	if not terminado:
		_fin("TIEMPO AGOTADO en fase %s" % jugadores[0].v.get("phase", "?"))


func _mensaje(st, j: Dictionary) -> void:
	if st.op_code == OP_AVISO:
		avisos += 1
		print("AVISO al jugador %d: %s" % [j.i, st.data])
		return
	if st.op_code != OP_ESTADO:
		return
	var v: Dictionary = JSON.parse_string(st.data)
	var antes: String = j.v.get("phase", "")
	j.v = v
	var mid: String = j.match
	match v.phase:
		"pick":
			if not v.offers.is_empty():
				j.socket.send_match_state_async(mid, OP_CARTA, JSON.stringify({"id": v.offers[0]}))
		"draw":
			var mias := 0
			for k in v.pool_taken:
				if int(v.pool_taken[k]) == 0:
					mias += 1
			if mias < 7:
				var libres: Array = range(28).filter(func(x): return not v.pool_taken.has(str(x)))
				if not libres.is_empty():
					j.socket.send_match_state_async(mid, OP_ROBAR, JSON.stringify({"idx": libres.pick_random()}))
		"play":
			if int(v.turn) == 0:
				_jugar(j, v)
		"shop":
			if antes != "shop":
				manos += 1
				if j.i == 0:
					print("MANO %d: %s %s · marcador %s" % [manos, v.last_result.reason, v.last_result.pts, v.scores])
			if not v.listos[0]:
				j.socket.send_match_state_async(mid, OP_LISTO, "{}")
		"over":
			if j.i == 0 and antes != "over":
				_fin("PARTIDA TERMINADA · marcador %s · %d manos" % [v.scores, int(v.hand_no)])


func _jugar(j: Dictionary, v: Dictionary) -> void:
	var mano: Array = v.hands[0]
	for t in mano:
		if v.chain.is_empty():
			if not v.first_hand or (int(t[0]) == 6 and int(t[1]) == 6):
				j.socket.send_match_state_async(j.match, OP_JUGAR, JSON.stringify({"tile": t, "side": 0}))
				return
			continue
		var l := int(v.left_end)
		var r := int(v.right_end)
		if int(t[0]) == l or int(t[1]) == l:
			j.socket.send_match_state_async(j.match, OP_JUGAR, JSON.stringify({"tile": t, "side": -1}))
			return
		if int(t[0]) == r or int(t[1]) == r:
			j.socket.send_match_state_async(j.match, OP_JUGAR, JSON.stringify({"tile": t, "side": 1}))
			return
	j.socket.send_match_state_async(j.match, OP_PASAR, "{}")


func _fin(texto: String) -> void:
	if terminado:
		return
	terminado = true
	print(texto)
	print("AVISOS (jugadas rechazadas): %d" % avisos)
	for j in jugadores:
		j.socket.close()
	quit()
