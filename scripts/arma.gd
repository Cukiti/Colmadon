extends Node
## El arma (paso 2a, sin conexión): una pistola en tus piernas. La coges con la
## mira (clic o E) y te levantas con ella; clic derecho apunta, clic izquierdo
## dispara. Daño por zonas con 100 de vida: cabeza mata de un tiro, pecho 3,
## brazos y piernas 5 (se suman). Quien muere cae al suelo, su turno espera y
## a los pocos segundos se levanta y vuelve a su silla.

# el servidor usa las mismas tablas (servidor/modulo/src/sala.ts: SALA_ARMAS)
const Red := preload("res://scripts/red.gd")
const Modelo := preload("res://scripts/modelo_arma.gd")
const ARMAS := {
	"pistola": {"nombre": "Pistola", "dano": {"cabeza": 100, "pecho": 34, "brazo": 20, "pierna": 20}, "cad": 0.28},
	"revolver": {"nombre": "Revólver", "dano": {"cabeza": 100, "pecho": 50, "brazo": 25, "pierna": 25}, "cad": 0.8},
}
const PRECIO_BALA := 5      # pesos
const MAX_BALAS := 12
const NOMBRE_ZONA := {"cabeza": "la cabeza", "pecho": "el pecho", "brazo": "un brazo", "pierna": "una pierna"}
const VUELVE_EN := 8.0        # sin conexión: segundos tumbado antes de volver
const HIP := Vector3(0.2, -0.2, -0.45)
const ADS := Vector3(0.0, -0.105, -0.42)

var m
var view
var lap: Node3D          # la pistola en tus piernas (mundo del colmado)
var fp: Node3D           # tu brazo con la pistola (primera persona, vista nítida)
var _muzzle: OmniLight3D
var _fogonazo: MeshInstance3D
var armado := false
var apuntando := false
var vida := [100, 100, 100, 100]
var muerto := [false, false, false, false]
var _cd := 0.0
var _ads_k := 0.0
var _retroceso := 0.0
var _silla_pos := {}
var yo_muerto := false
var _cuerpo := Vector2.ZERO     # online: dónde caíste (coordenadas del suelo de pie)
var _muerte_ui: Control
var _vol_antes := 0.0
var _balas_enviadas := ""        # online: sala y silla a las que ya mandamos balas y arma
var _volviendo := false          # pulsaste «Volver al colmado»: el servidor aún te cree muerto
var _modelo_tipo := ""
var _lap_arma: Node3D
var _fp_arma: Node3D


func _init(main_node) -> void:
	m = main_node
	view = main_node.view


func _ready() -> void:
	lap = Node3D.new()
	view.add_child(lap)
	fp = Node3D.new()
	(view._tiles_host if view._tiles_host else view).add_child(fp)
	var skin := _mat(view.my_cfg.get("skin", Color(0.6, 0.42, 0.3)))
	var shirt := _mat(view.my_cfg.get("shirt", Color(0.12, 0.65, 0.68)))
	view._box(Vector3(0.07, 0.07, 0.24), Vector3(0.0, -0.05, 0.2), shirt, fp)
	view._box(Vector3(0.065, 0.065, 0.1), Vector3(0.0, -0.045, 0.05), skin, fp)
	_poner_modelo()
	_fogonazo = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	_fogonazo.mesh = q
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.85, 0.4)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_fogonazo.material_override = fm
	_fogonazo.position = Vector3(0, 0.03, -0.2)
	_fogonazo.visible = false
	fp.add_child(_fogonazo)
	fp.visible = false
	_muzzle = OmniLight3D.new()
	_muzzle.light_color = Color(1.0, 0.8, 0.45)
	_muzzle.omni_range = 3.0
	_muzzle.light_energy = 0.0
	view.add_child(_muzzle)


func _mat(c: Color) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new()
	mt.albedo_color = c
	mt.roughness = 0.6
	return mt


# ---------------------------------------------------------------- cada fotograma

func tick(dt: float) -> void:
	_cd = maxf(_cd - dt, 0.0)
	if arma_id() != _modelo_tipo:
		_poner_modelo()
	_retroceso = move_toward(_retroceso, 0.0, dt * 6.0)
	if _muzzle.light_energy > 0.0:
		_muzzle.light_energy = maxf(_muzzle.light_energy - dt * 60.0, 0.0)
	# al sentarte la dejas otra vez en las piernas
	if armado and view.pie.mode == "sentado":
		soltar()
	var en_mano: bool = m.playing and m.g.phase in ["play", "draw", "shop"] and (not m.online or m.online_v.get("armas", false)) and not yo_muerto
	lap.visible = en_mano and not armado and view.pie.mode == "sentado" and not view.top_view
	if lap.visible:
		# sobre tus muslos, entre tú y el borde de la mesa, de lado
		lap.global_transform = Transform3D(Basis.from_euler(Vector3(0.0, PI / 2 + 0.35, PI / 2)), Vector3(0.1, view.TABLE_Y - 0.1, 0.97))
	_ads_k = move_toward(_ads_k, 1.0 if apuntando else 0.0, dt * 7.0)
	fp.visible = armado and view.pie.standing() and view.pie.mode != "levantando"
	if fp.visible:
		var off: Vector3 = HIP.lerp(ADS, smoothstep(0.0, 1.0, _ads_k)) + Vector3(0, 0, 0.05) * _retroceso
		fp.global_transform = view.camera.global_transform * Transform3D(Basis.from_euler(Vector3(_retroceso * 0.5, 0, 0)), off)
	if is_instance_valid(view.fp_hands) and armado:
		view.fp_hands.visible = false
	if m.online:
		_tick_online(dt)


## ¿La mira está sobre la pistola de tus piernas?
## Un vaso lleno al lado gana: tocar el vaso no debe coger la pistola (y levantarte).
func apunta_lap(p: Vector2) -> bool:
	if view.glass_at(p) >= 0 and view.glass_id(view.glass_at(p)) != "":
		return false
	return lap.visible and m.g.phase == "play" and p.distance_to(view._u(lap.global_position)) < 22.0


# ---------------------------------------------------------------- acciones

func coger() -> void:
	if armado or view.animating:
		return
	armado = true
	m.sfx.play("clack", -4.0)
	m._stand_up()
	if not view.pie.standing():
		armado = false   # no se pudo levantar ahora


func soltar() -> void:
	armado = false
	apuntando = false
	m.zoom = 1.0


func apuntar(on: bool) -> void:
	if not armado:
		return
	apuntando = on
	m.zoom = 1.6 if on else 1.0


func arma_id() -> String:
	if m.menus == null:
		return "pistola"   # aún arrancando: el perfil todavía no está cargado
	var a := str(m.menus.profile.get("arma", "pistola"))
	return a if ARMAS.has(a) else "pistola"


## Balas que te quedan (sin conexión, para practicar, no se gastan).
func balas() -> int:
	return int(m.online_v.get("balas", 0)) if m.online else 99


func disparar() -> void:
	if not armado or _cd > 0.0 or view.pie.mode != "de_pie" or yo_muerto:
		return
	if balas() <= 0:
		_cd = 0.4
		m.sfx.play("tick", -4.0)
		m._float("Sin balas · cómpralas en el espejo", Vector2(m.CX, 220), m.C_CREAM)
		return
	_cd = ARMAS[arma_id()].cad
	_retroceso = 1.0
	m.sfx.play("disparo", 0.0, 0.05)
	view.pie.pitch = clampf(view.pie.pitch + (0.02 if apuntando else 0.035), -1.3, 0.7)
	m.shake = maxf(m.shake, 1.5)
	_muzzle.global_position = view.camera.global_transform * Vector3(0.1, -0.05, -0.6)
	_muzzle.light_energy = 3.0
	_fogonazo.visible = true
	_fogonazo.rotation.z = randf() * TAU
	get_tree().create_timer(0.05).timeout.connect(func(): _fogonazo.visible = false)
	# sin apuntar, el tiro se abre un poco
	var o: Vector3 = view.camera.global_position
	var n: Vector3 = -view.camera.global_transform.basis.z
	if not apuntando:
		var b: Basis = view.camera.global_transform.basis
		n = (n + b.x * randf_range(-0.025, 0.025) + b.y * randf_range(-0.025, 0.025)).normalized()
	var hit: Dictionary = view.disparo_impacto(o, n)
	_impacto(hit.pos, hit.has("seat"))
	if m.online:
		# decide el servidor: manda el tiro y, si crees que tocaste, a quién y dónde
		var d := {"o": [snappedf(o.x, 0.01), snappedf(o.y, 0.01), snappedf(o.z, 0.01)], "n": [snappedf(n.x, 0.001), snappedf(n.y, 0.001), snappedf(n.z, 0.001)]}
		if hit.has("seat"):
			d.target = hit.seat
			d.zona = hit.zona
		m.red.enviar(Red.OP_DISPARO, d)
		m.menus.profile["balas"] = maxi(int(m.menus.profile.get("balas", 0)) - 1, 0)
		m.menus.save()
		m.online_v["balas"] = maxi(balas() - 1, 0)
	elif hit.has("seat"):
		danar(hit.seat, hit.zona)


func danar(s: int, zona: String) -> void:
	if muerto[s]:
		return
	vida[s] -= ARMAS[arma_id()].dano[zona]
	m.sfx.play("impacto", -2.0)
	var ch = view.heads[s]
	if vida[s] <= 0:
		morir(s, zona)
		return
	ch.act("stagger")
	m._float(m.tr("A %s en %s · %d") % [m.seat_names[s], m.tr(NOMBRE_ZONA[zona]), vida[s]], view.seat_screen_pos(s), Color(1, 0.6, 0.5))


func morir(s: int, zona: String) -> void:
	muerto[s] = true
	vida[s] = 0
	var ch = view.heads[s]
	_silla_pos[s] = ch.position
	ch.muerto = true
	ch.stand_k = 1.0
	# cae hacia atrás, lejos de la mesa, hasta el suelo
	var fuera: Vector3 = Vector3(ch.position.x, 0, ch.position.z).normalized()
	var tw: Tween = ch.create_tween()
	tw.tween_property(ch, "position", Vector3(fuera.x * 1.7, 0.22, fuera.z * 1.7), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	m.sfx.play("slam", -2.0)
	m._float(m.tr("¡%s cayó! (%s)") % [m.seat_names[s], m.tr(NOMBRE_ZONA[zona])], view.seat_screen_pos(s) + Vector2(0, -20), m.C_RED.lightened(0.3))
	get_tree().create_timer(VUELVE_EN).timeout.connect(revivir.bind(s))


## Se levanta del suelo y vuelve a su silla; su turno sigue donde estaba.
func revivir(s: int) -> void:
	if not muerto[s]:
		return
	var ch = view.heads[s]
	ch.muerto = false
	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(ch):
		return
	var tw: Tween = ch.create_tween()
	tw.tween_property(ch, "position", _silla_pos.get(s, ch.position), 1.2)
	tw.parallel().tween_property(ch, "stand_k", 0.0, 1.2)
	await tw.finished
	vida[s] = 100
	muerto[s] = false
	m.sfx.play("chair", -6.0)


## Nueva mano o partida: todos vivos y sentados.
func reiniciar() -> void:
	for s in 4:
		if muerto[s]:
			var ch = view.heads[s]
			if ch != null:
				ch.muerto = false
				ch.fallen_k = 0.0
				ch.rotation.x = 0.0
				ch.stand_k = 0.0
				ch.position = _silla_pos.get(s, ch.position)
		muerto[s] = false
		vida[s] = 100
	soltar()


func _impacto(at: Vector3, carne: bool) -> void:
	var c := Color(0.55, 0.08, 0.06) if carne else Color(0.75, 0.7, 0.6)
	for i in 6:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * 0.025
		b.mesh = bm
		var mt := StandardMaterial3D.new()
		mt.albedo_color = c
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		b.material_override = mt
		view.add_child(b)
		b.global_position = at
		var dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1)).normalized()
		var tw := b.create_tween()
		tw.tween_property(b, "global_position", at + dir * randf_range(0.08, 0.2), 0.35)
		tw.parallel().tween_property(mt, "albedo_color:a", 0.0, 0.35)
		tw.tween_callback(b.queue_free)


# ---------------------------------------------------------------- online

## Cada fotograma online: muertos en el suelo (los sentados caen hacia atrás) y
## los que vuelven, a su silla. Balas y arma al servidor una vez por sala.
## El arma elegida en el espejo, en tus piernas y en tu mano.
func _poner_modelo() -> void:
	_modelo_tipo = arma_id()
	for viejo in [_lap_arma, _fp_arma]:
		if is_instance_valid(viejo):
			viejo.queue_free()
	_lap_arma = Modelo.crear(_modelo_tipo)
	lap.add_child(_lap_arma)
	_lap_arma.scale = Vector3.ONE * 1.3   # que se distinga bien al mirar abajo
	_fp_arma = Modelo.crear(_modelo_tipo)
	fp.add_child(_fp_arma)


func _tick_online(dt: float) -> void:
	# por sala y por silla: si te cambias de silla, el servidor las guarda en la nueva
	var code := "%s/%d" % [m.online_v.get("code", ""), int(m.online_v.get("yo", 0))]
	if m.online_v.get("armas", false) and m.online_v.get("code", "") != "" and code != _balas_enviadas:
		_balas_enviadas = code
		m.red.enviar(Red.OP_BALAS, {"n": clampi(int(m.menus.profile.get("balas", 0)), 0, MAX_BALAS), "arma": arma_id()})
	var muertos: Array = m.online_v.get("muertos", [])
	var poses: Dictionary = view.pie.remote
	for k in [1, 2, 3]:
		var ch = view.heads[k]
		if ch == null:
			continue
		var muere: bool = k < muertos.size() and bool(muertos[k])
		ch.muerto = muere
		var de_pie: bool = poses.has(k) and int(poses[k].st) != 0
		if de_pie:
			continue   # de pie lo coloca pie._tick_remote (y cae donde está)
		if not _silla_pos.has(k):
			_silla_pos[k] = ch.position
		var fuera: Vector3 = Vector3(_silla_pos[k].x, 0, _silla_pos[k].z).normalized()
		var meta: Vector3 = Vector3(fuera.x * 1.7, 0.22, fuera.z * 1.7) if muere else _silla_pos[k]
		ch.position = ch.position.lerp(meta, minf(dt * (8.0 if muere else 3.0), 1.0))
		ch.stand_k = move_toward(ch.stand_k, 1.0 if muere else 0.0, dt * 3.0)
	# yo: muerto según el servidor (o vivo otra vez porque empezó otra mano)
	var yo := muertos.size() > 0 and bool(muertos[0])
	if not yo:
		_volviendo = false
	if yo and not yo_muerto and not _volviendo:
		muerte_propia("")
	elif not yo and yo_muerto and is_instance_valid(_muerte_ui):
		_cerrar_muerte(true)


## Aviso «disparo» del servidor: el fogonazo y el sonido de quien dispara, el
## impacto, y lo que le pasa a quien recibe el tiro.
func evento_disparo(e: Dictionary) -> void:
	var s := int(e.get("seat", -1))
	var o := _v3(e.get("o", [0, 0, 0]))
	var n := _v3(e.get("n", [0, 0, -1])).normalized()
	var t := int(e.get("target", -1))
	if s != 0:
		var d: float = view.camera.global_position.distance_to(o)
		m.sfx.play("disparo", clampf(-d * 2.5, -14.0, 0.0), 0.05)
		_muzzle.global_position = o + n * 0.5
		_muzzle.light_energy = 2.5
		if s > 0 and view.heads[s] != null:
			view.heads[s].shot_kick = 1.0
		var hit: Dictionary = view.disparo_impacto(o, n, [] if t < 0 else ([t] if t > 0 else []))
		_impacto(hit.pos, hit.has("seat"))
	if t < 0:
		return
	var zona := str(e.get("zona", ""))
	var queda := int(e.get("vida", 0))
	var nombre_z: String = m.tr(NOMBRE_ZONA.get(zona, zona))
	if t == 0:
		m.flash = maxf(m.flash, 0.8)
		m.shake = maxf(m.shake, 3.0)
		m.sfx.play("impacto", 0.0)
		if e.get("muerto", false):
			muerte_propia(m.seat_names[s] if s >= 0 and s < 4 else "")
		else:
			m._float(m.tr("¡%s te dio en %s! · %d") % [m.seat_names[s], nombre_z, queda], Vector2(m.CX, 250), m.C_RED.lightened(0.3))
		return
	m.sfx.play("impacto", -4.0)
	if e.get("muerto", false):
		m._float(m.tr("¡%s cayó! (%s)") % [m.seat_names[t], nombre_z], view.seat_screen_pos(t) + Vector2(0, -20), m.C_RED.lightened(0.3))
	elif view.heads[t] != null:
		view.heads[t].act("stagger")
		if s == 0:
			m._float(m.tr("A %s en %s · %d") % [m.seat_names[t], nombre_z, queda], view.seat_screen_pos(t), Color(1, 0.6, 0.5))


func _v3(a) -> Vector3:
	if a is Array and a.size() == 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO


## Te mataron: la vista cae con tu cuerpo, el colmado se apaga y sale
## «ESTÁS MUERTO»; luego el menú borroso para volver a mano.
func muerte_propia(quien: String) -> void:
	if yo_muerto:
		return
	yo_muerto = true
	soltar()
	_cuerpo = view.pie.pos if view.pie.standing() else Vector2(0, 1.7)
	m._capture_mouse(false)
	view.pie.drive_cam = false
	_vol_antes = AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_volume_db(0, _vol_antes - 14.0)
	m.sfx.play("latido", 6.0, 0.0)
	var cam: Camera3D = view.camera
	var desde: Transform3D = cam.global_transform
	var fwd := -desde.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3(0, 0, -1)
	var suelo := Vector3(_cuerpo.x, 0.22, _cuerpo.y)
	var hasta := Transform3D(Basis.looking_at(fwd + Vector3(0, 0.9, 0), Vector3.UP).rotated(fwd, 1.1), suelo)
	var tw := cam.create_tween()
	tw.tween_method(func(k: float): cam.global_transform = desde.interpolate_with(hasta, k), 0.0, 1.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# pantalla: borrosa y oscura, con el cartel
	_muerte_ui = Control.new()
	_muerte_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_muerte_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	m.hud.add_child(_muerte_ui)
	var borroso := ColorRect.new()
	borroso.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;
uniform float k = 0.0;
void fragment() {
	vec3 c = textureLod(pantalla, SCREEN_UV, 3.5 * k).rgb;
	float g = dot(c, vec3(0.3, 0.59, 0.11));
	COLOR = vec4(mix(c, vec3(g * 0.9, g * 0.35, g * 0.3), 0.6 * k) * (1.0 - 0.35 * k), 1.0);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	borroso.material = mat
	_muerte_ui.add_child(borroso)
	var tk := borroso.create_tween()
	tk.tween_method(func(k: float): mat.set_shader_parameter("k", k), 0.0, 1.0, 1.2)
	var titulo: Label = m._lbl("ESTÁS MUERTO", 30, m.C_RED.lightened(0.2))
	titulo.add_theme_constant_override("outline_size", 6)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.size = Vector2(m.W, 40)
	titulo.position = Vector2(0, 110)
	_muerte_ui.add_child(titulo)
	if quien != "":
		var sub: Label = m._lbl(m.tr("%s te disparó") % quien, 12, m.C_CREAM)
		sub.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.size = Vector2(m.W, 20)
		sub.position = Vector2(0, 150)
		_muerte_ui.add_child(sub)
	await get_tree().create_timer(3.0).timeout
	if not is_instance_valid(_muerte_ui):
		return
	# el menú: volver a mano (como reconectar) o salir
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 8)
	_muerte_ui.add_child(caja)
	var volver: Button = m._yellow(Button.new())
	volver.text = "Volver al colmado"
	volver.custom_minimum_size = Vector2(200, 34)
	volver.pressed.connect(_volver)
	caja.add_child(volver)
	var info: Label = m._lbl("Tu turno espera; si tardas, juega tu bot", 9, Color(m.C_CREAM, 0.7))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(info)
	var salir := Button.new()
	salir.text = "Salir al menú"
	salir.pressed.connect(func():
		_cerrar_muerte(true)
		m.quit_to_menu())
	caja.add_child(salir)
	caja.reset_size()
	caja.position = Vector2(m.CX - caja.size.x / 2, 190)


## «Volver al colmado»: apareces tumbado donde caíste, te levantas y vas a tu silla.
func _volver() -> void:
	m.red.enviar(Red.OP_REVIVIR)
	_volviendo = true
	_cerrar_muerte(false)
	var pie = view.pie
	pie.mode = "de_pie"
	pie.pos = _cuerpo
	pie.yaw = atan2(_cuerpo.x, _cuerpo.y)
	pie.pitch = -0.3
	pie.vel = Vector2.ZERO
	pie.drive_cam = true
	pie.knockdown(2.0)
	view._sig = ""
	m._capture_mouse(true)
	m._float("Vuelve a tu silla para jugar", Vector2(m.CX, 220), m.C_GOLD)


func _cerrar_muerte(sentado: bool) -> void:
	yo_muerto = false
	AudioServer.set_bus_volume_db(0, _vol_antes)
	if is_instance_valid(_muerte_ui):
		_muerte_ui.queue_free()
	_muerte_ui = null
	view.pie.drive_cam = true
	if sentado:
		view.pie.mode = "sentado"
		view.camera.global_transform = view._cam_normal
		view.seat_look = Vector2.ZERO
