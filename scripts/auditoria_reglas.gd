extends RefCounted
## Contratos del reglamento (docs/REGLAS_INTERACCION.md) comprobados por el bot.
## A diferencia de los demás auditores, no busca «algo roto» sino «algo que
## debería pasar y no pasa»: cada contrato dice qué tiene que verse o poder
## hacerse en un estado del juego. Solo mira: nunca mueve nada.
## Un contrato roto debe durar SEGUNDOS seguidos (las transiciones no cuentan);
## la primera vez deja captura y una línea en reglas.jsonl.

const MAX_FOTOS := 12

var muestras := 0
var fotos := 0
var _desde := {}      # id del contrato roto -> segundo en que empezó
var emitidos := {}
var contadores := {}  # id -> veces reportado

## id: [segundos que puede durar roto, qué dice el reglamento]
const CONTRATOS := {
	"R01": [2.5, "Al elegir aumento, a todos les sale la ventana, estén sentados, de pie o en el mostrador"],
	"R02": [1.5, "Si hay una ventana con botones, el ratón no puede estar capturado (hay que poder pulsarlos)"],
	"R03": [4.0, "En el tranque nadie se queda de pie: el colmadero te sienta"],
	"R04": [1.0, "El mostrador se cierra cuando se acaba la tienda"],
	"R05": [1.0, "Una ventana del juego no puede quedarse escondida fuera de la tienda y de «Ver la mesa»"],
	"R07": [2.5, "Toda espera con segundos enseña la cuenta atrás (no se queda en 0 s ni desaparece)"],
}

# R06 (tamaño estable): un panel o botón que ya se ve no cambia de tamaño
# porque su texto cambie o porque lo pulses. Se apunta una vez por control.
var cambios_tamano := {}   # ruta -> {texto antes/después, tamaño antes/después, pantalla, fase}
var _tamanos := {}         # ruta -> [tamaño, texto]


func revisar(bot) -> void:
	var m = bot.m
	muestras += 1
	_tamano_estable(bot)
	var rotos := inspeccionar(m)
	for id in _desde.keys():
		if not rotos.has(id):
			_desde.erase(id)
	for id in rotos:
		if not _desde.has(id):
			_desde[id] = bot._reloj
		if bot._reloj - float(_desde[id]) < float(CONTRATOS[id][0]) or emitidos.has(id + str(m.g.hand_no)):
			continue
		emitidos[id + str(m.g.hand_no)] = true
		contadores[id] = int(contadores.get(id, 0)) + 1
		var a := {"regla": id, "dice": CONTRATOS[id][1], "detalle": rotos[id], "fase": m.g.phase, "mano": m.g.hand_no,
			"de_pie": m.view.pie.mode, "fotograma": bot.frame, "segundo": bot._reloj}
		if fotos < MAX_FOTOS:
			var base := "regla_%s_%d" % [id, bot.frame]
			bot.foto(base)
			fotos += 1
			a["captura"] = base + ".png"
		bot.hallazgo("regla_" + id, "[%s] %s · %s" % [id, CONTRATOS[id][1], rotos[id]], id)
		var ruta: String = bot.dir + "/reglas.jsonl"
		var f := FileAccess.open(ruta, FileAccess.READ_WRITE) if FileAccess.file_exists(ruta) else FileAccess.open(ruta, FileAccess.WRITE)
		f.seek_end()
		f.store_line(JSON.stringify(a))
		f.close()


## Contratos rotos ahora mismo: id -> detalle.
func inspeccionar(m) -> Dictionary:
	var rotos := {}
	if not m.playing or m.paused or m.menus.visible:
		return rotos
	var g = m.g
	var de_pie: bool = m.view.pie.standing()
	# R01: elegir aumento → la ventana se ve (cartas o «esperando a los demás»)
	if g.phase == "pick" and m.avatar != "" and not m.overlay.is_visible_in_tree():
		rotos["R01"] = "fase pick sin ventana visible (de pie: %s, hijos: %d)" % [de_pie, m.overlay.get_child_count()]
	# R02: ventana con botones y ratón capturado
	if not OS.has_feature("mobile") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var botones := _botones_visibles(m.overlay)
		if is_instance_valid(m.counter_ui) and m.counter_ui.is_visible_in_tree():
			botones += _botones_visibles(m.counter_ui)
		if botones > 0:
			rotos["R02"] = "%d botones visibles con el ratón capturado (fase %s)" % [botones, g.phase]
	# R03: tranque con alguien (tú) de pie
	if m.tranque.activo and de_pie:
		rotos["R03"] = "tranque activo y sigues de pie (%s)" % m.view.pie.mode
	# R04: mostrador abierto fuera de la tienda
	if is_instance_valid(m.counter_ui) and g.phase != "shop":
		rotos["R04"] = "mostrador abierto en fase %s" % g.phase
	# R05: ventana con contenido escondida fuera de la tienda y de «Ver la mesa»
	if g.phase in ["pick", "over"] and m.overlay.get_child_count() > 0 and not m.overlay.visible \
			and not is_instance_valid(m._review_bar):
		rotos["R05"] = "capa de ventanas escondida en fase %s" % g.phase
	# R07: en el tranque, el reloj de girar fichas no se queda en «0 s»
	if m.tranque.activo and is_instance_valid(m.tranque._turno_lbl) and m.tranque._turno_lbl.is_visible_in_tree() 			and m.tranque._turno_lbl.text.ends_with("· 0 s"):
		rotos["R07"] = "«%s» parado en 0 s (etapa %s)" % [m.tranque._turno_lbl.text, m.tranque.st.get("etapa", "?")]
	return rotos


static func _botones_visibles(n: Node) -> int:
	var c := 0
	if n is BaseButton and n.is_visible_in_tree() and not n.disabled:
		c += 1
	for h in n.get_children():
		c += _botones_visibles(h)
	return c


## R06: recorre botones y paneles visibles y apunta los que cambian de tamaño
## estando en pantalla (el usuario: «cuando el texto no cabe el recuadro se hace
## más grande y se siente poco profesional»; botones que cambian al pulsarlos).
func _tamano_estable(bot) -> void:
	var m = bot.m
	var vistos := {}
	_recoger_tamanos(m.get_tree().root, vistos)
	for ruta in vistos:
		var ahora: Array = vistos[ruta]
		if _tamanos.has(ruta):
			var antes: Array = _tamanos[ruta]
			var d: Vector2 = (ahora[0] - antes[0]).abs()
			if (d.x > 2.0 or d.y > 2.0) and not cambios_tamano.has(ruta):
				cambios_tamano[ruta] = {"tipo": ahora[2], "texto_antes": antes[1], "texto_despues": ahora[1],
					"antes": str(antes[0]), "despues": str(ahora[0]), "pantalla": m.menus.screen if m.menus.visible else "partida",
					"fase": m.g.phase, "segundo": bot._reloj}
				bot.hallazgo("regla_R06", "[R06] «%s» cambia de tamaño %s → %s (texto «%s» → «%s»)" % [ahora[1], antes[0], ahora[0], antes[1], ahora[1]], ruta)
				FileAccess.open(bot.dir + "/tamanos.json", FileAccess.WRITE).store_string(JSON.stringify(cambios_tamano, "	"))
	_tamanos = vistos


func _recoger_tamanos(n: Node, out: Dictionary) -> void:
	if n is CanvasItem and not n.visible:
		return
	if (n is Button or n is PanelContainer) and n.is_visible_in_tree() and n.scale.is_equal_approx(Vector2.ONE):
		var texto: String = n.text if n is Button else _primer_texto(n)
		out[str(n.get_path())] = [n.size, texto, n.get_class()]
	for h in n.get_children():
		_recoger_tamanos(h, out)


static func _primer_texto(n: Node) -> String:
	for h in n.get_children():
		if (h is Label or h is Button) and h.text != "":
			return h.text
		var t := _primer_texto(h)
		if t != "":
			return t
	return ""
