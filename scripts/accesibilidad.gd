extends Node
## Opciones locales de interfaz. No modifica la escala ni las reglas de la mesa.
const ESCALAS := [1.0, 1.15, 1.3]
const AZUL := Color("56b4e9")
const NARANJA := Color("e69f00")
const TECLAS := {"gesto1": KEY_1, "gesto2": KEY_2, "gesto3": KEY_3, "gesto4": KEY_4,
	"gesto5": KEY_5, "gesto6": KEY_6, "gesto7": KEY_7, "usar": KEY_E, "paso": KEY_Q, "cantar": KEY_F, "recoger": KEY_R,
	"pararse": KEY_SPACE, "mirar": KEY_TAB, "chat": KEY_T}
# Alt queda libre: mantenerla suelta el ratón en el modo cámara
const RESERVADAS := [KEY_ESCAPE, KEY_W, KEY_A, KEY_S, KEY_D, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META,
	KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER]
var m
var escala := 1.0
var daltonico := false
var pendiente := ""
var aviso: Label
var _controles: Array[WeakRef] = []

static func normalizar(st: Dictionary) -> void:
	st.texto = clampi(int(st.get("texto", 0)), 0, 2)
	st.daltonico = st.get("daltonico", false) == true
	st.menos_movimiento = st.get("menos_movimiento", false) == true
	st.camara = st.get("camara", true) != false
	var mapa: Dictionary = TECLAS.duplicate()
	var entrada = st.get("teclas", {})
	if entrada is Dictionary:
		var usados := []
		var valido := true
		for accion in TECLAS:
			var key = entrada.get(accion, TECLAS[accion])
			if not key is int or key <= 0 or key >= KEY_UNKNOWN or key in RESERVADAS or key in usados:
				valido = false
				break
			mapa[accion] = key
			usados.append(key)
		if not valido:
			mapa = TECLAS.duplicate()
	st.teclas = mapa

func _init(main_node) -> void:
	m = main_node

func _ready() -> void:
	get_tree().node_added.connect(_nuevo)
	_recorrer(m.ui)

func _nuevo(n: Node) -> void:
	if n is Label or n is Button or n is LineEdit or n is RichTextLabel:
		_registrar.call_deferred(n)

func _recorrer(n: Node) -> void:
	_registrar(n)
	for c in n.get_children():
		_recorrer(c)

func _registrar(n) -> void:
	if not is_instance_valid(n) or n.is_queued_for_deletion():
		return
	if not (n is Label or n is Button or n is LineEdit or n is RichTextLabel) or not m.ui.is_ancestor_of(n):
		return
	if n.has_meta("a11y_registrado"):
		return
	var nombre := "normal_font_size" if n is RichTextLabel else "font_size"
	if not n.has_meta("a11y_base"):
		n.set_meta("a11y_base", n.get_theme_font_size(nombre))
	n.set_meta("a11y_registrado", true)
	if _controles.size() > 512:
		_controles = _controles.filter(func(ref): return is_instance_valid(ref.get_ref()))
	_controles.append(weakref(n))
	_fuente(n)

func _fuente(n: Control) -> void:
	var nombre := "normal_font_size" if n is RichTextLabel else "font_size"
	n.add_theme_font_size_override(nombre, roundi(int(n.get_meta("a11y_base")) * escala))

func aplicar() -> void:
	normalizar(m.menus.settings)
	escala = ESCALAS[m.menus.settings.texto]
	daltonico = m.menus.settings.daltonico
	pendiente = ""
	var vivos: Array[WeakRef] = []
	for ref in _controles:
		var n = ref.get_ref()
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			_fuente(n)
			vivos.append(ref)
	_controles = vivos

func coincide(ev: InputEventKey, accion: String) -> bool:
	return ev.pressed and not ev.echo and not ev.ctrl_pressed and not ev.alt_pressed and not ev.meta_pressed and ev.keycode == m.menus.settings.teclas[accion]

func asignar(accion: String, key: int) -> bool:
	if not TECLAS.has(accion) or key <= 0 or key >= KEY_UNKNOWN or key in RESERVADAS:
		return false
	for otra in TECLAS:
		if otra != accion and m.menus.settings.teclas[otra] == key:
			return false
	m.menus.settings.teclas[accion] = key
	return true

func capturar(ev: InputEvent) -> bool:
	if not m.menus.visible or m.menus.screen != "accesibilidad":
		pendiente = ""
		return false
	if pendiente == "" or not ev is InputEventKey or not ev.pressed:
		return false
	if ev.keycode == KEY_ESCAPE:
		pendiente = ""
		m.menus.open.call_deferred("accesibilidad", m.menus._from_game)
	elif not ev.echo:
		if not ev.ctrl_pressed and not ev.alt_pressed and not ev.meta_pressed and asignar(pendiente, ev.keycode):
			pendiente = ""
			m.menus.save()
			m.menus.open.call_deferred("accesibilidad", m.menus._from_game)
		elif is_instance_valid(aviso):
			aviso.text = tr("Tecla reservada o ya asignada · prueba otra")
	get_viewport().set_input_as_handled()
	return true
