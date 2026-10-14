extends RefCounted
## Observaciones del día de pruebas (O01–O18, «Pendientes de Colmadón.md» §0)
## convertidas en comprobaciones por fotograma. Solo mira: nunca mueve nada.
## Cada candidato debe repetirse unos fotogramas seguidos antes de reportarse
## (salvo los que son un salto de un fotograma), deja captura la primera vez y
## una línea en observaciones.jsonl. Lo que no se puede medir queda en
## cobertura_observaciones.json como «MANUAL».
const VISUAL := preload("res://scripts/auditoria_visual.gd")
const MINIMO := 10           # fotogramas seguidos para dar por bueno un candidato
const MAX_FOTOS := 16

var muestras := 0
var fotos := 0
var repetidos := {}
var emitidos := {}
var contadores := {}         # tipo -> veces reportado
var _aviso_mano := {}        # texto del aviso de resultado -> mano en que apareció
var _fichas_nuevas := {}     # id de ficha en mano -> [fotograma, posición inicial]
var _lote := []              # ids aparecidos juntos (recogida)
var _lote_frame := -1
var _pos_previas: Array = []  # fichas de tu mano el fotograma anterior (vacío: no tenías)
var _bandeja: Array = []      # dónde estaban las fichas del montón que ya cogiste (fotograma anterior)

const COBERTURA := {
	"O01": "MANUAL · snap de Windows: depende del gestor de ventanas, no del árbol del juego",
	"O02": "AUTO · código de sala visible fuera de la sala / botón «Volver a la sala»",
	"O03": "MANUAL · iconos de botones (arte)",
	"O04": "MANUAL · vitrina tapando la pizarra (composición)",
	"O05": "MANUAL · diseño de «Dominó con bots»",
	"O06": "AUTO · cámara de la sala no está en tu silla",
	"O07": "AUTO · recogida de fichas sin animación",
	"O08": "AUTO · reflejo del espejo ausente o descentrado",
	"O09": "MANUAL · sala vacía de humanos sigue existiendo (servidor; prueba en npm test)",
	"O10": "AUTO · «Esperando a que los demás elijan» sin cuántos faltan",
	"O11": "AUTO · placas NOSOTROS/ELLOS de distinto tamaño",
	"O12": "AUTO · textos solapados con el cartel ESTÁS AUSENTE",
	"O13": "AUTO · ficha de «pensar» sin la skin de fichas actual",
	"O14": "AUTO · cartel ESTÁS AUSENTE fuera de la mano en juego",
	"O15": "AUTO · fichas por contar demasiado cerca de las jugadas",
	"O16": "AUTO · fichas de los lados fuera del tablero tras la cuenta",
	"O17": "AUTO · aviso «ganó por…» sigue en la mano siguiente",
	"O18": "AUTO · ficha de la cadena girada o encima de otra",
}


func revisar(bot) -> void:
	var m = bot.m
	muestras += 1
	var actual := {}
	for a in inspeccionar(m, bot.frame):
		var clave: String = a.tipo + "|" + a.clave
		actual[clave] = int(repetidos.get(clave, 0)) + 1
		var minimo: int = int(a.get("minimo", MINIMO))
		if actual[clave] < minimo or emitidos.has(clave):
			continue
		emitidos[clave] = true
		contadores[a.tipo] = int(contadores.get(a.tipo, 0)) + 1
		a["fotograma"] = bot.frame
		a["fase"] = m.g.phase
		a["pantalla"] = m.menus.screen
		a["mano"] = m.g.hand_no
		a["estado"] = "CANDIDATO_PENDIENTE_REVISION"
		if fotos < MAX_FOTOS:
			var base := "obs_%s_%d" % [a.obs, bot.frame]
			bot.foto(base)
			fotos += 1
			a["captura"] = base + ".png"
		bot.hallazgo(a.tipo, "[%s] %s · %s" % [a.obs, a.detalle, JSON.stringify(a)], a.clave)
		var ruta: String = bot.dir + "/observaciones.jsonl"
		var f := FileAccess.open(ruta, FileAccess.READ_WRITE) if FileAccess.file_exists(ruta) else FileAccess.open(ruta, FileAccess.WRITE)
		f.seek_end()
		f.store_line(JSON.stringify(a))
		f.close()
	repetidos = actual
	if bot.frame % 60 == 0:
		FileAccess.open(bot.dir + "/cobertura_observaciones.json", FileAccess.WRITE).store_string(JSON.stringify({"muestras": muestras, "reportados": contadores, "cobertura": COBERTURA}, "\t"))


func inspeccionar(m, frame: int) -> Array:
	var alertas: Array = []
	var v = m.view
	var textos: Array = []
	VISUAL.new().recoger(m.get_tree().root, textos)
	_textos(m, textos, alertas)
	_marcador(m, alertas)
	_ausente(m, textos, alertas)
	_sala(m, alertas)
	_espejo(m, alertas)
	_pensar(v, alertas)
	_recogida(m, frame, alertas)
	_cuenta(v, alertas)
	_fichas_lados(m, alertas)
	_cadena(m, alertas)
	return alertas


static func _alerta(obs: String, tipo: String, clave: String, detalle: String, extra := {}) -> Dictionary:
	var a := {"obs": obs, "tipo": tipo, "clave": clave, "detalle": detalle}
	a.merge(extra)
	return a


static func _texto(n: Control) -> String:
	return n.text if n.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED else n.tr(n.text)


# O02, O10, O17: lo que dicen los textos visibles
func _textos(m, textos: Array, alertas: Array) -> void:
	# códigos reales: el de la sala actual y el de la última recordada
	var codigos: Array = []
	if m.red != null:
		if str(m.red.codigo) != "":
			codigos.append(str(m.red.codigo).to_upper())
		var ultima: Dictionary = m.red.ultima_sala()
		if str(ultima.get("codigo", "")) != "":
			codigos.append(str(ultima.codigo).to_upper())
	var en_sala: bool = m.g.phase == "lobby" or m.menus.screen in ["amigos", "sala"]
	var vistos_ahora := {}
	for n in textos:
		var t: String = _texto(n)
		var bajo := t.to_lower()
		# O02: un streamer enseña el código al volver («Volviendo a la sala KTJ123»)
		var junto := t.to_upper().replace(" ", "")
		if not en_sala and codigos.any(func(c): return c.length() >= 4 and c in junto):
			alertas.append(_alerta("O02", "obs_codigo_sala_expuesto", str(n.get_path()), "Código de sala visible fuera de la sala", {"texto": t, "minimo": 1}))
		if n is Button and ("volver a la sala" in bajo or "back to the room" in bajo) and n.is_visible_in_tree():
			alertas.append(_alerta("O02", "obs_boton_volver_sala", str(n.get_path()), "Botón «Volver a la sala» visible; comprobar que la sala sigue viva", {"texto": t, "en_partida": m.playing}))
		# O10: esperar a los demás sin decir cuántos faltan
		if ("esperando a que los demás" in bajo or "waiting for the others" in bajo) and not RegEx.create_from_string("\\d").search(t):
			alertas.append(_alerta("O10", "obs_espera_sin_conteo", str(n.get_path()), "Espera sin «X de 4 listos»", {"texto": t}))
		# O17: aviso de resultado que sobrevive a la mano siguiente
		if "ganó por" in bajo or "ganaron por" in bajo or " won by " in bajo:
			var k := str(n.get_instance_id())
			vistos_ahora[k] = true
			if not _aviso_mano.has(k):
				_aviso_mano[k] = m.g.hand_no
			elif m.g.hand_no > int(_aviso_mano[k]) and m.g.phase in ["play", "draw"]:
				alertas.append(_alerta("O17", "obs_aviso_resultado_persistente", k, "El aviso de resultado sigue en la mano siguiente", {"texto": t, "mano_aviso": _aviso_mano[k]}))
	for k in _aviso_mano.keys():
		if not vistos_ahora.has(k):
			_aviso_mano.erase(k)


# O11: las dos placas del marcador deben medir lo mismo
func _marcador(m, alertas: Array) -> void:
	if not is_instance_valid(m.score_us) or not is_instance_valid(m.score_them) or not m.score_us.is_visible_in_tree():
		return
	var a: Control = m.score_us.get_parent().get_parent()
	var b: Control = m.score_them.get_parent().get_parent()
	var ra := a.get_global_rect()
	var rb := b.get_global_rect()
	if absf(ra.size.x - rb.size.x) > 1.0 or absf(ra.size.y - rb.size.y) > 1.0 or absf(ra.position.y - rb.position.y) > 1.0:
		alertas.append(_alerta("O11", "obs_marcador_asimetrico", "marcador", "Placas NOSOTROS/ELLOS con distinto tamaño o altura", {"nosotros": [ra.size.x, ra.size.y], "ellos": [rb.size.x, rb.size.y]}))


# O12 y O14: el cartel ESTÁS AUSENTE
func _ausente(m, textos: Array, alertas: Array) -> void:
	var cartel: Control = m.away_banner
	if not is_instance_valid(cartel) or not cartel.is_visible_in_tree():
		return
	if not m.g.phase in ["play", "draw"]:
		alertas.append(_alerta("O14", "obs_ausente_fuera_de_mano", "fase_" + m.g.phase, "Cartel ESTÁS AUSENTE visible fuera de la mano en juego"))
	var rc := cartel.get_global_rect()
	for n in textos:
		if cartel.is_ancestor_of(n) or _texto(n).is_empty():
			continue
		var inter := VISUAL.tinta(n).intersection(rc)
		if inter.get_area() > 12:
			alertas.append(_alerta("O12", "obs_ausente_tapa_texto", str(n.get_path()), "Texto tapado por el cartel ESTÁS AUSENTE", {"texto": _texto(n), "area": inter.get_area()}))


# O06: en la sala online, la cámara ya desde tu silla
func _sala(m, alertas: Array) -> void:
	if not m.online or m.online_v.is_empty() or m.view.pie.standing():
		return
	var yo := int(m.online_v.get("yo", 0))
	if yo != m.view.room_seat:
		alertas.append(_alerta("O06", "obs_camara_otra_silla", "silla_%d" % yo, "La cámara no mira desde tu silla", {"tu_silla": yo, "camara_silla": m.view.room_seat, "fase_servidor": m.online_v.get("phase", "?")}))


var _cam_antes := Vector3.ZERO


# O08: tu personaje se ve en el probador, a la izquierda del panel y sin cortarse
func _espejo(m, alertas: Array) -> void:
	var v = m.view
	if m.menus.screen != "personaje":
		return
	if not is_instance_valid(v.mirror_char) or not v.mirror_char.is_visible_in_tree():
		alertas.append(_alerta("O08", "obs_espejo_sin_reflejo", "reflejo", "No se ve tu personaje en el probador"))
		return
	var cam: Camera3D = v.camera
	# solo con la cámara quieta (al cambiar de pestaña viaja de un plano a otro)
	var quieta := cam.global_position.distance_to(_cam_antes) < 0.005
	_cam_antes = cam.global_position
	if not quieta:
		return
	var caja: AABB = preload("res://scripts/auditoria_espacial.gd").caja_mundo(v.mirror_char)
	var centro := caja.get_center()
	if cam.is_position_behind(centro):
		return
	var ancho: float = cam.get_viewport().get_visible_rect().size.x
	var x := cam.unproject_position(centro).x / ancho
	# el panel ocupa la derecha (desde ~58 %): el personaje, en la mitad izquierda
	if x < 0.12 or x > 0.5:
		alertas.append(_alerta("O08", "obs_espejo_descentrado", "reflejo", "Tu personaje no queda en la zona libre de la izquierda", {"x_pct": snappedf(x * 100, 0.1)}))


# O13: la ficha de «pensar» debe llevar la skin de fichas puesta
func _pensar(v, alertas: Array) -> void:
	var estilo: Dictionary = v.TILE_STYLES.get(v.tile_style, {})
	if estilo.is_empty():
		return
	for s in v.heads.size():
		var ch = v.heads[s]
		if not is_instance_valid(ch) or not is_instance_valid(ch._fiddle_tile):
			continue
		for c in ch._fiddle_tile.get_children():
			if c is MeshInstance3D and c.material_override is StandardMaterial3D:
				var col: Color = c.material_override.albedo_color
				var cerca := func(x: Color) -> bool: return absf(x.r - col.r) + absf(x.g - col.g) + absf(x.b - col.b) < 0.25
				if not cerca.call(estilo.body) and not cerca.call(estilo.face):
					alertas.append(_alerta("O13", "obs_skin_ficha_pensar", "silla_%d" % s, "La ficha de pensar no tiene la skin «%s»" % v.tile_style, {"color": str(col), "esperado": str(estilo.body), "minimo": 3}))


# O07: las fichas recogidas deben viajar a la bandeja, no aparecer en su sitio
func _recogida(m, frame: int, alertas: Array) -> void:
	var v = m.view
	var vivos := {}
	for n in v.hand_nodes:
		if not is_instance_valid(n) or not n.is_visible_in_tree():
			continue
		var id: int = n.get_instance_id()
		vivos[id] = true
		if not _fichas_nuevas.has(id):
			_fichas_nuevas[id] = [frame, n.global_position]
			# recogida = aparecen con la mano vacía (de robar a jugar); si ya
			# había fichas, la mano solo se rehízo (jugó alguien, cambió el turno)
			if not _pos_previas.is_empty():
				continue
			# ya estaba en tu bandeja (la cogiste y voló allí): no es aparecer de golpe
			if _bandeja.any(func(b): return b.distance_to(n.global_position) < 0.02):
				continue
			if frame - _lote_frame > 3:
				_lote = []
			_lote.append(id)
			_lote_frame = frame
	_bandeja = []
	for i in v.pool_nodes.size():
		var pn = v.pool_nodes[i]
		if is_instance_valid(pn) and int(v.pool_taken.get(i, -1)) == 0:
			_bandeja.append(pn.global_position)
	_pos_previas = []
	for n in v.hand_nodes:
		if is_instance_valid(n) and n.is_visible_in_tree():
			_pos_previas.append(n.global_position)
	for id in _fichas_nuevas.keys():
		if not vivos.has(id):
			_fichas_nuevas.erase(id)
			_lote.erase(id)
	if _lote.size() >= 5 and frame - _lote_frame == 20:
		var quietas := 0
		for id in _lote:
			var n = instance_from_id(id)
			if n is Node3D and n.global_position.distance_to(_fichas_nuevas[id][1]) < 0.005:
				quietas += 1
		if quietas == _lote.size():
			alertas.append(_alerta("O07", "obs_recogida_instantanea", "mano_%d" % m.g.hand_no, "Las fichas aparecieron en la bandeja sin animación de recogida", {"fichas": quietas, "minimo": 1}))


# O15: en la cuenta, las jugadas apartadas de las que se cuentan
func _cuenta(v, alertas: Array) -> void:
	if not v.counting or v._count_order.is_empty():
		return
	var minimo := INF
	for t in v._chain_nodes:
		var a = v._chain_nodes[t]
		if not is_instance_valid(a):
			continue
		for i in v._count_left:
			var b = v._count_order[i][0]
			if is_instance_valid(b):
				minimo = minf(minimo, Vector2(a.position.x, a.position.z).distance_to(Vector2(b.position.x, b.position.z)))
	if minimo < v.TL * 0.9:
		alertas.append(_alerta("O15", "obs_cuenta_fichas_juntas", "cuenta", "Fichas por contar casi pegadas a las jugadas", {"distancia_m": snappedf(minimo, 0.001), "minimo_m": v.TL * 0.9}))


# O16: tras contar, las fichas de los lados deben quedar sobre el tablero
func _fichas_lados(m, alertas: Array) -> void:
	var v = m.view
	# solo tras contar: antes de la cuenta las fichas se voltean en su bandeja
	if v.counting or not m.g.phase in ["shop", "over", "pick"] or int(v.get("counted_hand")) != m.g.hand_no:
		return
	for s in [1, 3]:
		for pair in v._seat_tiles[s]:
			var n = pair[0]
			if not is_instance_valid(n) or not n.is_visible_in_tree() or pair[1].x < 0:
				continue
			var p: Vector3 = v.to_local(n.global_position)
			if maxf(absf(p.x), absf(p.z)) > v.BOARD:
				alertas.append(_alerta("O16", "obs_fichas_lado_fuera_mesa", "silla_%d" % s, "Fichas de un lado quedan fuera del tablero tras la cuenta", {"posicion": str(p)}))
				break


# O18: cadena asentada sin giros raros ni fichas montadas
func _cadena(m, alertas: Array) -> void:
	var v = m.view
	if m.g.phase != "play" or v.animating or v.counting:
		return
	var rects := []
	for t in v._chain_nodes:
		var n = v._chain_nodes[t]
		if not is_instance_valid(n) or absf(n.position.y - (v.TABLE_Y + v.TD / 2 + 0.002)) > 0.01:
			continue
		var eje := Vector2(n.basis.y.x, n.basis.y.z).normalized()
		var ang := fposmod(rad_to_deg(eje.angle()), 90.0)
		if minf(ang, 90.0 - ang) > 3.0:
			alertas.append(_alerta("O18", "obs_ficha_girada", str(t), "Ficha de la cadena girada fuera de 0/90°", {"grados": snappedf(ang, 0.1)}))
		rects.append([t, Vector2(n.position.x, n.position.z), eje])
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var a = rects[i]
			var b = rects[j]
			if _obb_solape(a[1], a[2], b[1], b[2], v.TL / 2 - 0.004, v.TW / 2 - 0.004):
				alertas.append(_alerta("O18", "obs_fichas_montadas", "%s|%s" % [a[0], b[0]], "Dos fichas de la cadena se pisan", {}))


static func _obb_solape(ca: Vector2, ea: Vector2, cb: Vector2, eb: Vector2, hl: float, hw: float) -> bool:
	var ejes := [ea, Vector2(-ea.y, ea.x), eb, Vector2(-eb.y, eb.x)]
	for e in ejes:
		var ra := hl * absf(ea.dot(e)) + hw * absf(Vector2(-ea.y, ea.x).dot(e))
		var rb := hl * absf(eb.dot(e)) + hw * absf(Vector2(-eb.y, eb.x).dot(e))
		if absf((cb - ca).dot(e)) >= ra + rb:
			return false
	return true
