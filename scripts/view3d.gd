extends Node3D
## Vista 3D de la mesa. Se renderiza a 640x360 y se amplía sin suavizado,
## así que el 3D se ve como pixel art.

const Character := preload("res://scripts/character.gd")
const Pie := preload("res://scripts/pie.gd")
var pie        # de pie en el colmado (pie.gd)
var covered := {}   # silla -> true si tiene las fichas tapadas
var my_chair: Node3D
var fp_hands: Node3D      # de pie: tus manos sujetando tus fichas (primera persona)
var _tiles_host: Node

const TABLE_Y := 0.75
const TW := 0.074  # ancho de ficha
const TL := 0.148  # largo de ficha
const TD := 0.026  # grosor
const GAP := 0.004
const BOARD := 0.66   # medio lado del tablero
const TRAY := 0.78    # distancia de las bandejas al centro
const CORNER := 0.84   # centro de los portavasos de las esquinas
const GLASS_ROW := 0.875  # fila de vasos detrás de cada bandeja
const SEG_LIMITS := [0.58, 0.5, 0.95, 0.45, 0.95]

var camera: Camera3D
var tiles_root: Node3D
var markers_root: Node3D
var shadows_root: Node3D
var mat_shadow := StandardMaterial3D.new()
var heads: Array = []
var turn_light: OmniLight3D
var hand_nodes: Array = []
var drag_slot := -1   # hueco de tu bandeja al reacomodar (F10); -1 = fuera
var other_hand_nodes: Array = []
var end_markers := {}
var accesible := false
var end_labels := {}
var end_world := {}
var animating := false
var top_view := false
var sphere: MeshInstance3D
var bulb_wire: MeshInstance3D

signal tile_landed(strength: float)
signal shuffle_started
signal sfx(name: String)

# tus manos y la interacción con la mesa
var avatar := "nena"
var arms := {}            # "l"/"r" -> {root, fore, sleeve, hand, pos}
var hover_index := -1
var drag_index := -1
var drag_point := Vector3.ZERO
var hover_side := 0
var pending_from = null   # Vector3 desde donde sale tu ficha (si la arrastraste)
var my_glasses: Array = []
var _hand_anim := {}
var _hand_follow: Node3D = null
var _hand_base := {}
var _my_glass: Node3D = null
# mirar, reacciones y ambiente
var _look_tile = null       # Vector3 de la última ficha que cayó
var _look_tile_t := 0.0
var _prev_turn := -1
var _prev_phase := ""
var _end_t := 0.0
var _chain_nodes := {}
var bulb: OmniLight3D
var bulb_tiles: OmniLight3D
var _swing := 0.0
var _flicker_in := 6.0
var _flicker_t := 0.0
var colmadero: Node3D
var _wipe_in := 6.0
var cat_tail: Node3D
var cat_head: Node3D
var fan_head: Node3D
const FAN_POS := Vector3(-0.85, 0, -1.9)   # abanico de pie (en el suelo del colmado)
var _cat_t := 0.0
# menús dentro del colmado
var show_arms := true
var arms_root: Node3D   # tus brazos: se pasan al mundo nítido de las fichas
# cosméticos del armario
const TILE_STYLES := {
	"marfil": {"face": Color(0.99, 0.975, 0.93), "pip": Color(0.04, 0.03, 0.03), "line": Color(0.18, 0.15, 0.12), "body": Color(0.9, 0.87, 0.8)},
	"negras": {"face": Color(0.12, 0.12, 0.14), "pip": Color(0.97, 0.97, 0.95), "line": Color(0.8, 0.8, 0.78), "body": Color(0.08, 0.08, 0.1)},
	"cristal": {"face": Color(0.72, 0.93, 0.86), "pip": Color(0.03, 0.3, 0.25), "line": Color(0.2, 0.5, 0.45), "body": Color(0.55, 0.85, 0.78)},
	"madera": {"face": Color(0.78, 0.56, 0.34), "pip": Color(0.18, 0.09, 0.03), "line": Color(0.35, 0.2, 0.08), "body": Color(0.6, 0.4, 0.22)},
	"doradas": {"face": Color(1.0, 0.86, 0.42), "pip": Color(0.35, 0.16, 0.04), "line": Color(0.55, 0.35, 0.08), "body": Color(0.85, 0.65, 0.2)},
}
var tile_style := "marfil"
var preview_on := false   # muestra del armario: la mesa no se redibuja sola
var table_style := "madera"
var board_mi: MeshInstance3D
var board_default: Material
var rail_default: Material
var rail_meshes: Array = []
var px_scale := 1.0   # tamaño del 3D respecto a 640x360 (píxeles finos = 1.5)
var my_cfg: Dictionary = {}
var mirror_char: Node3D
const MIRROR_C := Vector3(-2.2, 1.25, 1.25)   # centro del espejo (en el colmado, «room»)
const PROBADOR_C := Vector3(-1.85, 0.0, 1.5)   # dónde pisa tu personaje en el probador (colmado, «room»)
# mira hacia el fondo del colmado, a lo largo de la pared izquierda: la cámara
# queda pegada a esa pared, lejos de la mesa y de los que juegan
const PROBADOR_TF := Transform3D(Basis(Vector3.UP, PI / 2), PROBADOR_C)
const PROBADOR_CADERA := 0.81   # la raíz del personaje está en la cadera: los zapatos quedan 0,81 m más abajo
var probador: Node3D
var probador_giro := 0.0        # lo que lo giras arrastrando o con las flechas
var cams := {}
var room: Node3D             # el colmado: gira según tu silla (online)
var room_seat := 0           # tu silla en la sala del servidor (0 = la del anfitrión)
# robar de la mesa
var pool_nodes: Array = []
var pool_taken := {}      # índice de ficha -> y base en la bandeja
var pool_slot := {}       # índice de ficha -> hueco de la bandeja donde cayó

var _tex_cache := {}
var _sig := ""
var _chain_sig := ""
var hands_root: Node3D
var chain_root: Node3D
var hand_sh: Node3D
var chain_sh: Node3D
var _prev_chain: Array = []
var _t := 0.0
var _shuffled_hand := -1
var _cam_normal: Transform3D
var _cam_top: Transform3D
var _cam_tq: Transform3D
const R_TQ := 0.60   # tranque: filas de cada uno dentro del tablero (lejos de brazos y del borde)
var _show_ends := false

var mat_body := StandardMaterial3D.new()
var mat_back := StandardMaterial3D.new()
var mat_ghost := StandardMaterial3D.new()


func _ready() -> void:
	mat_body.albedo_color = Color(0.9, 0.87, 0.8)
	mat_back.albedo_color = Color(0.95, 0.92, 0.84)
	mat_ghost.albedo_color = Color(1, 0.85, 0.3, 0.45)
	mat_ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_build_room()
	pie = Pie.new(self)
	add_child(pie)
	pie.chair_move.connect(_move_my_chair)
	# tu silla (tú eres la cámara): solo se ve cuando te levantas
	my_chair = Node3D.new()
	my_chair.position = Vector3(0, TABLE_Y, 1.02)
	add_child(my_chair)
	var wood := _mat(Color(0.32, 0.2, 0.1))
	_box(Vector3(0.46, 0.05, 0.4), Vector3(0, -0.28, 0.12), wood, my_chair)
	_box(Vector3(0.46, 0.6, 0.05), Vector3(0, 0.0, 0.3), wood, my_chair)
	for lx in [-0.2, 0.2]:
		for lz in [-0.05, 0.29]:
			_box(Vector3(0.04, 0.47, 0.04), Vector3(lx, -0.53, lz), wood, my_chair)
	my_chair.visible = false


func _mat(c: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _box(size: Vector3, pos: Vector3, m: Material, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _wood_tex(base: Color, w: int, h: int, seed_v: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var band := sin(y * 0.55 + sin(y * 0.13) * 2.0) * 0.5 + 0.5
		for x in w:
			var c := base.darkened(band * 0.09 + rng.randf() * 0.03)
			img.set_pixel(x, y, c)
	# vetas y nudos
	for i in 10:
		var y0 := rng.randi_range(0, h - 1)
		var x0 := rng.randi_range(0, w - 1)
		for x in rng.randi_range(6, 20):
			img.set_pixel((x0 + x) % w, y0, base.darkened(0.22))
	for i in 2:
		var cx := rng.randi_range(4, w - 5)
		var cy := rng.randi_range(4, h - 5)
		for dx in range(-2, 3):
			for dy in range(-1, 2):
				img.set_pixel(cx + dx, cy + dy, base.darkened(0.3 if abs(dx) < 2 else 0.18))
	img.generate_mipmaps()   # sin mipmaps, las vetas parpadean de lejos al mover la cámara
	return ImageTexture.create_from_image(img)


func _tex_mat(tex: Texture2D, uv := Vector3.ONE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_scale = uv
	return m


func _build_room() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.06, 0.04, 0.04)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.4, 0.32, 0.32)
	e.ambient_light_energy = 0.75
	env.environment = e
	add_child(env)

	# el colmado (paredes, estantes, mostrador, colmadero, gata, abanico, radio,
	# espejo, calle…) cuelga de «room»: online gira según tu silla en la mesa,
	# así cada uno lo ve desde su sitio (la mesa, la gente y las fichas no giran)
	room = Node3D.new()
	room.name = "Colmado"
	add_child(room)

	camera = Camera3D.new()
	camera.fov = 54
	add_child(camera)
	_cam_normal = Transform3D(Basis(), Vector3(0, 1.98, 1.5)).looking_at(Vector3(0, TABLE_Y + 0.02, -0.2))
	# desde arriba se ve la mesa entera con un poco de margen
	_cam_top = Transform3D(Basis(), Vector3(0, TABLE_Y + 1.78, 0.06)).looking_at(Vector3(0, TABLE_Y, 0.06), Vector3(0, 0, -1))
	# tranque: centrada sobre la mesa (la de arriba mira hacia ti y cortaba la fila de arriba)
	_cam_tq = Transform3D(Basis(), Vector3(0, TABLE_Y + 1.62, 0)).looking_at(Vector3(0, TABLE_Y, 0), Vector3(0, 0, -1))
	camera.global_transform = _cam_normal

	# bombilla del colmado
	bulb = OmniLight3D.new()
	bulb.position = Vector3(0, 1.75, 0)
	bulb.light_color = Color(1.0, 0.82, 0.55)
	bulb.light_energy = 1.1
	bulb.omni_attenuation = 0.6
	bulb.omni_range = 4.0
	bulb.shadow_enabled = true
	add_child(bulb)
	sphere = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	sphere.mesh = sm
	sphere.material_override = _mat(Color(1, 0.9, 0.6), 4.0)
	sphere.position = Vector3(0, 1.82, 0)
	add_child(sphere)
	bulb_wire = _box(Vector3(0.008, 0.6, 0.008), Vector3(0, 2.15, 0), _mat(Color(0.1, 0.1, 0.1)))

	turn_light = OmniLight3D.new()
	turn_light.light_color = Color(1, 0.8, 0.3)
	turn_light.light_energy = 1.0
	turn_light.omni_range = 0.55
	add_child(turn_light)

	# suelo y pared del colmado con estantes
	_box(Vector3(8, 0.1, 8), Vector3(0, -0.05, 0), _tex_mat(_wood_tex(Color(0.3, 0.2, 0.14), 32, 32, 3), Vector3(8, 8, 1)), room)
	_box(Vector3(8, 4, 0.1), Vector3(0, 2, -2.2), _mat(Color(0.18, 0.42, 0.42)), room)
	_box(Vector3(8, 0.9, 0.11), Vector3(0, 0.45, -2.19), _mat(Color(0.85, 0.7, 0.3)), room)
	for i in 3:
		var y := 1.3 + i * 0.45
		# a la izquierda del colmadero (x 0.95): si no, la tabla le atraviesa la cabeza
		# y a la derecha de la pizarra (acaba en x −1,2): si no, la tapan por el borde
		_box(Vector3(1.55, 0.04, 0.3), Vector3(-0.275, y, -2.05), _mat(Color(0.35, 0.22, 0.12)), room)
		for j in 7:
			var bc: Color = [Color(0.2, 0.55, 0.3), Color(0.6, 0.35, 0.15), Color(0.8, 0.75, 0.6), Color(0.7, 0.2, 0.2)][(i + j) % 4]
			_box(Vector3(0.08, 0.22, 0.08), Vector3(-0.95 + j * 0.21, y + 0.13, -2.05), _mat(bc), room)

	# mesa de madera con borde alto y bandejas
	var wood_light := _tex_mat(_wood_tex(Color(0.5, 0.33, 0.2), 48, 48, 7), Vector3(1, 1, 1))
	var wood_rail := _tex_mat(_wood_tex(Color(0.72, 0.5, 0.28), 32, 8, 11), Vector3(3, 1, 1))
	rail_default = wood_rail
	var board := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(BOARD * 2, BOARD * 2)
	board.mesh = pm
	board.material_override = wood_light
	board_mi = board
	board_default = wood_light
	board.position = Vector3(0, TABLE_Y, 0)
	add_child(board)
	_box(Vector3(BOARD * 2 + 0.5, 0.05, BOARD * 2 + 0.5), Vector3(0, TABLE_Y - 0.03, 0), wood_rail)
	for s in 4:
		var dir := _seat_dir(s)
		var right := Vector3(dir.z, 0, -dir.x)
		var rail := _box(Vector3(BOARD * 2 + 0.12, 0.05, 0.05), dir * (BOARD + 0.03) + Vector3(0, TABLE_Y + 0.02, 0), wood_rail)
		rail.rotation.y = atan2(dir.x, dir.z)
		# bandeja: canal donde se apoyan las fichas de pie
		var tray := _box(Vector3(0.95, 0.02, 0.09), dir * TRAY + Vector3(0, TABLE_Y + 0.0, 0), wood_rail)
		tray.rotation.y = atan2(dir.x, dir.z)
		var lip := _box(Vector3(0.95, 0.035, 0.015), dir * (TRAY + 0.05) + Vector3(0, TABLE_Y + 0.02, 0), wood_rail)
		lip.rotation.y = atan2(dir.x, dir.z)
		var _r := right
	for sx in [-0.7, 0.7]:
		for sz in [-0.7, 0.7]:
			_box(Vector3(0.07, TABLE_Y, 0.07), Vector3(sx, TABLE_Y / 2, sz), _mat(Color(0.45, 0.3, 0.16)))

	for c in get_children():
		if c is MeshInstance3D and c.material_override == wood_rail:
			rail_meshes.append(c)

	# las fichas viven en otro mundo 3D que se dibuja nítido (ver attach_tiles)
	tiles_root = Node3D.new()
	markers_root = Node3D.new()
	shadows_root = Node3D.new()
	add_child(shadows_root)
	hands_root = Node3D.new()
	chain_root = Node3D.new()
	tiles_root.add_child(hands_root)
	tiles_root.add_child(chain_root)
	hand_sh = Node3D.new()
	chain_sh = Node3D.new()
	shadows_root.add_child(hand_sh)
	shadows_root.add_child(chain_sh)
	mat_shadow.albedo_color = Color(0.05, 0.02, 0.0, 0.45)
	mat_shadow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_shadow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# portavasos en las cuatro esquinas: cada uno usa la de su derecha
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var cp := Vector3(sx * CORNER, TABLE_Y - 0.004, sz * CORNER)
			var hole := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.05
			cm.bottom_radius = 0.05
			cm.height = 0.012
			cm.radial_segments = 12
			hole.mesh = cm
			hole.material_override = _mat(Color(0.12, 0.07, 0.04))
			hole.position = cp
			add_child(hole)
			var rim := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.05
			tm.outer_radius = 0.06
			tm.rings = 12
			tm.ring_segments = 4
			rim.mesh = tm
			rim.material_override = _mat(Color(0.55, 0.33, 0.15))
			rim.position = cp + Vector3(0, 0.004, 0)
			rim.scale = Vector3(1, 0.4, 1)
			add_child(rim)

	# jugadores (el asiento 0 eres tú: la cámara)
	heads = [null, null, null, null]
	var presets := {1: "yeya", 2: "fello", 3: "chichi"}
	for s in [1, 2, 3]:
		var dir := _seat_dir(s)
		var ch := Character.new()
		ch.own_chair = false
		ch.position = dir * 1.02 + Vector3(0, TABLE_Y, 0)
		ch.rotation.y = atan2(dir.x, dir.z)
		add_child(ch)
		ch.setup(presets[s])
		heads[s] = ch
		seat_chairs[s] = _make_seat_chair(ch.transform)
		_give_chair(s)
		ch.drink_spot = drink_corner(s)
		ch.drink_step = drink_step_dir(s)
		var seat_k: int = s
		ch.slot_fn = func(k: int) -> Vector3: return drink_slot(seat_k, k)

	_build_my_arms()
	var antes := get_children()
	_build_ambience()
	_build_menu_places()
	# todo lo que acaban de añadir es decoración del colmado: va a «room»
	for c in get_children():
		if not c in antes and c != room:
			c.reparent(room)

	for side in [-1, 1]:
		var mk := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(TW, TL, TD)
		mk.mesh = bm
		mk.material_override = mat_ghost
		mk.visible = false
		markers_root.add_child(mk)
		end_markers[side] = mk
		var etiqueta := Label3D.new()
		etiqueta.text = "1" if side == -1 else "2"
		etiqueta.font_size = 32
		etiqueta.pixel_size = 0.002
		etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		etiqueta.no_depth_test = true
		etiqueta.visible = false
		markers_root.add_child(etiqueta)
		end_labels[side] = etiqueta
		var material: StandardMaterial3D = mat_ghost.duplicate()
		material.albedo_color = Color("56b4e9") if side == -1 else Color("e69f00")
		material.albedo_color.a = 0.65
		mk.set_meta("accesible_material", material)


## Mete las fichas en el mundo de la vista nítida y le da su propia luz.
func attach_tiles(host: Node) -> void:
	_tiles_host = host
	host.add_child(tiles_root)
	host.add_child(markers_root)
	# tus brazos van en la misma capa que las fichas para taparlas bien
	if arms_root and arms_root.get_parent() == self:
		remove_child(arms_root)
		host.add_child(arms_root)
	bulb_tiles = OmniLight3D.new()
	bulb_tiles.position = Vector3(0, 1.75, 0)
	bulb_tiles.light_color = Color(1.0, 0.86, 0.65)
	bulb_tiles.light_energy = 1.0
	bulb_tiles.omni_range = 4.0
	bulb_tiles.omni_attenuation = 0.6
	host.add_child(bulb_tiles)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-1.1, 0.3, 0)
	fill.light_energy = 0.35
	host.add_child(fill)


func _shadow(pos: Vector3, basis_: Basis, size: Vector2, parent: Node3D = null) -> void:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.material_override = mat_shadow
	mi.transform.basis = basis_
	mi.position = pos
	(parent if parent else hand_sh).add_child(mi)


# ---------------------------------------------------------------- ambiente

func _build_ambience() -> void:
	# mostrador del colmado detrás de Don Fello
	var counter_m := _tex_mat(_wood_tex(Color(0.55, 0.3, 0.15), 32, 16, 21), Vector3(2, 1, 1))
	_box(Vector3(1.3, 0.95, 0.45), Vector3(0.85, 0.475, -1.6), counter_m)
	_box(Vector3(1.36, 0.04, 0.5), Vector3(0.85, 0.97, -1.6), _mat(Color(0.85, 0.75, 0.3)))
	# frascos de dulces y una radio
	for i in 3:
		var jar := _box(Vector3(0.1, 0.14, 0.1), Vector3(1.15 + i * 0.13, 1.06, -1.65), _mat(Color(0.85, 0.95, 1.0)))
		_box(Vector3(0.08, 0.07, 0.08), Vector3(0, -0.02, 0), _mat([Color(1, 0.3, 0.3), Color(1, 0.8, 0.2), Color(0.4, 0.8, 0.4)][i]), jar)

	# colmadero detrás del mostrador
	colmadero = Character.new()
	colmadero.position = Vector3(0.95, 0.86, -1.89)   # a -1.95 la nuca se metía en el estante del fondo
	colmadero.rotation.y = PI
	add_child(colmadero)
	colmadero.setup("colmadero")
	# gata dormida en el mostrador
	var cat := Node3D.new()
	cat.position = Vector3(0.55, 0.99, -1.55)
	cat.rotation.y = 0.5
	add_child(cat)
	var fur := _mat(Color(0.95, 0.6, 0.25))
	var fur_d := _mat(Color(0.7, 0.4, 0.15))
	_box(Vector3(0.2, 0.09, 0.12), Vector3(0, 0.045, 0), fur, cat)
	_box(Vector3(0.05, 0.091, 0.121), Vector3(-0.03, 0.045, 0), fur_d, cat)
	cat_head = Node3D.new()
	cat_head.position = Vector3(0.12, 0.07, 0.01)
	cat.add_child(cat_head)
	_box(Vector3(0.09, 0.08, 0.09), Vector3.ZERO, fur, cat_head)
	for ez in [-0.03, 0.03]:
		_box(Vector3(0.025, 0.035, 0.02), Vector3(0.01, 0.05, ez), fur_d, cat_head)
	cat_tail = Node3D.new()
	cat_tail.position = Vector3(-0.1, 0.03, 0)
	cat.add_child(cat_tail)
	_box(Vector3(0.14, 0.025, 0.025), Vector3(-0.07, 0, 0.0), fur_d, cat_tail)
	# abanico de pie en la esquina
	var fan := Node3D.new()
	# O04: a la derecha de la pizarra y fuera de su encuadre (antes, en -1,45,
	# su rejilla y sus aspas tapaban la esquina de la pizarra); sigue dejando
	# paso por detrás de Don Fello. Si se mueve, mover también su caja en pie.gd
	fan.position = FAN_POS
	add_child(fan)
	var metal := _mat(Color(0.2, 0.45, 0.45))
	_box(Vector3(0.25, 0.04, 0.25), Vector3(0, 0.02, 0), metal, fan)
	_box(Vector3(0.03, 1.2, 0.03), Vector3(0, 0.62, 0), metal, fan)
	var fan_pivot := Node3D.new()
	fan_pivot.position = Vector3(0, 1.25, 0)
	fan.add_child(fan_pivot)
	_box(Vector3(0.12, 0.12, 0.12), Vector3.ZERO, metal, fan_pivot)
	fan_head = Node3D.new()
	fan_head.position = Vector3(0, 0, 0.08)
	fan_pivot.add_child(fan_head)
	# disco translúcido: el «borrón» de las aspas girando
	var blur := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.2
	cyl.height = 0.004
	cyl.radial_segments = 16
	blur.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.85, 0.85, 0.8, 0.18)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blur.material_override = bm
	blur.rotation.x = PI / 2
	blur.position = Vector3(0, 0, 0.09)
	fan_pivot.add_child(blur)
	for i in 3:
		var blade := Node3D.new()
		blade.rotation.z = i * TAU / 3.0
		fan_head.add_child(blade)
		_box(Vector3(0.07, 0.18, 0.01), Vector3(0, 0.1, 0), _mat(Color(0.85, 0.85, 0.8)), blade)
	fan_pivot.set_meta("osc", true)
	fan.set_meta("pivot", fan_pivot)
	fan.name = "Fan"


# pizarra de modos (menus.gd coloca el texto exactamente dentro de ella)
const CHALK_C := Vector3(-1.9, 1.6, -2.1)
const CHALK_W := 1.3
const CHALK_H := 0.85
const CHALK_CAM_D := 1.06


## Textura de pizarra: verde oscuro con borrones de tiza y pasadas de borrador.
func _chalk_tex() -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var w := 260
	var h := 170
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var base := Color(0.13, 0.22, 0.17)
	for y in h:
		for x in w:
			var n := rng.randf() * 0.025
			# viñeta suave hacia los bordes
			var vx: float = abs(x - w / 2.0) / (w / 2.0)
			var vy: float = abs(y - h / 2.0) / (h / 2.0)
			var vig: float = max(vx, vy)
			img.set_pixel(x, y, base.lightened(n).darkened(vig * vig * 0.25))
	# pasadas de borrador: franjas anchas algo más claras
	for k in 7:
		var y0 := rng.randi_range(5, h - 25)
		var x0 := rng.randi_range(-20, w - 60)
		var span := rng.randi_range(70, 160)
		for x in range(max(x0, 0), min(x0 + span, w)):
			for y in range(y0, min(y0 + rng.randi_range(14, 22), h)):
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, c.lerp(Color(0.32, 0.4, 0.36), 0.12 * rng.randf()))
	# polvo de tiza
	for k in 900:
		var x := rng.randi_range(0, w - 1)
		var y := rng.randi_range(0, h - 1)
		img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(0.85, 0.9, 0.85), rng.randf_range(0.05, 0.22)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## La calle, la fachada con su neón, el espejo, la pizarra y la radio:
## cada menú es un sitio del colmado.
func _build_menu_places() -> void:
	# paredes laterales y fachada con puerta
	var wall := _mat(Color(0.18, 0.42, 0.42))
	var paint := _mat(Color(0.95, 0.75, 0.3))
	for sx in [-3.0, 3.0]:
		_box(Vector3(0.1, 3.0, 4.6), Vector3(sx, 1.5, 0.05), wall)
	var fz := 2.35
	_box(Vector3(2.5, 3.0, 0.12), Vector3(-1.75, 1.5, fz), paint)
	_box(Vector3(2.5, 3.0, 0.12), Vector3(1.75, 1.5, fz), paint)
	_box(Vector3(1.0, 0.9, 0.12), Vector3(0, 2.55, fz), paint)
	# zócalo por fuera: su cara de dentro quedaba en el mismo plano que la pared
	# y por dentro se veía una franja que temblaba (z-fighting)
	_box(Vector3(6, 0.5, 0.14), Vector3(0, 0.25, fz + 0.025), _mat(Color(0.12, 0.5, 0.5)))  # zócalo
	# ventana con reja
	for wx in [-1.6, 1.6]:
		_box(Vector3(0.9, 0.7, 0.17), Vector3(wx, 1.45, fz), _mat(Color(1, 0.85, 0.55), 0.6))
		for k in 5:
			_box(Vector3(0.045, 0.72, 0.03), Vector3(wx - 0.36 + k * 0.18, 1.45, fz + 0.11), _mat(Color(0.1, 0.1, 0.1)))   # gruesos: los finos parpadeaban
	# letrero de neón (luz fija, sin parpadeos)
	_box(Vector3(2.2, 0.55, 0.08), Vector3(0, 3.2, fz + 0.05), _mat(Color(0.12, 0.08, 0.06)))
	var neon := Label3D.new()
	neon.text = "COLMADÓN"
	neon.font_size = 96
	neon.pixel_size = 0.0034
	neon.modulate = Color(1.0, 0.45, 0.6)
	neon.outline_size = 14
	neon.outline_modulate = Color(1.0, 0.2, 0.45, 0.55)
	neon.position = Vector3(0, 3.2, fz + 0.1)
	neon.shaded = false
	add_child(neon)
	var nl := OmniLight3D.new()
	nl.light_color = Color(1, 0.35, 0.55)
	nl.light_energy = 1.4
	nl.omni_range = 2.2
	nl.position = Vector3(0, 3.0, fz + 0.5)
	add_child(nl)
	# acera, farola y un motor aparcado
	_box(Vector3(8, 0.08, 1.2), Vector3(0, 0.04, fz + 0.7), _mat(Color(0.45, 0.43, 0.4)))
	_box(Vector3(8, 0.02, 4), Vector3(0, 0.0, fz + 3.2), _mat(Color(0.12, 0.12, 0.14)))
	_box(Vector3(0.06, 3.2, 0.06), Vector3(-2.4, 1.6, fz + 1.1), _mat(Color(0.15, 0.15, 0.15)))
	_box(Vector3(0.3, 0.12, 0.2), Vector3(-2.3, 3.2, fz + 1.1), _mat(Color(1, 0.85, 0.5), 2.0))
	var street := OmniLight3D.new()
	street.light_color = Color(1, 0.75, 0.45)
	street.light_energy = 1.2
	street.omni_range = 3.5
	street.position = Vector3(-2.3, 3.0, fz + 1.2)
	add_child(street)
	var moto := Node3D.new()
	moto.position = Vector3(1.7, 0, fz + 1.6)
	moto.rotation.y = 0.3
	add_child(moto)
	var red := _mat(Color(0.75, 0.12, 0.12))
	var black := _mat(Color(0.08, 0.08, 0.08))
	for wz in [-0.45, 0.45]:
		_box(Vector3(0.08, 0.38, 0.38), Vector3(0, 0.2, wz), black, moto)
	_box(Vector3(0.18, 0.2, 0.7), Vector3(0, 0.45, 0), red, moto)
	_box(Vector3(0.2, 0.08, 0.35), Vector3(0, 0.6, 0.12), black, moto)
	_box(Vector3(0.5, 0.04, 0.04), Vector3(0, 0.78, -0.4), black, moto)

	# probador en la esquina izquierda (donde estaba el espejo): tu personaje de
	# pie a tamaño real sobre un círculo de luz, con un biombo detrás, un
	# perchero con camisas y un espejo de pie pequeño. Solo se ve en «Tu personaje».
	probador = Node3D.new()
	probador.name = "Probador"
	probador.visible = false
	# todo el probador en sus coordenadas: +x es hacia donde mira tu personaje
	probador.transform = PROBADOR_TF
	room.add_child(probador)
	var px := 0.0
	var pz := 0.0
	var madera := _tex_mat(_wood_tex(Color(0.45, 0.27, 0.13), 16, 32, 9), Vector3(1, 1, 1))
	var tela := _mat(Color(0.78, 0.36, 0.3))
	var tela2 := _mat(Color(0.9, 0.78, 0.55))
	# biombo de tres hojas en zigzag detrás del personaje
	for k in 3:
		var hoja := Node3D.new()
		hoja.position = Vector3(px - 0.55 + (0.06 if k == 1 else 0.0), 0, pz + (k - 1) * 0.5)
		hoja.rotation.y = [0.35, 0.0, -0.35][k]
		probador.add_child(hoja)
		_box(Vector3(0.04, 1.75, 0.04), Vector3(0, 0.875, -0.24), madera, hoja)
		_box(Vector3(0.04, 1.75, 0.04), Vector3(0, 0.875, 0.24), madera, hoja)
		_box(Vector3(0.04, 0.04, 0.52), Vector3(0, 1.73, 0), madera, hoja)
		_box(Vector3(0.04, 0.04, 0.52), Vector3(0, 0.14, 0), madera, hoja)
		_box(Vector3(0.02, 1.52, 0.44), Vector3(0, 0.94, 0), tela if k != 1 else tela2, hoja)
		_box(Vector3(0.025, 0.06, 0.44), Vector3(0.005, 1.5, 0), tela2 if k != 1 else tela, hoja)
		_box(Vector3(0.025, 0.06, 0.44), Vector3(0.005, 0.4, 0), tela2 if k != 1 else tela, hoja)
	# perchero con tres camisas, a la izquierda del personaje (visto desde la cámara)
	var perchero := Node3D.new()
	perchero.position = Vector3(px - 0.4, 0, pz + 0.95)
	probador.add_child(perchero)
	var metal := _mat(Color(0.25, 0.22, 0.2))
	_box(Vector3(0.035, 1.6, 0.035), Vector3(0, 0.8, -0.3), metal, perchero)
	_box(Vector3(0.035, 1.6, 0.035), Vector3(0, 0.8, 0.3), metal, perchero)
	_box(Vector3(0.03, 0.03, 0.66), Vector3(0, 1.58, 0), metal, perchero)
	_box(Vector3(0.3, 0.03, 0.03), Vector3(0, 0.02, -0.3), metal, perchero)
	_box(Vector3(0.3, 0.03, 0.03), Vector3(0, 0.02, 0.3), metal, perchero)
	for k in 3:
		var c: Color = [Color(0.95, 0.85, 0.3), Color(0.3, 0.55, 0.8), Color(0.85, 0.3, 0.35)][k]
		var z := -0.18 + k * 0.18
		_box(Vector3(0.012, 0.012, 0.16), Vector3(0, 1.53, z), metal, perchero)
		_box(Vector3(0.05, 0.42, 0.26), Vector3(0, 1.3, z), _mat(c), perchero)
		_box(Vector3(0.05, 0.14, 0.08), Vector3(0, 1.43, z - 0.16), _mat(c.darkened(0.1)), perchero)
		_box(Vector3(0.05, 0.14, 0.08), Vector3(0, 1.43, z + 0.16), _mat(c.darkened(0.1)), perchero)
	# espejo de pie pequeño, a la derecha del personaje, de adorno
	var espejo := Node3D.new()
	espejo.position = Vector3(px - 0.25, 0, pz - 0.8)
	espejo.rotation.y = 0.5
	probador.add_child(espejo)
	var dorado := _mat(Color(0.8, 0.62, 0.25))
	_box(Vector3(0.04, 1.2, 0.04), Vector3(0, 0.95, -0.22), dorado, espejo)
	_box(Vector3(0.04, 1.2, 0.04), Vector3(0, 0.95, 0.22), dorado, espejo)
	_box(Vector3(0.04, 0.04, 0.48), Vector3(0, 1.55, 0), dorado, espejo)
	_box(Vector3(0.04, 0.04, 0.48), Vector3(0, 0.35, 0), dorado, espejo)
	_box(Vector3(0.015, 1.16, 0.4), Vector3(0.01, 0.95, 0), _mat(Color(0.62, 0.78, 0.8), 0.25), espejo)
	_box(Vector3(0.3, 0.03, 0.06), Vector3(0, 0.02, -0.22), dorado, espejo)
	_box(Vector3(0.3, 0.03, 0.06), Vector3(0, 0.02, 0.22), dorado, espejo)
	# círculo de luz en el suelo y foco cálido desde arriba
	var disco := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.42
	cm.bottom_radius = 0.42
	cm.height = 0.006
	cm.radial_segments = 32
	disco.mesh = cm
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(1.0, 0.86, 0.55, 0.35)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disco.material_override = dm
	disco.position = Vector3(px, 0.004, pz)
	probador.add_child(disco)
	var aro := MeshInstance3D.new()
	var am := TorusMesh.new()
	am.inner_radius = 0.42
	am.outer_radius = 0.46
	am.rings = 32
	aro.mesh = am
	aro.material_override = _mat(Color(0.95, 0.75, 0.35), 0.6)
	aro.position = Vector3(px, 0.006, pz)
	aro.scale = Vector3(1, 0.15, 1)
	probador.add_child(aro)
	var foco := SpotLight3D.new()
	foco.light_color = Color(1, 0.9, 0.72)
	foco.light_energy = 2.2
	foco.spot_range = 3.2
	foco.spot_angle = 30.0
	foco.transform = Transform3D(Basis(), Vector3(px + 0.6, 2.6, pz)).looking_at(Vector3(px, 0.6, pz))
	probador.add_child(foco)
	var relleno := OmniLight3D.new()
	relleno.light_color = Color(1, 0.95, 0.85)
	relleno.light_energy = 0.7
	relleno.omni_range = 2.2
	relleno.position = Vector3(px + 1.2, 1.4, pz)
	probador.add_child(relleno)

	# pizarra de modos en la pared del fondo: textura de tiza, marco y repisa
	var frame_m := _tex_mat(_wood_tex(Color(0.55, 0.32, 0.14), 32, 8, 5), Vector3(4, 1, 1))
	_box(Vector3(CHALK_W + 0.1, CHALK_H + 0.1, 0.03), CHALK_C + Vector3(0, 0, -0.025), frame_m)
	_box(Vector3(CHALK_W, CHALK_H, 0.02), CHALK_C, _mat(Color(0.1, 0.17, 0.13)))
	var slate := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(CHALK_W, CHALK_H)
	slate.mesh = sq
	var sm2 := StandardMaterial3D.new()
	sm2.albedo_texture = _chalk_tex()
	sm2.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	slate.material_override = sm2
	slate.position = CHALK_C + Vector3(0, 0, 0.016)   # separada de la madera: sin parpadeo de lejos
	add_child(slate)
	# repisa con tizas y borrador
	var ledge := CHALK_C + Vector3(0, -CHALK_H / 2 - 0.06, 0.04)
	_box(Vector3(CHALK_W + 0.1, 0.03, 0.09), ledge, frame_m)
	for k in 3:
		var chalk_c: Color = [Color(0.95, 0.95, 0.9), Color(1, 0.75, 0.8), Color(0.75, 0.9, 1)][k]
		var ck := _box(Vector3(0.07, 0.016, 0.016), ledge + Vector3(-0.42 + k * 0.1, 0.023, 0.01), _mat(chalk_c))
		ck.rotation.y = randf_range(-0.4, 0.4)
	_box(Vector3(0.14, 0.035, 0.05), ledge + Vector3(0.42, 0.032, 0.0), _mat(Color(0.3, 0.2, 0.12)))
	_box(Vector3(0.14, 0.012, 0.05), ledge + Vector3(0.42, 0.012, 0.0), _mat(Color(0.85, 0.85, 0.82)))
	var chalk_l := OmniLight3D.new()
	chalk_l.position = CHALK_C + Vector3(0, 0.55, 0.55)
	chalk_l.light_color = Color(1, 0.9, 0.75)
	chalk_l.light_energy = 0.7
	chalk_l.omni_range = 1.4
	add_child(chalk_l)

	# radio grande del mostrador (ajustes)
	var radio := Node3D.new()
	radio.position = Vector3(0.36, 1.1, -1.68)
	add_child(radio)
	radio_node = radio
	_box(Vector3(0.34, 0.2, 0.14), Vector3.ZERO, _mat(Color(0.45, 0.25, 0.12)), radio)
	# Frente pintado en Aseprite; perillas y antena conservan volumen 3D.
	var radio_front := _tex_mat(load("res://arte/escenario/radio.png"))
	_box(Vector3(0.32, 0.18, 0.01), Vector3(0, 0, 0.076), radio_front, radio)
	for kx in [0.06, 0.12]:
		_box(Vector3(0.035, 0.035, 0.03), Vector3(kx, -0.04, 0.08), _mat(Color(0.9, 0.85, 0.75)), radio)
	_box(Vector3(0.008, 0.25, 0.008), Vector3(0.14, 0.22, 0), _mat(Color(0.7, 0.7, 0.7)), radio)  # antena

	# cámaras de cada sitio
	cams = {
		"calle": Transform3D(Basis(), Vector3(0.8, 1.75, 6.4)).looking_at(Vector3(-0.2, 2.05, 2.3)),
		"puerta": Transform3D(Basis(), Vector3(0, 1.6, 2.9)).looking_at(Vector3(0, 1.2, 0)),
		"pizarra": Transform3D(Basis(), CHALK_C + Vector3(0, 0, CHALK_CAM_D)).looking_at(CHALK_C),
		# espejo: de frente y a la altura del centro del espejo, a 1,27 m (con fov 54
		# el espejo ocupa ~85 % del alto) y corrida 0,48 m para que el espejo entero
		# quede centrado en la mitad izquierda (a la derecha va el panel)
		"espejo": probador_tf("cuerpo"),
		"probador_cuerpo": probador_tf("cuerpo"),
		"probador_cara": probador_tf("cara"),
		"probador_torso": probador_tf("torso"),
		"probador_piernas": probador_tf("piernas"),
		# radio: el colmadero con su gata y la radio a la izquierda (panel a la derecha)
		"radio": Transform3D(Basis(), Vector3(1.38, 1.5, 0.05)).looking_at(Vector3(1.38, 1.18, -1.75)),
		"mesa": _cam_normal,
		"armario": Transform3D(Basis(), Vector3(0.0, 1.5, 0.95)).looking_at(Vector3(0.0, TABLE_Y, 0.02)),
	}


## Lleva la cámara a un sitio del colmado. Pasa por la puerta si viene de la calle.
## Lugar de cámara: los del colmado (pizarra, radio, espejo…) giran con él;
## la cámara de la mesa es siempre la de tu silla.
func cam_tf(place: String) -> Transform3D:
	if place == "mesa" or room == null:
		return cams[place]
	return room.transform * cams[place]


## Sillas que se pueden empujar: las de quien está de pie y la tuya.
func loose_chairs() -> Array:
	var out: Array = []
	for s in [1, 2, 3]:
		if seat_chairs[s] != null and heads[s] != null and heads[s]._chair_out:
			out.append(seat_chairs[s])
	if my_chair.visible:
		out.append(my_chair)
	return out


## Mesazo: alguien chocó con la mesa. Tiemblan la bombilla y los vasos; muy
## fuerte, se vuelca uno (al rato alguien lo levanta).
func bump_table(strength: float) -> void:
	bump_bulb(clamp(strength / 2.5, 0.3, 1.0))
	sfx.emit("clink")
	# a los que están en la mesa les salta el pelo, la cadena y los aretes
	for h in heads:
		if h != null and is_instance_valid(h):
			h.sacudir(clampf(strength / 2.0, 0.4, 1.2))
	var vasos: Array = []
	for s in [1, 2, 3]:
		if heads[s] != null:
			for gl in heads[s].glasses:
				if is_instance_valid(gl):
					vasos.append(gl)
	for gl in my_glasses:
		if is_instance_valid(gl):
			vasos.append(gl)
	for gl in vasos:
		var tw: Tween = gl.create_tween()
		var a: float = randf_range(0.12, 0.25) * clamp(strength / 2.0, 0.5, 1.0)
		tw.tween_property(gl, "rotation:z", a, 0.06)
		tw.tween_property(gl, "rotation:z", -a * 0.6, 0.08)
		tw.tween_property(gl, "rotation:z", 0.0, 0.12)
	# F12: las fichas sueltas (bandejas y montón) saltan un poco y vuelven a su
	# sitio; las de la línea no se mueven nunca
	var sueltas: Array = hand_nodes + other_hand_nodes
	for n in sueltas:
		if not is_instance_valid(n) or (n as Node3D).has_meta("f12"):
			continue
		var nd: Node3D = n
		nd.set_meta("f12", true)
		var p0 := nd.position
		var f: float = clampf(strength / 2.0, 0.3, 1.0)
		var off := Vector3(randf_range(-0.006, 0.006) * f, 0.008 * f, randf_range(-0.004, 0.004) * f)
		var tn := nd.create_tween()
		tn.tween_interval(randf_range(0.0, 0.05))
		tn.tween_property(nd, "position", p0 + off, 0.05)
		tn.tween_property(nd, "position", p0, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tn.tween_callback(func(): if is_instance_valid(nd): nd.remove_meta("f12"))
	if strength > 1.9 and not vasos.is_empty():
		var v: Node3D = vasos.pick_random()
		var vt := v.create_tween()
		vt.tween_interval(0.25)
		vt.tween_property(v, "rotation:x", PI / 2.0 * 0.95, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		vt.parallel().tween_property(v, "position:y", v.position.y - 0.03, 0.25)
		# al rato alguien lo levanta
		vt.tween_interval(3.5)
		vt.tween_property(v, "rotation:x", 0.0, 0.3)
		vt.parallel().tween_property(v, "position:y", v.position.y, 0.3)


var _punch_t := 0.0


## Tus manos lanzan un manotazo (primera persona).
func fp_punch() -> void:
	_punch_t = 0.3


## Punto del colmado al que apuntas desde la pantalla: una persona (si el rayo
## pasa cerca de su cabeza o su cuerpo), la mesa o el suelo. {pos, seat?} o {}.
func aim_point(p: Vector2) -> Dictionary:
	var o := camera.project_ray_origin(p * px_scale)
	var n := camera.project_ray_normal(p * px_scale)
	var best := -1
	var bd := 0.28
	for s in [1, 2, 3]:
		if heads[s] == null or not heads[s].visible:
			continue
		for h in [0.45, 0.15]:
			var c: Vector3 = heads[s].global_position + Vector3(0, h, 0)
			var k: float = (c - o).dot(n)
			if k <= 0.0:
				continue
			var dist: float = (o + n * k).distance_to(c)
			if dist < bd:
				bd = dist
				best = s
	if best > 0:
		return {"pos": heads[best].global_position, "seat": best}
	if abs(n.y) < 0.001:
		return {}
	var kt := (TABLE_Y - o.y) / n.y
	if kt > 0.0:
		var ht := o + n * kt
		if abs(ht.x) < BOARD and abs(ht.z) < BOARD:
			return {"pos": ht}
	var kf := -o.y / n.y
	if kf <= 0.0:
		return {}
	return {"pos": o + n * kf}


## Disparo desde o hacia n: la persona y la zona que toca primero (la mesa
## tapa) o, si no da a nadie, el punto donde pega (mesa, suelo o pared).
func disparo_impacto(o: Vector3, n: Vector3, sillas := [1, 2, 3]) -> Dictionary:
	var tope := 30.0
	if n.y < -0.001:
		var k := (TABLE_Y - 0.03 - o.y) / n.y
		var ht := o + n * k
		if abs(ht.x) < BOARD + 0.06 and abs(ht.z) < BOARD + 0.06:
			tope = k
	var best := {}
	var bk := tope
	for s in sillas:
		var ch = heads[s]
		if ch == null or not ch.visible or ch.muerto:
			continue
		for z in ch.zonas_impacto():
			var k: float = (z[1] - o).dot(n)
			if k <= 0.05 or k >= bk:
				continue
			if (o + n * k).distance_to(z[1]) < z[2]:
				bk = k
				best = {"seat": s, "zona": z[0], "pos": o + n * k}
	if best.is_empty():
		var kf := tope
		if n.y < -0.001:
			kf = minf(tope, -o.y / n.y)
		best = {"pos": o + n * minf(kf, 8.0)}
	return best


## Marca que se abre en el suelo (o en la mesa) donde alguien señala.
func point_marker(at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.1
	tm.outer_radius = 0.13
	tm.rings = 16
	tm.ring_segments = 4
	ring.mesh = tm
	var m := _mat(Color(1, 0.85, 0.3), 2.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = m
	ring.position = at + Vector3(0, 0.02, 0)
	ring.scale = Vector3(0.3, 0.3, 0.3)
	add_child(ring)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(1.6, 1.0, 1.6), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 1.4)
	tw.chain().tween_callback(ring.queue_free)


## Dónde ponerse para pedir en el mostrador (delante del colmadero), en el suelo.
func counter_spot() -> Vector2:
	var p3: Vector3 = room.transform * Vector3(0.85, 0, -1.05)
	return Vector2(p3.x, p3.z)


## Tu silla en la sala (online): el colmado gira para que lo veas desde ella.
## 0 (anfitrión) mira al mostrador; 2 (enfrente) mira a la puerta y la calle.
func set_room_seat(s: int) -> void:
	_cam_y_base = INF
	room_seat = posmod(s, 4)
	room.rotation.y = -room_seat * PI / 2.0
	pie.giro = -room_seat


## Te cambiaste de silla en la sala: el colmado gira hasta tu sitio nuevo
## (por el camino más corto), como si dieras la vuelta a la mesa.
var _giro_tw: Tween = null
var _cabeceo_tw: Tween = null
var _cam_y_base := INF   # altura de la cámara sentada (el cabeceo vuelve siempre aquí)


func girar_sala(s: int) -> void:
	# muchos cambios seguidos: cada giro cancela el anterior y el cabeceo vuelve
	# siempre a la misma altura (antes se acumulaba y la cámara acababa en el techo)
	if _giro_tw != null and _giro_tw.is_valid():
		_giro_tw.kill()
	if _cabeceo_tw != null and _cabeceo_tw.is_valid():
		_cabeceo_tw.kill()
	if _cam_y_base == INF:
		_cam_y_base = camera.position.y
	var desde := room.rotation.y
	room_seat = posmod(s, 4)
	var hasta := -room_seat * PI / 2.0
	hasta = desde + wrapf(hasta - desde, -PI, PI)
	pie.giro = -room_seat
	_giro_tw = create_tween()
	_giro_tw.tween_property(room, "rotation:y", hasta, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	# un leve cabeceo de la cámara: te levantas y te vuelves a sentar
	_cabeceo_tw = create_tween()
	_cabeceo_tw.tween_property(camera, "position:y", _cam_y_base + 0.08, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cabeceo_tw.tween_property(camera, "position:y", _cam_y_base, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func cam_to(place: String, dur := 0.9) -> void:
	var tw := create_tween()
	if place != "calle" and camera.global_transform.origin.z > 4.0:
		tw.tween_property(camera, "global_transform", cam_tf("puerta"), dur * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(camera, "global_transform", cam_tf(place), dur * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	elif place == "calle" and camera.global_transform.origin.z < 4.0:
		tw.tween_property(camera, "global_transform", cam_tf("puerta"), dur * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(camera, "global_transform", cam_tf("calle"), dur * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(camera, "global_transform", cam_tf(place), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func cam_set(place: String) -> void:
	camera.global_transform = cam_tf(place)


## Tu reflejo en el espejo (se rehace al cambiar algo).
func set_mirror_cfg(c: Dictionary) -> void:
	if is_instance_valid(mirror_char):
		mirror_char.queue_free()
	mirror_char = Character.new()
	mirror_char.own_chair = false   # en el probador no lleva silla
	# de pie y a tamaño real, con los zapatos en el suelo del colmado
	mirror_char.position = Vector3(0, PROBADOR_CADERA, 0)
	mirror_char.rotation.y = -PI / 2 + probador_giro
	mirror_char.stand_k = 1.0
	# cuelga del probador (del colmado): fuera de «Tu personaje» no se ve
	probador.add_child(mirror_char)
	mirror_char.setup_cfg(c)


## El probador solo se ve en «Tu personaje» (en partida no hay nadie parado ahí).
func probador_mostrar(on: bool) -> void:
	if probador != null:
		probador.visible = on


## Cámara del probador según lo que estás cambiando: el cuerpo entero, la cara,
## el torso o las piernas. Tu personaje queda en el centro de la mitad izquierda
## (la derecha es del panel) y la cámara lo mira un poco de lado.
func probador_tf(enfoque: String) -> Transform3D:
	var datos: Array = {"cuerpo": [0.8, 2.7], "cara": [1.3, 1.1], "torso": [1.05, 1.3], "piernas": [0.42, 1.35]}.get(enfoque, [0.8, 2.7])
	var alto: float = datos[0]
	var d: float = datos[1]
	var mira := Vector3(0, alto, 0)
	var dir := Vector3(1, 0.12, 0.28).normalized()   # de frente, un poco desde arriba y de lado (lejos de la pared)
	var ojo := mira + dir * d
	# corrida a su derecha (−z): el personaje cae en la mitad izquierda de la pantalla
	var lado := Vector3(0, 0, -1) * d * 0.34
	return PROBADOR_TF * Transform3D(Basis(), ojo + lado).looking_at(mira + lado)


## Gira a tu personaje en el probador (arrastrando o con las flechas).
func probador_girar(radianes: float) -> void:
	probador_giro = wrapf(probador_giro + radianes, -PI, PI)
	if is_instance_valid(mirror_char):
		mirror_char.rotation.y = -PI / 2 + probador_giro


func mirror_react(kind: String) -> void:
	if not is_instance_valid(mirror_char):
		return
	match kind:
		"wink":
			mirror_char.wink()
		"talk":
			mirror_char.talk(2.2)
		"drink":
			mirror_char.drink(["cafe", "ron", "morir", "agua"].pick_random())
		_:
			mirror_char.act(kind)


func _tick_ambience(dt: float) -> void:
	# la bombilla parpadea a veces y se balancea tras un golpe
	_flicker_in -= dt
	if _flicker_in <= 0.0:
		_flicker_t = randf_range(0.08, 0.3)
		_flicker_in = randf_range(7.0, 16.0)
	# sin parpadeos: la luz es estable (el usuario los veía como fallos)
	var e := 1.1
	_swing *= pow(0.25, dt)
	var sw := Vector3(sin(_t * 3.2) * _swing, 0, cos(_t * 2.7) * _swing * 0.6)
	bulb.light_energy = e
	bulb.position = Vector3(0, 1.75, 0) + sw
	if bulb_tiles:
		bulb_tiles.light_energy = e * 0.9
		bulb_tiles.position = bulb.position
	sphere.position = Vector3(0, 1.82, 0) + sw
	# colmadero: limpia el mostrador de vez en cuando
	_wipe_in -= dt
	if _wipe_in <= 0.0:
		colmadero.act("wipe")
		_wipe_in = randf_range(7.0, 14.0)
	colmadero.look_target = Vector3(0, TABLE_Y, 0)
	# gata: cola que se mueve y cabeza que se levanta a veces
	_cat_t += dt
	cat_tail.rotation.y = sin(_cat_t * 2.0) * 0.5
	cat_head.rotation.z = max(0.0, sin(_cat_t * 0.35)) * 0.5
	# abanico: aspas girando y cabeza que oscila
	# despacio: a 18 rad/s las aspas hacían efecto de rueda de carro (parecían temblar)
	fan_head.rotation.z += dt * 3.5
	var piv: Node3D = room.get_node("Fan").get_meta("pivot")   # el abanico es del colmado (gira con él)
	piv.rotation.y = sin(_t * 0.5) * 0.8


func bump_bulb(strength: float) -> void:
	_swing = max(_swing, 0.04 + strength * 0.06)


# ---------------------------------------------------------------- tus manos

const ARM_REST := {"l": Vector3(-0.56, TABLE_Y + 0.03, 0.84), "r": Vector3(0.56, TABLE_Y + 0.03, 0.84)}
const MAX_REACH := 0.95   # el brazo no se estira más; la ficha vuela el resto
const ARM_SHOULDER := {"l": Vector3(-0.3, TABLE_Y + 0.42, 1.38), "r": Vector3(0.3, TABLE_Y + 0.42, 1.38)}
const FOREARM := 0.3
const UPPER := 0.36


func set_avatar(id: String) -> void:
	set_avatar_cfg(Character.PRESETS[id])


func set_avatar_cfg(c: Dictionary) -> void:
	my_cfg = c
	for k in arms:
		arms[k].root.queue_free()
	arms.clear()
	_build_my_arms()


func _build_my_arms() -> void:
	var cfg: Dictionary = my_cfg if not my_cfg.is_empty() else Character.PRESETS[avatar]
	var skin_m := _mat(cfg.skin)
	var sleeve_m := _mat(cfg.shirt)
	if arms_root == null:
		arms_root = Node3D.new()
		add_child(arms_root)
	for k in ["l", "r"]:
		var root := Node3D.new()
		arms_root.add_child(root)
		# antebrazo y brazo: cajas de largo 1 que se estiran entre articulaciones
		var fore := _box(Vector3(0.1, 0.09, 1.0), Vector3.ZERO, skin_m, root)
		var upper := _box(Vector3(0.115, 0.105, 1.0), Vector3.ZERO, skin_m, root)
		var sleeve := _box(Vector3(0.13, 0.12, 1.0), Vector3.ZERO, sleeve_m, root)
		var hand := Node3D.new()
		root.add_child(hand)
		_box(Vector3(0.1, 0.045, 0.1), Vector3.ZERO, skin_m, hand)
		_box(Vector3(0.095, 0.035, 0.055), Vector3(0, -0.008, -0.072), skin_m, hand)  # dedos
		var thumb_x := 0.06 if k == "l" else -0.06
		_box(Vector3(0.03, 0.03, 0.055), Vector3(thumb_x, 0.0, -0.035), skin_m, hand)
		arms[k] = {"root": root, "fore": fore, "upper": upper, "sleeve": sleeve, "hand": hand, "pos": ARM_REST[k]}
	_update_arm("l", 1.0)
	_update_arm("r", 1.0)


func _span(mi: MeshInstance3D, a: Vector3, b: Vector3, frac := 1.0) -> void:
	var d := b - a
	mi.position = a + d * (frac * 0.5)
	if d.length() > 0.001:
		mi.look_at(b, Vector3.UP if abs(d.normalized().y) < 0.98 else Vector3.FORWARD)
	mi.scale = Vector3(1, 1, max(d.length() * frac, 0.01))


func _update_arm(k: String, w: float) -> void:
	if arms_root == null or not arms_root.is_inside_tree():
		return
	var a: Dictionary = arms[k]
	a.pos = a.pos.lerp(_arm_target(k), w)
	var wrist: Vector3 = a.pos
	var base_sh: Vector3 = ARM_SHOULDER[k]
	if wrist.distance_to(base_sh) > MAX_REACH:
		wrist = base_sh + (wrist - base_sh).normalized() * MAX_REACH
	var reach: Vector3 = wrist - ARM_REST[k]
	var lean := Vector3(reach.x * 0.4, min(reach.y, 0.0) * 0.3, min(reach.z, 0.0) * 0.6)
	var shoulder: Vector3 = ARM_SHOULDER[k] + lean
	# codo: detrás de la muñeca, hacia el hombro, un poco hacia fuera y abajo
	var to_sh := shoulder - wrist
	var out := Vector3(-1 if k == "l" else 1, 0, 0) * 0.08
	var elbow: Vector3 = wrist + (to_sh.normalized() * FOREARM) + out + Vector3(0, -0.04, 0)
	if (shoulder - elbow).length() > UPPER * 1.6:
		elbow = shoulder + (elbow - shoulder).normalized() * UPPER * 1.6
	var hand: Node3D = a.hand
	hand.position = wrist
	var flat := Vector3(wrist.x - elbow.x, 0, wrist.z - elbow.z)
	if flat.length() > 0.01:
		hand.look_at(wrist + flat, Vector3.UP)
	_span(a.fore, elbow, wrist)
	_span(a.upper, shoulder, elbow)
	_span(a.sleeve, shoulder, elbow, 0.85)


func _arm_target(k: String) -> Vector3:
	var rest: Vector3 = ARM_REST[k]
	if not _hand_anim.is_empty() and _hand_anim.arm == k:
		var t: float = _hand_anim.t
		match _hand_anim.kind:
			"shuffle":
				return Vector3(0.12 + sin(t * 9.0) * 0.14, TABLE_Y + 0.04, 0.2 + cos(t * 9.0) * 0.1)
			"tap":
				# dos toques en la mesa: paso
				var p := Vector3(0.18, TABLE_Y + 0.02, 0.5)
				return p + Vector3(0, abs(sin(t * 9.0)) * 0.08, 0)
			"drink":
				var u: float = clamp(t / 1.8, 0.0, 1.0)
				var raise: float = smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.78, 1.0, u))
				var sip: float = clamp((u - 0.25) / 0.5, 0.0, 1.0)
				var mouth := Vector3(-0.1, TABLE_Y + 0.6 + sin(sip * PI * 6.0) * 0.01, 0.98)
				if is_instance_valid(_my_glass):
					_my_glass.rotation.x = 1.25 * raise
					_my_glass.get_node("Level").scale.y = max(1.0 - sip, 0.05)
				return rest.lerp(mouth, raise)
	if k == "r":
		if is_instance_valid(_hand_follow):
			return _hand_follow.position + Vector3(0.02, 0.04, 0.07)
		if drag_index >= 0:
			return drag_point + Vector3(0.02, 0.03, 0.08)
		if hover_index >= 0 and hover_index < hand_nodes.size():
			var n: Node3D = hand_nodes[hover_index]
			return Vector3(n.position.x + 0.03, TABLE_Y + 0.07, TRAY - 0.06)
	return rest


func hand_act(kind: String, id := "") -> void:
	_hand_anim = {"kind": kind, "arm": "l" if kind == "drink" else "r", "t": 0.0, "id": id}
	if kind == "drink":
		if is_instance_valid(_my_glass):
			_my_glass.queue_free()
		_my_glass = Character.make_glass(id)
		_my_glass.scale = Vector3.ONE * 0.9
		_my_glass.position = Vector3(0, 0.07, -0.02)
		arms.l.hand.add_child(_my_glass)


var my_empties: Array = []   # tipos de bebida ya tomadas (vasos vacíos)
var _my_glass_sig := ""


func set_my_drinks(list: Array) -> void:
	var sig := str(list, my_empties, preview_on)
	if sig == _my_glass_sig:
		return
	_my_glass_sig = sig
	for gl in my_glasses:
		if is_instance_valid(gl):
			gl.queue_free()
	my_glasses.clear()
	var nodes: Array = Character.layout_glasses(list, my_empties, func(k: int) -> Vector3: return drink_slot(0, k))
	for i in nodes.size():
		var gl: Node3D = nodes[i]
		add_child(gl)
		gl.global_position = gl.get_meta("pos")
		# los llenos van detrás de los vacíos, en el orden de la lista
		var k: int = i - (nodes.size() - list.size())
		if k >= 0:
			gl.set_meta("drink_id", list[k])
		my_glasses.append(gl)
	glass_hover = -1


## Vasos llenos tocables (fase 2): el que está bajo el puntero, o -1.
var count_idle := 0.0   # segundos sin tocar fichas en tu cuenta (a los 30 se cuentan solas)
var glass_hover := -1


func glass_at(p: Vector2) -> int:
	if top_view:
		return -1
	var best := -1
	var best_d := 18.0
	for i in my_glasses.size():
		var gl = my_glasses[i]
		if not is_instance_valid(gl) or not gl.has_meta("drink_id"):
			continue
		var d: float = _u(gl.global_position + Vector3(0, 0.03, 0)).distance_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


func glass_id(i: int) -> String:
	if i < 0 or i >= my_glasses.size() or not is_instance_valid(my_glasses[i]):
		return ""
	return str(my_glasses[i].get_meta("drink_id", ""))


## En tu turno los vasos llenos laten un poco: se pueden tocar para beber.
func pulse_glasses(on: bool) -> void:
	var k: float = 1.0 + (0.07 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)) if on else 0.0)
	for gl in my_glasses:
		if is_instance_valid(gl) and gl.has_meta("drink_id"):
			gl.scale = Vector3(k, k, k)


## Resalta el vaso bajo el puntero: se levanta un poco, como al ir a cogerlo.
func set_glass_hover(i: int) -> void:
	if i == glass_hover:
		return
	glass_hover = i
	for k in my_glasses.size():
		var gl = my_glasses[k]
		if is_instance_valid(gl) and gl.has_meta("pos"):
			var to: Vector3 = gl.get_meta("pos") + (Vector3(0, 0.025, 0) if k == i else Vector3.ZERO)
			gl.create_tween().tween_property(gl, "global_position", to, 0.12)


# ---------------------------------------------------------------- arrastrar

func table_point(p: Vector2) -> Vector3:
	var o := camera.project_ray_origin(p * px_scale)
	var n := camera.project_ray_normal(p * px_scale)
	if abs(n.y) < 0.001:
		return Vector3.ZERO
	var k := (TABLE_Y - o.y) / n.y
	return o + n * k


func start_drag(i: int) -> void:
	drag_index = i
	drag_slot = -1


func drag_to(p: Vector2) -> void:
	if drag_index < 0 or drag_index >= hand_nodes.size():
		return
	var hit := table_point(p)
	hit.x = clamp(hit.x, -BOARD, BOARD)
	hit.z = clamp(hit.z, -BOARD, TRAY)
	drag_point = hit
	var node: Node3D = hand_nodes[drag_index]
	# reglamento F10: cerca de tu bandeja se reacomoda (las otras se apartan)
	var n := hand_nodes.size()
	drag_slot = -1
	if hit.z > TRAY - 0.09:
		drag_slot = clampi(roundi(hit.x / (TW + 0.01) + (n - 1) / 2.0), 0, n - 1)
		var k := 0
		for j in n:
			if j == drag_index:
				continue
			if k == drag_slot:
				k += 1
			var o: Node3D = hand_nodes[j]
			o.position.x = lerp(o.position.x, (k - (n - 1) / 2.0) * (TW + 0.01), 0.3)
			k += 1
		var to := Vector3((drag_slot - (n - 1) / 2.0) * (TW + 0.01), TABLE_Y + TL / 2 + 0.05, TRAY)
		node.position = node.position.lerp(to.lerp(Vector3(hit.x, to.y, TRAY), 0.5), 0.5)
		node.rotation = node.rotation.lerp(Vector3(-0.3, 0, 0), 0.3)
		return
	for j in n:
		if j != drag_index:
			var o: Node3D = hand_nodes[j]
			o.position.x = lerp(o.position.x, (j - (n - 1) / 2.0) * (TW + 0.01), 0.3)
	node.position = node.position.lerp(hit + Vector3(0, 0.06, 0), 0.6)
	node.transform.basis = node.transform.basis.slerp(_flat_basis(Vector2(0, -1)), 0.35)


func end_drag() -> void:
	if drag_index >= 0 and drag_index < hand_nodes.size():
		pending_from = hand_nodes[drag_index].position
	drag_index = -1
	hover_side = 0
	_sig = ""


func set_hover_side(side: int) -> void:
	hover_side = side


# ---------------------------------------------------------------- impacto

func _impact(pos: Vector3, strength: float) -> void:
	tile_landed.emit(strength)
	# anillo que se expande
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.05
	tm.outer_radius = 0.06
	tm.rings = 12
	tm.ring_segments = 4
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(1, 0.9, 0.6, 0.7)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm
	ring.position = Vector3(pos.x, TABLE_Y + 0.004, pos.z)
	ring.scale = Vector3(0.6, 0.2, 0.6)
	add_child(ring)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(2.2, 0.2, 2.2) * (1.0 + strength), 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(rm, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(ring.queue_free)
	# polvo pixelado
	var dust := CPUParticles3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.012, 0.012, 0.012)
	dust.mesh = dm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.85, 0.72, 0.5)
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust.material_override = pm
	dust.amount = int(10 + 14 * strength)
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.lifetime = 0.45
	dust.direction = Vector3.UP
	dust.spread = 80.0
	dust.initial_velocity_min = 0.25
	dust.initial_velocity_max = 0.55 + strength * 0.4
	dust.gravity = Vector3(0, -2.2, 0)
	dust.position = Vector3(pos.x, TABLE_Y + 0.01, pos.z)
	add_child(dust)
	dust.emitting = true
	get_tree().create_timer(1.0).timeout.connect(dust.queue_free)


## De 3D a coordenadas de la interfaz (640x360), sea cual sea la resolución del 3D.
func _u(p3: Vector3) -> Vector2:
	return camera.unproject_position(p3) / px_scale


## Centro horizontal de la interfaz (la pantalla puede ser más ancha que 640).
func _cx() -> float:
	return camera.get_viewport().size.x / px_scale * 0.5


## Fichas del armario: rehace texturas y fichas con el nuevo estilo.
func set_tile_style(id: String) -> void:
	if not TILE_STYLES.has(id):
		return
	tile_style = id
	_tex_cache.clear()
	mat_body.albedo_color = TILE_STYLES[id].body
	_sig = ""
	_chain_sig = ""


## Mesa del armario: madera, plástico blanco, verde casino o turquesa.
func set_table_style(id: String) -> void:
	table_style = id
	var board_m: Material = board_default
	var rail_m: Material = rail_default
	match id:
		"blanca":
			board_m = _mat(Color(0.88, 0.88, 0.85))
			rail_m = _mat(Color(0.95, 0.95, 0.93))
		"casino":
			board_m = _mat(Color(0.1, 0.38, 0.22))
			rail_m = _mat(Color(0.35, 0.12, 0.08))
		"turquesa":
			board_m = _mat(Color(0.15, 0.55, 0.55))
			rail_m = _mat(Color(0.95, 0.75, 0.25))
	board_mi.material_override = board_m
	for r in rail_meshes:
		r.material_override = rail_m


func set_glass_style(id: String) -> void:
	Character.glass_style = id
	for gl in my_glasses:
		if is_instance_valid(gl):
			gl.queue_free()
	my_glasses.clear()
	_my_glass_sig = ""   # que se vuelvan a poner con el estilo nuevo
	if preview_on:
		_preview_glasses()
	for s2 in [1, 2, 3]:
		for gl in heads[s2].glasses:
			gl.queue_free()
		heads[s2].glasses.clear()


## Muestra unas fichas y un vaso de ejemplo para el armario.
func show_preview(on: bool) -> void:
	preview_on = on
	reset_table()
	for gl in my_glasses:
		if is_instance_valid(gl):
			gl.queue_free()
	my_glasses.clear()
	# antes la firma no cambiaba y los vasos de muestra no volvían a salir
	# (al entrar en la pestaña «Vasos» desaparecían)
	_my_glass_sig = ""
	if not on:
		return
	var sample := [Vector2i(6, 6), Vector2i(6, 3), Vector2i(3, 5), Vector2i(5, 5), Vector2i(5, 1)]
	var x := -0.5
	for t in sample:
		var dbl: bool = t.x == t.y
		var node := _make_tile(t, true)
		node.transform.basis = _flat_basis(Vector2(0, 1) if dbl else Vector2(-1, 0))
		var w: float = TW if dbl else TL
		node.position = Vector3(x + w / 2, TABLE_Y + TD / 2 + 0.002, 0.1)
		chain_root.add_child(node)
		_chain_nodes[t] = node
		_shadow(Vector3(node.position.x + 0.006, TABLE_Y + 0.002, 0.108), node.transform.basis, Vector2(TW + 0.008, TL + 0.008), chain_sh)
		x += w + GAP
	_preview_glasses()


## Vasos de muestra del armario (también al cambiar de estilo de vaso).
func _preview_glasses() -> void:
	set_my_drinks(["ron", "cafe"])
	for k in my_glasses.size():
		my_glasses[k].position = Vector3(-0.2 + k * 0.1, TABLE_Y + 0.04, 0.32)


## Prepara de antemano las 28 texturas de fichas (pantalla de carga).
func precache_tile(i: int) -> void:
	var k := 0
	for a in 7:
		for b in range(a, 7):
			if k == i:
				_tile_tex(Vector2i(a, b))
				return
			k += 1


## Marca en rojo la ficha del chivo cantado, con un cartel encima.
func highlight_chivo(t: Vector2i) -> void:
	if not _chain_nodes.has(t):
		return
	var node: Node3D = _chain_nodes[t]
	var glow := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(TW + 0.02, TL + 0.02, TD * 0.6)
	glow.mesh = bm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1, 0.15, 0.15, 0.55)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material_override = gm
	glow.position.z = -0.004
	node.add_child(glow)
	var lbl := Label3D.new()
	lbl.text = "¡CHIVO!"
	lbl.font_size = 48
	lbl.pixel_size = 0.0022
	lbl.modulate = Color(1, 0.3, 0.3)
	lbl.outline_size = 10
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = node.position + Vector3(0, 0.12, 0)
	chain_root.add_child(lbl)
	var tw := lbl.create_tween().set_loops()
	tw.tween_property(lbl, "position:y", lbl.position.y + 0.03, 0.4)
	tw.tween_property(lbl, "position:y", lbl.position.y, 0.4)


## Vacía la mesa (al volver al menú).
func reset_table() -> void:
	animating = false
	counting = false
	my_empties.clear()
	for s2 in [1, 2, 3]:
		if heads[s2]:
			heads[s2].empty_types.clear()
	_lay = {}
	counted_hand = -1
	_clear(hands_root)
	_clear(chain_root)
	_clear(hand_sh)
	_clear(chain_sh)
	hand_nodes.clear()
	pool_nodes.clear()
	pool_taken.clear()
	pool_slot.clear()
	_sig = ""
	_chain_sig = ""
	_shuffled_hand = -1
	_prev_chain = []


## Sitio n.º k de los vasos de un jugador: 0 = su portavasos (esquina derecha);
## los siguientes en fila por el borde, detrás de su bandeja.
func drink_slot(s: int, k: int) -> Vector3:
	# los tuyos, en el borde de la mesa a la derecha de tu bandeja: desde la
	# esquina se salían por abajo de la pantalla (ahora se beben tocándolos)
	if s == 0:
		return Vector3(0.76, TABLE_Y + 0.04, 0.68 - 0.1 * k)
	if k == 0:
		return drink_corner(s)
	var dir := _seat_dir(s)
	var right := Vector3(dir.z, 0, -dir.x)
	return dir * GLASS_ROW + right * (CORNER - 0.095 * k) + Vector3(0, TABLE_Y + 0.04, 0)


## Portavasos de la esquina a la derecha de cada jugador.
func drink_corner(s: int) -> Vector3:
	var dir := _seat_dir(s)
	var right := Vector3(dir.z, 0, -dir.x)
	return (dir + right) * CORNER + Vector3(0, TABLE_Y + 0.04, 0)


## La segunda bebida va al lado, hacia su propio sitio.
func drink_step_dir(s: int) -> Vector3:
	var dir := _seat_dir(s)
	var right := Vector3(dir.z, 0, -dir.x)
	return -right * 0.1


func _seat_dir(s: int) -> Vector3:
	return [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)][s]


# ---------------------------------------------------------------- fichas

## Las fichas no son pixel art: textura en alta definición con puntos redondos
## suavizados, para que se lean nítidas de cerca y de lejos.
func _tile_tex(t: Vector2i) -> ImageTexture:
	if _tex_cache.has(t):
		return _tex_cache[t]
	var w := 128
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var st: Dictionary = TILE_STYLES[tile_style]
	var ivory: Color = st.face
	for y in h:
		for x in w:
			# sombreado suave hacia los bordes (bisel)
			var ex: float = min(x, w - 1 - x) / 10.0
			var ey: float = min(y, h - 1 - y) / 10.0
			var e: float = clamp(min(ex, ey), 0.0, 1.0)
			img.set_pixel(x, y, ivory.darkened((1.0 - e) * 0.18))
	# línea central con remache
	for y in range(h / 2 - 2, h / 2 + 2):
		for x in range(14, w - 14):
			img.set_pixel(x, y, st.line)
	_disc(img, Vector2(w / 2.0, h / 2.0), 6.5, Color(0.8, 0.62, 0.25))
	_pips(img, 0, t.x)
	_pips(img, h / 2, t.y)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[t] = tex
	return tex


func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	for y in range(int(c.y - r - 2), int(c.y + r + 3)):
		for x in range(int(c.x - r - 2), int(c.x + r + 3)):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a: float = clamp(r + 0.5 - d, 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(col, a))


func _pips(img: Image, oy: int, n: int) -> void:
	var a := 30.0
	var b := 64.0
	var c := 98.0
	var layout := {
		0: [], 1: [[b, b]], 2: [[a, a], [c, c]], 3: [[a, a], [b, b], [c, c]],
		4: [[a, a], [c, a], [a, c], [c, c]], 5: [[a, a], [c, a], [a, c], [c, c], [b, b]],
		6: [[a, a], [a, b], [a, c], [c, a], [c, b], [c, c]],
	}
	for p in layout[n]:
		var center := Vector2(p[0], oy + p[1])
		_disc(img, center + Vector2(0, 1.5), 12.5, TILE_STYLES[tile_style].face.darkened(0.25))  # hundido
		_disc(img, center, 11.5, TILE_STYLES[tile_style].pip)


func _make_tile(t: Vector2i, face_visible: bool, glow := false, unshaded := false) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(TW, TL, TD)
	body.mesh = bm
	body.material_override = mat_body
	root.add_child(body)
	if face_visible:
		var front := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(TW * 0.96, TL * 0.96)
		front.mesh = qm
		front.position.z = TD / 2 + 0.0008
		var fm := StandardMaterial3D.new()
		fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		fm.albedo_texture = _tile_tex(t)
		fm.emission_enabled = true
		fm.emission_texture = fm.albedo_texture
		fm.emission = Color.WHITE
		fm.emission_energy_multiplier = 0.25
		if unshaded:
			fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if glow:
			fm.emission = Color(1, 0.85, 0.45)
			fm.emission_energy_multiplier = 0.55
		front.material_override = fm
		root.add_child(front)
	return root


func _flat_basis(v: Vector2, face_up := true) -> Basis:
	var y := Vector3(v.x, 0, v.y).normalized()
	var z := Vector3.UP if face_up else Vector3.DOWN
	return Basis(y.cross(z), y, z)


# ---------------------------------------------------------------- sincronizar

func sync(g, legal: Array, selected: int, seat_names: Array) -> void:
	_t += get_process_delta_time()
	# la mano siguiente empezó (online, los demás no esperan): se corta la cuenta
	if counting and not g.phase in ["shop", "over"]:
		_stop_count()
	# fuera de la partida (saliste al colmado a mitad) no se baraja: la mesa queda vacía
	if (g.phase == "draw" or g.phase == "play") and g.hand_no != _shuffled_hand and mesa_activa:
		_shuffled_hand = g.hand_no
		_start_shuffle(g)
	elif _prev_phase == "draw" and g.phase == "play" and not pool_nodes.is_empty():
		_prepare_deal(g)
	# O17: al elegir aumento las manos ya llegan vacías (como en el servidor):
	# la mesa se queda como acabó la mano (fichas de las manos y jugadas) hasta
	# que el barajado de la siguiente las recoge todas juntas
	# O16: ya contada la mano, sus fichas se quedan sobre la mesa donde las dejó
	# la cuenta (rehacer las devolvía a las bandejas, fuera del tablero)
	var contada: bool = g.phase in ["shop", "over"] and counted_hand == g.hand_no
	# (mientras las fichas vuelan a las bandejas no se rehace: saltarían a su sitio)
	var repartiendo: bool = Time.get_ticks_msec() < _dealing_until
	if not animating and not repartiendo and g.phase != "draw" and g.phase != "pick" and not contada and not preview_on:
		var ups := [pie.standing()]
		for s in [1, 2, 3]:
			ups.append(pie.remote.has(s) and pie.remote[s].st != 0)
		var sig := str(g.hands, g.chain, legal, selected, g.revealed, g.reveal_partner, g.phase, top_view, ups, show_all_hands, hand_tint, tranque_on, tranque_rev, tranque_dados)
		if sig != _sig:
			_sig = sig
			_rebuild(g, legal, selected)
	for s in [1, 2, 3]:
		var ch = heads[s]
		var active: bool = g.phase == "play" and g.turn == s and not animating
		if g.phase == "play":
			ch.state = "think" if active else "idle"
		elif g.phase == "pick":
			ch.state = "idle"
		elif not g.last_result.is_empty():
			# celebración (confirmado 2026-10-04): en la mano, 3 s los que ganan y
			# 2 s de lamento los que pierden; al ganar la partida, baile hasta el final
			var won: bool = g.last_result.team == s % 2
			if g.phase == "over" and won:
				ch.state = "win" if _end_t < 2.0 else "idle"
				if _end_t >= 2.0 and ch._action == "":
					ch.act("dance")
			elif won:
				ch.state = "win" if _end_t < 3.0 else "idle"
			else:
				ch.state = "lose" if _end_t < 2.0 else "idle"
		ch.set_drinks(g.drinks[s])
		# el jugueteo con la ficha solo dura su turno
		if not active:
			ch.fiddle = 0
	if not preview_on:
		set_my_drinks(g.drinks[0])
	_tick_ambience(get_process_delta_time())
	_tick_fp()
	_tick_auras()
	_occlude_tiles()
	_update_looks(g)
	# el aura de los pases es de la mano: al acabar se apaga siempre
	if g.phase != "play" and not _auras.is_empty():
		for k in _auras.keys():
			_drop_aura(k)
	if g.phase == "play" or g.phase == "draw":
		_end_t = 0.0
	else:
		_end_t += get_process_delta_time()
	_prev_phase = g.phase
	# fichas de tu bandeja: se levantan al pasar el ratón. Solo jugando: al
	# contar (tienda, libreta) tus fichas están tumbadas en la rejilla y esto
	# las devolvía a la altura de la bandeja (flotaban y se veían descolocadas)
	for i in hand_nodes.size():
		if counting or g.phase != "play" or Time.get_ticks_msec() < _dealing_until or show_all_hands or pie.standing() or i == drag_index or not _hand_base.has(i):
			continue
		var node: Node3D = hand_nodes[i]
		var lift := 0.0
		if i == selected:
			lift = 0.04
		elif i == hover_index:
			lift = 0.028
		elif i < g.hands[0].size() and legal.has(g.hands[0][i]):
			lift = 0.01 + sin(_t * 4.0 + i) * 0.003
		node.position.y = lerp(node.position.y, _hand_base[i] + lift, 0.25)
	# tus brazos
	if not _hand_anim.is_empty():
		_hand_anim.t += get_process_delta_time()
		if _hand_anim.t > {"drink": 1.8, "shuffle": 1.3}.get(_hand_anim.kind, 0.7):
			if _hand_anim.kind == "drink" and is_instance_valid(_my_glass):
				my_empties.append(_hand_anim.get("id", "ron"))
				_my_glass.queue_free()
				_my_glass = null
			_hand_anim = {}
	_update_arm("l", 0.18)
	_update_arm("r", 0.2 if drag_index < 0 else 0.45)
	for a in arms.values():
		a.root.visible = not top_view and show_arms and not pie.standing()
	# la luz del turno se desliza y se enciende suave, sin saltos
	var on: bool = g.phase == "play" and not animating
	turn_light.light_energy = lerp(turn_light.light_energy, 0.6 if on else 0.0, 0.08)
	var tp: Vector3 = _seat_dir(g.turn) * 0.6 + Vector3(0, TABLE_Y + 0.3, 0)
	turn_light.position = turn_light.position.lerp(tp, 0.08)
	# marcadores de extremos que laten
	var pulse := 0.35 + sin(_t * 6.0) * 0.2
	mat_ghost.albedo_color.a = pulse
	_update_markers()
	for side in end_markers:
		var mk: MeshInstance3D = end_markers[side]
		mk.visible = (_show_ends or drag_index >= 0) and end_world.has(side)
		mk.scale = Vector3.ONE * (1.18 if side == hover_side else 1.0)
		mk.material_override = mk.get_meta("accesible_material") if accesible else mat_ghost
		end_labels[side].position = mk.position + Vector3(0, 0.045, 0)
		end_labels[side].visible = accesible and mk.visible


## ¿Está la persona k (de pie, online) mirando las fichas de la silla s?
## Misma regla que el servidor (salaVeFichas): de pie, detrás de esa silla y
## cerca, con la silla sentada y sin tapar. my_cover: si tú (s = 0) tapaste.
func watching(k: int, s: int, my_cover := false) -> bool:
	if not pie.remote.has(k) or pie.remote[k].st != 2 or k == s:
		return false
	if s == 0:
		if pie.standing() or my_cover:
			return false
	elif covered.get(s, false) or (pie.remote.has(s) and pie.remote[s].st != 0):
		return false
	var d := _seat_dir(s)
	var seat2 := Vector2(d.x, d.z) * 1.1
	var v: Vector2 = pie.remote[k].cur - seat2
	return v.dot(Vector2(d.x, d.z)) > -0.05 and v.length() < 1.1


var _eyes := {}   # silla → Sprite3D del ojo sobre su cabeza


## Ojo sobre la cabeza de quien está mirando fichas ajenas.
func set_eye(k: int, on: bool) -> void:
	if not _eyes.has(k):
		if not on:
			return
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16:
				var e := Vector2((x - 7.5) / 7.5, (y - 7.5) / 4.5)
				if e.length() <= 1.0:
					img.set_pixel(x, y, Color(1, 1, 1))
				if Vector2(x - 7.5, y - 7.5).length() < 3.2:
					img.set_pixel(x, y, Color(0.1, 0.55, 0.6))
				if Vector2(x - 7.5, y - 7.5).length() < 1.5:
					img.set_pixel(x, y, Color(0.05, 0.03, 0.02))
				if e.length() > 1.0 and e.length() < 1.25:
					img.set_pixel(x, y, Color(0.12, 0.07, 0.04))
		var sp := Sprite3D.new()
		sp.texture = ImageTexture.create_from_image(img)
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.pixel_size = 0.012
		sp.no_depth_test = true
		add_child(sp)
		_eyes[k] = sp
	var eye: Sprite3D = _eyes[k]
	eye.visible = on and heads[k] != null and heads[k].visible
	if eye.visible:
		eye.global_position = heads[k].global_position + Vector3(0, 0.95 + sin(_t * 4.0) * 0.02, 0)


## Lo que hace otro jugador con sus fichas (online, o un bot imitándolo):
## 0 nada, 1 mirarlas, 2 una en la mano, 3 llevarla a una punta (side -1/1).
func set_fiddle(s: int, st: int, side := 0) -> void:
	if s < 1 or s > 3 or heads[s] == null:
		return
	heads[s].fiddle = st
	heads[s].fiddle_to = null
	if st == 3:
		var p: Vector2 = end_world[side].pos if end_world.has(side) else Vector2.ZERO
		heads[s].fiddle_to = Vector3(p.x, TABLE_Y, p.y)


## Silla de la mesa (objeto aparte: nunca va con el personaje).
var seat_chairs: Array = [null, null, null, null]


func _make_seat_chair(home: Transform3D) -> Node3D:
	var c := Node3D.new()
	c.name = "Silla"
	c.transform = home
	add_child(c)
	var wood := _mat(Color(0.32, 0.2, 0.1))
	_box(Vector3(0.46, 0.05, 0.4), Vector3(0, -0.28, 0.12), wood, c)
	_box(Vector3(0.46, 0.6, 0.05), Vector3(0, 0.0, 0.3), wood, c)
	for lx in [-0.2, 0.2]:
		for lz in [-0.05, 0.29]:
			_box(Vector3(0.04, 0.47, 0.04), Vector3(lx, -0.53, lz), wood, c)
	c.set_meta("home", home)
	return c


## El personaje de la silla s usa la silla de la mesa (en su sitio).
func _give_chair(s: int) -> void:
	var c: Node3D = seat_chairs[s]
	var ch = heads[s]
	c.transform = c.get_meta("home")
	ch.chair = c
	ch.chair_home = c.global_transform if c.is_inside_tree() else c.transform
	ch._chair_out = false


## Cambia el personaje de una silla (online: tu amigo con su aspecto, o el
## bot que toque). look: nombre de un preset o un diccionario de aspecto.
func set_seat_look(s: int, look) -> void:
	var old: Node3D = heads[s]
	var ch := Character.new()
	ch.own_chair = false
	# siempre en su silla (antes copiaba el sitio del anterior: si estaba de pie
	# junto a la pared, el nuevo y su silla nacían allí)
	var dir := _seat_dir(s)
	ch.position = dir * 1.02 + Vector3(0, TABLE_Y, 0)
	ch.rotation = Vector3(0, atan2(dir.x, dir.z), 0)
	add_child(ch)
	if look is Dictionary:
		ch.setup_cfg(look)
	else:
		ch.setup(str(look))
	ch.drink_spot = old.drink_spot
	ch.drink_step = old.drink_step
	ch.slot_fn = old.slot_fn
	for gl in old.glasses:
		if is_instance_valid(gl):
			gl.queue_free()
	ch.visible = old.visible
	heads[s] = ch
	old.chair = null
	old.queue_free()
	_give_chair(s)


## Silla vacía (sala de espera online): sin personaje hasta que alguien se siente.
func set_seat_empty(s: int, empty: bool) -> void:
	heads[s].visible = not empty


var _charla := {}   # silla -> {"a": a quién mira (0 = tú), "hasta": segundos}


## Sin partida en marcha (sala de espera, tienda): se miran entre ellos y a
## ti, y cambian de mirada cada pocos segundos, como en una charla.
func _charla_mira(s: int):
	var c: Dictionary = _charla.get(s, {"a": -1, "hasta": 0.0})
	c.hasta -= get_process_delta_time()
	if c.hasta <= 0.0:
		var otros: Array = []
		for k in 4:
			if k != s and (k == 0 or (heads[k] != null and heads[k].visible)):
				otros.append(k)
		c.a = otros.pick_random() if not otros.is_empty() and randf() < 0.85 else -1
		c.hasta = randf_range(1.8, 4.5)
	_charla[s] = c
	if c.a == 0:
		return camera.global_position
	if c.a > 0 and heads[c.a] != null:
		return heads[c.a].global_position + Vector3(0, 0.45, 0)
	return null   # a ratos, al frente


## A quién mira cada uno: a la ficha que acaba de caer y, si no, a quien juega.
func _update_looks(g) -> void:
	_look_tile_t -= get_process_delta_time()
	var turn_pos: Vector3 = camera.global_position if g.turn == 0 else heads[g.turn].global_position + Vector3(0, 0.45, 0)
	for s in [1, 2, 3]:
		var ch = heads[s]
		if pie.remote.has(s) and pie.remote[s].st == 2:
			# de pie, su cabeza mira justo al punto al que apunta su cámara (antes se
			# copiaba el ángulo y, con la cámara más alta que la cabeza, parecía mirar al suelo)
			var rr: Dictionary = pie.remote[s]
			var yw: float = rr.yaw
			var pt: float = rr.get("pitch", 0.0)
			var aim := Vector3(-sin(yw) * cos(pt), sin(pt), -cos(yw) * cos(pt))
			var eye := Vector3(rr.cur.x, pie.EYE, rr.cur.y)
			ch.look_target = ch.head.global_position + (eye + aim * 2.2 - ch.head.global_position).normalized() * 2.2
		elif pie.standing() and g.phase == "play":
			ch.look_target = camera.global_position   # todos pendientes de quien se paró
		elif animating:
			ch.look_target = null
		elif g.phase != "play":
			ch.look_target = _charla_mira(s)
		elif _look_tile_t > 0.0 and _look_tile != null:
			ch.look_target = _look_tile
		elif g.turn == s:
			# piensa mirando sus fichas; si lleva una a la punta, mira la punta
			ch.look_target = ch.fiddle_to if ch.fiddle == 3 else null
		else:
			ch.look_target = turn_pos
	# cuando te toca, tu compañero te mira y a veces te guiña o te hace una seña
	if g.phase == "play" and g.turn != _prev_turn:
		if g.turn == 0 and not animating:
			var r := randf()
			if r < 0.3:
				heads[2].wink()
			elif r < 0.45:
				heads[2].act("thumbs")
		_prev_turn = g.turn


var marker_dbl := false   # la ficha que llevas es doble
var marker_tile := Vector2i(-1, -1)   # la ficha que llevas
var _marker_sig := ""


## Coloca las marcas de las puntas con la forma que tendría tu ficha allí.
func _update_markers() -> void:
	if _lay.is_empty():
		# mesa vacía: una sola marca en el centro, con la forma de tu ficha
		var sig0 := str("vacia", marker_tile, marker_dbl)
		if sig0 == _marker_sig:
			return
		_marker_sig = sig0
		end_world.clear()
		var axis := Vector2(_seat_dir(0).x, _seat_dir(0).z)
		var d: Vector2 = Vector2(-axis.y, axis.x) if marker_dbl else -axis
		end_world[1] = {"pos": Vector2.ZERO, "dir": d}
		end_markers[1].transform.basis = _flat_basis(d)
		end_markers[1].position = Vector3(0, TABLE_Y + TD / 2 + 0.004, 0)
		return
	var sig := str(marker_tile, _lay.chain.size(), _lay.arms[0].i, _lay.arms[1].i)
	if sig == _marker_sig:
		return
	_marker_sig = sig
	for k in 2:
		var side: int = [1, -1][k]
		var probe: Dictionary = _lay.arms[k].duplicate()
		# la marca va donde caerá de verdad la ficha que llevas
		var e: int = _lay.ends[k]
		if marker_tile.x == e or marker_tile.y == e:
			_lay_base = _limit_for(marker_tile.y if marker_tile.x == e else marker_tile.x)
		var info := _spot_robust(probe, marker_dbl)
		_lay_base = LAY_LIMIT
		var d: Vector2 = info.d
		end_world[side] = {"pos": info.center, "dir": d}
		var mk: MeshInstance3D = end_markers[side]
		mk.transform.basis = _flat_basis(Vector2(-d.y, d.x) if marker_dbl else d)
		mk.position = Vector3(info.center.x, TABLE_Y + TD / 2 + 0.004, info.center.y)


func set_show_ends(v: bool) -> void:
	_show_ends = v


func _clear(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()


## Tranque: todas las manos boca arriba en la mesa (se ven desde arriba) y
## teñidas por silla (verde la pareja que gana, rojo la que pierde).
var show_all_hands := false
var hand_tint := {}   # silla -> Color


# ---------------------------------------------------------------- tranque con suspenso

var tranque_on := false        # fichas de todos tumbadas boca abajo; se giran una a una
var tranque_rev := {0: [], 1: [], 2: [], 3: []}   # índices ya girados de cada silla
var tranque_dados := {}        # silla -> true: sus fichas ya están con el ganador
var tranque_gana := -1         # silla del ganador (para el montón)
var _tq_giros := {}            # "s:i" -> lento: giros por animar al rehacer la mesa
var _tq_viajes := {}           # silla -> true: fichas que viajan al ganador al rehacer


## Empieza (o acaba) la mesa del tranque: todas las manos tumbadas boca abajo.
func tranque_mesa(on: bool) -> void:
	tranque_on = on
	tranque_rev = {0: [], 1: [], 2: [], 3: []}
	tranque_dados = {}
	tranque_gana = -1
	_tq_giros.clear()
	_tq_viajes.clear()
	_tq_linea_recogida = false
	show_all_hands = on
	hand_tint = {}
	_sig = ""
	if on:
		tranque_compactar_linea()


## Gira la ficha i de la silla s (lento = la que decide el tranque).
func tranque_girar(s: int, i: int, lento := false) -> void:
	if tranque_rev[s].has(i):
		return
	tranque_rev[s].append(i)
	_tq_giros["%d:%d" % [s, i]] = lento
	_sig = ""


## Amago: levanta la ficha como para girarla y la vuelve a dejar.
func tranque_amago(s: int, i: int) -> void:
	if i < 0 or i >= _seat_tiles[s].size():
		return
	var node: Node3D = _seat_tiles[s][i][0]
	if not is_instance_valid(node):
		return
	var y0 := node.position.y
	var r0 := node.rotation.x
	var tw := node.create_tween()
	tw.tween_property(node, "position:y", y0 + 0.06, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(node, "rotation:x", r0 - 0.7, 0.18)
	tw.tween_interval(0.25)
	tw.tween_property(node, "position:y", y0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(node, "rotation:x", r0, 0.16)
	tw.tween_callback(func(): sfx.emit("clack"))


## Las fichas de s pasan al montón del ganador (entregadas o arrebatadas).
func tranque_entregar(s: int, gana: int) -> void:
	tranque_gana = gana
	if tranque_dados.has(s):
		return
	tranque_dados[s] = true
	_tq_viajes[s] = true
	_sig = ""


## Dónde queda en la pantalla una ficha de la mesa del tranque (para tocarla).
func tranque_ficha_en_pantalla(s: int, i: int) -> Vector2:
	if i < 0 or i >= _seat_tiles[s].size() or not is_instance_valid(_seat_tiles[s][i][0]):
		return Vector2(-999, -999)
	return _u(_seat_tiles[s][i][0].global_position)


const TQ_COLS := 8   # fichas por fila en el montón del ganador


## Hueco k del montón del ganador: en SU mitad de la mesa, en filas que van del
## borde hacia el centro (la línea jugada se recoge en la otra mitad: no se pisan).
func _tq_monton(k: int) -> Vector3:
	var d := _seat_dir(tranque_gana)
	var right := Vector3(d.z, 0, -d.x)
	var fila := k / TQ_COLS
	var col := k % TQ_COLS
	return d * (R_TQ - 0.17 - fila * (TL + 0.016)) + right * (col - (TQ_COLS - 1) / 2.0) * (TW + 0.012) + Vector3(0, TABLE_Y + TD / 2 + 0.004, 0)


## Al empezar la cuenta del tranque: las fichas jugadas se recogen en filas en la
## mitad de la mesa lejos del ganador (como en la cuenta normal), mirando hacia él.
var _tq_linea_recogida := false


func tranque_recoger_linea(gana: int) -> void:
	tranque_gana = gana
	_tq_linea_recogida = true
	chain_sh.visible = false
	# en la cuenta: la línea (ya en bloque) se apila en montoncitos en la mitad
	# lejana del ganador; su montón va en la suya
	var d3 := _seat_dir(gana)
	var lejos := Vector3(-d3.x, 0, -d3.z)
	var lado := Vector3(lejos.z, 0, -lejos.x)
	var jugadas := _tq_jugadas()
	var pilas := ceili(jugadas.size() / 6.0)
	var rot := Vector3(PI / 2, atan2(d3.x, d3.z), 0)   # boca abajo, a lo largo
	for i in jugadas.size():
		var node: Node3D = jugadas[i]
		var pila := i / 6
		var alto := i % 6
		var dest: Vector3 = lejos * 0.3 + lado * (pila - (pilas - 1) / 2.0) * (TW + 0.03) + Vector3(0, TABLE_Y + TD / 2 + 0.002 + alto * (TD + 0.001), 0)
		var tw := node.create_tween()
		tw.tween_interval(i * 0.025)
		tw.tween_property(node, "position", dest + Vector3(0, 0.08, 0), 0.22).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(node, "rotation", rot, 0.22)
		tw.tween_property(node, "position", dest, 0.1)
		if alto == 0:
			tw.tween_callback(func(): sfx.emit("clack"))


func _tq_jugadas() -> Array:
	var out: Array = []
	for t in _chain_nodes:
		if is_instance_valid(_chain_nodes[t]):
			out.append(_chain_nodes[t])
	for c in chain_root.get_children():
		if c is Label3D:
			c.queue_free()
	return out


## Al empezar el tranque: la línea se recoge en un bloque en el centro (se sigue
## viendo de fondo) para dejar sitio a las filas de cada uno dentro del tablero.
func tranque_compactar_linea() -> void:
	_tq_linea_recogida = true
	chain_sh.visible = false
	var jugadas := _tq_jugadas()
	var fwd := Vector2(0, -1)    # de ti hacia el centro: se lee desde tu lado
	var side := Vector2(1, 0)
	var face := Quaternion(_flat_basis(fwd))
	var filas := ceili(jugadas.size() / 8.0)
	var dz := TL + 0.012
	var huecos := _grid_slots(jugadas.size(), 8, TW + 0.02, dz, -(filas - 1) * dz / 2.0, fwd, side)
	for i in jugadas.size():
		var node: Node3D = jugadas[i]
		var p2: Vector2 = huecos[i]
		var dest := Vector3(p2.x, TABLE_Y + TD / 2 + 0.002, p2.y)
		var tw := node.create_tween()
		tw.tween_interval(0.3 + i * 0.02)
		tw.tween_property(node, "position", dest + Vector3(0, 0.06, 0), 0.25).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(node, "quaternion", face, 0.25)
		tw.tween_property(node, "position", dest, 0.08)


## Pruebas: cuántas parejas de fichas de la mesa se pisan (huella en el suelo).
func fichas_solapadas() -> Array:
	var cajas: Array = []
	var nodos: Array = []
	for t in _chain_nodes:
		if is_instance_valid(_chain_nodes[t]):
			nodos.append(_chain_nodes[t])
	for s2 in 4:
		for pair in _seat_tiles[s2]:
			if is_instance_valid(pair[0]) and pair[0].visible:
				nodos.append(pair[0])
	for n in nodos:
		# huella real de la ficha (largo y ancho girados con ella), un poco encogida
		var b: Basis = n.global_transform.basis
		var ejes := [b.x * TW, b.y * TL, b.z * TD]
		var ext := Vector2.ZERO
		for e in ejes:
			ext += Vector2(absf(e.x), absf(e.z)) * 0.5
		var c := Vector2(n.global_position.x, n.global_position.z)
		cajas.append(Rect2(c - ext + Vector2(0.004, 0.004), ext * 2.0 - Vector2(0.008, 0.008)))
	var malos: Array = []
	for i in cajas.size():
		for j in range(i + 1, cajas.size()):
			# apiladas a propósito (una encima de otra, a distinta altura): no cuentan
			if absf(nodos[i].global_position.y - nodos[j].global_position.y) > TD * 0.8:
				continue
			if cajas[i].intersects(cajas[j]):
				malos.append([nodos[i].name, nodos[j].name])
	return malos


var _tq_monton_n := 0
signal tq_llega(pips: int, en: Vector2)   # tranque: una ficha aterriza en el montón del ganador


## Acercar la cámara a una ficha y volver (la que decide el tranque).
func tranque_acercar(s: int, i: int) -> void:
	if i < 0 or i >= _seat_tiles[s].size() or not is_instance_valid(_seat_tiles[s][i][0]):
		return
	var objetivo: Vector3 = _seat_tiles[s][i][0].global_position
	var desde := camera.global_transform
	var cerca := desde
	cerca.origin = desde.origin.lerp(objetivo + Vector3(0, 0.25, 0), 0.32)
	var tw := create_tween()
	tw.tween_property(camera, "global_transform", cerca, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.4)
	tw.tween_property(camera, "global_transform", desde, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


## Tras colocar las fichas: los giros y los viajes pendientes, animados.
var _tq_inicios := {}   # silla -> hueco del montón donde empiezan sus fichas


func _tq_inicio_viaje(s: int) -> int:
	return int(_tq_inicios.get(s, 0))


func _tq_animar() -> void:
	if not tranque_on:
		return
	_tq_monton_n = 0
	_tq_inicios.clear()
	for s in 4:
		if not tranque_dados.has(s) or s == tranque_gana:
			continue
		if _tq_monton_n % 7 != 0:
			_tq_monton_n += 1   # un hueco entre lo que dio cada uno
		_tq_inicios[s] = _tq_monton_n
		for pair in _seat_tiles[s]:
			var node: Node3D = pair[0]
			if not is_instance_valid(node):
				continue
			var dest := _tq_monton(_tq_monton_n)
			_tq_monton_n += 1
			var face := Vector3(-PI / 2, atan2(_seat_dir(tranque_gana).x, _seat_dir(tranque_gana).z) + PI, 0)
			if _tq_viajes.has(s):
				# una a una, en arco; cada ficha suma al aterrizar
				var orden_viaje: int = _tq_monton_n - _tq_inicio_viaje(s)
				var pips: int = pair[1].x + pair[1].y if pair[1].x >= 0 else 0
				var medio: Vector3 = node.position.lerp(dest, 0.5) + Vector3(0, 0.18, 0)
				var tw := node.create_tween()
				tw.tween_interval(0.14 * (orden_viaje - 1))
				tw.tween_property(node, "position", medio, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.parallel().tween_property(node, "rotation", face, 0.34)
				tw.tween_property(node, "position", dest, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.tween_callback(func():
					sfx.emit("clack")
					tq_llega.emit(pips, _u(dest)))
			else:
				node.position = dest
				node.rotation = face
	_tq_viajes.clear()
	for key in _tq_giros.keys():
		var partes: PackedStringArray = key.split(":")
		var s := int(partes[0])
		var i := int(partes[1])
		if i >= _seat_tiles[s].size() or not is_instance_valid(_seat_tiles[s][i][0]):
			continue
		var node: Node3D = _seat_tiles[s][i][0]
		var lento: bool = _tq_giros[key]
		var final_r := node.rotation
		var final_p := node.position
		node.rotation = Vector3(final_r.x + PI, final_r.y, final_r.z)   # empieza boca abajo
		var dur := 1.1 if lento else 0.32
		var tw := node.create_tween()
		if lento:
			tw.tween_interval(0.5)   # la cámara llega
		tw.tween_property(node, "position:y", final_p.y + (0.14 if lento else 0.07), dur * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(node, "rotation", final_r, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "position:y", final_p.y, 0.12)
		tw.tween_callback(func(): sfx.emit("slam" if lento else "clack"))
	_tq_giros.clear()


func show_hands_tinted(on: bool, tint := {}) -> void:
	show_all_hands = on
	hand_tint = tint if on else {}
	_sig = ""


func _tint(node: Node, c: Color) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c, 0.45)
	for c2 in node.find_children("*", "MeshInstance3D", true, false):
		(c2 as MeshInstance3D).material_overlay = m
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_overlay = m


func _rebuild(g, legal: Array, selected: int) -> void:
	_clear(hands_root)
	_clear(hand_sh)
	hand_nodes.clear()
	other_hand_nodes.clear()
	_hand_base.clear()
	_seat_tiles = {0: [], 1: [], 2: [], 3: []}
	chain_sh.visible = not _tq_linea_recogida   # recogida en el tranque: sus sombras no
	# tu mano: de pie en tu bandeja
	var n: int = g.hands[0].size()
	for i in n:
		var t: Vector2i = g.hands[0][i]
		var is_legal := legal.has(t)
		var node := _make_tile(t, true, is_legal, true)
		var x := (i - (n - 1) / 2.0) * (TW + 0.01)
		node.position = Vector3(x, TABLE_Y + TL / 2 + 0.01, TRAY)
		node.rotation.x = -0.3
		hands_root.add_child(node)
		hand_nodes.append(node)
		_seat_tiles[0].append([node, t])
		if show_all_hands:
			# tranque: boca arriba sobre la mesa (se leen desde arriba); con el
			# suspenso, boca abajo hasta que la giras
			node.rotation.x = -PI / 2 if not tranque_on or tranque_rev[0].has(i) else PI / 2
			node.position.y = TABLE_Y + TD / 2 + 0.004
			if tranque_on:
				node.position.z = R_TQ
			if hand_tint.has(0):
				_tint(node, hand_tint[0])
		elif pie.standing():
			# de pie, tus fichas se quedan en la mesa boca abajo: nadie las ve
			node.rotation.x = PI / 2
			node.position.y = TABLE_Y + TD / 2 + 0.004
		elif covered.get(0, false):
			node.rotation.x = -1.15   # tapadas: echadas hacia ti
		_hand_base[i] = node.position.y   # tumbadas (tranque, de pie) no se levantan
		_shadow(Vector3(x, TABLE_Y + 0.003, TRAY + 0.01), _flat_basis(Vector2(0, 1)), Vector2(TW + 0.012, TD + 0.03))
		_deal_in(node, 0, i)
	# manos de los demás: de pie en su bandeja, mirando a su dueño
	for s in [1, 2, 3]:
		var dir := _seat_dir(s)
		var right := Vector3(dir.z, 0, -dir.x)
		var m: int = g.hands[s].size()
		for i in m:
			var t: Vector2i = g.hands[s][i]
			var end_reveal: bool = g.phase == "shop" or g.phase == "over"
			var shown: bool = (s == 2 and g.reveal_partner) or g.revealed.has(t) or end_reveal
			# online, las fichas que no puedes ver llegan como (-1, -1): sin cara
			var node := _make_tile(t, t.x >= 0)
			node.position = dir * TRAY + right * (i - (m - 1) / 2.0) * (TW + 0.01) + Vector3(0, TABLE_Y + TL / 2 + 0.01, 0)
			# la cara mira al dueño; revelada, gira hacia el centro
			node.rotation.y = atan2(dir.x, dir.z) + (PI if shown else 0.0)
			node.rotation.x = 0.3 if shown else -0.25
			# tapadas o de pie: tumbadas boca abajo en su bandeja (nadie las ve)
			var up_s: bool = pie.remote.has(s) and pie.remote[s].st != 0 and not end_reveal
			if (covered.get(s, false) or up_s) and not shown:
				node.rotation.x = PI / 2
				node.position.y = TABLE_Y + TD / 2 + 0.004
			node.visible = (not top_view or show_all_hands) and Time.get_ticks_msec() >= int(_bandeja_oculta.get(s, 0))
			if show_all_hands:
				var abajo: bool = tranque_on and not tranque_rev[s].has(i)
				node.rotation = Vector3(PI / 2 if abajo else -PI / 2, atan2(dir.x, dir.z), 0)
				node.position.y = TABLE_Y + TD / 2 + 0.004
				if tranque_on:
					node.position = dir * R_TQ + right * (i - (m - 1) / 2.0) * (TW + 0.01) + Vector3(0, TABLE_Y + TD / 2 + 0.004, 0)
				if hand_tint.has(s):
					_tint(node, hand_tint[s])
			elif end_reveal and _prev_phase == "play":
				# se voltean una a una
				var final_rot := node.rotation
				node.rotation = Vector3(-0.25, final_rot.y - PI, 0)
				var ft := node.create_tween()
				_flip_tweens.append(ft)
				ft.tween_interval(0.5 + i * 0.07 + s * 0.15)
				ft.tween_property(node, "rotation", final_rot, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			hands_root.add_child(node)
			_shadow(Vector3(node.position.x, TABLE_Y + 0.003, node.position.z), _flat_basis(Vector2(dir.x, dir.z)), Vector2(TW + 0.012, TD + 0.03))
			_deal_in(node, s, i)
			other_hand_nodes.append(node)
			_seat_tiles[s].append([node, t])
	_deal_from.clear()
	pool_nodes = []
	pool_taken = {}
	pool_slot = {}
	var csig := str(g.chain, g.origin, g.opener)
	if csig != _chain_sig:
		_chain_sig = csig
		_build_chain(g)
	_tq_animar()   # tranque: giros y fichas que viajan al ganador


## O07: al acabar de robar (también si se acabó el tiempo y nadie recogió),
## cada ficha de las manos sale de donde estaba en la mesa: las que ya cogió
## cada uno desde su bandeja y las que quedaban, desde el montón.
var mesa_activa := true   # hay partida en la mesa (main lo apaga al salir al colmado)
var _deal_from := {}   # silla -> [[posición, giro], …] de donde sale cada ficha
var _dealing_until := 0


func _prepare_deal(g) -> void:
	_deal_from = {0: [], 1: [], 2: [], 3: []}
	var libres: Array = []
	var cogidas := {0: [], 1: [], 2: [], 3: []}   # silla -> [[hueco, posición, giro], …]
	for i in pool_nodes.size():
		var n = pool_nodes[i]
		if not is_instance_valid(n):
			continue
		if pool_taken.has(i) and int(pool_taken[i]) in cogidas:
			cogidas[int(pool_taken[i])].append([int(pool_slot.get(i, i)), n.position, n.quaternion])
		else:
			libres.append([n.position, n.quaternion])
	# por hueco: la ficha i de la mano sale del hueco i de la bandeja, que es
	# donde ya está (antes salían en el orden del montón y se cruzaban)
	for s in 4:
		cogidas[s].sort_custom(func(a, b): return a[0] < b[0])
		for c in cogidas[s]:
			_deal_from[s].append([c[1], c[2]])
	for s in 4:
		while _deal_from[s].size() < g.hands[s].size() and not libres.is_empty():
			_deal_from[s].append(libres.pop_front())
	_sig = ""


func _deal_in(node: Node3D, s: int, i: int) -> void:
	if not _deal_from.has(s) or i >= _deal_from[s].size():
		return
	var p1 := node.position
	var q1 := node.quaternion
	var p0: Vector3 = _deal_from[s][i][0]
	var q0: Quaternion = _deal_from[s][i][1]
	if p0.distance_to(p1) < 0.01:
		return
	node.position = p0
	node.quaternion = q0
	var espera := 0.03 * i + 0.05 * s
	_dealing_until = maxi(_dealing_until, Time.get_ticks_msec() + int((espera + 0.4) * 1000))
	var tw := node.create_tween()
	tw.tween_interval(espera)
	tw.tween_method(func(k: float):
		if not is_instance_valid(node):
			return
		node.position = p0.lerp(p1, k) + Vector3(0, sin(k * PI) * 0.1, 0)
		node.quaternion = q0.slerp(q1, k), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Coloca la línea como en la mesa real: la primera ficha atravesada frente a
## quien salió y la línea recta hacia él y hacia el lado contrario; al llegar
## al borde dobla.
func _build_chain(g) -> void:
	_chain_nodes.clear()
	_marker_sig = ""
	_clear(chain_root)
	_clear(chain_sh)
	end_world.clear()
	if g.chain.is_empty():
		# mesa vacía: olvidar la línea de la mano anterior (si no, sus dos puntas
		# salían como marcas al ir a poner la primera ficha de la mano nueva)
		_prev_chain = []
		_lay = {}
		_marker_sig = ""
		return
	var d3 := _seat_dir(g.opener)
	var axis := Vector2(d3.x, d3.z)
	var perp := Vector2(-axis.y, axis.x)
	var placed: Array = []
	# primera ficha: el doble va atravesado (horizontal para quien sale); una
	# ficha normal va a lo largo de la línea, con su lado izquierdo (x) hacia
	# el brazo izquierdo
	placed = layout_chain(g)
	for p in placed:
		var t: Vector2i = p.t
		var node := _make_tile(t, true)
		node.transform.basis = _flat_basis(p.y)
		var target := Vector3(p.pos.x, TABLE_Y + TD / 2 + 0.002, p.pos.y)
		node.position = target
		chain_root.add_child(node)
		_chain_nodes[t] = node   # para resaltar un chivo y para la cuenta final
		_shadow(Vector3(target.x + 0.006, TABLE_Y + 0.002, target.z + 0.008), node.transform.basis, Vector2(TW + 0.008, TL + 0.008), chain_sh)
		if not _prev_chain.has(t) and not animating:
			_fly_in(node, target, g)
	for side in end_world:
		var info: Dictionary = end_world[side]
		var mk: MeshInstance3D = end_markers[side]
		mk.transform.basis = _flat_basis(info.dir)
		mk.position = Vector3(info.pos.x, TABLE_Y + TD / 2 + 0.004, info.pos.y)
	_prev_chain = g.chain.duplicate()


## La ficha nueva vuela desde la bandeja de quien la jugó y cae con impacto.
func _fly_in(node: Node3D, target: Vector3, g) -> void:
	var seat: int = g.last_seat
	var dir := _seat_dir(seat)
	var right := Vector3(dir.z, 0, -dir.x)
	var start: Vector3 = dir * TRAY + right * randf_range(-0.15, 0.15) + Vector3(0, TL / 2 + TABLE_Y + 0.02, 0)
	if seat == 0 and pending_from != null:
		start = pending_from
	pending_from = null
	var q_end := node.transform.basis.get_rotation_quaternion()
	var q_start := Basis.from_euler(Vector3(-0.3 if seat == 0 else -0.25, atan2(dir.x, dir.z), 0)).get_rotation_quaternion()
	var height := 0.1 if seat == 0 else 0.16
	var final_tile: bool = g.phase != "play"
	node.position = start
	node.quaternion = q_start
	if seat == 0:
		_hand_follow = node
	var tw := node.create_tween()  # muere con la ficha si la mesa se rehace
	tw.tween_method(func(k: float):
		if not is_instance_valid(node):
			return
		node.position = start.lerp(target, k) + Vector3(0, sin(k * PI) * height, 0)
		node.quaternion = q_start.slerp(q_end, min(k * 1.3, 1.0)),
		0.0, 1.0, 0.32 if seat == 0 else 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_look_tile = target
	_look_tile_t = 0.9
	tw.tween_callback(func():
		_impact(target, 1.0 if final_tile else 0.0)
		bump_bulb(1.0 if final_tile else 0.15)
		if _hand_follow == node:
			_hand_follow = null)
	# F11: tiene peso: rebota un poco, se asienta inclinada y queda exacta en la línea
	var rebote := 0.018 if final_tile else 0.01
	var q_tilt := q_end * Quaternion(Vector3(1, 0, 0), randf_range(-0.06, 0.06))
	tw.tween_property(node, "position", target + Vector3(0, rebote, 0), 0.07).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(node, "quaternion", q_tilt, 0.07)
	tw.tween_property(node, "position", target, 0.08).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(node, "quaternion", q_end, 0.1)
	tw.tween_callback(func(): tile_landed.emit(0.0))
	tw.tween_property(node, "position", target + Vector3(0, rebote * 0.25, 0), 0.04)
	tw.tween_property(node, "position", target, 0.05)


const DBL_LIMIT := 0.645  # hasta aquí llega un doble atravesado
# Las filas no pueden ir más pegadas al borde que FAR_LIMIT - TW / 2 (su eje):
# así un doble atravesado en cualquier fila siempre cabe (llega a DBL_LIMIT).
# La línea dobla antes del borde (LAY_LIMIT) para que, si después viene un
# doble, quepa recto y la fila que sale de él siga en zona válida. Si el doble
# de ese número ya está en la mesa no puede venir, así que la ficha sigue
# recta hasta FAR_LIMIT.
const FAR_LIMIT := DBL_LIMIT - TL / 2 + TW / 2
const LAY_LIMIT := FAR_LIMIT - TW - GAP
const DBL_SHIFT := (TL - TW) / 2  # lo que se puede correr un doble y seguir tocando la punta
var _lay_limit := LAY_LIMIT
var _lay_base := LAY_LIMIT   # límite de la ficha que se coloca ahora
var stuck_count := 0   # fichas que tuvieron que salir en escalón (para las pruebas)
var suelta_count := 0   # fichas que fueron al hueco libre (línea encerrada del todo)
var dbl_turn_count := 0  # dobles que tuvieron que girar la esquina (no debería pasar)
var _lay_ok := true


## Huella de una ficha en la mesa (rectángulo alineado): «along» es la medida
## en la dirección de la línea.
func _foot(center: Vector2, d: Vector2, along: float, across: float) -> Rect2:
	var size := Vector2(along, across) if abs(d.x) > 0.5 else Vector2(across, along)
	return Rect2(center - size / 2, size)


const CLEAR := 0.034  # hueco ideal entre fichas que no casan entre sí
const DBL_GAP_MIN := 0.004  # hueco mínimo (aún visible) con el que un doble va recto en vez de girar (O18)
var _gap := CLEAR


## ¿Cabe esta huella? Dentro de la mesa, sin montarse en su vecina de línea
## (prev_id) y dejando un hueco visible con todas las demás fichas.
## Si se da «along» (dirección en que avanza la línea), el límite solo aprieta
## en esa dirección; de lado, una ficha normal llega hasta FAR_LIMIT y un doble
## atravesado hasta DBL_LIMIT (así una fila junto al borde sigue recta y sus
## dobles caben).
func _fits(r: Rect2, occupied: Array, limit := -1.0, prev_id := -99, along := Vector2.ZERO, dbl := true) -> bool:
	if limit < 0.0:
		limit = _lay_limit
	var lx := limit
	var ly := limit
	if along != Vector2.ZERO:
		var side_lim: float = max(limit, DBL_LIMIT if dbl else FAR_LIMIT)
		if abs(along.x) > 0.5:
			ly = side_lim
		else:
			lx = side_lim
	if r.position.x < -lx or r.position.y < -ly or r.end.x > lx or r.end.y > ly:
		return false
	var tight := r.grow(-0.006)
	var wide := r.grow(_gap)
	for o in occupied:
		if o.id == prev_id:
			if tight.intersects(o.r):
				return false
		elif wide.intersects(o.r):
			return false
	return true


# estado de la línea ya colocada: una ficha puesta NO se vuelve a mover
var _lay := {}


## Coloca la línea ficha a ficha, como en la mesa real: cada ficha nueva se
## pone a partir de lo que ya hay y las anteriores no se mueven nunca.
## Devuelve la colocación de todas las fichas de la línea.
func layout_chain(g) -> Array:
	var origin_t: Vector2i = g.chain[g.origin]
	var left_n: int = g.origin
	var right_n: int = g.chain.size() - g.origin - 1
	var same: bool = not _lay.is_empty() and _lay.origin_t == origin_t and _lay.opener == g.opener \
		and left_n >= _lay.arms[1].i and right_n >= _lay.arms[0].i \
		and _lay.chain == g.chain.slice(left_n - _lay.arms[1].i, left_n - _lay.arms[1].i + _lay.chain.size())
	if not same:
		_new_layout(g)
	var right_arm: Array = g.chain.slice(g.origin + 1)
	var left_arm: Array = g.chain.slice(0, g.origin)
	left_arm.reverse()
	var arms_t := [right_arm, left_arm]
	# solo se colocan las fichas nuevas (normalmente una)
	var pending := true
	while pending:
		pending = false
		for k in 2:
			var a: Dictionary = _lay.arms[k]
			if a.i < arms_t[k].size():
				_place_robust(a, arms_t[k][a.i], k == 0)
				a.i += 1
				pending = true
	_lay.chain = g.chain.duplicate()
	_lay.ends = [g.right_end, g.left_end]
	# puntas donde iría la siguiente ficha
	end_world.clear()
	for k in 2:
		var probe: Dictionary = _lay.arms[k].duplicate()
		var info := _spot_robust(probe, false)
		end_world[[1, -1][k]] = {"pos": info.center, "dir": info.d}
	var out: Array = []
	for t in g.chain:
		out.append(_lay.placed[t])
	return out


func _new_layout(g) -> void:
	var d3 := _seat_dir(g.opener)
	var axis := Vector2(d3.x, d3.z)
	var perp := Vector2(-axis.y, axis.x)
	var first: Vector2i = g.chain[g.origin]
	var first_dbl: bool = first.x == first.y
	var along0: float = TW if first_dbl else TL
	_lay = {
		"origin_t": first, "opener": g.opener, "chain": [first],
		"occupied": [{"r": _foot(Vector2.ZERO, axis, along0, TL if first_dbl else TW), "arm": -1, "id": 0}],
		"placed": {first: {"t": first, "pos": Vector2.ZERO, "y": perp if first_dbl else -axis}},
		"arms": [],
	}
	for k in 2:
		var d: Vector2 = axis * (1 if k == 0 else -1)
		var own: Vector2 = perp * (1 if k == 0 else -1)
		_lay.arms.append({"d": d, "cur": d * (along0 / 2), "last_dbl": first_dbl, "last_center": Vector2.ZERO,
			"i": 0, "k": k, "own": own, "prev_id": 0, "turns": 0})
	_lay.chain = g.chain.slice(g.origin, g.origin + 1)


## Busca sitio para la siguiente ficha relajando poco a poco el hueco y el
## margen del borde; nunca la saca del tablero.
func _spot_robust(a: Dictionary, dbl: bool) -> Dictionary:
	# primero todo con hueco visible entre fichas (normal, escalón, búsqueda
	# fina); solo si no hay manera se aprieta el hueco
	for gaps in [[CLEAR, 0.02, 0.013], [0.008, 0.0]]:
		var info = _spot_normal(a, dbl, gaps)
		if info != null:
			return info
		info = _spot_stuck(a, dbl, gaps)
		if info != null:
			return info
	# encerrada del todo: como en la mesa de verdad, va al hueco libre más
	# cercano a la punta antes que montarla encima de otra
	var hueco = _spot_libre(a, dbl)
	if hueco != null:
		hueco.suelta = true
		return hueco
	_gap = CLEAR
	_lay_limit = LAY_LIMIT
	var info2 := _next_spot(a, dbl, _lay.occupied)
	info2.stuck = true
	var lim2 := BOARD - TL / 2 - 0.004
	info2.center = info2.center.clamp(Vector2(-lim2, -lim2), Vector2(lim2, lim2))
	return info2


func _spot_libre(a: Dictionary, dbl: bool):
	var ext: float = TW if dbl else TL
	var across: float = TL if dbl else TW
	var best = null
	var best_d := INF
	for gap in [0.013, 0.0]:
		_gap = gap
		var p := -DBL_LIMIT
		while p <= DBL_LIMIT:
			var q := -DBL_LIMIT
			while q <= DBL_LIMIT:
				var c := Vector2(p, q)
				var dist: float = c.distance_to(a.cur)
				if dist < best_d:
					for dd in [a.d, Vector2(-a.d.y, a.d.x)]:
						if _fits(_foot(c, dd, ext, across), _lay.occupied, DBL_LIMIT, -99):
							best_d = dist
							best = {"center": c, "d": dd, "turned": dd != a.d, "stuck": true}
							break
				q += 0.01
			p += 0.01
		if best != null:
			break
	_gap = CLEAR
	return best


## Colocación normal (recta o doblando) con los huecos dados, relajando el
## margen del borde.
func _spot_normal(a: Dictionary, dbl: bool, gaps: Array):
	var occ: Array = _lay.occupied
	for gap in gaps:
		for lim in [_lay_base, (_lay_base + DBL_LIMIT) / 2, DBL_LIMIT]:
			_gap = gap
			_lay_limit = lim
			_lay_ok = true
			var info := _next_spot(a, dbl, occ)
			if _lay_ok:
				_gap = CLEAR
				_lay_limit = LAY_LIMIT
				return info
	_gap = CLEAR
	_lay_limit = LAY_LIMIT
	return null


## Línea encerrada: salir en escalón (desplazada de lado, tocando la punta) o,
## si no, en cualquier sitio pegado a la ficha anterior (punta o costado).
func _spot_stuck(a: Dictionary, dbl: bool, gaps: Array):
	var occ: Array = _lay.occupied
	var ext: float = TW if dbl else TL
	var across: float = TL if dbl else TW
	var tip: Vector2 = a.cur
	for gap in gaps:
		_gap = maxf(gap, 0.0)
		for dd in [a.d, Vector2(-a.d.y, a.d.x), Vector2(a.d.y, -a.d.x)]:
			var side_v := Vector2(-dd.y, dd.x)
			for off in [0.0, TW / 2, -TW / 2, TW, -TW, TL / 2, -TL / 2]:
				var c: Vector2 = tip + dd * (ext / 2 + GAP) + side_v * off
				if dd != a.d:
					c = a.last_center + dd * ((TL if a.last_dbl else TW) / 2 + ext / 2 + GAP) + side_v * off
				if _fits(_foot(c, dd, ext, across), occ, DBL_LIMIT, a.prev_id):
					_gap = CLEAR
					return {"center": c, "d": dd, "turned": dd != a.d, "stuck": true}
		var pr: Rect2 = occ[a.prev_id].r
		for dd in [a.d, Vector2(-a.d.y, a.d.x), Vector2(a.d.y, -a.d.x)]:
			var side_v := Vector2(-dd.y, dd.x)
			var half_prev: float = pr.size.x / 2 if abs(dd.x) > 0.5 else pr.size.y / 2
			var half_side: float = pr.size.y / 2 if abs(dd.x) > 0.5 else pr.size.x / 2
			var base: Vector2 = pr.get_center() + dd * (half_prev + ext / 2 + GAP)
			var reach: float = half_side + across / 2 - 0.01
			var off := 0.0
			while off <= reach:
				for sg in [1.0, -1.0]:
					var c: Vector2 = base + side_v * off * sg
					if _fits(_foot(c, dd, ext, across), occ, DBL_LIMIT, a.prev_id):
						_gap = CLEAR
						return {"center": c, "d": dd, "turned": dd != a.d, "stuck": true}
				off += 0.005
	_gap = CLEAR
	return null


func _place_robust(a: Dictionary, t: Vector2i, x_inner: bool) -> void:
	var dbl: bool = t.x == t.y
	_lay_base = _limit_for(t.y if a.k == 0 else t.x)
	var info := _spot_robust(a, dbl)
	if info.get("stuck", false):
		stuck_count += 1  # solo fichas puestas; las sondas de puntas no cuentan
	if info.get("suelta", false):
		suelta_count += 1
	_lay_base = LAY_LIMIT
	var d: Vector2 = info.d
	if info.turned:
		a.turns += 1
		if dbl:
			dbl_turn_count += 1
	var ext: float = TW if dbl else TL
	var across: float = TL if dbl else TW
	var center: Vector2 = info.center
	var yv: Vector2 = Vector2(-d.y, d.x) if dbl else (-d if x_inner else d)
	_lay.placed[t] = {"t": t, "pos": center, "y": yv}
	var id: int = _lay.occupied.size()
	_lay.occupied.append({"r": _foot(center, d, ext, across), "arm": a.k, "id": id})
	a.prev_id = id
	a.d = d
	a.cur = center + d * (ext / 2 + GAP)
	a.last_dbl = dbl
	a.last_center = center


## Límite de la línea para una ficha que deja abierto el número n: sin
## reserva si el doble de n ya se jugó (no puede venir detrás).
func _limit_for(n: int) -> float:
	return FAR_LIMIT if _lay.placed.has(Vector2i(n, n)) else LAY_LIMIT


## Cuántas fichas más cabrían en línea recta desde aquí (para no encerrarse).
func _runway(center: Vector2, d: Vector2, ext: float, occupied: Array) -> int:
	var cur := center + d * (ext / 2 + GAP)
	var n := 0
	for k in 9:
		var c := cur + d * (TL / 2 + GAP)
		if not _fits(_foot(c, d, TL, TW), occupied, -1.0, -99, d, false):
			break
		n += 1
		cur = c + d * (TL / 2 + GAP)
	return n


const REACH_CELL := TW / 2
const REACH_CAP := 220   # a partir de aquí sobra sitio: no distingue más
const REACH_W := 0.25


## Sitio libre (en celdas) al que puede llegar la línea si pone una ficha en c
## mirando hacia d: rellena la mesa desde la punta de esa ficha por donde
## cabría el centro de otra ficha (a media ficha de todo lo ocupado y del borde).
func _reach(c: Vector2, d: Vector2, ext: float, across: float, occupied: Array) -> int:
	var n := int(ceil(DBL_LIMIT * 2 / REACH_CELL))
	var lim := DBL_LIMIT - TW / 2
	var blocks: Array = []
	var pad := TW / 2 + 0.006
	for o in occupied:
		blocks.append(o.r.grow(pad))
	blocks.append(_foot(c, d, ext, across).grow(pad))
	var free := PackedByteArray()
	free.resize(n * n)
	for iy in n:
		for ix in n:
			var p := Vector2(-DBL_LIMIT + (ix + 0.5) * REACH_CELL, -DBL_LIMIT + (iy + 0.5) * REACH_CELL)
			var ok: bool = abs(p.x) <= lim and abs(p.y) <= lim
			if ok:
				for b in blocks:
					if b.has_point(p):
						ok = false
						break
			free[iy * n + ix] = 1 if ok else 0
	# empieza justo delante de la punta de la ficha nueva
	var tip := c + d * (ext / 2 + TW / 2 + 0.008)
	var sx := int(floor((tip.x + DBL_LIMIT) / REACH_CELL))
	var sy := int(floor((tip.y + DBL_LIMIT) / REACH_CELL))
	if sx < 0 or sy < 0 or sx >= n or sy >= n or free[sy * n + sx] == 0:
		return 0
	var count := 0
	var stack: Array = [sy * n + sx]
	free[sy * n + sx] = 0
	while not stack.is_empty() and count < REACH_CAP:
		var i: int = stack.pop_back()
		count += 1
		var x := i % n
		var y := i / n
		for nb in [[x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]]:
			if nb[0] >= 0 and nb[1] >= 0 and nb[0] < n and nb[1] < n:
				var j: int = nb[1] * n + nb[0]
				if free[j] == 1:
					free[j] = 0
					stack.append(j)
	return count


## ¿Cabría un doble atravesado justo detrás de una ficha puesta en c (recto o
## corrido de lado, como lo colocaría _next_spot)?
func _dbl_cabe_tras(c: Vector2, d: Vector2, ext: float, across: float, occupied: Array) -> bool:
	var occ: Array = occupied.duplicate()
	occ.append({"r": _foot(c, d, ext, across), "arm": -2, "id": -7})
	var dc: Vector2 = c + d * (ext / 2 + GAP + TW / 2)
	var side_v := Vector2(-d.y, d.x)
	for off in [0.0, DBL_SHIFT, -DBL_SHIFT, DBL_SHIFT / 2, -DBL_SHIFT / 2]:
		if _fits(_foot(dc + side_v * off, d, TW, TL), occ, DBL_LIMIT, -7):
			return true
	return false


## Distancia de un punto a la ficha más cercana del otro brazo.
func _clearance(p: Vector2, occupied: Array, k: int) -> float:
	var best := 9.0
	for o in occupied:
		if o.arm != k and o.arm != -1:
			best = min(best, p.distance_to(o.r.get_center()))
	return best


## Dónde va la siguiente ficha: recta si cabe; si no, dobla. Los dobles van
## siempre atravesados y no doblan (usan la franja del borde).
func _next_spot(a: Dictionary, dbl: bool, occupied: Array) -> Dictionary:
	var d: Vector2 = a.d
	var ext: float = TW if dbl else TL
	var across: float = TL if dbl else TW
	var prev: int = a.prev_id
	var straight: Vector2 = a.cur + d * (ext / 2 + GAP)
	# si recta cabe pero detrás no cabría el doble que aún puede venir, mejor
	# doblar ya (con esta ficha normal); si no hay vuelta mejor, recta
	var fallback = null
	if _fits(_foot(straight, d, ext, across), occupied, -1.0, prev, d, dbl):
		if dbl or _lay_base >= FAR_LIMIT or _dbl_cabe_tras(straight, d, ext, across, occupied):
			return {"center": straight, "d": d, "turned": false}
		fallback = {"center": straight, "d": d, "turned": false}
	if dbl and _fits(_foot(straight, d, ext, across), occupied, DBL_LIMIT, prev):
		return {"center": straight, "d": d, "turned": false}
	# un doble sin sitio de lado: atravesado pero corrido hacia el lado libre,
	# sin dejar de tocar entera la punta de la ficha anterior (nunca gira)
	if dbl:
		var side_v := Vector2(-d.y, d.x)
		for off in [DBL_SHIFT, -DBL_SHIFT, DBL_SHIFT / 2, -DBL_SHIFT / 2]:
			var c: Vector2 = straight + side_v * off
			if _fits(_foot(c, d, ext, across), occupied, DBL_LIMIT, prev):
				return {"center": c, "d": d, "turned": false}
		# O18: un doble que gira la esquina queda raro y la ficha siguiente sale
		# en escalón. Casi siempre cabe recto si se acepta un hueco menor con
		# las fichas de al lado (la línea viene enroscada): mejor eso, mientras
		# el hueco se siga viendo
		if _gap > DBL_GAP_MIN:
			var g0 := _gap
			_gap = DBL_GAP_MIN
			for off in [0.0, DBL_SHIFT, -DBL_SHIFT, DBL_SHIFT / 2, -DBL_SHIFT / 2]:
				var c: Vector2 = straight + side_v * off
				if _fits(_foot(c, d, ext, across), occupied, DBL_LIMIT, prev):
					_gap = g0
					return {"center": c, "d": d, "turned": false}
			_gap = g0
	# doblar: candidatos a los dos lados, con el límite normal y luego el amplio
	for lim in [-1.0, DBL_LIMIT]:
		var best = null
		var best_score := -INF
		for sgn in [1, -1]:
			var nd: Vector2 = Vector2(-d.y, d.x) * sgn
			var start: Vector2 = a.last_center + nd * (TL / 2) if a.last_dbl else a.cur - d * (TW / 2) + nd * (TW / 2)
			var c2: Vector2 = start + nd * (ext / 2 + GAP)
			if not _fits(_foot(c2, nd, ext, across), occupied, lim, prev):
				continue
			# Al salir de un doble, reservar el doble del nuevo número también
			# cuando la recta ya no cabe. Evita encerrar dos dobles en la esquina.
			if (fallback != null or a.last_dbl) and not dbl and _lay_base < FAR_LIMIT and not _dbl_cabe_tras(c2, nd, ext, across, occupied):
				continue
			var score := _clearance(c2, occupied, a.k) * 4.0 + _runway(c2, nd, ext, occupied) * 3.0
			# no meterse en un hueco que se cierra: cuenta el sitio libre al que
			# puede llegar la línea por ese lado
			score += min(_reach(c2, nd, ext, across, occupied), REACH_CAP) * REACH_W
			if a.turns == 0 and nd.dot(a.own) > 0.0:
				score += 10.0  # la primera vuelta, hacia su propia mitad
			# preferir no acercarse al centro de la mesa (donde crece el otro brazo)
			score -= max(0.0, -(c2 + nd * 0.2).dot(a.own)) * 2.0
			if score > best_score:
				best_score = score
				best = {"center": c2, "d": nd, "turned": true, "start": start}
		if best != null:
			return best
	if fallback != null:
		return fallback
	_lay_ok = false  # sin hueco: esta forma de colocar no sirve
	return {"center": straight, "d": d, "turned": false}


func _place_next(a: Dictionary, t: Vector2i, x_inner: bool, placed: Array, occupied: Array) -> void:
	var dbl: bool = t.x == t.y
	var info := _next_spot(a, dbl, occupied)
	var d: Vector2 = info.d
	if info.turned:
		a.cur = info.start
		a.turns += 1
	var ext: float = TW if dbl else TL
	var across: float = TL if dbl else TW
	var center: Vector2 = a.cur + d * (ext / 2 + GAP)
	var yv: Vector2 = Vector2(-d.y, d.x) if dbl else (-d if x_inner else d)
	placed.append({"t": t, "pos": center, "y": yv})
	var id := occupied.size()
	occupied.append({"r": _foot(center, d, ext, across), "arm": a.k, "id": id})
	a.prev_id = id
	a.d = d
	a.cur = center + d * (ext / 2 + GAP)
	a.last_dbl = dbl
	a.last_center = center


# ---------------------------------------------------------------- barajar

func _start_shuffle(g) -> void:
	_stop_count()
	counted_hand = -1
	animating = true
	var token := _shuffled_hand
	# recoger: todas las fichas de la mano anterior se deslizan boca abajo al centro
	var old: Array = chain_root.get_children() + hands_root.get_children()
	_clear(hand_sh)
	_clear(chain_sh)
	if not old.is_empty():
		for c in old:
			var a := randf() * TAU
			var r := randf_range(0.02, 0.22)
			var gt: Tween = c.create_tween().set_parallel(true)
			gt.tween_property(c, "position", Vector3(cos(a) * r, TABLE_Y + TD / 2 + 0.002, sin(a) * r), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			gt.tween_property(c, "quaternion", _flat_basis(Vector2(cos(a), sin(a)), false).get_rotation_quaternion(), 0.45)
		for s in [1, 2, 3]:
			heads[s].act("play")
		_hand_anim = {"kind": "shuffle", "arm": "r", "t": 0.6}
		await get_tree().create_timer(0.55).timeout
	if token != _shuffled_hand:
		return
	_clear(hands_root)
	_clear(chain_root)
	_chain_sig = ""
	hand_nodes.clear()
	var nodes: Array = []
	var pool_src: Array = g.pool if g.pool.size() == 28 else []
	for i in 28:
		var node := _make_tile(pool_src[i] if not pool_src.is_empty() else Vector2i.ZERO, not pool_src.is_empty())
		var a := randf() * TAU
		var r := randf_range(0.02, 0.3)
		node.transform.basis = _flat_basis(Vector2(cos(a), sin(a)), false)
		node.position = Vector3(cos(a) * r, TABLE_Y + TD / 2 + 0.002, sin(a) * r)
		hands_root.add_child(node)
		nodes.append(node)
	# las fichas giran revueltas por la mesa
	var tw := create_tween().set_parallel(true)
	for node in nodes:
		var p0: Vector3 = node.position
		var steps := 4
		var chain_tw: Tween = node.create_tween()
		for k in steps:
			var a := randf() * TAU
			var r := randf_range(0.05, 0.38)
			var p := Vector3(cos(a) * r, p0.y, sin(a) * r)
			chain_tw.tween_property(node, "position", p, 0.3).set_trans(Tween.TRANS_SINE)
			chain_tw.parallel().tween_property(node, "rotation:y", node.rotation.y + randf_range(-2.5, 2.5), 0.3)
	tw.tween_interval(1.25)
	shuffle_started.emit()
	for s in [1, 2, 3]:
		heads[s].act("shuffle")
	_hand_anim = {"kind": "shuffle", "arm": "r", "t": 0.0}
	await get_tree().create_timer(1.3).timeout
	if token != _shuffled_hand:
		return
	# quedan boca abajo esparcidas por la mesa para que cada uno elija las suyas
	var cells: Array = []
	for cx in 7:
		for cz in 4:
			cells.append(Vector3(-0.42 + cx * 0.14 + randf_range(-0.025, 0.025), TABLE_Y + TD / 2 + 0.002, -0.27 + cz * 0.18 + randf_range(-0.03, 0.03)))
	cells.shuffle()
	# saliste al colmado en mitad del barajeo: las fichas ya no existen
	if nodes.any(func(n): return not is_instance_valid(n)):
		return
	for k in 28:
		var node: Node3D = nodes[k]
		var spread := node.create_tween().set_parallel(true)
		var a := randf_range(-0.5, 0.5) + (PI / 2 if randf() < 0.5 else 0.0)
		spread.tween_property(node, "position", cells[k], 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		spread.tween_property(node, "quaternion", _flat_basis(Vector2(cos(a), sin(a)), false).get_rotation_quaternion(), 0.3)
	await get_tree().create_timer(0.35).timeout
	if token != _shuffled_hand:
		return
	pool_nodes = nodes
	pool_taken = {}
	pool_slot = {}
	animating = false
	if g.phase != "draw":
		_sig = ""
	_prev_chain = g.chain.duplicate()


# ---------------------------------------------------------------- robar

## Ficha boca abajo bajo el cursor (índice de g.pool) o -1.
func pool_tile_at(p: Vector2) -> int:
	var best := -1
	var best_d := 18.0
	for i in pool_nodes.size():
		if pool_taken.has(i) or not is_instance_valid(pool_nodes[i]):
			continue
		var d := p.distance_to(_u(pool_nodes[i].position))
		if d < best_d:
			best_d = d
			best = i
	return best


## La ficha elegida vuela a la bandeja de quien la cogió.
func take_pool_tile(idx: int, seat: int, slot: int) -> void:
	# online puede llegar antes de que termine de barajar: sin ficha, no se marca
	# (el siguiente estado del servidor la vuelve a traer)
	if idx < 0 or idx >= pool_nodes.size() or not is_instance_valid(pool_nodes[idx]):
		return
	pool_taken[idx] = seat
	pool_slot[idx] = slot
	var node: Node3D = pool_nodes[idx]
	node.scale = Vector3.ONE   # la señalada estaba agrandada: a la bandeja va a su tamaño
	var dir := _seat_dir(seat)
	var right := Vector3(dir.z, 0, -dir.x)
	var target: Vector3
	var rot: Vector3
	if seat == 0:
		# un poco hacia la mesa e inclinadas hacia ti: ves cuáles te tocaron
		target = Vector3((slot - 3) * (TW + 0.012), TABLE_Y + TL / 2 + 0.03, TRAY - 0.08)
		rot = Vector3(-0.75, 0, 0)
	else:
		target = dir * TRAY + right * (slot - 3) * (TW + 0.01) + Vector3(0, TABLE_Y + TL / 2 + 0.01, 0)
		rot = Vector3(-0.25, atan2(dir.x, dir.z), 0)
	var start := node.position
	var q0 := node.quaternion
	var q1 := Basis.from_euler(rot).get_rotation_quaternion()
	if seat == 0:
		_hand_follow = node
	else:
		heads[seat].act("play")
	var tw := node.create_tween()
	tw.tween_method(func(k: float):
		if not is_instance_valid(node):
			return
		node.position = start.lerp(target, k) + Vector3(0, sin(k * PI) * 0.12, 0)
		node.quaternion = q0.slerp(q1, k), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		if _hand_follow == node:
			_hand_follow = null)
	sfx.emit("pick")


## Online: la ficha del montón que cogiste se cambia por una de cara (antes de
## llevarla a tu bandeja; el servidor solo te dice cuáles son las tuyas).
func pool_cara(idx: int, t: Vector2i) -> void:
	if idx < 0 or idx >= pool_nodes.size() or not is_instance_valid(pool_nodes[idx]):
		return
	var viejo: Node3D = pool_nodes[idx]
	var nuevo := _make_tile(t, true)
	nuevo.set_meta("cara", true)
	viejo.get_parent().add_child(nuevo)
	nuevo.transform = viejo.transform
	pool_nodes[idx] = nuevo
	viejo.queue_free()


var _pool_aro: MeshInstance3D = null   # marco dorado bajo la ficha que señalas
var _aro_idx := -1


## El marco no se queda en la mesa: fuera de la fase de robar, o si esa ficha ya
## se cogió (aunque el puntero no se mueva), se esconde.
func pool_aro_revisar(robando: bool) -> void:
	if _pool_aro == null or not _pool_aro.visible:
		return
	if not robando or _aro_idx < 0 or pool_taken.has(_aro_idx) or _aro_idx >= pool_nodes.size() or not is_instance_valid(pool_nodes[_aro_idx]):
		_pool_aro.visible = false
		_aro_idx = -1


func pool_hover(p: Vector2) -> void:
	var h := pool_tile_at(p)
	for i in pool_nodes.size():
		if pool_taken.has(i) or not is_instance_valid(pool_nodes[i]):
			continue
		var n: Node3D = pool_nodes[i]
		# la que señalas sube, crece un poco y lleva un marco dorado debajo
		n.position.y = lerp(n.position.y, TABLE_Y + TD / 2 + 0.002 + (0.055 if i == h else 0.0), 0.5)
		n.scale = n.scale.lerp(Vector3.ONE * (1.2 if i == h else 1.0), 0.5)
	if _pool_aro == null:
		_pool_aro = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(TW + 0.04, 0.004, TL + 0.04)
		_pool_aro.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.82, 0.25)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_pool_aro.material_override = mat
		add_child(_pool_aro)
	var hay: bool = h >= 0 and not pool_taken.has(h) and is_instance_valid(pool_nodes[h])
	_pool_aro.visible = hay
	_aro_idx = h if hay else -1
	if hay:
		var n: Node3D = pool_nodes[h]
		_pool_aro.global_basis = Basis(Vector3.UP, n.global_basis.get_euler().y)
		_pool_aro.global_position = Vector3(n.global_position.x, TABLE_Y + TD + 0.004, n.global_position.z)


# ---------------------------------------------------------------- cámara

## Sentado: hacia dónde miras además de la mesa (x = giro, y = cabeceo, en
## radianes). Se aplica sobre la cámara normal; desde arriba no.
var seat_look := Vector2.ZERO
var _seat_look_on := false


func apply_seat_look(allowed: bool) -> void:
	if not allowed or top_view:
		if top_view:
			seat_look = Vector2.ZERO
		_seat_look_on = false
		return
	if seat_look == Vector2.ZERO and not _seat_look_on:
		return   # sin mirada libre: la cámara es de quien la mueva (tweens, menús)
	var b := _cam_normal.basis.rotated(Vector3.UP, seat_look.x)
	b = b.rotated(b.x, seat_look.y)
	camera.global_transform = Transform3D(b, _cam_normal.origin)
	_seat_look_on = seat_look != Vector2.ZERO


func toggle_top() -> void:
	set_top(not top_view)


func set_top(v: bool) -> void:
	# desde arriba, la bombilla y su cable quedarían justo delante de la cámara
	sphere.visible = not v
	bulb_wire.visible = not v
	if v == top_view:
		return
	top_view = v
	_sig = ""
	sphere.visible = not v
	var tw := create_tween()
	tw.tween_property(camera, "global_transform", (_cam_tq if tranque_on else _cam_top) if v else _cam_normal, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func hits_table(p: Vector2) -> bool:
	var o := camera.project_ray_origin(p * px_scale)
	var n := camera.project_ray_normal(p * px_scale)
	if abs(n.y) < 0.001:
		return false
	var k := (TABLE_Y - o.y) / n.y
	if k < 0:
		return false
	var hit := o + n * k
	return abs(hit.x) < BOARD and abs(hit.z) < BOARD


# ---------------------------------------------------------------- pantalla

## Reacciones de la mesa a lo que pasa.
func react(e: Dictionary, g) -> void:
	match e.k:
		"pass":
			var passer: int = e.seat
			var partner := (passer + 2) % 4
			# su compañero se lleva la mano a la cabeza
			if partner != 0:
				heads[partner].act("facepalm")
			# quien le tapó (si es rival) se ríe
			var by: int = e.get("by", -1)
			if by > 0 and by % 2 != passer % 2:
				get_tree().create_timer(0.25).timeout.connect(func(): heads[by].act("laugh"))
		"chivo_caught":
			var cheater: int = e.cheater
			if cheater != 0:
				heads[cheater].act("facepalm")
			if e.seat != 0:
				heads[e.seat].act("standup")
		"chivo_false":
			if e.seat != 0:
				heads[e.seat].act("facepalm")
			for s2 in [1, 2, 3]:
				if s2 % 2 != e.seat % 2:
					heads[s2].act("laugh")
		"end":
			var r: Dictionary = g.last_result
			if r.reason == "chivo":
				return
			if r.get("capicua", false):
				# ¡capicúa! todos de pie
				for s in [1, 2, 3]:
					var d: float = 0.15 * s
					get_tree().create_timer(0.5 + d).timeout.connect(func(): heads[s].act("standup"))
			else:
				for s in [1, 2, 3]:
					if s % 2 != r.team:
						get_tree().create_timer(0.7).timeout.connect(func(): heads[s].act("facepalm"))


func on_event(e: Dictionary) -> void:
	if e.seat == 0:
		match e.k:
			"pass":
				hand_act("tap")
			"drink":
				hand_act("drink", e.id)
		return
	match e.k:
		"play":
			heads[e.seat].act("play")
		"drink":
			heads[e.seat].drink(e.id)
		"pass":
			heads[e.seat].act("tap")
		"end":
			heads[e.seat].act("slam")


func hand_rects() -> Array:
	var res: Array = []
	for node in hand_nodes:
		var pts: Array = []
		for cx in [-1, 1]:
			for cy in [-1, 1]:
				pts.append(_u(node.to_global(Vector3(cx * TW / 2, cy * TL / 2, 0))))
		var r := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			r = r.expand(p)
		res.append(r.grow(2))
	return res


func end_screen_pos(side: int) -> Vector2:
	if not end_world.has(side):
		return Vector2(-999, -999)
	var p: Vector2 = end_world[side].pos
	return _u(Vector3(p.x, TABLE_Y, p.y))


## Encima de la cabeza (para la placa con el nombre).
func plate_screen_pos(s: int) -> Vector2:
	return _u(heads[s].global_position + Vector3(0, 0.78, 0))


## Centro de la bandeja de una silla en pantalla (con la cámara de ahora).
func tray_screen_pos(s: int) -> Vector2:
	return _u(_seat_dir(s) * TRAY + Vector3(0, TABLE_Y, 0))


func seat_screen_pos(s: int) -> Vector2:
	var p: Vector3 = Vector3(0, TABLE_Y + 0.2, 0.6) if s == 0 else heads[s].global_position + Vector3(0, 0.2, 0)
	if s == 0 and pie.standing():
		return Vector2(_cx(), 250)   # de pie, tus avisos salen delante de ti
	if camera.is_position_behind(p):
		return Vector2(_cx(), 120)   # a tu espalda: el aviso, arriba en el centro (no reflejado)
	return _u(p)


# ---------------------------------------------------------------- aura de pases

## Aura de quien puso la última ficha mientras los demás pasan: nivel 1 suave
## (pasó uno), 2 más grande (pasaron dos) y 3 épica (no fue nadie: +30).
## Nivel 0 la apaga. Se ve alrededor del cuerpo; la tuya, al borde de tu mesa.
var _auras := {}   # silla -> {root, level}
const AURA_COL := [Color(1.0, 0.82, 0.3), Color(1.0, 0.6, 0.15), Color(1.0, 0.35, 0.9)]


func set_aura(s: int, level: int) -> void:
	for k in _auras.keys():
		if k != s or level <= 0:
			_drop_aura(k)
	if level <= 0:
		return
	if _auras.has(s) and _auras[s].level == level:
		return
	_drop_aura(s)
	var root := Node3D.new()
	add_child(root)
	# la tuya va por el borde de tu lado de la mesa, más fina (está junto a la cámara)
	var near := s == 0
	var sz := 0.45 if near else 1.0
	if near:
		root.position = Vector3(0, TABLE_Y + 0.01, 0.9)
	else:
		root.position = heads[s].global_position + Vector3(0, 0.05, 0)
	var col: Color = AURA_COL[clampi(level - 1, 0, 2)]
	var k := float(level)
	# llamas que suben alrededor del cuerpo
	var fl := _aura_particles(col, int((10 + 18 * k * k * 0.6) * (0.6 if near else 1.0)), (0.6 + 0.25 * k) * (0.6 if near else 1.0), Vector3(0.22 + 0.05 * k, 0.32, 0.16 + 0.04 * k) if not near else Vector3(0.7, 0.01, 0.04), sz)
	fl.gravity = Vector3(0, (0.5 + 0.35 * k) * (0.4 if near else 1.0), 0)
	root.add_child(fl)
	fl.emitting = true
	# luz que late
	var lt := OmniLight3D.new()
	lt.light_color = col
	lt.light_energy = (0.4 + 0.45 * k) * (0.3 if near else 1.0)
	lt.omni_range = (0.7 + 0.35 * k) * (0.6 if near else 1.0)
	lt.position = Vector3(0, 0.35, 0)
	root.add_child(lt)
	if level >= 2:
		# chispas rápidas
		var sp := _aura_particles(Color(1, 0.95, 0.7), int(14 * level * (0.5 if near else 1.0)), 0.45 * (0.6 if near else 1.0), Vector3(0.3, 0.3, 0.2) if not near else Vector3(0.7, 0.01, 0.04), sz)
		sp.initial_velocity_min = 0.6
		sp.initial_velocity_max = 1.2
		sp.spread = 60.0
		sp.scale_amount_min = 0.3
		sp.scale_amount_max = 0.6
		root.add_child(sp)
		sp.emitting = true
	if level >= 3:
		# anillos de energía que se abren desde el suelo, uno tras otro
		var ring_timer := Timer.new()
		ring_timer.wait_time = 0.35
		ring_timer.autostart = true
		root.add_child(ring_timer)
		ring_timer.timeout.connect(func(): _aura_ring(root, col, sz))
		_aura_ring(root, col, sz)
	# entrada con fuerza
	root.scale = Vector3.ONE * 0.4
	root.create_tween().tween_property(root, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# la luz late en _tick_auras (un tween en bucle se queda colgado al borrar el aura)
	_auras[s] = {"root": root, "level": level, "light": lt, "base": lt.light_energy}
	sfx.emit("aura%d" % level)


func _tick_auras() -> void:
	for a in _auras.values():
		if is_instance_valid(a.light):
			a.light.light_energy = a.base * (1.3 + 0.3 * sin(_t * (8.0 + 3.0 * a.level)))


func _drop_aura(s: int) -> void:
	if not _auras.has(s):
		return
	var root: Node3D = _auras[s].root
	_auras.erase(s)
	if not is_instance_valid(root):
		return
	for c in root.get_children():
		if c is CPUParticles3D:
			c.emitting = false
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * 0.01, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)


func _aura_particles(col: Color, amount: int, life: float, box: Vector3, sz := 1.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.03 * sz
	p.mesh = m
	var pm := StandardMaterial3D.new()
	pm.albedo_color = col
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pm.vertex_color_use_as_albedo = true
	p.material_override = pm
	p.amount = max(amount, 4)
	p.lifetime = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.35
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(col.lightened(0.4), 1.0))
	ramp.set_color(1, Color(col, 0.0))
	p.color_ramp = ramp
	return p


func _aura_ring(root: Node3D, col: Color, sz := 1.0) -> void:
	if not is_instance_valid(root):
		return
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.2 * sz
	tm.outer_radius = 0.23 * sz
	tm.rings = 16
	tm.ring_segments = 4
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(col.lightened(0.3), 0.8)
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring.material_override = rm
	ring.position = Vector3(0, -0.2 * sz, 0)
	root.add_child(ring)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(2.4, 1, 2.4), 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "position:y", 0.5 * sz, 0.6)
	tw.tween_property(rm, "albedo_color:a", 0.0, 0.6)
	tw.chain().tween_callback(ring.queue_free)


## Acusación falsa de renuncio: las fichas del acusado se levantan y se ven
## unos segundos, para comprobar con la mesa que de verdad no llevaba.
var _bandeja_oculta := {}   # silla -> ms hasta los que su bandeja no se ve (enseña la mano)


func reveal_hand(s: int, tiles: Array, secs := 4.0) -> void:
	if s == 0:
		return
	# mientras enseña la mano, sus fichas de la bandeja no se ven: si no, la
	# mano salía dos veces (boca arriba delante y de cara a él en la bandeja)
	_bandeja_oculta[s] = Time.get_ticks_msec() + int((secs + 0.3) * 1000.0)
	for pair in _seat_tiles[s]:
		if is_instance_valid(pair[0]):
			pair[0].visible = false
	get_tree().create_timer(secs + 0.3).timeout.connect(func():
		if Time.get_ticks_msec() >= int(_bandeja_oculta.get(s, 0)):
			_bandeja_oculta.erase(s)
			_sig = "")   # vuelven a su bandeja tal como estén ahora
	var dir := _seat_dir(s)
	var right := Vector3(dir.z, 0, -dir.x)
	var root := Node3D.new()
	tiles_root.add_child(root)
	var m := tiles.size()
	for i in m:
		var node := _make_tile(tiles[i], true, true, true)
		var target := dir * (TRAY - 0.12) + right * (i - (m - 1) / 2.0) * (TW + 0.012) + Vector3(0, TABLE_Y + TL / 2 + 0.06, 0)
		node.position = dir * TRAY + Vector3(0, TABLE_Y + TL / 2, 0)
		node.rotation.y = atan2(dir.x, dir.z) + PI
		node.rotation.x = 0.35
		root.add_child(node)
		var tw := node.create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_property(node, "position", target, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var out := root.create_tween()
	out.tween_interval(secs)
	out.tween_property(root, "scale", Vector3.ONE * 0.01, 0.3)
	out.tween_callback(root.queue_free)



# ---------------------------------------------------------------- conteo de fin de mano

## Al acabar la mano la cuenta la pareja ganadora: las fichas jugadas se riegan
## a la izquierda, las que quedaron en las manos se ordenan a la derecha boca
## arriba y quien ganó las cuenta una a una (count_tick por ficha y count_done
## con el total). Clic durante la cuenta = más rápido.
signal count_tick(pips: int, total: int, at: Vector2)
signal count_done(total: int)
var counting := false
var count_fast := false
var _seat_tiles := {0: [], 1: [], 2: [], 3: []}   # silla -> [[nodo, ficha], ...]


func count_hand(g, manual := false, remote := false) -> void:
	if counting or g.last_result.is_empty():
		return
	seat_look = Vector2.ZERO   # reglamento C4: al empezar la cuenta todos miran la mesa
	counting = true
	_count_tweens.clear()
	count_fast = false
	count_manual = manual or remote
	count_remote = remote
	_count_order = []
	_count_queue.clear()
	animating = true
	# las fichas que aún se estaban volteando, quietas ya (si no, se ponían de pie a mitad de la cuenta)
	for tw in _flip_tweens:
		if tw.is_valid():
			tw.kill()
	_flip_tweens.clear()
	var win: int = int(g.last_result.seat)
	sfx.emit("shuffle")
	# el cartel «¡CHIVO!» se quedaba flotando donde estaba su ficha
	for c in chain_root.get_children():
		if c is Label3D:
			var ft := c.create_tween()
			ft.tween_property(c, "modulate:a", 0.0, 0.25)
			ft.tween_callback(c.queue_free)
	# todo se ordena mirando a quien ganó: sus ejes en la mesa
	var d3 := _seat_dir(win)
	var fwd := Vector2(-d3.x, -d3.z)          # de quien ganó hacia el centro
	var side := Vector2(-fwd.y, fwd.x)        # su derecha
	var face := Quaternion(_flat_basis(fwd))  # fichas boca arriba, legibles para quien ganó
	# 1. las jugadas, recogidas en la mitad de la mesa lejos de quien ganó, en filas centradas
	chain_sh.visible = false
	var played: Array = []
	for t in _chain_nodes:
		if is_instance_valid(_chain_nodes[t]):
			played.append(_chain_nodes[t])
	# O15: más apartadas de las que se cuentan (a 0,2 m del centro si caben en
	# 3 filas; con 4 filas no cabrían en el tablero y empiezan a 0,1 m)
	var p_start := 0.2 if ceili(played.size() / 8.0) <= 3 else 0.1
	var pslots := _grid_slots(played.size(), 8, TW + 0.02, TL + 0.012, p_start, fwd, side)
	for i in played.size():
		var node: Node3D = played[i]
		var p2: Vector2 = pslots[i]
		var target := Vector3(p2.x, TABLE_Y + TD / 2 + 0.002, p2.y)
		var tw := node.create_tween()
		_count_tweens.append(tw)
		tw.tween_interval(i * 0.018)
		tw.tween_property(node, "position", target + Vector3(0, 0.06, 0), 0.2).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(node, "quaternion", face, 0.2)
		tw.tween_property(node, "position", target, 0.08)
	await get_tree().create_timer(0.35 + played.size() * 0.018).timeout
	if not counting:
		return
	# 2. las que quedaron en las manos, delante de quien ganó, en filas centradas hacia él
	var order: Array = []
	for k in range(1, 5):
		var s: int = (win + k) % 4
		for pair in _seat_tiles[s]:
			if is_instance_valid(pair[0]) and pair[1].x >= 0:
				order.append(pair)
	var hslots := _grid_slots(order.size(), 7, TW + 0.03, TL + 0.035, -0.52, fwd, side)
	# F13: llegan boca abajo; al contarlas se cogen y se voltean
	_count_face = face
	var face_down := face * Quaternion(Vector3.UP, PI)
	for n in order.size():
		var node: Node3D = order[n][0]
		node.visible = true
		node.scale = Vector3.ONE
		var p2: Vector2 = hslots[n]
		var slot := Vector3(p2.x, TABLE_Y + TD / 2 + 0.002, p2.y)
		var tw := node.create_tween()
		_count_tweens.append(tw)
		tw.tween_interval(n * 0.05)
		tw.tween_property(node, "position", slot + Vector3(0, 0.12, 0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(node, "quaternion", face_down, 0.22)
		tw.tween_property(node, "position", slot, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): sfx.emit("clack"))
	_clear(hand_sh)
	await get_tree().create_timer(0.45 + order.size() * 0.05).timeout
	# 3. la cuenta: si gana tu pareja la haces tú tocando cada ficha; si no, la hace quien ganó
	_count_order = order
	_count_left = range(order.size())
	_count_total = 0
	if manual:
		count_ready.emit()
	# lo que quien ganó ya contó mientras aquí se ordenaban las fichas
	for t in _remote_buffer:
		count_remote_tile(t)
	_remote_buffer.clear()
	var t_idle := 0.0
	count_idle = 0.0
	var aviso_rapido := false
	while not _count_left.is_empty():
		if not counting:
			return
		# tu cuenta pasa a «todas de golpe» (botón, 30 s sin tocar, tienda…): los demás también
		if manual and not remote and count_fast and not aviso_rapido:
			aviso_rapido = true
			counted_all.emit()
		var n := -1
		if manual and not count_fast:
			if _count_queue.is_empty():
				await get_tree().process_frame
				t_idle += get_process_delta_time()
				count_idle = t_idle   # la interfaz enseña cuántos segundos quedan
				if t_idle > (40.0 if count_remote else 30.0):
					count_fast = true   # nadie cuenta (o se perdió la conexión): se cuentan solas
				continue
			n = _count_queue.pop_front()
			if not n in _count_left:
				continue
		else:
			n = _count_left[0]
		t_idle = 0.0
		_count_left.erase(n)
		if not is_instance_valid(order[n][0]):
			continue   # empezó otra mano mientras se contaba
		_count_one(order[n][0], order[n][1], win)
		if manual and not remote and not count_fast:
			counted_local.emit(order[n][1])   # online: los demás lo ven contar
		if not manual or count_fast:
			await get_tree().create_timer(0.07 if count_fast else 0.2).timeout
	count_done.emit(_count_total)
	counted_hand = g.hand_no
	await get_tree().create_timer(0.5 if count_fast else 1.1).timeout
	counting = false
	animating = false


signal count_ready   # te toca contar (tu pareja ganó)
signal counted_local(t: Vector2i)   # contaste tú esta ficha
signal counted_all   # tu cuenta pasó a contarlas todas de golpe
var count_manual := false
var count_remote := false   # online: la cuenta la hace otra persona; aquí se sigue su ritmo
var _remote_buffer: Array = []
var _count_queue: Array = []
var _count_order: Array = []
var counted_hand := -1   # mano cuya cuenta ya terminó (sus fichas no vuelven a las bandejas)
var _count_left: Array = []
var _count_face := Quaternion.IDENTITY   # F13: de cara para quien ganó
var _count_total := 0
var _flip_tweens: Array = []
var _count_tweens: Array = []   # animaciones de la cuenta en curso


## Corta la cuenta y sus animaciones: si no, al empezar otra mano (online los
## demás no esperan) la cuenta y la recogida movían las mismas fichas a la vez.
func _stop_count() -> void:
	_remote_buffer.clear()
	_count_order = []
	counting = false
	animating = false
	for tw in _count_tweens:
		if tw.is_valid():
			tw.kill()
	_count_tweens.clear()


## Online: quien ganó tocó esta ficha (o todas si t es null).
func count_remote_tile(t) -> void:
	if _count_order.is_empty():
		_remote_buffer.append(t)   # aquí aún se están ordenando las fichas
		return
	if t == null:
		count_fast = true
		return
	for n in _count_left:
		if _count_order[n][1] == t:
			_count_queue.append(n)
			return


## Huecos de una rejilla centrada y simétrica en el suelo de la mesa, vista
## por quien ganó: filas de hasta «cols» fichas, repartidas por igual y centradas.
## start: distancia de la primera fila al centro, medida hacia quien ganó (negativa)
## o hacia el lado contrario (positiva); las filas avanzan alejándose de él.
func _grid_slots(n: int, cols: int, dx: float, dz: float, start: float, fwd: Vector2, side: Vector2) -> Array:
	var out: Array = []
	var rows := ceili(n / float(cols))
	# filas repartidas a partes iguales (8 fichas = 4 + 4, no 7 + 1 suelta)
	for r in rows:
		var in_row: int = n / rows + (1 if r < n % rows else 0)
		for c in in_row:
			var x := (c - (in_row - 1) / 2.0) * dx
			var z := start + r * dz
			out.append(side * x + fwd * z)
	return out


## Tocas una ficha durante tu cuenta: se cuenta si no estaba contada.
## Devuelve true si diste en una ficha.
func count_pick(p: Vector2) -> bool:
	if count_remote:
		return false   # cuenta otra persona
	var best := -1
	var bd := 26.0
	for n in _count_left:
		if not is_instance_valid(_count_order[n][0]):
			continue
		var d: float = _u(_count_order[n][0].global_position).distance_to(p)
		if d < bd:
			bd = d
			best = n
	if best >= 0:
		_count_queue.append(best)
	return best >= 0


## F13: quien no cuenta también puede coger una ficha para mirarla (solo en
## su pantalla): sube, se ladea hacia ti y vuelve a su sitio. Devuelve su valor
## si está de cara, -1 si está boca abajo, -2 si no tocaste ninguna.
func count_inspect(p: Vector2) -> int:
	var best := -1
	var bd := 26.0
	for n in _count_order.size():
		var nd = _count_order[n][0]
		if not is_instance_valid(nd) or (nd as Node3D).has_meta("f13"):
			continue
		var d: float = _u(nd.global_position).distance_to(p)
		if d < bd:
			bd = d
			best = n
	if best < 0:
		return -2
	var node: Node3D = _count_order[best][0]
	node.set_meta("f13", true)
	var y0 := node.position.y
	var q0 := node.quaternion
	var tw := node.create_tween()
	_count_tweens.append(tw)
	tw.tween_property(node, "position:y", y0 + 0.07, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(node, "quaternion", q0 * Quaternion(Vector3.RIGHT, -0.5), 0.12)
	tw.tween_interval(0.5)
	tw.tween_property(node, "position:y", y0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(node, "quaternion", q0, 0.12)
	tw.tween_callback(func():
		sfx.emit("clack")
		if is_instance_valid(node):
			node.remove_meta("f13"))
	var contada: bool = not best in _count_left
	var t: Vector2i = _count_order[best][1]
	return t.x + t.y if contada else -1


## Una ficha contada: salta, se apaga un poco (ya contada) y suma.
func _count_one(node: Node3D, t: Vector2i, win: int) -> void:
	_count_total += t.x + t.y
	if win != 0 and heads[win] != null:
		heads[win].act("play")
	elif win == 0 and not count_manual:
		hand_act("tap")   # contando tú a mano, tu brazo no tapa las fichas
	# F13: se coge, se voltea en el aire y se vuelve a dejar (de cara)
	var y0 := node.position.y
	var rapido := count_fast
	var pop := node.create_tween()
	_count_tweens.append(pop)
	pop.tween_property(node, "position:y", y0 + (0.05 if rapido else 0.09), 0.06 if rapido else 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.parallel().tween_property(node, "scale", Vector3.ONE * 1.2, 0.07)
	pop.tween_property(node, "quaternion", _count_face, 0.08 if rapido else 0.16)
	pop.tween_property(node, "position:y", y0, 0.08 if rapido else 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	pop.parallel().tween_property(node, "scale", Vector3.ONE, 0.1)
	pop.tween_callback(func(): sfx.emit("clack"))
	for c in node.get_children():
		if c is MeshInstance3D and c.material_override is StandardMaterial3D and c.material_override != mat_body:
			c.material_override.albedo_color = Color(0.72, 0.72, 0.68)   # ya contada
	count_tick.emit(t.x + t.y, _count_total, _u(node.global_position))


## «Ver la mesa» y la siguiente mano: la línea vuelve tal como quedó.
func restore_table() -> void:
	# reglamento C3: «Ver la mesa» enseña la mesa como la dejó lo último que pasó.
	# Si la cuenta ya terminó, sus fichas se quedan donde las puso (antes volvían
	# giradas a las bandejas); solo una cuenta a medias se deshace.
	if counting:
		_stop_count()
		counted_hand = -1
		_sig = ""
		_chain_sig = ""
	# con la cuenta hecha tampoco se rehace la línea: tras un tranque está en
	# bloque para dejar sitio a los montones y, rehecha, quedaba debajo de ellos
	chain_sh.visible = true



# ---------------------------------------------------------------- tapar fichas

## Tapar (o destapar) las fichas de una silla: se tumban boca abajo y el
## personaje pone las manos encima. Con alguien de pie mirando, es la defensa.
func cover_hand(s: int, on: bool) -> void:
	if covered.get(s, false) == on:
		return
	covered[s] = on
	if s != 0 and heads[s] != null:
		heads[s].covering = on
	_sig = ""   # rehacer las bandejas con las fichas tumbadas



# ---------------------------------------------------------------- fichas tapadas por cuerpos

## Las fichas viven en una capa nítida que se pinta encima de la escena, así
## que un cuerpo nunca las tapa. De pie eso se nota (ves las fichas «a través»
## de quien tienes delante): cada ficha que queda detrás de un cuerpo, vista
## desde la cámara, se esconde.
var _occ_on := false

## Capa nítida con oclusión real (2026-10-09): en el mundo de las fichas hay
## una copia de cada personaje (misma malla, misma postura cada fotograma) que
## no se ilumina: pinta los píxeles de la escena normal que tiene debajo. Así
## escribe profundidad y tapa las fichas que quedan detrás de cabezas y brazos,
## y lo que se ve es el personaje pixelado de siempre.
const OCLUSOR_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, depth_draw_opaque;
uniform sampler2D escena : source_color, filter_nearest;
void fragment() {
	ALBEDO = texture(escena, SCREEN_UV).rgb;
}
"""
var _ocl_mat: ShaderMaterial
var _ocl_root: Node3D
var _ocl := {}   # personaje -> [[malla original, copia], ...]


func set_scene_texture(tex: Texture2D) -> void:
	if _ocl_mat == null:
		var sh := Shader.new()
		sh.code = OCLUSOR_SHADER
		_ocl_mat = ShaderMaterial.new()
		_ocl_mat.shader = sh
	_ocl_mat.set_shader_parameter("escena", tex)


func _sync_occluders() -> void:
	if _ocl_mat == null or _tiles_host == null:
		return
	if _ocl_root == null:
		_ocl_root = Node3D.new()
		_ocl_root.name = "Oclusores"
		_tiles_host.add_child(_ocl_root)
	var vivos := {}
	for s in [1, 2, 3]:
		var ch = heads[s]
		if ch == null or not is_instance_valid(ch):
			continue
		vivos[ch] = true
		if not _ocl.has(ch):
			var pares: Array = []
			for mi in ch.find_children("*", "MeshInstance3D", true, false):
				var c := MeshInstance3D.new()
				c.material_override = _ocl_mat
				c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_ocl_root.add_child(c)
				pares.append([mi, c])
			_ocl[ch] = pares
		for par in _ocl[ch]:
			var src = par[0]
			var c: MeshInstance3D = par[1]
			if not is_instance_valid(src):
				c.visible = false
				continue
			c.visible = src.is_visible_in_tree() and src.mesh != null
			if c.visible:
				c.mesh = src.mesh
				c.global_transform = src.global_transform
	for ch in _ocl.keys():
		if not vivos.has(ch):
			for par in _ocl[ch]:
				if is_instance_valid(par[1]):
					par[1].queue_free()
			_ocl.erase(ch)


func _occlude_tiles() -> void:
	if _ocl_mat != null:
		_sync_occluders()
		return   # la oclusión real ya tapa lo justo (antes se escondía la ficha entera)
	var anyone_up: bool = pie.standing()
	for k in pie.remote:
		if pie.remote[k].st != 0:
			anyone_up = true
	if not anyone_up:
		if _occ_on:
			_occ_on = false
			for n in _all_tile_nodes():
				for c in n.get_children():
					c.visible = true
		return
	_occ_on = true
	var cam := camera.global_position
	var bodies: Array = []   # [abajo, arriba, radio]
	for s in [1, 2, 3]:
		var ch = heads[s]
		if ch == null or not ch.visible:
			continue
		# sentados solo tapan si tú estás de pie; de pie, siempre
		var up: bool = pie.remote.has(s) and pie.remote[s].st != 0
		if not pie.standing() and not up:
			continue
		var back: Vector3 = ch.global_transform.basis.z * 0.08
		bodies.append([ch.global_position + back + Vector3(0, -0.12, 0), ch.global_position + back + Vector3(0, 0.5, 0), 0.19])
	for n in _all_tile_nodes():
		var p: Vector3 = n.global_position
		var hide := false
		for b in bodies:
			var pts := Geometry3D.get_closest_points_between_segments(cam, p, b[0], b[1])
			if pts[0].distance_to(pts[1]) < b[2] and cam.distance_to(pts[0]) < cam.distance_to(p) - 0.05:
				hide = true
				break
		for c in n.get_children():
			c.visible = not hide


func _all_tile_nodes() -> Array:
	var out: Array = []
	for n in other_hand_nodes:
		if is_instance_valid(n):
			out.append(n)
	for t in _chain_nodes:
		if is_instance_valid(_chain_nodes[t]):
			out.append(_chain_nodes[t])
	return out



# ---------------------------------------------------------------- tu silla y tus manos de pie

## La silla se echa hacia atrás y se tuerce al levantarte; al sentarte vuelve.
func _move_my_chair(out: bool) -> void:
	my_chair.visible = true
	var tw := my_chair.create_tween().set_parallel(true)
	var pos := Vector3(-0.08, TABLE_Y, 1.38) if out else Vector3(0, TABLE_Y, 1.02)
	tw.tween_property(my_chair, "position", pos, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(my_chair, "rotation:y", 0.35 if out else 0.0, 0.55)
	if not out:
		tw.chain().tween_callback(func(): my_chair.visible = pie.standing())


var _chair_glow: Array = []   # contornos de la silla (cascarón por dentro, sin luz)
var _chair_mat: StandardMaterial3D
var chair_glow_on := false


## Contorno dorado alrededor de tu silla: la apuntas estando cerca y con un
## clic te sientas. Es la técnica del cascarón: una copia algo más grande de
## cada pieza que solo pinta sus caras de dentro, así se ve solo el borde.
func set_chair_glow(on: bool) -> void:
	chair_glow_on = on
	if _chair_glow.is_empty():
		if not on:
			return
		_chair_mat = StandardMaterial3D.new()
		_chair_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_chair_mat.cull_mode = BaseMaterial3D.CULL_FRONT
		_chair_mat.albedo_color = Color(1.0, 0.82, 0.25)
		for c in my_chair.get_children():
			if c is MeshInstance3D and c.mesh is BoxMesh:
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = c.mesh.size + Vector3.ONE * 0.035
				mi.mesh = bm
				mi.material_override = _chair_mat
				mi.position = c.position
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				my_chair.add_child(mi)
				_chair_glow.append(mi)
	for mi in _chair_glow:
		mi.visible = on
	if on:
		# late suave para que se note que se puede tocar
		_chair_mat.albedo_color = Color(1.0, 0.82, 0.25).lerp(Color(1, 1, 0.75), 0.5 + 0.5 * sin(_t * 6.0))


## ¿El punto de la pantalla (640x360) apunta a tu silla?
var radio_node: Node3D


## ¿Apunta p (pantalla 640x360) a la radio del colmado?
func radio_hit(p: Vector2) -> bool:
	if radio_node == null or not radio_node.is_visible_in_tree():
		return false
	var o := camera.project_ray_origin(p * px_scale)
	var n := camera.project_ray_normal(p * px_scale)
	var inv := radio_node.global_transform.affine_inverse()
	var box := AABB(Vector3(-0.2, -0.13, -0.1), Vector3(0.4, 0.4, 0.22))
	return box.intersects_ray(inv * o, (inv.basis * n).normalized()) != null


## Distancia de la cámara a la radio (para su volumen).
func radio_dist() -> float:
	return camera.global_position.distance_to(radio_node.global_position) if radio_node else 3.0


func chair_hit(p: Vector2) -> bool:
	if not my_chair.visible:
		return false
	var o := camera.project_ray_origin(p * px_scale)
	var n := camera.project_ray_normal(p * px_scale)
	var inv := my_chair.global_transform.affine_inverse()
	var lo: Vector3 = inv * o
	var ln: Vector3 = (inv.basis * n).normalized()
	# la silla entera: asiento, respaldo y patas (con un poco de margen)
	var box := AABB(Vector3(-0.27, -0.8, -0.12), Vector3(0.54, 1.14, 0.48))
	return box.intersects_ray(lo, ln) != null


## Tu silla en su sitio y escondida (salir al colmado o empezar otra partida estando de pie).
func reset_chair() -> void:
	my_chair.position = Vector3(0, TABLE_Y, 1.02)
	my_chair.rotation.y = 0.0
	my_chair.visible = false
	set_chair_glow(false)


## Tus manos delante del pecho con las fichas escondidas: se mecen al andar.
func _tick_fp() -> void:
	var on: bool = pie.standing() and pie.mode != "sentando" and show_arms
	if not on:
		if is_instance_valid(fp_hands):
			fp_hands.visible = false
		return
	if not is_instance_valid(fp_hands):
		_build_fp_hands()
	fp_hands.visible = true
	var spd: float = clamp(pie.vel.length() / pie.SPEED, 0.0, 1.0)
	var bob: float = sin(pie._step_ph) * 0.012 * spd
	var sway: float = sin(pie._step_ph * 0.5) * 0.015 * spd
	var rise: float = 1.0
	if pie.mode == "levantando":
		rise = smoothstep(0.5, 1.0, pie._t / pie.RISE_TIME)
	var off := Vector3(0.04 + sway, -0.3 + bob - 0.25 * (1.0 - rise), -0.46)
	# manotazo: las manos salen hacia delante y vuelven
	if _punch_t > 0.0:
		_punch_t = max(_punch_t - get_process_delta_time(), 0.0)
		off += Vector3(0.05, 0.06, -0.22) * sin((0.3 - _punch_t) / 0.3 * PI)
	fp_hands.global_transform = camera.global_transform * Transform3D(Basis.from_euler(Vector3(0.55, 0.15, sway * 2.0)), off)


func _build_fp_hands() -> void:
	fp_hands = Node3D.new()
	(_tiles_host if _tiles_host else self).add_child(fp_hands)
	var skin := _mat(my_cfg.get("skin", Color(0.6, 0.42, 0.3)))
	var shirt := _mat(my_cfg.get("shirt", Color(0.12, 0.65, 0.68)))
	for sx in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(0.09 * sx, -0.03, 0.06)
		arm.rotation = Vector3(0.15, -0.6 * sx, 0)
		fp_hands.add_child(arm)
		_box(Vector3(0.07, 0.07, 0.2), Vector3(0, 0, 0.08), shirt, arm)
		_box(Vector3(0.065, 0.06, 0.12), Vector3(0, 0, -0.07), skin, arm)
	# (las fichas ya no van contigo: se quedan boca abajo en la mesa)
	for i in 0:
		var t := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(TW * 0.34, TL * 0.34, TD * 0.45)
		t.mesh = bm
		t.material_override = mat_back
		t.position = Vector3(-0.04 + i * 0.02, 0.01, -0.1 + i * 0.003)
		t.rotation = Vector3(-0.25, 0, (i - 2) * 0.05)
		fp_hands.add_child(t)
