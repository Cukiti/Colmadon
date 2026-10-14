extends Node
## De pie en el colmado: levantarse de la silla con tus fichas escondidas,
## caminar con choques (mesa, mostrador, paredes, gente), empujar, hacer
## emotes, mirar las fichas de quien no las tapó y volver a sentarse.
## También mueve a los demás jugadores que se paran (online).
##
## Coordenadas: suelo XZ de la vista 3D; tu silla está en +Z (asiento 0).

signal stood_up                  # terminaste de levantarte (los demás ya pueden ver que estás de pie)
signal sat_down                  # volviste a tu silla
signal bumped(seat: int)         # chocaste con alguien sentado (silla) o de pie
signal pose_changed              # online: hay que mandar tu posición
signal chair_move(out: bool)     # tu silla se aparta (true) o vuelve a la mesa (false)
signal step                      # un paso (sonido)
signal table_bump(strength: float)   # chocaste con la mesa con fuerza (tiemblan vasos y bombilla)

const EYE := 1.75                # tus ojos de pie: por encima de las cabezas de quien está sentado
const RADIUS := 0.22             # tu cuerpo
const SPEED := 1.7
const RUN := 2.7                 # corriendo (Mayúsculas)
const RISE_TIME := 2.4           # levantarse dura unos segundos: da tiempo a tapar fichas
const SIT_TIME := 1.1
const SEAT_SPOT := Vector2(0.34, 1.4)   # donde te quedas tras apartar la silla y salir por un lado
const SIT_RANGE := 0.75                  # a esta distancia de tu silla ya puedes sentarte
const ROOM := Rect2(-2.9, -2.1, 5.8, 4.35)
# obstáculos fijos (rectángulos en el suelo)
const BOXES := [
	Rect2(-0.92, -0.92, 1.84, 1.84),     # mesa
	Rect2(0.18, -1.84, 1.36, 0.5),       # mostrador
	Rect2(-0.98, -2.03, 0.26, 0.26),     # abanico (FAN_POS de view3d.gd)
]

var view
var mode := "sentado"            # sentado, levantando, de_pie, caminando_a_silla, sentando
var pos := Vector2(0, 1.42)
var vel := Vector2.ZERO
var yaw := 0.0                   # 0 = mirando a la mesa (-Z)
var pitch := -0.45
var _t := 0.0
var _bob := 0.0
var _from: Transform3D
var _push_cool := 0.0
var emote_bob := ""
var _step_ph := 0.0          # fase de los pasos (balanceo y sonido)
var _last_step := 0
var _roll := 0.0
var _path: Array = []         # camino de vuelta a la silla (puntos del suelo)
const CELL := 0.06
var _emote_t := 0.0
var _walk_t := 0.0
var _caido_secs := 3.0
const CAIDA := 0.35          # lo que tarda en caer (y en levantarse del suelo, el doble)           # tiempo andando hacia tu silla (si se atasca, te sientas igual)
# otros jugadores de pie: silla -> {target: Vector2, yaw, st, k}
var remote := {}
var _sentar_luego := false   # orden de sentarse que llegó estando caído o levantándote
var ultimo_regreso := 0.0   # segundos que tardó la última vuelta a la silla (pruebas)
var atascos := 0            # vueltas que se rindieron a los 7 s (pruebas)
var _medir_saltos := OS.get_cmdline_user_args().has("--recorrido")
# el colmado gira según tu silla (online): sus paredes y muebles también.
# giro = cuartos de vuelta (como salaGirar del servidor: (x, z) → (z, −x))
var giro := 0:
	set(v):
		giro = v
		room_r = _rot_rect(ROOM, v)
		boxes = BOXES.map(func(r): return _rot_rect(r, v))
var room_r: Rect2 = ROOM
var boxes: Array = BOXES.duplicate()
var drive_cam := true
var running := false
var _table_cool := 0.0         # Mayúsculas: corres        # false con los ajustes abiertos: la cámara es de los menús


func _init(v) -> void:
	view = v


static func rot_point(p: Vector2, k: int) -> Vector2:
	for i in posmod(k, 4):
		p = Vector2(p.y, -p.x)
	return p


static func _rot_rect(r: Rect2, k: int) -> Rect2:
	var a := rot_point(r.position, k)
	var b := rot_point(r.end, k)
	return Rect2(a, Vector2.ZERO).expand(b)


func standing() -> bool:
	return mode != "sentado"


func walking() -> bool:
	return mode == "de_pie" or mode == "caminando_a_silla"


## Te tumbaron (manotazo online): al suelo unos segundos, mirando al techo,
## y luego te levantas solo. Mientras, no puedes andar.
func knockdown(secs: float) -> void:
	if mode != "de_pie" and mode != "caminando_a_silla":
		return
	mode = "caido"
	_t = 0.0
	_caido_secs = secs
	_from = view.camera.global_transform
	vel = Vector2.ZERO
	view.sfx.emit("knock")


func caido() -> bool:
	return mode == "caido"


## Te levantas: la cámara se echa atrás y sube despacio.
func stand_up() -> void:
	if mode != "sentado":
		return
	mode = "levantando"
	_t = 0.0
	_from = view.camera.global_transform
	pos = SEAT_SPOT
	yaw = 0.0
	pitch = -0.45
	vel = Vector2.ZERO
	view.sfx.emit("chair")
	chair_move.emit(true)


func near_seat() -> bool:
	if pos.distance_to(SEAT_SPOT) < SIT_RANGE:
		return true
	# pegado a tu silla por el otro lado (su choque te deja a 0,42 m de ella y
	# lejos del sitio por donde entras): también puedes sentarte
	var c: Vector3 = view.my_chair.global_position
	return view.my_chair.visible and pos.distance_to(Vector2(c.x, c.z)) < SIT_RANGE


## Vuelves a tu silla. Normalmente solo si estás cerca; force (se acabó la
## mano, pausa) te lleva caminando solo, rodeando la mesa.
func sit_down(force := false) -> void:
	# en el suelo o aún levantándote: la orden no se pierde (el colmadero te
	# manda a tu silla justo tras el tercer manotazo, cuando estás caído)
	if force and mode in ["caido", "levantando"]:
		_sentar_luego = true
		return
	if mode == "de_pie" and (force or near_seat()):
		_sentar_luego = false
		mode = "caminando_a_silla"
		_walk_t = 0.0
		_path = find_path(pos, SEAT_SPOT, true)


func emote(kind: String) -> void:
	emote_bob = kind
	_emote_t = 0.0


func update(dt: float, move: Vector2, look: Vector2) -> void:
	_t += dt
	_push_cool = max(_push_cool - dt, 0.0)
	_table_cool = max(_table_cool - dt, 0.0)
	_tick_remote(dt)
	match mode:
		"sentado":
			_tick_emote(dt)   # los gestos sentado también se acaban (si no, «bailabas» para siempre)
			return
		"levantando":
			if drive_cam:
				view.camera.global_transform = _rise_transform(clamp(_t / RISE_TIME, 0.0, 1.0))
			if _t >= RISE_TIME:
				mode = "de_pie"
				stood_up.emit()
				if _sentar_luego:
					sit_down(true)
		"de_pie", "caminando_a_silla":
			if mode == "caminando_a_silla":
				move = _auto_walk_dir()
				_walk_t += dt
				if _walk_t > 7.0:
					pos = SEAT_SPOT   # atascado: a tu silla sin más
					move = Vector2.ZERO
					atascos += 1
				if move == Vector2.ZERO:
					ultimo_regreso = _walk_t
					mode = "sentando"
					_t = 0.0
					_from = view.camera.global_transform
					view.sfx.emit("chair")
					return
			else:
				yaw -= look.x * 0.006
				pitch = clamp(pitch - look.y * 0.005, -1.2, 0.6)
			_walk(dt, move)
			if drive_cam:
				view.camera.global_transform = _cam_transform(_bob)
			_tick_emote(dt)
			pose_changed.emit()
		"caido":
			# cae de espaldas (0,35 s), en el suelo con estrellitas, y se levanta (0,7 s)
			var down: float = smoothstep(0.0, CAIDA, _t) * (1.0 - smoothstep(_caido_secs - CAIDA * 2.0, _caido_secs, _t))
			var eye := Vector3(pos.x, lerp(EYE, 0.32, down), pos.y)
			var b := Basis.from_euler(Vector3(lerp(pitch, 0.9, down), yaw, lerp(0.0, 0.5, down) + sin(_t * 5.0) * 0.04 * down), EULER_ORDER_YXZ)
			if drive_cam:
				view.camera.global_transform = Transform3D(b, eye)
			pose_changed.emit()
			if _t >= _caido_secs:
				mode = "de_pie"
				if _sentar_luego:
					sit_down(true)
		"sentando":
			var u: float = clamp(_t / SIT_TIME, 0.0, 1.0)
			# al revés que al levantarse: te giras hacia la mesa, entras de lado y bajas
			if drive_cam:
				view.camera.global_transform = _from.interpolate_with(_rise_transform(1.0 - u), smoothstep(0.0, 0.25, u)) 				if u < 0.25 else _rise_transform(1.0 - u)
			if u > 0.6 and u - get_process_delta_time() / SIT_TIME <= 0.6:
				chair_move.emit(false)
			if u >= 1.0:
				mode = "sentado"
				sat_down.emit()
				pose_changed.emit()


## Levantarse (u: 0 sentado … 1 de pie), como alguien de verdad:
##   0–0,35  empujas la silla hacia atrás (te echas atrás y un poco hacia delante)
##   0,35–0,65  te giras y das un paso al lado para salir del hueco
##   0,6–1  te pones de pie del todo y vuelves a mirar la mesa
func _rise_transform(u: float) -> Transform3D:
	var seat: Transform3D = view.cams["mesa"]
	var push: float = smoothstep(0.0, 0.35, u)
	var step_out: float = smoothstep(0.35, 0.65, u)
	var up: float = smoothstep(0.55, 1.0, u)
	var turn: float = sin(clamp((u - 0.3) / 0.45, 0.0, 1.0) * PI) * 0.55   # mira hacia donde sale
	var o: Vector3 = seat.origin
	o += Vector3(0, -0.1 * push, 0.28 * push)                        # silla atrás
	o.x += SEAT_SPOT.x * step_out                                   # paso al lado
	o.z = lerp(o.z, SEAT_SPOT.y, up)
	o.y = lerp(o.y, EYE, up)
	o.y += sin(u * PI * 3.0) * 0.012 * (1.0 - u)                    # vaivén del esfuerzo
	var p_seat := -0.62
	var p: float = lerp(p_seat + 0.12 * push, pitch, up)                   # al empujar, te inclinas
	var b := Basis.from_euler(Vector3(p, -turn, sin(step_out * PI) * 0.03), EULER_ORDER_YXZ)
	# al principio (y al final de sentarse) coincide exacto con la cámara de la silla
	return seat.interpolate_with(Transform3D(b, o), smoothstep(0.0, 0.3, u))


## Cámara de pie: posición, giro y cabeceo (más el balanceo al caminar).
func _cam_transform(bob: float) -> Transform3D:
	var b := Basis.from_euler(Vector3(pitch, yaw, _roll), EULER_ORDER_YXZ)
	var eye := Vector3(pos.x, EYE + bob, pos.y)
	# al andar el cuerpo se mece un poco de lado a lado
	var sway: float = sin(_step_ph * 0.5) * 0.018 * clamp(vel.length() / SPEED, 0.0, 1.0)
	eye += Vector3(cos(yaw), 0, -sin(yaw)) * sway
	if emote_bob == "dance":
		eye.y += abs(sin(_emote_t * 9.0)) * 0.05
		b = b.rotated(b.z, sin(_emote_t * 9.0) * 0.05)
	return Transform3D(b, eye)


func _walk(dt: float, move: Vector2) -> void:
	# move: x = derecha, y = adelante (respecto a donde miras)
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	var want := (right * move.x + fwd * move.y)
	if want.length() > 1.0:
		want = want.normalized()
	want *= RUN if running and mode == "de_pie" else SPEED
	vel = vel.lerp(want, min(dt * 10.0, 1.0))
	pos += vel * dt
	_collide()
	var spd := vel.length() / SPEED
	# pasos: balanceo arriba-abajo, un poco de inclinación en las curvas y sonido de cada pisada
	_step_ph += dt * 9.5 * spd
	var n := int(_step_ph / PI)
	if n != _last_step:
		_last_step = n
		if spd > 0.25:
			step.emit()
	_roll = lerp(_roll, -move.x * 0.025 * spd, min(dt * 6.0, 1.0))
	_bob = -abs(sin(_step_ph)) * 0.04 * spd   # cada pisada baja un poco la cabeza


## Choques: paredes, mesa, mostrador y gente (sentada o de pie). A la gente se
## la empuja un poco y avisa (bumped).
func _collide() -> void:
	for it in 3:
		pos.x = clamp(pos.x, room_r.position.x + RADIUS, room_r.end.x - RADIUS)
		pos.y = clamp(pos.y, room_r.position.y + RADIUS, room_r.end.y - RADIUS)
		for r in boxes:
			var antes := pos
			pos = _out_of_box(pos, r, RADIUS)
			# la mesa es la primera caja: un choque fuerte la sacude
			if r == boxes[0] and antes != pos and it == 0 and vel.length() > 1.1 and _table_cool <= 0.0:
				_table_cool = 1.0
				table_bump.emit(vel.length())
		# volviendo a tu silla ni las sillas ni la gente te bloquean: el camino no
		# las tiene en cuenta y tu propia silla apartada tapaba el sitio donde te
		# sientas (andabas 7 s delante de ella hasta rendirte)
		if mode == "caminando_a_silla":
			continue
		# sillas vacías (de quien está de pie, y la tuya): se quedan junto a la
		# mesa; chocas con ellas pero no se empujan
		for ch_node in view.loose_chairs():
			var c2 := Vector2(ch_node.global_position.x, ch_node.global_position.z)
			var d2 := pos - c2
			if d2.length() < RADIUS + 0.2 and d2.length() > 0.0001:
				pos = c2 + d2.normalized() * (RADIUS + 0.2)
		for s in [1, 2, 3]:
			var c: Vector2 = person_pos(s)
			var rr: float = 0.3 if not remote.has(s) or remote[s].st == 0 else 0.24
			var d := pos - c
			if d.length() < RADIUS + rr and d.length() > 0.0001:
				pos = c + d.normalized() * (RADIUS + rr)
				if _push_cool <= 0.0 and vel.length() > 0.6:
					_push_cool = 1.2
					bumped.emit(s)


static func _out_of_box(p: Vector2, r: Rect2, rad: float) -> Vector2:
	var q := Vector2(clamp(p.x, r.position.x, r.end.x), clamp(p.y, r.position.y, r.end.y))
	var d := p - q
	if d.length() >= rad:
		return p
	if d.length() < 0.0001:
		# dentro: salir por el lado más cercano
		var outs := [Vector2(r.position.x - rad, p.y), Vector2(r.end.x + rad, p.y), Vector2(p.x, r.position.y - rad), Vector2(p.x, r.end.y + rad)]
		var best: Vector2 = outs[0]
		for o in outs:
			if p.distance_to(o) < p.distance_to(best):
				best = o
		return best
	return q + d.normalized() * rad


## Dónde está (en el suelo) el jugador de una silla: sentado en su silla o de pie donde ande.
func person_pos(s: int) -> Vector2:
	if remote.has(s) and remote[s].st != 0:
		return remote[s].cur
	var d: Vector3 = view._seat_dir(s)
	return Vector2(d.x, d.z) * 1.1


## Vuelta a la silla siguiendo el camino (find_path). Devuelve hacia dónde
## andar (en ejes de la cámara) o ZERO al llegar.
func _auto_walk_dir() -> Vector2:
	while not _path.is_empty() and pos.distance_to(_path[0]) < 0.12:
		_path.pop_front()
	var goal: Vector2 = _path[0] if not _path.is_empty() else SEAT_SPOT
	var to := goal - pos
	if _path.is_empty() and to.length() < 0.06:
		return Vector2.ZERO
	var dir := to.normalized()
	# mirar hacia donde camina
	var want_yaw := atan2(-dir.x, -dir.y)
	yaw = lerp_angle(yaw, want_yaw, 0.15)
	pitch = lerp(pitch, -0.35, 0.1)
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	var k: float = 1.0 if not _path.is_empty() else max(min(1.0, to.length() * 3.0), 0.35)
	return Vector2(dir.dot(right), dir.dot(fwd)) * k


## ¿Cabe tu cuerpo aquí? (paredes, mesa, mostrador, abanico, espejo y gente sentada o de pie)
func free_spot(p: Vector2, ignore_people := false) -> bool:
	var r := RADIUS + 0.01
	if p.x < room_r.position.x + r or p.x > room_r.end.x - r or p.y < room_r.position.y + r or p.y > room_r.end.y - r:
		return false
	for b in boxes:
		if b.grow(r).has_point(p):
			return false
	if ignore_people:
		return true
	for s in [1, 2, 3]:
		var rr: float = 0.3 if not remote.has(s) or remote[s].st == 0 else 0.24
		if p.distance_to(person_pos(s)) < rr + r:
			return false
	return true


## Camino más corto por una rejilla del suelo (búsqueda en anchura, 8 vecinos)
## y luego simplificado: solo los puntos donde hay que girar.
func find_path(from: Vector2, to: Vector2, ignore_people := false) -> Array:
	var w := int(room_r.size.x / CELL) + 1
	var h := int(room_r.size.y / CELL) + 1
	var cell := func(p: Vector2) -> Vector2i:
		return Vector2i(clampi(int((p.x - room_r.position.x) / CELL), 0, w - 1), clampi(int((p.y - room_r.position.y) / CELL), 0, h - 1))
	var center := func(c: Vector2i) -> Vector2:
		return room_r.position + (Vector2(c) + Vector2(0.5, 0.5)) * CELL
	var start: Vector2i = cell.call(from)
	var goal: Vector2i = cell.call(to)
	var prev := {start: start}
	var queue: Array = [start]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var found := false
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == goal:
			found = true
			break
		for d in dirs:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or prev.has(n):
				continue
			if not free_spot(center.call(n), ignore_people) and n != goal:
				continue
			prev[n] = c
			queue.append(n)
	if not found:
		return []
	var cells: Array = []
	var c2: Vector2i = goal
	while c2 != start:
		cells.push_front(c2)
		c2 = prev[c2]
	# quitar puntos intermedios en línea recta (se camina más natural)
	var pts: Array = []
	var last_dir := Vector2i.ZERO
	var at := start
	for c3 in cells:
		var d2: Vector2i = c3 - at
		if d2 != last_dir and at != start:
			pts.append(center.call(at))
		last_dir = d2
		at = c3
	pts.append(to)
	return pts


static func _crosses_table(a: Vector2, b: Vector2) -> bool:
	for k in 11:
		var p := a.lerp(b, k / 10.0)
		if abs(p.x) < 1.25 and abs(p.y) < 1.25:
			return true
	return false


func _tick_emote(dt: float) -> void:
	if emote_bob == "":
		return
	_emote_t += dt
	if _emote_t > 3.2:
		emote_bob = ""


# ---------------------------------------------------------------- otros de pie (online)

## Pose de otro jugador (ya girada para ti): st 0 sentado, 1 levantándose, 2 de pie.
func set_remote(s: int, st: int, p: Vector2, yaw_r: float, pitch_r := 0.0, en_suelo := false) -> void:
	if not remote.has(s):
		remote[s] = {"st": 0, "cur": person_pos(s), "target": p, "yaw": yaw_r, "k": 0.0, "pitch": 0.0}
	var r: Dictionary = remote[s]
	if r.st == 0 and st != 0:
		r.cur = person_pos(s)
		view.sfx.emit("chair")   # aparta la silla: también lo oyen los demás
	if r.st != 0 and st == 0:
		view.sfx.emit("chair")   # se vuelve a sentar
	# termina de levantarse: echa a andar desde donde está su cuerpo (antes
	# volvía un instante a la silla y luego se deslizaba hasta su sitio)
	if r.st == 1 and st == 2 and view.heads[s] != null:
		var hp: Vector3 = view.heads[s].position
		r.cur = Vector2(hp.x, hp.z)
	if (r.st == 0) != (st == 0):
		view._sig = ""   # sus fichas se van con él (o vuelven a su bandeja)
	r.st = st
	r.target = p
	r.yaw = yaw_r
	r.pitch = pitch_r
	r.caido = en_suelo


func _tick_remote(dt: float) -> void:
	for s in remote:
		var r: Dictionary = remote[s]
		var ch = view.heads[s]
		if ch == null:
			continue
		var seat3: Vector3 = view._seat_dir(s) * 1.02
		var goal_k := 0.0 if r.st == 0 else 1.0
		# vuelve andando a la silla: no se sienta hasta llegar a ella
		if r.st == 0 and r.has("vis") and Vector2(r.vis.x, r.vis.z).distance_to(Vector2(seat3.x, seat3.z)) > 0.5:
			goal_k = 1.0
		r.k = move_toward(r.k, goal_k, dt / (RISE_TIME if goal_k > r.k else SIT_TIME))
		ch.stand_k = r.k
		ch.hold_tiles = false   # sus fichas se quedan boca abajo en la mesa
		ch.head_pitch = r.get("pitch", 0.0) if r.st == 2 else 0.0
		var body_yaw = null
		if r.st == 2:
			var prev: Vector2 = r.cur
			r.cur = r.cur.lerp(r.target, min(dt * 8.0, 1.0))
			var mv: Vector2 = r.cur - prev
			var spd: float = mv.length() / max(dt, 0.001)
			ch.walk_amt = clamp(spd / SPEED, 0.0, 1.6)
			# cuerpo hacia donde anda; cabeza hacia donde mira (cuello hasta ±70°)
			if spd > 0.25:
				var move_yaw := atan2(-mv.x, -mv.y)
				body_yaw = r.yaw if abs(wrapf(move_yaw - r.yaw, -PI, PI)) > 1.9 else move_yaw   # marcha atrás: de frente
			elif abs(wrapf(r.yaw - ch.rotation.y, -PI, PI)) > 1.0:
				body_yaw = r.yaw   # quieto: el cuerpo solo gira si la mirada se va lejos
			else:
				body_yaw = ch.rotation.y
			ch.head_yaw = clamp(wrapf(r.yaw - ch.rotation.y, -PI, PI), -1.2, 1.2)
		else:
			ch.walk_amt = 0.0
			if r.st == 0:
				r.cur = r.cur.lerp(Vector2(seat3.x, seat3.z), min(dt * 4.0, 1.0))
		var lift: float = view.Character.STAND_LIFT * r.k
		var base := Vector3(seat3.x, view.TABLE_Y, seat3.z)
		var walk3 := Vector3(r.cur.x, view.TABLE_Y, r.cur.y)
		# levantándose: se echa atrás antes de andar
		# levantándose: se echa atrás con la silla y sale por un lado
		var dir3: Vector3 = view._seat_dir(s)
		var back: Vector3 = dir3 * 0.25 * smoothstep(0.0, 0.5, r.k) + Vector3(dir3.z, 0, -dir3.x) * 0.3 * smoothstep(0.4, 1.0, r.k)
		var goal3: Vector3 = (walk3 if r.st == 2 else base + back) + Vector3(0, lift, 0)
		# al volver a la silla (de pie → sentándose) llega andando, sin saltar
		if r.st == 2 or not r.has("vis"):
			r.vis = goal3
		else:
			# a paso de caminar (antes, a 1 m de la silla, daba saltos de 14 cm)
			var h := Vector2(r.vis.x, r.vis.z).move_toward(Vector2(goal3.x, goal3.z), SPEED * 1.3 * dt)
			r.vis = Vector3(h.x, goal3.y, h.y)
		# pruebas: un salto de más de 12 cm en un fotograma es un teletransporte
		if r.has("ultimo") and _medir_saltos and ch.position.distance_to(r.ultimo) < 1.0:
			var salto: float = Vector2(r.vis.x, r.vis.z).distance_to(Vector2(r.ultimo.x, r.ultimo.z))
			if salto > 0.12:
				print("HALLAZGO salto_remoto: silla %d st %d %.2f m en un fotograma" % [s, r.st, salto])
		if r.st != 2 and r.has("ultimo"):
			# de vuelta a la silla, andando: mueve las piernas
			var paso: float = Vector2(r.vis.x, r.vis.z).distance_to(Vector2(r.ultimo.x, r.ultimo.z)) / max(dt, 0.001)
			ch.walk_amt = clamp(paso / SPEED, 0.0, 1.2) if r.k > 0.5 else 0.0
		ch.position = r.vis
		r.ultimo = r.vis
		# en el suelo: tumbado a la altura del suelo (Character._tick_fallen lo gira)
		ch.fallen = r.get("caido", false) and r.st == 2
		if ch.fallen_k > 0.0:
			ch.position.y = lerp(ch.position.y, 0.22, smoothstep(0.0, 1.0, ch.fallen_k))
		var seat_yaw := atan2(seat3.x, seat3.z)
		ch.rotation.y = lerp_angle(ch.rotation.y, body_yaw if r.st == 2 else seat_yaw, min(dt * 6.0, 1.0))
		if r.st != 2:
			ch.head_yaw = 0.0
