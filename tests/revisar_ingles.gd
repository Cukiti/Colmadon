extends SceneTree
## Auditoría visual reproducible. Se combina con --recorrido o las pruebas
## --prueba-menus/--prueba-cartas/--prueba-revision del producto.
## --qa-estaticas --autotest añade estados preparados de interfaz.

class Observador extends Node:
	var m
	var salida := ""
	var frame := 0
	var vistos := {}
	var registro: FileAccess
	var fotos := 0
	var idioma := "en"
	func _ready() -> void:
		registro = FileAccess.open(salida + "/observaciones.jsonl", FileAccess.WRITE)
	func _process(_delta: float) -> void:
		frame += 1
		if frame % 30 != 0 or not is_instance_valid(m):
			return
		var raiz: Node = m.pause_ui if m.paused and is_instance_valid(m.pause_ui) else m.ui
		inspeccionar(raiz)
	func inspeccionar(n: Node) -> void:
		if n is CanvasItem and not n.is_visible_in_tree():
			return
		if n is Label or n is Button:
			var texto: String = n.text if n.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED else n.tr(n.text)
			var rect: Rect2 = n.get_global_rect()
			var pantalla := Rect2(Vector2.ZERO, Vector2(640, 360))
			if texto != "" and rect.size.x > 0:
				if not pantalla.grow(2).encloses(rect):
					anotar(n, texto, "fuera", rect, 0)
				var font: Font = n.get_theme_font("font")
				var ancho := 0.0
				for linea in texto.split("\n"):
					ancho = maxf(ancho, font.get_string_size(linea, HORIZONTAL_ALIGNMENT_LEFT, -1, n.get_theme_font_size("font_size")).x)
				if (n is Button or n.autowrap_mode == TextServer.AUTOWRAP_OFF) and ancho > rect.size.x + 1:
					anotar(n, texto, "ancho", rect, ancho)
		for c in n.get_children():
			inspeccionar(c)
	func anotar(n: Control, texto: String, tipo: String, rect: Rect2, ancho: float) -> void:
		var key := str(n.get_path()) + texto + tipo
		if vistos.has(key):
			return
		vistos[key] = true
		var foto := ""
		if fotos < 20:
			foto = "observacion_%02d.png" % fotos
			fotos += 1
			m.get_viewport().get_texture().get_image().save_png(salida + "/" + foto)
		registro.store_line(JSON.stringify({"tipo": tipo, "texto": texto, "ruta": str(n.get_path()),
			"rect": str(rect), "ancho": ancho, "foto": foto, "idioma": TranslationServer.get_locale(),
			"menu": m.menus.screen, "fase": m.g.phase, "frame": frame}))
		registro.flush()

var m
var salida := ""
var observador

func cambiar(idioma: String) -> void:
	m.menus.settings.idioma = idioma
	m.apply_settings()
	await process_frame
	await process_frame

func boton(n: Node, texto: String) -> Button:
	if n is Button and n.text == texto:
		return n
	for child in n.get_children():
		var encontrado := boton(child, texto)
		if encontrado != null:
			return encontrado
	return null

func _initialize() -> void:
	call_deferred("run")

func snap(nombre: String, espera := -1.0) -> void:
	await create_timer(espera if espera >= 0 else (6.0 if nombre == "modos" else 1.8)).timeout
	m.get_viewport().get_texture().get_image().save_png(salida + "/" + nombre + ".png")
	print("QA FOTO ", nombre, " idioma=", TranslationServer.get_locale())

func run() -> void:
	var idioma := "en"
	var size := Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-idioma="):
			idioma = arg.trim_prefix("--qa-idioma=")
		elif arg.begins_with("--qa-salida="):
			salida = ProjectSettings.globalize_path(arg.trim_prefix("--qa-salida="))
		elif arg.begins_with("--qa-resolucion="):
			var xy := arg.trim_prefix("--qa-resolucion=").split("x")
			size = Vector2i(int(xy[0]), int(xy[1]))
	assert(salida != "", "Falta --qa-salida")
	DirAccess.make_dir_recursive_absolute(salida)
	m = load("res://main.tscn").instantiate()
	root.add_child(m)
	m.menus.settings.idioma = idioma
	m.menus.settings.fullscreen = false
	m.menus.settings.ventana = ""
	m.apply_settings()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	TranslationServer.set_locale(idioma)
	observador = Observador.new()
	observador.m = m
	observador.salida = salida
	root.add_child(observador)
	print("QA IDIOMA ", idioma, " RESOLUCION ", size, " USERDATA ", OS.get_user_data_dir())
	create_timer(1000).timeout.connect(func():
		print("QA FALLO: límite de tiempo")
		quit(1))
	if OS.get_cmdline_user_args().has("--qa-estaticas"):
		var completo = await estaticas(idioma)
		if completo != true:
			print("QA FALLO: recorrido estático incompleto")
			quit(1)
			return
		print("QA ESTATICAS TERMINADAS")
		quit()

func estaticas(idioma: String) -> bool:
	await create_timer(2).timeout
	m.autotest = false
	m.set_process(false)
	m.quit_to_menu()
	m.menus.settings.idioma = idioma
	m.apply_settings()
	for pagina in ["inicio", "modos", "amigos", "personaje", "armario", "ajustes"]:
		m.menus.open(pagina)
		await snap(pagina)
		if pagina == "personaje":
			for tab in ["ropa", "detalles"]:
				m.menus._mirror_tab = tab
				m.menus.open(pagina)
				await snap("personaje_" + tab)
		if pagina == "armario":
			for tab in ["mesa", "vaso"]:
				m.menus._tab = tab
				m.menus.open(pagina)
				await snap("armario_" + tab)
		if pagina == "ajustes":
			m.menus._delete_ask.pressed.emit()
			await snap("borrar_confirmacion")
			m.menus.open("ajustes")
			m.radio.emisora = "fm"
			m.menus.open("ajustes")
			await snap("radio_fm")
			m.radio.emisora = "mia"
			m.menus.open("ajustes")
			await snap("musica_propia")
			var avisos := CanvasLayer.new()
			avisos.layer = 30
			root.add_child(avisos)
			for cantidad in [0, 1, 2]:
				# Presentación preparada del texto: no abre el selector nativo
				# ni copia música del jugador.
				var aviso := PanelContainer.new()
				aviso.theme = m.theme_ui
				aviso.position = Vector2(350, 310)
				aviso.add_child(m._lbl(m.menus._import_notice(cantidad), 13, m.C_GOLD))
				avisos.add_child(aviso)
				await snap("importacion_%d" % cantidad, 0.2)
				aviso.queue_free()
			avisos.queue_free()
			m.radio.emisora = "off"
	m.start_game(true)
	m.set_process(false)
	m.autotest = false
	m.busy = true
	await snap("elegir_aumento")
	await cambiar("es" if idioma == "en" else "en")
	await snap("aumento_idioma_caliente")
	await cambiar(idioma)
	m.g.phase = "shop"
	m.ui_phase = "shop"
	m.g.last_result = {"seat": 0, "team": 0, "pts": 60, "reason": "dominó", "bonus": [], "capicua": false}
	m.g.coins[0] = 50
	m._build_shop()
	await snap("tienda")
	await cambiar("es" if idioma == "en" else "en")
	await snap("tienda_idioma_caliente")
	await cambiar(idioma)
	m.g.mode = "clasico"
	m._build_between()
	await snap("entre_manos")
	m.g.phase = "over"
	m.ui_phase = "over"
	m._clear_overlay()
	m._build_notebook()
	await snap("libreta")
	var pesos: int = m.menus.profile.pesos
	var ganadas: int = m.menus.profile.get("ganadas", 0)
	await cambiar("es" if idioma == "en" else "en")
	await snap("libreta_idioma_caliente")
	if m.menus.profile.pesos != pesos or m.menus.profile.get("ganadas", 0) != ganadas:
		push_error("QA FALLO: idioma repitió premios")
		return false
	await cambiar(idioma)
	# Estados online preparados: solo interfaz, sin conexión a ningún servidor.
	m._clear_overlay()
	m.g.phase = "lobby"
	m.ui_phase = "lobby"
	m.online_v = {"code": "PRUEBA", "me_host": true, "seats": [
		{"bot": false, "name": "Tú"}, {"bot": false, "name": "Amigo"},
		{"bot": true, "name": "Fello"}, {"bot": true, "name": "Chichí"}]}
	m._lobby_sig = ""
	m._build_lobby()
	m._toggle_chat()
	await snap("sala_chat_preparada")
	m.chat_panel.queue_free()
	m.online_v.me_host = false
	m._lobby_sig = ""
	m._build_lobby()
	await snap("sala_invitado_preparada")
	m.online = true
	m.online_v.seats[0].away = true
	m._tick_away()
	await snap("ausente_preparado")
	m.online = false
	m._tick_away()
	m._wait_others("Esperando a que los demás elijan…")
	await snap("espera_preparada")
	# Cambiar idioma desde la radio con una página visible, sin reiniciar.
	m.quit_to_menu()
	m.menus.open("ajustes")
	await snap("idioma_antes")
	var elegido := boton(m.menus, "Español" if idioma == "en" else "English")
	if elegido == null:
		push_error("QA FALLO: no se encontró selector de idioma")
		return false
	elegido.pressed.emit()
	await snap("idioma_caliente")
	await cambiar(idioma)
	return true
