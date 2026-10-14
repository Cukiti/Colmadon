extends Node
## Tranque con suspenso (2026-10-10): todos miran la mesa desde arriba con las
## fichas boca abajo; por turnos, empezando por quien trancó, cada uno gira las
## suyas y su contador sube. La suma de cada pareja no se ve hasta la última
## ficha (que se gira a cámara lenta). Luego VISTO con el ganador y, en la
## cuenta, los demás entregan sus fichas o el ganador se las arrebata.
## Online lo lleva el servidor (vista «tranque» y avisos revela/amago/entrega/
## arrebata); sin conexión, este mismo archivo hace de servidor (_sim_*).

const T_INTRO := 2.5
const T_TURNO := 8.0
const T_AUTO := 0.9
const T_BOT := 1.1
const T_ENTRE := 2.5   # reglamento: pausas de 2-3 s entre pasos
const T_VISTO := 30.0
const T_ENTREGAR := 10.0

var m   # main.gd
var activo := false
var st: Dictionary = {}        # etapa, turno, orden, rev, secs, entregadas, ganador (sillas locales)
var _etapa_vista := ""
var ui: Control = null
var _contadores: Array = [null, null, null, null]
var _mostrado: Array = [0, 0, 0, 0]   # lo que enseña cada contador (sube contando)
var _parejas: Label = null
var _turno_lbl: Label = null
var _botones: Control = null
var _visto_panel: Control = null
var _monton_lbl: Label = null
var _monton_total := 0
var _latido_t := 0.0
var _session := 0

# sin conexión
var _sim := false
var _sim_auto := 0.0
var _sim_hasta := 0.0
var _sim_t := 0.0
var _sim_ok := false
var _sim_amago := false
var _sim_fin_en := 0.0   # tras la última ficha, pausa antes de anunciar al ganador


func _init(main_node) -> void:
	m = main_node


func _ficha_de(s: int, i: int) -> Vector2i:
	var h: Array = m.g.hands[s]
	return h[i] if i < h.size() else Vector2i(-1, -1)


func _pips(t: Vector2i) -> int:
	return t.x + t.y if t.x >= 0 else 0


func _suma_revelada(s: int) -> int:
	var n := 0
	for i in st.get("rev", [[], [], [], []])[s]:
		n += _pips(_ficha_de(s, int(i)))
	return n


func _suma_total(s: int) -> int:
	var n := 0
	for t in m.g.hands[s]:
		n += _pips(t)
	return n


func _nombre(s: int) -> String:
	return m.tr("Tú") if s == 0 else m.seat_names[s]


# ---------------------------------------------------------------- flujo

## Se juega el tranque entero; vuelve cuando acaba (etapa «fin») o si se sale.
func jugar() -> void:
	_session = m._game_session
	activo = true
	_sim = not m.online
	_etapa_vista = ""
	st = {}
	_mostrado = [0, 0, 0, 0]
	_monton_total = 0
	# de pie no podrías tocar tus fichas (manda el control de caminar): a tu silla
	if m.view.pie.standing():
		m.view.pie.sit_down(true)
	m.view.tranque_mesa(true)
	m.view.set_top(true)
	m.sfx.play("knock", -2.0)
	m._float(["¡Se trancó el juego!", "¡Tranque! Nadie lleva…", "¡Esto se trancó!"].pick_random(), Vector2(m.CX, 70), m.C_GOLD)
	if _sim:
		_sim_empezar()
	if not m.view.tq_llega.is_connected(_ficha_llega):
		m.view.tq_llega.connect(_ficha_llega)
	_montar_ui()
	m.view_btn.visible = false   # «Ver mesa / Volver» no pinta nada aquí
	m.sfx.bucle("redoble", true, -16.0)
	while activo and _sigue():
		if not _sim:
			var v = m.online_v.get("tranque", null)
			if v is Dictionary:
				st = v
		_marcar_secs()
		if st.get("etapa", "") == "fin":
			break
		_al_cambiar_etapa()
		_actualizar_ui()
		await m.get_tree().process_frame
	# remate: que aterrice la última ficha y se vea el total antes de la tienda
	if _sigue() and is_instance_valid(_monton_lbl) and not m.autotest:
		for c in _botones.get_children():
			c.queue_free()
		await m.get_tree().create_timer(0.9).timeout
		if is_instance_valid(_monton_lbl) and _sigue():
			var gana: int = int(st.get("ganador", 0))
			_monton_lbl.text = m.tr("¡%d puntos para tu pareja!") % int(m.g.last_result.get("pts", _monton_total)) if gana % 2 == 0 				else m.tr("¡%d puntos para los rivales!") % int(m.g.last_result.get("pts", _monton_total))
			var tw := _monton_lbl.create_tween()
			tw.tween_property(_monton_lbl, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK)
			tw.tween_property(_monton_lbl, "scale", Vector2.ONE, 0.2)
			m.sfx.play("coin", -4.0, 0.0)
			await m.get_tree().create_timer(3.0).timeout   # que se vea el total antes de la tienda
	_cerrar()


func _sigue() -> bool:
	return m.playing and _session == m._game_session and m.g.phase in ["shop", "over"]


func _cerrar() -> void:
	activo = false
	m.sfx.bucle("redoble", false)
	m.marcador_tq = []
	m._refresh()   # ahora sí: el marcador suma los puntos del tranque
	if is_instance_valid(ui):
		ui.queue_free()
	ui = null
	m._refresh()


# Cuenta atrás local: el servidor manda los segundos solo al cambiar algo; entre
# mensajes se descuentan aquí para que el reloj no se quede parado (reglamento:
# toda espera con segundos enseña la cuenta atrás).
var _secs_clave := ""
var _secs_base := 0.0
var _secs_t := 0.0


func _marcar_secs() -> void:
	var clave := "%s|%s|%s" % [st.get("etapa", ""), st.get("turno", -1), st.get("secs", 0)]
	if clave != _secs_clave:
		_secs_clave = clave
		_secs_base = float(st.get("secs", 0))
		_secs_t = Time.get_ticks_msec() / 1000.0


func _secs() -> int:
	return maxi(0, ceili(_secs_base - (Time.get_ticks_msec() / 1000.0 - _secs_t)))


func _process(delta: float) -> void:
	if activo and _sim:
		_sim_tick(delta)
	if activo:
		_tick_latido(delta)
	# empezó otra mano (online el servidor puede adelantarse a la entrega de
	# fichas): el tranque se cierra ya. Si seguía «activo», la mesa del
	# tranque se quedaba puesta y en el reparto siguiente las fichas que iba
	# robando cada uno salían boca arriba delante de él hasta acabar de robar.
	if activo and m.playing and not m.g.phase in ["shop", "over"]:
		_cerrar()
	if not activo and m.view.tranque_on and not m.g.phase in ["shop", "over"]:
		m.view.tranque_mesa(false)
		m.view.set_top(false)


## Cambios de etapa: el ganador al acabar de revelar y la cuenta.
func _al_cambiar_etapa() -> void:
	var e: String = st.get("etapa", "")
	if e == _etapa_vista:
		return
	var antes := _etapa_vista
	_etapa_vista = e
	if e == "visto":
		m.sfx.bucle("redoble", false)
		_mostrar_ganador()
	elif e == "entregar":
		if is_instance_valid(_visto_panel):
			var tw := _visto_panel.create_tween()
			tw.tween_property(_visto_panel, "modulate:a", 0.0, 0.25)
			tw.tween_callback(_visto_panel.queue_free)
		_empezar_entrega()
	if antes == "" and e == "revelar":
		m.marcador_tq = _marcador_antes()
		m._refresh()


func _marcador_antes() -> Array:
	if not _sim:
		return m.g.scores.duplicate()   # online, al revelar el servidor manda el de antes: se guarda hasta el final
	var r: Dictionary = m.g.last_result
	var sc: Array = m.g.scores.duplicate()
	sc[int(r.team)] = maxi(0, sc[int(r.team)] - int(r.pts))
	return sc


# ---------------------------------------------------------------- avisos

## Avisos del tranque (online del servidor; sin conexión, de _sim_*).
func evento(e: Dictionary) -> void:
	if not activo:
		return
	var k: String = e.get("k", "")
	var s := int(e.get("seat", 0))
	match k:
		"revela":
			var i := int(e.get("idx", 0))
			var ultima: bool = e.get("ultima", false)
			if ultima:
				_sim_fin_en = _sim_t + 3.0
			var tile = e.get("tile", null)
			var t: Vector2i = Vector2i(int(tile[0]), int(tile[1])) if tile is Array else (tile if tile is Vector2i else _ficha_de(s, i))
			if _sim:
				st.rev[s].append(i)
			m.view.tranque_girar(s, i, ultima)
			if ultima:
				m.view.tranque_acercar(s, i)
				m.sfx.bucle("redoble", false)
			var espera := 1.7 if ultima else 0.35
			var sess := _session
			m.get_tree().create_timer(espera).timeout.connect(func():
				if sess != _session or not activo:
					return
				_sumar(s, _pips(t))
				_reaccion(s, _pips(t)))
		"amago":
			m.view.tranque_amago(s, int(e.get("idx", 0)))
			m._float(m.tr("¡Amago!"), m.view.tray_screen_pos(s) + Vector2(0, -24), m.C_CREAM)
			m.sfx.play("card", -8.0)
		"entrega", "arrebata":
			var quien: int = s if k == "entrega" else int(e.get("target", s))
			var gana: int = int(e.get("target", 0)) if k == "entrega" else s
			if _sim:
				st.entregadas[quien] = true
			m.view.tranque_entregar(quien, gana)
			if k == "arrebata":
				if quien == 0:
					# I9: «¡Se las quitó a Tú!» y encima de «Entrega tus fichas…»
					m._float(m.tr("¡%s te las quitó!") % _nombre(gana), Vector2(m.CX, 262), m.C_GOLD)
				else:
					m._float(m.tr("¡Se las quitó a %s!") % _nombre(quien), m.view.tray_screen_pos(quien), m.C_GOLD)
				m.sfx.play("card", -4.0)
				if gana != 0 and m.view.heads[gana] != null:
					m.view.heads[gana].act("point")
			else:
				m._float(m.tr("Entregas tus fichas") if quien == 0 else m.tr("%s entregó ✓") % _nombre(quien), m.view.tray_screen_pos(quien) + Vector2(0, 24), m.C_CREAM)   # corto: con nombres largos se pisaban
			# cada ficha suma al aterrizar en el montón (view.tq_llega)


## El contador de s sube número a número (con un tic por cada uno).
func _sumar(s: int, n: int) -> void:
	if n <= 0:
		_mostrado[s] = _mostrado[s]
		_pop(s)
		return
	var desde: int = _mostrado[s]
	var hasta: int = desde + n
	_mostrado[s] = hasta
	var lbl: Label = _contadores[s]
	if not is_instance_valid(lbl):
		return
	var tw := lbl.create_tween()
	tw.tween_method(func(x: float):
		if is_instance_valid(lbl):
			var nuevo := int(round(x))
			if lbl.text != str(nuevo):
				lbl.text = str(nuevo)
				m.sfx.play("tick", -12.0, 0.0), float(desde), float(hasta), 0.05 * n + 0.1)
	_pop(s)


func _pop(s: int) -> void:
	var lbl: Label = _contadores[s]
	if not is_instance_valid(lbl):
		return
	if lbl.text == "?":
		lbl.text = "0"
	lbl.pivot_offset = lbl.size / 2
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.3, 1.3), 0.08)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.15)


## Los personajes reaccionan: ficha gorda, se tapan la cara (y los rivales se ríen).
func _reaccion(s: int, pips: int) -> void:
	if pips >= 9:
		if s != 0 and m.view.heads[s] != null:
			m.view.heads[s].act("facepalm")
		for o in [1, 2, 3]:
			if o != s and o % 2 != s % 2 and m.view.heads[o] != null:
				m.view.heads[o].act("laugh")
	elif pips <= 2:
		if s != 0 and m.view.heads[s] != null:
			m.view.heads[s].act("thumbs")
		var socio: int = (s + 2) % 4
		if socio != 0 and m.view.heads[socio] != null:
			m.view.heads[socio].act("cheer")


## Latido cuando quedan pocas fichas por girar (la mano se decide ya).
func _tick_latido(delta: float) -> void:
	if st.get("etapa", "") != "revelar":
		return
	var quedan := 0
	for s in 4:
		quedan += m.g.hands[s].size() - st.get("rev", [[], [], [], []])[s].size()
	if quedan == 0 or quedan > 2:
		return
	_latido_t -= delta
	if _latido_t <= 0.0:
		_latido_t = 0.85 if quedan == 2 else 0.6
		m.sfx.play("latido", -4.0, 0.0)


# ---------------------------------------------------------------- pantalla

func _montar_ui() -> void:
	if is_instance_valid(ui):
		ui.queue_free()
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.hud.add_child(ui)
	m.tranque_ui = ui
	for s in 4:
		var l: Label = m._lbl("?", 18, m.C_CREAM)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.add_theme_constant_override("outline_size", 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(44, 26)
		ui.add_child(l)
		_contadores[s] = l
	# fuera de la mesa (antes, arriba en el centro, tapaban la fila de arriba):
	# las parejas a la derecha bajo los botones; el turno a la izquierda
	_parejas = m._lbl("", 12, m.C_GOLD)
	_parejas.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_parejas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_parejas.add_theme_constant_override("outline_size", 5)
	_parejas.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_parejas.position = Vector2(498, 262)   # más arriba: pegado al botón del chat
	_parejas.size = Vector2(136, 40)
	ui.add_child(_parejas)
	_turno_lbl = m._lbl("", 11, m.C_CREAM)
	_turno_lbl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_turno_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turno_lbl.add_theme_constant_override("outline_size", 5)
	_turno_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_turno_lbl.position = Vector2(6, 92)
	_turno_lbl.size = Vector2(134, 60)
	ui.add_child(_turno_lbl)
	# en columna, a la derecha y a media altura: abajo tapaban tus fichas
	_botones = VBoxContainer.new()
	_botones.alignment = BoxContainer.ALIGNMENT_CENTER
	_botones.add_theme_constant_override("separation", 6)
	_botones.position = Vector2(500, 196)
	_botones.size = Vector2(132, 92)
	ui.add_child(_botones)


func _actualizar_ui() -> void:
	if not is_instance_valid(ui):
		return
	var e: String = st.get("etapa", "")
	var nombres_eq: Array = [m._team_title(0), m._team_title(1)]
	# contadores sobre las fichas de cada uno
	for s in 4:
		var l: Label = _contadores[s]
		if not is_instance_valid(l):
			continue
		# al final de su fila de fichas (antes, encima de ellas, las tapaba)
		var at: Vector2 = m.view.tray_screen_pos(s)
		var n_f: int = m.g.hands[s].size()
		if n_f > 0 and not st.get("entregadas", [false, false, false, false])[s]:
			var p0: Vector2 = m.view.tranque_ficha_en_pantalla(s, 0)
			var p1: Vector2 = m.view.tranque_ficha_en_pantalla(s, n_f - 1)
			var dir: Vector2 = (p1 - p0).normalized() if p1.distance_to(p0) > 1.0 else Vector2.RIGHT
			at = p1 + dir * 26.0
		l.size = l.get_combined_minimum_size()
		l.position = (at - l.size / 2).clamp(Vector2(4, 44), Vector2(636, 330) - l.size)
		# en la cuenta, el del ganador y el de quien ya entregó sobran (manda el montón)
		l.visible = not (e == "entregar" and (s == int(st.get("ganador", -1)) or st.get("entregadas", [false, false, false, false])[s]))
		var es_turno: bool = e == "revelar" and int(st.get("turno", -1)) == s
		var col: Color = m.C_GOLD if es_turno else m.C_CREAM
		if e != "revelar" and int(st.get("ganador", -1)) >= 0:
			col = Color(0.4, 0.95, 0.45) if s % 2 == int(st.ganador) % 2 else Color(1.0, 0.45, 0.4)
		l.add_theme_color_override("font_color", col)
	# suma de las parejas: oculta hasta la última ficha
	if e == "revelar":
		_parejas.text = "%s ??\n%s ??" % nombres_eq
		var tu: int = int(st.get("turno", -1))
		var secs := _secs()
		if tu == 0:
			_turno_lbl.text = m.tr("¡Te toca! Gira tus fichas · %d s") % secs
			_turno_lbl.add_theme_color_override("font_color", m.C_GOLD)
		elif tu > 0:
			_turno_lbl.text = m.tr("%s gira sus fichas…") % _nombre(tu)
			_turno_lbl.add_theme_color_override("font_color", m.C_CREAM)
		else:
			_turno_lbl.text = ""
	elif e == "entregar":
		_turno_lbl.text = m.tr("quedan %d s") % _secs() if _secs() > 0 else ""
		_turno_lbl.add_theme_color_override("font_color", m.C_GOLD)
	_botones_etapa(e)


var _botones_sig := ""


## Botones según la etapa: girar/amagar en tu turno; entregar o arrebatar en la cuenta.
func _botones_etapa(e: String) -> void:
	var tu: int = int(st.get("turno", -1))
	var gana: int = int(st.get("ganador", -1))
	var ent: Array = st.get("entregadas", [false, false, false, false])
	# solo lo que cambia TUS botones: si otro entrega mientras pulsas ENTREGAR, tu
	# botón no se rehace (antes se rehacía y el clic se perdía)
	var sig := str(e, tu == 0 and _quedan(0) > 0, gana, ent if gana == 0 else ent[0])
	if sig == _botones_sig:
		return
	_botones_sig = sig
	for c in _botones.get_children():
		_botones.remove_child(c)
		c.queue_free()
	_colocar_botones.call_deferred()
	if e == "revelar" and tu == 0 and _quedan(0) > 0:
		var gira: Button = m._yellow(Button.new())
		gira.text = m.tr("GIRAR UNA")
		gira.pressed.connect(func(): _revelar_mia(_siguiente(0)))
		_botones.add_child(gira)
		var am := Button.new()
		am.text = m.tr("AMAGAR")
		am.tooltip_text = m.tr("Levantas la ficha y la vuelves a dejar: que sufran")
		am.pressed.connect(func(): _amagar_mia(_siguiente(0)))
		_botones.add_child(am)
	elif e == "entregar":
		if gana != 0 and not ent[0]:
			var dar: Button = m._yellow(Button.new())
			dar.text = m.tr("ENTREGAR")   # cabe en la columna (el largo se salía de la pantalla)
			dar.tooltip_text = m.tr("Entregas tus fichas al ganador")
			dar.pressed.connect(_entregar_mias)
			_botones.add_child(dar)
		elif gana == 0:
			for s in [1, 2, 3]:
				if not ent[s]:
					var b: Button = m._yellow(Button.new())
					b.text = m.tr("Quitar a %s") % _nombre(s)
					b.clip_text = true   # I9: con nombres largos la columna crecía y tapaba los totales
					b.custom_minimum_size = Vector2(132, 0)
					b.size_flags_horizontal = Control.SIZE_SHRINK_END
					b.tooltip_text = m.tr("O toca sus fichas en la mesa")
					b.pressed.connect(_arrebatar.bind(s))
					_botones.add_child(b)
		else:
			var l: Label = m._lbl(m.tr("%s recoge las fichas…") % _nombre(gana), 11, m.C_CREAM)
			_botones.add_child(l)


## I9: la columna de botones termina siempre encima de los totales de las parejas.
func _colocar_botones() -> void:
	if not is_instance_valid(_botones):
		return
	_botones.size = Vector2(132, 0)
	_botones.size = _botones.get_combined_minimum_size().max(Vector2(132, 0))
	_botones.position = Vector2(634 - _botones.size.x, _parejas.position.y - 6 - _botones.size.y)


func _quedan(s: int) -> int:
	return m.g.hands[s].size() - st.get("rev", [[], [], [], []])[s].size()


func _siguiente(s: int) -> int:
	var rev: Array = st.get("rev", [[], [], [], []])[s]
	for i in m.g.hands[s].size():
		if not rev.has(i) and not rev.has(float(i)):
			return i
	return -1


## Clic en la mesa del tranque: tu ficha (girar) o, si ganaste, las de otro (arrebatar).
func clic(p: Vector2, derecho := false) -> bool:
	if not activo:
		return false
	var e: String = st.get("etapa", "")
	if e == "revelar" and int(st.get("turno", -1)) == 0:
		var mejor := -1
		var bd := 22.0
		for i in m.g.hands[0].size():
			var d: float = m.view.tranque_ficha_en_pantalla(0, i).distance_to(p)
			if d < bd and _siguiente_valida(i):
				bd = d
				mejor = i
		if mejor >= 0:
			if derecho:
				_amagar_mia(mejor)
			else:
				_revelar_mia(mejor)
			return true
	if e == "entregar" and int(st.get("ganador", -1)) == 0:
		for s in [1, 2, 3]:
			if st.entregadas[s]:
				continue
			for i in m.g.hands[s].size():
				if m.view.tranque_ficha_en_pantalla(s, i).distance_to(p) < 22.0:
					_arrebatar(s)
					return true
	return false


func _siguiente_valida(i: int) -> bool:
	var rev: Array = st.get("rev", [[], [], [], []])[0]
	return not rev.has(i) and not rev.has(float(i))


func _revelar_mia(i: int) -> void:
	if i < 0:
		return
	if _sim:
		if not _siguiente_valida(i) or int(st.turno) != 0:
			return
		_sim_hasta = _sim_t + T_TURNO
		_sim_auto = _sim_t + 0.35
		evento({"k": "revela", "seat": 0, "idx": i, "tile": _ficha_de(0, i), "ultima": _sim_es_ultima(0)})
	else:
		m.red.enviar(m.Red.OP_REVELAR, {"idx": i})


func _amagar_mia(i: int) -> void:
	if i < 0:
		return
	if _sim:
		_sim_hasta = _sim_t + T_TURNO
		evento({"k": "amago", "seat": 0, "idx": i})
	else:
		m.red.enviar(m.Red.OP_AMAGO, {"idx": i})


func _entregar_mias() -> void:
	if _sim:
		evento({"k": "entrega", "seat": 0, "target": int(st.ganador)})
	else:
		m.red.enviar(m.Red.OP_ENTREGAR)
	m.sfx.play("card", -6.0)


func _arrebatar(s: int) -> void:
	if _sim:
		if not st.entregadas[s]:
			evento({"k": "arrebata", "seat": 0, "target": s})
	else:
		m.red.enviar(m.Red.OP_ARREBATAR, {"seat": s})


## Se acabó de revelar: suma de las parejas que sube, ganador y VISTO.
func _mostrar_ganador() -> void:
	var r: Dictionary = m.g.last_result
	var gana: int = int(st.get("ganador", -1))
	var eq_gana: int = gana % 2 if gana >= 0 else int(r.get("team", 0))
	var us := eq_gana == 0
	var sumas := [_suma_total(0) + _suma_total(2), _suma_total(1) + _suma_total(3)]
	var nombres_eq: Array = [m._team_title(0), m._team_title(1)]
	_turno_lbl.text = ""
	# las parejas, contando hacia arriba a la vez
	var tw := _parejas.create_tween()
	tw.tween_method(func(x: float):
		if is_instance_valid(_parejas):
			_parejas.text = "%s %d\n%s %d" % [nombres_eq[0], int(round(sumas[0] * x)), nombres_eq[1], int(round(sumas[1] * x))], 0.0, 1.0, 1.2)
	m.sfx.play("win" if us else "lose", -4.0, 0.0)
	# el marcador no cambia hasta que acaba el tranque (lo pidió el usuario): se suma en _cerrar
	m._show_big_banner()
	for s in [1, 2, 3]:
		if m.view.heads[s] != null:
			m.view.heads[s].act("cheer" if s % 2 == eq_gana else "facepalm")
	# panel del VISTO: quién gana y quién lo ha visto ya
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", m._box_style(Color(0.12, 0.07, 0.04, 0.94), m.C_GOLD, 3, 4, 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	var t1: Label = m._lbl(m.tr("TRANQUE · gana la pareja que suma MENOS"), 10, m.C_GOLD)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t1.custom_minimum_size = Vector2(230, 0)   # estrecho: no llega a tu fila de fichas
	v.add_child(t1)
	var win_txt := ""
	var tq: Dictionary = r.get("tranque", {})
	if tq.get("tie", false):
		win_txt = m.tr("Empate a %d: gana la pareja que salió") % sumas[0]
		if r.get("bonus", []).has("Tranque seguro"):
			win_txt = m.tr("Empate a %d: ¡Tranque seguro!") % sumas[0]
	else:
		win_txt = m.tr("¡Gana tu pareja!") if us else m.tr("Ganan los rivales")
	var wl: Label = m._lbl("✓ " + win_txt, 13, (Color(0.4, 0.95, 0.45) if us else Color(1.0, 0.45, 0.4)))
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wl.custom_minimum_size = Vector2(230, 0)
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(wl)
	var pts: Label = m._lbl(m.tr("%s recoge %d puntos") % [_nombre(gana), int(r.get("pts", 0))], 9, m.C_CREAM)
	pts.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(pts)
	var vistos: Label = m._lbl("", 9, m.C_CREAM)
	vistos.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	vistos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(vistos)
	var ok: Button = m._yellow(Button.new())
	ok.text = m.tr("VISTO")
	ok.pressed.connect(func():
		ok.disabled = true
		m.sfx.play("clack", -6.0)
		if _sim:
			_sim_ok = true
		else:
			m.red.enviar(m.Red.OP_TRANQUE_OK))
	v.add_child(ok)
	ui.add_child(p)
	p.reset_size()
	# esquina de abajo a la izquierda: es la zona sin fichas (en el centro tapaba
	# la fila de la izquierda y las jugadas)
	p.position = Vector2(6, 354 - p.size.y)
	p.pivot_offset = p.size / 2
	p.scale = Vector2(0.7, 0.7)
	p.modulate.a = 0.0
	var tp := p.create_tween().set_parallel()
	tp.tween_property(p, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(1.3)
	tp.tween_property(p, "modulate:a", 1.0, 0.2).set_delay(1.3)
	_visto_panel = p
	# los vistos se actualizan solos
	var sess := _session
	var refrescar := func():
		while is_instance_valid(vistos) and activo and sess == _session and st.get("etapa", "") == "visto":
			var oks: Array = m.online_v.get("tranque_ok", []) if not _sim else [_sim_ok, true, true, true]
			var n := 0
			var marcas := ""
			for k in mini(4, oks.size()):
				if oks[k]:
					n += 1
				marcas += ("✓" if oks[k] else "·")
			vistos.text = m.tr("Vistos %d de 4  %s  · %d s") % [n, marcas, _secs()]
			await m.get_tree().process_frame
	refrescar.call()


## La cuenta del tranque: el montón del ganador sube con cada mano que llega.
func _empezar_entrega() -> void:
	var gana: int = int(st.get("ganador", 0))
	# la línea jugada se aparta a la mitad lejana: el montón del ganador va en la suya
	m.view.tranque_recoger_linea(gana)
	_monton_total = _suma_total(gana)
	_monton_lbl = m._lbl("", 11, m.C_GOLD)   # más discreto: a 16 tapaba al ganador
	_monton_lbl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_monton_lbl.add_theme_constant_override("outline_size", 6)
	_monton_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_monton_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_monton_lbl.position = Vector2(6, 160)
	_monton_lbl.size = Vector2(134, 60)
	_monton_lbl.pivot_offset = Vector2(67, 30)
	ui.add_child(_monton_lbl)
	_monton_lbl.text = _texto_monton(gana, _monton_total)
	if gana == 0:
		m._float(m.tr("¡Recoge las fichas! Toca las de cada uno"), Vector2(m.CX, 300), m.C_GOLD)
	else:
		m._float(m.tr("Entrega tus fichas a %s") % _nombre(gana), Vector2(m.CX, 300), m.C_CREAM)


func _texto_monton(gana: int, n: int) -> String:
	return m.tr("Cuentas: %d") % n if gana == 0 else m.tr("%s cuenta: %d") % [_nombre(gana), n]


## Una ficha aterriza en el montón del ganador: «+n» encima y el total sube.
func _ficha_llega(pips: int, en: Vector2) -> void:
	if not activo:
		return
	m._float("+%d" % pips, en + Vector2(0, -8), m.C_GOLD)
	m.sfx.play("tick", -8.0, 0.0)
	_sumar_monton(pips)


func _sumar_monton(n: int) -> void:
	if not is_instance_valid(_monton_lbl):
		return
	var gana: int = int(st.get("ganador", 0))
	var desde := _monton_total
	_monton_total += n
	var lbl := _monton_lbl
	var tw := lbl.create_tween()
	tw.tween_method(func(x: float):
		if is_instance_valid(lbl):
			lbl.text = _texto_monton(gana, int(round(x))), float(desde), float(_monton_total), 0.12)
	tw.parallel().tween_property(lbl, "scale", Vector2(1.15, 1.15), 0.08)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.12)



# ---------------------------------------------------------------- sin conexión (hace de servidor)

func _sim_empezar() -> void:
	var g = m.g
	var orden := []
	for k in 4:
		orden.append((g.last_seat + k) % 4)
	st = {"etapa": "revelar", "orden": orden, "i": 0, "turno": orden[0], "rev": [[], [], [], []], "secs": int(T_INTRO + T_TURNO),
		"entregadas": [false, false, false, false], "ganador": -1}
	_sim_t = 0.0
	_sim_auto = T_INTRO
	_sim_hasta = T_INTRO + T_TURNO
	_sim_ok = false
	_sim_amago = false


func _sim_es_ultima(s_actual: int) -> bool:
	var quedan := 0
	for s in 4:
		quedan += _quedan(s)
	return quedan == 1


func _sim_rapido() -> bool:
	return m.autotest


func _sim_tick(delta: float) -> void:
	_sim_t += delta * (8.0 if _sim_rapido() else 1.0)
	var e: String = st.get("etapa", "")
	st.secs = maxi(0, ceili(_sim_hasta - _sim_t))
	if e == "revelar":
		st.turno = st.orden[mini(int(st.i), 3)]
		if _sim_t < _sim_auto:
			return
		var s: int = st.turno
		if _quedan(s) <= 0:
			if int(st.i) >= 3 and _sim_t < _sim_fin_en:
				return   # aún se está girando la última (cámara lenta)
			st.i = int(st.i) + 1
			if int(st.i) >= 4:
				st.etapa = "visto"
				st.ganador = int(m.g.last_result.seat)
				st.turno = -1
				_sim_hasta = _sim_t + T_VISTO
			else:
				_sim_auto = _sim_t + T_ENTRE
				_sim_hasta = _sim_auto + T_TURNO
			return
		var automatico: bool = s != 0 or _sim_rapido()
		if automatico:
			if s != 0 and randf() < 0.25 and not _sim_amago:
				_sim_amago = true
				evento({"k": "amago", "seat": s, "idx": _siguiente(s)})
				_sim_auto = _sim_t + T_BOT
				return
			_sim_amago = false
			var i := _siguiente(s)
			evento({"k": "revela", "seat": s, "idx": i, "tile": _ficha_de(s, i), "ultima": _sim_es_ultima(s)})
			_sim_auto = _sim_t + T_BOT
		elif _sim_t >= _sim_hasta:
			var i2 := _siguiente(0)
			evento({"k": "revela", "seat": 0, "idx": i2, "tile": _ficha_de(0, i2), "ultima": _sim_es_ultima(0)})
			_sim_auto = _sim_t + T_AUTO
	elif e == "visto":
		if _sim_ok or _sim_t >= _sim_hasta or _sim_rapido():
			st.etapa = "entregar"
			st.entregadas[int(st.ganador)] = true
			_sim_hasta = _sim_t + T_ENTREGAR
			_sim_auto = _sim_t + T_BOT
	elif e == "entregar":
		var quedan := false
		for s in 4:
			if not st.entregadas[s]:
				quedan = true
		if not quedan:
			st.etapa = "fin"
			return
		if _sim_t < _sim_auto:
			return
		var gana: int = int(st.ganador)
		var tarde: bool = _sim_t >= _sim_hasta or _sim_rapido()
		if tarde:
			# se acabó el tiempo: el ganador se queda con todas las que falten a la vez
			for s in st.orden:
				if not st.entregadas[s]:
					evento({"k": "arrebata", "seat": gana, "target": s})
			return
		for s in st.orden:
			if st.entregadas[s]:
				continue
			if gana == 0:
				if not tarde:
					return   # ganaste tú: se las quitas tú (o se te acaba el tiempo)
				evento({"k": "arrebata", "seat": 0, "target": s})
			elif s == 0:
				if not tarde:
					continue   # te toca entregar a ti
				evento({"k": "arrebata", "seat": gana, "target": 0})
			else:
				evento({"k": "entrega", "seat": s, "target": gana})
			_sim_auto = _sim_t + (T_AUTO if tarde else T_BOT)
			return
