extends Control
## Pantallas fuera de la partida, todas dentro del colmado en 3D:
## inicio (la calle), modos (la pizarra), personaje (el espejo) y ajustes
## (la radio). También guarda el perfil y los ajustes en disco.

const Character := preload("res://scripts/character.gd")
const View := preload("res://scripts/view3d.gd")

const C_INK := Color(0.12, 0.07, 0.04)
const C_CREAM := Color(1.0, 0.95, 0.82)
const C_GOLD := Color(1.0, 0.8, 0.22)
const C_TURQ := Color(0.1, 0.62, 0.62)
const C_RED := Color(0.85, 0.22, 0.2)
const C_PINK := Color(1.0, 0.45, 0.6)
const C_CHALK := Color(0.95, 0.97, 0.92)

const PROFILE_PATH := "user://perfil.cfg"
const SETTINGS_PATH := "user://ajustes.cfg"
# las pruebas automáticas usan sus propios archivos y nunca tocan los del jugador
const TEST_PROFILE_PATH := "user://perfil_prueba.cfg"
const TEST_SETTINGS_PATH := "user://ajustes_prueba.cfg"
var _profile_path := PROFILE_PATH
var _settings_path := SETTINGS_PATH

# opciones del espejo
const SKINS := [Color(0.86, 0.66, 0.5), Color(0.72, 0.5, 0.35), Color(0.62, 0.42, 0.29), Color(0.5, 0.33, 0.22), Color(0.42, 0.28, 0.2), Color(0.33, 0.21, 0.14)]
const HATS := ["rizos", "mono", "calvo", "panuelo", "gorra", "paja"]
const HAT_NAMES := {"rizos": "Rizos", "mono": "Moño", "calvo": "Calvo", "panuelo": "Pañuelo", "gorra": "Gorra", "paja": "Sombrero"}
const HAIRS := [Color(0.1, 0.07, 0.05), Color(0.3, 0.17, 0.08), Color(0.55, 0.35, 0.15), Color(0.75, 0.75, 0.72), Color(0.6, 0.2, 0.1)]
const HAIR_NAMES := ["Negro", "Castaño", "Claro", "Canoso", "Rojizo"]
const SHIRTS := [Color(0.12, 0.65, 0.68), Color(0.25, 0.4, 0.8), Color(0.98, 0.78, 0.15), Color(0.85, 0.22, 0.25), Color(0.95, 0.95, 0.9), Color(0.2, 0.55, 0.3), Color(0.95, 0.5, 0.65), Color(0.95, 0.5, 0.15)]
const SHIRT_NAMES := ["Turquesa", "Azul", "Amarillo", "Rojo", "Blanco", "Verde", "Rosado", "Naranja"]
const PATTERNS := ["guayabera", "flores", "jersey", "rayas"]
const PATTERN_NAMES := {"guayabera": "Guayabera", "flores": "Flores", "jersey": "Camiseta 7", "rayas": "Rayas"}
const FACES := ["nada", "bigote", "barba"]
const FACE_NAMES := {"nada": "Afeitado", "bigote": "Bigote", "barba": "Barba"}
const BODIES := ["hombre", "mujer"]
const BODY_NAMES := {"hombre": "Hombre", "mujer": "Mujer"}
# accesorios: "" = ninguno (los tipos están en character.gd)
const GLASSES_NAMES := {"": "Ningunos", "redondas": "Redondos", "cuadradas": "Cuadrados", "sol": "De sol", "abuela": "De abuela", "colores": "De colores"}
const EARRINGS_NAMES := {"": "Ningunos", "aros": "Aros", "argollas": "Argollas", "bolitas": "Bolitas", "diamantes": "Diamantes", "perlas": "Perlas"}
const CHAIN_NAMES := {"": "Ninguna", "chopa": "Chopa", "riquito": "Riquito", "ajentao": "Ajentao", "bultero": "Bultero", "tiguere": "Tíguere"}
const LIPS_NAMES := {"": "Naturales", "rojos": "Rojos", "rosados": "Rosados", "morados": "Morados", "brillo": "Con brillo"}
const OPT_KEYS := {"glasses": GLASSES_NAMES, "earrings": EARRINGS_NAMES, "chain": CHAIN_NAMES, "lips": LIPS_NAMES}
var _mirror_tab := "cuerpo"
var _sala_modo := "aumentos"   # modo de la sala que creas (con aumentos o clásico)
var _sala_publica := false
var _sala_armas := false        # sala privada con armas (lo elige quien la crea)
var _online_ocupado := false
var _salas_cargando := false

# armario: [id, nombre, precio en pesos]
const CATALOG := {
	"fichas": [["marfil", "Marfil", 0], ["negras", "Negras", 60], ["madera", "Madera", 90], ["cristal", "Cristal", 120], ["doradas", "Doradas", 250]],
	"mesa": [["madera", "Madera", 0], ["blanca", "Plástico de calle", 80], ["turquesa", "Turquesa pintada", 100], ["casino", "Verde casino", 150]],
	"vaso": [["vaso", "Vaso", 0], ["jarrito", "Jarrito de barro", 50], ["copa", "Copa", 90]],
}
const CAT_NAMES := {"fichas": "Fichas", "mesa": "Mesa", "vaso": "Vasos"}

var m  # main
var _tab := "fichas"
var screen := ""
var profile: Dictionary = {}
var settings := {"vol": 0.8, "fx": 0.8, "mus": 0.5, "emisora": "fm", "shake": 1.0, "pixels": "grandes", "fullscreen": false, "idioma": "", "meta": 100}
var _from_game := false
var _page: Control


func _init(main_node) -> void:
	m = main_node
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--prueba") or a == "--autotest" or a == "--demo" or a == "--retratos" or a == "--recorrido":
			_profile_path = TEST_PROFILE_PATH
			_settings_path = TEST_SETTINGS_PATH
		# dos ventanas en el mismo PC (online): cada cuenta con su propio perfil
		if a.begins_with("--cuenta="):
			_profile_path = "user://perfil_%s.cfg" % a.trim_prefix("--cuenta=")
	_load()


# ---------------------------------------------------------------- disco

func _default_profile() -> Dictionary:
	var c: Dictionary = Character.PRESETS["nena"].duplicate()
	c["glasses"] = ""
	c["chain"] = ""
	_norm_look(c)
	# monedero que se guarda entre partidas y cosméticos
	c["pesos"] = 100
	c["owned"] = ["fichas:marfil", "mesa:madera", "vaso:vaso"]
	c["equip"] = {"fichas": "marfil", "mesa": "madera", "vaso": "vaso"}
	return c


func _load() -> void:
	profile = _default_profile()
	var cf := ConfigFile.new()
	if cf.load(_profile_path) == OK:
		for k in cf.get_section_keys("avatar"):
			profile[k] = cf.get_value("avatar", k)
	# personajes guardados (hasta 3): el activo se copia arriba en el perfil
	if not profile.has("personajes") or profile.personajes.is_empty():
		profile["personajes"] = [personaje_actual()]
		profile["activo"] = 0
	profile.activo = clampi(int(profile.get("activo", 0)), 0, profile.personajes.size() - 1)
	_norm_look(profile)
	for c in profile.personajes:
		_norm_look(c)
	var cs := ConfigFile.new()
	if cs.load(_settings_path) == OK:
		for k in cs.get_section_keys("ajustes"):
			settings[k] = cs.get_value("ajustes", k)
	settings.erase("amb")   # «Ambiente del colmado» ahora va con los efectos
	preload("res://scripts/accesibilidad.gd").normalizar(settings)
	# las pruebas automáticas, sin radio (no tarda en componer ni suena)
	if _settings_path == TEST_SETTINGS_PATH:
		settings.emisora = "off"


## Accesorios de sí/no (perfiles viejos) a su tipo; el cuerpo, si falta.
func _norm_look(c: Dictionary) -> void:
	for k in OPT_KEYS:
		var v = c.get(k, "")
		if v is bool:
			c[k] = (OPT_KEYS[k].keys()[1] if v else "")
	if not c.has("cuerpo"):
		c["cuerpo"] = "hombre"


func save() -> void:
	var cf := ConfigFile.new()
	for k in profile:
		cf.set_value("avatar", k, profile[k])
	cf.save(_profile_path)
	var cs := ConfigFile.new()
	for k in settings:
		cs.set_value("ajustes", k, settings[k])
	cs.save(_settings_path)


# ---------------------------------------------------------------- personajes

const MAX_PERSONAJES := 3
# lo que no es aspecto del personaje (monedero, armario, partidas…)
const NO_ASPECTO := ["pesos", "owned", "equip", "ganadas", "nombre", "personajes", "activo", "arma", "balas"]


## Aspecto del personaje activo (sin nombre ni monedero): lo que ven los demás.
func aspecto() -> Dictionary:
	var c := {}
	for k in profile:
		if not k in NO_ASPECTO:
			c[k] = profile[k]
	return c


func nombre_personaje() -> String:
	return str(profile.get("nombre", "")).strip_edges()


func personaje_actual() -> Dictionary:
	var c := aspecto()
	c["nombre"] = nombre_personaje()
	return c


## Guarda en su hueco el personaje que estás editando.
func guardar_personaje() -> void:
	profile.personajes[int(profile.activo)] = personaje_actual()
	save()


func elegir_personaje(i: int) -> void:
	profile.personajes[int(profile.activo)] = personaje_actual()
	profile.activo = i
	for k in profile.personajes[i]:
		profile[k] = profile.personajes[i][k]
	save()
	m.view.set_avatar_cfg(profile)


func nuevo_personaje() -> void:
	if profile.personajes.size() >= MAX_PERSONAJES:
		return
	profile.personajes[int(profile.activo)] = personaje_actual()
	var c: Dictionary = Character.PRESETS[Character.AVATARS.pick_random()].duplicate()
	c["glasses"] = ""
	c["chain"] = ""
	_norm_look(c)
	c["nombre"] = ""
	profile.personajes.append(c)
	elegir_personaje(profile.personajes.size() - 1)


func borrar_personaje() -> void:
	if profile.personajes.size() <= 1:
		return
	profile.personajes.remove_at(int(profile.activo))
	profile.activo = 0
	for k in profile.personajes[0]:
		profile[k] = profile.personajes[0][k]
	save()
	m.view.set_avatar_cfg(profile)


# ---------------------------------------------------------------- navegación

## Las pantallas del colmado en círculo: desde la pizarra, a la izquierda el
## espejo y a la derecha el armario (y del armario se vuelve al espejo). La
## radio de ajustes está arriba, en el mostrador, encima del armario.
const RING := ["personaje", "modos", "armario"]
const PLACE_NAMES := {"personaje": "Tu personaje", "modos": "Jugar", "amigos": "Jugar", "bots": "Jugar", "armario": "Armario", "ajustes": "Ajustes"}
var _prev := ""   # pantalla de la que vienes: GUARDAR, LISTO y VOLVER te devuelven a ella


## Abre una pantalla. from_game: se abrió desde la pausa (al volver, sigue la partida).
func open(name: String, from_game := false) -> void:
	var same: bool = name == screen
	if name != "personaje":
		m.view.probador_mostrar(false)
	if screen in ["ajustes", "accesibilidad"] and not same:
		save()
	if not same and screen != "" and not name == "accesibilidad" and not screen == "accesibilidad":
		_prev = screen
	if screen == "armario" and name != "armario":
		apply_equip()   # lo que estabas probando vuelve a lo que tienes puesto
		m.view.show_preview(false)
		m.sharp_rect.visible = false
	screen = name
	_from_game = from_game
	visible = true
	if is_instance_valid(_page):
		_page.queue_free()
	_page = Control.new()
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page)
	match name:
		"inicio":
			m.view.cam_to("calle", 1.2)
			_build_home()
		"modos":
			m.view.cam_to("pizarra", 1.3)
			_build_modes()
		"amigos":
			m.view.cam_to("pizarra", 0.6)
			_build_friends()
		"bots":
			m.view.cam_to("pizarra", 0.6)
			_build_bots()
		"publicas":
			m.view.cam_to("pizarra", 0.6)
			_build_public_rooms()
		"personaje":
			m.view.set_mirror_cfg(profile)
			_probador_arma()
			m.view.probador_mostrar(true)
			# la cámara se acerca a lo que toca cambiar en esta pestaña
			_enfoque = ENFOQUE_PESTANA.get(_mirror_tab, "cuerpo")
			m.view.cam_to("probador_" + _enfoque, 0.5 if same else 1.0)
			_build_mirror()
		"ajustes":
			m.view.cam_to("radio", 0.9)
			_build_settings()
		"accesibilidad":
			m.view.cam_to("radio", 0.0)
			_build_accessibility()
		"armario":
			m.view.show_preview(true)
			m.sharp_rect.visible = true
			m.view.cam_to("armario", 1.1)
			_build_wardrobe()
	if not from_game:
		_build_nav()
	if m.accesibilidad != null:
		m.accesibilidad._recorrer(_page)
		_encajar_paneles.call_deferred(_page)
	# los textos aparecen después de que llegue la cámara
	if same:
		return
	_page.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.45)
	tw.tween_property(_page, "modulate:a", 1.0, 0.3)

func _encajar_paneles(pagina) -> void:
	if not is_instance_valid(pagina):
		return
	await get_tree().process_frame
	if not is_instance_valid(pagina) or pagina.is_queued_for_deletion():
		return
	for panel in pagina.get_children():
		if panel is PanelContainer:
			panel.position.x = minf(panel.position.x, 632 - panel.size.x)


func close() -> void:
	m.view.probador_mostrar(false)
	if screen in ["ajustes", "accesibilidad"]:
		save()
	if screen == "armario":
		m.view.show_preview(false)
		m.sharp_rect.visible = false
	visible = false
	if is_instance_valid(_page):
		_page.queue_free()
	screen = ""


## Vuelve a la pantalla de la que viniste (la calle si no hay otra).
func _back() -> void:
	m.sfx.play("card", -6.0)
	if _from_game:
		close()
		m.resume_from_menu()
	else:
		open(_prev if _prev != "" and _prev != screen else "inicio")


## Flechas para dar la vuelta al colmado: ◀ y ▶ abajo, ▲ ajustes encima del
## armario, ▼ desde la radio de vuelta al armario y ⌂ a la calle.
func _build_nav() -> void:
	var ring_name := "modos" if screen in ["amigos", "bots"] else screen
	var i := RING.find(ring_name)
	if i >= 0:
		var left: String = RING[(i + RING.size() - 1) % RING.size()]
		var right: String = RING[(i + 1) % RING.size()]
		var lb := _nav_button("◀  " + PLACE_NAMES[left], func(): open(left))
		lb.position = Vector2(8, 328)
		_page.add_child(lb)
		var rb := _nav_button(PLACE_NAMES[right] + "  ▶", func(): open(right))
		_page.add_child(rb)
		_place_right(rb, 328)
	if screen == "armario":
		var ub := _nav_button("▲  Ajustes", func(): open("ajustes"), "gear")
		_page.add_child(ub)
		_center_x(ub, 6)
	if screen == "ajustes":
		var db := _nav_button("▼  Armario", func(): open("armario"))
		db.position = Vector2(8, 328)
		_page.add_child(db)
	if screen in ["personaje", "armario", "ajustes"]:
		var hb := _nav_button("⌂ Calle", func(): open("inicio"))
		hb.position = Vector2(8, 8)
		_page.add_child(hb)


## Botón-flecha del recorrido: madera oscura con letras crema y un vaivén al pasar.
func _nav_button(text: String, cb: Callable, icon := "") -> Button:
	for symbol in {"◀": "arrow_left", "▶": "arrow_right", "▲": "arrow_up", "▼": "arrow_down", "⌂": "home"}:
		if text.contains(symbol):
			if icon == "":
				icon = {"◀": "arrow_left", "▶": "arrow_right", "▲": "arrow_up", "▼": "arrow_down", "⌂": "home"}[symbol]
			text = text.replace(symbol, "").strip_edges()
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_stylebox_override("normal", m._box_style(Color(0.27, 0.15, 0.07, 0.92), C_GOLD, 2, 4, 6))
	b.add_theme_stylebox_override("hover", m._box_style(Color(0.4, 0.24, 0.1, 0.95), C_GOLD.lightened(0.3), 2, 4, 6))
	b.add_theme_stylebox_override("pressed", m._box_style(Color(0.2, 0.11, 0.05), C_GOLD, 2, 2, 6))
	b.add_theme_color_override("font_color", C_GOLD)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	if icon != "":
		b.icon = m._icon(icon, C_GOLD)
	b.pressed.connect(func():
		m.sfx.play("card", -6.0)
		cb.call())
	b.mouse_entered.connect(func():
		m.sfx.play("hover", -14.0, 0.2)
		b.pivot_offset = b.size / 2
		create_tween().tween_property(b, "scale", Vector2(1.06, 1.06), 0.1))
	b.mouse_exited.connect(func(): create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))
	return b


## Pega un control al borde derecho cuando ya sabe su tamaño.
func _place_right(c: Control, y: float) -> void:
	c.position = Vector2(560, y)
	await get_tree().process_frame
	if is_instance_valid(c):
		c.position = Vector2(632 - c.size.x, y)


func _center_x(c: Control, y: float) -> void:
	c.position = Vector2(280, y)
	await get_tree().process_frame
	if is_instance_valid(c):
		c.position = Vector2(m.CX - c.size.x / 2, y)


# ---------------------------------------------------------------- piezas

func _sign_button(text: String, col: Color, cb: Callable, size := 14) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", m._box_style(col, C_INK, 3, 5, 4))
	b.add_theme_stylebox_override("hover", m._box_style(col.lightened(0.2), C_INK, 3, 5, 4))
	b.add_theme_stylebox_override("pressed", m._box_style(col.darkened(0.15), C_INK, 3, 2, 4))
	var ink: bool = col.get_luminance() > 0.5
	b.add_theme_color_override("font_color", C_INK if ink else C_CREAM)
	b.add_theme_color_override("font_hover_color", C_INK if ink else Color.WHITE)
	b.add_theme_constant_override("outline_size", 0 if ink else 3)
	b.custom_minimum_size = Vector2(150, 30)
	b.pivot_offset = Vector2(75, 15)
	b.pressed.connect(func():
		m.sfx.play("hover", -4.0, 0.1)
		cb.call())
	b.mouse_entered.connect(func():
		m.sfx.play("hover", -14.0, 0.2)
		create_tween().tween_property(b, "rotation", randf_range(-0.04, 0.04), 0.12))
	b.mouse_exited.connect(func(): create_tween().tween_property(b, "rotation", 0.0, 0.12))
	return b


func _chalk_button(text: String, cb: Callable, enabled := true, note := "") -> Button:
	var b := Button.new()
	m._symbol_button(b, text)
	if note != "":
		b.text += "   · " + tr(note)
	b.flat = true
	b.add_theme_font_size_override("font_size", 15)
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, empty)
	b.add_theme_color_override("font_color", C_CHALK)
	b.add_theme_color_override("font_hover_color", C_GOLD)
	b.add_theme_color_override("font_disabled_color", Color(C_CHALK, 0.4))
	b.add_theme_constant_override("outline_size", 0)
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if enabled:
		b.pressed.connect(func():
			m.sfx.play("hover", -4.0, 0.1)
			cb.call())
	return b


func _label(text: String, size: int, col := C_CREAM) -> Label:
	return m._lbl(text, size, col)


# ---------------------------------------------------------------- inicio

func _build_home() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.position = Vector2(26, 130)
	_page.add_child(col)
	# O03: cada botón con su icono pixel art (arte/interfaz/inicio_*.aseprite)
	col.add_child(_con_icono(_sign_button("JUGAR", C_GOLD, func(): open("modos"), 16), "inicio_jugar"))
	# volver a la partida online de la que saliste (o que se cerró): un toque
	# O02: solo si el servidor confirma que la sala sigue y puedes volver; el
	# código no se enseña (streamers)
	var ultima: Dictionary = m.red.ultima_sala() if m.red != null else {}
	if not ultima.is_empty():
		var vb := _con_icono(_sign_button("VOLVER A LA SALA", C_TURQ, func(): _volver_a_sala(str(ultima.codigo))), "inicio_sala")
		vb.tooltip_text = tr("Vuelves a tu silla")
		vb.set_meta("codigo", ultima.codigo)
		vb.visible = false
		col.add_child(vb)
		_comprobar_sala(vb, col, str(ultima.codigo))
	col.add_child(_con_icono(_sign_button("PERSONAJE", C_TURQ, func(): open("personaje")), "inicio_personaje"))
	col.add_child(_con_icono(_sign_button("ARMARIO", C_PINK, func(): open("armario")), "inicio_armario"))
	var aj := _sign_button("AJUSTES", Color(0.45, 0.28, 0.14), func(): open("ajustes"))
	aj.icon = m._icon("gear", C_GOLD)
	aj.expand_icon = false
	col.add_child(aj)
	col.add_child(_con_icono(_sign_button("SALIR", C_RED, func(): get_tree().quit()), "inicio_salir"))


func _con_icono(b: Button, id: String) -> Button:
	b.icon = m._icon(id)
	b.expand_icon = false
	return b


var _volviendo := false


func _comprobar_sala(vb: Control, col: Control, code: String) -> void:
	var nombre := nombre_personaje().substr(0, 16)
	var viva: int = await m.red.sala_viva(code, nombre) if nombre != "" else -1
	if not is_instance_valid(vb):
		return   # se cambió de pantalla mientras se preguntaba
	if viva != 1:
		if viva == 0:
			m.red.olvidar_sala()   # sin conexión no se olvida: se vuelve a preguntar luego
		vb.queue_free()
		return
	vb.visible = true
	col.position.y = 112


## «VOLVER A LA SALA»: entra otra vez con el código guardado. Si la sala ya
## no existe, se olvida y se avisa.
func _volver_a_sala(code: String) -> void:
	if _volviendo:
		return
	var nombre := nombre_personaje().substr(0, 16)
	if nombre == "":
		open("personaje")
		return
	_volviendo = true
	# O02, inmersivo: cruzas la puerta del colmado a pie (sin enseñar el código)
	if is_instance_valid(_page):
		create_tween().tween_property(_page, "modulate:a", 0.0, 0.25)
	var cartel := _sign_button("Vuelves a tu silla…", C_GOLD, func(): pass, 13)
	cartel.disabled = true
	cartel.add_theme_stylebox_override("disabled", m._box_style(C_GOLD, C_INK, 3, 5, 4))
	cartel.add_theme_color_override("font_disabled_color", C_INK)
	cartel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cartel)
	cartel.size = cartel.get_combined_minimum_size()
	cartel.position = Vector2(m.CX - cartel.size.x / 2, 300)
	cartel.modulate.a = 0.0
	create_tween().tween_property(cartel, "modulate:a", 1.0, 0.3)
	m.view.cam_to("puerta", 1.4)
	var pasos := func():
		for i in 5:
			if not _volviendo:
				return
			m.sfx.play("step", -8.0)
			await get_tree().create_timer(0.3).timeout
	pasos.call()
	var err: String = await m.red.unirse(code, nombre, aspecto())
	_volviendo = false
	if is_instance_valid(cartel):
		var tw := cartel.create_tween()
		tw.tween_property(cartel, "modulate:a", 0.0, 0.25)
		tw.tween_callback(cartel.queue_free)
	if err != "":
		m.red.olvidar_sala()
		m.view.cam_to("calle", 1.0)   # das media vuelta: la sala ya cerró
		m._float(tr("Esa sala ya no está (%s)") % tr(err), Vector2(m.CX, 120), Color(1, 0.6, 0.5))
		if screen == "inicio":
			open("inicio")   # sin el botón
		return
	m.start_online()


## Meta elegida en la pizarra: 100 o 200 puntos.
func meta_actual() -> int:
	return 200 if int(settings.get("meta", 100)) == 200 else 100


# ---------------------------------------------------------------- pizarra de modos

var _chalk_font: SystemFont


## Letra de tiza escrita a mano (con alternativas si el sistema no la tiene).
func _chalk() -> SystemFont:
	if _chalk_font == null:
		_chalk_font = SystemFont.new()
		_chalk_font.font_names = PackedStringArray(["Segoe Print", "Ink Free", "Comic Sans MS", "Verdana"])
		_chalk_font.font_weight = 700
	return _chalk_font


func _chalk_label(text: String, size: int, col := C_CHALK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _chalk())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_color_override("font_shadow_color", Color(col, 0.18))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Rectángulo de la pizarra en pantalla, calculado con la cámara del sitio.
func _board_rect() -> Rect2:
	var vis_h: float = 2.0 * View.CHALK_CAM_D * tan(deg_to_rad(m.view.camera.fov / 2.0))
	var w_px: float = View.CHALK_W / (vis_h * m.W / 360.0) * m.W
	var h_px: float = View.CHALK_H / vis_h * 360.0
	return Rect2(Vector2(m.CX - w_px / 2, 180 - h_px / 2), Vector2(w_px, h_px))


## Trazo de tiza con pulso tembloroso.
func _chalk_line(from: Vector2, to: Vector2, col := C_CHALK, width := 2.0) -> Line2D:
	var ln := Line2D.new()
	ln.width = width
	ln.default_color = Color(col, 0.85)
	ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ln.end_cap_mode = Line2D.LINE_CAP_ROUND
	var steps := 8
	for k in steps + 1:
		var p := from.lerp(to, k / float(steps))
		if k > 0 and k < steps:
			p += Vector2(randf_range(-0.8, 0.8), randf_range(-1.2, 1.2))
		ln.add_point(p)
	return ln


## Iconos dibujados a tiza (32x32).
func _chalk_icon(kind: String) -> ImageTexture:
	var key := "chalk:" + kind
	if not m._icons.has(key):
		var source: Texture2D = load("res://arte/interfaz/tiza_%s.png" % kind)
		m._icons[key] = ImageTexture.create_from_image(source.get_image())
	return m._icons[key]

## Un modo de juego: recuadro a tiza con icono, nombre, descripción y acción.
func _mode_row(width: float, icon: String, title: String, sub: String, enabled: bool, cb: Callable, height := 44.0, accion := "JUGAR ▸") -> Button:
	if settings.texto > 0:
		height = ceilf(height * 1.6)
	var b := Button.new()
	b.custom_minimum_size = Vector2(width, height)
	b.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.draw_center = false
	normal.bg_color = Color(1, 1, 1, 0.03)
	normal.border_color = Color(C_CHALK, 0.0)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(1, 0.9, 0.5, 0.08)
	hover.draw_center = true
	hover.border_color = Color(C_GOLD, 0.9)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover if enabled else normal)
	b.add_theme_stylebox_override("pressed", hover if enabled else normal)
	b.add_theme_stylebox_override("disabled", normal)
	b.disabled = not enabled
	b.pivot_offset = Vector2(width / 2, height / 2)
	# recuadro a tiza (se dibuja con animación)
	var box := _chalk_rect(Vector2(width, height), Color(C_CHALK, 0.6 if enabled else 0.28))
	box.name = "Box"
	b.add_child(box)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_right = -10
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ic := TextureRect.new()
	ic.name = "Icon"
	ic.texture = _chalk_icon(icon)
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.custom_minimum_size = Vector2(30, 30)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.modulate.a = 1.0 if enabled else 0.4
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var txt := VBoxContainer.new()
	txt.alignment = BoxContainer.ALIGNMENT_CENTER
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.add_theme_constant_override("separation", -3)
	txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(txt)
	var tl := _chalk_label(title, 14, C_CHALK if enabled else Color(C_CHALK, 0.45))
	tl.name = "Title"
	txt.add_child(tl)
	var sl := _chalk_label(sub, 9, Color(C_CHALK, 0.7 if enabled else 0.35))
	sl.name = "Sub"
	# el texto largo ya no empuja «JUGAR» fuera de su sitio: se recorta con «…»
	sl.clip_text = true
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if settings.texto > 0:
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.clip_text = false
		sl.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	sl.custom_minimum_size.x = 10
	txt.add_child(sl)
	# columna fija a la derecha: «JUGAR ▸» y «PRONTO» alineados en todas las filas
	var col_w := 74.0
	if enabled:
		var go := HBoxContainer.new()
		go.name = "Action"
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		go.custom_minimum_size.x = col_w
		go.alignment = BoxContainer.ALIGNMENT_END
		go.add_theme_constant_override("separation", 2)
		var action_text := _chalk_label(tr(accion).replace("▸", "").strip_edges(), 13, C_GOLD)
		action_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		go.add_child(action_text)
		go.add_child(m._icon_rect(m._icon("arrow_right"), 10))
		h.add_child(go)
		b.pressed.connect(func():
			m.sfx.play("clack", -6.0, 0.1)
			cb.call())
		b.mouse_entered.connect(func():
			m.sfx.play("hover", -12.0, 0.2)
			create_tween().tween_property(b, "scale", Vector2(1.025, 1.025), 0.1)
			create_tween().tween_property(ic, "rotation", 0.15, 0.1))
		b.mouse_exited.connect(func():
			create_tween().tween_property(b, "scale", Vector2.ONE, 0.1)
			create_tween().tween_property(ic, "rotation", 0.0, 0.1))
	else:
		# sello «PRONTO» torcido, a tiza rosada
		var stamp := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = Color(C_PINK, 0.8)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		stamp.add_theme_stylebox_override("panel", sb)
		stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stamp.rotation = -0.14
		stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stamp.add_child(_chalk_label("PRONTO", 11, Color(C_PINK, 0.9)))
		stamp.name = "Action"
		var slot := Control.new()   # misma columna que «JUGAR ▸»
		slot.custom_minimum_size = Vector2(col_w, 0)
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(slot)
		slot.add_child(stamp)
		stamp.position = Vector2(4, -10)
	return b


## Rectángulo de esquinas redondeadas trazado a tiza, con pulso tembloroso.
func _chalk_rect(size: Vector2, col: Color) -> Line2D:
	var ln := Line2D.new()
	ln.width = 2.0
	ln.default_color = col
	ln.joint_mode = Line2D.LINE_JOINT_ROUND
	ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ln.end_cap_mode = Line2D.LINE_CAP_ROUND
	var r := 6.0
	var corners := [Vector2(r, 1), Vector2(size.x - r, 1), Vector2(size.x - 1, r), Vector2(size.x - 1, size.y - r),
		Vector2(size.x - r, size.y - 1), Vector2(r, size.y - 1), Vector2(1, size.y - r), Vector2(1, r), Vector2(r + 3, 1)]
	for i in corners.size() - 1:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[i + 1]
		var steps := int(max(2.0, a.distance_to(b) / 14.0))
		for k in steps:
			var p := a.lerp(b, k / float(steps))
			if k > 0:
				p += Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6))
			ln.add_point(p)
	ln.add_point(corners[-1])
	return ln


## Traza una línea de tiza poco a poco (de 0 a todos sus puntos).
func _draw_line_anim(ln: Line2D, dur: float) -> void:
	var pts: PackedVector2Array = ln.points
	if pts.size() < 2:
		return
	ln.clear_points()
	ln.add_point(pts[0])
	ln.add_point(pts[0])
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	var tw := ln.create_tween()
	tw.tween_method(func(k: float):
		if not is_instance_valid(ln):
			return
		var target := k * total
		var acc := 0.0
		var out := PackedVector2Array([pts[0]])
		for i in range(1, pts.size()):
			var seg := pts[i - 1].distance_to(pts[i])
			if acc + seg >= target:
				out.append(pts[i - 1].lerp(pts[i], (target - acc) / max(seg, 0.001)))
				break
			out.append(pts[i])
			acc += seg
		ln.points = out, 0.0, 1.0, dur)


## Escribe un texto letra a letra, como con tiza.
func _write_anim(l: Label, dur: float) -> void:
	l.visible_ratio = 0.0
	l.create_tween().tween_property(l, "visible_ratio", 1.0, dur)


func _tally(n: int) -> String:
	if n == 0:
		return "—"
	var out := ""
	for k in min(n, 20) / 5:
		out += "||||/ "
	out += "|".repeat(min(n, 20) % 5)
	if n > 20:
		out += " +%d" % (n - 20)
	return out.strip_edges()


func _build_modes() -> void:
	var r := _board_rect()
	var margin := 14.0
	var inner := r.grow(-margin)
	var area := Control.new()
	area.position = inner.position
	area.size = inner.size
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(area)
	# título y subrayado
	var title := _chalk_label("Hoy se juega", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, -6)
	title.size = Vector2(inner.size.x, 34)
	area.add_child(title)
	area.add_child(_chalk_line(Vector2(inner.size.x / 2 - 80, 30), Vector2(inner.size.x / 2 + 80, 29)))
	# modos
	var rows := VBoxContainer.new()
	rows.position = Vector2(0, 38)
	rows.size = Vector2(inner.size.x, 180)
	rows.add_theme_constant_override("separation", 5)
	if settings.texto > 0:
		var scroll := ScrollContainer.new()
		scroll.position = rows.position
		scroll.size = Vector2(inner.size.x, inner.size.y - 94)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		area.add_child(scroll)
		rows.position = Vector2.ZERO
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(rows)
	else:
		area.add_child(rows)
	var ancho_fila := inner.size.x - (14.0 if settings.texto > 0 else 0.0)
	# O05: un solo «Dominó con bots»; dentro se elige clásico o con aumentos
	rows.add_child(_mode_row(ancho_fila, "domino", "Dominó con bots",
		"Con Don Fello contra Yeya y Chichí", true, func(): open("bots")))
	# no empieza partida: abre crear sala, entrar con código y el buscador público
	rows.add_child(_mode_row(ancho_fila, "amigos", "Sala con amigos",
		"Crea una sala, entra con código o busca salas públicas", true, func(): open("amigos"), 44.0, "ABRIR ▸"))
	rows.add_child(_mode_row(ancho_fila, "trofeo", "Clasificatoria",
		"Solo o en pareja · sube tu ELO", false, func(): pass))
	# pie: volver, partidas ganadas y meta
	var foot_y := inner.size.y - 15
	area.add_child(_chalk_line(Vector2(0, foot_y - 6), Vector2(inner.size.x, foot_y - 7), C_CHALK, 1.0))
	var back := Button.new()
	back.flat = true
	back.focus_mode = Control.FOCUS_NONE
	m._symbol_button(back, "‹ Volver a la calle")
	back.add_theme_font_override("font", _chalk())
	back.add_theme_font_size_override("font_size", 12)
	back.add_theme_color_override("font_color", C_CHALK)
	back.add_theme_color_override("font_hover_color", C_GOLD)
	back.add_theme_constant_override("outline_size", 0)
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus"]:
		back.add_theme_stylebox_override(st, empty)
	back.position = Vector2(-4, foot_y - 4)
	back.custom_minimum_size = Vector2(124, 0)   # que el texto no se corte
	back.pressed.connect(func(): open("inicio"))
	area.add_child(back)
	var wins := _chalk_label(tr("Ganadas  %s") % _tally(int(profile.get("ganadas", 0))), 11, Color(C_CHALK, 0.8))
	wins.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wins.position = Vector2(0, foot_y)
	wins.size = Vector2(inner.size.x - 104, 18)
	if settings.texto > 0:
		wins.position.y = foot_y - 28
		wins.size.x = inner.size.x
		wins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	area.add_child(wins)
	# meta de la partida (100 o 200): se toca para cambiarla; vale también para la sala
	var meta_b := _meta_button()
	meta_b.position = Vector2(inner.size.x - 100 - back.position.x, 2)
	back.add_child(meta_b)   # aparece con el pie (la animación de «back»)
	_animate_board(area, title, rows, back, wins)


## Meta de la partida (100 o 200) a tiza: se toca para cambiarla.
func _meta_button() -> Button:
	var meta_b := _chalk_button("", func(): pass)
	meta_b.add_theme_font_override("font", _chalk())
	meta_b.add_theme_font_size_override("font_size", 12)
	meta_b.add_theme_color_override("font_color", C_GOLD)
	meta_b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta_b.tooltip_text = tr("Toca para jugar a 100 o a 200 puntos")
	m._symbol_button(meta_b, "Meta %d ▾", [meta_actual()])
	meta_b.pressed.connect(func():
		settings.meta = 200 if meta_actual() == 100 else 100
		save()
		m._symbol_button(meta_b, "Meta %d ▾", [meta_actual()]))
	meta_b.size = Vector2(100, 18)
	return meta_b


## O05 · Dominó con bots: dos folletos de tiza que llenan la pizarra, a la
## izquierda el clásico y a la derecha con aumentos y bebidas.
func _build_bots() -> void:
	var r := _board_rect()
	var inner := r.grow(-14.0)
	var area := Control.new()
	area.position = inner.position
	area.size = inner.size
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(area)
	var title := _chalk_label("Dominó con bots", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, -6)
	title.size = Vector2(inner.size.x, 32)
	area.add_child(title)
	area.add_child(_chalk_line(Vector2(inner.size.x / 2 - 80, 27), Vector2(inner.size.x / 2 + 80, 26)))
	var foot_y := inner.size.y - 15
	var gap := 10.0
	var w := (inner.size.x - gap) / 2.0
	var h := foot_y - 46.0
	var folletos := [
		["folleto_clasico", "Clásico", "Sin aumentos ni bebidas · el renuncio pierde la partida", "clasico"],
		["folleto_aumentos", "Con aumentos", "Un aumento cada mano · bebidas y tienda del colmado", "aumentos"],
	]
	for k in folletos.size():
		var f: Array = folletos[k]
		var b := _folleto(Vector2(w, h), f[0], f[1], f[2], func():
			close()
			m.start_game(false, f[3]))
		b.position = Vector2(k * (w + gap), 36)
		area.add_child(b)
		b.modulate.a = 0.0
		var tw := b.create_tween()
		tw.tween_interval(0.1 + 0.12 * k)
		tw.tween_property(b, "modulate:a", 1.0, 0.25)
	area.add_child(_chalk_line(Vector2(0, foot_y - 6), Vector2(inner.size.x, foot_y - 7), C_CHALK, 1.0))
	var back := _chalk_button("‹ Volver a la pizarra", func(): open("modos"))
	back.add_theme_font_override("font", _chalk())   # igual que «Volver a la calle»
	back.add_theme_font_size_override("font_size", 12)
	back.custom_minimum_size = Vector2(130, 0)
	back.position = Vector2(-4, foot_y - 4)
	area.add_child(back)
	var meta_b := _meta_button()
	meta_b.position = Vector2(inner.size.x - 100, foot_y - 2)
	area.add_child(meta_b)


## Un folleto: recuadro de tiza que se puede tocar, con título, dibujo,
## dos líneas de qué trae y «JUGAR ▸».
func _folleto(size: Vector2, icon: String, title: String, sub: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = size
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.draw_center = false
	normal.set_corner_radius_all(8)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.draw_center = true
	hover.bg_color = Color(1, 0.9, 0.5, 0.08)
	hover.border_color = Color(C_GOLD, 0.9)
	hover.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_child(_chalk_rect(size, Color(C_CHALK, 0.6)))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 8
	v.offset_bottom = -8
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var tl := _chalk_label(title, 16)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tl)
	var ic := TextureRect.new()
	ic.texture = _chalk_icon(icon)
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.custom_minimum_size = Vector2(64, 64)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ic)
	var sl := _chalk_label(sub, 10, Color(C_CHALK, 0.75))
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)
	var go := _chalk_label("JUGAR ▸", 13, C_GOLD)
	go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(go)
	b.pressed.connect(cb)
	return b


## Sala con amigos, en la pizarra: tu nombre, crear una sala o entrar con código.
func _build_friends() -> void:
	var r := _board_rect()
	var inner := r.grow(-14.0)
	var area := Control.new()
	area.position = inner.position
	area.size = inner.size
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(area)
	var title := _chalk_label("Sala con amigos", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, -6)
	title.size = Vector2(inner.size.x, 32)
	area.add_child(title)
	area.add_child(_chalk_line(Vector2(inner.size.x / 2 - 90, 28), Vector2(inner.size.x / 2 + 90, 27)))
	# tu personaje del espejo: icono y nombre (tocar para cambiarlo)
	var sin_nombre := nombre_personaje() == ""
	var yo := _chalk_button(nombre_personaje() if not sin_nombre else "Ponte un nombre", func(): open("personaje"))
	if not sin_nombre:
		yo.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # un «Ron» no sale como «Rum»
	yo.icon = m._icon("inicio_personaje")
	yo.expand_icon = false
	yo.add_theme_constant_override("icon_max_width", 16)
	yo.add_theme_color_override("font_color", C_PINK if sin_nombre else C_GOLD)
	yo.add_theme_font_size_override("font_size", 13)
	yo.tooltip_text = tr("Juegas con tu personaje del espejo. Toca para cambiarlo.")
	yo.alignment = HORIZONTAL_ALIGNMENT_LEFT
	area.add_child(yo)
	yo.size = yo.get_combined_minimum_size()
	yo.position = Vector2(inner.size.x - yo.size.x, 0)
	var aviso_nombre := "Ponle un nombre a tu personaje en el espejo para jugar online."
	var estado := _chalk_label(aviso_nombre if sin_nombre else "", 11, C_PINK)
	estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ir := func(code: String):
		var request_page := _page
		if _online_ocupado or _salas_cargando:
			return
		var nombre := nombre_personaje().substr(0, 16)
		if nombre == "":
			estado.add_theme_color_override("font_color", C_PINK)
			estado.text = aviso_nombre
			return
		estado.add_theme_color_override("font_color", C_GOLD)
		estado.text = "Llamando al colmado…"
		var look := aspecto()
		var err := ""
		_online_ocupado = true
		if code == "":
			err = await m.red.crear_sala(nombre, look, _sala_modo, meta_actual(), _sala_publica, _sala_armas)
		else:
			err = await m.red.unirse(code, nombre, look)
		_online_ocupado = false
		if not is_instance_valid(request_page) or request_page != _page:
			if err == "":
				m.red.salir()
			return
		if err != "":
			if not is_instance_valid(estado):
				return
			estado.add_theme_color_override("font_color", C_PINK)
			estado.text = err
			return
		m.start_online()
	# dos columnas a tiza: CREAR (izquierda) y UNIRSE (derecha)
	var ancho_izq: float = floor(inner.size.x * 0.62)
	var arriba := 40.0
	var alto: float = inner.size.y - arriba - 40.0
	var izq := Control.new()
	izq.position = Vector2(0, arriba)
	izq.size = Vector2(ancho_izq - 8, alto)
	izq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	izq.add_child(_chalk_rect(izq.size, Color(C_CHALK, 0.5)))
	area.add_child(izq)
	var der := Control.new()
	der.position = Vector2(ancho_izq + 4, arriba)
	der.size = Vector2(inner.size.x - ancho_izq - 4, alto)
	der.mouse_filter = Control.MOUSE_FILTER_IGNORE
	der.add_child(_chalk_rect(der.size, Color(C_CHALK, 0.5)))
	area.add_child(der)
	var t1 := _chalk_label("Crear sala", 14, C_GOLD)
	t1.position = Vector2(8, 2)
	izq.add_child(t1)
	var t2 := _chalk_label("Unirse", 14, C_GOLD)
	t2.position = Vector2(8, 2)
	der.add_child(t2)
	# cuatro opciones: cada una es un icono con una palabra; tocarla la cambia
	var fila := GridContainer.new()
	fila.columns = 2
	fila.position = Vector2(8, 26)
	fila.size = Vector2(izq.size.x - 16, 70)
	fila.add_theme_constant_override("h_separation", 6)
	fila.add_theme_constant_override("v_separation", 8)
	izq.add_child(fila)
	var ops := {}
	var pinta := func():
		ops.modo.icon = _chalk_icon("sala_" + _sala_modo)
		ops.modo.text = tr("Aumentos") if _sala_modo == "aumentos" else tr("Clásico")
		ops.modo.tooltip_text = tr("Con aumentos: una carta cada mano, bebidas y tienda.") if _sala_modo == "aumentos" else tr("Clásico: sin aumentos ni bebidas; el renuncio pierde la partida.")
		ops.meta.text = tr("%d puntos") % meta_actual()
		ops.privada.icon = _chalk_icon("sala_publica" if _sala_publica else "sala_privada")
		ops.privada.text = tr("Pública") if _sala_publica else tr("Privada")
		ops.privada.tooltip_text = tr("Pública: cualquiera la encuentra en «Buscar».") if _sala_publica else tr("Privada: solo entra quien tenga el código.")
		ops.armas.icon = _chalk_icon("sala_armas" if _sala_armas and not _sala_publica else "sala_sin_armas")
		ops.armas.text = tr("Con armas") if _sala_armas and not _sala_publica else tr("Sin armas")
		ops.armas.disabled = _sala_publica
		ops.armas.tooltip_text = tr("Las armas solo van en salas privadas.") if _sala_publica else tr("Con armas: pistola en las piernas; los tiros quitan vida.")
	var opcion := func(clave: String, al_tocar: Callable) -> Button:
		var b := _chalk_button("", func():
			al_tocar.call()
			pinta.call())
		b.custom_minimum_size = Vector2((izq.size.x - 22) / 2, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 40)
		b.add_theme_constant_override("h_separation", 6)
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_color_override("font_color", C_GOLD)
		b.add_theme_color_override("icon_hover_color", Color(1.2, 1.15, 0.9))
		ops[clave] = b
		fila.add_child(b)
		return b
	opcion.call("modo", func(): _sala_modo = "clasico" if _sala_modo == "aumentos" else "aumentos")
	var mb: Button = opcion.call("meta", func():
		settings.meta = 200 if meta_actual() == 100 else 100
		save())
	mb.icon = _chalk_icon("sala_meta")
	mb.tooltip_text = tr("Puntos para ganar la partida: 100 o 200.")
	opcion.call("privada", func(): _sala_publica = not _sala_publica)
	opcion.call("armas", func(): _sala_armas = not _sala_armas)
	pinta.call()
	var crear := _sign_button("CREAR", C_GOLD, func(): ir.call(""), 14)
	# icono a todo color (el de tiza se perdía sobre el dorado): mesa con fichas y «+»
	crear.icon = load("res://arte/interfaz/boton_crear_sala.png")
	crear.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crear.expand_icon = false
	crear.add_theme_constant_override("icon_max_width", 26)
	crear.custom_minimum_size = Vector2(110, 28)
	izq.add_child(crear)
	crear.size = crear.get_combined_minimum_size()
	crear.position = Vector2((izq.size.x - crear.size.x) / 2, izq.size.y - crear.size.y - 8)
	# unirse: código + entrar, o buscar salas públicas
	var code_in := _chalk_input("", 6)
	code_in.placeholder_text = "CÓDIGO"
	code_in.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_in.tooltip_text = tr("El código de 6 letras que te pasó quien creó la sala.")
	code_in.position = Vector2(10, 28)
	code_in.size = Vector2(der.size.x - 20, 26)
	code_in.text_changed.connect(func(t: String):
		var c := t.to_upper()
		if c != t:
			code_in.text = c
			code_in.caret_column = c.length())
	der.add_child(code_in)
	var enter := _chalk_button("Entrar", func():
		if code_in.text.strip_edges().length() != 6:
			estado.add_theme_color_override("font_color", C_PINK)
			estado.text = "El código tiene 6 letras"
			return
		ir.call(code_in.text.strip_edges()))
	enter.icon = _chalk_icon("sala_entrar")
	enter.expand_icon = false
	enter.add_theme_constant_override("icon_max_width", 22)
	enter.position = Vector2(8, 58)
	enter.size = Vector2(der.size.x - 16, 26)
	der.add_child(enter)
	code_in.text_submitted.connect(func(_t): enter.pressed.emit())
	der.add_child(_chalk_line(Vector2(14, 92), Vector2(der.size.x - 14, 91), Color(C_CHALK, 0.35), 1.0))
	var buscar := _chalk_button("Buscar", func(): open("publicas"))
	buscar.icon = _chalk_icon("sala_buscar")
	buscar.expand_icon = false
	buscar.add_theme_constant_override("icon_max_width", 22)
	buscar.tooltip_text = tr("Salas públicas abiertas ahora mismo.")
	buscar.position = Vector2(8, 98)
	buscar.size = Vector2(der.size.x - 16, 26)
	der.add_child(buscar)
	estado.position = Vector2(0, inner.size.y - 38)
	estado.size = Vector2(inner.size.x, 16)
	area.add_child(estado)
	var back := _chalk_button("‹ Volver a la pizarra", func(): open("modos"))
	back.add_theme_font_override("font", _chalk())   # igual que «Volver a la calle»
	back.custom_minimum_size = Vector2(130, 0)
	back.add_theme_font_size_override("font_size", 12)
	back.position = Vector2(-4, inner.size.y - 19)
	area.add_child(back)


## Buscador en la misma pizarra; el Timer pertenece a la página y muere al salir.
func _build_public_rooms() -> void:
	var page := _page
	var r := _board_rect()
	var inner := r.grow(-14.0)
	var area := Control.new()
	area.position = inner.position
	area.size = inner.size
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(area)
	var title := _chalk_label("Buscar salas", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, -6)
	title.size = Vector2(inner.size.x, 32)
	area.add_child(title)
	area.add_child(_chalk_line(Vector2(inner.size.x / 2 - 80, 28), Vector2(inner.size.x / 2 + 80, 27)))
	# filtros: cada uno es un icono con una palabra; tocarlo cambia lo que se ve
	var filters := {"modo": "", "meta": 0, "solo_libres": false, "estado": ""}
	var barra := HBoxContainer.new()
	barra.position = Vector2(0, 34)
	barra.size = Vector2(inner.size.x, 30)
	barra.alignment = BoxContainer.ALIGNMENT_CENTER
	barra.add_theme_constant_override("separation", 4)
	area.add_child(barra)
	var chip := func(icon: String, tip: String) -> Button:
		var b := _chalk_button("", func(): pass)
		b.icon = _chalk_icon(icon)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 26)
		b.add_theme_constant_override("h_separation", 3)
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_color_override("font_color", C_GOLD)
		b.tooltip_text = tr(tip)
		barra.add_child(b)
		return b
	var modo: Button = chip.call("sala_todos", "Qué modo de juego: todos, clásico o con aumentos.")
	var meta: Button = chip.call("sala_meta", "Meta de la partida: todas, 100 o 200 puntos.")
	var libres: Button = chip.call("sala_silla", "Ver solo salas con alguna silla libre.")
	var fase: Button = chip.call("sala_esperando", "Salas esperando gente o ya jugando.")
	var refresh: Button = chip.call("sala_actualizar", "Volver a mirar ahora (se actualiza solo cada 5 s).")
	var pinta := func():
		modo.icon = _chalk_icon("sala_todos" if filters.modo == "" else "sala_" + str(filters.modo))
		modo.text = tr("Todos") if filters.modo == "" else (tr("Clásico") if filters.modo == "clasico" else tr("Aumentos"))
		meta.text = tr("Todas") if filters.meta == 0 else str(filters.meta)
		libres.text = tr("Con sitio") if filters.solo_libres else tr("Llenas también")
		fase.icon = _chalk_icon("sala_jugando" if filters.estado == "jugando" else "sala_esperando")
		fase.text = tr("Cualquiera") if filters.estado == "" else (tr("Esperando") if filters.estado == "esperando" else tr("Jugando"))
	pinta.call()
	area.add_child(_chalk_line(Vector2(20, 68), Vector2(inner.size.x - 20, 67), Color(C_CHALK, 0.35), 1.0))
	var info := _chalk_label("", 11, C_PINK)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.position = Vector2(0, inner.size.y - 40)
	info.size = Vector2(inner.size.x, 16)
	area.add_child(info)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8, 74)
	scroll.size = Vector2(inner.size.x - 16, inner.size.y - 74 - 42)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	area.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	scroll.add_child(rows)
	var update := func(): _refresh_public_rooms(page, rows, info, filters, refresh)
	modo.pressed.connect(func():
		filters.modo = "clasico" if filters.modo == "" else ("aumentos" if filters.modo == "clasico" else "")
		pinta.call()
		update.call())
	meta.pressed.connect(func():
		filters.meta = 100 if filters.meta == 0 else (200 if filters.meta == 100 else 0)
		pinta.call()
		update.call())
	libres.pressed.connect(func():
		filters.solo_libres = not filters.solo_libres
		pinta.call()
		update.call())
	fase.pressed.connect(func():
		filters.estado = "esperando" if filters.estado == "" else ("jugando" if filters.estado == "esperando" else "")
		pinta.call()
		update.call())
	refresh.pressed.connect(update)
	var back := _chalk_button("‹ Volver a Sala con amigos", func(): open("amigos"))
	back.add_theme_font_override("font", _chalk())
	back.add_theme_font_size_override("font_size", 12)
	back.position = Vector2(-4, inner.size.y - 19)
	area.add_child(back)
	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.timeout.connect(update)
	page.add_child(timer)
	timer.start()
	update.call()


## Una sala de la lista: recuadro a tiza con el modo, quién la abrió, las cuatro
## sillas (llenas o libres), la meta, cómo va y el botón para entrar.
func _sala_tarjeta(room: Dictionary, ancho: float, page: Control, info: Label) -> Control:
	var alto := 38.0
	var card := Control.new()
	card.custom_minimum_size = Vector2(ancho, alto)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(_chalk_rect(Vector2(ancho, alto), Color(C_CHALK, 0.45)))
	var icono := func(id: String, pos: Vector2, lado: float) -> TextureRect:
		var t := TextureRect.new()
		t.texture = _chalk_icon(id)
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.position = pos
		t.size = Vector2(lado, lado)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(t)
		return t
	icono.call("sala_clasico" if room.modo == "clasico" else "sala_aumentos", Vector2(4, 3), 32.0)
	var host := _chalk_label("", 13, C_GOLD)
	host.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	host.text = str(room.anfitrion) if str(room.anfitrion) != "" else tr("Jugador")
	host.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	host.position = Vector2(40, 1)
	host.size = Vector2(ancho * 0.38 - 44, 18)
	card.add_child(host)
	# las cuatro sillas: ocupadas en tiza blanca, libres en turquesa
	var n := int(room.jugadores)
	for k in 4:
		var silla := ColorRect.new()
		silla.color = C_CHALK if k < n else Color(0.45, 0.84, 0.79, 0.35)
		silla.position = Vector2(41 + k * 10, 24)
		silla.size = Vector2(7, 7)
		silla.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(silla)
	var sitio := _chalk_label("%d/4" % n, 10, Color(C_CHALK, 0.75))
	sitio.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	sitio.position = Vector2(84, 20)
	card.add_child(sitio)
	icono.call("sala_meta", Vector2(ancho * 0.38, 9), 20.0)
	var meta_l := _chalk_label(str(int(room.meta)), 12)
	meta_l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	meta_l.position = Vector2(ancho * 0.38 + 22, 10)
	card.add_child(meta_l)
	var jugando: bool = room.estado != "esperando"
	icono.call("sala_jugando" if jugando else "sala_esperando", Vector2(ancho * 0.54, 9), 20.0)
	var est_l := _chalk_label(tr("Mano %d") % int(room.mano) if jugando else tr("Esperando"), 11)
	est_l.position = Vector2(ancho * 0.54 + 22, 11)
	card.add_child(est_l)
	var code := str(room.code)
	var enter := _chalk_button("Entrar" if room.puede_entrar else ("En curso" if room.estado == "jugando" else "Llena"), func(): _join_public_room(code, page, info))
	enter.disabled = not room.puede_entrar
	enter.set_meta("room_code", code)
	if room.puede_entrar:
		enter.icon = _chalk_icon("sala_entrar")
		enter.expand_icon = false
		enter.add_theme_constant_override("icon_max_width", 22)
	enter.add_theme_font_size_override("font_size", 13)
	enter.clip_text = true
	enter.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	enter.position = Vector2(ancho - 92, 6)
	enter.size = Vector2(88, 26)
	card.add_child(enter)
	return card


func _refresh_public_rooms(page: Control, rows: VBoxContainer, info: Label, filters: Dictionary, refresh: Button) -> void:
	if _salas_cargando or _online_ocupado or page != _page or screen != "publicas":
		return
	_salas_cargando = true
	refresh.disabled = true
	var requested := filters.duplicate()
	var result: Dictionary = await m.red.listar_salas(nombre_personaje(), requested)
	_salas_cargando = false
	if not is_instance_valid(page) or page != _page or screen != "publicas":
		return
	refresh.disabled = false
	# Si cambiaron los filtros durante el await, no pintar una respuesta antigua.
	if requested != filters:
		_refresh_public_rooms(page, rows, info, filters, refresh)
		return
	info.text = str(result.get("error", ""))
	if result.has("error"):
		return
	# Conserva controles, foco y desplazamiento si la respuesta no cambió.
	if rows.get_meta("salas", []) == result.salas and rows.get_child_count() > 0:
		return
	rows.set_meta("salas", result.salas.duplicate(true))
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var ancho: float = rows.get_parent().size.x - 4
	if result.salas.is_empty():
		# mesa vacía dibujada a tiza y un atajo para crear una
		var vacia := VBoxContainer.new()
		vacia.alignment = BoxContainer.ALIGNMENT_CENTER
		vacia.add_theme_constant_override("separation", 6)
		vacia.custom_minimum_size = Vector2(ancho, 100)
		rows.add_child(vacia)
		var dib := TextureRect.new()
		dib.texture = _chalk_icon("sala_vacia")
		dib.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		dib.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dib.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dib.custom_minimum_size = Vector2(ancho, 44)
		vacia.add_child(dib)
		var todos: bool = requested.modo == "" and requested.meta == 0 and requested.estado == "" and not requested.solo_libres
		var txt := _chalk_label("No hay salas abiertas" if todos else "Nada con estos filtros", 15, C_PINK)
		txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vacia.add_child(txt)
		var crear := _sign_button("CREAR UNA", C_GOLD, func(): open("amigos"), 12)
		crear.icon = _chalk_icon("sala_crear")
		crear.expand_icon = false
		crear.add_theme_constant_override("icon_max_width", 20)
		crear.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vacia.add_child(crear)
		return
	for room in result.salas:
		rows.add_child(_sala_tarjeta(room, ancho, page, info))


func _join_public_room(code: String, page: Control, info: Label) -> void:
	if _online_ocupado or _salas_cargando:
		return
	var nombre := nombre_personaje().substr(0, 16)
	if nombre == "":
		info.text = tr("Ponle un nombre a tu personaje en el espejo para jugar online.")
		return
	_online_ocupado = true
	info.text = tr("Llamando al colmado…")
	var err: String = await m.red.unirse(code, nombre, aspecto())
	_online_ocupado = false
	if not is_instance_valid(page) or page != _page or screen != "publicas":
		if err == "":
			m.red.salir()
		return
	if err == "":
		m.start_online()
	elif is_instance_valid(page) and page == _page:
		info.text = tr(err)


## Casilla de texto escrita a tiza (subrayada).
func _chalk_input(text: String, max_len: int) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.max_length = max_len
	e.add_theme_font_override("font", _chalk())
	e.add_theme_font_size_override("font_size", 15)
	e.add_theme_color_override("font_color", C_GOLD)
	e.add_theme_color_override("font_placeholder_color", Color(C_CHALK, 0.35))
	e.add_theme_color_override("caret_color", C_CHALK)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.04)
	sb.border_color = Color(C_CHALK, 0.6)
	sb.border_width_bottom = 2
	sb.content_margin_left = 4
	e.add_theme_stylebox_override("normal", sb)
	var sf: StyleBoxFlat = sb.duplicate()
	sf.border_color = C_GOLD
	e.add_theme_stylebox_override("focus", sf)
	return e


## La tiza dibuja el menú: título, subrayado, cada recuadro con su icono y
## textos, y por último el pie. Empieza cuando la cámara llega a la pizarra.
func _animate_board(area: Control, title: Label, rows: VBoxContainer, back: Button, wins: Label) -> void:
	var lines: Array = []
	for c in area.get_children():
		if c is Line2D:
			lines.append(c)
	# todo oculto hasta que se dibuje
	title.visible_ratio = 0.0
	for ln in lines:
		ln.visible = false
	back.modulate.a = 0.0
	wins.visible_ratio = 0.0
	var row_parts: Array = []
	for r in rows.get_children():
		var parts := {"row": r, "box": r.get_node("Box"), "icon": r.find_child("Icon", true, false),
			"title": r.find_child("Title", true, false), "sub": r.find_child("Sub", true, false),
			"action": r.find_child("Action", true, false)}
		parts.box.visible = false
		parts.icon.modulate.a = 0.0
		parts.title.visible_ratio = 0.0
		parts.sub.visible_ratio = 0.0
		parts.action.modulate.a = 0.0
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_parts.append(parts)
	# esperar a que la cámara casi llegue
	var target: Transform3D = m.view.cam_tf("pizarra")
	var waited := 0.0
	while m.view.camera.global_transform.origin.distance_to(target.origin) > 0.12 and waited < 2.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if not is_instance_valid(area):
			return
	if not is_instance_valid(area):
		return
	# solo el título se escribe a tiza; al terminar, el resto aparece de golpe
	m.sfx.play("chalk", -6.0, 0.1)
	_write_anim(title, 0.45)
	await get_tree().create_timer(0.45).timeout
	if not is_instance_valid(area):
		return
	m.sfx.play("chalk", -10.0, 0.2)
	for ln in lines:
		if is_instance_valid(ln):
			ln.visible = true
	for parts in row_parts:
		if not is_instance_valid(parts.row):
			return
		parts.box.visible = true
		parts.icon.modulate.a = 1.0 if parts.row.disabled == false else 0.4
		parts.title.visible_ratio = 1.0
		parts.sub.visible_ratio = 1.0
		parts.action.modulate.a = 1.0
		parts.row.mouse_filter = Control.MOUSE_FILTER_STOP
	back.modulate.a = 1.0
	wins.visible_ratio = 1.0
	# un saltito al aparecer, para que no sea un corte seco
	area.pivot_offset = area.size / 2
	area.scale = Vector2(0.985, 0.985)
	area.create_tween().tween_property(area, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- espejo

func _idx(arr: Array, val) -> int:
	for i in arr.size():
		if arr[i] is Color and val is Color:
			if (arr[i] as Color).is_equal_approx(val):
				return i
		elif arr[i] == val:
			return i
	return 0


func _face_value() -> String:
	if profile.get("beard", false):
		return "barba"
	if profile.get("mustache", false):
		return "bigote"
	return "nada"


func _build_mirror() -> void:
	# a la izquierda: arrastra para girar a tu personaje (detrás de los botones)
	var giro := Control.new()
	giro.position = Vector2(0, 34)
	giro.size = Vector2(366, 280)
	giro.mouse_filter = Control.MOUSE_FILTER_STOP
	giro.mouse_default_cursor_shape = Control.CURSOR_DRAG
	giro.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			m.view.probador_girar(ev.relative.x * 0.015)
		elif ev is InputEventScreenDrag:
			m.view.probador_girar(ev.relative.x * 0.015))
	_page.add_child(giro)
	var flechas := HBoxContainer.new()
	flechas.add_theme_constant_override("separation", 10)
	flechas.position = Vector2(150, 322)
	_page.add_child(flechas)
	for par in [["arrow_left", -1.0], ["arrow_right", 1.0]]:
		var gb := Button.new()
		gb.icon = m._icon(par[0])
		gb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		gb.tooltip_text = tr("Girar a tu personaje (también arrastrando)")
		var sentido: float = par[1]
		gb.pressed.connect(func(): m.view.probador_girar(sentido * PI / 4))
		flechas.add_child(gb)
	var panel := PanelContainer.new()
	panel.position = Vector2(372, 8)
	panel.custom_minimum_size = Vector2(258, 292)   # alto fijo: no crece al abrir una tira de opciones
	_page.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	var t := _label("TUS PERSONAJES", 13, C_GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	# uno por pestaña; con el que está marcado juegas (y te ven online)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	v.add_child(tabs)
	for i in profile.personajes.size():
		var tb := Button.new()
		var n: String = nombre_personaje() if i == int(profile.activo) else str(profile.personajes[i].get("nombre", ""))
		tb.text = n if n != "" else "Sin nombre"
		if n != "":
			tb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		tb.toggle_mode = true
		tb.button_pressed = i == int(profile.activo)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.clip_text = true
		tb.add_theme_font_size_override("font_size", 10)
		var idx: int = i
		tb.pressed.connect(func():
			elegir_personaje(idx)
			open("personaje"))
		tabs.add_child(tb)
	if profile.personajes.size() < MAX_PERSONAJES:
		var nb := Button.new()
		m._symbol_button(nb, "+ Nuevo")
		nb.add_theme_font_size_override("font_size", 10)
		nb.pressed.connect(func():
			nuevo_personaje()
			open("personaje"))
		tabs.add_child(nb)
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 4)
	v.add_child(nh)
	var nl := _label("Nombre", 10)
	nl.custom_minimum_size = Vector2(70, 0)
	nh.add_child(nl)
	var name_in := LineEdit.new()
	name_in.text = nombre_personaje()
	name_in.placeholder_text = "Ponle un nombre"
	name_in.max_length = 16
	name_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_in.add_theme_font_size_override("font_size", 11)
	name_in.text_changed.connect(func(tx: String): profile["nombre"] = tx.strip_edges())
	nh.add_child(name_in)
	# secciones: cuerpo, ropa y detalles (así cabe todo sin salirse)
	var secs := HBoxContainer.new()
	secs.add_theme_constant_override("separation", 3)
	v.add_child(secs)
	for pair in [["cuerpo", "Cuerpo"], ["ropa", "Ropa"], ["detalles", "Detalles"], ["arma", "Arma"]]:
		var sb := Button.new()
		sb.text = pair[1]
		sb.toggle_mode = true
		sb.button_pressed = _mirror_tab == pair[0]
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.add_theme_font_size_override("font_size", 10)
		var sid: String = pair[0]
		sb.pressed.connect(func():
			_mirror_tab = sid
			_fila_activa = ""
			open("personaje"))
		if _mirror_tab == pair[0]:
			sb.add_theme_stylebox_override("pressed", m._box_style(C_GOLD, C_INK, 2, 2))
			sb.add_theme_color_override("font_pressed_color", C_INK)
			sb.add_theme_constant_override("outline_size", 0)
		secs.add_child(sb)
	match _mirror_tab:
		"cuerpo":
			_row(v, "Cuerpo", func(): return BODY_NAMES.get(profile.get("cuerpo", "hombre"), "Hombre"), func(d): _cycle("cuerpo", BODIES, d),
				_opc_retrato("cuerpo", BODIES, BODY_NAMES, "cuerpo"))
			_row(v, "Piel", func(): return tr("Tono %d") % (_idx(SKINS, profile.skin) + 1), func(d): _cycle("skin", SKINS, d), _opc_color("skin", SKINS, []))
			_row(v, "Cabeza", func(): return HAT_NAMES[profile.hat], func(d): _cycle("hat", HATS, d), _opc_retrato("hat", HATS, HAT_NAMES, "cara"))
			_row(v, "Pelo", func(): return HAIR_NAMES[_idx(HAIRS, profile.hair)], func(d): _cycle("hair", HAIRS, d), _opc_color("hair", HAIRS, HAIR_NAMES))
			var caras := []
			for f in FACES:
				caras.append({"nombre": FACE_NAMES[f], "cambio": {"mustache": f == "bigote", "beard": f == "barba"}, "plano": "cara"})
			_row(v, "Cara", func(): return FACE_NAMES[_face_value()], func(d):
				var i: int = (FACES.find(_face_value()) + d + FACES.size()) % FACES.size()
				profile["mustache"] = FACES[i] == "bigote"
				profile["beard"] = FACES[i] == "barba"
				_changed(), caras)
		"ropa":
			_row(v, "Camisa", func(): return SHIRT_NAMES[_idx(SHIRTS, profile.shirt)], func(d): _cycle("shirt", SHIRTS, d), _opc_color("shirt", SHIRTS, SHIRT_NAMES))
			_row(v, "Estampado", func(): return PATTERN_NAMES[profile.pattern], func(d): _cycle("pattern", PATTERNS, d), _opc_retrato("pattern", PATTERNS, PATTERN_NAMES, "torso"))
		"arma":
			var ids: Array = m.arma.ARMAS.keys()
			_row(v, "Arma", func(): return tr(m.arma.ARMAS[m.arma.arma_id()].nombre), func(d):
				profile["arma"] = ids[(ids.find(m.arma.arma_id()) + d + ids.size()) % ids.size()]
				m.sfx.play("clack", -8.0))
			var bh := HBoxContainer.new()
			bh.add_theme_constant_override("separation", 4)
			v.add_child(bh)
			var bl := _label("", 10)
			bl.custom_minimum_size = Vector2(70, 0)
			bh.add_child(bl)
			var comprar := Button.new()
			comprar.add_theme_font_size_override("font_size", 10)
			comprar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bh.add_child(comprar)
			var pintar := func():
				bl.text = tr("Balas: %d") % int(profile.get("balas", 0))
				comprar.text = tr("+1 bala · %d pesos (tienes %d)") % [m.arma.PRECIO_BALA, int(profile.get("pesos", 0))]
				comprar.disabled = int(profile.get("pesos", 0)) < m.arma.PRECIO_BALA or int(profile.get("balas", 0)) >= m.arma.MAX_BALAS
			pintar.call()
			comprar.pressed.connect(func():
				profile["pesos"] = int(profile.get("pesos", 0)) - m.arma.PRECIO_BALA
				profile["balas"] = int(profile.get("balas", 0)) + 1
				save()
				m.sfx.play("coin", -6.0, 0.0)
				pintar.call())
			v.add_child(_label("Las armas vienen sin balas. Solo en salas privadas «con armas»", 8, Color(C_CREAM, 0.7)))
		"detalles":
			for pair in [["Gafas", "glasses"], ["Aretes", "earrings"], ["Cadena", "chain"], ["Labios", "lips"]]:
				var key: String = pair[1]
				var names: Dictionary = OPT_KEYS[key]
				_row(v, pair[0], func(): return tr(names.get(str(profile.get(key, "")), names[""])), func(d): _cycle(key, names.keys(), d),
				_opc_retrato(key, names.keys(), names, "torso" if key == "chain" else "cara"))
	var hueco := Control.new()   # empuja Al azar / Guardar al fondo del panel (alto fijo)
	hueco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(hueco)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	v.add_child(h)
	var rnd := Button.new()
	rnd.text = "Al azar"
	rnd.pressed.connect(_randomize)
	h.add_child(rnd)
	if profile.personajes.size() > 1:
		var del := Button.new()
		del.text = "Borrar"
		del.pressed.connect(func():
			borrar_personaje()
			open("personaje"))
		h.add_child(del)
	var ok: Button = m._yellow(Button.new())
	ok.text = "GUARDAR"
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func():
		if nombre_personaje() == "":
			name_in.placeholder_text = "¡Falta el nombre!"
			name_in.grab_focus()
			m.sfx.play("knock", -8.0)
			return
		guardar_personaje()
		m.view.set_avatar_cfg(profile)
		m.sfx.play("coin", -6.0, 0.0)
		_back())
	h.add_child(ok)
	# gestos para probar
	var g := HBoxContainer.new()
	g.position = Vector2(80, 8)
	g.add_theme_constant_override("separation", 4)
	_page.add_child(g)
	for pair in [["Guiñar", "wink"], ["Hablar", "talk"], ["Beber", "drink"], ["Reír", "laugh"], ["¡Capicúa!", "standup"]]:
		var b := Button.new()
		b.text = pair[0]
		var kind: String = pair[1]
		b.pressed.connect(func(): m.view.mirror_react(kind))
		g.add_child(b)


## Una fila del probador: nombre, ◀ valor ▶ y, si es la fila activa, una tira con
## todas las opciones (muestras de color o retratos de tu personaje con cada una).
## opciones: [{nombre, cambio: {clave: valor}, color?, plano?}]
func _row(parent: Control, title: String, value_fn: Callable, change_fn: Callable, opciones: Array = []) -> void:
	if _fila_activa == "" and not opciones.is_empty():
		_fila_activa = title
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	parent.add_child(h)
	var l := Button.new()
	l.text = title
	l.flat = true
	l.alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.custom_minimum_size = Vector2(80, 0)
	l.clip_text = true
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", C_GOLD if _fila_activa == title else C_CREAM)
	l.tooltip_text = tr("Ver todas las opciones")
	h.add_child(l)
	var prev := Button.new()
	prev.icon = m._icon("arrow_left")
	prev.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(prev)
	var val := _label(value_fn.call(), 10, C_GOLD)
	val.custom_minimum_size = Vector2(96, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(val)
	var nxt := Button.new()
	nxt.icon = m._icon("arrow_right")
	nxt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	nxt.set_meta("option_next", true)
	h.add_child(nxt)
	var tira := HFlowContainer.new()
	tira.add_theme_constant_override("h_separation", 2)
	tira.add_theme_constant_override("v_separation", 2)
	var marcar := func():
		for ob in tira.get_children():
			ob.button_pressed = _opcion_puesta(ob.get_meta("cambio"))
	var cambiar := func(d: int):
		change_fn.call(d)
		val.text = value_fn.call()
		marcar.call()
		_enfocar_fila(title)
	prev.pressed.connect(cambiar.bind(-1))
	nxt.pressed.connect(cambiar.bind(1))
	l.pressed.connect(func():
		_fila_activa = title
		open("personaje")
		_enfocar_fila(title))
	if opciones.is_empty() or _fila_activa != title:
		return
	parent.add_child(tira)
	for o in opciones:
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(28, 28)
		b.tooltip_text = tr(str(o.nombre))
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.set_meta("cambio", o.cambio)
		b.add_theme_stylebox_override("pressed", m._box_style(C_GOLD, C_INK, 2, 2))
		if o.has("color"):
			var sw := ColorRect.new()
			sw.color = o.color
			sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			sw.offset_left = 5
			sw.offset_top = 5
			sw.offset_right = -5
			sw.offset_bottom = -5
			b.add_child(sw)
		else:
			var foto := TextureRect.new()
			foto.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
			foto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			foto.offset_left = 2
			foto.offset_top = 2
			foto.offset_right = -2
			foto.offset_bottom = -2
			b.add_child(foto)
			_miniatura(o.cambio, str(o.get("plano", "cara")), foto)
		var cambio: Dictionary = o.cambio
		b.pressed.connect(func():
			profile.merge(cambio, true)
			_changed()
			val.text = value_fn.call()
			marcar.call()
			_enfocar_fila(title))
		tira.add_child(b)
	marcar.call()


var _fila_activa := ""   # la fila del probador que enseña todas sus opciones


func _opcion_puesta(cambio: Dictionary) -> bool:
	for k in cambio:
		var a = profile.get(k)
		var b = cambio[k]
		if a is Color and b is Color:
			if not a.is_equal_approx(b):
				return false
		elif str(a if a != null else "") != str(b):
			return false
	return true


func _opc_color(key: String, colores: Array, nombres: Array) -> Array:
	var r := []
	for c in colores:
		var i := r.size()
		r.append({"nombre": nombres[i] if i < nombres.size() else tr("Tono %d") % (i + 1), "cambio": {key: c}, "color": c})
	return r


func _opc_retrato(key: String, valores: Array, nombres, plano: String) -> Array:
	var r := []
	for i in valores.size():
		var nom = nombres.get(valores[i], "") if nombres is Dictionary else nombres[i]
		r.append({"nombre": str(nom), "cambio": {key: valores[i]}, "plano": plano})
	return r


# ---- miniaturas: tu personaje con cada opción, pintado una vez y guardado

const Personaje := preload("res://scripts/character.gd")
const MINI_PLANOS := {"cara": [0.42, 0.62], "torso": [0.12, 0.95], "cuerpo": [0.15, 1.1]}   # altura a la que mira, distancia
var _minis := {}          # clave → textura
var _mini_cola: Array = []
var _mini_ocupado := false
var _mini_sv: SubViewport
var _mini_cam: Camera3D


func _miniatura(cambio: Dictionary, plano: String, destino: TextureRect) -> void:
	var cfg: Dictionary = profile.duplicate()
	for k in ["personajes", "activo", "pesos", "balas", "nombre", "arma"]:
		cfg.erase(k)
	cfg.merge(cambio, true)
	var clave := var_to_str(cfg) + plano
	if _minis.has(clave):
		destino.texture = _minis[clave]
		return
	_mini_cola.append([clave, cfg, plano, destino])
	if not _mini_ocupado:
		_mini_trabajar()


func _mini_preparar() -> void:
	_mini_sv = SubViewport.new()
	_mini_sv.own_world_3d = true
	_mini_sv.size = Vector2i(64, 64)
	_mini_sv.transparent_bg = true
	_mini_sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_mini_sv)
	_mini_cam = Camera3D.new()
	_mini_cam.fov = 40
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.66, 0.6)
	_mini_cam.environment = env
	_mini_sv.add_child(_mini_cam)
	var luz := DirectionalLight3D.new()
	luz.rotation = Vector3(-0.6, PI + 0.4, 0)
	_mini_sv.add_child(luz)


func _mini_trabajar() -> void:
	_mini_ocupado = true
	if _mini_sv == null:
		_mini_preparar()
	while not _mini_cola.is_empty():
		var it: Array = _mini_cola.pop_front()
		var destino: TextureRect = it[3]
		if not is_instance_valid(destino):
			continue
		if _minis.has(it[0]):
			destino.texture = _minis[it[0]]
			continue
		var ch = Personaje.new()
		ch.own_chair = false
		_mini_sv.add_child(ch)
		ch.setup_cfg(it[1])
		var pl: Array = MINI_PLANOS.get(it[2], MINI_PLANOS.cara)
		_mini_cam.transform = Transform3D(Basis(), Vector3(0, pl[0] + 0.08, -pl[1])).looking_at(Vector3(0, pl[0], 0))
		_mini_sv.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var tex := ImageTexture.create_from_image(_mini_sv.get_texture().get_image())
		_minis[it[0]] = tex
		ch.free()
		if is_instance_valid(destino):
			destino.texture = tex
	_mini_ocupado = false


func _cycle(key: String, arr: Array, d: int) -> void:
	var i := (_idx(arr, profile.get(key, arr[0])) + d + arr.size()) % arr.size()
	profile[key] = arr[i]
	_changed()


func _changed() -> void:
	m.sfx.play("hover", -10.0, 0.2)
	m.view.set_mirror_cfg(profile)
	_probador_arma()


## Qué enseña la cámara del probador al cambiar cada cosa (y al abrir cada pestaña).
const ENFOQUE_FILA := {"Cuerpo": "cuerpo", "Piel": "cara", "Cabeza": "cara", "Pelo": "cara", "Cara": "cara",
	"Camisa": "torso", "Estampado": "torso", "Gafas": "cara", "Aretes": "cara", "Cadena": "torso", "Labios": "cara", "Arma": "torso"}
const ENFOQUE_PESTANA := {"cuerpo": "cuerpo", "ropa": "torso", "detalles": "cara", "arma": "cuerpo"}
var _enfoque := "cuerpo"


func _enfocar_fila(fila: String) -> void:
	if screen != "personaje":
		return
	var e: String = ENFOQUE_FILA.get(fila, _enfoque)
	if e != _enfoque:
		_enfoque = e
		m.view.cam_to("probador_" + e, 0.5)


## En la pestaña Arma tu personaje la lleva en la mano (la que tienes elegida).
func _probador_arma() -> void:
	var ch = m.view.mirror_char
	if is_instance_valid(ch):
		ch.arma_tipo = m.arma.arma_id()
		ch.armado = _mirror_tab == "arma"


func _randomize() -> void:
	profile.skin = SKINS.pick_random()
	profile.hat = HATS.pick_random()
	profile.hair = HAIRS.pick_random()
	profile.shirt = SHIRTS.pick_random()
	profile.pattern = PATTERNS.pick_random()
	var f: String = FACES.pick_random()
	profile.mustache = f == "bigote"
	profile.beard = f == "barba"
	profile.cuerpo = BODIES.pick_random()
	for k in OPT_KEYS:
		var types: Array = OPT_KEYS[k].keys()
		profile[k] = types.slice(1).pick_random() if randf() < 0.35 else ""
	open("personaje")


# ---------------------------------------------------------------- armario

## Aplica a la mesa lo que tienes equipado.
func apply_equip() -> void:
	var e: Dictionary = profile.equip
	m.view.set_tile_style(e.fichas)
	m.view.set_table_style(e.mesa)
	m.view.set_glass_style(e.vaso)
	# en el armario, la muestra vuelve a lo que tienes puesto (fichas y vasos)
	if screen == "armario" and m.view.preview_on:
		m.view.show_preview(true)


func add_pesos(n: int) -> void:
	profile.pesos = int(profile.get("pesos", 0)) + n
	save()


func _build_wardrobe() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(392, 26)
	panel.custom_minimum_size = Vector2(238, 0)
	_page.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	var t := _label("EL ARMARIO", 14, C_GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var wallet := HBoxContainer.new()
	wallet.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(wallet)
	wallet.add_child(m._icon_rect(m._icon("coin"), 14))
	var pesos_l := _label(tr("%d pesos") % int(profile.pesos), 12, C_GOLD)
	wallet.add_child(pesos_l)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	v.add_child(tabs)
	for cat in CATALOG:
		var tb := Button.new()
		tb.text = CAT_NAMES[cat]
		tb.toggle_mode = true
		tb.button_pressed = cat == _tab
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var c: String = cat
		tb.pressed.connect(func():
			_tab = c
			open("armario"))
		tabs.add_child(tb)
	for item in CATALOG[_tab]:
		var id: String = item[0]
		var price: int = item[2]
		var key := "%s:%s" % [_tab, id]
		var owned: bool = profile.owned.has(key)
		var equipped: bool = profile.equip[_tab] == id
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var state: String = tr("✓ Puesto") if equipped else (tr("Tuyo") if owned else tr("%d pesos") % price)
		b.text = "%s   ·   %s" % [tr(item[1]), state]
		if equipped:
			b.add_theme_stylebox_override("normal", m._box_style(C_GOLD, C_INK, 2, 4))
			b.add_theme_color_override("font_color", C_INK)
			b.add_theme_constant_override("outline_size", 0)
		elif not owned and int(profile.pesos) < price:
			b.add_theme_color_override("font_color", Color(C_CREAM, 0.55))
		b.pressed.connect(func(): _wardrobe_pick(id, price))
		b.mouse_entered.connect(func(): _try_on(id))
		b.mouse_exited.connect(func(): apply_equip())
		v.add_child(b)
	var note := _label("Los pesos se ganan jugando: más si ganas, haces capicúa o cantas chivo.", 9, Color(C_CREAM, 0.75))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(220, 0)
	v.add_child(note)


## Al pasar el ratón: probarlo en la mesa sin comprar.
func _try_on(id: String) -> void:
	match _tab:
		"fichas":
			m.view.set_tile_style(id)
			m.view.show_preview(true)
		"mesa":
			m.view.set_table_style(id)
		"vaso":
			m.view.set_glass_style(id)
			m.view.show_preview(true)


func _wardrobe_pick(id: String, price: int) -> void:
	var key := "%s:%s" % [_tab, id]
	if not profile.owned.has(key):
		if int(profile.pesos) < price:
			m.sfx.play("knock", -6.0)
			m._float(tr("Te faltan %d pesos") % (price - int(profile.pesos)), Vector2(200, 160), C_RED.lightened(0.3))
			return
		profile.pesos = int(profile.pesos) - price
		profile.owned.append(key)
		m.sfx.play("coin", -4.0, 0.0)
		m._float("¡Comprado!", Vector2(200, 160), C_GOLD)
	else:
		m.sfx.play("clink", -8.0)
	profile.equip[_tab] = id
	save()
	apply_equip()
	m.view.show_preview(true)
	open("armario")


# ---------------------------------------------------------------- radio de ajustes

func _build_settings() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(268, 8)
	panel.custom_minimum_size = Vector2(364, 318)   # alto fijo: no crece al cambiar opciones
	_page.add_child(panel)
	var contenedor: Control = panel
	var columna: VBoxContainer
	if settings.texto > 0:
		panel.size = Vector2(364, 344)
		columna = VBoxContainer.new()
		panel.add_child(columna)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		columna.add_child(scroll)
		contenedor = scroll
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	contenedor.add_child(v)
	var th := HBoxContainer.new()
	th.alignment = BoxContainer.ALIGNMENT_CENTER
	th.add_theme_constant_override("separation", 6)
	v.add_child(th)
	th.add_child(m._icon_rect(m._icon("gear", C_GOLD), 16))
	th.add_child(_label("AJUSTES", 15, C_GOLD))
	var acceso := Button.new()
	acceso.text = "Accesibilidad"
	acceso.add_theme_font_size_override("font_size", 10)
	acceso.pressed.connect(func(): open("accesibilidad", _from_game))
	th.add_child(acceso)
	_slider(v, "Volumen", "vol")
	_slider(v, "Efectos", "fx")
	_slider(v, "Música", "mus")
	_radio_rows(v)
	_choice(v, "Sacudida de cámara", "shake", [1.0, 0.5, 0.0], ["Normal", "Suave", "Apagada"])
	_choice(v, "Pantalla completa", "fullscreen", [false, true], ["No", "Sí"])
	# cada idioma con su propio nombre («Español» y «English» no se traducen)
	_choice(v, "Idioma", "idioma", ["", "es", "en"], ["Automático", "Español", "English"])
	_delete_account_row(v)
	_registro_row(v)
	var back: Button = m._yellow(Button.new())
	back.text = "LISTO"
	back.pressed.connect(_back)
	(columna if columna != null else v).add_child(back)


func _build_accessibility() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(268, 8)
	panel.size = Vector2(364, 344)
	_page.add_child(panel)
	var columna := VBoxContainer.new()
	panel.add_child(columna)
	columna.add_child(_label("ACCESIBILIDAD", 15, C_GOLD))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 5)
	scroll.add_child(v)
	for fila in [["Tamaño del texto", "texto", [0, 1, 2], ["Normal", "Grande", "Muy grande"]],
		["Modo daltónico", "daltonico", [false, true], ["No", "Sí"]],
		["Menos movimiento", "menos_movimiento", [false, true], ["No", "Sí"]],
		["Modo cámara (mirar con el ratón)", "camara", [true, false], ["Sí", "No"]]]:
		v.add_child(_label(fila[0], 11))
		var h := HBoxContainer.new()
		v.add_child(h)
		for i in fila[2].size():
			var b := Button.new()
			b.text = fila[3][i]
			b.add_theme_font_size_override("font_size", 11)
			b.toggle_mode = true
			b.button_pressed = settings[fila[1]] == fila[2][i]
			var clave: String = fila[1]
			var valor = fila[2][i]
			b.pressed.connect(func():
				settings[clave] = valor
				m.apply_settings()
				save()
				open.call_deferred("accesibilidad", _from_game))
			h.add_child(b)
	if not OS.has_feature("mobile"):
		v.add_child(_label("Controles de PC", 12, C_GOLD))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(grid)
		var nombres := {"usar": "Usar / jugar ficha", "paso": "Paso", "cantar": "¡Chivo! / ¡Ute va!", "recoger": "Recoger mis fichas", "pararse": "Pararse / sentarse", "mirar": "Mirar la mesa", "chat": "Chat"}
		for accion in m.accesibilidad.TECLAS:
			var nombre: String = tr(nombres[accion]) if nombres.has(accion) else tr("Gesto %d") % int(accion.trim_prefix("gesto"))
			grid.add_child(_label(nombre, 11))
			var b := Button.new()
			b.text = OS.get_keycode_string(settings.teclas[accion])
			b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			b.add_theme_font_size_override("font_size", 11)
			var seleccion: String = accion
			b.pressed.connect(func():
				m.accesibilidad.pendiente = seleccion
				m.accesibilidad.aviso.text = tr("Pulsa una tecla · Esc cancela"))
			grid.add_child(b)
		m.accesibilidad.aviso = _label("Pulsa una tecla para cambiarla", 10, C_GOLD)
		v.add_child(m.accesibilidad.aviso)
		var reset := Button.new()
		reset.text = "Restablecer controles"
		reset.pressed.connect(func():
			settings.teclas = m.accesibilidad.TECLAS.duplicate()
			save()
			open.call_deferred("accesibilidad", _from_game))
		v.add_child(reset)
	var back := Button.new()
	back.text = "Volver a Ajustes"
	back.pressed.connect(func():
		m.accesibilidad.pendiente = ""
		open("ajustes", _from_game))
	columna.add_child(back)


func _registro_row(parent: Control) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	parent.add_child(fila)
	var b := Button.new()
	b.text = "Copiar registro de fallos"
	b.add_theme_font_size_override("font_size", 10)
	b.tooltip_text = "Copia información técnica; no se envía automáticamente"
	fila.add_child(b)
	var aviso := _label("", 9, C_GOLD)
	aviso.visible = false
	fila.add_child(aviso)
	b.pressed.connect(func():
		aviso.text = "Copiado" if RegistroFallos.copiar() else "No se pudo copiar el registro"
		aviso.visible = true)


## La radio del mostrador: emisora del juego o tu propia música, con sus botones.
func _radio_rows(parent: Control) -> void:
	var r = m.radio
	_choice(parent, "Radio", "emisora", ["fm", "mia", "off"], ["Colmadón FM", "Tu música", "Apagada"])
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	parent.add_child(h)
	h.add_child(m._icon_rect(m._icon("music", C_GOLD), 14))
	var song := _label("", 10, C_GOLD)
	song.custom_minimum_size = Vector2(164, 0)
	song.clip_text = true
	song.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	song.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # los nombres de canciones no se traducen
	h.add_child(song)
	var mini := func(txt: String, tip: String, cb: Callable) -> Button:
		var b := Button.new()
		b.icon = m._icon(txt)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.tooltip_text = tip
		b.add_theme_font_size_override("font_size", 10)
		b.custom_minimum_size = Vector2(26, 0)
		b.pressed.connect(cb)
		h.add_child(b)
		return b
	var prev: Button = mini.call("previous", "Anterior", func(): r.siguiente(-1))
	var play: Button = mini.call("play_pause", "Pausa / seguir", func(): r.pausa())
	var nxt: Button = mini.call("next", "Siguiente", func(): r.siguiente(1))
	# tu música: añadir canciones (selector del sistema) o abrir la carpeta (PC)
	var h2 := HBoxContainer.new()
	h2.add_theme_constant_override("separation", 4)
	parent.add_child(h2)
	var add := Button.new()
	m._symbol_button(add, "+ Añadir canciones")
	add.add_theme_font_size_override("font_size", 10)
	h2.add_child(add)
	var folder := Button.new()
	folder.text = "Abrir carpeta"
	folder.add_theme_font_size_override("font_size", 10)
	folder.visible = not OS.has_feature("mobile")
	h2.add_child(folder)
	var note := _label("Solo la oyes tú: tu música no se envía a nadie", 9, Color(C_CREAM, 0.65))
	parent.add_child(note)
	var refresh := func():
		if not is_instance_valid(song):
			return
		song.text = r.titulo()
		var mia: bool = r.emisora == "mia"
		prev.visible = mia
		nxt.visible = mia
		play.disabled = r.emisora == "off"
		h2.visible = mia
		note.visible = mia
	r.cambio.connect(refresh)
	song.tree_exiting.connect(func(): r.cambio.disconnect(refresh))
	refresh.call()
	m._live_text(song, func(): return r.titulo())
	folder.pressed.connect(func(): OS.shell_open(r.ruta_carpeta()))
	add.pressed.connect(func():
		if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
			OS.shell_open(r.ruta_carpeta())
			return
		DisplayServer.file_dialog_show(tr("Elige tus canciones"), "", "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILES,
			PackedStringArray([tr("*.mp3, *.ogg, *.wav ; Música")]), func(ok: bool, paths: PackedStringArray, _f: int):
				if not ok or paths.is_empty():
					return
				var n: int = r.importar(paths)
				m._float(_import_notice(n), Vector2(460, 200), C_GOLD)
				# El selector nativo puede seguir abierto al cambiar de emisora.
				if r.emisora == "mia":
					r.poner("mia")))


## «Borrar mis datos online» con confirmación (lo pide la política de
## privacidad). Solo borra la cuenta del servidor; el perfil del dispositivo
## (personajes, pesos, armario) se queda.
var _delete_ask: Button  # para la prueba de menús


func _import_notice(n: int) -> String:
	return tr("%d canción añadida" if n == 1 else "%d canciones añadidas") % n


func _delete_account_row(parent: Control) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	var ask := Button.new()
	ask.text = "Borrar mis datos online"
	ask.flat = true
	ask.add_theme_font_size_override("font_size", 10)
	for st in ["font_color", "font_hover_color", "font_pressed_color"]:
		ask.add_theme_color_override(st, C_RED.lightened(0.5))
	box.add_child(ask)
	_delete_ask = ask
	var info := _label("", 10, Color(C_CREAM, 0.85))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(m.CX, 0)
	info.visible = false
	box.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.visible = false
	box.add_child(row)
	var yes := Button.new()
	yes.text = "Sí, borrar"
	yes.add_theme_stylebox_override("normal", m._box_style(C_RED, C_RED.darkened(0.4), 2, 2, 4))
	yes.add_theme_stylebox_override("hover", m._box_style(C_RED.lightened(0.15), C_RED.darkened(0.4), 2, 2, 4))
	yes.add_theme_color_override("font_color", C_CREAM)
	yes.add_theme_color_override("font_hover_color", C_CREAM)
	row.add_child(yes)
	var no := Button.new()
	no.text = "Cancelar"
	row.add_child(no)
	ask.pressed.connect(func():
		ask.visible = false
		info.text = "¿Seguro? Se borra tu cuenta online; tus personajes y pesos de este dispositivo se quedan"
		info.visible = true
		row.visible = true)
	no.pressed.connect(func():
		ask.visible = true
		info.visible = false
		row.visible = false)
	yes.pressed.connect(func():
		row.visible = false
		info.text = "Borrando…"
		var err: String = await m.red.borrar_cuenta()
		if not is_instance_valid(info) or not is_instance_valid(ask):
			return
		info.text = err if err != "" else "Listo: tu cuenta online se borró"
		ask.visible = err != "")


func _slider(parent: Control, title: String, key: String) -> void:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := _label(title, 10)
	l.custom_minimum_size = Vector2(118, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = settings[key]
	s.custom_minimum_size = Vector2(200, 16)
	s.value_changed.connect(func(v: float):
		settings[key] = v
		m.apply_settings()
		if key == "fx":
			m.sfx.play("clack", -4.0))
	h.add_child(s)


func _choice(parent: Control, title: String, key: String, values: Array, names: Array) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	parent.add_child(h)
	var l := _label(title, 10)
	l.custom_minimum_size = Vector2(118, 0)
	if settings.texto > 0:
		parent.add_child(l)
		parent.move_child(l, h.get_index())
	else:
		h.add_child(l)
	for i in values.size():
		var b := Button.new()
		b.text = names[i]
		b.add_theme_font_size_override("font_size", 10)
		if names[i] in ["Español", "English", "Colmadón FM"]:
			b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.toggle_mode = true
		b.button_pressed = settings[key] == values[i]
		var val = values[i]
		b.pressed.connect(func():
			settings[key] = val
			m.apply_settings()
			for c in h.get_children():
				if c is Button:
					c.button_pressed = c == b)
		if key == "idioma":
			b.pressed.connect(func(): open.call_deferred(screen, _from_game))
		h.add_child(b)
