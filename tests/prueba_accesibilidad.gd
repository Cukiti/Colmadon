extends SceneTree
## Ejecutar CON ventana y -- --autotest: nunca abre ni guarda el perfil real.
var m
var fallos := 0
var comprobaciones := 0
var salida := "res://capturas/recorrido/accesibilidad"
var original: Dictionary

func _initialize() -> void:
	call_deferred("run")

func check(condicion: bool, mensaje: String) -> void:
	comprobaciones += 1
	if not condicion:
		fallos += 1
		print("FALLO ACCESIBILIDAD: ", mensaje)

func controles(n: Node) -> Array:
	var out := []
	if n is Control:
		out.append(n)
	for c in n.get_children():
		out.append_array(controles(c))
	return out

func auditar(n: Node) -> void:
	for c in controles(n):
		if not c.is_visible_in_tree() or not (c is Label or c is Button or c is LineEdit):
			continue
		var padre = c.get_parent()
		var recortado := false
		while padre != null:
			if padre is ScrollContainer:
				recortado = true
				break
			padre = padre.get_parent()
		if recortado:
			continue  # contenido desplazable, auditado visualmente en las capturas
		var texto: String = c.tr(c.text) if c.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED else c.text
		if texto.is_empty():
			continue
		check(Rect2(-2, -2, 644, 364).encloses(c.get_global_rect()), "fuera: " + texto + " " + str(c.get_global_rect()))
		if c is Label and c.autowrap_mode != TextServer.AUTOWRAP_OFF:
			continue
		var ancho := 0.0
		for linea in texto.split("\n"):
			ancho = maxf(ancho, c.get_theme_font("font").get_string_size(linea, HORIZONTAL_ALIGNMENT_LEFT, -1, c.get_theme_font_size("font_size")).x)
		check(ancho <= c.size.x + 2, "texto recortado: " + texto)

func snap(nombre: String, raiz: Node) -> void:
	await create_timer(0.65).timeout
	auditar(raiz)
	root.get_texture().get_image().save_png(salida + "/" + nombre + ".png")

func run() -> void:
	if not "--autotest" in OS.get_cmdline_user_args():
		print("FALLO: se requiere -- --autotest para aislar los datos")
		quit(1)
		return
	var resolucion := DisplayServer.window_get_size()
	salida += "/%dx%d" % [resolucion.x, resolucion.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(salida))
	m = load("res://main.tscn").instantiate()
	root.add_child(m)
	m.autotest = false
	original = m.menus.settings.duplicate(true)
	m.menus._settings_path = "user://ajustes_accesibilidad_%dx%d_prueba.cfg" % [resolucion.x, resolucion.y]
	m.menus._profile_path = "user://perfil_accesibilidad_%dx%d_prueba.cfg" % [resolucion.x, resolucion.y]
	m.menus.settings.fullscreen = false
	m.menus.settings.ventana = ""
	m.menus.settings.emisora = "off"
	for tam in range(3):
		for activo in [false, true]:
			m.menus.settings.texto = tam
			m.menus.settings.daltonico = activo
			m.menus.settings.menos_movimiento = activo
			m.menus.settings.teclas = m.accesibilidad.TECLAS.duplicate()
			for i in range(7):
				check(m.accesibilidad.asignar("gesto%d" % (i + 1), KEY_F1 + i), "asignar gesto %d" % (i + 1))
			check(m.accesibilidad.asignar("pararse", KEY_F8), "asignar F8")
			check(m.accesibilidad.asignar("mirar", KEY_F9), "asignar F9")
			check(m.accesibilidad.asignar("chat", KEY_F10), "asignar F10")
			check(not m.accesibilidad.asignar("chat", KEY_F1), "rechazar duplicada")
			check(not m.accesibilidad.asignar("chat", KEY_ESCAPE), "rechazar Escape")
			check(not m.accesibilidad.asignar("chat", KEY_W), "proteger movimiento")
			var esperado: Dictionary = m.menus.settings.duplicate(true)
			m.menus.save()
			m.menus.settings.texto = -1
			m.menus.settings.teclas = {}
			m.menus._load()
			check(m.menus.settings == esperado, "guardar/cargar tamaño %d activo %s" % [tam, activo])
			m.apply_settings()
			check(m.shake_mult == (0.0 if activo else m.menus.settings.shake), "menos movimiento")
			check(m.view.accesible == activo and m.sv3d.size == Vector2i(640, 360), "paleta y mesa sin escalar")
	var viejo := {}
	m.accesibilidad.normalizar(viejo)
	check(viejo.texto == 0 and not viejo.daltonico and viejo.teclas == m.accesibilidad.TECLAS, "migración ajustes antiguos")
	viejo.teclas.chat = KEY_1
	m.accesibilidad.normalizar(viejo)
	check(viejo.teclas == m.accesibilidad.TECLAS, "recuperar mapa inválido")
	m.menus.settings.teclas = m.accesibilidad.TECLAS.duplicate()
	check(m.accesibilidad.asignar("gesto1", KEY_F1), "reasignar gesto")
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_F1
	check(m.accesibilidad.coincide(ev, "gesto1"), "evento nueva tecla")
	ev.keycode = KEY_1
	check(not m.accesibilidad.coincide(ev, "gesto1"), "tecla anterior deja de responder")
	ev.keycode = KEY_F1
	ev.ctrl_pressed = true
	check(not m.accesibilidad.coincide(ev, "gesto1"), "combinación no activa gesto")
	await create_timer(3).timeout
	m.set_process(false)
	m.quit_to_menu()
	await create_timer(1.6).timeout
	for idioma in ["es", "en"]:
		for tam in range(3):
			m.menus.settings.idioma = idioma
			m.menus.settings.texto = tam
			m.menus.settings.daltonico = tam == 2
			m.apply_settings()
			for pantalla in ["ajustes", "accesibilidad"]:
				m.menus.open(pantalla)
				m.view.cam_set("radio")
				await snap("%s_%s_%d" % [pantalla, idioma, tam], m.menus)
				if pantalla == "accesibilidad":
					for c in controles(m.menus):
						if c is ScrollContainer:
							c.scroll_vertical = 10000
					await snap("controles_%s_%d" % [idioma, tam], m.menus)
					m.accesibilidad.pendiente = "chat"
					ev.ctrl_pressed = false
					ev.keycode = KEY_W
					m._input(ev)
					check(m.accesibilidad.pendiente == "chat", "captura rechaza tecla reservada")
					ev.keycode = KEY_ESCAPE
					m._input(ev)
					check(m.accesibilidad.pendiente == "", "Escape cancela captura")
					await process_frame
					await process_frame
					for c in controles(m.menus):
						if c is Button and c.text == "Restablecer controles":
							c.pressed.emit()
					await process_frame
					await process_frame
					check(m.menus.settings.teclas == m.accesibilidad.TECLAS, "botón restablecer")
		m.start_game(true, "clasico")
		m.autotest = false
		m.set_process(false)
		await create_timer(2.2).timeout  # termina el barajado antes de preparar la mesa
		m.g.finish_draw(m.g.auto_picks([]))
		var primer: Dictionary = m.g.legal_moves(m.g.turn)[0]
		m.g.play(m.g.turn, primer.tile, primer.side)
		m.view.reset_table()
		m.view._shuffled_hand = m.g.hand_no  # fixture ya repartida: no vuelve a barajar
		m.g.events.clear()
		m.floats.clear()
		m.busy = true
		m._clear_overlay()
		m.g.phase = "play"
		m.g.turn = 0
		m.my_picks = range(7)
		m.view.sync(m.g, [], -1, m.seat_names)
		m.view.animating = false
		m._process(0.0)
		m._refresh()
		await process_frame
		await process_frame
		m._process(0.0)
		m.view.set_show_ends(true)
		m.view.sync(m.g, [], -1, m.seat_names)
		m.menus.settings.teclas = m.accesibilidad.TECLAS.duplicate()
		m.accesibilidad.asignar("mirar", KEY_F9)
		ev.ctrl_pressed = false
		ev.keycode = KEY_F9
		m._unhandled_input(ev)
		check(m.view.top_view, "mirar con tecla reasignada")
		m._unhandled_input(ev)
		check(not m.view.top_view, "mirar alterna")
		m.chat_btn.visible = true
		m.accesibilidad.asignar("chat", KEY_F10)
		ev.keycode = KEY_F10
		m._unhandled_input(ev)
		check(is_instance_valid(m.chat_panel), "chat con tecla reasignada")
		await snap("chat_%s_muy_grande" % idioma, m.chat_panel)
		m._unhandled_input(ev)
		await process_frame
		check(not is_instance_valid(m.chat_panel), "cerrar chat con nueva tecla")
		for i in range(7):
			m.accesibilidad.asignar("gesto%d" % (i + 1), KEY_F1 + i)
			ev.keycode = KEY_F1 + i
			m._input(ev)
			check(m.view.pie.emote_bob == m.EMOTES[i][0], "gesto %d con nueva tecla" % (i + 1))
		m.accesibilidad.asignar("pararse", KEY_F8)
		ev.keycode = KEY_F8
		m.stand_btn.visible = true
		m.view.animating = false
		m._input(ev)
		check(m.view.pie.standing(), "pararse con nueva tecla")
		m.view.pie.mode = "de_pie"
		m.view.pie.pos = m.view.pie.SEAT_SPOT
		m._input(ev)
		check(m.view.pie.mode == "caminando_a_silla", "sentarse con nueva tecla")
		m.view.pie.mode = "sentado"
		m._capture_mouse(false)
		m.floats.clear()
		m.g.events.clear()
		m._refresh()
		await process_frame
		await process_frame
		m._process(0.0)
		await snap("mesa_%s_muy_grande" % idioma, m.hud)
		m.view.set_show_ends(true)
		m.view.sync(m.g, [], -1, m.seat_names)
		check(m.view.end_labels[-1].visible and m.view.end_labels[1].visible, "puntas distinguibles con números")
		await snap("puntas_%s_daltonico" % idioma, m.hud)
		m._tranque_pending = true
		m.g.phase = "shop"
		m.g.last_result = {"reason": "tranque", "team": 0, "seat": 0, "pts": 12, "bonus": [],
			"tranque": {"pips": [1, 8, 2, 9], "teams": [3, 17], "tie": false, "opener": 0}}
		m._tranque_screen(m.g.last_result)
		await create_timer(2).timeout
		m.view.sync(m.g, [], -1, m.seat_names)
		m.floats.clear()
		m.draw_btn.visible = false
		m.action_box.visible = false
		m.stand_btn.visible = false
		m.turn_banner.visible = false
		m._place_plates()
		await snap("tranque_%s_daltonico" % idioma, m.tranque_ui)
		m.quit_to_menu()
		m.accesibilidad.pendiente = "chat"
		check(not m.accesibilidad.capturar(ev) and m.accesibilidad.pendiente == "", "cerrar menú cancela captura")
	m.menus.settings = original
	m.apply_settings()
	m.menus.save()  # solo archivos aislados de esta prueba
	print("ACCESIBILIDAD: ", comprobaciones, " comprobaciones; ", fallos, " fallos")
	quit(1 if fallos else 0)
