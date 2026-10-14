extends Node3D
## Personaje del colmado hecho con bloques y texturas pixel art pintadas en código.
## Mira hacia -Z (el centro de la mesa).

const PX := 16  # resolución de las caras procedurales; Aseprite admite 16 o 64

var cfg: Dictionary
var head: Node3D
var torso: MeshInstance3D
var arm_l: Node3D
var arm_r: Node3D
var face_mat: StandardMaterial3D
var tex_open: ImageTexture
var tex_blink: ImageTexture
var glasses: Array = []
var drink_spot := Vector3.ZERO   # esquina de la mesa donde deja las bebidas
var drink_step := Vector3.ZERO
var slot_fn: Callable          # sitio n.º k de sus vasos en la mesa (lo da la mesa)
var empty_types: Array = []    # bebidas ya tomadas: sus vasos vacíos
var _glass_sig := ""
var tex_wink: ImageTexture
var tex_talk: ImageTexture
# de pie (fase de pararse y moverse): la vista mueve el personaje; aquí solo
# se colocan piernas, silla y brazos
const STAND_LIFT := 0.06     # cuánto sube la cadera al ponerse de pie (pies en el suelo)
var chair: Node3D = null
var chair_home := Transform3D.IDENTITY   # sitio de la silla en la mesa (al estar sentado)
var _chair_out := false
var own_chair := true   # false: la silla es de la mesa (la pone la vista) y no del personaje
var seat_legs: MeshInstance3D
var legs: Array = []         # [{hip, knee, side}]
var stand_k := 0.0           # 0 sentado … 1 de pie (lo anima la vista)
var walk_amt := 0.0          # 0 quieto … 1 caminando
var _walk_ph := 0.0
var head_pitch := 0.0
var head_yaw := 0.0           # de pie online: giro del cuello respecto al cuerpo         # de pie online: hacia dónde mira arriba/abajo (su cámara)
var hold_tiles := false      # de pie con sus fichas escondidas contra el pecho
var _held: Node3D = null
var covering := false        # sentado, tapando sus fichas con las manos
# jugueteo con sus fichas en su turno (online lo manda cada jugador; los bots lo imitan):
# 0 nada, 1 mira sus fichas (la mano pasa por encima), 2 una ficha en la mano dándole
# vueltas, 3 la lleva hacia una punta de la mesa (fiddle_to)
var fiddle := 0
var point_at = null          # Vector3 global al que señala (gesto «point»), o null
var fiddle_to = null         # Vector3 global de la punta a la que la lleva, o null
var _fiddle_t := 0.0
var _fiddle_tile: Node3D = null
var _alcance := 0.46           # hasta dónde estira el brazo al llevar la ficha (m desde el hombro)
var tex_talk_wide: ImageTexture
var _aseprite_face: Image = null
var tex_expr := {}            # caras de emoción: enfado, susto, risa
var expr := ""                # la que se ve ahora ("" = la normal)
var _expr_t := 0.0
# en el suelo (tumbado online): 0 de pie … 1 tumbado; se anima solo hacia «fallen»
var fallen := false
var muerto := false   # le dispararon: tumbado sin estrellitas hasta que vuelve
var armado := false   # de pie online con la pistola: brazo al frente
var arma_tipo := "pistola"   # el modelo que lleva en la mano (pistola o revólver)
var _pistola_tipo := ""
var shot_kick := 0.0  # retroceso del último tiro
var _pistola: Node3D
var fallen_k := 0.0
var _stars: Node3D = null
var _talk_t := 0.0       # segundos que le quedan hablando (boca en movimiento)
var talk_level := 0.0    # 0..1: volumen de su voz (chat de voz); mueve la boca
var look_target = null   # Vector3 global hacia donde mira, o null
var seat_head := Vector2.ZERO   # online, sentado: hacia dónde gira la cabeza su jugador (modo cámara)
var _wink_t := 0.0

var state := "idle"  # idle, think, win, lose
var _t := randf() * 10.0
var _blink_in := randf_range(1.5, 4.0)
var _blink_t := 0.0
var _action := ""
var _action_t := 0.0

const ARM_REST := -0.62
const PRESETS := {
	"fello": {
		"skin": Color(0.55, 0.36, 0.24), "hair": Color(0.8, 0.8, 0.78), "shirt": Color(0.94, 0.93, 0.88),
		"pants": Color(0.35, 0.3, 0.25), "mustache": true, "hat": "paja", "pattern": "guayabera",
	},
	"yeya": {
		"face_sheet": "res://arte/personajes/yeya/caras.png",
		"skin": Color(0.47, 0.3, 0.2), "hair": Color(0.12, 0.08, 0.06), "shirt": Color(0.85, 0.25, 0.35),
		"pants": Color(0.2, 0.2, 0.35), "lips": true, "earrings": true, "hat": "rizos", "pattern": "flores", "cuerpo": "mujer",
	},
	"chichi": {
		"face_sheet": "res://arte/personajes/chichi/caras.png",
		"skin": Color(0.72, 0.5, 0.35), "hair": Color(0.1, 0.07, 0.05), "shirt": Color(0.2, 0.55, 0.3),
		"pants": Color(0.15, 0.15, 0.18), "beard": true, "hat": "gorra", "pattern": "jersey",
	},
	# avatares elegibles por el jugador
	"nena": {
		"skin": Color(0.62, 0.42, 0.29), "hair": Color(0.3, 0.17, 0.08), "shirt": Color(0.12, 0.65, 0.68),
		"pants": Color(0.95, 0.9, 0.8), "lips": true, "earrings": true, "hat": "mono", "pattern": "rayas", "cuerpo": "mujer",
	},
	"tito": {
		"skin": Color(0.36, 0.23, 0.15), "hair": Color(0.15, 0.1, 0.07), "shirt": Color(0.25, 0.4, 0.8),
		"pants": Color(0.2, 0.18, 0.15), "mustache": true, "hat": "calvo", "pattern": "guayabera",
	},
	"rafa": {
		"skin": Color(0.8, 0.6, 0.45), "hair": Color(0.2, 0.12, 0.06), "shirt": Color(0.98, 0.78, 0.15),
		"pants": Color(0.2, 0.3, 0.5), "beard": true, "hat": "panuelo", "pattern": "jersey",
	},
}
const AVATARS := ["nena", "tito", "rafa"]
const EXTRA_PRESETS := {
	"colmadero": {
		"skin": Color(0.5, 0.33, 0.22), "hair": Color(0.75, 0.75, 0.72), "shirt": Color(0.95, 0.95, 0.92),
		"pants": Color(0.2, 0.2, 0.25), "mustache": true, "hat": "calvo", "pattern": "delantal", "standing": true,
	},
}
const AVATAR_NAMES := {"nena": "Nena", "tito": "Tito", "rafa": "Rafa"}

# accesorios por tipo ("" = ninguno). Los perfiles viejos guardaban true/false:
# true se lee como el primer tipo de la lista.
const GLASSES_T := ["redondas", "cuadradas", "sol", "abuela", "colores"]
const EARRINGS_T := ["aros", "argollas", "bolitas", "diamantes", "perlas"]
const CHAIN_T := ["chopa", "riquito", "ajentao", "bultero", "tiguere"]
const LIPS_T := ["rojos", "rosados", "morados", "brillo"]
const LIP_COLORS := {"rojos": Color(0.78, 0.12, 0.18), "rosados": Color(0.95, 0.45, 0.6), "morados": Color(0.45, 0.15, 0.4), "brillo": Color(0.9, 0.35, 0.4)}


## Tipo de un accesorio del aspecto ("" si no lleva).
func opt(key: String) -> String:
	var v = cfg.get(key, "")
	if v is bool:
		if not v:
			return ""
		return {"glasses": GLASSES_T, "earrings": EARRINGS_T, "chain": CHAIN_T, "lips": LIPS_T}[key][0]
	return str(v) if v != null else ""


func is_woman() -> bool:
	return str(cfg.get("cuerpo", "")) == "mujer"


func setup(preset: String) -> void:
	var preset_cfg: Dictionary = (PRESETS[preset] if PRESETS.has(preset) else EXTRA_PRESETS[preset]).duplicate(true)
	# Los presets fijos usan Aseprite; el espejo sigue pintando el aspecto personalizado.
	preset_cfg["face_sheet"] = "res://arte/personajes/%s/caras.png" % preset
	preset_cfg["shirt_texture"] = "res://arte/personajes/%s/ropa.png" % preset
	setup_cfg(preset_cfg)


## Personaje a medida (editor del espejo).
func setup_cfg(c: Dictionary) -> void:
	cfg = c
	_aseprite_face = null
	var sheet_path: String = str(cfg.get("face_sheet", ""))
	if sheet_path != "" and ResourceLoader.exists(sheet_path):
		var sheet := load(sheet_path) as Texture2D
		if sheet != null:
			var image := sheet.get_image()
			if image != null and image.get_height() in [16, 64] and image.get_width() == image.get_height() * 10:
				image.convert(Image.FORMAT_RGBA8)
				_aseprite_face = image
	tex_open = ImageTexture.create_from_image(_paint_face(false))
	tex_blink = ImageTexture.create_from_image(_paint_face(true))
	tex_wink = ImageTexture.create_from_image(_paint_face(false, true))
	tex_talk = ImageTexture.create_from_image(_paint_face(false, false, 1))
	tex_talk_wide = ImageTexture.create_from_image(_paint_face(false, false, 2))
	for ex in ["enfado", "susto", "risa"]:
		tex_expr[ex] = ImageTexture.create_from_image(_paint_expr(ex))
	_build()


# ---------------------------------------------------------------- texturas

## mouth_open: 0 cerrada, 1 entreabierta, 2 abierta (hablar).
## Caras de emoción sobre la cara normal: enfado (cejas en V, boca torcida),
## susto (ojos grandes, boca en O) y risa (ojos cerrados en arco, boca abierta).
func _paint_expr(kind: String) -> Image:
	if _aseprite_face != null:
		return _aseprite_frame({"enfado": 5, "susto": 6, "risa": 7}.get(kind, 0))
	var img := _paint_face(false, false, 2 if kind == "risa" else 0)
	var skin: Color = cfg.skin
	var dark := Color(0.08, 0.05, 0.04)
	var white := Color(0.95, 0.95, 0.9)
	var brow: Color = cfg.hair.darkened(0.2) if cfg.hair.v > 0.5 else cfg.hair
	match kind:
		"enfado":
			for x in [3, 4, 5, 10, 11, 12]:
				img.set_pixel(x, 5, skin)
			for k in 3:
				img.set_pixel(3 + k, 4 + k, brow)    # cejas en V
				img.set_pixel(12 - k, 4 + k, brow)
			for x in range(6, 10):
				img.set_pixel(x, 12, skin)
			for x in range(6, 10):
				img.set_pixel(x, 13 if x < 8 else 12, skin.darkened(0.55))   # boca torcida
		"susto":
			for ex in [4, 11]:
				for dy in [6, 7, 8]:
					img.set_pixel(ex - 1, dy, white)
					img.set_pixel(ex + 1, dy, white)
				img.set_pixel(ex, 6, white)
				img.set_pixel(ex, 7, dark)
				img.set_pixel(ex, 8, white)
			for x in range(5, 11):
				img.set_pixel(x, 12, skin)
			for x in range(7, 9):
				for y in range(11, 14):
					img.set_pixel(x, y, Color(0.25, 0.05, 0.06))   # boca en O
		"risa":
			for ex in [4, 11]:
				img.set_pixel(ex - 1, 8, dark)
				img.set_pixel(ex, 7, dark)
				img.set_pixel(ex + 1, 8, dark)
				img.set_pixel(ex - 1, 7, skin)
				img.set_pixel(ex, 8, skin)
	return img


func _paint_face(blink: bool, wink := false, mouth_open := 0) -> Image:
	if _aseprite_face != null:
		var index := 1 if blink else (2 if wink else (3 if mouth_open == 1 else (4 if mouth_open == 2 else 0)))
		return _aseprite_frame(index)
	var img := Image.create(PX, PX, false, Image.FORMAT_RGBA8)
	var skin: Color = cfg.skin
	img.fill(skin)
	var dark := Color(0.08, 0.05, 0.04)
	var hair: Color = cfg.hair
	# pelo/frente
	for x in PX:
		img.set_pixel(x, 0, hair)
		img.set_pixel(x, 1, hair)
	# cejas
	for x in [3, 4, 5, 10, 11, 12]:
		img.set_pixel(x, 5, hair.darkened(0.2) if cfg.hair.v > 0.5 else hair)
	# pestañas (cuerpo de mujer)
	if is_woman() and not blink:
		img.set_pixel(2, 6, dark)
		img.set_pixel(13, 6, dark)
	# ojos
	for ex in [4, 11]:
		if blink or (wink and ex == 4):
			img.set_pixel(ex - 1, 7, dark)
			img.set_pixel(ex, 7, dark)
			img.set_pixel(ex + 1, 7, dark)
		else:
			img.set_pixel(ex - 1, 7, Color(0.95, 0.95, 0.9))
			img.set_pixel(ex, 7, dark)
			img.set_pixel(ex, 8, dark)
			img.set_pixel(ex - 1, 8, Color(0.95, 0.95, 0.9))
	# nariz
	img.set_pixel(7, 9, skin.darkened(0.25))
	img.set_pixel(8, 9, skin.darkened(0.25))
	img.set_pixel(7, 10, skin.darkened(0.35))
	img.set_pixel(8, 10, skin.darkened(0.35))
	# mejillas
	for cx in [2, 13]:
		img.set_pixel(cx, 10, skin.lerp(Color(0.9, 0.35, 0.35), 0.35))
	# boca: con labios pintados, del color elegido (y un brillo si es «brillo»)
	var lt := opt("lips")
	var mouth: Color = LIP_COLORS.get(lt, Color(0.75, 0.15, 0.2)) if lt != "" else skin.darkened(0.5)
	if mouth_open == 0:
		for x in range(6, 10):
			img.set_pixel(x, 12, mouth)
		img.set_pixel(5, 11, mouth)
		img.set_pixel(10, 11, mouth)
		if lt == "brillo":
			img.set_pixel(7, 12, mouth.lightened(0.5))
	else:
		# hablando: labio de arriba, hueco oscuro y labio de abajo
		var inside := Color(0.25, 0.05, 0.06)
		var top := 11 if mouth_open == 1 else 10
		var bottom := 13 if mouth_open == 2 else 12
		for x in range(6, 10):
			img.set_pixel(x, top, mouth)
			img.set_pixel(x, bottom, mouth)
		for y in range(top + 1, bottom):
			for x in range(6, 10):
				img.set_pixel(x, y, inside)
		img.set_pixel(5, top + 1, mouth)
		img.set_pixel(10, top + 1, mouth)
		if mouth_open == 2:
			img.set_pixel(7, top + 1, Color(0.95, 0.95, 0.9))  # dientes
			img.set_pixel(8, top + 1, Color(0.95, 0.95, 0.9))
	if cfg.get("mustache", false):
		# El bigote sigue al labio superior; no tapa el hueco ni los dientes.
		var mustache_y: int = 11 - mini(mouth_open, 1)
		for x in range(4, 12):
			img.set_pixel(x, mustache_y, hair)
	if cfg.get("beard", false):
		for x in range(3, 13):
			img.set_pixel(x, 14, hair)
			img.set_pixel(x, 15, hair)
		for y in range(11, 14):
			img.set_pixel(2, y, hair)
			img.set_pixel(13, y, hair)
		for x in range(6, 10):
			img.set_pixel(x, 13, hair)
	return img


## Orden de los diez fotogramas documentado en caras.json y en Aseprite.
func _aseprite_frame(index: int) -> Image:
	var frame_size := _aseprite_face.get_height()
	return _aseprite_face.get_region(Rect2i(index * frame_size, 0, frame_size, frame_size))


func _shirt_tex() -> ImageTexture:
	var shirt_path: String = str(cfg.get("shirt_texture", ""))
	if shirt_path != "" and ResourceLoader.exists(shirt_path):
		var shirt := load(shirt_path) as Texture2D
		if shirt != null:
			var image := shirt.get_image()
			if image != null and image.get_size() in [Vector2i(16, 16), Vector2i(64, 64)]:
				return ImageTexture.create_from_image(image)
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var c: Color = cfg.shirt
	img.fill(c)
	match cfg.pattern:
		"guayabera":
			for y in 16:
				for x in [3, 5, 10, 12]:
					img.set_pixel(x, y, c.darkened(0.12))
				if y % 4 == 1:
					img.set_pixel(8, y, Color(0.6, 0.55, 0.45))
			for x in range(2, 6):
				img.set_pixel(x, 9, c.darkened(0.2))
				img.set_pixel(x + 8, 9, c.darkened(0.2))
		"flores":
			var flower := [Color(1, 0.85, 0.3), Color(1, 1, 1), Color(0.3, 0.75, 0.6)]
			for i in 14:
				var x := (i * 7 + 3) % 16
				var y := (i * 5 + 1) % 16
				var fc: Color = flower[i % 3]
				img.set_pixel(x, y, fc)
				img.set_pixel((x + 1) % 16, y, fc)
				img.set_pixel(x, (y + 1) % 16, fc)
		"jersey":
			for x in 16:
				img.set_pixel(x, 0, Color(1, 1, 1))
				img.set_pixel(x, 1, Color(1, 1, 1))
			# número 7
			for x in range(5, 11):
				img.set_pixel(x, 5, Color(1, 1, 1))
			for i in 6:
				img.set_pixel(10 - i / 2, 6 + i, Color(1, 1, 1))
		"delantal":
			var apron := Color(0.2, 0.45, 0.75)
			for y in range(5, 16):
				for x in range(3, 13):
					img.set_pixel(x, y, apron)
			for y in 5:
				img.set_pixel(4, y, apron)
				img.set_pixel(11, y, apron)
			for x in range(6, 10):
				img.set_pixel(x, 10, apron.darkened(0.3))  # bolsillo
		"rayas":
			for y in 16:
				if y % 4 < 2:
					for x in 16:
						img.set_pixel(x, y, Color(1, 1, 1).lerp(c, 0.15))
	return ImageTexture.create_from_image(img)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _tex_mat(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m


func _box(size: Vector3, pos: Vector3, m: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _quad(size: Vector2, pos: Vector3, m: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = PI  # mirar hacia -Z
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- modelo

func _build() -> void:
	var skin_m := _mat(cfg.skin)
	var shirt_m := _mat(cfg.shirt)
	# silla (nodo aparte: se queda en su sitio cuando el personaje se levanta)
	if own_chair and not cfg.get("standing", false):
		chair = Node3D.new()
		add_child(chair)
		# la silla es de la mesa, no del personaje: suelta desde el principio en
		# su sitio (antes se enganchaba al cuerpo y online podía irse con él)
		if is_inside_tree():
			chair.top_level = true
			chair_home = global_transform
			chair.global_transform = chair_home
		var wood := _mat(Color(0.32, 0.2, 0.1))
		_box(Vector3(0.46, 0.05, 0.4), Vector3(0, -0.28, 0.12), wood, chair)
		_box(Vector3(0.46, 0.6, 0.05), Vector3(0, 0.0, 0.3), wood, chair)
		for lx in [-0.2, 0.2]:
			for lz in [-0.05, 0.29]:
				_box(Vector3(0.04, 0.47, 0.04), Vector3(lx, -0.53, lz), wood, chair)
	# piernas sentado (asomando bajo la mesa) y piernas de pie (se ven al levantarse)
	seat_legs = _box(Vector3(0.36, 0.12, 0.3), Vector3(0, -0.2, 0.0), _mat(cfg.pants), self)
	var pants := _mat(cfg.pants)
	var shoe := _mat(Color(0.12, 0.08, 0.06))
	for side in [-1, 1]:
		var hip := Node3D.new()
		hip.position = Vector3(0.09 * side, -0.17, 0.08)
		add_child(hip)
		# piernas cortas y gruesas, a la escala del cuerpo (antes eran de zancos)
		_box(Vector3(0.16, 0.32, 0.18), Vector3(0, -0.16, 0), pants, hip)
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.32, 0)
		hip.add_child(knee)
		_box(Vector3(0.15, 0.28, 0.17), Vector3(0, -0.14, 0), pants, knee)
		_box(Vector3(0.16, 0.06, 0.25), Vector3(0, -0.29, -0.05), shoe, knee)
		hip.visible = false
		legs.append({"hip": hip, "knee": knee, "side": side})
	# torso con textura de camisa en el frente (mujer: hombros más estrechos y pecho)
	var tw := 0.35 if is_woman() else 0.4
	torso = _box(Vector3(tw, 0.46, 0.24), Vector3(0, 0.04, 0.08), shirt_m, self)
	_quad(Vector2(tw, 0.46), Vector3(0, 0, -0.121), _tex_mat(_shirt_tex()), torso)
	if is_woman():
		for bx in [-0.075, 0.075]:
			_box(Vector3(0.12, 0.1, 0.05), Vector3(bx, 0.07, -0.13), shirt_m, torso)
	if cfg.pattern == "guayabera" or cfg.pattern == "flores":
		_box(Vector3(0.14, 0.05, 0.02), Vector3(0, 0.2, -0.125), _mat(cfg.skin), torso)
	var antes_cadena := torso.get_child_count()
	_build_chain()
	cadena = _agrupar(torso, antes_cadena, Vector3(0, 0.22, -0.13))
	# cabeza
	head = Node3D.new()
	head.position = Vector3(0, 0.44, 0.06)
	add_child(head)
	_box(Vector3(0.1, 0.08, 0.1), Vector3(0, -0.15, 0), skin_m, head)  # cuello
	_box(Vector3(0.26, 0.26, 0.26), Vector3.ZERO, skin_m, head)
	face_mat = _tex_mat(tex_open)
	_quad(Vector2(0.26, 0.26), Vector3(0, 0, -0.131), face_mat, head)
	var hair_m := _mat(cfg.hair)
	var antes_pelo := head.get_child_count()
	match cfg.hat:
		"paja":
			_box(Vector3(0.27, 0.04, 0.27), Vector3(0, 0.12, 0), hair_m, head)
			var straw := _mat(Color(0.86, 0.74, 0.45))
			_box(Vector3(0.48, 0.025, 0.48), Vector3(0, 0.15, 0), straw, head)
			_box(Vector3(0.28, 0.12, 0.28), Vector3(0, 0.22, 0), straw, head)
			_box(Vector3(0.29, 0.03, 0.29), Vector3(0, 0.18, 0), _mat(Color(0.25, 0.15, 0.1)), head)
		"rizos":
			for i in 14:
				var a := i * TAU / 14.0
				var r := 0.16
				var p := Vector3(cos(a) * r, 0.1 + sin(i * 1.7) * 0.04, sin(a) * r + 0.03)
				if p.z < -0.08:
					p.y += 0.06
				_box(Vector3(0.12, 0.12, 0.12), p, hair_m, head)
			_box(Vector3(0.3, 0.14, 0.3), Vector3(0, 0.18, 0.02), hair_m, head)
		"mono":
			_box(Vector3(0.28, 0.08, 0.28), Vector3(0, 0.12, 0.01), hair_m, head)
			_box(Vector3(0.28, 0.2, 0.06), Vector3(0, 0.02, 0.13), hair_m, head)
			_box(Vector3(0.14, 0.14, 0.14), Vector3(0, 0.22, 0.04), hair_m, head)  # moño
			_box(Vector3(0.16, 0.03, 0.16), Vector3(0, 0.16, 0.04), _mat(Color(0.95, 0.3, 0.45)), head)
		"calvo":
			for sx in [-0.135, 0.135]:
				_box(Vector3(0.02, 0.1, 0.2), Vector3(sx, 0.03, 0.03), hair_m, head)
			_box(Vector3(0.26, 0.1, 0.03), Vector3(0, 0.03, 0.135), hair_m, head)
			_box(Vector3(0.06, 0.02, 0.01), Vector3(-0.05, 0.1, -0.132), _mat(Color(1, 1, 1, 1).lerp(cfg.skin, 0.4)), head)  # brillo
		"panuelo":
			var band := _mat(Color(0.85, 0.15, 0.18))
			_box(Vector3(0.28, 0.1, 0.28), Vector3(0, 0.13, 0), band, head)
			_box(Vector3(0.06, 0.1, 0.04), Vector3(0.06, 0.05, 0.16), band, head)  # nudo
			for i in 5:
				_box(Vector3(0.02, 0.02, 0.21), Vector3(-0.08 + i * 0.04, 0.17, -0.0), _mat(Color(1, 1, 1)), head)
		"gorra":
			var cap := _mat(Color(0.85, 0.2, 0.2))
			_box(Vector3(0.28, 0.1, 0.28), Vector3(0, 0.15, 0), cap, head)
			_box(Vector3(0.18, 0.025, 0.14), Vector3(0, 0.11, 0.19), cap, head)  # visera atrás
			_box(Vector3(0.27, 0.05, 0.27), Vector3(0, 0.1, 0.01), hair_m, head)
	if cfg.hat != "calvo":   # las patillas del calvo van pegadas a la cabeza
		pelo = _agrupar(head, antes_pelo, Vector3(0, 0.12, 0.02))
	var antes_aretes := head.get_child_count()
	_build_earrings()
	aretes.clear()
	for lado in [-1.0, 1.0]:
		var piezas := head.get_children().slice(antes_aretes).filter(func(n): return n is Node3D and signf(n.position.x) == lado)
		if not piezas.is_empty():
			aretes.append(_agrupar_nodos(head, piezas, Vector3(0.14 * lado, -0.035, 0)))
	_build_glasses()
	# brazos con pivote en el hombro
	var sx := 0.225 if is_woman() else 0.25
	arm_l = _make_arm(-sx, shirt_m, skin_m)
	arm_r = _make_arm(sx, shirt_m, skin_m)


## Mete en un pivote los hijos de `parent` creados desde el índice `desde`
## (pelo y sombrero, cadena…) para que se mezan juntos alrededor de `pivote`.
func _agrupar(parent: Node3D, desde: int, pivote: Vector3) -> Node3D:
	return _agrupar_nodos(parent, parent.get_children().slice(desde), pivote)


func _agrupar_nodos(parent: Node3D, nodos: Array, pivote: Vector3) -> Node3D:
	var g := Node3D.new()
	g.position = pivote
	parent.add_child(g)
	for n in nodos:
		parent.remove_child(n)
		g.add_child(n)
		n.position -= pivote
	return g


# ---------------------------------------------------------------- peso (muelles)
## Física secundaria: el cuerpo ya no es rígido. Cada pieza (tronco, cabeza,
## pelo/sombrero, cadena, aretes) cuelga de un muelle amortiguado que recibe la
## aceleración del personaje (arrancar, frenar, girar) y los empujones; se pasa
## un poco y vuelve. Solo es visual: no cambia posiciones ni se manda online.
## x = (cabeceo, alabeo) en radianes; k = rigidez; d = amortiguación; g = cuánto le afecta.
static var peso := 1.0   # 0,3 con «Menos movimiento»
var pelo: Node3D
var cadena: Node3D
var aretes: Array = []
var _muelles := {
	"tronco": {"x": Vector2.ZERO, "v": Vector2.ZERO, "k": 90.0, "d": 11.0, "g": 0.025, "max": 0.22},
	"cabeza": {"x": Vector2.ZERO, "v": Vector2.ZERO, "k": 70.0, "d": 8.0, "g": 0.04, "max": 0.4},
	"pelo": {"x": Vector2.ZERO, "v": Vector2.ZERO, "k": 45.0, "d": 4.5, "g": 0.06, "max": 0.22},
	"cadena": {"x": Vector2.ZERO, "v": Vector2.ZERO, "k": 30.0, "d": 3.0, "g": 0.12, "max": 0.7},
	"aretes": {"x": Vector2.ZERO, "v": Vector2.ZERO, "k": 25.0, "d": 2.2, "g": 0.18, "max": 0.8},
}
var _prev_pos = null
var _prev_vel := Vector3.ZERO
var _torso_z := 0.0
var _head_rot := Vector3.ZERO
var _prev_yaw := 0.0
var _blink_cool := 0.0
var _sobre_tronco := Vector3.ZERO


## Un golpe al cuerpo desde fuera: dir en coordenadas globales (hacia donde lo
## empujan), fuerza ~1 un empujón, ~2 un tiro o un manotazo fuerte.
func empujar(dir: Vector3, fuerza := 1.0) -> void:
	if dir.length() < 0.001:
		return
	var l: Vector3 = global_transform.basis.inverse() * dir.normalized()
	# empujado hacia +Z (su espalda) el tronco se va atrás: cabeceo positivo
	var imp := Vector2(l.z, -l.x) * fuerza * 3.5 * peso
	for n in _muelles:
		var mu: Dictionary = _muelles[n]
		mu.v += imp * (mu.g / 0.025) * 0.6


## Sacudida sin dirección (golpe en la mesa, ¡pam! de la última ficha).
func sacudir(fuerza := 1.0) -> void:
	for n in ["pelo", "cadena", "aretes", "cabeza"]:
		var mu: Dictionary = _muelles[n]
		mu.v += Vector2(-1.0, randf_range(-0.6, 0.6)) * fuerza * 4.0 * (mu.g / 0.06) * peso


func _tick_muelles(delta: float) -> void:
	# aceleración del cuerpo en su propio sistema (adelante es −Z)
	var acc := Vector3.ZERO
	if _prev_pos != null and delta > 0.0:
		var vel: Vector3 = (global_position - _prev_pos) / delta
		if vel.length() > 8.0:   # saltó de sitio (se sentó, cambió de silla): no es movimiento
			vel = Vector3.ZERO
			_prev_vel = Vector3.ZERO
		acc = (vel - _prev_vel) / delta
		_prev_vel = vel
	_prev_pos = global_position
	acc = (global_transform.basis.inverse() * acc).limit_length(25.0)
	# girar rápido también empuja (el pelo y los aretes se van hacia fuera)
	var giro: float = clampf(wrapf(global_rotation.y - _prev_yaw, -PI, PI) / maxf(delta, 0.001), -6.0, 6.0)
	_prev_yaw = global_rotation.y
	var fuerza := Vector2(-acc.z, acc.x + giro * 0.8)
	var dt: float = minf(delta, 0.05)
	for n in _muelles:
		var mu: Dictionary = _muelles[n]
		var a: Vector2 = -mu.x * mu.k - mu.v * mu.d + fuerza * mu.g * 10.0 * peso
		mu.v += a * dt
		mu.x += mu.v * dt
		mu.x = mu.x.limit_length(mu.max)
	var tr: Vector2 = _muelles.tronco.x
	if is_instance_valid(pelo):
		var p: Vector2 = _muelles.pelo.x
		pelo.rotation = Vector3(p.x, 0, p.y)
	if is_instance_valid(cadena):
		# cuelga: si el tronco se inclina, ella sigue vertical (nunca entra en el pecho)
		var c: Vector2 = _muelles.cadena.x - tr * 1.2
		cadena.rotation = Vector3(clampf(-c.x, 0.0, 0.6), 0, clampf(c.y, -0.4, 0.4))
	for ar in aretes:
		var e: Vector2 = _muelles.aretes.x - _muelles.cabeza.x
		ar.rotation = Vector3(e.x, 0, e.y)


func _shiny(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := _mat(c)
	m.metallic = 0.6
	m.roughness = 0.35
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


## Cadena colgada sobre la camisa (antes iba dentro del pecho y no se veía).
## chopa: fina y sencilla · riquito: con medalla · ajentao: cubana gruesa ·
## bultero: larga, gruesa y con un «$» enorme · tiguere: plateada con cruz.
func _build_chain() -> void:
	var t := opt("chain")
	if t == "":
		return
	var gold := _shiny(Color(1, 0.8, 0.25), 0.15)
	var gold_d := _shiny(Color(0.85, 0.6, 0.15), 0.1)
	var silver := _shiny(Color(0.85, 0.87, 0.9), 0.15)
	var m: Material = silver if t == "tiguere" else gold
	var thick: float = {"chopa": 0.012, "riquito": 0.016, "ajentao": 0.028, "bultero": 0.03, "tiguere": 0.014}.get(t, 0.014)
	var depth: float = {"chopa": 0.11, "riquito": 0.13, "ajentao": 0.09, "bultero": 0.2, "tiguere": 0.12}.get(t, 0.12)
	var z := -0.128 - (0.03 if is_woman() else 0.0)
	var top := Vector2(0.075, 0.225)   # sale del cuello
	var bottom := Vector2(0.0, 0.225 - depth)
	# dos tramos en V, en eslabones (la cubana alterna claro y oscuro)
	var links := int(depth / (thick * 0.9)) + 2
	for side in [-1, 1]:
		for k in links:
			var u := float(k) / (links - 1)
			var p := Vector2(top.x * side, top.y).lerp(bottom, u)
			p.y -= sin(u * PI) * 0.012   # cuelga un poco, como una cadena de verdad
			var lm: Material = gold_d if (t == "ajentao" and k % 2 == 1) else m
			_box(Vector3(thick, thick, 0.012), Vector3(p.x, p.y, z), lm, torso)
	match t:
		"riquito":
			_box(Vector3(0.05, 0.05, 0.012), Vector3(0, bottom.y - 0.03, z - 0.002), gold, torso)
			_box(Vector3(0.026, 0.026, 0.006), Vector3(0, bottom.y - 0.03, z - 0.01), _shiny(Color(0.7, 0.1, 0.12), 0.3), torso)
		"bultero":
			# «$» gigante de oro con piedritas
			var c := Vector3(0, bottom.y - 0.055, z - 0.004)
			_box(Vector3(0.075, 0.09, 0.014), c, gold, torso)
			var ink := _mat(Color(0.25, 0.16, 0.04))
			for y in [0.025, 0.0, -0.025]:
				_box(Vector3(0.04, 0.009, 0.004), c + Vector3(0, y, -0.009), ink, torso)
			_box(Vector3(0.009, 0.02, 0.004), c + Vector3(-0.016, 0.013, -0.009), ink, torso)
			_box(Vector3(0.009, 0.02, 0.004), c + Vector3(0.016, -0.013, -0.009), ink, torso)
			_box(Vector3(0.006, 0.075, 0.004), c + Vector3(0, 0, -0.01), ink, torso)
			for px in [-0.03, 0.03]:
				_box(Vector3(0.01, 0.01, 0.004), c + Vector3(px, 0.038, -0.009), _shiny(Color(0.85, 0.95, 1), 1.0), torso)
		"tiguere":
			_box(Vector3(0.014, 0.06, 0.01), Vector3(0, bottom.y - 0.035, z - 0.002), silver, torso)
			_box(Vector3(0.04, 0.012, 0.01), Vector3(0, bottom.y - 0.022, z - 0.002), silver, torso)


func _build_earrings() -> void:
	var t := opt("earrings")
	if t == "":
		return
	var gold := _shiny(Color(1, 0.8, 0.25), 0.15)
	for sx in [-0.14, 0.14]:
		var out: float = 0.004 * signf(sx)
		match t:
			"aros":
				# aro pequeño: cuatro lados de un cuadradito
				for dy in [0.022, -0.022]:
					_box(Vector3(0.012, 0.01, 0.05), Vector3(sx, -0.06 + dy, 0), gold, head)
				for dz in [-0.022, 0.022]:
					_box(Vector3(0.012, 0.045, 0.01), Vector3(sx, -0.06, dz), gold, head)
			"argollas":
				for dy in [0.035, -0.05]:
					_box(Vector3(0.012, 0.012, 0.085), Vector3(sx + out, -0.075 + dy, 0), gold, head)
				for dz in [-0.04, 0.04]:
					_box(Vector3(0.012, 0.085, 0.012), Vector3(sx + out, -0.083, dz), gold, head)
			"bolitas":
				_box(Vector3(0.022, 0.022, 0.022), Vector3(sx, -0.05, 0), gold, head)
			"diamantes":
				var b := _box(Vector3(0.022, 0.022, 0.022), Vector3(sx, -0.05, 0), _shiny(Color(0.85, 0.97, 1.0), 1.2), head)
				b.rotation.x = PI / 4
			"perlas":
				_box(Vector3(0.024, 0.024, 0.024), Vector3(sx, -0.055, 0), _shiny(Color(0.98, 0.96, 0.9), 0.3), head)


func _build_glasses() -> void:
	var t := opt("glasses")
	if t == "":
		return
	var frame := _mat(Color(0.08, 0.06, 0.05))
	var lens := StandardMaterial3D.new()
	lens.albedo_color = Color(0.6, 0.85, 1.0, 0.45)
	lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var fw := 0.09
	var fh := 0.07
	var y := 0.02
	match t:
		"cuadradas":
			fw = 0.1
			fh = 0.065
		"sol":
			fw = 0.1
			fh = 0.075
			lens = _mat(Color(0.05, 0.05, 0.08))
			lens.metallic = 0.8
			lens.roughness = 0.15
		"abuela":
			fw = 0.075
			fh = 0.045
			y = 0.0
			frame = _shiny(Color(0.9, 0.7, 0.25))
		"colores":
			frame = _mat(Color(1.0, 0.35, 0.6))
	for gx in [-0.065, 0.065]:
		_box(Vector3(fw, fh, 0.012), Vector3(gx, y, -0.136), frame, head)
		_box(Vector3(fw - 0.02, fh - 0.02, 0.014), Vector3(gx, y, -0.137), lens, head)
		if t == "redondas":
			# esquinas recortadas: en pixel art parecen redondas
			for cx in [-1, 1]:
				for cy in [-1, 1]:
					_box(Vector3(0.012, 0.012, 0.016), Vector3(gx + cx * (fw / 2 - 0.006), y + cy * (fh / 2 - 0.006), -0.138), _mat(cfg.skin), head)
	_box(Vector3(0.04, 0.012, 0.012), Vector3(0, y + 0.015, -0.137), frame, head)
	for sx in [-0.135, 0.135]:
		_box(Vector3(0.01, 0.01, 0.13), Vector3(sx, y + 0.01, -0.07), frame, head)  # patillas


## Mueve la boca unos segundos (frases del chat; luego, chat de voz).
func talk(seconds: float) -> void:
	_talk_t = max(_talk_t, seconds)


## Zonas del cuerpo para los disparos: [zona, centro global, radio].
func zonas_impacto() -> Array:
	var r: Array = []
	r.append(["cabeza", head.global_transform * Vector3(0, 0.0, 0), 0.15])
	for y in [-0.14, 0.0, 0.14]:
		r.append(["pecho", torso.global_transform * Vector3(0, y, 0), 0.16])
	for a in [arm_l, arm_r]:
		for d in [0.06, 0.2, 0.34]:
			r.append(["brazo", a.global_transform * Vector3(0, 0, -d), 0.065])
	if stand_k > 0.5:
		for lg in legs:
			r.append(["pierna", lg.hip.global_transform * Vector3(0, -0.16, 0), 0.1])
			r.append(["pierna", lg.knee.global_transform * Vector3(0, -0.14, 0), 0.09])
	else:
		r.append(["pierna", seat_legs.global_position, 0.17])
	return r


var _hombro_x := 0.25


func _make_arm(x: float, shirt_m: Material, skin_m: Material) -> Node3D:
	_hombro_x = absf(x)
	var pivot := Node3D.new()
	pivot.position = Vector3(x, 0.24, 0.06)
	pivot.rotation.x = ARM_REST
	add_child(pivot)
	_box(Vector3(0.1, 0.1, 0.24), Vector3(0, 0, -0.1), shirt_m, pivot)
	_box(Vector3(0.09, 0.09, 0.16), Vector3(0, 0, -0.29), skin_m, pivot)
	_box(Vector3(0.1, 0.07, 0.08), Vector3(0, 0, -0.4), skin_m, pivot)
	return pivot


# ---------------------------------------------------------------- vasos en la mesa

const DRINK_COLORS := {"cafe": Color(0.35, 0.2, 0.1), "ron": Color(0.8, 0.5, 0.15), "morir": Color(1, 0.7, 0.4), "agua": Color(0.6, 0.85, 1)}
const ACTION_TIME := {"play": 0.45, "tap": 0.6, "drink": 1.8, "slam": 0.55, "shuffle": 1.2, "cheer": 0.9,
	"facepalm": 1.2, "laugh": 1.3, "standup": 1.8, "thumbs": 1.1, "wipe": 2.0,
	"dance": 3.2, "clap": 1.6, "point": 1.4, "stretch": 1.8, "wave": 1.4, "shove": 0.5, "stagger": 0.7,
	"choca": 1.0, "brindis": 1.6}
# emotes (de pie o sentado): poses de brazos y cabeza por tiempo
const EMOTE_POSE := ["dance", "clap", "point", "stretch", "wave", "shove", "stagger", "choca", "brindis"]


## Estilo de vaso del armario: "vaso", "jarrito" (barro) o "copa".
static var glass_style := "vaso"


static func _part(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)


static func make_glass(id: String) -> Node3D:
	var gl := Node3D.new()
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.9, 0.95, 1, 0.35)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	match glass_style:
		"jarrito":
			glass.albedo_color = Color(0.72, 0.38, 0.2, 1.0)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			var clay := StandardMaterial3D.new()
			clay.albedo_color = Color(0.6, 0.3, 0.15)
			_part(gl, Vector3(0.015, 0.05, 0.012), Vector3(0.034, 0.0, 0), clay)  # asa
			_part(gl, Vector3(0.056, 0.012, 0.056), Vector3(0, 0.036, 0), clay)  # borde
		"copa":
			var stem := StandardMaterial3D.new()
			stem.albedo_color = Color(0.85, 0.95, 1, 0.6)
			stem.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_part(gl, Vector3(0.012, 0.05, 0.012), Vector3(0, -0.065, 0), stem)
			_part(gl, Vector3(0.05, 0.008, 0.05), Vector3(0, -0.09, 0), stem)
			gl.position.y += 0.0
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.08, 0.05)
	body.mesh = bm
	body.material_override = glass
	gl.add_child(body)
	# el líquido baja desde abajo: pivote en el fondo del vaso
	var level := Node3D.new()
	level.name = "Level"
	level.position = Vector3(0, -0.037, 0)
	gl.add_child(level)
	var liquid := StandardMaterial3D.new()
	liquid.albedo_color = DRINK_COLORS.get(id, Color.WHITE)
	liquid.emission_enabled = true
	liquid.emission = liquid.albedo_color
	liquid.emission_energy_multiplier = 0.25
	var lm := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.042, 0.055, 0.042)
	lm.mesh = lb
	lm.material_override = liquid
	lm.position = Vector3(0, 0.0275, 0)
	level.add_child(lm)
	if id == "ron" or id == "agua":
		# hielo
		var ice := MeshInstance3D.new()
		var ib := BoxMesh.new()
		ib.size = Vector3(0.018, 0.018, 0.018)
		ice.mesh = ib
		var im := StandardMaterial3D.new()
		im.albedo_color = Color(0.95, 1, 1, 0.8)
		im.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ice.material_override = im
		ice.position = Vector3(0.006, 0.05, 0.004)
		ice.rotation = Vector3(0.4, 0.6, 0)
		level.add_child(ice)
	return gl


## Vasos en la mesa: los vacíos (ya tomados) se apilan por tipo empezando en
## el portavasos; los llenos van en fila detrás. Devuelve los nodos con su
## posición en la meta "pos".
static func layout_glasses(full: Array, empties: Array, slot: Callable) -> Array:
	var nodes: Array = []
	var stacks: Array = []   # tipos en orden de aparición
	var count := {}
	for id in empties:
		if not count.has(id):
			stacks.append(id)
			count[id] = 0
		var gl := make_glass(id)
		var lv: Node3D = gl.get_node("Level")
		lv.scale.y = 0.06   # vacío: solo un culito
		gl.set_meta("pos", slot.call(stacks.find(id)) + Vector3(0, 0.085 * count[id], 0))
		count[id] += 1
		nodes.append(gl)
	for i in full.size():
		var gl := make_glass(full[i])
		gl.set_meta("pos", slot.call(stacks.size() + i))
		nodes.append(gl)
	return nodes


func set_drinks(list: Array) -> void:
	var sig := str(list, empty_types)
	if sig == _glass_sig:
		return
	_glass_sig = sig
	for gl in glasses:
		gl.queue_free()
	glasses.clear()
	if not slot_fn.is_valid():
		return
	for gl in layout_glasses(list, empty_types, slot_fn):
		add_child(gl)
		# los vasos son de la mesa: no se mueven cuando su dueño se levanta y camina
		gl.top_level = true
		gl.global_position = gl.get_meta("pos")
		glasses.append(gl)


# ---------------------------------------------------------------- animación

var _drink_glass: Node3D = null
var _drink_id := ""
var _after := ""        # efecto que dura tras beber
var _after_t := 0.0
var _fx: CPUParticles3D = null


# Director de animación (2026-10-04): prioridad de cada acción. Una acción no
# corta a otra más importante: espera (la última que llegó) y se hace después.
const ACTION_PRIO := {"drink": 3, "slam": 3, "play": 3, "stagger": 3, "shove": 3, "standup": 3,
	"dance": 2, "clap": 2, "point": 2, "wave": 2, "stretch": 2, "choca": 2, "brindis": 2,
	"cheer": 2, "laugh": 2, "facepalm": 2, "thumbs": 2,
	"tap": 1, "shuffle": 1, "wipe": 1}
var _queued := ""
var _queued_ms := 0


func act(kind: String) -> void:
	# tumbado en el suelo no hace gestos (solo se puede tambalear al levantarse)
	if fallen and kind != "stagger":
		return
	var cur_p: int = ACTION_PRIO.get(_action, 0) if _action != "" else 0
	var new_p: int = ACTION_PRIO.get(kind, 1)
	if _action != "" and cur_p > new_p:
		_queued = kind
		_queued_ms = Time.get_ticks_msec()
		return
	# la misma acción a medias no se reinicia (se veía a saltos)
	if kind == _action and _action_t < ACTION_TIME.get(kind, 0.45) * 0.5 and kind != "play":
		return
	_start_action(kind)


func _start_action(kind: String) -> void:
	_action = kind
	_action_t = 0.0
	if kind == "laugh":
		emotion("risa", 1.3)
	elif kind == "stagger":
		emotion("enfado", 2.0)
		# trastabilla hacia atrás y un poco de lado
		empujar(global_transform.basis.z + global_transform.basis.x * randf_range(-0.6, 0.6), 1.4)
	elif kind == "shove":
		empujar(-global_transform.basis.z, 0.6)   # se echa adelante al empujar
	elif kind == "slam":
		get_tree().create_timer(ACTION_TIME.slam * 0.55).timeout.connect(sacudir.bind(1.2))
	# brindar: un vaso en la mano mientras dura el gesto
	if is_instance_valid(_toast_glass):
		_toast_glass.queue_free()
	if kind == "brindis":
		_toast_glass = make_glass(_drink_id if _drink_id != "" else "ron")
		_toast_glass.position = Vector3(0, 0.05, -0.43)
		arm_r.add_child(_toast_glass)
		get_tree().create_timer(ACTION_TIME.brindis).timeout.connect(func():
			if is_instance_valid(_toast_glass) and _action != "brindis":
				_toast_glass.queue_free())


var _toast_glass: Node3D = null


## Cara de emoción unos segundos: "enfado", "susto" o "risa".
func emotion(kind: String, secs := 2.0) -> void:
	expr = kind
	_expr_t = secs


func wink() -> void:
	_wink_t = 0.45


## Coge un vaso, se lo bebe a la vista de todos y le queda el efecto.
func drink(id: String) -> void:
	if is_instance_valid(_drink_glass):
		_drink_glass.queue_free()
	_drink_id = id
	_drink_glass = make_glass(id)
	_drink_glass.position = Vector3(0, 0.05, -0.43)
	arm_r.add_child(_drink_glass)
	act("drink")


## Pose de un emote en el instante u (0..1).
func _emote_pose(kind: String, u: float) -> Dictionary:
	var k: float = sin(u * PI)
	var t := _action_t
	match kind:
		"dance":
			# merengue: brazos doblados que van y vienen, cadera y cabeza al ritmo
			return {"l": 0.4 + sin(t * 9.0) * 0.5, "r": 0.4 - sin(t * 9.0) * 0.5, "ly": -0.6, "ry": 0.6,
				"bz": sin(t * 9.0) * 0.12, "hz": sin(t * 9.0 + 0.5) * 0.15, "hy": abs(sin(t * 9.0)) * 0.03}
		"clap":
			var c: float = abs(sin(t * 14.0))
			return {"l": 0.9 * k, "r": 0.9 * k, "ly": -0.2 - 0.45 * c * k, "ry": 0.2 + 0.45 * c * k, "hx": 0.1 * k}
		"point":
			# si sabe a dónde señala, el brazo apunta allí (giro y altura)
			if point_at != null:
				var dl: Vector3 = to_local(point_at) - arm_r.position
				var aim_y: float = clamp(atan2(-dl.x, -dl.z), -1.2, 1.2)
				var aim_x: float = clamp(atan2(dl.y, Vector2(dl.x, dl.z).length()), -1.0, 0.8)
				return {"r": lerp(ARM_REST, aim_x, k), "ry": aim_y * k, "hx": aim_x * 0.4 * k}
			return {"r": lerp(ARM_REST, 0.15, k), "ry": 0.0, "hx": 0.05}
		"stretch":
			return {"l": lerp(ARM_REST, 3.0, k), "r": lerp(ARM_REST, 3.0, k), "hx": 0.35 * k, "hy": 0.03 * k}
		"wave":
			return {"r": lerp(ARM_REST, 2.7, k), "ry": sin(t * 12.0) * 0.5 * k, "hz": 0.12 * k}
		"shove":
			return {"l": lerp(ARM_REST, 0.05, k), "r": lerp(ARM_REST, 0.05, k), "ly": -0.15, "ry": 0.15}
		"choca":
			# mano arriba y adelante; a mitad, ¡plas! (un golpecito hacia delante)
			var hit: float = 1.0 - abs(u - 0.5) * 4.0 if abs(u - 0.5) < 0.25 else 0.0
			return {"r": lerp(ARM_REST, 2.3, k) - 0.35 * hit, "ry": 0.25, "hx": 0.12 * k, "bz": -0.05 * hit}
		"brindis":
			# levanta el vaso hacia el centro, chin chin, y un sorbito
			var up: float = smoothstep(0.0, 0.3, u) * (1.0 - smoothstep(0.85, 1.0, u))
			return {"r": lerp(ARM_REST, 1.15, up) + sin(t * 20.0) * 0.04 * up, "ry": 0.35 * up, "hx": 0.2 * up}
		"stagger":
			return {"l": ARM_REST + 1.2 * k, "r": ARM_REST + 0.6 * k, "bz": sin(t * 18.0) * 0.18 * k, "hx": -0.2 * k}
	return {}


## De pie: piernas, silla y fichas en la mano.
func _pose_standing(delta: float) -> void:
	if legs.is_empty():
		return
	var standing := stand_k > 0.02
	seat_legs.visible = not standing
	_walk_ph += delta * 9.0 * walk_amt
	for lg in legs:
		lg.hip.visible = standing
		# sentado: muslo hacia delante y espinilla colgando; de pie: rectas
		var swing: float = sin(_walk_ph + (PI if lg.side > 0 else 0.0)) * 0.55 * minf(walk_amt, 1.2)
		lg.hip.rotation.x = lerp(PI / 2, swing, stand_k)
		lg.knee.rotation.x = lerp(-PI / 2, -max(0.0, -swing) * 1.1 if walk_amt > 0.05 else 0.0, stand_k)
	# la silla se queda en su sitio de la mesa: al levantarse se corre un poco
	# hacia atrás y al sentarse vuelve (nunca sigue al cuerpo)
	if is_instance_valid(chair) and (chair.top_level or not own_chair) and standing != _chair_out:
		_chair_out = standing
		var dest: Vector3 = chair_home.origin + (chair_home.basis.z * 0.18 if standing else Vector3.ZERO)
		chair.create_tween().tween_property(chair, "global_position", dest, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# fichas escondidas en las manos
	if hold_tiles and stand_k > 0.5 and not is_instance_valid(_held):
		_held = Node3D.new()
		var ivory := _tile_mat()
		for i in 4:
			_box(Vector3(0.05, 0.1, 0.018), Vector3(-0.06 + i * 0.04, 0, -0.02 * i), ivory, _held)
		_held.position = Vector3(0, 0.06, -0.2)
		torso.add_child(_held)
	elif (not hold_tiles or stand_k < 0.5) and is_instance_valid(_held):
		_held.queue_free()
		_held = null


## Tumbado en el suelo (le dieron un manotazo con fuerza): cae de espaldas
## con estrellitas girando sobre la cabeza y se levanta solo. La vista baja
## su altura (pie._tick_remote) mientras fallen_k > 0.
func _tick_fallen(delta: float) -> void:
	var goal := 1.0 if (fallen or muerto) else 0.0
	fallen_k = move_toward(fallen_k, goal, delta * (3.0 if (fallen or muerto) else 1.6))
	rotation.x = -PI / 2.0 * 0.92 * smoothstep(0.0, 1.0, fallen_k)
	if fallen_k > 0.6 and not muerto and not is_instance_valid(_stars):
		_stars = Node3D.new()
		var st_m := StandardMaterial3D.new()
		st_m.albedo_color = Color(1, 0.9, 0.3)
		st_m.emission_enabled = true
		st_m.emission = Color(1, 0.85, 0.2)
		st_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for i in 4:
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.05, 0.05, 0.05)
			b.mesh = bm
			b.material_override = st_m
			b.position = Vector3(cos(i * TAU / 4.0) * 0.18, 0, sin(i * TAU / 4.0) * 0.18)
			_stars.add_child(b)
		head.add_child(_stars)
		_stars.position = Vector3(0, 0.0, 0.32)   # tumbado: «encima» de la cabeza es hacia su espalda
	elif fallen_k < 0.3 and is_instance_valid(_stars):
		_stars.queue_free()
		_stars = null
	if is_instance_valid(_stars):
		_stars.rotation.z += delta * 5.0


## Material de las fichas que lleva en la mano: la skin de fichas puesta en la
## mesa (cuerpo de TILE_STYLES de view3d.gd); marfil si no está en la mesa.
func _tile_mat() -> StandardMaterial3D:
	var v = get_parent()
	if v != null and "tile_style" in v and v.TILE_STYLES.has(v.tile_style):
		return _mat(v.TILE_STYLES[v.tile_style].body)
	return _mat(Color(0.96, 0.94, 0.86))


## La ficha que tiene en la mano mientras juguetea (boca abajo: no se ve cuál es).
func _tick_fiddle_tile(fid: int) -> void:
	var want: bool = fid >= 2
	if want and not is_instance_valid(_fiddle_tile):
		_fiddle_tile = Node3D.new()
		_box(Vector3(0.055, 0.016, 0.11), Vector3.ZERO, _tile_mat(), _fiddle_tile)
		_fiddle_tile.position = Vector3(0, -0.02, -0.46)
		arm_r.add_child(_fiddle_tile)
	elif not want and is_instance_valid(_fiddle_tile):
		_fiddle_tile.queue_free()
		_fiddle_tile = null
	# al llevarla a una punta el brazo se estira hasta allí (y vuelve después)
	var largo: float = _alcance / 0.46 if fid == 3 else 1.0
	arm_r.scale.z = lerp(arm_r.scale.z, largo, 0.15)
	if is_instance_valid(_fiddle_tile):
		# vueltas entre los dedos; al llevarla a la punta va quieta y plana
		var spin: float = 0.0 if fid == 3 else sin(_fiddle_t * 3.2) * 0.9 + _fiddle_t * 0.6
		_fiddle_tile.rotation = Vector3(0.0, spin, sin(_fiddle_t * 2.1) * 0.25 if fid == 2 else 0.0)
		_fiddle_tile.scale = Vector3(1, 1, 1.0 / maxf(arm_r.scale.z, 0.01))   # la ficha no se estira con el brazo


func _particles(color: Color, amount: int, up: float, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.018, 0.018, 0.018)
	p.mesh = m
	var pm := StandardMaterial3D.new()
	pm.albedo_color = color
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = pm
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, up, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.15
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	return p


func _start_after(id: String) -> void:
	_after = id
	_after_t = 0.0
	if is_instance_valid(_fx):
		_fx.queue_free()
	match id:
		"cafe":
			_fx = _particles(Color(1, 1, 1, 0.6), 10, 0.25, 1.0)
			_fx.position = Vector3(0, 0.25, -0.15)
			head.add_child(_fx)
		"agua":
			_fx = _particles(Color(0.7, 0.95, 1, 0.9), 8, -0.2, 0.6)
			_fx.spread = 180.0
			_fx.position = Vector3(0, 0.05, -0.1)
			head.add_child(_fx)
		"morir":
			_fx = _particles(Color(1, 0.5, 0.6, 0.9), 6, 0.15, 0.9)
			_fx.position = Vector3(0, 0.22, -0.1)
			head.add_child(_fx)
		"ron":
			_fx = null
	if _fx:
		_fx.emitting = true
	_set_flush(id == "ron")


func _set_flush(on: bool) -> void:
	if _aseprite_face != null:
		tex_open = ImageTexture.create_from_image(_aseprite_frame(8 if on else 0))
		tex_blink = ImageTexture.create_from_image(_aseprite_frame(9 if on else 1))
		return
	var img := _paint_face(false)
	var img_b := _paint_face(true)
	if on:
		for im in [img, img_b]:
			for cx in [1, 2, 3, 12, 13, 14]:
				for cy in [9, 10]:
					im.set_pixel(cx, cy, Color(0.85, 0.25, 0.25))
	tex_open = ImageTexture.create_from_image(img)
	tex_blink = ImageTexture.create_from_image(img_b)


func _process(delta: float) -> void:
	_t += delta
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink_t = 0.12
		# a veces parpadea dos veces seguidas, como la gente
		_blink_in = 0.25 if randf() < 0.18 else randf_range(2.0, 5.0)
	_blink_cool -= delta
	_blink_t -= delta
	face_mat.albedo_texture = tex_blink if _blink_t > 0.0 else tex_open
	if _wink_t > 0.0:
		_wink_t -= delta
		face_mat.albedo_texture = tex_wink
	# emoción (unos segundos): enfado, susto o risa
	if expr != "":
		_expr_t -= delta
		if _expr_t <= 0.0:
			expr = ""
		elif tex_expr.has(expr) and _blink_t <= 0.0:
			face_mat.albedo_texture = tex_expr[expr]
	# hablando: la boca se abre y se cierra con sílabas irregulares
	_talk_t = max(_talk_t - delta, 0.0)
	var voice: float = max(talk_level, 0.7 if _talk_t > 0.0 else 0.0)
	if voice > 0.05 and _blink_t <= 0.0 and _wink_t <= 0.0:
		var syl: float = abs(sin(_t * 17.0) * sin(_t * 6.3 + 1.0))
		var open_k := syl * voice
		# la cabeza acompaña las sílabas con cabeceos pequeños
		_muelles.cabeza.v.x += (open_k - 0.3) * delta * 6.0 * peso
		if open_k > 0.45:
			face_mat.albedo_texture = tex_talk_wide
		elif open_k > 0.15:
			face_mat.albedo_texture = tex_talk

	var breathe := sin(_t * 2.2) * 0.008
	torso.scale.y = 1.0 + breathe
	var head_rot := Vector3(0, sin(_t * 0.7) * 0.08, 0)
	var l := ARM_REST
	var r := ARM_REST
	var ry := 0.0
	var ly := 0.0
	var head_y := 0.44 + breathe
	var body_z := 0.0
	var lean := 0.0
	var body_lift := 0.0

	if look_target != null:
		var d: Vector3 = to_local(look_target) - head.position
		head_rot.y = clamp(atan2(-d.x, -d.z), -1.1, 1.1)
		head_rot.x = clamp(atan2(d.y, Vector2(d.x, d.z).length()), -0.7, 0.8)
	# su jugador mueve la cabeza con el ratón: manda sobre la mirada automática
	if seat_head != Vector2.ZERO and stand_k < 0.5:
		head_rot.y = clamp(seat_head.x, -1.2, 1.2)
		head_rot.x = clamp(seat_head.y * 0.9, -0.7, 0.5)
	match state:
		"think":
			head_rot.z = 0.15
			head_rot.x = -0.15
			r = 1.15  # mano a la barbilla
			ry = 0.35
		"win":
			l = 2.7 + sin(_t * 14.0) * 0.25
			r = 2.7 - sin(_t * 14.0) * 0.25
			head_rot.x = 0.25
			head_y += abs(sin(_t * 10.0)) * 0.04
		"lose":
			head_rot.x = -0.45
			head_rot.y = 0.0
			l = ARM_REST + 0.15
			r = ARM_REST + 0.15
			lean = 0.08

	# efectos que quedan tras beber
	if _after != "":
		_after_t += delta
		match _after:
			"ron":
				body_z = sin(_t * 2.5) * 0.12  # se tambalea
				head_rot.z += sin(_t * 2.5 + 0.6) * 0.12
			"agua":
				if _after_t < 1.2:
					body_z = sin(_t * 60.0) * 0.03  # escalofrío
			"morir":
				head_y += abs(sin(_t * 6.0)) * 0.02
			"cafe":
				head_y += abs(sin(_t * 12.0)) * 0.006  # nervio
		if _after_t > 4.0:
			_after = ""
			_set_flush(false)
			if is_instance_valid(_fx):
				_fx.emitting = false

	if stand_k > 0.5:
		var sway := sin(_t * 1.3) * 0.035
		l = -PI / 2 + sway
		r = -PI / 2 - sway
		ly = 0.0
		ry = 0.0
	if _action != "":
		_action_t += delta
		var dur: float = ACTION_TIME.get(_action, 0.45)
		var u: float = clamp(_action_t / dur, 0.0, 1.0)
		var k: float = sin(u * PI)
		match _action:
			"play":
				r = lerp(r, -0.15, k)
				lean = -0.06 * k
			"slam":
				# el último golpe: brazo arriba y ¡pam!
				r = 1.4 if u < 0.5 else lerp(1.4, -0.35, min((u - 0.5) * 6.0, 1.0))
				lean = -0.1 * k
			"tap":
				r = ARM_REST + 0.1 + abs(sin(_action_t * 14.0)) * 0.35
			"shuffle":
				l = lerp(l, -0.25, k) + sin(_action_t * 18.0) * 0.12
				r = lerp(r, -0.25, k) - sin(_action_t * 18.0) * 0.12
				ly = sin(_action_t * 9.0) * 0.3
				ry = -sin(_action_t * 9.0) * 0.3
				lean = -0.08 * k
			"cheer":
				r = lerp(r, 2.8, k)
				head_y += k * 0.05
			"laugh":
				# se ríe: cabeza atrás, hombros que saltan, mano a la barriga
				head_rot.x = lerp(head_rot.x, 0.35, k) + sin(_action_t * 28.0) * 0.06 * k
				head_y += abs(sin(_action_t * 14.0)) * 0.02 * k
				l = lerp(l, -0.05, k)
				ly = lerp(0.0, -0.6, k)
				lean = 0.05 * k
			"standup":
				# todos de pie (capicúa)
				head_y += 0.16 * k
				body_lift = 0.16 * k
				l = lerp(l, 2.6, k)
				r = lerp(r, 2.6, k)
			"thumbs":
				# señas al compañero: pulgar arriba
				r = lerp(r, 0.85, k)
				ry = lerp(ry, 0.55, k)
				head_rot.z += 0.12 * k
			"wipe":
				# el colmadero limpia el mostrador
				r = lerp(r, -0.35, k)
				ry = sin(_action_t * 7.0) * 0.5 * k
				lean = -0.05 * k
			"facepalm":
				l = lerp(l, 1.25, k)
				ly = lerp(0.0, -0.45, k)
				head_rot.x = lerp(head_rot.x, -0.3, k)
			"drink":
				# subir (0-0.25), beber a tragos (0.25-0.75), bajar (0.75-1)
				var raise: float = smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.75, 1.0, u))
				var sip: float = clamp((u - 0.25) / 0.5, 0.0, 1.0)
				r = lerp(r, 0.55, raise)
				ry = lerp(ry, 0.5, raise)
				head_rot.x = lerp(head_rot.x, 0.45 + sin(sip * PI * 6.0) * 0.06, raise)
				head_rot.y = lerp(head_rot.y, 0.0, raise)
				if is_instance_valid(_drink_glass):
					_drink_glass.rotation.x = -1.3 * raise
					var lv: Node3D = _drink_glass.get_node("Level")
					lv.scale.y = max(1.0 - sip, 0.05)
		if _action_t >= dur:
			# la que esperaba (si no es vieja) va después
			if _queued != "" and Time.get_ticks_msec() - _queued_ms < 2500:
				var q := _queued
				_queued = ""
				get_tree().create_timer(0.05).timeout.connect(func(): act(q))
			_queued = ""
			if _action == "point":
				point_at = null
			if _action == "drink":
				# el vaso vacío vuelve a su portavasos (o a su pila del mismo tipo)
				empty_types.append(_drink_id)
				_glass_sig = ""
				if is_instance_valid(_drink_glass):
					_drink_glass.queue_free()
				_drink_glass = null
				_start_after(_drink_id)
			_action = ""

	# jugueteo con sus fichas (sentado, sin otra acción en marcha)
	var fid: int = fiddle if (_action == "" and stand_k < 0.5 and not covering) else 0
	if fid != 0:
		_fiddle_t += delta
	else:
		_fiddle_t = 0.0
	match fid:
		1:
			# repasa sus fichas: la mano va y viene sobre la bandeja y mira abajo
			r = ARM_REST + 0.32
			ry = sin(_fiddle_t * 2.6) * 0.38
			head_rot.x = -0.32
			head_rot.y = sin(_fiddle_t * 2.6) * 0.12
			lean = -0.04
		2:
			# ficha en la mano: le da vueltas y golpecitos, pensando dónde ponerla
			r = 0.15 + abs(sin(_fiddle_t * 5.0)) * 0.12 * (0.5 + 0.5 * sin(_fiddle_t * 0.9))
			ry = 0.22 + sin(_fiddle_t * 1.7) * 0.12
			head_rot.x = -0.22
			head_rot.z += sin(_fiddle_t * 1.3) * 0.08
			lean = -0.03
		3:
			# la lleva a la punta: se echa sobre la mesa, mira la punta y estira
			# el brazo hasta tener la ficha encima de donde la va a poner
			r = -0.12
			lean = -0.3
			ry = 0.0
			_alcance = 0.56
			if fiddle_to != null:
				var dl: Vector3 = to_local(fiddle_to) + Vector3(0, 0.05, 0) - arm_r.position
				var horiz := Vector2(dl.x, dl.z).length()
				ry = clamp(atan2(-dl.x, -dl.z), -1.0, 1.0)
				r = clamp(atan2(dl.y, horiz), -0.9, 0.15)
				_alcance = clamp(horiz - 0.2, 0.46, 0.64)   # el cuerpo se inclina; el brazo, poco
				head_rot.y = ry * 0.7
				head_rot.x = -0.38
	_tick_fiddle_tile(fid)

	# de pie: piernas que se estiran y caminan, silla que se queda atrás
	_pose_standing(delta)
	if stand_k > 0.5:
		lean = 0.0
		# de pie, la cabeza sigue su mirada: si mira a la mesa, baja la cabeza
		if look_target == null:
			head_rot.x = clamp(head_pitch * 0.9, -0.7, 0.5)
			head_rot.y = head_yaw
		if hold_tiles and _action == "":
			# las fichas, escondidas contra el pecho con las dos manos
			l = -0.35
			r = -0.35
			ly = -0.75
			ry = 0.75
		elif _action == "" and walk_amt > 0.05:
			var sw: float = minf(walk_amt, 1.4)
			l = -PI / 2 + sin(_walk_ph) * 0.45 * sw
			r = -PI / 2 - sin(_walk_ph) * 0.45 * sw
			lean = -0.035 * sw   # se inclina un poco al andar (más al correr)
			# el peso pasa de un pie a otro: sube en cada paso y se mece de lado
			body_lift += abs(sin(_walk_ph)) * 0.025 * sw
			body_z += sin(_walk_ph) * 0.045 * sw
	elif covering and _action == "":
		# tapando sus fichas: las dos manos sobre la bandeja
		l = -0.35
		r = -0.35
		ly = 0.35
		ry = -0.35
		lean = -0.08
	if _action != "" and _action in EMOTE_POSE:
		var em: Dictionary = _emote_pose(_action, clamp(_action_t / ACTION_TIME.get(_action, 1.0), 0.0, 1.0))
		l = em.get("l", l)
		r = em.get("r", r)
		ly = em.get("ly", ly)
		ry = em.get("ry", ry)
		head_rot.x += em.get("hx", 0.0)
		head_rot.z += em.get("hz", 0.0)
		body_z += em.get("bz", 0.0)
		head_y += em.get("hy", 0.0)
	_tick_muelles(delta)
	var mt: Vector2 = _muelles.tronco.x
	var mc: Vector2 = _muelles.cabeza.x
	head.position.y = head_y
	var yaw_antes := _head_rot.y
	_head_rot = _head_rot.lerp(head_rot, min(delta * 8.0, 1.0))
	# al girar la cabeza deprisa se parpadea (pasa al cambiar la mirada)
	if _blink_cool <= 0.0 and absf(_head_rot.y - yaw_antes) > delta * 2.5:
		_blink_t = 0.1
		_blink_cool = 1.2
		_blink_in = maxf(_blink_in, 1.5)
	head.rotation = _head_rot + Vector3(mc.x, 0, mc.y)
	_torso_z = lerp(_torso_z, body_z, min(delta * 6.0, 1.0))
	torso.rotation = Vector3(mt.x, 0, _torso_z + mt.y)
	torso.position.z = lerp(torso.position.z, 0.08 + lean, min(delta * 6.0, 1.0))
	torso.position.y = lerp(torso.position.y, 0.04 + body_lift, min(delta * 8.0, 1.0))
	head.position.z = lerp(head.position.z, 0.06 + lean * 1.5, min(delta * 6.0, 1.0))
	head.position.x = lerp(head.position.x, -body_z * 0.25, min(delta * 6.0, 1.0))
	# la cabeza y los hombros van montados en el tronco: lo siguen al inclinarse
	var sobre_tronco := Vector3(-(_torso_z + mt.y) * 0.25, 0, mt.x * 0.25)
	head.position += (sobre_tronco - _sobre_tronco)
	_sobre_tronco = sobre_tronco
	# los hombros van montados en el tronco: siguen su altura, su inclinación
	# hacia delante (lean) y su giro de lado; antes solo la altura, y al estirarse
	# a por una ficha el brazo se separaba del cuerpo
	for a in [arm_l, arm_r]:
		var hombro := Vector3(signf(a.position.x) * _hombro_x, 0.20, -0.02)
		a.position = torso.transform * hombro
	# con la pistola: el brazo derecho al frente, hacia donde mira
	if armado and stand_k > 0.5 and not muerto:
		r = clamp(head_pitch, -0.9, 0.7) + shot_kick * 0.35
		ry = 0.0
		if is_instance_valid(_pistola) and _pistola_tipo != arma_tipo:
			_pistola.queue_free()
			_pistola = null
		if not is_instance_valid(_pistola):
			_pistola_tipo = arma_tipo
			_pistola = preload("res://scripts/modelo_arma.gd").crear(arma_tipo)
			_pistola.position = Vector3(0, 0, -0.45)
			arm_r.add_child(_pistola)
	if is_instance_valid(_pistola):
		_pistola.visible = armado and stand_k > 0.5 and not muerto
	shot_kick = move_toward(shot_kick, 0.0, delta * 5.0)
	arm_l.rotation.x = lerp(arm_l.rotation.x, l, min(delta * 10.0, 1.0))
	arm_r.rotation.x = lerp(arm_r.rotation.x, r, min(delta * 10.0, 1.0))
	arm_l.rotation.y = lerp(arm_l.rotation.y, ly, min(delta * 10.0, 1.0))
	arm_r.rotation.y = lerp(arm_r.rotation.y, ry, min(delta * 10.0, 1.0))
	_tick_fallen(delta)
