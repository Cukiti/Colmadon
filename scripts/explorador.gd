extends "res://scripts/recorrido.gd"
## Bot explorador: juega partidas rápidas con libertad, como una persona
## curiosa (toca de todo, se para, baila, pausa, mira la mesa, compra…) y
## repasa una lista de pendientes. Cada pendiente acaba en OK o FALLO con su
## nota; además vigila invariantes todo el rato (atascos, puntos que bajan,
## fichas que no suman 28, placas que se montan…).
##
## Uso: bash tools/recorrido.sh explorar   (graba vídeo y hace el informe)
##   o: godot --path . -- --recorrido --escena=explorar [--semilla=N] [--partidas=N]
## Salida en capturas/recorrido/explorar/: pendientes.md, además de lo del recorrido.

var pendientes: Array = []    # [{id, que, estado, nota}]
var _rng := RandomNumberGenerator.new()
var _partidas := 2
var _firma := ""
var _firma_frame := 0
var _firma_ms := 0
# grabando vídeo el juego va más lento que el reloj: ahí el atasco se mide en fotogramas
var _grabando := OS.get_cmdline_args().has("--write-movie")


func _quieto_seg() -> float:
	return (frame - _firma_frame) / FPS if _grabando else (Time.get_ticks_msec() - _firma_ms) / 1000.0
var _ult_marcador := [0, 0]
var _vio_jugueteo := false
var _acciones := 0


func _lista() -> void:
	for p in [
		["pausa_no_tapa", "El botón de pausa no tapa el cartel «ELIGE UN AUMENTO» ni el del turno"],
		["mesa_limpia", "Al empezar una partida rápida la mesa está vacía (nada de la partida anterior)"],
		["ver_mesa", "«Ver la mesa» desde la tienda: sus botones se ven enteros y «Volver» devuelve la tienda"],
		["pausa_de_pie", "Pausar de pie (Esc) no te sienta; al seguir sigues de pie con el ratón capturado"],
		["ajustes_de_pie", "Ajustes desde la pausa estando de pie: al volver sigues de pie y la cámara en tus ojos"],
		["silla_cerca", "De pie, cerca y apuntando a tu silla: se resalta su contorno"],
		["silla_lejos", "Lejos de la silla, apuntarla no la resalta"],
		["silla_clic", "Clic en la silla resaltada: te sientas"],
		["gestos_sentado", "Gestos sentado: botón de gestos y teclas 1-5 (los bots reaccionan)"],
		["bots_juguetean", "Los bots juguetean con su ficha en su turno (la miran, la cogen)"],
		["salir_y_nueva", "Salir al colmado a mitad y empezar otra partida rápida: marcador a 0 y mesa limpia"],
		["sin_atascos", "Juego libre: nunca se queda atascado (más de 40 s sin que cambie nada)"],
		["invariantes", "Juego libre: puntos que no bajan, 28 fichas, monedas ≥ 0, placas sin montarse"],
		["puntas_iguales", "Con las dos puntas iguales, una ficha buena soltada en cualquiera es jugada (no chivo)"],
		["chivos_validos", "Todo chivo registrado es de verdad: la ficha no casa con su vecina, o quien pasó llevaba jugada"],
		["botones_menus", "Cada botón de inicio, pizarra, bots, espejo, armario, ajustes y accesibilidad responde sin errores del motor"],
		["botones_pausa", "En partida: pausa y cada botón de los ajustes abiertos desde ella; LISTO y SEGUIR devuelven la partida"],
		["camara_robar", "Modo cámara: robar las 7 fichas con la mira y E"],
		["camara_devolver", "Modo cámara: coger una ficha con E y devolverla con el clic derecho (no se juega)"],
		["camara_coger_soltar", "Modo cámara: coger con E, llevarla a la punta y soltar con E la juega"],
		["camara_teclas", "Modo cámara: Tab enseña la mesa desde arriba y al volver sigue el modo cámara"],
		["arma_coger", "Arma: mirar a la pistola de las piernas y E te levanta armado"],
		["arma_disparo", "Arma: apuntando (clic derecho) un tiro a la cabeza mata al bot y queda tumbado"],
		["arma_sentarse", "Arma: Espacio te sienta y la pistola vuelve a las piernas"],
		["arma_turno_muerto", "Arma: el turno de un muerto espera (no juega tumbado)"],
		["arma_vuelve", "Arma: el bot muerto vuelve a su silla a los pocos segundos"],
		["sin_errores_motor", "En todo el recorrido no salta ningún error del motor (scripts, nodos, shaders)"],
		["sin_fugas", "Los nodos no crecen sin parar de una mano a otra"],
	]:
		pendientes.append({"id": p[0], "que": p[1], "estado": "pendiente", "nota": ""})


func _hecho(id: String, ok: bool, nota := "") -> void:
	for p in pendientes:
		if p.id == id:
			# un fallo no se borra con un acierto posterior
			if p.estado == "FALLO" and ok:
				return
			p.estado = "OK" if ok else "FALLO"
			if nota != "":
				p.nota = nota
	marca("PENDIENTE %s → %s %s" % [id, "OK" if ok else "FALLO", nota])
	if not ok:
		hallazgo("pendiente_" + id, nota if nota != "" else id)
		foto("fallo_" + id)


func _estado(id: String) -> String:
	for p in pendientes:
		if p.id == id:
			return p.estado
	return ""


func _correr() -> void:
	marca("INICIO explorar")
	_lista()
	var semilla := SEMILLA
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--semilla="):
			semilla = int(str(a).trim_prefix("--semilla="))
		if str(a).begins_with("--partidas="):
			_partidas = int(str(a).trim_prefix("--partidas="))
	_rng.seed = semilla
	marca("semilla %d · %d partidas libres" % [semilla, _partidas])
	OS.add_logger(_vigia)
	_camara(false)
	await hasta(func(): return m.menus.screen == "inicio" or m.playing, 30.0)
	await esperar(1.0)
	if not "--sin-barrido" in OS.get_cmdline_user_args():
		await _barrido_menus()
	# el barrido no cuenta como tiempo parado
	_firma = ""
	_firma_ms = Time.get_ticks_msec()
	_firma_frame = frame
	await _guiados()
	if m.playing and m.g.phase in ["pick", "draw", "play"]:
		await _barrido_pausa()
	await _guiados_camara()
	await _libre()
	_recoger_errores()
	if _estado("sin_errores_motor") == "pendiente":
		_hecho("sin_errores_motor", true)
	var fuga := _revisar_fugas()
	if _nodos_mano.size() >= 4:
		_hecho("sin_fugas", fuga == "", fuga if fuga != "" else "%d manos medidas" % _nodos_mano.size())
	if _estado("sin_atascos") == "pendiente":
		_hecho("sin_atascos", _fallos_bot == 0, "%d acciones libres; %d fallos o esperas agotadas registrados" % [_acciones, _fallos_bot])
	if _estado("invariantes") == "pendiente":
		_hecho("invariantes", true)
	if _estado("puntas_iguales") == "pendiente":
		for p in pendientes:
			if p.id == "puntas_iguales":
				p.estado = "NO_REVISADO"
				p.nota = "No se dio el caso en esta partida"
	if _estado("chivos_validos") == "pendiente":
		if _chivos_vistos > 0:
			_hecho("chivos_validos", true, "%d chivos y renuncios revisados" % _chivos_vistos)
		else:
			for p in pendientes:
				if p.id == "chivos_validos":
					p.estado = "NO_REVISADO"
	if _estado("bots_juguetean") == "pendiente":
		_hecho("bots_juguetean", _vio_jugueteo, "" if _vio_jugueteo else "Ningún bot jugueteó en toda la prueba")
	await terminar()


func _process(dt: float) -> void:
	super(dt)
	if not _fin and frame % 10 == 0:
		_recoger_errores()
		if m.playing:
			_vigilar()
			_vigilar_nuevo()
		elif m.menus.visible:
			# fuera de la partida la mesa queda vacía (salir a mitad del robo dejaba las 28 fichas)
			var restos: int = m.view.hands_root.get_children().filter(func(n): return n is Node3D and n.visible and not n.is_queued_for_deletion()).size()
			_restos_mesa = _restos_mesa + 1 if restos > 0 else 0
			if _restos_mesa == 6:
				_hecho("invariantes", false, "En los menús quedan %d fichas de la partida sobre la mesa" % restos)
				foto("restos_en_la_mesa")


# ---------------------------------------------------------------- pendientes guiados

func _nueva_partida_rapida() -> void:
	await pulsar("JUGAR")
	await esperar(2.0)
	await jugar_con_bots("aumentos")
	await hasta(func(): return m.g.phase == "pick" and m.overlay.get_child_count() > 2, 10.0)
	await esperar(1.0)


func _mesa_limpia() -> String:
	var v = m.view
	var n_cadena := 0
	for t in v._chain_nodes:
		if is_instance_valid(v._chain_nodes[t]) and v._chain_nodes[t].is_visible_in_tree():
			n_cadena += 1
	var n_mano := 0
	for n in v.hand_nodes:
		if is_instance_valid(n) and n.is_visible_in_tree():
			n_mano += 1
	if n_cadena > 0 or n_mano > 0 or not m.g.chain.is_empty():
		return "En la elección del aumento se ven %d fichas de la línea y %d tuyas" % [n_cadena, n_mano]
	return ""


func _pausa_tapa() -> String:
	var pr: Rect2 = m.pause_btn.get_global_rect()
	var tapa := []
	for n in _textos(m.hud):
		if n == m.pause_btn or m.pause_btn.is_ancestor_of(n) or m.wallet_panel.is_ancestor_of(n):
			continue
		if n.get_global_rect().intersects(pr):
			tapa.append(n.text if "text" in n else n.name)
	return "" if tapa.is_empty() else "La pausa pisa: %s" % ", ".join(tapa)


func _textos(n: Node) -> Array:
	var out: Array = []
	if n is CanvasItem and not n.is_visible_in_tree():
		return out
	if n is Label and n.text.strip_edges() != "":
		out.append(n)
	for c in n.get_children():
		out.append_array(_textos(c))
	return out


func _guiados() -> void:
	marca("== pendientes guiados")
	await _nueva_partida_rapida()
	foto("g_aumento")
	var t := _pausa_tapa()
	_hecho("pausa_no_tapa", t == "", t)
	t = _mesa_limpia()
	_hecho("mesa_limpia", t == "", t)
	await _jugar_hasta(func(): return m.g.phase == "play" and m.g.turn != 0 and not m.view.animating, 90.0)
	t = _pausa_tapa()
	if t != "":
		_hecho("pausa_no_tapa", false, "En juego: " + t)
	# gestos sentado
	await _jugar_hasta(func(): return m.g.phase == "play" and not m.view.animating and m.emote_btn.visible, 60.0)
	if m.emote_btn.visible:
		await pulsar_nodo(m.emote_btn)
		await esperar(0.4)
		var abierto: bool = is_instance_valid(m.emote_panel)
		await pulsar("Bailar", 2.0)
		await esperar(0.6)
		await tecla(KEY_2)
		await esperar(1.0)
		foto("g_gestos_sentado")
		_hecho("gestos_sentado", abierto, "" if abierto else "El botón de gestos no abrió el panel")
	else:
		_hecho("gestos_sentado", false, "No apareció el botón de gestos sentado")
	# de pie: pausa, ajustes y silla
	await _jugar_hasta(func(): return m.g.phase == "play" and m.stand_btn.visible, 90.0)
	if m.stand_btn.visible:
		await _pruebas_de_pie()
	else:
		for id in ["pausa_de_pie", "ajustes_de_pie", "silla_cerca", "silla_lejos", "silla_clic"]:
			_hecho(id, false, "No se pudo pararse (no apareció PARARSE)")
	# hasta la tienda: ver la mesa
	await _jugar_hasta(func(): return m.g.phase in ["shop", "over"] and not m.view.counting and m.overlay.get_child_count() > 2, 300.0)
	if m.g.phase == "shop":
		await esperar(1.0)
		await pulsar("Ver la mesa")
		await esperar(1.2)
		var fuera := []
		for txt in ["Volver", "Desde abajo" if m.view.top_view else "Desde arriba"]:
			var b := boton(txt)
			if b == null or not Rect2(0, 0, 640, 360).encloses(b.get_global_rect()):
				fuera.append(txt)
		foto("g_ver_mesa")
		await pulsar("Volver", 2.0)
		await esperar(0.8)
		var vuelve: bool = m.overlay.visible and boton("SIGUIENTE MANO") != null
		_hecho("ver_mesa", fuera.is_empty() and vuelve, ("Fuera de pantalla: %s. " % ", ".join(fuera) if not fuera.is_empty() else "") + ("" if vuelve else "Volver no devolvió la tienda"))
	else:
		_hecho("ver_mesa", false, "La partida acabó sin pasar por la tienda (fase %s)" % m.g.phase)
	# salir a mitad y otra partida
	await tecla(KEY_ESCAPE)
	await esperar(0.6)
	await pulsar("SALIR AL COLMADO")
	await esperar(2.5)
	await _nueva_partida_rapida()
	foto("g_otra_partida")
	t = _mesa_limpia()
	var marcador_ok: bool = m.g.scores == [0, 0] and m.g.hand_no == 1
	_hecho("salir_y_nueva", t == "" and marcador_ok, t + ("" if marcador_ok else " Marcador %s, mano %d" % [m.g.scores, m.g.hand_no]))
	if t != "":
		_hecho("mesa_limpia", false, "Tras salir: " + t)


## Mira a un punto del mundo desde tus ojos (de pie).
func _mirar_punto(p3: Vector3) -> void:
	var pie = m.view.pie
	var eye := Vector3(pie.pos.x, pie.EYE, pie.pos.y)
	var d := p3 - eye
	pie.yaw = atan2(-d.x, -d.z)
	pie.pitch = atan2(d.y, Vector2(d.x, d.z).length())


func _pruebas_de_pie() -> void:
	var pie = m.view.pie
	marca("pararse")
	await pulsar_nodo(m.stand_btn)
	await hasta(func(): return pie.mode == "de_pie", 6.0)
	await esperar(0.5)
	# pausa de pie
	await teclas([KEY_A], 0.6)
	await tecla(KEY_ESCAPE)
	await esperar(0.8)
	foto("g_pausa_de_pie")
	var sigue: bool = pie.mode == "de_pie" and m.paused
	await pulsar("SEGUIR")
	await esperar(0.6)
	var capturado := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	_hecho("pausa_de_pie", sigue and pie.mode == "de_pie" and capturado,
		("" if sigue else "Al pausar se sentó (modo %s). " % pie.mode) + ("" if capturado else "Al seguir, el ratón no volvió a capturarse"))
	# ajustes desde la pausa de pie
	await tecla(KEY_ESCAPE)
	await esperar(0.5)
	await pulsar("AJUSTES")
	await esperar(1.6)
	foto("g_ajustes_de_pie")
	await pulsar("LISTO")
	await esperar(1.2)
	var cam_y: float = m.view.camera.global_position.y
	_hecho("ajustes_de_pie", pie.standing() and abs(cam_y - pie.EYE) < 0.15,
		"" if pie.standing() and abs(cam_y - pie.EYE) < 0.15 else "Modo %s, cámara a %.2f m (ojos a %.2f)" % [pie.mode, cam_y, pie.EYE])
	if not pie.standing():
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		await clic(Vector2(320, 120))   # clic en la escena: vuelve a capturar
	# lejos: no se resalta
	pie.pos = Vector2(-1.6, 1.6)
	await esperar(0.2)
	_mirar_punto(m.view.my_chair.global_position + Vector3(0, -0.25, 0.1))
	await esperar(0.3)
	foto("g_silla_lejos")
	_hecho("silla_lejos", not m.view.chair_glow_on, "" if not m.view.chair_glow_on else "Se resalta a %.1f m" % pie.pos.distance_to(Vector2(m.view.my_chair.global_position.x, m.view.my_chair.global_position.z)))
	# cerca: se resalta
	pie.pos = pie.SEAT_SPOT + Vector2(0.45, 0.25)
	await esperar(0.2)
	_mirar_punto(m.view.my_chair.global_position + Vector3(0, -0.25, 0.1))
	await esperar(0.4)
	foto("g_silla_resaltada")
	_hecho("silla_cerca", m.view.chair_glow_on and m._chair_aim, "" if m.view.chair_glow_on else "Apuntando a la silla a un paso no se resalta")
	# clic: te sientas
	if m.view.chair_glow_on:
		_boton_raton(Vector2(320, 180), true)
		await m.get_tree().process_frame
		_boton_raton(Vector2(320, 180), false)
		var ok := await hasta(func(): return pie.mode == "sentado", 20.0)
		foto("g_sentado_por_clic")
		_hecho("silla_clic", ok, "" if ok else "Tras el clic sigue en modo %s" % pie.mode)
	else:
		_hecho("silla_clic", false, "No se pudo probar: la silla no estaba resaltada")
		pie.sit_down(true)
		await hasta(func(): return pie.mode == "sentado", 10.0)


# ---------------------------------------------------------------- juego libre

func _libre() -> void:
	marca("== juego libre")
	var hechas := 0
	var firma_libre := ""
	var progreso_libre := _reloj
	var recuperaciones := 0
	_firma_frame = frame
	while hechas < _partidas and not _fin:
		if await _atender_pendientes():
			continue
		var nueva_firma := _estado_progreso()
		if nueva_firma != firma_libre:
			firma_libre = nueva_firma
			progreso_libre = _reloj
			recuperaciones = 0
		elif _reloj - progreso_libre > _limite_progreso:
			_fallo_bot("explorador_sin_progreso", "Juego libre sin progreso durante 40 s")
			_hecho("sin_atascos", false, "Recuperación necesaria; evidencia conservada")
			if recuperaciones >= 2:
				break
			recuperaciones += 1
			progreso_libre = _reloj
			await _recuperar()
		var g = m.g
		if not m.playing:
			await _nueva_partida_rapida()
			continue
		if m.tranque.activo:
			await _paso_tranque()
			continue
		_camara(_partida_n % 2 == 1)
		if m.paused:
			await pulsar("SEGUIR", 2.0)
		if m.view.pie.standing() and m.view.pie.mode == "de_pie" and g.phase != "play":
			await esperar(0.5)
		# de pie fuera de un paseo (p. ej. si se rindió esperando): volver a la silla
		if m.view.pie.mode == "de_pie" and g.phase == "play":
			await _volver_a_la_silla()
		elif m.view.pie.mode == "levantando":
			await esperar(0.3)
		match g.phase:
			"pick":
				await _libre_aumento()
			"draw":
				if m.cam_mode:
					await _cam_robar()
				else:
					await _libre_robar()
			"play":
				if m.view.counting:
					await _libre_contar()
				elif g.turn == 0 and not m.busy and not m.view.animating and m.cam_mode:
					if m.view.hand_rects().size() == g.hands[0].size():
						await _cam_turno()
				elif g.turn == 0 and not m.busy and not m.view.animating:
					await _libre_turno()
				else:
					await _libre_esperando()
			"shop":
				if m.view.counting:
					await _libre_contar()
				elif m.overlay.get_child_count() > 2:
					await _libre_tienda()
			"over":
				if m.view.counting:
					await _libre_contar()
				elif boton("REVANCHA") != null:
					hechas += 1
					_partida_n += 1
					marca("partida libre %d terminada %s" % [hechas, g.scores])
					foto("libre_libreta_%d" % hechas)
					await _libre_libreta(hechas >= _partidas)
		await m.get_tree().process_frame


func _azar(p: float) -> bool:
	return _rng.randf() < p


func _libre_aumento() -> void:
	if not await hasta(func(): return not m._card_nodes.is_empty() and m.overlay.get_child_count() > 2, 6.0):
		return
	await esperar(0.4)
	var ids: Array = m._card_nodes.keys()
	for k in _rng.randi_range(1, 4):
		var cid = ids[_rng.randi() % ids.size()]
		if m._card_nodes.has(cid) and is_instance_valid(m._card_nodes[cid]):
			await mover(m._card_nodes[cid].get_global_rect().get_center() + Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-40, 40)), 0.2)
	if _azar(0.2):
		marca("libre: pausa en el aumento")
		await pulsar_nodo(m.pause_btn)
		await esperar(0.6)
		await pulsar("SEGUIR")
	var cid2 = ids[_rng.randi() % ids.size()]
	if m._card_nodes.has(cid2) and is_instance_valid(m._card_nodes[cid2]):
		_acciones += 1
		await pulsar_nodo(m._card_nodes[cid2])
	await hasta(func(): return m.g.phase != "pick", 8.0)


func _libre_robar() -> void:
	if _azar(0.5) and m.draw_btn.visible:
		_acciones += 1
		await pulsar_nodo(m.draw_btn)
		await esperar(1.0)
		return
	# tocar fichas del montón una a una (y algún clic perdido)
	var guard := 0
	while m.g.phase == "draw" and m.my_picks.size() < 7 and guard < 30:
		guard += 1
		if m.view.animating:
			await esperar(0.2)
			continue
		var libres: Array = []
		for i in m.view.pool_nodes.size():
			if not m.view.pool_taken.has(i) and is_instance_valid(m.view.pool_nodes[i]):
				libres.append(i)
		if libres.is_empty():
			break
		var n: Node3D = m.view.pool_nodes[libres[_rng.randi() % libres.size()]]
		var p: Vector2 = m.view._u(n.global_position)
		if _azar(0.1):
			p = Vector2(_rng.randf_range(20, 620), _rng.randf_range(60, 340))   # clic perdido
		_acciones += 1
		await clic(p, 0.15)
		await esperar(0.15)
	if m.g.phase == "draw" and m.draw_btn.visible:
		await pulsar_nodo(m.draw_btn)
	await esperar(0.8)


func _libre_turno() -> void:
	var g = m.g
	await esperar(_rng.randf_range(0.2, 0.8))
	if g.phase != "play" or g.turn != 0 or m.busy or m.view.animating:
		return
	# repasar las fichas con el ratón
	var rects: Array = m.view.hand_rects()
	for k in _rng.randi_range(0, 3):
		if rects.is_empty():
			break
		await mover(rects[_rng.randi() % rects.size()].get_center(), 0.15)
	var r := _rng.randf()
	_acciones += 1
	if r < 0.08:
		marca("libre: mirar la mesa desde arriba")
		await clic(Vector2(320, 190))
		await esperar(1.0)
		await clic(Vector2(320, 190))
		await esperar(0.5)
		return
	if r < 0.14 and g.drinks[0].size() > 0:
		var nombre: String = g.DRINKS[g.drinks[0][0]].name
		marca("libre: beber " + nombre)
		await beber_vaso()
		await esperar(2.2)
		return
	if r < 0.20:
		marca("libre: pausa y seguir en mi turno")
		await tecla(KEY_ESCAPE)
		await esperar(_rng.randf_range(0.3, 1.0))
		await tecla(KEY_ESCAPE)
		await esperar(0.4)
		return
	if r < 0.27 and m.stand_btn.visible:
		await _libre_paseo()
		return
	if r < 0.31:
		marca("libre: gesto sentado")
		await tecla([KEY_1, KEY_2, KEY_3, KEY_4, KEY_5][_rng.randi() % 5])
		await esperar(0.8)
		return
	var moves: Array = g.legal_moves(0)
	if g.phase != "play" or g.turn != 0:
		return
	if moves.is_empty():
		var normales: Array = g.hands[0].filter(func(t): return t.x != t.y)
		if _azar(0.15) and not normales.is_empty() and g.hands[0].size() > 2:
			marca("libre: meter chivo")
			var i: int = g.hands[0].find(normales[0])
			await arrastrar(m.view.hand_rects()[i].get_center(), func(): return m.view.end_screen_pos([-1, 1][_rng.randi() % 2]))
		else:
			await pulsar("PASO", 3.0)
		await esperar(0.6)
		return
	if not m.action_box.get_children().is_empty() and _azar(0.1):
		var b := boton("¡UTE VA!")
		if b == null:
			b = boton("¡CHIVO!")
		if b != null:
			marca("libre: cantar " + b.text)
			await pulsar_nodo(b)
			await esperar(1.5)
			return
	# el caso del usuario: puntas iguales y una ficha buena soltada en la punta «repetida»
	if g.left_end == g.right_end and not g.chain.is_empty() and _azar(0.7):
		var buena: Dictionary = moves[0]
		var ib: int = g.hands[0].find(buena.tile)
		rects = m.view.hand_rects()
		if ib >= 0 and ib < rects.size():
			marca("libre: puntas iguales (%d), arrastro %s a la otra punta" % [g.left_end, buena.tile])
			var largo: int = g.chain.size()
			await arrastrar(rects[ib].get_center(), func(): return m.view.end_screen_pos(1), 0.5)
			await esperar(0.4)
			var bien: bool = g.chain.size() == largo + 1 and (g.chivo.is_empty() or g.chivo.seat != 0)
			_hecho("puntas_iguales", bien, "" if bien else "Con las dos puntas en %d, %s soltada en la derecha: chivo %s" % [g.left_end, buena.tile, g.chivo])
			return
	var mv: Dictionary = moves[_rng.randi() % moves.size()]
	var i: int = g.hands[0].find(mv.tile)
	rects = m.view.hand_rects()
	if i < 0 or i >= rects.size():
		return
	var desde: Vector2 = rects[i].get_center()
	if _azar(0.5) or g.chain.is_empty():
		await clic(desde, 0.15)
		await esperar(0.3)
		if m.g.turn == 0 and m.selected >= 0:
			await clic(m.view.end_screen_pos(mv.side), 0.25)
	else:
		var lado: int = mv.side
		await arrastrar(desde, func(): return m.view.end_screen_pos(lado) if not m.g.chain.is_empty() else Vector2(320, 180), _rng.randf_range(0.3, 0.8))
	await esperar(0.8)


func _libre_esperando() -> void:
	var r := _rng.randf()
	if m.cam_mode:
		if r < 0.05:
			_acciones += 1
			await girar(_rng.randf_range(-300, 300), _rng.randf_range(-80, 80), 0.4)
		elif r < 0.06:
			_acciones += 1
			await tecla([KEY_1, KEY_2, KEY_3, KEY_4, KEY_5][_rng.randi() % 5])
		else:
			await esperar(0.1)
		return
	if r < 0.02 and m.stand_btn.visible:
		_acciones += 1
		await _libre_paseo()
	elif r < 0.04:
		_acciones += 1
		await mover(Vector2(_rng.randf_range(40, 600), _rng.randf_range(60, 330)), 0.3)
	elif r < 0.05 and m.emote_btn.visible:
		_acciones += 1
		await pulsar_nodo(m.emote_btn)
		await esperar(0.3)
		var b := boton(["Aplaudir", "Saludar", "Señalar", "Estirarse"][_rng.randi() % 4])
		if b:
			await pulsar_nodo(b)
		elif is_instance_valid(m.emote_panel):
			await pulsar_nodo(m.emote_btn)
	else:
		await esperar(0.1)


## Pararse, dar una vuelta (mirar, caminar, gesto) y volver a la silla con un clic en ella.
func _libre_paseo() -> void:
	var pie = m.view.pie
	marca("libre: pararse y pasear")
	await pulsar_nodo(m.stand_btn)
	if not await hasta(func(): return pie.mode == "de_pie", 6.0):
		return
	for k in _rng.randi_range(1, 3):
		await girar(_rng.randf_range(-600, 600), _rng.randf_range(-60, 60), 0.5)
		await teclas([[KEY_W], [KEY_A], [KEY_D], [KEY_W, KEY_D], [KEY_S]][_rng.randi() % 5], _rng.randf_range(0.3, 1.0))
		if _azar(0.4):
			await tecla([KEY_1, KEY_2, KEY_3, KEY_4, KEY_5][_rng.randi() % 5])
			await esperar(0.6)
		if m.g.phase != "play" or pie.mode != "de_pie":
			break
	await _volver_a_la_silla()


func _volver_a_la_silla() -> void:
	var pie = m.view.pie
	marca("libre: vuelta a la silla desde %s (modo %s)" % [pie.pos, pie.mode])
	if pie.mode != "de_pie":
		await hasta(func(): return pie.mode == "sentado", 15.0)
		return
	# volver: acercarse andando hasta la silla y tocarla
	pie.sit_down(true)   # camina solo rodeando la mesa…
	var silla := Vector2(m.view.my_chair.global_position.x, m.view.my_chair.global_position.z)
	await hasta(func(): return pie.pos.distance_to(silla) < 0.9 or pie.mode != "caminando_a_silla", 10.0)
	if pie.mode == "caminando_a_silla":
		pie.mode = "de_pie"   # …y a un paso se para para tocar la silla él
		_mirar_punto(m.view.my_chair.global_position + Vector3(0, -0.25, 0.1))
		await esperar(0.3)
		marca("libre: apunta a la silla a %.2f m · resaltada %s · modo %s" % [pie.pos.distance_to(pie.SEAT_SPOT), m._chair_aim, pie.mode])
		if m._chair_aim:
			_boton_raton(Vector2(320, 180), true)
			await m.get_tree().process_frame
			_boton_raton(Vector2(320, 180), false)
		else:
			hallazgo("silla_no_resalta", "En el paseo, a %.2f m de la silla y apuntando, no se resaltó" % pie.pos.distance_to(silla))
			pie.sit_down(true)
	if not await hasta(func(): return pie.mode == "sentado", 20.0):
		hallazgo("no_vuelve_a_sentarse", "Tras el paseo sigue en modo %s en %s" % [pie.mode, pie.pos], "paseo")
		foto("no_vuelve_a_sentarse")
		pie.sit_down(true)
		await hasta(func(): return pie.mode == "sentado", 20.0)


func _libre_contar() -> void:
	if m.view.count_manual and is_instance_valid(m._count_ui):
		var guard := 0
		while m.view.counting and not m.view._count_left.is_empty() and guard < 40:
			guard += 1
			if _azar(0.08):
				marca("libre: contar todas de golpe")
				await pulsar("CONTAR TODAS", 1.0)
				break
			var left: Array = m.view._count_left
			var n: int = left[_rng.randi() % left.size()]
			if not is_instance_valid(m.view._count_order[n][0]):
				break   # (asignar una ficha ya borrada a una variable da error)
			var nodo = m.view._count_order[n][0]
			await clic(m.view._u(nodo.global_position), 0.12)
			await esperar(0.1)
	elif _azar(0.3):
		await clic(Vector2(320, 200), 0.1)   # acelerar la cuenta
	await hasta(func(): return not m.view.counting, 20.0)
	await esperar(0.4)


func _libre_tienda() -> void:
	await esperar(0.6)
	_acciones += 1
	if m.g.mode != "clasico" and _azar(0.7):
		var ids: Array = m.g.DRINKS.keys()
		var id: String = ids[_rng.randi() % ids.size()]
		if m.g.can_buy(0, id):
			marca("libre: comprar " + id)
			var precio := _exacto(m.get_tree().root, str(m.g.drink_cost(0, id)))
			if precio:
				await pulsar_nodo(precio)
			await esperar(0.5)
	if _azar(0.5):
		marca("libre: ver la mesa en la tienda")
		await pulsar("Ver la mesa", 2.0)
		await esperar(0.6)
		if _azar(0.5):
			await pulsar("Desde abajo" if m.view.top_view else "Desde arriba", 1.0)
			await esperar(0.8)
		if _azar(0.3):
			# pausa con «Ver la mesa» abierto (el caso que se quedó trabado)
			await tecla(KEY_ESCAPE)
			await esperar(0.5)
			await pulsar("SEGUIR")
			await esperar(0.3)
		await pulsar("Volver", 2.0)
		await esperar(0.5)
	await pulsar("SIGUIENTE MANO", 4.0)
	await esperar(0.8)


func _libre_libreta(ultima: bool) -> void:
	await esperar(1.0)
	if _azar(0.6):
		await pulsar("Ver la mesa", 2.0)
		await esperar(0.8)
		await pulsar("Volver", 2.0)
		await esperar(0.5)
	if ultima:
		return
	if _azar(0.5):
		marca("libre: revancha")
		await pulsar("REVANCHA")
		await esperar(1.5)
		var t := _mesa_limpia()
		if t != "":
			_hecho("mesa_limpia", false, "Tras la revancha: " + t)
	else:
		marca("libre: volver al colmado y otra partida rápida (ratón %d, de pie %s)" % [Input.mouse_mode, m.view.pie.mode])
		await pulsar("Volver al colmado")
		await esperar(2.0)
		if m.playing:
			_hecho("invariantes", false, "«Volver al colmado» no hizo nada (ratón %d, pausa %s)" % [Input.mouse_mode, m.paused])
			m.quit_to_menu()
			await esperar(2.0)
		await _nueva_partida_rapida()
		var t2 := _mesa_limpia()
		if t2 != "":
			_hecho("mesa_limpia", false, "Tras volver al colmado: " + t2)


# ---------------------------------------------------------------- vigilancia continua

func _vigilar() -> void:
	var g = m.g
	var v = m.view
	# atascos: nada cambia en 40 s (sin pausa ni menús)
	var f := str(g.phase, g.hand_no, g.turn, g.chain.size(), g.hands.map(func(h): return h.size()), m.overlay.get_child_count(),
		v.counting, v.animating, m.paused, m.menus.screen, v.pie.mode, m.my_picks.size(), g.scores)
	if f != _firma:
		_firma = f
		_firma_ms = Time.get_ticks_msec()
		_firma_frame = frame
	elif _quieto_seg() > 40.0 and not m.paused:
		_hecho("sin_atascos", false, "Atascado 40 s en fase %s (mano %d, turno %d, cuenta %s, animando %s, capa %d, ratón %d, de pie %s, mis fichas %d)" % [g.phase, g.hand_no, g.turn, v.counting, v.animating, m.overlay.get_child_count(), Input.mouse_mode, v.pie.mode, m.my_picks.size()])
		_firma_ms = Time.get_ticks_msec()
		_firma_frame = frame
	# puntos que bajan en la misma partida
	if g.hand_no > 1 or g.phase != "pick":
		for k in 2:
			if g.scores[k] < _ult_marcador[k] and g.hand_no > 1:
				_hecho("invariantes", false, "El marcador bajó de %s a %s" % [_ult_marcador, g.scores])
	_ult_marcador = g.scores.duplicate()
	if g.hand_no == 1 and g.phase == "pick":
		_ult_marcador = [0, 0]
	# 28 fichas en juego
	if g.phase == "play" and not v.animating:
		var total: int = g.chain.size()
		for h in g.hands:
			total += h.size()
		if total != 28:
			_hecho("invariantes", false, "En juego hay %d fichas (deberían ser 28)" % total)
	for s in 4:
		if g.coins[s] < 0:
			_hecho("invariantes", false, "Monedas negativas en la silla %d" % s)
	# placas de nombre montadas
	var placas: Array = m.name_plates.filter(func(p): return p.is_visible_in_tree())
	for i in placas.size():
		for j in range(i + 1, placas.size()):
			if placas[i].get_global_rect().intersection(placas[j].get_global_rect()).get_area() > 30.0:
				hallazgo("placas_montadas", "Dos placas de nombre se montan", "placas")
	# bots jugueteando
	for s in [1, 2, 3]:
		if v.heads[s] != null and v.heads[s].fiddle >= 1:
			_vio_jugueteo = true
	if _vio_jugueteo and _estado("bots_juguetean") == "pendiente":
		_hecho("bots_juguetean", true)
		foto("bot_jugueteando")
	# pausar de pie nunca te sienta
	if m.paused and v.pie.mode == "sentado" and _pie_antes_de_pausa:
		_hecho("pausa_de_pie", false, "En juego libre, la pausa te sentó")
	if not m.paused:
		_pie_antes_de_pausa = v.pie.mode == "de_pie"
	# chivos de verdad (comprobado aquí por separado, sin usar fits() del juego)
	var ch: Dictionary = g.chivo
	var ch_sig := str(ch, g.chain.size())
	if not ch.is_empty() and ch_sig != _chivo_visto:
		_chivo_visto = ch_sig
		_chivos_vistos += 1
		var malo := ""
		if ch.kind == "ficha" and g.chain.size() >= 2:
			var t: Vector2i = ch.tile
			var vecino := -1
			if g.chain[0] == t:
				vecino = g.chain[1].x
			elif g.chain[-1] == t:
				vecino = g.chain[-2].y
			if vecino >= 0 and (t.x == vecino or t.y == vecino):
				malo = "El chivo %s de la silla %d sí casaba con %d" % [t, ch.seat, vecino]
		elif ch.kind == "pase":
			var lleva := false
			for t2 in g.hands[ch.seat]:
				if t2.x == g.left_end or t2.y == g.left_end or t2.x == g.right_end or t2.y == g.right_end:
					lleva = true
			if not lleva:
				malo = "Renuncio de la silla %d sin llevar jugada" % ch.seat
		if malo != "":
			_hecho("chivos_validos", false, malo)
	# ratón capturado sin estar de pie: los botones no reciben clics
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not m.cam_mode and (v.pie.mode == "sentado" or m.paused):
		_raton_mal += 1
		if _raton_mal >= 3:
			_hecho("invariantes", false, "Ratón capturado en modo %s (pausa %s): los botones no responden" % [v.pie.mode, m.paused])
	else:
		_raton_mal = 0
	# la pausa no pisa textos
	var t := _pausa_tapa()
	if t != "":
		_hecho("pausa_no_tapa", false, t)


var _pie_antes_de_pausa := false
var _raton_mal := 0
var _chivo_visto := ""
var _chivos_vistos := 0


# ---------------------------------------------------------------- informe

func _informe() -> void:
	var ok := pendientes.filter(func(p): return p.estado == "OK").size()
	var lineas: Array = ["# Bot explorador · partida rápida", "",
		"%d de %d pendientes OK · %d acciones libres" % [ok, pendientes.size(), _acciones], "",
		"| Estado | Pendiente | Nota |", "|---|---|---|"]
	for p in pendientes:
		lineas.append("| %s | %s | %s |" % [p.estado, p.que, p.nota.replace("|", "/")])
	lineas.append_array(["", "## Botones pulsados uno a uno", "", "| Pantalla | Botón | Resultado |", "|---|---|---|"])
	for b in _botones_log:
		lineas.append("| %s | %s | %s |" % [b.pantalla, str(b.boton).left(60).replace("|", "/"), b.resultado])
	lineas.append_array(["", "## Errores del motor (%d)" % _errores.size(), ""])
	for e in _errores.slice(0, 40):
		lineas.append("- fotograma %d, tras «%s»: `%s`" % [e.fotograma, e.accion, e.error])
	lineas.append_array(["", "## Nodos al empezar cada mano", ""])
	for n in _nodos_mano:
		lineas.append("- partida %d, mano %d: %d nodos" % n)
	var f := FileAccess.open(dir + "/pendientes.md", FileAccess.WRITE)
	f.store_string("\n".join(lineas) + "\n")
	f.close()
	for l in lineas:
		print("PENDIENTES ", l)


func terminar() -> void:
	if _fin:
		return
	for p in pendientes:
		if p.estado == "pendiente":
			p.estado = "NO_REVISADO"
			p.nota = "No completado antes del cierre del escenario"
		if p.estado == "FALLO":
			_fallos_bot += 1
		_cobertura.append({"caso": p.id, "estado": p.estado, "detalle": p.nota})
	_informe()
	OS.remove_logger(_vigia)
	if _camara_antes != null:
		m.menus.settings["camara"] = _camara_antes
		m.menus.save()
	await super.terminar()


# ---------------------------------------------------------------- errores del motor

## Cuenta los errores del motor (scripts, nodos liberados, shaders…) mientras
## juega, para saber qué acción los provocó.
class Vigia extends Logger:
	var mutex := Mutex.new()
	var nuevos: Array = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		mutex.lock()
		nuevos.append("%s:%d %s · %s %s" % [file.get_file(), line, function, code, rationale])
		mutex.unlock()


var _vigia := Vigia.new()
var _errores: Array = []        # [{error, accion, fotograma}]
var _ultima_accion := "arranque"


func _recoger_errores() -> void:
	_vigia.mutex.lock()
	var lote: Array = _vigia.nuevos.duplicate()
	_vigia.nuevos.clear()
	_vigia.mutex.unlock()
	for e in lote:
		_errores.append({"error": e, "accion": _ultima_accion, "fotograma": frame})
		hallazgo("error_motor", "%s (tras: %s)" % [e, _ultima_accion], e)
		if _errores.size() <= 12:
			_hecho("sin_errores_motor", false, "%s · tras «%s»" % [e, _ultima_accion])


func marca(texto: String) -> void:
	_ultima_accion = texto
	super(texto)


# ---------------------------------------------------------------- barrido de botones

## Botones visibles y pulsables bajo «raiz», en orden de árbol.
func _pulsables(raiz: Node) -> Array:
	var out: Array = []
	if is_instance_valid(raiz):
		_recoger_botones(raiz, out)
	return out.filter(func(b): return not b.disabled)


## Todo el texto de un botón (el suyo, el tooltip y las etiquetas de dentro).
func _texto_total(b: Node) -> String:
	var t: String = (b.text + " " + b.tooltip_text) if b is Button else ""
	for c in b.get_children():
		if c is Label:
			t += " " + c.text
		if not c is Button:
			t += " " + _texto_total(c)
	return t.strip_edges().replace("\n", " ")


## Lo que no se pulsa a ciegas: cerrar el juego, borrar, ir al servidor o
## cambiar la ventana del sistema.
const NO_PULSAR := ["SALIR", "Borrar", "BORRAR", "amigos", "Clasificatoria", "VOLVER A LA SALA", "Pantalla completa", "públicas", "Sala con"]

var _botones_log: Array = []    # [{pantalla, boton, resultado}]


func _excluido(txt: String) -> bool:
	for x in NO_PULSAR:
		if txt.contains(x):
			return true
	return false


## Pulsa uno a uno todos los botones de cada pantalla de los menús. Antes de
## cada uno vuelve a abrir la pantalla; después mira si hubo errores del motor,
## si arrancó una partida o se quedó esperando una tecla, y lo deja como estaba.
func _barrido_menus() -> void:
	marca("== barrido de botones de los menús")
	var ajustes_antes: Dictionary = m.menus.settings.duplicate(true)
	var perfil_antes: Dictionary = m.menus.profile.duplicate(true)
	var idioma := TranslationServer.get_locale()
	var pulsados := 0
	var con_error := 0
	for pantalla in ["inicio", "modos", "bots", "personaje", "armario", "ajustes", "accesibilidad"]:
		m.menus.open(pantalla)
		await esperar(1.0)
		var total: int = _pulsables(m.menus).size()
		for idx in mini(total, 40):
			m.menus.open(pantalla)
			await esperar(0.8)
			var lista := _pulsables(m.menus)
			if idx >= lista.size():
				break
			var b: Button = lista[idx]
			var txt := _texto_total(b)
			if txt == "":
				txt = str(b.name)
			if _excluido(txt):
				_botones_log.append({"pantalla": pantalla, "boton": txt, "resultado": "omitido"})
				continue
			# en una lista con desplazamiento, primero se baja hasta el botón
			var sc: Node = b.get_parent()
			while sc != null and not sc is ScrollContainer:
				sc = sc.get_parent()
			if sc != null:
				sc.ensure_control_visible(b)
				await esperar(0.2)
			if not Rect2(Vector2.ZERO, m.hud.get_viewport_rect().size).encloses(b.get_global_rect()):
				_botones_log.append({"pantalla": pantalla, "boton": txt, "resultado": "fuera de la pantalla (sin desplazamiento)"})
				hallazgo("boton_inalcanzable", "«%s» en %s queda fuera de la pantalla y no hay cómo llegar" % [txt.left(40), pantalla], txt)
				continue
			var n_err := _errores.size()
			marca("barrido %s: «%s»" % [pantalla, txt.left(50)])
			await pulsar_nodo(b)
			await esperar(1.0)
			_recoger_errores()
			if m.playing:
				await esperar(2.5)   # lo que arranca la partida (barajar) también cuenta
				_recoger_errores()
			pulsados += 1
			var res: String = "→ " + (str(m.menus.screen) if m.menus.visible else ("partida" if m.playing else "sin menú"))
			if m.accesibilidad.pendiente != "":
				res += " (esperaba una tecla)"
				m.accesibilidad.pendiente = ""
			if _errores.size() > n_err:
				res += " · %d errores del motor" % (_errores.size() - n_err)
				con_error += 1
				foto("barrido_error_%d" % con_error)
			_botones_log.append({"pantalla": pantalla, "boton": txt, "resultado": res})
			if m.playing:
				m.quit_to_menu()
				await hasta(func(): return not m.playing and m.menus.visible, 10.0)
				await esperar(1.5)
			elif not m.menus.visible:
				m.menus.open("inicio")
				await esperar(0.6)
	# lo que se tocó en ajustes y espejo vuelve a como estaba
	m.menus.settings = ajustes_antes
	m.menus.profile = perfil_antes
	m.menus.save()
	TranslationServer.set_locale(idioma)
	m.accesibilidad.aplicar()
	m.menus.open("inicio")
	await esperar(1.0)
	_hecho("botones_menus", con_error == 0, "%d botones pulsados en 7 pantallas; %d con errores del motor" % [pulsados, con_error])


## En partida: la pausa y los ajustes abiertos desde ella, botón a botón.
func _barrido_pausa() -> void:
	marca("== barrido de la pausa")
	var ajustes_antes: Dictionary = m.menus.settings.duplicate(true)
	var idioma := TranslationServer.get_locale()
	var n_err := _errores.size()
	var pulsados := 0
	var problemas := []
	if not m.paused:
		await tecla(KEY_ESCAPE)
		await esperar(0.6)
	if not m.paused:
		_hecho("botones_pausa", false, "Esc no abrió la pausa (fase %s)" % m.g.phase)
		return
	# ajustes desde la partida: cada botón y volver con LISTO
	await pulsar("AJUSTES", 3.0)
	await esperar(1.2)
	var total: int = _pulsables(m.menus._page).size() if m.menus.visible else 0
	for idx in mini(total, 30):
		if not m.menus.visible:
			if not m.paused:
				await tecla(KEY_ESCAPE)
				await esperar(0.5)
			await pulsar("AJUSTES", 3.0)
			await esperar(1.0)
		var lista := _pulsables(m.menus._page)
		if idx >= lista.size():
			break
		var b2: Button = lista[idx]
		var t2 := _texto_total(b2)
		if _excluido(t2) or t2.begins_with("LISTO") or t2.begins_with("VOLVER") or t2.contains("Accesibilidad"):
			continue
		marca("ajustes en partida: «%s»" % t2.left(50))
		await pulsar_nodo(b2)
		await esperar(0.8)
		_recoger_errores()
		pulsados += 1
		m.accesibilidad.pendiente = ""
		if not m.playing:
			problemas.append("«%s» en los ajustes de la pausa sacó de la partida" % t2.left(40))
			break
	if m.menus.visible:
		await pulsar("LISTO", 3.0)
		await esperar(1.0)
	if m.paused:
		await pulsar("SEGUIR", 3.0)
		await esperar(0.5)
	m.menus.settings = ajustes_antes
	m.menus.save()
	TranslationServer.set_locale(idioma)
	m.accesibilidad.aplicar()
	_recoger_errores()
	if m.paused or m.menus.visible:
		problemas.append("Tras LISTO y SEGUIR sigue en pausa %s / menú %s" % [m.paused, m.menus.visible])
	var bien: bool = problemas.is_empty() and _errores.size() == n_err and m.playing
	_hecho("botones_pausa", bien, "%d botones. %s%s" % [pulsados, " ".join(problemas), "" if _errores.size() == n_err else " %d errores del motor" % (_errores.size() - n_err)])


# ---------------------------------------------------------------- modo cámara

var _camara_antes = null   # lo que tenía el perfil de pruebas; se deja igual al acabar


func _camara(on: bool) -> void:
	if _camara_antes == null:
		_camara_antes = m.menus.settings.get("camara", true)
	m._cam_bloqueado = not on
	m.menus.settings["camara"] = on


## Gira la cabeza (ratón capturado) hasta que la mira caiga en el punto.
func _mira(destino: Callable, paso := 0.5) -> bool:
	for k in 200:
		var d: Vector2 = destino.call() - Vector2(m.CX, 180)
		if d.length() < 3.0:
			return true
		var ev := InputEventMouseMotion.new()
		ev.relative = d * paso
		m._unhandled_input(ev)
		await m.get_tree().process_frame
	return false


func _usar() -> void:
	await tecla(m.menus.settings.teclas.usar)


func _derecho() -> void:
	await _derecho_mantener(true)
	await _derecho_mantener(false)


func _derecho_mantener(abajo: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = abajo
	ev.position = Vector2(m.CX, 180)
	m._unhandled_input(ev)
	await esperar(0.2)


func _clic_izquierdo_centro() -> void:
	for abajo in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = abajo
		ev.position = Vector2(m.CX, 180)
		m._unhandled_input(ev)
		await m.get_tree().process_frame


## Robar con la mira: apunta a fichas del montón y pulsa E; luego R.
func _cam_robar() -> int:
	var cogidas := 0
	var guard := 0
	while m.g.phase == "draw" and m.my_picks.size() < 7 and guard < 30:
		guard += 1
		if m.view.animating or not m.cam_mode:
			await esperar(0.2)
			continue
		var libres: Array = []
		for i in m.view.pool_nodes.size():
			if not m.view.pool_taken.has(i) and is_instance_valid(m.view.pool_nodes[i]):
				libres.append(i)
		if libres.is_empty():
			break
		var n: Node3D = m.view.pool_nodes[libres[_rng.randi() % libres.size()]]
		var antes: int = m.my_picks.size()
		await _mira(func(): return m.view._u(n.global_position) if is_instance_valid(n) else Vector2(m.CX, 180))
		await _usar()
		await esperar(0.25)
		if m.my_picks.size() > antes:
			cogidas += 1
	if m.g.phase == "draw":
		await tecla(m.menus.settings.teclas.recoger)
	await esperar(0.8)
	return cogidas


const CASOS_CAMARA := ["camara_robar", "camara_devolver", "camara_coger_soltar", "camara_teclas", "arma_coger", "arma_disparo", "arma_turno_muerto", "arma_vuelve", "arma_sentarse"]


## Pendientes guiados del modo cámara y del arma (partida rápida sin conexión).
func _guiados_camara() -> void:
	marca("== pendientes del modo cámara y del arma")
	_camara(true)
	if m.playing:
		if not m.paused:
			await tecla(KEY_ESCAPE)
			await esperar(0.5)
		await pulsar("SALIR AL COLMADO")
		await esperar(2.5)
	await _nueva_partida_rapida()
	await _libre_aumento()
	if not await hasta(func(): return m.g.phase == "draw" and m.cam_mode, 20.0, false):
		for id in CASOS_CAMARA:
			_hecho(id, false, "El modo cámara no se activó al robar (fase %s, cam %s)" % [m.g.phase, m.cam_mode])
		_camara(false)
		return
	var cogidas := await _cam_robar()
	foto("cam_robadas")
	_hecho("camara_robar", cogidas == 7, "Cogió %d con la mira (fase %s)" % [cogidas, m.g.phase])
	# mi turno con jugada y la mano colocada
	var listo := func() -> bool:
		return m.g.phase == "play" and m.g.turn == 0 and m.cam_mode and not m.view.animating and not m.busy and not m.g.legal_moves(0).is_empty() and m.view.hand_rects().size() == m.g.hands[0].size()
	if await _jugar_camara_hasta(listo, 120.0):
		var mov: Dictionary = m.g.legal_moves(0)[0]
		var i: int = m.g.hands[0].find(mov.tile)
		var largo: int = m.g.chain.size()
		var en_mano: int = m.g.hands[0].size()
		# coger y devolver con el clic derecho
		await _mira(func(): return m.view.hand_rects()[i].get_center())
		await _usar()
		await esperar(0.4)
		var cogida: bool = m._cam_hold
		await _derecho()
		await esperar(0.4)
		_hecho("camara_devolver", cogida and not m._cam_hold and m.g.chain.size() == largo and m.g.hands[0].size() == en_mano,
			"cogida %s, la sigue llevando %s, línea %d→%d" % [cogida, m._cam_hold, largo, m.g.chain.size()])
		# coger, llevar y soltar en la punta
		i = m.g.hands[0].find(mov.tile)
		await _mira(func(): return m.view.hand_rects()[i].get_center())
		await _usar()
		await esperar(0.3)
		var lado: int = mov.side
		await _mira(func(): return m.view._u(Vector3(0, m.view.TABLE_Y, 0)) if m.g.chain.is_empty() else m.view.end_screen_pos(lado), 0.12)
		await esperar(0.6)
		foto("cam_llevando")
		await _usar()
		var jugo := await hasta(func(): return m.g.chain.size() > largo, 5.0, false)
		_hecho("camara_coger_soltar", jugo, "" if jugo else "La ficha llevada a la punta no se jugó (la sigue llevando %s)" % m._cam_hold)
	else:
		_hecho("camara_devolver", false, "No llegó un turno con jugada en modo cámara")
		_hecho("camara_coger_soltar", false, "No llegó un turno con jugada en modo cámara")
	# Tab: ver la mesa desde arriba y volver
	await _jugar_camara_hasta(func(): return m.g.phase == "play" and m.cam_mode and not m.view.animating, 60.0)
	var nota := ""
	if m.cam_mode:
		await tecla(m.menus.settings.teclas.mirar)
		await esperar(0.8)
		var arriba: bool = m.view.top_view
		foto("cam_tab")
		await tecla(m.menus.settings.teclas.mirar)
		await esperar(0.8)
		if m.view.top_view:
			await clic(Vector2(320, 190))
			await esperar(0.6)
		var vuelve: bool = not m.view.top_view and await hasta(func(): return m.cam_mode or m.g.phase != "play", 4.0, false)
		if not arriba:
			nota += "Tab no enseñó la mesa desde arriba. "
		if not vuelve:
			nota += "Tras volver de la mesa no regresó el modo cámara. "
	else:
		nota = "No se pudo probar: sin modo cámara"
	_hecho("camara_teclas", nota == "", nota)
	await _pruebas_arma()
	_camara(false)


## Juega en modo cámara (con la mira y las teclas) hasta que se cumpla «fin».
func _jugar_camara_hasta(fin: Callable, max_seg: float) -> bool:
	var t0 := _reloj
	while _reloj - t0 < max_seg and not _fin:
		if fin.call():
			return true
		if await _atender_pendientes():
			continue
		if m.tranque.activo:
			await _paso_tranque()
			continue
		match m.g.phase:
			"pick":
				await _libre_aumento()
			"draw":
				if m.cam_mode:
					await _cam_robar()
				else:
					await _libre_robar()
			"play":
				if m.view.counting:
					await _libre_contar()
				elif m.g.turn == 0 and m.cam_mode and not m.busy and not m.view.animating and m.view.hand_rects().size() == m.g.hands[0].size():
					if fin.call():
						return true
					await _cam_turno()
				else:
					await esperar(0.1)
			"shop":
				if m.view.counting:
					await _libre_contar()
				elif m.overlay.get_child_count() > 2:
					await _libre_tienda()
			"over":
				return fin.call()
		await m.get_tree().process_frame
	return fin.call()


## Un turno en modo cámara: coger con E, llevar a la punta y soltar; Q si no lleva.
func _cam_turno() -> void:
	var g = m.g
	var moves: Array = g.legal_moves(0)
	_acciones += 1
	if moves.is_empty():
		var normales: Array = g.hands[0].filter(func(t): return t.x != t.y)
		if _azar(0.1) and not normales.is_empty() and g.hands[0].size() > 2:
			# chivo con la mira: una ficha que no casa soltada en la punta
			var j: int = g.hands[0].find(normales[0])
			marca("cámara: meter chivo")
			await _mira(func(): return m.view.hand_rects()[j].get_center())
			await _usar()
			await _mira(func(): return m.view.end_screen_pos([-1, 1][_rng.randi() % 2]), 0.12)
			await _usar()
			await esperar(0.3)
			if m._cam_hold:
				await _derecho()
		else:
			marca("cámara: paso con Q")
			await tecla(m.menus.settings.teclas.paso)
		await esperar(0.6)
		return
	if _azar(0.08) and not m.action_box.get_children().is_empty():
		marca("cámara: cantar con F")
		await tecla(m.menus.settings.teclas.cantar)
		await esperar(1.0)
		return
	if _azar(0.06):
		await _libre_tiroteo()
		return
	if _azar(0.05):
		marca("cámara: mirar alrededor y E sobre nada")
		await girar(_rng.randf_range(-500, 500), _rng.randf_range(-200, 200), 0.6)
		await _usar()
		await esperar(0.3)
	var mv: Dictionary = moves[_rng.randi() % moves.size()]
	var i: int = g.hands[0].find(mv.tile)
	if i < 0 or i >= m.view.hand_rects().size():
		return
	marca("cámara: juego %s" % mv.tile)
	await _mira(func(): return m.view.hand_rects()[i].get_center() if i < m.view.hand_rects().size() else Vector2(m.CX, 180))
	await _usar()
	await esperar(_rng.randf_range(0.1, 0.5))
	if not m._cam_hold:
		return
	if _azar(0.1):
		marca("cámara: soltar lejos de las puntas")
		await _mira(func(): return Vector2(_rng.randf_range(80, 560), _rng.randf_range(60, 200)), 0.15)
		await _usar()
		await esperar(0.3)
	var lado: int = mv.side
	await _mira(func(): return m.view._u(Vector3(0, m.view.TABLE_Y, 0)) if m.g.chain.is_empty() else m.view.end_screen_pos(lado), 0.12)
	await _usar()
	await esperar(0.6)
	if m._cam_hold and m.g.turn == 0:
		hallazgo("cam_ficha_colgada", "Tras soltar en la punta sigue llevando la ficha", "cam_colgada")
		await _derecho()


# ---------------------------------------------------------------- arma (sin conexión)

func _pruebas_arma() -> void:
	var arma = m.arma
	var pie = m.view.pie
	if not await _jugar_camara_hasta(func(): return m.g.phase == "play" and m.cam_mode and not m.view.animating and arma.lap.visible, 90.0):
		for id in CASOS_CAMARA.slice(4):
			_hecho(id, false, "No llegó el momento de coger la pistola (fase %s, cam %s, pistola %s)" % [m.g.phase, m.cam_mode, arma.lap.visible])
		return
	marca("arma: mirar a las piernas y coger la pistola")
	await _mira(func(): return m.view._u(arma.lap.global_position), 0.8)
	await _usar()
	var arriba := await hasta(func(): return pie.mode == "de_pie" and arma.armado, 8.0, false)
	await esperar(0.5)
	foto("arma_en_mano")
	_hecho("arma_coger", arriba, "" if arriba else "Con la mira en la pistola y E: modo %s, armado %s" % [pie.mode, arma.armado])
	if not arriba:
		for id in CASOS_CAMARA.slice(5):
			_hecho(id, false, "Sin pistola en la mano")
		return
	var blanco := 1
	for s in [1, 2, 3]:
		if not arma.muerto[s]:
			blanco = s
			break
	await _derecho_mantener(true)
	var mato := false
	for intento in 6:
		var d: Vector3 = m.view.heads[blanco].head.global_position - m.view.camera.global_position
		pie.yaw = atan2(-d.x, -d.z)
		pie.pitch = atan2(d.y, Vector2(d.x, d.z).length())
		await esperar(0.3)
		marca("arma: disparo a la silla %d (intento %d)" % [blanco, intento + 1])
		await _clic_izquierdo_centro()
		await esperar(0.5)
		if arma.muerto[blanco]:
			mato = true
			break
	await _derecho_mantener(false)
	foto("arma_disparo")
	var vida_ok: bool = arma.vida.all(func(v): return v >= 0 and v <= 100)
	_hecho("arma_disparo", mato and vida_ok and m.view.heads[blanco].muerto, "silla %d muerta %s, vida %s, tumbada %s" % [blanco, arma.muerto[blanco], arma.vida, m.view.heads[blanco].muerto])
	# volver a la silla con Espacio: la pistola vuelve a las piernas
	await tecla(m.menus.settings.teclas.pararse)
	var sentado := await hasta(func(): return pie.mode == "sentado", 20.0, false)
	await esperar(0.6)
	_hecho("arma_sentarse", sentado and not arma.armado, "" if sentado and not arma.armado else "modo %s, armado %s" % [pie.mode, arma.armado])
	if not mato:
		_hecho("arma_turno_muerto", false, "No murió nadie")
		_hecho("arma_vuelve", false, "No murió nadie")
		return
	# el turno de un muerto espera; a los VUELVE_EN s vuelve a su silla
	var desde := _reloj
	var turno := ""
	while arma.muerto[blanco] and _reloj - desde < 25.0 and not _fin:
		if m.g.phase == "play" and m.g.turn == blanco and not m.view.animating:
			var largo: int = m.g.chain.size()
			await esperar(1.5)
			if arma.muerto[blanco] and m.g.chain.size() != largo:
				turno = "La silla %d jugó estando muerta" % blanco
			elif turno == "":
				turno = "ok"
		elif m.g.phase == "play" and m.g.turn == 0 and m.cam_mode and not m.busy and not m.view.animating:
			await _cam_turno()
		await m.get_tree().process_frame
	_hecho("arma_vuelve", not arma.muerto[blanco], "Tumbada %.1f s (vuelve a los %.0f)" % [_reloj - desde, arma.VUELVE_EN])
	if turno == "":
		for p in pendientes:
			if p.id == "arma_turno_muerto":
				p.estado = "NO_REVISADO"
				p.nota = "No le tocó jugar mientras estaba muerta"
	else:
		_hecho("arma_turno_muerto", turno == "ok", "" if turno == "ok" else turno)


## Juego libre armado: a veces te paras con la pistola y disparas al azar.
func _libre_tiroteo() -> void:
	var arma = m.arma
	if not arma.lap.visible:
		return
	marca("libre: coger la pistola y disparar al azar")
	await _mira(func(): return m.view._u(arma.lap.global_position), 0.8)
	await _usar()
	if not await hasta(func(): return m.view.pie.mode == "de_pie" and arma.armado, 6.0, false):
		return
	for k in _rng.randi_range(1, 4):
		await girar(_rng.randf_range(-400, 400), _rng.randf_range(-80, 60), 0.4)
		var ads := _azar(0.5)
		if ads:
			await _derecho_mantener(true)
		await _clic_izquierdo_centro()
		await esperar(0.4)
		if ads:
			await _derecho_mantener(false)
	if _azar(0.3):
		await teclas([[KEY_W], [KEY_A], [KEY_D], [KEY_S]][_rng.randi() % 4], _rng.randf_range(0.3, 0.8))
	await tecla(m.menus.settings.teclas.pararse)
	if not m.view.pie.near_seat():
		pass   # reglamento P3: lejos de la silla no se sienta (sale un aviso); no es un fallo
	elif not await hasta(func(): return m.view.pie.mode == "sentado", 20.0, false):
		hallazgo("armado_no_se_sienta", "Con la pistola, Espacio no te devolvió a la silla (modo %s)" % m.view.pie.mode, "armado_sentarse")
		m.view.pie.sit_down(true)
		await hasta(func(): return m.view.pie.mode == "sentado", 20.0, false)


# ---------------------------------------------------------------- vigilancia nueva

var _muerto_desde := [-1.0, -1.0, -1.0, -1.0]
var _cam_mal := 0
var _hold_mal := 0
var _nodos_mano: Array = []    # [partida, mano, nodos] al empezar a robar
var _mano_vista := ""


func _vigilar_nuevo() -> void:
	var g = m.g
	var v = m.view
	# manos ajenas boca arriba fuera del tranque (el fallo del reparto tras un tranque)
	if g.phase in ["pick", "draw"] and v.show_all_hands and not v.tranque_on and not m.tranque.activo:
		_hecho("invariantes", false, "Manos de todos boca arriba en la fase %s sin tranque" % g.phase)
	# fichas de juguetear en la mano fuera de la jugada
	if g.phase in ["pick", "shop", "over"] and not v.counting and not v.animating:
		for s in [1, 2, 3]:
			if v.heads[s] != null and v.heads[s].fiddle >= 2:
				hallazgo("ficha_en_mano_fuera", "La silla %d lleva una ficha en la mano en la fase %s" % [s, g.phase], "fiddle%d%s" % [s, g.phase])
	# arma: vida en su rango y muertos que vuelven
	for s in 4:
		var vida: int = m.arma.vida[s]
		if vida < 0 or vida > 100:
			_hecho("invariantes", false, "Vida %d en la silla %d" % [vida, s])
		if m.arma.muerto[s]:
			if _muerto_desde[s] < 0:
				_muerto_desde[s] = _reloj
			elif _reloj - _muerto_desde[s] > m.arma.VUELVE_EN + 6.0 and not m.online and not m.paused:
				hallazgo("muerto_no_vuelve", "La silla %d lleva %.0f s muerta" % [s, _reloj - _muerto_desde[s]], "muerto%d" % s)
		else:
			_muerto_desde[s] = -1.0
	# modo cámara: ratón capturado, y ninguna ficha llevada fuera de tu turno
	if m.cam_mode and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_cam_mal += 1
		if _cam_mal >= 3:
			_hecho("invariantes", false, "Modo cámara con el ratón suelto (fase %s)" % g.phase)
	else:
		_cam_mal = 0
	if m._cam_hold and (g.phase != "play" or g.turn != 0):
		_hold_mal += 1
		if _hold_mal >= 3:
			_hecho("invariantes", false, "Sigues llevando una ficha fuera de tu turno (fase %s, turno %d)" % [g.phase, g.turn])
	else:
		_hold_mal = 0
	# nodos al empezar a robar en cada mano (para ver fugas)
	var clave := "%d-%d" % [_partida_n, g.hand_no]
	if g.phase == "draw" and clave != _mano_vista:
		_mano_vista = clave
		_nodos_mano.append([_partida_n, g.hand_no, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])


var _partida_n := 0
var _restos_mesa := 0


## ¿Crecen los nodos de una mano a otra sin parar? (fuga)
func _revisar_fugas() -> String:
	if _nodos_mano.size() < 4:
		return ""
	var primero: int = _nodos_mano[1][2]   # la primera mano aún carga cosas
	var ultimo: int = _nodos_mano[-1][2]
	if ultimo > primero * 1.25 and ultimo - primero > 300:
		return "Los nodos pasan de %d a %d en %d manos" % [primero, ultimo, _nodos_mano.size() - 1]
	return ""
