extends Node
## Bot director del recorrido de pruebas: juega como una persona (eventos
## reales de ratón y teclado), pasa por cada escena del juego y, mientras se
## graba el vídeo (Movie Maker de Godot), deja marcas de tiempo y una
## auditoría automática de interfaz y mesa.
##
## Uso (lo lanza tools/recorrido.sh, una escena por proceso):
##   godot --path . --write-movie capturas/recorrido/<escena>/video.avi --fixed-fps 30 -- --recorrido --escena=<escena>
## Escenas: menus, partida, clasico, de_pie, raros, final, online_anfitrion, online_amigo
##
## Salida en capturas/recorrido/<escena>/: marcas.tsv (fotograma, segundo,
## evento), auditoria.jsonl (hallazgos), metricas.tsv (nodos y memoria) y fotos.

const FPS := 30.0
const SEMILLA := 20261004
var _visual := preload("res://scripts/auditoria_visual.gd").new()
var _frames: FileAccess
var _auditoria_por_frame := false
var _espacial := preload("res://scripts/auditoria_espacial.gd").new()
var _observaciones := preload("res://scripts/auditoria_observaciones.gd").new()
var _reglas := preload("res://scripts/auditoria_reglas.gd").new()   # contratos de docs/REGLAS_INTERACCION.md

var m                 # main.gd
var escena := ""
var dir := ""
var frame := 0
var _marcas: FileAccess
var _audit: FileAccess
var _metricas: FileAccess
var _vistos := {}     # hallazgos ya apuntados (para no repetir)
var _pendientes := {} # solapes vistos en la revisión anterior (deben repetirse para contar)
var _ahora := {}
var _raton := Vector2(320, 180)
var _grabando_video := "--write-movie" in OS.get_cmdline_args()
var _fixture_pausa := false
var _fin := false
var _reloj := 0.0
var _limite_total := 1200.0
var _limite_progreso := 40.0
var _fallos_bot := 0
var _cobertura: Array = []
var _idiomas := {}
var _registro_acciones: FileAccess
var _atendiendo := false



func _init(main_node, nombre: String) -> void:
	m = main_node
	escena = nombre


func _ready() -> void:
	var salida := "res://capturas/recorrido/"
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--salida-recorrido="):
			salida = str(arg).trim_prefix("--salida-recorrido=").trim_suffix("/") + "/"
	dir = ProjectSettings.globalize_path(salida + escena)
	DirAccess.make_dir_recursive_absolute(dir)
	if not FileAccess.file_exists(ProjectSettings.globalize_path(salida) + ".gdignore"):   # que no entren en el juego exportado
		FileAccess.open(ProjectSettings.globalize_path(salida) + ".gdignore", FileAccess.WRITE).close()
	var raiz := ProjectSettings.globalize_path("res://capturas/recorrido")
	if not FileAccess.file_exists(raiz + "/.gdignore"):  # que Godot no importe vídeos ni fotos
		FileAccess.open(raiz + "/.gdignore", FileAccess.WRITE).close()
	_marcas = FileAccess.open(dir + "/marcas.tsv", FileAccess.WRITE)
	_marcas.store_line("fotograma\tsegundo\tevento")
	_audit = FileAccess.open(dir + "/auditoria.jsonl", FileAccess.WRITE)
	_metricas = FileAccess.open(dir + "/metricas.tsv", FileAccess.WRITE)
	_metricas.store_line("fotograma\tnodos\tobjetos\tmemoria_mb\tms_proceso")
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--limite-recorrido="):
			_limite_total = maxf(1.0, float(str(arg).trim_prefix("--limite-recorrido=")))
	_auditoria_por_frame = "--auditar-cada-frame" in OS.get_cmdline_user_args()
	_registro_acciones = FileAccess.open(dir + "/acciones.jsonl", FileAccess.WRITE)
	_frames = FileAccess.open(dir + "/frames.jsonl", FileAccess.WRITE)
	_cargar_idiomas()
	_correr.call_deferred()


func _process(_dt: float) -> void:
	if _fin:
		return
	_reloj += _dt
	if _reloj >= _limite_total:
		_fallo_bot("limite_total", "El escenario excedió %.1f s; se abandona sin marcarlo aprobado" % _limite_total)
		terminar()
		return
	frame += 1
	if _auditoria_por_frame or frame % 10 == 0:
		_auditar()
		_visual.revisar(self)
		_observaciones.revisar(self)
		_reglas.revisar(self)
	if _auditoria_por_frame:
		_frames.store_line(JSON.stringify({"fotograma":frame, "fotograma_video":fotograma_evidencia(), "segundo":_reloj, "fase":m.g.phase, "pantalla":m.menus.screen, "mano":m.g.hand_no, "de_pie":m.view.pie.mode, "pausa":m.paused, "controles":_visual.controles, "contando":m.view.counting, "animando":m.view.animating, "silla_camara":m.view.room_seat, "fichas_mano":m.view.hand_nodes.size(), "fichas_mesa":m.view._chain_nodes.size(), "skin_fichas":m.view.tile_style, "ausente":is_instance_valid(m.away_banner) and m.away_banner.is_visible_in_tree(), "observaciones":_observaciones.contadores.duplicate()}))
	if _auditoria_por_frame or frame % 30 == 0:
		_espacial.revisar(self)
	if frame % 60 == 0:
		_metricas.store_line("%d\t%d\t%d\t%.1f\t%.2f" % [frame, Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
		_metricas.flush()


# ---------------------------------------------------------------- utilidades

func fotograma_evidencia() -> int:
	return maxi(0, Engine.get_frames_drawn() - 1) if _grabando_video else frame

func segundo_evidencia() -> float:
	return fotograma_evidencia() / FPS if _grabando_video else _reloj

func marca(texto: String) -> void:
	var linea := "%d\t%.2f\t%s" % [fotograma_evidencia(), segundo_evidencia(), texto]
	if _marcas == null or not _marcas.is_open():
		return
	_marcas.store_line(linea)
	_marcas.flush()
	print("MARCA ", linea)


func foto(nombre: String) -> void:
	var imagen: Image = m.get_viewport().get_texture().get_image()
	if imagen != null:
		imagen.save_png("%s/%s.png" % [dir, nombre])
	var controles: Array = []
	_visual.recoger(m.get_tree().root, controles)
	var interfaz: Array = []
	for n in controles:
		var r: Rect2 = n.get_global_rect()
		var item := {"control":str(n.get_path()), "clase":n.get_class(), "texto":n.text, "rect":[r.position.x,r.position.y,r.size.x,r.size.y], "tam_fuente":n.get_theme_font_size("font_size"), "color_texto":str(n.get_theme_color("font_color"))}
		if n is Button:
			item["deshabilitado"] = n.disabled
			var estilo: StyleBox = n.get_theme_stylebox("normal")
			if estilo is StyleBoxFlat:
				item["fondo"] = str(estilo.bg_color)
		if n is Label:
			item["alineacion_h"] = n.horizontal_alignment
			item["alineacion_v"] = n.vertical_alignment
		interfaz.append(item)
	FileAccess.open("%s/%s_interfaz.json" % [dir,nombre], FileAccess.WRITE).store_string(JSON.stringify({"fotograma":fotograma_evidencia(),"segundo":segundo_evidencia(),"resolucion":str(DisplayServer.window_get_size()),"idioma":TranslationServer.get_locale(),"pantalla":m.menus.screen,"fase":m.g.phase,"controles":interfaz}, "\t"))


func hallazgo(tipo: String, detalle: String, clave := "") -> void:
	var k := tipo + "|" + (clave if clave != "" else detalle)
	if _vistos.has(k):
		return
	_vistos[k] = true
	if _audit == null or not _audit.is_open():
		return
	_audit.store_line(JSON.stringify({"fotograma": fotograma_evidencia(), "segundo": snappedf(segundo_evidencia(), 0.01), "tipo": tipo, "detalle": detalle}))
	_audit.flush()
	print("HALLAZGO ", tipo, ": ", detalle)


func esperar(seg: float) -> void:
	await m.get_tree().create_timer(seg).timeout


## Espera hasta que se cumpla la condición (o pase el tiempo). Devuelve si se cumplió.
func hasta(cond: Callable, max_seg := 20.0, reportar := true) -> bool:
	var t := 0.0
	while not cond.call():
		await m.get_tree().process_frame
		t += m.get_process_delta_time()   # tiempo real (sin grabar va a más de 30 fps)
		if _fin:
			return false
		if t > max_seg:
			if reportar:
				_fallo_bot("espera_agotada", "Condición no alcanzada en %.1f s" % max_seg)
			return false
	return true


func _k() -> float:
	return DisplayServer.window_get_size().x / 640.0


## Mueve el ratón poco a poco (en coordenadas de la interfaz, 640x360).
func mover(p: Vector2, seg := 0.25) -> void:
	var desde := _raton
	var pasos: int = max(1, int(seg * FPS))
	for i in pasos:
		var q := desde.lerp(p, (i + 1) / float(pasos))
		var ev := InputEventMouseMotion.new()
		ev.position = q
		ev.global_position = ev.position
		ev.relative = q - _raton
		m.get_viewport().push_input(ev, true)
		_raton = q
		await m.get_tree().process_frame


func _boton_raton(p: Vector2, abajo: bool, boton := MOUSE_BUTTON_LEFT) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = boton
	ev.pressed = abajo
	ev.position = p
	ev.global_position = ev.position
	m.get_viewport().push_input(ev, true)


## Bebe tocando el primer vaso lleno de tu portavasos (fase 2: sin botones).
func beber_vaso() -> bool:
	var antes: int = m.g.drinks[0].size()
	for i in m.view.my_glasses.size():
		if m.view.glass_id(i) != "":
			await clic(m.view._u(m.view.my_glasses[i].global_position + Vector3(0, 0.03, 0)))
			await esperar(1.5)   # online lo confirma el servidor
			var ok: bool = m.g.drinks[0].size() < antes
			if not ok:
				_fallo_bot("vaso_no_bebido", "Clic en el vaso sin beber")
			return ok
	_fallo_bot("vaso_no_encontrado", "No hay vaso lleno en la mesa")
	return false


func clic(p: Vector2, seg := 0.25) -> void:
	await mover(p, seg)
	_boton_raton(p, true)
	await m.get_tree().process_frame
	await m.get_tree().process_frame
	_boton_raton(p, false)
	await m.get_tree().process_frame


func arrastrar(a: Vector2, b: Callable, seg := 0.5) -> void:
	await mover(a, 0.2)
	_boton_raton(a, true)
	var pasos: int = max(2, int(seg * FPS))
	for i in pasos:
		var q: Vector2 = a.lerp(b.call(), (i + 1) / float(pasos))
		var ev := InputEventMouseMotion.new()
		ev.position = q
		ev.global_position = ev.position
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
		m.get_viewport().push_input(ev, true)
		_raton = q
		await m.get_tree().process_frame
	_boton_raton(_raton, false)
	await m.get_tree().process_frame


## Mira con el ratón capturado (movimiento relativo).
func girar(dx: float, dy: float, seg := 0.6) -> void:
	var pasos: int = max(1, int(seg * FPS))
	for i in pasos:
		var ev := InputEventMouseMotion.new()
		ev.position = _raton
		ev.relative = Vector2(dx, dy) / pasos
		m.get_viewport().push_input(ev, true)
		await m.get_tree().process_frame


func _tecla(key: Key, abajo: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.physical_keycode = key
	ev.pressed = abajo
	Input.parse_input_event(ev)


## Modo cámara online: el anfitrión coge una ficha con la mira, la lleva a la
## punta y la suelta; los demás tienen que ver su mano con la ficha yendo allí.
func _camara_online(rol: int) -> void:
	if rol == 0:
		m._cam_bloqueado = false
		m.menus.settings["camara"] = true
		# esperando el turno se mueve un poco el ratón: sin tocar nada el servidor te marca ausente
		var t_mov := [0]
		var listo: bool = await hasta(func():
			t_mov[0] += 1
			if t_mov[0] % 45 == 0:
				var ev := InputEventMouseMotion.new()
				ev.position = _raton
				ev.relative = Vector2(1, 0) if t_mov[0] % 90 == 0 else Vector2(-1, 0)
				m.get_viewport().push_input(ev, true)
			return m.g.phase == "play" and m.g.turn == 0 and m.cam_mode and not m.view.animating and not m.busy and not m.g.legal_moves(0).is_empty() and m.view.hand_rects().size() == m.g.hands[0].size(), 120.0, false)
		var jugo := false
		if listo:
			var mov: Dictionary = m.g.legal_moves(0)[0]
			var i: int = m.g.hands[0].find(mov.tile)
			var antes: int = m.g.chain.size()
			await _mirar_a(func(): return m.view.hand_rects()[i].get_center())
			m._usar()
			await esperar(0.4)
			var lado: int = mov.side
			await _mirar_a(func(): return m.view._u(Vector3(0, m.view.TABLE_Y, 0)) if m.g.chain.is_empty() else m.view.end_screen_pos(lado), 0.08)
			await esperar(1.5)   # los demás ven la ficha en tu mano camino de la punta
			foto("camara_llevando")
			m._usar()
			jugo = await hasta(func(): return m.g.chain.size() > antes, 5.0, false)
		marca("camara online: coger y soltar con la mira jugo=%s" % jugo)
		_caso("colocar_con_la_mira_online", jugo)
		m._cam_bloqueado = true
	else:
		var vio: bool = await hasta(func():
			for k in [1, 2, 3]:
				if m.view.heads[k] != null and m.view.heads[k].fiddle == 3:
					return true
			return false, 130.0, false)
		await esperar(0.3)
		foto("camara_ve_ficha_en_mano")
		marca("camara online: ve la ficha en la mano de otro=%s" % vio)
		_caso("ven_la_ficha_en_la_mano_online", vio)
	await esperar(2.0)


## Gira la cabeza (modo cámara) hasta que la mira caiga en el punto.
func _mirar_a(destino: Callable, paso := 0.5) -> void:
	for k in 200:
		var d: Vector2 = destino.call() - Vector2(m.CX, 180)
		if d.length() < 3.0:
			return
		var ev := InputEventMouseMotion.new()
		ev.relative = d * paso
		m._unhandled_input(ev)
		await m.get_tree().process_frame


## Armas online: el anfitrión dispara a la cabeza de otra persona; la víctima
## ve «ESTÁS MUERTO», vuelve al colmado, se levanta del suelo y se sienta; los
## demás la ven tumbada.
func _armas_online(rol: int) -> void:
	_caso("sala_con_armas", bool(m.online_v.get("armas", false)) and int(m.online_v.get("balas", 0)) > 0)
	var vi_muerto := false
	if rol == 0:
		await hasta(func(): return m.g.phase == "play" and not m.view.animating, 30.0)
		var blanco := -1
		var sillas: Array = m.online_v.get("seats", [])
		for k in [2, 1, 3]:
			if k < sillas.size() and not sillas[k].bot:
				blanco = k
				break
		m.arma.coger()
		await hasta(func(): return m.view.pie.mode == "de_pie", 8.0)
		await esperar(1.0)
		m.arma.apuntar(true)
		var mato := false
		for intento in 3:
			var cam: Vector3 = m.view.camera.global_position
			var d: Vector3 = m.view.heads[blanco].head.global_position - cam
			m.view.pie.yaw = atan2(-d.x, -d.z)
			m.view.pie.pitch = atan2(d.y, Vector2(d.x, d.z).length())
			await esperar(0.4)
			foto("armas_apunta")
			m.arma.disparar()
			mato = await hasta(func(): return bool(m.online_v.get("muertos", [false, false, false, false])[blanco]), 4.0, false)
			if mato:
				break
			await esperar(1.0)
		marca("armas: disparo a la silla %d mato=%s" % [blanco, mato])
		_caso("disparo_mata_online", mato)
		if mato:
			vi_muerto = await hasta(func(): return m.view.heads[blanco].muerto, 4.0, false)
		await esperar(6.0)   # de pie con el arma un rato: los demás la tienen que ver
		foto("armas_muerto_visto")
		m.arma.apuntar(false)
		m.view.pie.sit_down(true)
		await hasta(func(): return not m.view.pie.standing(), 15.0)
	# la víctima (quien vea que ha muerto): su pantalla, volver y sentarse
	var alguno := func() -> bool:
		for k in [1, 2, 3]:
			if m.view.heads[k] != null and m.view.heads[k].muerto:
				return true
		return false
	# los demás: ¿se le ve el revólver al anfitrión de pie? (se mira mientras dura el tiroteo)
	var ve_revolver := [false]
	var mira_revolver := func() -> bool:
		for k in [1, 2, 3]:
			var h = m.view.heads[k]
			if h != null and h.armado and h._pistola_tipo == "revolver" and is_instance_valid(h._pistola) and h._pistola.visible:
				ve_revolver[0] = true
		return ve_revolver[0]
	await hasta(func():
		mira_revolver.call()
		return m.arma.yo_muerto or alguno.call(), 25.0, false)
	if rol != 0:
		if not ve_revolver[0]:
			await hasta(mira_revolver, 8.0, false)
		var diag := []
		for k in [1, 2, 3]:
			var h = m.view.heads[k]
			if h != null:
				diag.append("%d:armado=%s tipo=%s modelo=%s" % [k, h.armado, h.arma_tipo, h._pistola_tipo])
		marca("armas: ve el revólver del anfitrión=%s · armas_de %s · %s" % [ve_revolver[0], m.online_v.get("armas_de", "—"), ", ".join(diag)])
		_caso("ven_el_revolver_online", ve_revolver[0])

	vi_muerto = vi_muerto or alguno.call()
	if m.arma.yo_muerto:
		await esperar(3.6)
		foto("armas_estas_muerto")
		_caso("pantalla_muerte_online", is_instance_valid(m.arma._muerte_ui))
		await pulsar("Volver al colmado")
		var arriba := await hasta(func(): return m.view.pie.mode == "de_pie", 10.0, false)
		await esperar(0.5)
		foto("armas_vuelve")
		_caso("volver_al_colmado_online", arriba and not m.arma.yo_muerto)
		m.view.pie.sit_down(true)
		_caso("muerto_se_sienta", await hasta(func(): return m.view.pie.mode == "sentado", 20.0, false))
	else:
		marca("armas: ve al muerto=%s" % vi_muerto)
		_caso("ven_al_muerto_online", vi_muerto)
	await esperar(3.0)


func tecla(key: Key, seg := 0.0) -> void:
	_tecla(key, true)
	if seg > 0.0:
		await esperar(seg)
	else:
		await m.get_tree().process_frame
	_tecla(key, false)
	await m.get_tree().process_frame


## Varias teclas a la vez (caminar en diagonal, por ejemplo).
func teclas(keys: Array, seg: float) -> void:
	for k in keys:
		_tecla(k, true)
	await esperar(seg)
	for k in keys:
		_tecla(k, false)
	await m.get_tree().process_frame


## Botón visible cuyo texto contiene «txt» (o null).
func boton(txt: String) -> Button:
	var found := _buscar(m.get_tree().root, txt.to_lower())
	if found != null:
		return found
	var key := _texto_accion(txt)
	for alias in _idiomas.get(key, []):
		found = _buscar(m.get_tree().root, alias)
		if found != null:
			return found
	return null


func _buscar(n, txt: String) -> Button:
	if not is_instance_valid(n):
		return null
	if n is Button and n.is_visible_in_tree() and (n.text.to_lower().contains(txt) or n.tooltip_text.to_lower().begins_with(txt) or _etiqueta_con(n, txt)):
		return n
	for c in n.get_children():
		var r := _buscar(c, txt)
		if r:
			return r
	return null


## Sala con amigos: toca la opción (cada toque la cambia) hasta que quede como se pide.
func _opcion_sala(clave: String, valor) -> void:
	var actual := func():
		return m.menus._sala_modo if clave == "modo" else m.menus._sala_armas
	var textos: Array = ["Aumentos", "Clásico"] if clave == "modo" else ["Con armas", "Sin armas"]
	for intento in 3:
		if actual.call() == valor:
			return
		var b: Button = null
		for t in textos:
			b = _exacto(m.menus._page, tr(t))
			if b != null:
				break
		if b == null:
			_fallo_bot("boton_no_aparece", "No está la opción «%s» en la sala con amigos" % clave, clave)
			return
		await pulsar_nodo(b)
		await esperar(0.2)
	if actual.call() != valor:
		_fallo_bot("opcion_sala", "La opción «%s» no quedó en %s" % [clave, valor], clave)


## Desde la pizarra: «Dominó con bots» y el folleto del modo (O05).
func jugar_con_bots(modo: String) -> bool:
	if not await pulsar("Dominó con bots"):
		return false
	await esperar(0.8)
	return await pulsar("Con aumentos" if modo == "aumentos" else "Clásico")


## Pulsa el botón con ese texto (esperándolo hasta max_seg). Devuelve si lo pulsó.
func pulsar(txt: String, max_seg := 8.0) -> bool:
	var ok := await hasta(func(): return boton(txt) != null and not boton(txt).disabled, max_seg)
	if not ok:
		_fallo_bot("boton_no_aparece", "No apareció el botón «%s» en la escena %s" % [txt, escena], txt)
		return false
	var b := boton(txt)
	await pulsar_nodo(b)
	return true


## Botón cuyo texto es exactamente «txt» (los precios: «4» no es «14»).
func _exacto(n: Node, txt: String) -> Button:
	if n is Button and n.is_visible_in_tree() and n.text == txt and not n.disabled:
		return n
	for c in n.get_children():
		var r := _exacto(c, txt)
		if r:
			return r
	return null


func pulsar_nodo(b: Control) -> void:
	if not is_instance_valid(b) or not b.is_visible_in_tree():
		return
	if _registro_acciones != null:
		_registro_acciones.store_line(JSON.stringify({"fotograma":frame, "segundo":_reloj, "control":str(b.get_path()), "texto":b.text if b is Button else b.name, "pantalla":m.menus.screen, "fase":m.g.phase}))
		_registro_acciones.flush()
	if b is Button:
		var confirmado := [false]
		var reconocer := func(): confirmado[0] = true
		b.pressed.connect(reconocer, CONNECT_ONE_SHOT)
		await mover(b.get_global_rect().get_center(), 0.25)
		# quién tiene el ratón encima justo antes de pulsar (para el clic perdido)
		var encima = m.get_viewport().gui_get_hovered_control()
		var encima_txt: String = str(encima.get_path()) + " filtro " + str(encima.mouse_filter) if encima != null else "ninguno"
		if not is_instance_valid(b):
			return   # el botón se fue mientras el ratón iba hacia él (la pantalla cambió)
		await clic(b.get_global_rect().get_center(), 0.0)
		if is_instance_valid(b) and b.pressed.is_connected(reconocer):
			b.pressed.disconnect(reconocer)
		if not confirmado[0]:
			_fallo_bot("clic_no_recibido", "El control no recibió pressed; encima: " + encima_txt, str(b.get_path()) if is_instance_valid(b) else "control liberado")
	else:
		await clic(b.get_global_rect().get_center())


func terminar() -> void:
	if _fin:
		return
	_fin = true
	marca("FIN")
	FileAccess.open(dir + "/resultado_bot.json", FileAccess.WRITE).store_string(JSON.stringify({
		"escena": escena, "estado": "FALLO" if _fallos_bot > 0 else "COMPLETADO",
		"fallos_bot": _fallos_bot, "segundos_simulados": _reloj, "casos": _cobertura,
		"fotogramas":frame, "auditoria_cada_frame":_auditoria_por_frame, "visual": {"muestras":_visual.muestras, "candidatos":_visual.vistos.size(), "estado":"PENDIENTE_REVISION"}, "observaciones": {"muestras":_observaciones.muestras, "reportados":_observaciones.contadores, "cobertura":_observaciones.COBERTURA}, "reglas": {"muestras":_reglas.muestras, "rotas":_reglas.contadores},
		"espacial": {"cobertura": _espacial.inventario, "candidatos": _espacial.emitidos.size(), "clasificacion": "PENDIENTE_REVISION_VISUAL"}}, "	"))
	await esperar(0.5)
	_marcas.close()
	_audit.close()
	_metricas.close()
	_frames.close()
	_registro_acciones.close()
	print("RECORRIDO TERMINADO ", escena)
	m.get_tree().quit()



# ------------------------------------------------ supervisor del bot (sin modificar reglas)
func _texto_accion(text: String) -> String:
	for symbol in ["💬", "✋", "⇧", "+", "▶", "▸", "‹", "▾", "←", "→"]:
		text = text.replace(symbol, "")
	return " ".join(text.to_lower().split(" ", false)).strip_edges()

func _cargar_idiomas() -> void:
	var csv := FileAccess.open("res://translations/textos.csv", FileAccess.READ)
	if csv == null:
		return
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() < 3:
			continue
		var key := _texto_accion(row[0])
		var aliases: Array = _idiomas.get(key, [])
		for text in row:
			var alias := _texto_accion(text)
			if not alias.is_empty() and not aliases.has(alias):
				aliases.append(alias)
		_idiomas[key] = aliases

func _estado_progreso() -> String:
	return str(m.g.phase, m.g.hand_no, m.g.turn, m.g.chain.size(),
		m.g.hands.map(func(h): return h.size()), m.g.revision, m.g.scores,
		m.view.counting, m.view.animating, m.my_picks.size(), m.paused,
		m.view.pie.mode, m.view.top_view, m.overlay.get_child_count())

func _fallo_bot(tipo: String, detalle: String, clave := "") -> void:
	_fallos_bot += 1
	hallazgo(tipo, detalle, clave)
	_evidencia(tipo)
	_cobertura.append({"caso": tipo, "estado": "FALLO", "detalle": detalle, "fotograma": frame})

func _evidencia(nombre: String) -> void:
	var base := "%s_%d" % [nombre, frame]
	foto(base)
	FileAccess.open(dir + "/" + base + ".json", FileAccess.WRITE).store_string(JSON.stringify({
		"fotograma": frame, "segundo": _reloj, "estado": _estado_progreso(),
		"revision": m.g.revision, "raton": Input.mouse_mode,
		"idioma": TranslationServer.get_locale()}, "	"))

func _caso(nombre: String, ok: bool) -> void:
	_cobertura.append({"caso": nombre, "estado": "COMPLETADO" if ok else "FALLO", "fotograma": frame})
	marca("CASO %s %s" % [nombre, "COMPLETADO" if ok else "FALLO"])

## Prioridad a revisión y tranque, incluso si ya cambió la fase del juego.
## Solo usa clics reales; nunca resolve_revision ni cambio directo de fase.
func _atender_pendientes() -> bool:
	if _atendiendo or _fin or not m.playing or m.paused:
		return false
	if m._revisando() >= 0:
		_atendiendo = true
		await _resolver_revision()
		_atendiendo = false
		return true
	if m.tranque.activo:
		return false   # el tranque con suspenso lo juega _paso_tranque
	if is_instance_valid(m.tranque_ui) and m.tranque_ui.is_visible_in_tree():
		_atendiendo = true
		marca("atender tranque antes de continuar")
		_evidencia("tranque_pendiente")
		await esperar(1.4)
		if not is_instance_valid(m.tranque_ui):
			_atendiendo = false
			return true
		var b := _buscar(m.tranque_ui, "visto")
		if b == null:
			b = _buscar(m.tranque_ui, str(tr("VISTO")).to_lower())
		if b != null and not b.disabled:
			await pulsar_nodo(b)
		var ok := await hasta(func(): return not is_instance_valid(m.tranque_ui), 35.0)
		_caso("tranque_reconocido", ok)
		if not ok:
			await terminar()
		_atendiendo = false
		return true
	return false

func _resolver_revision() -> void:
	marca("atender ventana UTE VA")
	_evidencia("ute_pendiente")
	var acc: int = m._revisando()
	if not await hasta(func(): return is_instance_valid(m.revision_ui), 3.0):
		return
	var target: Button
	for tile in m.g.hands[acc]:
		if m.g.fits(tile, -1) or m.g.fits(tile, 1):
			target = _buscar(m.revision_ui, "%d-%d" % [tile.x, tile.y])
			break
	if target == null:
		var hay_valida: bool = m.g.hands[acc].any(func(tile): return m.g.fits(tile, -1) or m.g.fits(tile, 1))
		if hay_valida:
			_fallo_bot("revision_sin_ficha", "Había ficha válida, pero el bot no encontró su control")
			await terminar()
			return
		target = _buscar(m.revision_ui, "no llevaba")
	if target == null:
		_fallo_bot("revision_sin_control", "No se encontró una ficha válida ni NO LLEVABA")
		await terminar()
		return
	marca("revisión: " + (target.tooltip_text if target.text.is_empty() else target.text))
	await pulsar_nodo(target)
	var ok := await hasta(func(): return m._revisando() < 0, 4.0)
	_caso("ute_resuelta", ok)
	_evidencia("ute_resultado")
	if not ok:
		await terminar()

func _recuperar() -> void:
	marca("RECUPERACION limitada; fallo conservado")
	if await _atender_pendientes():
		return
	if m.paused:
		await pulsar("SEGUIR", 2.0)
	elif m.view.counting:
		await pulsar("CONTAR TODAS", 2.0)
	elif m.view.top_view:
		await pulsar("Volver", 2.0)
	elif m.view.pie.mode == "de_pie":
		await tecla(KEY_SPACE)
	# No reinicia partida ni altera estado: el supervisor abandona si persiste.

# ---------------------------------------------------------------- auditoría automática

func _auditar() -> void:
	var botones: Array = []
	# con la pausa abierta, lo de debajo está tapado a propósito: solo cuenta la pausa
	_recoger_botones(m.pause_ui if m.paused and is_instance_valid(m.pause_ui) else m.get_tree().root, botones)
	var pantalla := Rect2(Vector2.ZERO, m.hud.get_viewport_rect().size)
	for b in botones:
		var r: Rect2 = b.get_global_rect()
		if not pantalla.grow(2).encloses(r):
			hallazgo("fuera_de_pantalla", "«%s» se sale de la pantalla (%s)" % [_nombre(b), r], _nombre(b))
		# texto más ancho que el botón (se corta o se sale)
		if b.text != "" and not b.clip_text and b.expand_icon == false:
			var f: Font = b.get_theme_font("font")
			var w: float = f.get_string_size(b.text if b.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED else tr(b.text), HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
			# en mitad de una animación de escala el rectángulo está encogido y el texto no
			w *= b.get_global_transform().get_scale().x
			if w > r.size.x + 1.0:
				hallazgo("texto_cortado", "«%s»: el texto mide %d px y el botón %d px" % [_nombre(b), w, r.size.x], _nombre(b))
	_pendientes = _ahora
	_ahora = {}
	for i in botones.size():
		for j in range(i + 1, botones.size()):
			var a: Control = botones[i]
			var c: Control = botones[j]
			if a.is_ancestor_of(c) or c.is_ancestor_of(a):
				continue
			var inter := a.get_global_rect().intersection(c.get_global_rect())
			if inter.get_area() > 24.0:
				# un contenedor recién mostrado coloca sus botones al fotograma siguiente:
				# solo cuenta si el solape sigue en la revisión siguiente
				var kk := _nombre(a) + "+" + _nombre(c)
				_ahora[kk] = true
				if not _pendientes.has(kk):
					continue
				hallazgo("botones_pisados", "«%s» y «%s» se pisan (%d px²)" % [_nombre(a), _nombre(c), inter.get_area()], _nombre(a) + "+" + _nombre(c))
	_auditar_mesa()


func _recoger_botones(n: Node, out: Array) -> void:
	if n is CanvasItem and not n.visible:
		return
	if n is Button and n.is_visible_in_tree() and n.mouse_filter != Control.MOUSE_FILTER_IGNORE and _opaco(n):
		out.append(n)
	for c in n.get_children():
		_recoger_botones(c, out)


func _opaco(c: CanvasItem) -> bool:
	var n: Node = c
	while n is CanvasItem:
		if n.modulate.a < 0.5 or n.self_modulate.a < 0.5:
			return false
		n = n.get_parent()
	return true


func _nombre(b: Button) -> String:
	if b.text != "":
		return b.text.replace("\n", " ")
	if b.tooltip_text != "":
		return b.tooltip_text.split("\n")[0]
	return b.name


var _invisibles := 0


## Comprobaciones de la mesa: fichas invisibles en tu bandeja y fichas montadas.
func _auditar_mesa() -> void:
	var g = m.g
	var v = m.view
	if not m.playing or v.animating or v.counting or g.phase != "play":
		return
	if not v.pie.standing() and not v.top_view and v.hand_nodes.size() == g.hands[0].size():
		var vis := 0
		for n in v.hand_nodes:
			if is_instance_valid(n) and n.is_visible_in_tree():
				vis += 1
		# cuenta solo si sigue así en dos revisiones seguidas (al sentarse se rehacen en un fotograma)
		_invisibles = _invisibles + 1 if vis < g.hands[0].size() else 0
		if _invisibles >= 2:
			hallazgo("fichas_invisibles", "Sentado en tu turno de juego se ven %d de tus %d fichas (modo %s, arriba %s)" % [vis, g.hands[0].size(), v.pie.mode, v.top_view], "mano")
			foto("fichas_invisibles")
	# fichas de la línea que se montan (huellas en la mesa que se cruzan)
	var huellas: Array = []
	for t in v._chain_nodes:
		var n = v._chain_nodes[t]
		if not is_instance_valid(n):
			continue
		# la que aún vuela hacia la mesa no cuenta (todavía no está puesta)
		if abs(n.global_position.y - (v.TABLE_Y + v.TD / 2 + 0.002)) > 0.004:
			continue
		var ax: Vector3 = n.global_transform.basis.y
		var largo := Vector2(ax.x, ax.z).normalized()
		huellas.append([Vector2(n.global_position.x, n.global_position.z), largo, t])
	for i in huellas.size():
		for j in range(i + 1, huellas.size()):
			if _se_montan(huellas[i], huellas[j]):
				hallazgo("fichas_montadas", "Las fichas %s y %s de la línea se montan" % [huellas[i][2], huellas[j][2]], str(huellas[i][2], huellas[j][2]))


## Dos fichas planas (rectángulos girados) que se solapan más de 4 mm.
func _se_montan(a: Array, b: Array) -> bool:
	var ejes := [a[1], Vector2(-a[1].y, a[1].x), b[1], Vector2(-b[1].y, b[1].x)]
	var mitad := Vector2(m.view.TW, m.view.TL) / 2.0 - Vector2(0.004, 0.004)
	for e in ejes:
		var pa := _proy(a, e, mitad)
		var pb := _proy(b, e, mitad)
		if pa.y <= pb.x or pb.y <= pa.x:
			return false
	return true


func _proy(h: Array, e: Vector2, mitad: Vector2) -> Vector2:
	var c: float = h[0].dot(e)
	var r: float = abs(h[1].dot(e)) * mitad.y + abs(Vector2(-h[1].y, h[1].x).dot(e)) * mitad.x
	return Vector2(c - r, c + r)


# ---------------------------------------------------------------- escenas

func _correr() -> void:
	await _recorrer_escena()
	if _fixture_pausa:
		m.set_process(true)
	await terminar()

func _recorrer_escena() -> void:
	marca("INICIO " + escena)
	await hasta(func(): return m.menus.screen == "inicio" or m.playing, 30.0)
	await esperar(1.0)
	match escena:
		"menus":
			await _escena_menus()
		"partida":
			await _escena_partida("aumentos", 2)
		"clasico":
			await _escena_partida("clasico", 2)
		"de_pie":
			await _escena_de_pie()
		"volver_silla":
			await _escena_volver_silla()
		"salidas":
			await _escena_salidas()
		"tranque":
			await _escena_tranque()
		"raros":
			await _escena_raros()
		"final":
			await _escena_final()
		"repro":
			await _escena_repro()
		"celebrar":
			_chivo_probado = true
			_ute_probado = true
			await pulsar("JUGAR")
			await esperar(2.0)
			await jugar_con_bots("aumentos")
			if not await _jugar_hasta(func(): return m.g.phase in ["shop", "over"], 300.0):
				return
			for k in 12:
				marca("t=%d fase %s cuenta %s end_t %.1f estados %s acciones %s" % [k, m.g.phase, m.view.counting, m.view._end_t,
					[1, 2, 3].map(func(x): return m.view.heads[x].state), [1, 2, 3].map(func(x): return m.view.heads[x]._action)])
				if k in [1, 5, 10]:
					foto("celebrar_%d" % k)
				await esperar(1.0)
		"revisar":
			_chivo_probado = true
			_ute_probado = true
			await pulsar("JUGAR")
			await esperar(3.0)
			foto("r_pizarra")
			await pulsar("Sala con amigos")
			await esperar(2.5)
			foto("r_amigos")
			m.menus.open("modos")
			await esperar(2.0)
			await jugar_con_bots("aumentos")
			if not await _jugar_hasta(func(): return m.g.phase == "play" and m.g.turn == 0 and not m.busy and not m.view.animating and m.g.chain.size() >= 2, 120.0):
				return
			await esperar(1.0)
			foto("r_mi_turno")
			marca("fuerzo un tranque")
			m.g._end_hand(-1, Vector2i(-1, -1), false)
			await esperar(2.6)
			foto("r_tranque_a")
			await esperar(2.0)
			foto("r_tranque_b")
			marca("resultado %s" % m.g.last_result)
			await esperar(8.0)
			foto("r_tras_cuenta")
		"ute":
			_chivo_probado = true
			_ute_probado = true
			await pulsar("JUGAR")
			await esperar(2.0)
			await jugar_con_bots("aumentos")
			if not await _jugar_hasta(func(): return m.g.phase == "play" and not m.view.animating and not m.busy, 120.0):
				return
			m.set_process(false)
			_fixture_pausa = true
			var g = m.g
			# Preparación explícita de una revisión, no una partida natural.
			if g.chain.is_empty():
				g.first_hand = false
				g.opener = 0
				g.turn = 0
				g.play(0, g.hands[0][0], 0)
			g.turn = 3
			# Fixture: aislar el renuncio de un tranque por cuatro pases.
			g.pass_streak = 0
			# Chichí (silla 3) lleva una que va y pasa igual (renuncio)
			g.hands[3][0] = Vector2i(g.left_end, (g.left_end + 3) % 7)
			g.pass_fake(3)
			m._refresh()
			# Dejar completar el layout antes de congelar la lógica del fixture.
			m.set_process(true)
			await m.get_tree().process_frame
			await m.get_tree().process_frame
			m.set_process(false)
			await esperar(1.5)
			foto("u_boton")
			await pulsar("¡UTE VA!", 3.0)
			m._tick_revision()
			await esperar(1.5)
			foto("u_panel")
			if not is_instance_valid(m.revision_ui):
				_fallo_bot("revision_desaparecida", "El panel UTE ya no existe; no continuar con un nodo liberado")
				return
			var mala: Vector2i = Vector2i(-1, -1)
			for t in g.hands[3]:
				if not (g.fits(t, -1) or g.fits(t, 1)):
					mala = t
			if mala.x >= 0:
				await pulsar_nodo(_buscar(m.revision_ui, "%d-%d" % [mala.x, mala.y]))
				await esperar(0.6)
				foto("u_no_iba")
			await _atender_pendientes()
			_caso("ute_escena", g.revision.is_empty())
			await esperar(1.0)
			foto("u_cazado")
			marca("resultado %s" % g.last_result)
		"mostrador":
			_chivo_probado = true
			_ute_probado = true
			await pulsar("JUGAR")
			await esperar(2.0)
			await jugar_con_bots("aumentos")
			if not await _jugar_hasta(func(): return m.g.phase == "play" and m.g.turn == 0 and not m.busy and not m.view.animating and m.g.chain.size() >= 1, 120.0):
				return
			marca("gestos sentado: bailar (los bots se suman) y brindar")
			await tecla(KEY_1)
			await esperar(1.2)
			foto("m_baile")
			await esperar(2.5)
			await tecla(KEY_7)
			await esperar(0.9)
			foto("m_brindis")
			if not await _jugar_hasta(func(): return m.g.phase == "shop" and not m.view.counting and m.overlay.get_child_count() > 2, 300.0):
				return
			await esperar(1.0)
			m.g.coins[0] = 30
			m._build_shop()
			await esperar(0.5)
			foto("m_tienda")
			await pulsar("IR AL MOSTRADOR")
			await hasta(func(): return m.view.pie.mode == "de_pie", 6.0)
			var sp: Vector2 = m.view.counter_spot()
			if not await caminar_hasta(sp + Vector2(0.3, 0.1)):
				return
			var cp: Vector3 = m.view.colmadero.global_position + Vector3(0, 0.3, 0)
			var eye := Vector3(m.view.pie.pos.x, m.view.pie.EYE, m.view.pie.pos.y)
			var d := cp - eye
			m.view.pie.yaw = atan2(-d.x, -d.z)
			m.view.pie.pitch = atan2(d.y, Vector2(d.x, d.z).length())
			await esperar(1.0)
			foto("m_mostrador")
			marca("mostrador visible: %s" % is_instance_valid(m.counter_ui))
			await pulsar("Café", 2.0)
			await esperar(0.8)
			foto("m_comprado")
			marca("bebidas %s monedas %d" % [m.g.drinks[0], m.g.coins[0]])
			await pulsar("SIGUIENTE MANO", 3.0)
			await esperar(4.0)
			foto("m_siguiente")
			marca("fase %s modo %s" % [m.g.phase, m.view.pie.mode])
			# fase 2: el café se bebe tocando el vaso de la mesa en tu turno
			if m.g.drinks[0].size() > 0 and await _jugar_hasta(func(): return m.g.phase == "play" and m.g.turn == 0 					and not m.busy and not m.view.animating and m.g.drinks[0].size() > 0, 120.0):
				for i in m.view.my_glasses.size():
					if m.view.glass_id(i) != "":
						await mover(m.view._u(m.view.my_glasses[i].global_position + Vector3(0, 0.03, 0)), 0.4)
						break
				await esperar(0.4)
				marca("vaso encima: hover %d · etiqueta %s" % [m.view.glass_hover, m.glass_tip.text.replace("
", " / ") if is_instance_valid(m.glass_tip) and m.glass_tip.visible else "no"])
				foto("m_vaso_encima")
				_caso("beber_tocando_vaso", await beber_vaso())
				foto("m_bebido")
		"mostrador_tiempo":
			# reglamento: quedarte en el mostrador hasta que se acaba la tienda.
			# Al empezar la elección de aumento te tiene que salir la ventana
			# donde estés (antes quedaba escondida) y el mostrador se cierra.
			_chivo_probado = true
			_ute_probado = true
			await pulsar("JUGAR")
			await esperar(2.0)
			await jugar_con_bots("aumentos")
			if not await _jugar_hasta(func(): return m.g.phase == "shop" and not m.view.counting and m.overlay.get_child_count() > 2, 400.0):
				return
			await esperar(1.0)
			await pulsar("IR AL MOSTRADOR")
			await hasta(func(): return m.view.pie.mode == "de_pie", 6.0)
			if not await caminar_hasta(m.view.counter_spot() + Vector2(0.3, 0.1)):
				return
			foto("mt_mostrador")
			marca("en el mostrador: %s · se acaba la tienda estando de pie" % is_instance_valid(m.counter_ui))
			# sin conexión la tienda no tiene reloj: SIGUIENTE MANO estando de pie
			# equivale a que se acabe el tiempo (online lo hace el servidor)
			await pulsar("SIGUIENTE MANO", 3.0)
			await hasta(func(): return m.g.phase == "pick", 20.0)
			await esperar(2.0)
			foto("mt_aumentos")
			var visible: bool = m.overlay.is_visible_in_tree()
			marca("aumentos tras el mostrador: ventana %s · de pie %s · mostrador %s · ratón %d" % [visible, m.view.pie.mode, is_instance_valid(m.counter_ui), Input.mouse_mode])
			_caso("aumentos_tras_mostrador", visible and not is_instance_valid(m.counter_ui))
		"silla":
			await pulsar("JUGAR")
			await esperar(2.0)
			await jugar_con_bots("aumentos")
			if not await _jugar_hasta(func(): return m.g.phase == "play" and not m.view.animating, 120.0):
				return
			var ch = m.view.heads[1]
			m.view.pie.set_remote(1, 1, Vector2(1.6, 0), PI / 2)
			for k in 30:
				var p := Vector2(1.6, 0.0).lerp(Vector2(0.6, 1.6), k / 29.0)
				m.view.pie.set_remote(1, 2 if k > 8 else 1, p, PI / 2)
				await esperar(0.2)
				if k % 5 == 0:
					marca("k=%d stand_k %.2f top %s silla %s cuerpo %s" % [k, ch.stand_k, ch.chair.top_level, ch.chair.global_position, ch.global_position])
			foto("silla")
		"foto_inicio":
			await esperar(2.5)
			foto("inicio")
		"online_cuatro":
			await _escena_online_cuatro()
		"online_anfitrion":
			await _escena_online(true)
		"online_amigo":
			await _escena_online(false)
		_:
			_fallo_bot("escena_desconocida", "No hay recorrido definido para " + escena)


# -- menús ------------------------------------------------------------------

func caminar_hasta(destino: Vector2, max_seg := 20.0) -> bool:
	var pie = m.view.pie
	var paso := 0.16
	var region: Rect2 = pie.room_r
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, Vector2i(ceil(region.size.x / paso), ceil(region.size.y / paso)))
	grid.cell_size = Vector2.ONE * paso
	grid.offset = region.position + Vector2.ONE * paso / 2
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var inicio := Vector2i((pie.pos - grid.offset) / paso)
	var fin := Vector2i((destino - grid.offset) / paso)
	for x in grid.region.size.x:
		for y in grid.region.size.y:
			var id := Vector2i(x, y)
			var centro := grid.get_point_position(id)
			var bloqueado: bool = not region.grow(-pie.RADIUS).has_point(centro)
			for box in pie.boxes:
				bloqueado = bloqueado or box.grow(pie.RADIUS + 0.02).has_point(centro)
			for seat in [1, 2, 3]:
				bloqueado = bloqueado or centro.distance_to(pie.person_pos(seat)) < pie.RADIUS + 0.34
			for silla in m.view.loose_chairs():
				var pos_silla := Vector2(silla.global_position.x, silla.global_position.z)
				bloqueado = bloqueado or centro.distance_to(pos_silla) < pie.RADIUS + 0.24
			grid.set_point_solid(id, bloqueado)
	if not grid.is_in_boundsv(inicio) or not grid.is_in_boundsv(fin):
		_fallo_bot("ruta_fuera_sala", "Origen/destino fuera del mapa de caminar")
		return false
	grid.set_point_solid(inicio, false)
	if grid.is_point_solid(fin):
		var mejor := INF
		var alternativo := fin
		for x in range(fin.x - 4, fin.x + 5):
			for y in range(fin.y - 4, fin.y + 5):
				var id := Vector2i(x, y)
				if not grid.is_in_boundsv(id) or grid.is_point_solid(id):
					continue
				var distancia := grid.get_point_position(id).distance_to(destino)
				if distancia < mejor and not grid.get_id_path(inicio, id).is_empty():
					mejor = distancia
					alternativo = id
		if mejor < 0.5:
			fin = alternativo
			destino = grid.get_point_position(fin)
	var ruta := grid.get_point_path(inicio, fin)
	if ruta.is_empty():
		_fallo_bot("ruta_no_encontrada", "No hay ruta libre hacia " + str(destino))
		return false
	marca("caminar por ruta: %d puntos; sin teletransporte" % ruta.size())
	var t := 0.0
	for punto in ruta:
		while pie.pos.distance_to(punto) > 0.13 and t < max_seg and pie.standing():
			var d: Vector2 = punto - pie.pos
			pie.yaw = atan2(-d.x, -d.y)
			_tecla(KEY_W, true)
			await m.get_tree().process_frame
			t += m.get_process_delta_time()
		_tecla(KEY_W, false)
		if t >= max_seg:
			_fallo_bot("caminar_bloqueado", "Ruta no completada; posición " + str(pie.pos))
			return false
	_caso("caminar_hasta_objetivo", pie.pos.distance_to(destino) < 0.35)
	return pie.pos.distance_to(destino) < 0.35

func _escena_menus() -> void:
	marca("calle: pasar el ratón por los letreros")
	for t in ["JUGAR", "PERSONAJE", "ARMARIO", "AJUSTES", "SALIR"]:
		var b := boton(t)
		if b:
			await mover(b.get_global_rect().get_center(), 0.3)
			await esperar(0.2)
	marca("pizarra")
	await pulsar("JUGAR")
	await esperar(2.0)
	await esperar(3.0)
	foto("pizarra")
	for t in ["Dominó con bots", "Sala con amigos"]:
		var b := boton(t)
		if b:
			await mover(b.get_global_rect().get_center(), 0.3)
	marca("dominó con bots: los dos folletos")
	await pulsar("Dominó con bots")
	await esperar(1.5)
	foto("bots")
	for t in ["Clásico", "Con aumentos"]:
		var b := boton(t)
		if b:
			await mover(b.get_global_rect().get_center(), 0.3)
	await pulsar("Volver a la pizarra")
	await esperar(1.0)
	marca("sala con amigos y vuelta")
	await pulsar("Sala con amigos")
	await esperar(1.0)
	foto("amigos")
	await _opcion_sala("modo", "clasico")
	await _opcion_sala("modo", "aumentos")
	await _opcion_sala("armas", true)
	await _opcion_sala("armas", false)
	marca("cambiar personaje desde la sala")
	await pulsar("Juegas con este personaje")
	await esperar(1.5)
	marca("espejo: cada pestaña y cada opción")
	for tab in ["Cuerpo", "Ropa", "Detalles"]:
		await pulsar(tab)
		await esperar(0.6)
		foto("espejo_" + tab.to_lower())
		# avanza cada fila un par de veces con ▶
		var flechas: Array = []
		_flechas(m.get_tree().root, flechas)
		for f in flechas:
			for k in 2:
				await pulsar_nodo(f)
				await esperar(0.15)
	marca("gestos del espejo")
	for gst in ["Guiñar", "Hablar", "Beber", "Reír", "Capicúa"]:
		await pulsar(gst)
		await esperar(1.0)
	await pulsar("Al azar")
	await esperar(0.8)
	marca("guardar sin nombre (debe avisar)")
	await pulsar("GUARDAR")
	await esperar(0.6)
	marca("recorrido circular")
	await pulsar("Armario")
	await esperar(1.8)
	foto("armario")
	for tab in ["Fichas", "Mesa", "Vasos"]:
		await pulsar(tab)
		await esperar(0.5)
		var items: Array = []
		_botones_con(m.get_tree().root, "·", items)
		for it in items:
			await mover(it.get_global_rect().get_center(), 0.25)
			await esperar(0.35)
		foto("armario_" + tab.to_lower())
	marca("ajustes encima del armario")
	await pulsar("Ajustes")
	await esperar(1.8)
	foto("ajustes")
	for t in ["Colmadón FM", "Tu música", "Apagada", "Suave", "Normal", "English", "Español"]:
		await pulsar(t)
		await esperar(0.5)
	foto("ajustes_despues")
	await pulsar("Borrar mis datos online")
	await esperar(0.4)
	foto("ajustes_borrar")
	await pulsar("Cancelar")
	await pulsar("Armario")
	await esperar(1.5)
	await pulsar("Tu personaje")
	await esperar(1.5)
	await pulsar("Jugar")
	await esperar(1.5)
	await pulsar("Volver a la calle")
	await esperar(1.5)
	foto("calle_final")


## Botones hechos con etiquetas dentro (las filas de la pizarra).
func _etiqueta_con(n: Node, txt: String) -> bool:
	for c in n.get_children():
		if c is Label and c.text.to_lower().contains(txt):
			return true
		if not c is Button and _etiqueta_con(c, txt):
			return true
	return false


func _flechas(n: Node, out: Array) -> void:
	if n is Button and n.is_visible_in_tree() and (n.text == "▶" or n.get_meta("option_next", false)):
		out.append(n)
	for c in n.get_children():
		_flechas(c, out)


func _botones_con(n: Node, txt: String, out: Array) -> void:
	if n is Button and n.is_visible_in_tree() and n.text.contains(txt):
		out.append(n)
	for c in n.get_children():
		_botones_con(c, txt, out)


# -- partida ----------------------------------------------------------------

## Juega como una persona: elige aumento, recoge, juega (clic o arrastre),
## pasa, canta, bebe, cuenta, compra… hasta jugar «manos» manos.
func _escena_partida(modo: String, manos: int) -> void:
	_chivo_probado = true
	_ute_probado = true
	marca("pizarra → %s" % modo)
	await pulsar("JUGAR")
	await esperar(2.0)
	await jugar_con_bots(modo)
	var mano_ini: int = m.g.hand_no
	if not await _jugar_hasta(func(): return m.g.phase == "over" or m.g.hand_no >= mano_ini + manos, 400.0):
		return
	marca("fin de la escena: fase %s, mano %d (empezó en %d), marcador %s" % [m.g.phase, m.g.hand_no, mano_ini, m.g.scores])
	foto("fin_" + modo)


# chivo y «¡Ute va!» los prueba la escena final: cantados en la primera mano
# acaban la partida de golpe y el recorrido no vería más manos
var _chivo_probado := false
var _ute_probado := false
var _bebidas_usadas := 0
var _turnos := 0


## Bucle de jugador: actúa según la fase hasta que se cumpla «fin».
func _jugar_hasta(fin: Callable, max_seg: float) -> bool:
	var t0 := _reloj
	var firma := ""
	var progreso := _reloj
	var intentos := 0
	var ultima_fase := ""
	while not _fin and _reloj - t0 < max_seg:
		if await _atender_pendientes():
			continue
		if fin.call():
			return true
		if m.tranque.activo:
			await _paso_tranque()
			continue
		var actual := _estado_progreso()
		if actual != firma:
			firma = actual
			progreso = _reloj
			intentos = 0
		elif _reloj - progreso > _limite_progreso:
			_fallo_bot("sin_progreso", "%.1f s sin progreso; recuperaciones utilizadas %d/2" % [_limite_progreso, intentos])
			if intentos >= 2:
				return false
			intentos += 1
			progreso = _reloj
			await _recuperar()
		var g = m.g
		if g.phase != ultima_fase:
			marca("fase " + g.phase + " (mano %d)" % g.hand_no)
			ultima_fase = g.phase
			foto("fase_%s_m%d" % [g.phase, g.hand_no])
		match g.phase:
			"pick":
				await _elegir_aumento()
			"draw":
				if _sin_recoger and g.hand_no == 1:
					# O07: no recoge y deja que se acabe el tiempo; las fichas tienen que volar a la bandeja
					await _medir_tiempo_agotado()
				elif m.draw_btn.visible:
					if m.online and not _robo_mirado and m.view.pool_nodes.size() == 28:
						await _mirar_robo()
					marca("recoger fichas")
					await pulsar_nodo(m.draw_btn)
					await esperar(1.0)
			"play":
				if m.online and _rol_online == 3 and not _salio_y_volvio and g.chain.size() >= 4 						and OS.get_cmdline_user_args().has("--salir-volver"):
					await _salir_y_volver()
				elif m.view.counting:
					await _contar()
				elif g.turn == 0 and not m.busy and not m.view.animating:
					await _mi_turno()
			"shop":
				if m.view.counting:
					await _contar()
				elif m.overlay.get_child_count() > 2:
					await _tienda()
			"over":
				if m.view.counting:
					await _contar()
				else:
					break
		await m.get_tree().process_frame

	_fallo_bot("objetivo_agotado", "Objetivo de juego no alcanzado en %.1f s" % max_seg)
	return false


func _elegir_aumento() -> void:
	if not await hasta(func(): return not m._card_nodes.is_empty() and m.overlay.get_child_count() > 2, 6.0):
		return
	await esperar(0.8)
	var ids: Array = m._card_nodes.keys()
	for id in ids:   # pasar por encima de cada carta
		var c: Control = m._card_nodes[id]
		if is_instance_valid(c):
			await mover(c.get_global_rect().get_center(), 0.25)
			await esperar(0.2)
	var elegido: Control = m._card_nodes[ids[_turnos % ids.size()]]
	marca("elige aumento")
	await pulsar_nodo(elegido)
	await esperar(0.5)
	foto("aumento_volando")
	await hasta(func(): return m.g.phase != "pick", 10.0)


func _mi_turno() -> void:
	var g = m.g
	await esperar(0.5)
	if g.phase != "play" or g.turn != 0 or m.busy:
		return
	_turnos += 1
	# a veces, beber lo que tienes
	if g.drinks[0].size() > 0 and _bebidas_usadas < 3 and _turnos % 3 == 0:
		var nombre: String = g.DRINKS[g.drinks[0][0]].name
		marca("beber " + nombre)
		if await beber_vaso():
			_bebidas_usadas += 1
			await esperar(2.5)
			if g.phase != "play" or g.turn != 0:
				return
	var moves: Array = g.legal_moves(0)
	# el anterior pasó: a veces se le canta «¡Ute va!»
	if not _ute_probado and g.last_pass_seat == 3 and not g.chain.is_empty():
		_ute_probado = true
		marca("cantar ¡UTE VA!")
		await pulsar("¡UTE VA!", 2.0)
		await esperar(2.0)
		return
	if moves.is_empty():
		# meter un chivo una vez por partida; si no, pasar
		var normales: Array = g.hands[0].filter(func(t): return t.x != t.y)
		if not _chivo_probado and g.hands[0].size() > 2 and not normales.is_empty():
			_chivo_probado = true
			marca("meter chivo arrastrando")
			var i: int = g.hands[0].find(normales[0])
			await arrastrar(m.view.hand_rects()[i].get_center(), func(): return m.view.end_screen_pos(1))
			await esperar(1.0)
			return
		marca("PASO (no lleva)")
		await pulsar("PASO", 3.0)
		await esperar(0.8)
		return
	var mv: Dictionary = moves[_turnos % moves.size()]
	var i: int = g.hands[0].find(mv.tile)
	if i < 0 or i >= m.view.hand_rects().size():
		return
	var desde: Vector2 = m.view.hand_rects()[i].get_center()
	await mover(desde, 0.3)   # la ficha se levanta al pasar el ratón
	await esperar(0.2)
	var lados: int = moves.filter(func(x): return x.tile == mv.tile).size()
	if _turnos % 2 == 0 or g.chain.is_empty():
		marca("jugar %s con clic" % mv.tile)
		await clic(desde, 0.1)
		if lados > 1:
			await esperar(0.4)
			foto("elige_punta")
			await clic(m.view.end_screen_pos(mv.side), 0.3)
	else:
		marca("jugar %s arrastrando" % mv.tile)
		var lado: int = mv.side
		await arrastrar(desde, func(): return m.view.end_screen_pos(lado) if not m.g.chain.is_empty() else Vector2(320, 180), 0.6)
	await esperar(1.2)


func _contar() -> void:
	var inicio := _reloj
	var clicks := 0
	# La interfaz de cuenta puede aparecer unos frames después de counting.
	# No esperar pasivamente si la cuenta pasa a manual durante la animación.
	# cuenta de otra persona (online): se mira a su ritmo, sin tocar
	while m.view.counting and not _fin and _reloj - inicio < (60.0 if m.view.count_remote else 45.0):
		if m.view.count_manual and not m.view.count_remote and is_instance_valid(m._count_ui) and not m.view._count_left.is_empty():
			var n: int = m.view._count_left[0]
			if is_instance_valid(m.view._count_order[n][0]):
				var nodo = m.view._count_order[n][0]
				await clic(m.view._u(nodo.global_position), 0.2)
				clicks += 1
				if clicks == 3:
					foto("contando")
			if clicks >= 40:
				break
		await esperar(0.15)
	if m.view.counting:
		_fallo_bot("cuenta_sin_terminar", "La cuenta no terminó tras 45 s o 40 clics; intento CONTAR TODAS")
		await pulsar("CONTAR TODAS", 2.0)
		await hasta(func(): return not m.view.counting, 5.0)
	await esperar(0.5)


func _tienda() -> void:
	await esperar(1.0)
	foto("tienda_m%d" % m.g.hand_no)
	# fin de mano (cuenta normal o tranque): ninguna ficha encima de otra
	var solapes: Array = m.view.fichas_solapadas()
	marca("fin de mano %d (%s): fichas que se pisan %d" % [m.g.hand_no, m.g.last_result.get("reason", "?"), solapes.size()])
	if not solapes.is_empty():
		foto("solapes_m%d" % m.g.hand_no)
		hallazgo("fichas_solapadas", "%d parejas de fichas se pisan al acabar la mano %d (%s)" % [solapes.size(), m.g.hand_no, m.g.last_result.get("reason", "?")])
	if m.online and _rol_online == 1 and not _mostrador_online and m.g.mode != "clasico":
		# reglamento T1/T2: te quedas en el mostrador hasta que se acaba el
		# tiempo de la tienda; la ventana de aumentos te tiene que salir y el
		# mostrador se cierra
		_mostrador_online = true
		await pulsar("IR AL MOSTRADOR")
		await hasta(func(): return m.view.pie.mode == "de_pie", 6.0)
		await caminar_hasta(m.view.counter_spot() + Vector2(0.3, 0.1))
		foto("online_mostrador")
		marca("online: en el mostrador hasta que se acabe la tienda")
		await hasta(func(): return m.g.phase == "pick", 90.0)
		await esperar(2.5)
		foto("online_aumentos_tras_mostrador")
		var ok: bool = m.overlay.is_visible_in_tree() and not is_instance_valid(m.counter_ui)
		marca("online: aumentos tras el mostrador · ventana %s · de pie %s · mostrador %s" % [m.overlay.is_visible_in_tree(), m.view.pie.mode, is_instance_valid(m.counter_ui)])
		_caso("aumentos_tras_mostrador_online", ok)
		return
	if m.g.mode != "clasico":
		# comprar la primera bebida que se pueda
		for id in m.g.DRINKS:
			if m.g.can_buy(0, id):
				marca("comprar " + id)
				var precio := _exacto(m.get_tree().root, str(m.g.drink_cost(0, id)))
				if precio:
					await pulsar_nodo(precio)
				await esperar(0.6)
				break
	marca("ver la mesa desde la tienda")
	var contada_antes: bool = int(m.view.counted_hand) == m.g.hand_no
	await pulsar("Ver la mesa")
	await esperar(1.0)
	# C3: la mesa sigue como la dejó la cuenta (las fichas no vuelven a las bandejas)
	foto("ver_mesa_tras_cuenta_m%d" % m.g.hand_no)
	if contada_antes:
		_caso("ver_mesa_tras_cuenta", int(m.view.counted_hand) == m.g.hand_no)
	await pulsar("Desde abajo" if m.view.top_view else "Desde arriba")
	await esperar(1.2)
	foto("mesa_arriba_m%d" % m.g.hand_no)
	await pulsar("Volver")
	await esperar(0.6)
	marca("siguiente mano")
	await pulsar("SIGUIENTE MANO")
	await esperar(1.0)
	if m.online:   # online la tienda sigue hasta que los cuatro están listos
		await hasta(func(): return m.g.phase != "shop", 40.0)


# -- sala de espera: sillas, nombre de equipo y LISTO ------------------------

## Responde a lo que pida la sala hasta estar listo: acepta un cambio de silla,
## propone el nombre (la primera propuesta de la pareja se rechaza para probarlo)
## y marca LISTO. Comprueba también que «¡A JUGAR!» siga apagado mientras falte alguien.
func _sala_acordar_y_listo(rol: int) -> void:
	var rechazado := false
	var t0 := Time.get_ticks_msec()
	while m.g.phase == "lobby" and Time.get_ticks_msec() - t0 < 90000:
		await esperar(0.4)
		var v: Dictionary = m.online_v
		var pet = v.get("peticion", null)
		if pet is Dictionary and int(pet.a) == 0:
			marca("acepto el cambio de silla")
			await pulsar("Aceptar")
			continue
		if pet is Dictionary:
			continue   # primero el cambio de silla (cambia las parejas)
		if rol == 0 and is_instance_valid(m._lobby.get("go")) and m._lobby.go.disabled == false and not v.get("todos_listos", false):
			hallazgo("jugar_sin_listos", "«¡A JUGAR!» habilitado sin todos listos")
		var ns: Array = v.get("nombres", [])
		if ns.size() < 2:
			continue
		var me: Dictionary = ns[0]
		var listo: bool = bool(v.get("listos_sala", [false])[0])
		match str(me.estado):
			"aceptado":
				if not listo:
					marca("LISTO")
					await pulsar("LISTO")
				else:
					return
			"propuesto":
				if int(me.propone) != 0:
					if not rechazado:
						rechazado = true
						marca("no me gusta «%s»" % me.nombre)
						await pulsar("No me gusta")
					else:
						marca("me gusta «%s»" % me.nombre)
						await pulsar("Me gusta")
			_:
				# los dos pueden proponer: vale el primero que llega al servidor
				if int(me.turno) in [-1, 0] and is_instance_valid(m._team_edit):
					m._team_edit.text = "QA%d" % rol
					marca("propongo QA%d" % rol)
					m._send_team_name()
					await esperar(0.8)
	_caso("sala_lista", bool(m.online_v.get("listos_sala", [false])[0]) or m.g.phase != "lobby")


# -- de pie -----------------------------------------------------------------

## Fichas que se pisan en la mesa del tranque: durante el revelar y al acabar la cuenta.
func _medir_solapes_tranque() -> void:
	await esperar(2.5)   # que acaben de llegar al montón
	var malos: Array = m.view.fichas_solapadas()
	marca("tranque: fichas que se pisan %d" % malos.size())
	if not malos.is_empty():
		foto("tranque_solapes")
		hallazgo("fichas_solapadas", "%d parejas de fichas se pisan en la cuenta del tranque: %s" % [malos.size(), str(malos.slice(0, 3))])


## Un paso del tranque (online o no): girar en tu turno (la primera vez, amago),
## VISTO y entregar o arrebatar. Marca lo que hace para el informe.
var _tq_amagado := false
var _tq_visto_mano := -1
var _tq_entregado_mano := -1
var _tq_amago_clave := -1


## Cada tranque es nuevo: la mano 1 de otra partida no es la de antes.
func _tq_clave() -> int:
	return m._game_session * 1000 + m.g.hand_no
func _paso_tranque() -> void:
	var tq = m.tranque
	var e: String = tq.st.get("etapa", "")
	if e == "revelar" and int(tq.st.get("turno", -1)) == 0 and tq._quedan(0) > 0:
		var i: int = tq._siguiente(0)
		var at: Vector2 = m.view.tranque_ficha_en_pantalla(0, i)
		if _tq_amago_clave != _tq_clave():
			_tq_amago_clave = _tq_clave()
			_tq_amagado = false
		if not _tq_amagado:
			_tq_amagado = true
			marca("tranque: amago")
			tq.clic(at, true)
		else:
			marca("tranque: giro mi ficha %d" % i)
			tq.clic(at)
		await esperar(0.9)
		return
	if e == "visto" and _tq_visto_mano != _tq_clave():
		_tq_visto_mano = _tq_clave()
		await esperar(2.0)
		foto("tranque_visto_m%d" % m.g.hand_no)
		marca("tranque: VISTO (gana la silla %d)" % int(tq.st.get("ganador", -1)))
		await pulsar("VISTO", 5.0)
		return
	if e == "entregar" and _tq_entregado_mano != _tq_clave():
		_tq_entregado_mano = _tq_clave()
		await esperar(0.6)
		if int(tq.st.get("ganador", -1)) == 0:
			marca("tranque: arrebato")
			await pulsar("Quitar a", 5.0)
		elif not tq.st.get("entregadas", [false])[0]:
			marca("tranque: entrego mis fichas")
			await pulsar("ENTREGAR", 5.0)
		return
	await esperar(0.3)


var _sin_recoger: bool = "--sin-recoger" in OS.get_cmdline_user_args()
var _tiempo_medido := false


## Sin tocar el montón hasta que acaba el tiempo de robar: al repartir, las
## fichas de tu mano deben moverse (vuelan del montón a la bandeja), no aparecer.
func _medir_tiempo_agotado() -> void:
	if _tiempo_medido:
		await esperar(0.2)
		return
	_tiempo_medido = true
	marca("tiempo agotado: no recojo")
	if not await hasta(func(): return m.g.phase != "draw" and m.view.hand_nodes.size() >= 5, 90.0, false):
		_caso("tiempo_agotado_vuelan", false)
		return
	var inicio := {}
	for n in m.view.hand_nodes:
		if is_instance_valid(n):
			inicio[n.get_instance_id()] = n.global_position
	var max_mov := {}
	for k in 30:
		await m.get_tree().process_frame
		for n in m.view.hand_nodes:
			if is_instance_valid(n) and inicio.has(n.get_instance_id()):
				var d: float = n.global_position.distance_to(inicio[n.get_instance_id()])
				max_mov[n.get_instance_id()] = maxf(float(max_mov.get(n.get_instance_id(), 0.0)), d)
		if k == 6:
			foto("tiempo_agotado_vuelan")
	var vuelan: int = max_mov.values().filter(func(d): return d > 0.05).size()
	marca("tiempo agotado: %d de %d fichas vuelan a la bandeja" % [vuelan, inicio.size()])
	_caso("tiempo_agotado_vuelan", vuelan >= 5)


## Tranque con suspenso sin conexión: se fuerza un tranque y se juega entero
## (girar con amago, VISTO, entregar o arrebatar) con fotos de cada momento.
func _escena_tranque() -> void:
	await pulsar("JUGAR")
	await esperar(2.0)
	await jugar_con_bots("aumentos")
	# un tranque de verdad llega con la línea larga (dobla por los bordes): se fuerza tarde
	if not await _jugar_hasta(func(): return m.g.phase == "play" and m.g.turn == 0 and not m.busy and not m.view.animating and m.g.chain.size() >= 12, 240.0):
		if not await _jugar_hasta(func(): return m.g.phase == "play" and m.g.turn == 0 and not m.busy and not m.view.animating and m.g.chain.size() >= 2, 120.0):
			return
	marca("fuerzo un tranque con %d fichas jugadas" % m.g.chain.size())
	var marcador0: Array = m.g.scores.duplicate()
	m.g._end_hand(-1, Vector2i(-1, -1), false)
	if not await hasta(func(): return m.tranque.activo, 6.0):
		return
	await esperar(2.0)
	foto("tq_mesa_boca_abajo")
	marca("marcador mientras se revela %s (antes %s, ahora %s)" % [m.score_us.text + "-" + m.score_them.text, marcador0, m.g.scores])
	_caso("tranque_marcador_oculto", m.score_us.text == str(marcador0[0]) and m.score_them.text == str(marcador0[1]))
	var amagado := false
	var fotos_turno := false
	var t0 := Time.get_ticks_msec()
	while m.tranque.activo and m.tranque.st.get("etapa", "") == "revelar" and Time.get_ticks_msec() - t0 < 90000:
		if int(m.tranque.st.get("turno", -1)) == 0 and m.tranque._quedan(0) > 0 and Time.get_ticks_msec() >= int(m.tranque.st.get("_bot_listo", 0)):
			if not fotos_turno:
				fotos_turno = true
				foto("tq_mi_turno")
			var i: int = m.tranque._siguiente(0)
			var at: Vector2 = m.view.tranque_ficha_en_pantalla(0, i)
			if not amagado:
				amagado = true
				marca("amago")
				m.tranque.clic(at, true)
			else:
				marca("giro mi ficha %d" % i)
				m.tranque.clic(at)
			await esperar(0.9)
		await esperar(0.2)
	var solapes_rev: Array = m.view.fichas_solapadas()
	marca("tranque: fichas que se pisan al revelar %d" % solapes_rev.size())
	if not solapes_rev.is_empty():
		hallazgo("fichas_solapadas", "%d parejas se pisan al revelar" % solapes_rev.size())
	foto("tq_revelado")
	_caso("tranque_revelar", m.tranque.st.get("etapa", "") in ["visto", "entregar", "fin"])
	await hasta(func(): return m.tranque.st.get("etapa", "") == "visto", 10.0)
	await esperar(1.8)
	foto("tq_visto")
	await pulsar("VISTO", 5.0)
	await hasta(func(): return m.tranque.st.get("etapa", "") == "entregar", 10.0)
	await esperar(0.8)
	foto("tq_entregar")
	# regla T6: el marcador no suma el tranque hasta que se cierra su pantalla
	_caso("tranque_marcador_hasta_el_final", m.score_us.text == str(marcador0[0]) and m.score_them.text == str(marcador0[1]))
	var gana: int = int(m.tranque.st.get("ganador", -1))
	marca("gana la silla %d" % gana)
	if gana == 0:
		await pulsar("Quitar a", 5.0)
	else:
		await pulsar("ENTREGAR", 5.0)
	await esperar(1.0)
	foto("tq_entregando")
	await _medir_solapes_tranque()
	_caso("tranque_completo", await hasta(func(): return not m.tranque.activo, 30.0))
	await esperar(0.3)
	_caso("tranque_marcador_suma_al_cerrar", m.score_us.text == str(m.g.scores[0]) and m.score_them.text == str(m.g.scores[1]))
	await esperar(1.5)
	foto("tq_tienda")
	marca("fase tras el tranque: %s" % m.g.phase)


## Todas las formas de volver a la silla desde muchos sitios: forzado (colmadero,
## siguiente mano, «volver a la silla») y a mano (E cerca de la silla). Mide lo
## que tarda y si se atasca (más de 7 s andando delante de la silla).
func _escena_volver_silla() -> void:
	await pulsar("JUGAR")
	await esperar(2.0)
	await jugar_con_bots("aumentos")
	if not await _jugar_hasta(func(): return m.g.phase == "play" and not m.view.animating, 120.0):
		return
	m.paused = false
	var pie = m.view.pie
	var sitios := [Vector2(2.2, 1.8), Vector2(-2.2, 1.8), Vector2(2.3, -1.2), Vector2(-2.3, -1.2), Vector2(1.6, 0.0), Vector2(-1.6, 0.0),
		Vector2(0.9, 1.3), Vector2(-0.6, 1.5), Vector2(0.0, 1.9), Vector2(0.6, 1.1), Vector2(-0.3, 1.25), Vector2(1.4, -1.6)]
	var peor := 0.0
	var probados := 0
	for forzado in [true, false]:
		for p in sitios:
			if m.g.phase != "play":
				await _jugar_hasta(func(): return m.g.phase == "play" and not m.view.animating, 60.0)
			if pie.mode == "sentado":
				await pulsar("PARARSE", 4.0)
			if not await hasta(func(): return pie.mode == "de_pie", 6.0, false):
				continue
			var q: Vector2 = pie.rot_point(p, -m.view.room_seat) if m.view.room_seat != 0 else p
			if not pie.free_spot(q):
				continue
			if not forzado and q.distance_to(pie.SEAT_SPOT) > pie.SIT_RANGE:
				q = pie.SEAT_SPOT + (q - pie.SEAT_SPOT).normalized() * (pie.SIT_RANGE - 0.05)
				if not pie.free_spot(q):
					continue
			pie.pos = q
			pie.vel = Vector2.ZERO
			await esperar(0.3)
			var atascos0: int = pie.atascos
			var t0 := Time.get_ticks_msec()
			if forzado:
				pie.sit_down(true)
			else:
				await tecla(KEY_SPACE)
			var ok: bool = await hasta(func(): return pie.mode == "sentado", 12.0, false)
			var seg := (Time.get_ticks_msec() - t0) / 1000.0
			probados += 1
			peor = maxf(peor, pie.ultimo_regreso)
			marca("volver a la silla %s desde (%.1f, %.1f): %.1f s andando · %s" % ["forzado" if forzado else "con E", p.x, p.y, pie.ultimo_regreso, "ATASCO" if pie.atascos > atascos0 else ("ok" if ok else "NO SE SENTÓ")])
			if pie.atascos > atascos0 or not ok:
				hallazgo("silla_atasco", "Vuelta a la silla desde (%.1f, %.1f) %s: %.1f s" % [p.x, p.y, "forzada" if forzado else "con E", seg])
	# el colmadero te manda a tu silla estando en el suelo (tras un manotazo)
	if pie.mode == "sentado":
		await pulsar("PARARSE", 4.0)
	if await hasta(func(): return pie.mode == "de_pie", 6.0, false):
		pie.knockdown(2.0)
		await esperar(0.3)
		pie.sit_down(true)
		var caido_ok: bool = await hasta(func(): return pie.mode == "sentado", 12.0, false)
		marca("sentarse estando en el suelo: %s" % ("ok" if caido_ok else "NO SE SENTÓ"))
		if not caido_ok:
			hallazgo("silla_atasco", "La orden de sentarse estando en el suelo se perdió")
	marca("vueltas probadas %d · la más larga %.1f s andando" % [probados, peor])
	_caso("volver_silla_sin_atascos", probados > 0)


func _escena_de_pie() -> void:
	await pulsar("JUGAR")
	await esperar(2.0)
	await jugar_con_bots("aumentos")
	if not await _jugar_hasta(func(): return m.g.phase == "play" and m.g.chain.size() >= 2 and m.g.turn != 0 and not m.view.animating, 120.0):
		return
	marca("PARARSE")
	await pulsar("PARARSE")
	await esperar(0.8)
	foto("levantandose")
	await esperar(2.0)
	foto("de_pie")
	marca("mirar alrededor con el ratón")
	await girar(-500, 0, 1.5)
	await girar(900, -80, 2.0)
	await girar(-400, 120, 1.0)
	marca("caminar: vuelta al colmado")
	await teclas([KEY_D], 1.2)
	await girar(-250, 0, 0.5)
	await teclas([KEY_W], 1.5)
	await teclas([KEY_W, KEY_A], 1.0)
	foto("caminando")
	await girar(-300, 0, 0.6)
	await teclas([KEY_W], 2.0)
	marca("chocar con la mesa y con alguien")
	await teclas([KEY_W], 1.0)
	await teclas([KEY_S], 0.4)
	marca("gestos 1-5")
	for k in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]:
		await tecla(k)
		await esperar(1.6)
	foto("gestos")
	marca("buscar a alguien para empujar")
	var cerca := await hasta(func(): return m._nearest_person() >= 0, 0.1, false)
	if not cerca:
		var p: Vector2 = m.view.pie.person_pos(3) + Vector2(0.55, 0.5)
		m.view.pie.pos = p
		await esperar(0.3)
	await tecla(KEY_Q)
	await esperar(1.0)
	foto("empujon")
	marca("lejos de la silla: E no debe sentarte")
	m.view.pie.pos = Vector2(1.2, -1.45)
	await esperar(0.5)
	await tecla(KEY_SPACE)
	await esperar(0.5)
	if m.view.pie.mode != "de_pie":
		hallazgo("se_sienta_lejos", "Con E lejos de la silla se sentó")
	foto("lejos")
	marca("soltar el ratón con Tab y pulsar un gesto con el ratón")
	await tecla(KEY_TAB)
	await esperar(0.3)
	await pulsar("Bailar")
	await esperar(1.5)
	marca("volver a la silla caminando y sentarse")
	m.view.pie.pos = m.view.pie.SEAT_SPOT + Vector2(0.3, 0.05)
	await esperar(0.5)
	await tecla(KEY_SPACE)
	await hasta(func(): return not m.view.pie.standing(), 12.0)
	await esperar(1.0)
	foto("sentado")
	if m.view.pie.standing():
		hallazgo("no_se_sienta", "Cerca de la silla, E no lo sentó")
	marca("seguir jugando un poco")
	var mano: int = m.g.hand_no
	if not await _jugar_hasta(func(): return m.g.hand_no > mano or m.g.phase == "over", 120.0):
		return


# -- casos raros ------------------------------------------------------------

func _escena_raros() -> void:
	_chivo_probado = true
	_ute_probado = true
	await pulsar("JUGAR")
	await esperar(2.0)
	await jugar_con_bots("aumentos")
	marca("pausa en la elección de aumento")
	await hasta(func(): return m.g.phase == "pick" and m.overlay.get_child_count() > 2, 10.0)
	await esperar(1.0)
	await pulsar_nodo(m.pause_btn)
	await esperar(0.8)
	foto("pausa_aumento")
	await pulsar("SEGUIR")
	await _elegir_aumento()
	marca("pausa al barajar")
	await esperar(0.5)
	await tecla(KEY_ESCAPE)
	await esperar(0.8)
	foto("pausa_barajando")
	await tecla(KEY_ESCAPE)
	if not await _jugar_hasta(func(): return m.g.phase == "play" and m.g.turn == 0 and not m.busy and not m.view.animating, 60.0):
		return
	marca("ajustes desde la pausa en mi turno")
	await tecla(KEY_ESCAPE)
	await esperar(0.6)
	await pulsar("AJUSTES")
	await esperar(1.5)
	foto("ajustes_desde_pausa")
	await pulsar("LISTO")
	await esperar(1.5)
	foto("vuelta_de_ajustes")
	marca("ver la mesa desde arriba en mi turno (tocando la mesa)")
	await clic(Vector2(320, 200))
	await esperar(1.0)
	foto("arriba_en_turno")
	await clic(Vector2(320, 200))
	await esperar(0.8)
	marca("pararse en mi turno y pausar de pie")
	await pulsar("PARARSE")
	await esperar(3.0)
	await tecla(KEY_ESCAPE)
	await esperar(0.8)
	foto("pausa_de_pie")
	await pulsar("SEGUIR")
	await esperar(1.0)
	marca("salir al colmado a mitad de mano")
	await tecla(KEY_ESCAPE)
	await esperar(0.5)
	await pulsar("SALIR AL COLMADO")
	await esperar(2.5)
	foto("calle_tras_salir")
	marca("otra partida en inglés")
	m.menus.settings.idioma = "en"
	m.apply_settings()
	await pulsar("JUGAR")   # los botones guardan el texto en español (se ve en inglés)
	await esperar(2.0)
	await jugar_con_bots("aumentos")
	var mano: int = m.g.hand_no
	if not await _jugar_hasta(func(): return m.g.hand_no > mano or m.g.phase == "over", 150.0):
		return
	foto("ingles")
	m.menus.settings.idioma = "es"
	m.apply_settings()


# -- reproducir: ver la mesa tras una mano y empezar otra partida rápida --

func _escena_repro() -> void:
	_chivo_probado = true
	_ute_probado = true
	await pulsar("JUGAR")
	await esperar(2.0)
	await jugar_con_bots("aumentos")
	if not await _jugar_hasta(func(): return m.g.phase == "shop" and not m.view.counting and m.overlay.get_child_count() > 2, 200.0):
		return
	await esperar(1.5)
	foto("r1_tienda")
	await pulsar("Ver la mesa")
	await esperar(1.5)
	foto("r2_ver_mesa")
	marca("barra: %s" % (str(m._review_bar.get_global_rect()) if is_instance_valid(m._review_bar) else "no hay"))
	await tecla(KEY_ESCAPE)
	await esperar(0.6)
	await pulsar("SALIR AL COLMADO")
	await esperar(2.5)
	await pulsar("JUGAR")
	await esperar(2.0)
	await jugar_con_bots("aumentos")
	await hasta(func(): return m.g.phase == "pick" and m.overlay.get_child_count() > 2, 10.0)
	await esperar(1.5)
	foto("r3_aumento_nueva")
	await _elegir_aumento()
	await esperar(2.0)
	foto("r4_tras_aumento")
	await esperar(4.0)
	foto("r5_barajando")


# -- final de partida --------------------------------------------------------

func _escena_final() -> void:
	await pulsar("JUGAR")
	await esperar(2.0)
	await jugar_con_bots("aumentos")
	await hasta(func(): return m.g.phase == "pick", 10.0)
	m.g.scores = [92, 88]   # a punto de acabar: la libreta llega en esta mano
	marca("última mano (marcador 92-88)")
	if not await _jugar_hasta(func(): return m.g.phase == "over" and not m.view.counting, 200.0):
		return
	await hasta(func(): return boton("REVANCHA") != null, 10.0)
	await esperar(1.0)
	foto("libreta")
	marca("libreta: ver la mesa")
	await pulsar("Ver la mesa")
	await esperar(1.0)
	await pulsar("Desde abajo" if m.view.top_view else "Desde arriba")
	await esperar(1.2)
	foto("libreta_mesa_arriba")
	await pulsar("Volver")
	await esperar(0.8)
	marca("revancha")
	await pulsar("REVANCHA")
	await esperar(2.0)
	foto("revancha")
	await esperar(1.0)
	await tecla(KEY_ESCAPE)
	await pulsar("SALIR AL COLMADO")
	await esperar(2.0)


# -- online (dos ventanas: anfitrión y amigo) -------------------------------

func _escena_online(anfitrion: bool) -> void:
	await pulsar("JUGAR")
	await esperar(2.0)
	if m.menus.screen != "modos":
		m.menus.open("modos")
		await esperar(2.0)
	await pulsar("Sala con amigos")
	await esperar(1.0)
	# nombre del personaje (obligatorio online)
	m.menus.profile.nombre = "Anfitrión" if anfitrion else "Amigo"
	var codigo_f := ProjectSettings.globalize_path("res://capturas/recorrido/codigo_sala.txt")
	if anfitrion:
		DirAccess.remove_absolute(codigo_f)
		marca("crear sala")
		m.menus.open("amigos")
		await esperar(0.8)
		await pulsar("CREAR")
		await hasta(func(): return m.online and m.red.codigo != "", 20.0)
		var f := FileAccess.open(codigo_f, FileAccess.WRITE)
		f.store_string(m.red.codigo)
		f.close()
	else:
		m.menus.open("amigos")
		await hasta(func(): return FileAccess.file_exists(codigo_f), 40.0)
		await esperar(1.5)
		var code := FileAccess.get_file_as_string(codigo_f).strip_edges()
		marca("entrar con el código " + code)
		var campo := _campo(m.get_tree().root)
		if campo:
			await clic(campo.get_global_rect().get_center())
			for ch in code:
				var ev := InputEventKey.new()
				ev.unicode = ch.unicode_at(0)
				ev.keycode = OS.find_keycode_from_string(ch)
				ev.pressed = true
				m.get_viewport().push_input(ev, true)
				await m.get_tree().process_frame
		await pulsar("Entrar")
		if not await hasta(func(): return m.online, 20.0):
			foto("amigo_no_entra")
			hallazgo("amigo_no_entra", "El amigo no consiguió entrar en la sala " + code)
	await esperar(2.0)
	foto("sala_espera")
	marca("frase del chat")
	await pulsar_nodo(m.chat_btn)
	await esperar(0.5)
	await pulsar("Pásate" if anfitrion else "Capicúa")
	if anfitrion:
		await hasta(func():
			var n := 0
			for s in m.online_v.get("seats", []):
				if not s.bot:
					n += 1
			return n >= 2, 40.0)
		await esperar(1.5)
		marca("¡A JUGAR!")
		await pulsar("A JUGAR")
	await hasta(func(): return m.g.phase != "lobby", 40.0)
	# el anfitrión se para y pasea; el amigo tapa sus fichas al verlo
	var parado := false
	var t0 := frame
	while m.online and m.g.phase != "over" and (frame - t0) / FPS < 240.0:
		var g = m.g
		if anfitrion and not parado and g.phase == "play" and g.chain.size() >= 3 and g.turn != 0 and m.stand_btn.visible:
			parado = true
			marca("online: pararse y caminar")
			await pulsar_nodo(m.stand_btn)
			await esperar(3.0)
			await teclas([KEY_D], 1.0)
			await girar(-300, 0, 0.6)
			await teclas([KEY_W], 1.0)
			await tecla(KEY_1)
			await esperar(2.0)
			foto("online_de_pie")
			# esperar a que el amigo también esté de pie (los dos a la vez)
			await hasta(func(): return m.view.pie.remote.has(2) and m.view.pie.remote[2].st == 2, 12.0)
			foto("online_dos_de_pie")
			# manotazos: acercarse al amigo y darle dos seguidos (el segundo tumba)
			if m.view.pie.remote.has(2) and m.view.pie.remote[2].st == 2:
				await esperar(1.0)
				for golpe in 2:
					var otro: Vector2 = m.view.pie.remote[2].cur
					var desde: Vector2 = otro + (m.view.pie.pos - otro).normalized() * 0.6
					m.view.pie.pos = desde
					var dd: Vector2 = otro - desde
					m.view.pie.yaw = atan2(-dd.x, -dd.y)
					m.view.pie.pitch = -0.2
					await esperar(0.4)
					marca("online: manotazo %d (objetivo %d)" % [golpe + 1, m._golpe_target()])
					if golpe == 1:
						m.view.pie.vel = Vector2(-sin(m.view.pie.yaw), -cos(m.view.pie.yaw)) * 2.0   # con carrerilla: tumba
					_boton_raton(Vector2(320, 180), true)
					await m.get_tree().process_frame
					_boton_raton(Vector2(320, 180), false)
					await esperar(3.5)
				foto("online_golpe")
				await esperar(1.0)
			m.view.pie.pos = m.view.pie.SEAT_SPOT
			await tecla(KEY_SPACE)
			if not await hasta(func(): return not m.view.pie.standing(), 12.0):
				hallazgo("no_se_sienta_online", "El anfitrión no pudo sentarse con otro de pie (modo %s)" % m.view.pie.mode)
		# lo que hace el otro con sus fichas (OP_MANO): se ve su mano con la ficha
		for k in [1, 2, 3]:
			var ch = m.view.heads[k]
			if ch != null and ch.fiddle >= 2 and not _vio_mano.has(k):
				_vio_mano[k] = true
				var quien := "persona" if k < m.online_v.get("seats", []).size() and not m.online_v.seats[k].get("bot", true) else "bot"
				marca("online: la silla %d (%s) juguetea con una ficha (estado %d)" % [k, quien, ch.fiddle])
				foto("online_jugueteo_%d" % k)
		# diagnóstico: la silla del anfitrión (silla 2 para el amigo) mientras camina
		if not anfitrion and m.view.pie.remote.has(2) and m.view.pie.remote[2].st != 0 and frame % 30 == 0:
			var chh = m.view.heads[2]
			if chh != null and chh.chair != null:
				marca("silla anfitrión: top %s silla %s cuerpo %s stand_k %.2f st %d" % [chh.chair.top_level, chh.chair.global_position, chh.global_position, chh.stand_k, m.view.pie.remote[2].st])
		# el amigo también se para cuando ve al anfitrión de pie, y luego vuelve a sentarse
		if not anfitrion and not _amigo_parado and g.phase == "play" and m.stand_btn.visible 				and m.view.pie.remote.has(2) and m.view.pie.remote[2].st != 0:
			_amigo_parado = true
			marca("online: el amigo también se para (dos de pie)")
			await pulsar_nodo(m.stand_btn)
			await hasta(func(): return m.view.pie.mode == "de_pie", 6.0)
			await teclas([KEY_W], 0.8)
			await girar(300, 40, 0.5)
			# esperar quieto (el anfitrión viene a darle); apuntar si cae al suelo
			var t_caer := 0.0
			var vio_caer := false
			while t_caer < 16.0 and not (vio_caer and not m.view.pie.caido()):
				if m.view.pie.caido() and not vio_caer:
					vio_caer = true
					marca("online: el amigo cae al suelo por el manotazo")
					foto("online_amigo_en_el_suelo")
				await esperar(0.2)
				t_caer += 0.2
			foto("online_amigo_de_pie")
			m.view.pie.pos = m.view.pie.SEAT_SPOT + Vector2(0.15, 0.1)
			await tecla(KEY_SPACE)
			if not await hasta(func(): return not m.view.pie.standing(), 12.0):
				hallazgo("no_se_sienta_online", "El amigo no pudo sentarse con otro de pie (modo %s)" % m.view.pie.mode)
			else:
				marca("online: el amigo se sentó")
		if not anfitrion and m.cover_btn.visible and m.cover_btn.text.begins_with("TAPAR"):
			marca("online: tapar mis fichas")
			await pulsar_nodo(m.cover_btn)
			await esperar(1.0)
			foto("online_tapado")
		match g.phase:
			"pick":
				if not m._card_nodes.is_empty() and m.overlay.get_child_count() > 2 and not m._picking:
					await _elegir_aumento()
			"draw":
				if m.draw_btn.visible:
					await pulsar_nodo(m.draw_btn)
					await esperar(1.0)
			"play":
				if m.view.counting:
					await _contar()
				elif g.turn == 0 and not m.view.animating:
					await _mi_turno()
			"shop":
				if m.view.counting:
					await _contar()
				elif boton("SIGUIENTE MANO"):
					await esperar(1.0)
					foto("online_tienda")
					await pulsar("SIGUIENTE MANO")
		await m.get_tree().process_frame
	foto("online_final")


var _mostrador_online := false
var _robo_mirado := false
var _salio_y_volvio := false


## Online: salir al colmado a mitad de la mano, esperar y pulsar «VOLVER A LA
## SALA». Tiene que volver a la misma partida, en su silla, con sus fichas.
func _salir_y_volver() -> void:
	_salio_y_volvio = true
	var mano0: int = m.g.hand_no
	var fichas0: int = m.g.hands[0].size()
	marca("online: salgo a mitad de la mano %d con %d fichas" % [mano0, fichas0])
	foto("online_antes_de_salir")
	await tecla(KEY_ESCAPE)
	await esperar(0.6)
	if not await pulsar("SALIR AL COLMADO", 3.0):
		m.quit_to_menu()
	await esperar(5.0)
	foto("online_en_la_calle")
	var hay_boton: bool = await hasta(func(): return boton("VOLVER A LA SALA") != null, 15.0)
	marca("online: botón VOLVER A LA SALA %s" % hay_boton)
	if not hay_boton:
		_caso("volver_a_la_sala", false)
		return
	await pulsar("VOLVER A LA SALA", 5.0)
	var dentro: bool = await hasta(func(): return m.online and m.playing and m.g.phase in ["play", "shop", "pick", "draw", "over"], 25.0)
	await esperar(2.0)
	foto("online_de_vuelta")
	var misma: bool = dentro and m.g.hand_no >= mano0
	marca("online: de vuelta %s · fase %s · mano %d (antes %d) · fichas %d (antes %d) · de pie %s" % [dentro, m.g.phase, m.g.hand_no, mano0, m.g.hands[0].size(), fichas0, m.view.pie.mode])
	_caso("volver_a_la_sala", misma and m.view.pie.mode == "sentado")


## I3 online: cojo 3 fichas a mano y miro que en mi bandeja salgan de cara
## (el servidor manda las tuyas en «mis_robo»).
func _mirar_robo() -> void:
	_robo_mirado = true
	for k in 3:
		var libre: Array = range(28).filter(func(x): return not m.view.pool_taken.has(x))
		if libre.is_empty() or m.g.phase != "draw":
			break
		# cada cliente va a por fichas distintas (si no, los cuatro piden la misma)
		m._draw_pick(libre[(maxi(_rol_online, 0) * 5 + k) % libre.size()])
		await esperar(0.8)
	await esperar(1.0)
	foto("online_robo_de_cara")
	var de_cara := 0
	for idx in m.my_picks:
		var n = m.view.pool_nodes[idx] if idx < m.view.pool_nodes.size() else null
		if is_instance_valid(n) and n.get_meta("cara", false):
			de_cara += 1
	marca("online: fichas cogidas %d · de cara %d" % [m.my_picks.size(), de_cara])
	_caso("robo_de_cara_online", m.my_picks.size() > 0 and de_cara == m.my_picks.size())
var _rol_online := -1
var _vio_mano := {}
var _amigo_parado := false


func _campo(n: Node) -> LineEdit:
	if n is LineEdit and n.is_visible_in_tree() and n.placeholder_text in ["ABC123", "CÓDIGO"]:
		return n
	for c in n.get_children():
		var r := _campo(c)
		if r:
			return r
	return null



func _escena_online_cuatro() -> void:
	var rol := 0
	var codigo_f := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rol-recorrido="):
			rol = int(arg.trim_prefix("--rol-recorrido="))
		if arg.begins_with("--codigo-recorrido="):
			codigo_f = ProjectSettings.globalize_path(arg.trim_prefix("--codigo-recorrido="))
	if codigo_f.is_empty():
		_fallo_bot("configuracion_online", "Falta ruta de coordinación de esta sesión")
		return
	_rol_online = rol
	marca("online cuatro: rol %d host %s" % [rol, m.red._host()[0]])
	m.menus.profile.nombre = "QA recorrido %d" % rol
	var con_armas := OS.get_cmdline_user_args().has("--armas")
	if con_armas:
		m.menus.profile["balas"] = 4
		m.menus.profile["arma"] = "revolver" if rol == 0 else "pistola"   # los demás deben ver el revólver del anfitrión
	await pulsar("JUGAR")
	await esperar(5.0)
	await pulsar("Sala con amigos")
	await esperar(1.0)
	if rol == 0:
		await _opcion_sala("modo", "aumentos" if OS.get_cmdline_user_args().has("--aumentos") else "clasico")
		await _opcion_sala("armas", con_armas)
		await pulsar("CREAR")
		if not await hasta(func(): return m.online and m.red.codigo != "", 30.0):
			return
		# solo en la sala (antes de dar el código): se cambia a una silla libre al momento
		await hasta(func(): return m._lobby.has("panel") and is_instance_valid(m._lobby.panel), 15.0)
		await esperar(2.5)   # la cámara llega a la mesa
		var yo0 := int(m.online_v.get("yo", 0))
		await pulsar("Sentarme aquí")
		_caso("silla_libre_al_momento", await hasta(func(): return int(m.online_v.get("yo", 0)) != yo0, 8.0))
		await esperar(1.2)
		foto("silla_cambiada")
		# a lo loco: 8 clics seguidos en sillas libres; la cámara tiene que acabar
		# en su sitio (antes se iba al techo) y el colmado recto en una silla
		var y_base: float = m.view.camera.position.y
		for k in 8:
			for b in m._seat_btns:
				if b is Button and is_instance_valid(b) and b.visible and "Sentarme" in b.text:
					b.pressed.emit()
					break
			await esperar(0.15)
		await esperar(2.5)
		foto("silla_a_lo_loco")
		var giro: float = fposmod(m.view.room.rotation.y, PI / 2.0)
		var recto: bool = giro < 0.02 or giro > PI / 2.0 - 0.02
		var altura_ok: bool = absf(m.view.camera.position.y - y_base) < 0.01
		marca("silla a lo loco: cámara %.3f (base %.3f) · colmado recto %s" % [m.view.camera.position.y, y_base, recto])
		_caso("silla_a_lo_loco", recto and altura_ok)
		FileAccess.open(codigo_f, FileAccess.WRITE).store_string(m.red.codigo)
	else:
		if not await hasta(func(): return FileAccess.file_exists(codigo_f), 50.0):
			return
		var campo := _campo(m.get_tree().root)
		if not is_instance_valid(campo):
			_fallo_bot("codigo_sin_campo", "No se encontró entrada de código")
			return
		await clic(campo.get_global_rect().get_center())
		for ch in FileAccess.get_file_as_string(codigo_f).strip_edges():
			var ev := InputEventKey.new()
			ev.unicode = ch.unicode_at(0)
			ev.pressed = true
			m.get_viewport().push_input(ev, true)
			await m.get_tree().process_frame
		await pulsar("Entrar")
		if not await hasta(func(): return m.online, 30.0):
			return
	foto("online_sala")
	# radio compartida: el anfitrión la toca y todos pasan a la pista 2 en el mismo punto
	# (las pruebas apagan la radio: aquí se enciende la FM, con volumen mínimo)
	m.radio.set_volumen(0.01)
	m.radio.poner("fm")
	if rol == 0:
		await esperar(6.0)
		m.red.enviar(m.Red.OP_RADIO, {})
	var radio_ok: bool = await hasta(func(): return m.radio.compartida and int(m.radio._sala.pista) == 1 and m.radio.player.playing, 25.0, false)
	await esperar(1.0)
	marca("radio sala: pista %d on %s · reloj %d ms · posicion %.2f s" % [int(m.radio._sala.pista), m.radio._sala.on, Time.get_unix_time_from_system() * 1000.0, m.radio.player.get_playback_position()])
	_caso("radio_compartida", radio_ok and m.radio.player.playing)
	if rol == 0:
		if not await hasta(func(): return m.online_v.get("seats", []).filter(func(x): return not x.bot).size() == 4, 60.0):
			return
		_caso("cuatro_clientes_en_sala", true)
		for k in 3:   # sala de espera: se miran entre ellos (no todos al frente)
			await esperar(1.5)
			foto("sala_llena_%d" % k)
	else:
		await hasta(func(): return m.online_v.get("seats", []).filter(func(x): return not x.bot).size() == 4, 60.0)
	# el 1 pide la silla de enfrente; quien la tiene acepta
	if rol == 1:
		await esperar(1.0)
		m._pedir_silla(2)
	await _sala_acordar_y_listo(rol)
	if rol == 0:
		_caso("jugar_desactivado_hasta_listos", true)
		await hasta(func(): return m.online_v.get("todos_listos", false), 60.0)
		foto("sala_todos_listos")
		await pulsar("A JUGAR")
	if not await hasta(func(): return m.g.phase != "lobby", 60.0):
		return
	if not await _jugar_hasta(func(): return m.g.phase == "play" and m.stand_btn.visible, 90.0):
		return
	await tecla(KEY_1)
	await pulsar_nodo(m.stand_btn)
	await hasta(func(): return m.view.pie.mode == "de_pie", 6.0)
	await esperar(2.0 + rol * 0.3)
	foto("online_de_pie")
	await tecla(KEY_SPACE)
	if not await hasta(func(): return not m.view.pie.standing(), 10.0):
		return
	_caso("gesto_pararse_sentarse_online", true)
	if OS.get_cmdline_user_args().has("--camara"):
		await _camara_online(rol)
	if con_armas:
		await _armas_online(rol)
	if OS.get_cmdline_user_args().has("--forzar-tranque"):
		# servidor local de pruebas: el anfitrión tranca la mano y todos la juegan
		if rol == 0:
			await hasta(func(): return m.g.phase == "play" and not m.view.animating, 30.0)
			await esperar(2.0)
			marca("tranque online forzado")
			m.red.enviar(99, {})
		var hubo := await hasta(func(): return m.tranque.activo, 30.0)
		foto("tranque_online_inicio")
		if hubo:
			await esperar(3.0)
			foto("tranque_online_boca_abajo")
			await _jugar_hasta(func(): return m.tranque.st.get("etapa", "") == "fin" or (m.tranque.activo and m.tranque.st.get("entregadas", [false, false, false, false]).count(true) == 4) or not m.tranque.activo, 150.0)
			await _medir_solapes_tranque()
			await _jugar_hasta(func(): return not m.tranque.activo, 30.0)
			foto("tranque_online_fin")
		_caso("tranque_online", hubo and not m.tranque.activo)
	var final := await _jugar_hasta(func(): return m.g.phase == "over" and not m.view.counting, 500.0)
	# la cuenta final empieza 1,5 s después del golpe: contarla si toca
	await esperar(2.5)
	if m.view.counting:
		await _contar()
	# si la última mano acabó trancada, se juega el tranque antes de la libreta
	var t_tq := _reloj
	while (m.tranque.activo or (is_instance_valid(m.tranque_ui) and m.tranque_ui.is_visible_in_tree())) and _reloj - t_tq < 90.0 and not _fin:
		if m.tranque.activo:
			await _paso_tranque()
		else:
			await _atender_pendientes()
			await esperar(0.3)
	if m.view.counting:
		await _contar()
	await hasta(func(): return boton("Revancha") != null, 20.0, false)
	await esperar(1.0)
	_caso("libreta_final_online", boton("Revancha") != null)
	_caso("partida_completa_online", final)
	foto("online_final")
	m.red.salir()



# -- salidas: salir al colmado en cada momento y volver a jugar ---------------

## En cada momento de la partida sale al colmado (Esc → SALIR AL COLMADO) y
## comprueba que no queda nada colgado y que la partida nueva empieza limpia.
func _escena_salidas() -> void:
	_chivo_probado = true
	_ute_probado = true
	for momento in ["pick", "robando", "mi_turno", "de_pie", "contando", "tienda", "mostrador", "tranque"]:
		await pulsar("JUGAR")
		await esperar(3.0)   # que la pizarra termine de escribirse
		await jugar_con_bots("aumentos")
		var llegue: bool = await _ir_a_momento(momento)
		marca("salidas: momento %s · llegué %s (fase %s)" % [momento, llegue, m.g.phase])
		if not llegue:
			hallazgo("salidas_sin_llegar", "No llegué al momento «%s» (fase %s)" % [momento, m.g.phase])
			m.quit_to_menu()
			await esperar(1.5)
			continue
		foto("salida_antes_%s" % momento)
		await tecla(KEY_ESCAPE)
		await esperar(0.6)
		if not await pulsar("SALIR AL COLMADO", 3.0):
			m.quit_to_menu()
		await esperar(1.5)
		var restos := _restos_tras_salir()
		foto("salida_despues_%s" % momento)
		if restos != "":
			hallazgo("salida_con_restos", "Tras salir en «%s»: %s" % [momento, restos])
		_caso("salir_limpio_" + momento, restos == "")
		# otra partida: tiene que empezar de cero
		await pulsar("JUGAR")
		await esperar(3.0)   # que la pizarra termine de escribirse
		await jugar_con_bots("aumentos")
		var ok_nueva: bool = await hasta(func(): return m.g.phase == "pick" and m.overlay.is_visible_in_tree(), 15.0)
		var limpia: bool = ok_nueva and m.g.scores == [0, 0] and m.g.hand_no == 1 and m.view.pie.mode == "sentado"
		if not limpia:
			foto("nueva_sucia_%s" % momento)
			hallazgo("nueva_partida_sucia", "Tras salir en «%s» la partida nueva no empieza limpia: fase %s, marcador %s, mano %d, de pie %s" % [momento, m.g.phase, m.g.scores, m.g.hand_no, m.view.pie.mode])
		_caso("nueva_limpia_tras_" + momento, limpia)
		m.quit_to_menu()
		await esperar(1.5)


func _restos_tras_salir() -> String:
	var r: Array = []
	if m.playing:
		r.append("sigue jugando")
	if m.overlay.get_child_count() > 0:
		r.append("%d ventanas en la capa" % m.overlay.get_child_count())
	if is_instance_valid(m.counter_ui):
		r.append("mostrador abierto")
	if m.tranque.activo:
		r.append("tranque activo")
	if m.view.counting:
		r.append("cuenta en marcha")
	if m.view.pie.mode != "sentado":
		r.append("de pie (%s)" % m.view.pie.mode)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		r.append("ratón capturado")
	var fichas: int = m.view.hands_root.get_children().filter(func(n): return n is Node3D and n.visible and not n.is_queued_for_deletion()).size()
	if fichas > 0:
		r.append("%d fichas en la mesa" % fichas)
	if m.hud.visible:
		r.append("marcador de la partida visible")
	return ", ".join(r)


func _ir_a_momento(momento: String) -> bool:
	match momento:
		"pick":
			return await hasta(func(): return m.g.phase == "pick" and m.overlay.get_child_count() > 2, 15.0)
		"robando":
			if not await _jugar_hasta(func(): return m.g.phase == "draw" and m.view.pool_nodes.size() == 28 and not m.view.animating, 60.0):
				return false
			for k in 3:
				var libre: Array = range(28).filter(func(x): return not m.view.pool_taken.has(x))
				m._draw_pick(libre[0])
				await esperar(0.4)
			return m.g.phase == "draw"
		"mi_turno":
			return await _jugar_hasta(func(): return m.g.phase == "play" and m.g.turn == 0 and not m.busy and not m.view.animating, 120.0)
		"de_pie":
			if not await _jugar_hasta(func(): return m.g.phase == "play" and m.g.turn == 0 and not m.busy and not m.view.animating, 120.0):
				return false
			m._stand_up()
			return await hasta(func(): return m.view.pie.mode == "de_pie", 6.0)
		"contando":
			return await _jugar_hasta(func(): return m.view.counting, 300.0)
		"tienda":
			return await _jugar_hasta(func(): return m.g.phase == "shop" and not m.view.counting and m.overlay.get_child_count() > 2, 300.0)
		"mostrador":
			if not await _jugar_hasta(func(): return m.g.phase == "shop" and not m.view.counting and m.overlay.get_child_count() > 2, 300.0):
				return false
			await pulsar("IR AL MOSTRADOR")
			await hasta(func(): return m.view.pie.mode == "de_pie", 6.0)
			await caminar_hasta(m.view.counter_spot() + Vector2(0.3, 0.1))
			return await hasta(func(): return is_instance_valid(m.counter_ui), 5.0)
		"tranque":
			if not await _jugar_hasta(func(): return m.g.phase == "play" and m.g.turn == 0 and not m.busy and not m.view.animating and m.g.chain.size() >= 2, 120.0):
				return false
			m.g._end_hand(-1, Vector2i(-1, -1), false)
			if not await hasta(func(): return m.tranque.activo, 6.0):
				return false
			await esperar(2.0)
			return true
	return false
