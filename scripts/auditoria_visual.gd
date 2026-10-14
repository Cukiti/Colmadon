extends RefCounted
## Candidatos medibles; legibilidad y composición requieren revisión humana.
var muestras := 0
var controles := 0
var persistencia := {}
var vistos := {}

func recoger(n: Node, out: Array) -> void:
	if n is CanvasItem and not n.is_visible_in_tree():
		return
	if n is Control and (n is Label or n is Button) and n.get_global_rect().has_area() and n.modulate.a >= 0.5 and n.get_global_transform().x.length() >= 0.05:
		out.append(n)
	for c in n.get_children():
		recoger(c, out)

static func tinta(n: Control) -> Rect2:
	var r := n.get_global_rect()
	if not n is Label:
		return r
	var font: Font = n.get_theme_font("font")
	var texto: String = n.text if n.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED else n.tr(n.text)
	var ancho := 0.0
	for linea in texto.split("\n"):
		ancho = maxf(ancho, font.get_string_size(linea, HORIZONTAL_ALIGNMENT_LEFT, -1, n.get_theme_font_size("font_size")).x)
	ancho *= n.get_global_transform().x.length()
	var alto: float = font.get_height(n.get_theme_font_size("font_size")) * n.get_line_count() * n.get_global_transform().y.length()
	var tam := Vector2(minf(ancho, r.size.x), minf(alto, r.size.y))
	var pos := r.position
	if n.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		pos.x += (r.size.x - tam.x) / 2
	elif n.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		pos.x += r.size.x - tam.x
	if n.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		pos.y += (r.size.y - tam.y) / 2
	elif n.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
		pos.y += r.size.y - tam.y
	return Rect2(pos, tam)

func inspeccionar(raiz: Node, pantalla: Rect2) -> Array:
	var items: Array = []
	recoger(raiz, items)
	controles = items.size()
	muestras += 1
	var alertas: Array = []
	for n in items:
		var r: Rect2 = n.get_global_rect()
		var texto: String = n.text
		if texto.is_empty() or (n is Label and n.visible_ratio < 1.0):
			continue
		var base := {"clave": str(n.get_path()), "texto": texto, "rect": [r.position.x, r.position.y, r.size.x, r.size.y]}
		if not pantalla.grow(2).encloses(tinta(n)):
			var a := base.duplicate()
			a.merge({"tipo":"texto_fuera_pantalla", "detalle":"Texto fuera del área visible", "recomendacion":"Reubicar dentro del margen seguro y probar ambas resoluciones."})
			alertas.append(a)
		var font: Font = n.get_theme_font("font")
		var tam: int = n.get_theme_font_size("font_size")
		var traducido: String = texto if n.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED else n.tr(texto)
		var ancho := 0.0
		for linea in traducido.split("\n"):
			ancho = maxf(ancho, font.get_string_size(linea, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x)
		ancho *= n.get_global_transform().x.length()
		var envuelve: bool = n is Label and n.autowrap_mode != TextServer.AUTOWRAP_OFF
		if not envuelve and ancho > r.size.x + 2:
			var a := base.duplicate()
			a.merge({"tipo":"texto_sin_espacio", "detalle":"Texto excede el ancho disponible (incluye texto recortado)", "recomendacion":"Ampliar el control, permitir varias líneas o acortar el texto sin perder el significado."})
			alertas.append(a)
	for i in items.size():
		var a: Control = items[i]
		for j in range(i + 1, items.size()):
			var b: Control = items[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a) or (a is Button and b is Button):
				continue
			if str(a.text).strip_edges() == "" or str(b.text).strip_edges() == "":
				continue   # botones de solo icono (cartas, monedero): su dibujo va dentro a propósito
			var inter := tinta(a).intersection(tinta(b))
			if inter.get_area() > 24 and inter.size.y > 3:
				alertas.append({"tipo":"texto_solapado_candidato", "clave": str(a.get_path(), "|", b.get_path()), "texto": _txt(a) + " ⟷ " + _txt(b), "detalle":"Texto/control se superponen; comprobar capas y paneles intencionales", "recomendacion":"Separar avisos de turno, marcador y acciones; alinear con márgenes consistentes.", "a":str(a.get_path()), "b":str(b.get_path())})
	return alertas

static func _txt(n: Control) -> String:
	if "text" in n and str(n.text) != "":
		return str(n.text).left(40)
	for c in n.get_children():
		if c is Control:
			var t := _txt(c)
			if t != "":
				return t
	return n.get_class()


## I9: textos de la interfaz encima de la cara de alguien sentado a la mesa
## (las placas de nombre van encima de la cabeza a propósito: no cuentan).
func caras(bot, items: Array) -> Array:
	var out: Array = []
	var v = bot.m.view
	if v == null or v.top_view or bot.m.paused or not bot.m.playing or bot.m.overlay.get_child_count() > 0:
		return out   # con la tienda, la libreta o un menú delante, la escena va atenuada debajo
	var cam: Camera3D = v.camera
	var placas: Array = bot.m.name_plates
	for s in range(1, 4):
		var h = v.heads[s] if s < v.heads.size() else null
		if h == null or not is_instance_valid(h) or not h.is_visible_in_tree():
			continue
		var c: Vector3 = h.global_position + Vector3(0, 0.45, 0)
		if cam.is_position_behind(c):
			continue
		var r := Rect2(v._u(c), Vector2.ZERO)
		for dx in [-0.13, 0.13]:
			for dy in [-0.13, 0.13]:
				var q: Vector3 = c + cam.global_transform.basis.x * dx + Vector3(0, dy, 0)
				r = r.expand(v._u(q))
		r = r.grow(-r.size.x * 0.15)
		for n in items:
			if not n is Label or str(n.text).strip_edges() == "" or placas.any(func(pl): return is_instance_valid(pl) and pl.is_ancestor_of(n)):
				continue
			var inter := tinta(n).intersection(r)
			if inter.get_area() > r.get_area() * 0.2:
				out.append({"tipo":"texto_tapa_cara", "clave": str(n.get_path(), "|cara", s), "texto": _txt(n), "detalle": "Texto encima de la cara de la silla %d" % s})
	return out


func revisar(bot) -> void:
	var raiz: Node = bot.m.pause_ui if bot.m.paused and is_instance_valid(bot.m.pause_ui) else bot.m.get_tree().root
	var actual := {}
	var pantalla := Rect2(Vector2.ZERO, bot.m.hud.get_viewport_rect().size)
	var todos: Array = inspeccionar(raiz, pantalla)
	if raiz == bot.m.get_tree().root:
		var items: Array = []
		recoger(raiz, items)
		todos.append_array(caras(bot, items))
	for a in todos:
		var key: String = a.tipo + "|" + a.clave
		actual[key] = int(persistencia.get(key, 0)) + 1
		if actual[key] < 15 or vistos.has(key):
			continue
		vistos[key] = true
		bot.hallazgo(a.tipo, a.detalle + " · " + JSON.stringify(a), a.clave)
		if vistos.size() <= 40:
			bot.foto("solape_%02d_%s" % [vistos.size(), a.tipo])   # I9: con foto se ve qué pisa a qué
	persistencia = actual
