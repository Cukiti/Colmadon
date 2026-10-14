extends Node2D
## Partida: une la lógica (game.gd), la mesa 3D (view3d.gd) y la interfaz
## estilo colmado caribeño.

const ColmadoGame := preload("res://scripts/game.gd")
const View3D := preload("res://scripts/view3d.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Menus := preload("res://scripts/menus.gd")
const Accesibilidad := preload("res://scripts/accesibilidad.gd")

const SEAT_NAMES_LOCAL := ["Tú", "Yeya", "Don Fello", "Chichí"]
# consejos y dichos de la pantalla de carga
const DICHOS := [
	"El que tranca, cobra.",
	"Cuidado con el chivo: el que sigue siempre está mirando.",
	"Suelta los dobles antes de que te los ahorquen.",
	"Si tu compañero pasó a un número, no se lo vuelvas a dar.",
	"Un ron te alegra… y te despista.",
	"Cuenta las fichas: si ya salieron seis del 4, el 4 está muerto.",
	"El agua fría deja al rival sin turno.",
	"Las fichas pesadas, mejor soltarlas temprano.",
	"La capicúa vale más con la carta Capicúa.",
	"En el colmado se fía… pero las bebidas se pagan.",
]
# paleta del colmado
const C_INK := Color(0.12, 0.07, 0.04)
const C_CREAM := Color(1.0, 0.95, 0.82)
const C_GOLD := Color(1.0, 0.8, 0.22)
const C_TURQ := Color(0.1, 0.62, 0.62)
const C_RED := Color(0.85, 0.22, 0.2)
const C_WOOD := Color(0.5, 0.3, 0.15)
const C_WOOD_D := Color(0.27, 0.15, 0.07)
const CARD_KIND := {
	"doble": "pts", "capicua": "pts", "cierre": "pts",
	"pasador": "coin", "bolsillo": "coin", "fiado": "coin",
	"ojo": "info", "ligera": "info",
	"marcada": "pts", "suerte": "pts", "tranque": "info",
}
# chat rápido online: ids que acepta el servidor (sala.ts, SALA_FRASES)
const FRASES := [["capicua", "¡Capicúa!"], ["pasate", "¡Pásate, compai!"], ["chivo_visto", "Ese chivo te lo vi"],
	["buena", "¡Buena jugada!"], ["ay", "¡Ay, mi madre!"], ["tranque", "Esto se tranca"],
	["bebe", "¡Échate un trago!"], ["gracias", "Gracias, compai"]]
const DRINK_COLOR := {"cafe": Color(0.4, 0.22, 0.1), "ron": Color(0.85, 0.5, 0.12), "morir": Color(1, 0.72, 0.42), "agua": Color(0.55, 0.85, 1)}

var g := ColmadoGame.new()
var seat_names: Array = SEAT_NAMES_LOCAL.duplicate()
# partida online: el servidor decide; aquí solo se envían las jugadas
const Red := preload("res://scripts/red.gd")
const Radio := preload("res://scripts/radio.gd")
var red: Node
var radio: Node
var online := false
var online_v := {}          # último estado recibido
var _deadline_ms := 0       # online: cuándo se acaba el tiempo de la fase o del turno
var _turn_base := ""        # texto del cartel de turno sin el reloj
var _tic_last := -1
var chat_btn: Button
var chat_panel: PanelContainer
var emote_btn: Button          # gestos sentado (bailar en la silla, aplaudir…): los ven todos
var emote_panel: PanelContainer
var _look_sig := ["", "", "", ""]
var selected := -1
var busy := false
var ui_phase := ""
var floats: Array = []
var shake := 0.0
var zoom := 1.0                 # rueda del ratón: 1 normal … 2,5 de cerca (estrecha la vista)
var _rlook := false             # sentado: arrastrando con el clic derecho para mirar
# modo cámara (PC, sentado): el ratón mueve la cabeza y la mira del centro elige
var cam_mode := false
var _cam_hold := false   # modo cámara: llevas una ficha en la mano (clic/E la coge, otro clic la suelta)
var _cam_hold_raton := false   # la cogiste con el clic: al soltar el botón se coloca (reglamento)
var _usando := false           # la tecla «usar» simula pulsar y soltar: ese soltar no coloca
# los bots y pruebas que hacen clic en posiciones de la pantalla no usan el modo cámara
var _cam_bloqueado: bool = Array(OS.get_cmdline_user_args()).any(func(a): return a == "--recorrido" or a == "--demo" or a.begins_with("--escena") or (a.begins_with("--prueba") and not a in ["--prueba-camara", "--prueba-arma"]))
var _cam_hint: Label
const CAM_SENS := 0.0025
const CAM_MIN := Vector2(-1.22, -0.6)    # ~70° a cada lado, como un cuello de verdad
const CAM_MAX := Vector2(1.22, 0.45)
var _rlook_moved := 0.0
var flash := 0.0
var t_anim := 0.0
# --demo: el juego se juega solo (también tu silla) y al acabar cada mano
# enseña la mesa unos segundos y guarda fotos numeradas en capturas/demo/
var demo := OS.get_cmdline_user_args().has("--demo")
var autotest := OS.get_cmdline_user_args().has("--autotest") or demo
var shots := 0

var view: Node3D
var menus: Control
var accesibilidad
var hud: Control
var pause_ui: Control
var sharp_rect: TextureRect
var sv3d: SubViewport
## ancho visible de la interfaz (360 de alto fijo; en pantallas anchas pasa de 640)
var W := 640.0
var CX := 320.0
var screen_rect: TextureRect
var playing := false
var paused := false
var shake_mult := 1.0
var avatar := ""
var sfx: Node
var tint: ColorRect
var dizzy := 0.0
var _last_hover := -1
var my_picks: Array = []
var bot_picks: Array = [[], [], [], []]
var action_box: VBoxContainer
var _press_i := -1
var _mi_orden: Array = []   # F10: orden de tu mano que elegiste
var _press_pos := Vector2.ZERO
var _dragging := false
var tiles_sv: SubViewport
var tiles_cam: Camera3D
var ui: CanvasLayer
var theme_ui: Theme
var font: SystemFont
var score_us: Label
var score_them: Label
var meta_lbl: Label
var coin_lbl: Label
var cards_row: HBoxContainer
var turn_banner: PanelContainer
var turn_lbl: Label
var drink_box: HBoxContainer
var view_btn: Button
var pause_btn: Button
var draw_btn: Button
var _collecting := false
var _picking := false
var _card_nodes := {}   # id del aumento -> su carta en pantalla (para animar la elegida)
var pick_timer: Label
var shop_timer: Label        # online: la mano siguiente empieza en N s
# de pie (pie.gd): botón, barra de emotes y controles
var stand_btn: Button
var stand_ui: Control
var shove_btn: Button
var stand_hint: Label
var cover_btn: Button
var sit_btn: Button
var _pose_ms := 0
var _my_cover := false
var _look_acc := Vector2.ZERO
var _look_id := -2          # dedo (o -1 ratón) que mueve la mirada
var _look_last := Vector2.ZERO
var _joy_id := -2           # dedo del joystick (móvil)
var _joy_center := Vector2.ZERO
var _joy_vec := Vector2.ZERO
var _mano_sent := "0,0"     # online: lo último que mandaste de tus fichas
var _mano_ms := 0
var _drag_side := 0         # punta hacia la que llevas la ficha al arrastrar
var _chair_aim := false     # de pie: apuntas a tu silla y estás cerca (clic = sentarte)
var _radio_aim := false     # de pie: apuntas a la radio del colmado (clic = cambiarla)
const CHAIR_REACH := 1.2    # metros hasta tu silla para poder tocarla
const EMOTES := [["dance", "Bailar"], ["clap", "Aplaudir"], ["point", "Señalar"], ["wave", "Saludar"], ["stretch", "Estirarse"], ["choca", "Chocar"], ["brindis", "Brindar"]]
var wallet_panel: PanelContainer
var name_plates: Array = []
var overlay: Control
var big_banner: Label
var _last_scores := [0, 0]
var _icons := {}


func _ready() -> void:
	randomize()
	# recorrido de pruebas: misma semilla = misma partida en cada grabación
	if OS.get_cmdline_user_args().has("--recorrido"):
		seed(20261004)
		for a in OS.get_cmdline_user_args():
			if str(a).begins_with("--semilla="):   # el bot explorador cambia de partida con otra semilla
				seed(int(str(a).trim_prefix("--semilla=")))
	# el 3D conserva 640x360 y escalado nearest, con suavizado leve de bordes;
	# la interfaz se dibuja a resolución real para que los textos se lean bien
	var bg := CanvasLayer.new()
	bg.layer = -1
	add_child(bg)
	var sv := SubViewport.new()
	sv3d = sv
	sv.size = Vector2i(640, 360)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	view = View3D.new()
	sv.add_child(view)
	var screen := TextureRect.new()
	screen.texture = sv.get_texture()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.size = Vector2(W, 360)
	screen_rect = screen
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(screen)
	var pixel_soft := preload("res://scripts/pixel_suave.gd").new()
	pixel_soft.name = "PixelSuave"
	add_child(pixel_soft)
	pixel_soft.setup(sv, screen, view.camera)
	# segunda vista, a resolución real y con suavizado, solo para las fichas
	tiles_sv = SubViewport.new()
	tiles_sv.transparent_bg = true
	tiles_sv.msaa_3d = Viewport.MSAA_4X
	tiles_sv.own_world_3d = true
	tiles_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(tiles_sv)
	tiles_cam = Camera3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.32, 0.32)
	env.ambient_light_energy = 0.75
	tiles_cam.environment = env
	tiles_sv.add_child(tiles_cam)
	view.attach_tiles(tiles_sv)
	view.set_scene_texture(sv.get_texture())
	sfx = Sfx.new()
	add_child(sfx)
	radio = Radio.new()
	radio.emisora = ""   # la pone apply_settings con la de los ajustes
	add_child(radio)
	red = Red.new()
	add_child(red)
	tranque = preload("res://scripts/tranque.gd").new(self)
	add_child(tranque)
	arma = preload("res://scripts/arma.gd").new(self)
	add_child(arma)
	red.estado.connect(_on_estado)
	red.aviso.connect(func(t: String): _float(t, Vector2(CX, 210), Color(1, 0.6, 0.5)))
	red.desconectado.connect(_on_desconectado)
	red.poses.connect(_on_poses)
	red.manos.connect(func(d: Dictionary): view.set_fiddle(int(d.get("seat", 0)), int(d.get("st", 0)), int(d.get("side", 0))))
	# la cuenta de quien ganó, a su ritmo; y la tuya, para los demás
	red.cuenta.connect(func(d: Dictionary):
		if int(d.get("seat", -1)) != int(g.last_result.get("seat", -2)):
			return
		var t = d.get("tile")
		var ficha = Vector2i(int(t[0]), int(t[1])) if t is Array else null
		if autotest or OS.get_cmdline_user_args().has("--recorrido"):
			print("CUENTA AJENA ", d)
		if view.count_remote:
			view.count_remote_tile(ficha)
		elif g.phase in ["shop", "over"] and not view.counting:
			# tranque: aquí aún está abierta su pantalla (cada uno la cierra a su
			# momento): sus toques se guardan y la cuenta los sigue al empezar
			view._remote_buffer.append(ficha))
	view.counted_local.connect(func(t: Vector2i):
		if online:
			red.enviar(Red.OP_CUENTA, {"tile": [t.x, t.y]}))
	view.counted_all.connect(func():
		if online:
			red.enviar(Red.OP_CUENTA, {"all": true}))
	view.tile_landed.connect(func(strength: float):
		shake = max(shake, 2.2 + strength * 4.0)
		sfx.play("slam" if strength > 0.5 else "clack", 0.0 if strength > 0.5 else -3.0))
	view.shuffle_started.connect(func(): sfx.play("shuffle", -2.0, 0.03))
	view.count_tick.connect(_on_count_tick)
	view.count_done.connect(_on_count_done)
	view.count_ready.connect(_on_count_ready)
	view.sfx.connect(func(n: String): sfx.play(n, -8.0))
	var sharp := TextureRect.new()
	sharp.texture = tiles_sv.get_texture()
	sharp.size = Vector2(W, 360)
	sharp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sharp.stretch_mode = TextureRect.STRETCH_SCALE
	sharp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(sharp)
	sharp_rect = sharp
	sharp.position = Vector2.ZERO
	sharp.size = Vector2(W, 360)
	_resize_tiles_view()
	get_viewport().size_changed.connect(_resize_tiles_view)
	get_viewport().size_changed.connect(RegistroFallos.contexto)
	_make_theme()
	_build_hud()
	menus = Menus.new(self)
	menus.theme = theme_ui
	ui.add_child(menus)
	accesibilidad = Accesibilidad.new(self)
	add_child(accesibilidad)
	apply_settings()
	# la ventana arranca como la dejaste: maximizada si lo estaba
	if not menus.settings.fullscreen and menus.settings.get("ventana", "") == "max" and not autotest:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	_colocar_cuadrante()
	view.set_avatar_cfg(menus.profile)
	menus.apply_equip()
	g.new_game()
	var args: Array = Array(OS.get_cmdline_user_args())
	var test_mode: bool = autotest or args.any(func(a): return (a.begins_with("--prueba") and a != "--prueba-menus" and not a.begins_with("--prueba-sala")) or a == "--retratos")
	if test_mode:
		start_game(true, "clasico" if args.has("--clasico") else "aumentos")
	else:
		# se empieza en la calle, frente al colmado
		hud.visible = false
		sharp_rect.visible = false
		view.show_arms = false
		view.cam_set("calle")
		await _loading_screen()
		menus.open("inicio")
		if args.has("--prueba-menus"):
			_prueba_menus()
		if args.has("--prueba-sala") or args.has("--prueba-sala-unirse"):
			_prueba_sala(args.has("--prueba-sala"))
		if args.has("--recorrido"):
			var esc := "menus"
			for a in args:
				if str(a).begins_with("--escena="):
					esc = str(a).trim_prefix("--escena=")
			var bot_script: Script = load("res://scripts/explorador.gd") if esc == "explorar" else preload("res://scripts/recorrido.gd")
			add_child(bot_script.new(self, esc))
	if OS.get_cmdline_user_args().has("--retratos"):
		_retratos()
	if OS.get_cmdline_user_args().has("--prueba-dobles"):
		_prueba_dobles()
	if OS.get_cmdline_user_args().has("--prueba-camara"):
		_prueba_camara()
	if OS.get_cmdline_user_args().has("--prueba-tranque-reparto"):
		_prueba_tranque_reparto()
	if OS.get_cmdline_user_args().has("--prueba-arma"):
		_prueba_arma()
	if OS.get_cmdline_user_args().has("--prueba-arrastre"):
		_prueba_arrastre()
	if OS.get_cmdline_user_args().has("--prueba-beber"):
		_prueba_beber()
	if OS.get_cmdline_user_args().has("--prueba-visual"):
		_prueba_visual()
	if OS.get_cmdline_user_args().has("--prueba-cuenta"):
		_prueba_cuenta()
	if OS.get_cmdline_user_args().has("--prueba-revision"):
		_prueba_revision()
	if OS.get_cmdline_user_args().has("--prueba-cartas"):
		_prueba_cartas()
	if OS.get_cmdline_user_args().has("--prueba-minimizar"):
		_prueba_minimizar()
	if OS.get_cmdline_user_args().has("--prueba-pases"):
		_prueba_pases()
	if OS.get_cmdline_user_args().has("--prueba-pie"):
		_prueba_pie()


## Prueba de pie: levantarse, mirar las fichas de Yeya por detrás, bailar,
## empujar y volver solo a la silla rodeando la mesa. Capturas pie_*.png.
func _prueba_pie() -> void:
	var snap := func(n: String):
		get_viewport().get_texture().get_image().save_png("user://pie_%s.png" % n)
		print("FOTO ", n)
	_pick(g.offers[0][0])
	while g.phase != "play" or view.animating:
		if g.phase == "draw" and not _collecting and draw_btn.visible:
			_auto_collect()
		await get_tree().process_frame
	while g.turn == 0:
		await get_tree().process_frame
	_stand_up()
	await get_tree().create_timer(0.7).timeout
	snap.call("silla_atras")
	await get_tree().create_timer(0.5).timeout
	snap.call("levantando")
	await get_tree().create_timer(1.6).timeout
	snap.call("de_pie")
	# caminar hacia la derecha de la mesa, detrás de Yeya (silla 1, en +X)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1400:
		Input.action_press("ui_right")
		view.pie.update(get_process_delta_time(), Vector2(1, 0), Vector2.ZERO)
		await get_tree().process_frame
	view.pie.pos = Vector2(1.75, 0.0)
	view.pie.yaw = PI / 2       # mirando hacia el centro (-X)
	view.pie.pos = Vector2(1.45, 0.45)   # por encima del hombro de Yeya
	view.pie.yaw = PI / 2 + 0.5
	view.pie.pitch = -0.85
	await get_tree().create_timer(0.6).timeout
	snap.call("detras_de_yeya")
	print("TAPADAS ", view.covered)
	view.pie.pos = Vector2(0.6, 1.5)
	view.pie.yaw = 0.0
	view.pie.pitch = -0.35
	_emote("dance")
	await get_tree().create_timer(1.0).timeout
	snap.call("baile")
	view.pie.pos = Vector2(-1.45, 0.3)
	view.pie.yaw = -PI / 2
	await get_tree().create_timer(0.3).timeout
	print("CERCA DE ", _nearest_person(), " (esperado 3)")
	_emote("shove")
	await get_tree().create_timer(0.3).timeout
	snap.call("empujon")
	view.pie.pos = Vector2(-0.3, -1.5)   # al otro lado de la mesa
	view.pie.sit_down()
	await get_tree().create_timer(0.2).timeout
	print("LEJOS no se sienta: ", view.pie.mode == "de_pie", " · botón SENTARSE visible: ", sit_btn.visible)
	view.pie.sit_down(true)
	t0 = Time.get_ticks_msec()
	var dbg := 0
	while view.pie.standing() and Time.get_ticks_msec() - t0 < 12000:
		await get_tree().process_frame
		dbg += 1
		if dbg % 60 == 0:
			print("VUELTA pos ", view.pie.pos, " modo ", view.pie.mode)
	print("SENTADO de nuevo: ", not view.pie.standing(), " en ", (Time.get_ticks_msec() - t0) / 1000.0, " s")
	await get_tree().create_timer(0.5).timeout
	snap.call("sentado")
	get_tree().quit()


## Prueba visual de lo nuevo: aumento elegido, recoger fichas, aura de pases,
## +30 (salida y corrido) y los botones PASO / ¡UTE VA!. Capturas pases_*.png.
func _prueba_pases() -> void:
	var snap := func(n: String):
		get_viewport().get_texture().get_image().save_png("user://pases_%s.png" % n)
		print("FOTO ", n)
	await get_tree().create_timer(1.6).timeout
	_pick(g.offers[0][0])
	await get_tree().create_timer(0.45).timeout
	snap.call("aumento")
	var t0 := Time.get_ticks_msec()
	while not draw_btn.visible and Time.get_ticks_msec() - t0 < 8000:
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	print("RECOGER visible=", draw_btn.visible, " anim=", view.animating, " picks=", my_picks.size(), " rec=", _collecting, " pos=", draw_btn.position, " tam=", draw_btn.size, " hud=", hud.visible)
	snap.call("recoger")
	_auto_collect()
	while g.phase == "draw":
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	# mesa preparada: tú sales con el 6-6 y nadie lleva seis
	busy = true   # los bots esperan: los pases los manda la prueba
	g.scores = [0, 0]
	g.hands = [[Vector2i(6, 6), Vector2i(1, 6), Vector2i(0, 3), Vector2i(2, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 4)], [Vector2i(0, 0), Vector2i(3, 3), Vector2i(1, 4)],
		[Vector2i(4, 4), Vector2i(2, 3), Vector2i(0, 4)]]
	g.chain.clear()
	g.first_hand = true
	g.turn = 0
	g.phase = "play"
	view.reset_table()
	busy = true   # los bots esperan: los pases los manda la prueba
	g.play(0, Vector2i(6, 6), 0)
	_refresh()
	await get_tree().create_timer(1.2).timeout
	g.pass_turn(1)
	_refresh()
	await get_tree().create_timer(0.35).timeout
	snap.call("salida")
	await get_tree().create_timer(2.2).timeout
	g.pass_turn(2)
	_refresh()
	await get_tree().create_timer(0.6).timeout
	snap.call("aura2")
	g.pass_turn(3)
	_refresh()
	await get_tree().create_timer(0.4).timeout
	snap.call("corrido")
	await get_tree().create_timer(2.4).timeout
	snap.call("aura3_turno")
	print("MARCADOR ", g.scores, " (esperado [60, 0])")
	view.set_aura(1, 2)
	await get_tree().create_timer(0.8).timeout
	snap.call("aura_rival2")
	view.set_aura(1, 3)
	await get_tree().create_timer(0.8).timeout
	snap.call("aura_rival3")
	# dominó: la mano se acaba y se cuentan las fichas
	g.hands[0] = [Vector2i(1, 6)]
	g.turn = 0
	g.play(0, Vector2i(1, 6), 1)
	_refresh()
	# ganó tu pareja: te toca contar; la prueba toca las fichas una a una
	var t0c := Time.get_ticks_msec()
	while not is_instance_valid(_count_ui) and Time.get_ticks_msec() - t0c < 8000:
		await get_tree().process_frame
	snap.call("cuenta_a")
	print("CUENTA MANUAL: ", view.count_manual, " fichas ", view._count_left.size())
	for k in 4:
		var n: int = view._count_left[0]
		view.count_pick(view._u(view._count_order[n][0].global_position))
		await get_tree().create_timer(0.3).timeout
	snap.call("cuenta_b")
	view.count_fast = true
	await get_tree().create_timer(2.0).timeout
	snap.call("cuenta_c")
	view.set_top(true)
	_review_table()
	await get_tree().create_timer(1.2).timeout
	view.set_top(true)
	await get_tree().create_timer(1.0).timeout
	snap.call("arriba")
	get_tree().quit()


## Minimizar y volver a mitad de partida (con pantalla completa también):
## buscando el cierre que vieron los amigos al cambiar de ventana.
func _prueba_minimizar() -> void:
	for k in 4:
		await get_tree().create_timer(2.5).timeout
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		print("MINIMIZADA ", k, " tamaño ", DisplayServer.window_get_size())
		await get_tree().create_timer(2.0).timeout
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if k % 2 == 1 else DisplayServer.WINDOW_MODE_WINDOWED)
		print("VUELTA ", k, " tamaño ", DisplayServer.window_get_size(), " fichas ", tiles_sv.size)
	print("PRUEBA MINIMIZAR TERMINADA")
	get_tree().quit()


func _resize_tiles_view() -> void:
	# stretch «expand»: el alto se queda en 360 y el ancho crece con la pantalla;
	# la mesa 3D se dibuja a ese ancho para que no queden franjas negras
	W = maxf(640.0, roundf(get_viewport().get_visible_rect().size.x))
	CX = W * 0.5
	sv3d.size = Vector2i(roundi(W), 360)
	screen_rect.size = Vector2(W, 360)
	sharp_rect.size = Vector2(W, 360)
	# misma proporción exacta que la vista de la mesa, a la resolución de la ventana
	var win := DisplayServer.window_get_size()
	var k: float = max(1.0, min(win.x / W, win.y / 360.0))
	tiles_sv.size = Vector2i(roundi(W * k), roundi(360 * k))


## Prueba: el tranque sigue «activo» (online la entrega aún no acabó) y el
## servidor ya pasó al reparto de la mano siguiente. Las manos de los demás
## no pueden quedarse boca arriba en la mesa.
func _prueba_tranque_reparto() -> void:
	while g.phase != "play":
		await get_tree().process_frame
		if g.phase == "pick" and overlay.get_child_count() > 0 and not _picking:
			await get_tree().create_timer(1.0).timeout
			if g.phase == "pick":
				await _pick(g.offers[0][0])
		if g.phase == "draw" and draw_btn.visible and not _collecting:
			_auto_collect()
	await get_tree().create_timer(1.0).timeout
	view.tranque_mesa(true)
	tranque.activo = true
	await get_tree().create_timer(0.5).timeout
	g.phase = "draw"
	for k in 30:
		await get_tree().process_frame
	print("TRANQUE-REPARTO manos boca arriba=", view.show_all_hands, " mesa del tranque=", view.tranque_on, " tranque activo=", tranque.activo)
	get_viewport().get_texture().get_image().save_png("user://tranque_reparto.png")
	get_tree().quit()


## Prueba del modo cámara: girar la cabeza con el ratón hasta que la mira
## caiga en una ficha que se pueda jugar y pulsar E (y, si cabe en las dos
## puntas, apuntar a la punta y E otra vez). Tres jugadas y capturas.
func _prueba_camara() -> void:
	var foto := func(n: String):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://camara_%s.png" % n)
	var apuntar := func(destino: Callable) -> bool:
		for k in 60:
			var d: Vector2 = destino.call() - Vector2(CX, 180)
			if d.length() < 3.0:
				return true
			var ev := InputEventMouseMotion.new()
			ev.relative = d * 0.8
			_unhandled_input(ev)
			await get_tree().process_frame
		return false
	var tecla_e := func():
		var ev := InputEventKey.new()
		ev.keycode = menus.settings.teclas.usar
		ev.pressed = true
		_unhandled_input(ev)
	# jugadas impares: mantener el clic del ratón y soltarlo en la punta (reglamento)
	var boton := func(abajo: bool):
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = abajo
		ev.position = Vector2(CX, 180)
		_unhandled_input(ev)
	var jugadas := 0
	var fallos := 0
	var t0 := Time.get_ticks_msec()
	var recogido := false
	while jugadas < 3 and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
		if Engine.get_process_frames() % 120 == 0:
			print("CAMARA espera fase=", g.phase, " turno=", g.turn, " busy=", busy, " anim=", view.animating, " cam=", cam_mode, " playing=", playing, " paused=", paused, " menus=", menus.visible, " pie=", view.pie.mode, " overlay=", overlay.get_child_count(), " top=", view.top_view, " tq=", tranque.activo, " cuenta=", view.counting, " review=", is_instance_valid(_review_bar))
		if g.phase == "pick" and not g.offers.is_empty() and overlay.get_child_count() > 0:
			await get_tree().create_timer(1.0).timeout
			if g.phase == "pick":
				await _pick(g.offers[0][0])
			continue
		if g.phase == "draw" and cam_mode and my_picks.size() >= 7 and draw_btn.visible and not recogido:
			await foto.call("recoger")
			var er := InputEventKey.new()
			er.keycode = menus.settings.teclas.recoger
			er.pressed = true
			_unhandled_input(er)
			recogido = true
			print("CAMARA recoger con tecla")
			continue
		if g.phase == "draw" and cam_mode and my_picks.size() < 7 and not view.animating:
			var libre: int = range(view.pool_nodes.size()).filter(func(x): return not view.pool_taken.has(x)).front()
			var cogidas: int = my_picks.size()
			await apuntar.call(func(): return view._u(view.pool_nodes[libre].position))
			if cogidas == 0:
				await foto.call("robar")
			tecla_e.call()
			await get_tree().create_timer(0.4).timeout
			print("CAMARA robar: ", cogidas, " -> ", my_picks.size())
			continue
		if not (g.phase == "play" and g.turn == 0 and not busy and not view.animating and cam_mode):
			continue
		var legales: Array = g.legal_moves(0)
		if legales.is_empty():
			await get_tree().create_timer(0.5).timeout
			var q := InputEventKey.new()
			q.keycode = menus.settings.teclas.paso
			q.pressed = true
			_unhandled_input(q)
			print("CAMARA sin ficha: paso con la tecla, turno ", g.turn)
			await get_tree().create_timer(1.0).timeout
			continue
		var t_mano := Time.get_ticks_msec()
		while view.hand_rects().size() != g.hands[0].size() and Time.get_ticks_msec() - t_mano < 3000:
			await get_tree().process_frame
		if view.hand_rects().size() != g.hands[0].size():
			continue
		var i: int = g.hands[0].find(legales[0].tile)
		var antes: int = g.chain.size()
		var ok: bool = await apuntar.call(func(): return view.hand_rects()[i].get_center())
		print("CAMARA apunta ficha ", g.hands[0][i], " ok=", ok, " hover=", view.hover_index, " look=", view.seat_look)
		await foto.call("apunta_%d" % jugadas)
		var con_raton: bool = jugadas % 2 == 1
		if con_raton:
			boton.call(true)
		else:
			tecla_e.call()
		await get_tree().create_timer(0.3).timeout
		print("CAMARA cogida en la mano: ", _cam_hold, " arrastrando=", view.drag_index)
		if _cam_hold:
			var lado: int = legales[0].side
			# con la mesa vacía, la salida va en cualquier punto del tablero (el centro)
			ok = await apuntar.call(func(): return view._u(Vector3(0, view.TABLE_Y, 0)) if g.chain.is_empty() else view.end_screen_pos(lado))
			await foto.call("llevando_%d" % jugadas)
			if con_raton:
				boton.call(false)
				print("CAMARA soltar el clic en la punta")
			else:
				tecla_e.call()
		var t1 := Time.get_ticks_msec()
		while g.chain.size() == antes and Time.get_ticks_msec() - t1 < 3000:
			await get_tree().process_frame
		if g.chain.size() > antes:
			jugadas += 1
			print("CAMARA jugada ", jugadas, " cadena ", g.chain.size())
		else:
			fallos += 1
			print("CAMARA FALLO: la ficha no se jugó")
			if fallos > 3:
				break
	print("CAMARA RESULTADO jugadas=", jugadas, " fallos=", fallos, " cam_mode=", cam_mode, " raton=", Input.mouse_mode)
	get_tree().quit()


## Prueba del arma: coger la pistola de las piernas con la mira, levantarse,
## matar a Yeya de un tiro en la cabeza y a Chichí con tres en el pecho;
## comprobar que el turno del muerto espera y que vuelve a su silla.
func _prueba_arma() -> void:
	var foto := func(n: String):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://arma_%s.png" % n)
	var mover := func(rel: Vector2):
		var ev := InputEventMouseMotion.new()
		ev.relative = rel
		_unhandled_input(ev)
	var raton := func(boton: int, down: bool):
		var ev := InputEventMouseButton.new()
		ev.button_index = boton
		ev.pressed = down
		ev.position = Vector2(CX, 180)
		_unhandled_input(ev)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
		if g.phase == "pick" and overlay.get_child_count() > 0:
			await get_tree().create_timer(1.0).timeout
			if g.phase == "pick":
				await _pick(g.offers[0][0])
		if g.phase == "draw" and draw_btn.visible and not _collecting:
			_auto_collect()
		if g.phase == "play" and g.turn == 0 and cam_mode and not view.animating:
			break
	print("ARMA fase=", g.phase, " cam=", cam_mode)
	# mirar hacia las piernas hasta tener la pistola en la mira
	for k in 80:
		var d: Vector2 = view._u(arma.lap.global_position) - Vector2(CX, 180)
		if d.length() < 4.0:
			break
		mover.call(d * 0.8)
		await get_tree().process_frame
	await foto.call("piernas")
	print("ARMA apunta a la pistola: ", arma.apunta_lap(Vector2(CX, 180)))
	var e := InputEventKey.new()
	e.keycode = menus.settings.teclas.usar
	e.pressed = true
	_unhandled_input(e)
	var t1 := Time.get_ticks_msec()
	while view.pie.mode != "de_pie" and Time.get_ticks_msec() - t1 < 6000:
		await get_tree().process_frame
	print("ARMA de pie=", view.pie.mode, " armado=", arma.armado)
	await get_tree().create_timer(0.5).timeout
	await foto.call("en_mano")
	var blanco := func(s: int, punto: Callable) -> void:
		for k in 120:
			var d: Vector2 = view._u(punto.call()) - Vector2(CX, 180)
			if d.length() < 1.5:
				break
			mover.call(d * 0.3)
			await get_tree().process_frame
	# Yeya (silla 1): un tiro apuntando a la cabeza
	raton.call(MOUSE_BUTTON_RIGHT, true)
	await get_tree().create_timer(0.4).timeout
	await blanco.call(1, func(): return view.heads[1].head.global_position)
	await foto.call("apuntando")
	raton.call(MOUSE_BUTTON_LEFT, true)
	await get_tree().create_timer(0.1).timeout
	await foto.call("disparo")
	print("ARMA Yeya muerto=", arma.muerto[1], " vida=", arma.vida[1])
	# Chichí (silla 3): tres al pecho
	for i in 3:
		await blanco.call(3, func(): return view.heads[3].torso.global_transform * Vector3(0, 0.1, 0))
		raton.call(MOUSE_BUTTON_LEFT, true)
		await get_tree().create_timer(0.4).timeout
		print("ARMA Chichí tiro ", i + 1, " vida=", arma.vida[3], " muerto=", arma.muerto[3])
	raton.call(MOUSE_BUTTON_RIGHT, false)
	await get_tree().create_timer(0.6).timeout
	await foto.call("caidos")
	# sentarse (Espacio), matar de nuevo a Yeya no hace falta: sigue tumbada.
	# Juega una ficha con la mira para que le toque a Yeya (silla 1)
	var sp := InputEventKey.new()
	sp.keycode = menus.settings.teclas.pararse
	sp.pressed = true
	_unhandled_input(sp)
	var t2 := Time.get_ticks_msec()
	while not cam_mode and Time.get_ticks_msec() - t2 < 8000:
		await get_tree().process_frame
	print("ARMA sentado cam=", cam_mode, " pistola en piernas=", arma.lap.visible)
	if g.turn == 0 and not g.legal_moves(0).is_empty():
		var i: int = g.hands[0].find(g.legal_moves(0)[0].tile)
		var antes0 := g.chain.size()
		var _sel := await _apuntar_y_e(func(): return view.hand_rects()[i].get_center())
		if selected >= 0 or _cam_hold:
			await _apuntar_y_e(func(): return view._u(Vector3(0, view.TABLE_Y, 0)) if g.chain.is_empty() else view.end_screen_pos(g.legal_moves(0)[0].side))
		await get_tree().create_timer(1.5).timeout
		print("ARMA jugué ficha: ", g.chain.size() > antes0)
	# el turno de un muerto no avanza
	var cad := g.chain.size()
	var turno := g.turn
	await get_tree().create_timer(4.0).timeout
	print("ARMA turno=", turno, " muerto_turno=", arma.muerto[turno], " cadena antes/después ", cad, "/", g.chain.size())
	await get_tree().create_timer(7.0).timeout
	print("ARMA vuelven: Yeya ", arma.muerto[1], " Chichí ", arma.muerto[3], " vida ", arma.vida)
	await foto.call("vuelta")
	get_tree().quit()


## Pruebas: girar la cabeza (modo cámara) hasta el punto y pulsar E.
func _apuntar_y_e(destino: Callable) -> bool:
	for k in 60:
		var d: Vector2 = destino.call() - Vector2(CX, 180)
		if d.length() < 3.0:
			break
		var ev := InputEventMouseMotion.new()
		ev.relative = d * 0.8
		_unhandled_input(ev)
		await get_tree().process_frame
	_usar()
	await get_tree().create_timer(0.3).timeout
	return true


## Prueba visual: una línea con dobles justo donde dobla.
func _prueba_dobles() -> void:
	ui.visible = false
	g.human_pick(g.offers[0][0])
	g.finish_draw(g.auto_picks([]))
	view._shuffled_hand = g.hand_no
	for s in 4:
		g.hands[s] = []
	g.chain = [Vector2i(2, 2), Vector2i(2, 6), Vector2i(6, 6), Vector2i(6, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 3), Vector2i(3, 4), Vector2i(4, 5), Vector2i(5, 5), Vector2i(5, 0), Vector2i(0, 0), Vector2i(0, 4)]
	g.chain[0] = Vector2i(2, 2)
	g.chain[1] = Vector2i(2, 6)
	g.origin = 2
	g.opener = 0
	g.chain[0] = Vector2i(4, 4)
	g.chain[1] = Vector2i(4, 6)
	g.left_end = 4
	g.right_end = 4
	g.turn = 1
	busy = true
	view.set_top(true)
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png("user://prueba_dobles.png")
	get_tree().quit()


## Prueba de interacción: arrastra con el ratón una ficha válida hasta la punta.
func _prueba_arrastre() -> void:
	await get_tree().create_timer(0.5).timeout
	_choose_avatar("tito")
	await get_tree().create_timer(0.3).timeout
	_pick(g.offers[0][0])
	await get_tree().create_timer(2.6).timeout
	_finish_draw_auto()
	var ok := 0
	for intento in 6:
		# esperar a que sea tu turno con jugada posible
		var waited := 0.0
		while not (g.phase == "play" and g.turn == 0 and not busy and not view.animating and not g.legal_moves(0).is_empty()):
			await get_tree().process_frame
			waited += get_process_delta_time()
			if waited > 25.0 or g.phase != "play":
				break
		if g.phase != "play" or g.turn != 0:
			break
		await get_tree().create_timer(0.4).timeout
		while view.hand_rects().size() != g.hands[0].size():
			await get_tree().process_frame
		var m: Dictionary = g.legal_moves(0)[0]
		var i: int = g.hands[0].find(m.tile)
		var from: Vector2 = view.hand_rects()[i].get_center()
		var to: Vector2 = view.end_screen_pos(m.side) if not g.chain.is_empty() else Vector2(CX, 180)
		var before: int = g.chain.size()
		var scale_k: float = DisplayServer.window_get_size().x / W
		_send_mouse(from * scale_k, true)
		for step in 12:
			await get_tree().process_frame
			# con la ficha en la mano, la marca de la punta se coloca para esa ficha
			if not g.chain.is_empty():
				to = view.end_screen_pos(m.side)
			_send_motion(from.lerp(to, (step + 1) / 12.0) * scale_k)
		await get_tree().create_timer(0.1).timeout
		if intento == 0:
			get_viewport().get_texture().get_image().save_png("user://prueba_arrastre_medio.png")
		_send_mouse(to * scale_k, false)
		await get_tree().create_timer(0.2).timeout
		var played: bool = g.chain.size() > before
		print("ARRASTRE intento ", intento, " ficha ", m.tile, " lado ", m.side, " jugada: ", played)
		if not played:
			print("  DEPURAR to=", to, " puntas=", view.end_world.keys(), " izq=", view.end_screen_pos(-1), " der=", view.end_screen_pos(1), " desde=", from, " turno=", g.turn, " fase=", g.phase, " ocupado=", busy, " anim=", view.animating, " eventos_eco=", g.chain.size())
		if played:
			ok += 1
		if intento == 0:
			await get_tree().create_timer(0.1).timeout
			get_viewport().get_texture().get_image().save_png("user://prueba_arrastre_vuelo.png")
	print("ARRASTRE RESULTADO ", ok)
	get_tree().quit()


func _send_mouse(pos: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)


func _send_motion(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)


## Prueba visual: tú y Don Fello bebéis; capturas a mitad del trago.
func _prueba_beber() -> void:
	await get_tree().create_timer(0.5).timeout
	_choose_avatar("nena")
	await get_tree().create_timer(0.2).timeout
	_pick(g.offers[0][0])
	await get_tree().create_timer(2.6).timeout
	_finish_draw_auto()
	await get_tree().create_timer(3.0).timeout
	busy = true
	paused = true
	# Don Fello: dos cafés y un ron (vacíos apilados por tipo y en fila)
	for d in ["cafe", "cafe", "ron"]:
		g.drinks[2] = [d, "agua"]
		await get_tree().create_timer(0.2).timeout
		g.turn = 2   # solo se bebe en tu turno
		g.use_drink(2, d)
		_drain_events()
		if d == "cafe" and view.heads[2].empty_types.is_empty():
			await get_tree().create_timer(0.9).timeout
			get_viewport().get_texture().get_image().save_png("user://beber_fello.png")
		await get_tree().create_timer(2.0).timeout
	get_viewport().get_texture().get_image().save_png("user://beber_fello_despues.png")
	g.drinks[0] = ["ron", "cafe"]
	await get_tree().create_timer(0.3).timeout
	g.turn = 0
	g.use_drink(0, "ron")
	_drain_events()
	await get_tree().create_timer(0.95).timeout
	get_viewport().get_texture().get_image().save_png("user://beber_yo.png")
	await get_tree().create_timer(1.8).timeout
	get_viewport().get_texture().get_image().save_png("user://beber_yo_efecto.png")
	get_tree().quit()


func _prueba_menus() -> void:
	var snap := func(n: String):
		get_viewport().get_texture().get_image().save_png("user://menu_%s.png" % n)
	await get_tree().create_timer(2.0).timeout
	while menus.screen != "inicio":
		await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout
	snap.call("inicio")
	menus.profile["ganadas"] = 7
	menus.open("modos")
	await get_tree().create_timer(2.6).timeout
	snap.call("modos_dibujando")
	await get_tree().create_timer(2.6).timeout
	snap.call("modos")
	menus.open("personaje")
	await get_tree().create_timer(1.8).timeout
	menus._randomize()
	await get_tree().create_timer(1.6).timeout
	snap.call("personaje")
	menus._mirror_tab = "arma"
	menus.profile["pesos"] = maxi(int(menus.profile.get("pesos", 0)), 12)
	menus.open("personaje")
	await get_tree().create_timer(0.8).timeout
	snap.call("personaje_arma")
	menus._mirror_tab = "cuerpo"
	menus.profile.merge({"cuerpo": "mujer", "chain": "bultero", "glasses": "sol", "earrings": "argollas", "lips": "rojos"}, true)
	menus._mirror_tab = "detalles"
	menus.open("personaje")
	view.mirror_react("talk")
	await get_tree().create_timer(0.5).timeout
	snap.call("personaje_detalles")
	for ch in ["chopa", "riquito", "ajentao", "tiguere"]:
		menus.profile.chain = ch
		menus._changed()
		await get_tree().create_timer(0.3).timeout
		snap.call("cadena_" + ch)
	# volver atrás respeta la pantalla de la que vienes
	menus.open("amigos")
	await get_tree().create_timer(0.8).timeout
	menus.open("personaje")
	await get_tree().create_timer(0.8).timeout
	menus._back()
	print("VOLVER desde el espejo: ", menus.screen, " (esperado amigos)")
	menus.open("ajustes")
	await get_tree().create_timer(1.8).timeout
	snap.call("ajustes")
	menus._delete_ask.pressed.emit()  # solo abre la confirmación, no borra nada
	await get_tree().create_timer(0.3).timeout
	snap.call("ajustes_borrar")
	menus.profile.pesos = 500
	menus.open("armario")
	await get_tree().create_timer(1.8).timeout
	snap.call("armario")
	menus._wardrobe_pick("negras", 60)
	menus._tab = "mesa"
	menus._wardrobe_pick("casino", 150)
	menus._tab = "vaso"
	menus._wardrobe_pick("jarrito", 50)
	await get_tree().create_timer(0.8).timeout
	snap.call("armario_comprado")
	menus._tab = "vaso"
	menus.open("armario")
	await get_tree().create_timer(0.6).timeout
	print("VASOS en la pestaña Vasos: ", view.my_glasses.size(), " (esperado 2)")
	snap.call("armario_vasos")
	menus.profile.equip = {"fichas": "marfil", "mesa": "madera", "vaso": "vaso"}
	menus.profile.pesos = 100
	menus.apply_equip()
	menus.open("modos")
	await get_tree().create_timer(2.0).timeout
	menus.close()
	start_game()
	await get_tree().create_timer(1.6).timeout
	snap.call("entrada_mesa")
	toggle_pause()
	await get_tree().create_timer(0.4).timeout
	snap.call("pausa")
	toggle_pause()
	g.stats = {"manos": [4, 2], "dominos": [3, 1], "tranques": [1, 0], "capicuas": [1, 0], "chivos": [0, 1], "bebidas": [3, 4], "max_mano": [41, 30]}
	g.scores = [112, 64]
	g.last_result = {"seat": 0, "team": 0, "pts": 41, "reason": "dominó", "bonus": [], "capicua": false}
	g.phase = "over"
	_refresh()
	await get_tree().create_timer(2.3).timeout
	snap.call("libreta")
	get_tree().quit()


## Prueba online con dos ventanas: una crea la sala (--prueba-sala) y la otra
## entra con el código que deja en user:// (--prueba-sala-unirse). Las dos
## juegan solas a través del servidor y guardan capturas sala_<quien>_*.png.
## Uso (servidor en marcha): dos procesos con --cuenta=A y --cuenta=B.
func _prueba_sala(anfitrion: bool) -> void:
	var quien := "anfitrion" if anfitrion else "amigo"
	var fotos := {}
	var snap := func(n: String):
		if fotos.has(n):
			return
		fotos[n] = true
		get_viewport().get_texture().get_image().save_png("user://sala_%s_%s.png" % [quien, n])
		print("FOTO ", quien, " ", n)
	while menus.screen != "inicio":
		await get_tree().process_frame
	if anfitrion:
		menus.open("personaje")
		await get_tree().create_timer(1.6).timeout
		snap.call("espejo")
	menus.open("modos")
	await get_tree().create_timer(2.5).timeout
	menus.open("amigos")
	await get_tree().create_timer(1.2).timeout
	snap.call("pizarra")
	var look: Dictionary = menus.aspecto()
	if not anfitrion:
		look.merge(View3D.Character.PRESETS["tito"], true)
	var err := ""
	if anfitrion:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://prueba_sala.txt"))
		err = await red.crear_sala("Anfitrión", look)
		var f := FileAccess.open("user://prueba_sala.txt", FileAccess.WRITE)
		f.store_string(red.codigo)
		f.close()
	else:
		var code := ""
		for i in 100:
			if FileAccess.file_exists("user://prueba_sala.txt"):
				code = FileAccess.get_file_as_string("user://prueba_sala.txt").strip_edges()
				if code != "":
					break
			await get_tree().create_timer(0.3).timeout
		await get_tree().create_timer(1.5).timeout
		err = await red.unirse(code, "Amigo", look)
	if err != "":
		print("PRUEBA SALA ERROR: ", err)
		get_tree().quit()
		return
	start_online()
	print("EN LA SALA ", red.codigo, " como ", quien)
	# el anfitrión espera a su amigo y empieza
	var limite := Time.get_ticks_msec() + 300000
	var empezado := false
	while Time.get_ticks_msec() < limite:
		await get_tree().create_timer(0.4).timeout
		var v := online_v
		if v.is_empty():
			continue
		match str(v.get("phase", "")):
			"lobby":
				var humanos := 0
				for st in v.seats:
					if not st.bot:
						humanos += 1
				if humanos == 1 and anfitrion:
					await get_tree().create_timer(1.0).timeout
					snap.call("sola")
				if humanos >= 2:
					await get_tree().create_timer(1.0).timeout
					snap.call("espera")
					if not anfitrion and not fotos.has("frase"):
						red.enviar(Red.OP_FRASE, {"id": "pasate"})
						await get_tree().create_timer(0.5).timeout
						snap.call("frase")
						await get_tree().create_timer(1.0).timeout
					if anfitrion and not empezado:
						empezado = true
						red.enviar(Red.OP_EMPEZAR)
			"pick":
				await get_tree().create_timer(0.8).timeout
				snap.call("carta")
				if not g.offers[0].is_empty() and overlay.get_child_count() > 2:
					_pick(g.offers[0][0])
			"draw":
				if my_picks.size() < 7 and not view.animating:
					var free: Array = range(28).filter(func(x): return not view.pool_taken.has(x))
					if not free.is_empty():
						_draw_pick(free.pick_random())
				if my_picks.size() == 4:
					snap.call("robar")
			"play":
				if g.chain.size() >= 6:
					snap.call("jugando")
				# de pie online: el anfitrión se levanta y pasea; el amigo lo ve
				if anfitrion and g.chain.size() >= 2 and not fotos.has("yo_de_pie") and not view.pie.standing():
					_stand_up()
					await get_tree().create_timer(2.8).timeout
					view.pie.pos = Vector2(1.7, 0.4)
					view.pie.yaw = PI / 2
					_pose_ms = 0
					_send_pose()
					await get_tree().create_timer(1.0).timeout
					snap.call("yo_de_pie")
					_emote("dance")
					await get_tree().create_timer(1.2).timeout
					view.pie.sit_down()
					continue
				if not anfitrion and not fotos.has("otro_de_pie"):
					for k in view.pie.remote:
						if view.pie.remote[k].st == 2 and view.pie.remote[k].k > 0.95:
							await get_tree().create_timer(0.6).timeout
							snap.call("otro_de_pie")
							print("AMIGO VE DE PIE a la silla ", k, " en ", view.pie.remote[k].cur)
							break
				if view.pie.standing():
					continue
				if g.turn == 0 and not view.animating:
					var moves: Array = g.legal_moves(0)
					if not moves.is_empty():
						_act_play(moves[0].tile, moves[0].side)
						await get_tree().create_timer(0.6).timeout
					elif not g.chain.is_empty():
						_pass_button()   # pasar es a mano
						await get_tree().create_timer(0.6).timeout
			"shop":
				await get_tree().create_timer(2.0).timeout
				snap.call("tienda")
				if not v.listos[0]:
					_next_hand()
			"over":
				await get_tree().create_timer(2.5).timeout
				snap.call("final")
				print("PRUEBA SALA TERMINADA ", quien, " marcador ", g.scores)
				get_tree().quit()
				return
	print("PRUEBA SALA TIEMPO AGOTADO ", quien, " fase ", online_v.get("phase", "?"))
	get_tree().quit()


## Fin de partida → «Ver la mesa» → salir al colmado → otra partida.
## Antes se quedaba la interfaz escondida y no se podía seguir jugando.
func _prueba_revision() -> void:
	var snap := func(n: String):
		get_viewport().get_texture().get_image().save_png("user://revision_%s.png" % n)
	await get_tree().create_timer(0.5).timeout
	_choose_avatar("tito")
	_pick(g.offers[0][0])
	await get_tree().create_timer(2.6).timeout
	_finish_draw_auto()
	await get_tree().create_timer(1.0).timeout
	# un doble que no casa no se puede meter de chivo
	var dbl := Vector2i(-1, -1)
	for t in g.hands[g.turn]:
		if t.x == t.y and t.x != g.left_end and t.x != g.right_end:
			dbl = t
	if dbl.x >= 0:
		print("CHIVO DOBLE ACEPTADO: ", g.play_chivo(g.turn, dbl, 1))
	g.last_result = {"seat": 1, "team": 1, "pts": 25, "reason": "chivo", "bonus": [], "capicua": false}
	g.scores = [0, 100]
	g.phase = "over"
	_refresh()
	await get_tree().create_timer(2.3).timeout
	_review_table()
	await get_tree().create_timer(0.5).timeout
	snap.call("barra")
	print("BARRA DENTRO: ", Rect2(0, 0, 640, 360).encloses(_review_bar.get_child(0).get_global_rect()))
	quit_to_menu()
	await get_tree().create_timer(1.0).timeout
	start_game(true)
	await get_tree().create_timer(1.5).timeout
	snap.call("nueva")
	print("NUEVA PARTIDA: overlay visible=", overlay.visible, " hijos=", overlay.get_child_count(), " barra=", is_instance_valid(_review_bar), " fase=", g.phase)
	get_tree().quit()


## Cartas nuevas a la vista: que sus textos quepan en la carta, los pases de
## Ficha marcada en las placas y el aviso de Doble suerte. Guarda
## user://cartas_*.png (probar también con LANG=en_US para el inglés).
func _prueba_cartas() -> void:
	var snap := func(n: String):
		get_viewport().get_texture().get_image().save_png("user://cartas_%s.png" % n)
	await get_tree().create_timer(0.5).timeout
	_choose_avatar("tito")
	g.offers[0] = ["marcada", "suerte", "tranque"]
	ui_phase = ""
	_refresh()
	await get_tree().create_timer(1.5).timeout
	snap.call("elegir")
	_pick("marcada")
	await get_tree().create_timer(2.6).timeout
	_finish_draw_auto()
	await get_tree().create_timer(1.0).timeout
	g.lacks[1] = {2: true, 5: true}
	g.lacks[3] = {0: true, 4: true, 6: true}
	await get_tree().create_timer(0.3).timeout
	snap.call("pases")
	g.events.append({"k": "lucky", "seat": 1})
	_refresh()
	await get_tree().create_timer(0.4).timeout
	snap.call("suerte")
	get_tree().quit()


## Casos extremos de colocación: líneas largas y desequilibradas.
func _prueba_visual() -> void:
	await get_tree().create_timer(0.5).timeout
	_choose_avatar("tito")
	_pick(g.offers[0][0])
	await get_tree().create_timer(2.6).timeout
	_finish_draw_auto()
	await get_tree().create_timer(1.0).timeout
	busy = true
	paused = true  # congela los turnos de los bots durante la prueba
	var all: Array = []
	for a in 7:
		for b in range(a, 7):
			all.append(Vector2i(a, b))
	# tu mano: sale el 6-4, doble 4 en una punta; 6-3 y doble 3 en la otra
	var tu_mano := [Vector2i(3, 3), Vector2i(3, 6), Vector2i(6, 4), Vector2i(4, 4), Vector2i(4, 1)]
	var cases := [["inicio_normal", 5, 2, 0], ["larga", 24, 12, 0], ["un_lado", 20, 2, 1], ["lateral", 22, 11, 3], ["como_tu_partida", 21, 9, 2]]
	for c in cases:
		for k in 4:
			g.hands[k] = all.slice(24, 28) if k == 0 else []
		g.chain = tu_mano.duplicate() if c[0] == "inicio_normal" else all.slice(0, c[1])
		g.origin = c[2]
		g.opener = c[3]
		g.left_end = g.chain[0].x
		g.right_end = g.chain[-1].y
		g.last_seat = 1
		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png("user://visual_%s.png" % c[0])
		view.set_top(true)
		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png("user://visual_%s_arriba.png" % c[0])
		view.set_top(false)
		await get_tree().create_timer(0.6).timeout
	get_tree().quit()


## La cuenta de fin de mano con cada asiento como ganador: capturas normal y
## desde arriba en capturas/cuenta/ (las fichas deben quedar en rejilla).
func _prueba_cuenta() -> void:
	var dir := ProjectSettings.globalize_path("res://capturas/cuenta")
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(0.5).timeout
	_choose_avatar("tito")
	_pick(g.offers[0][0])
	await get_tree().create_timer(2.6).timeout
	_finish_draw_auto()
	await get_tree().create_timer(1.0).timeout
	busy = true
	paused = true
	var guard := 0
	while g.phase == "play" and guard < 300:
		guard += 1
		g.bot_turn()
		g.events.clear()
	_refresh()
	await get_tree().create_timer(2.5).timeout
	for s in 4:
		view.restore_table()
		await get_tree().create_timer(0.8).timeout
		g.last_result.seat = s
		overlay.visible = false
		_clear_overlay()
		view.count_hand(g, false)
		await view.count_done
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png(dir + "/cuenta_%d.png" % s)
		view.set_top(true)
		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png(dir + "/cuenta_%d_arriba.png" % s)
		view.set_top(false)
		await get_tree().create_timer(0.6).timeout
	print("PRUEBA CUENTA TERMINADA")
	get_tree().quit()


func _retratos() -> void:
	ui.visible = false
	for s in [2, 1, 3]:
		var ch: Node3D = view.heads[s]
		var fwd: Vector3 = -ch.global_transform.basis.z
		view.camera.global_position = ch.global_position + fwd * 0.75 + Vector3(0, 0.55, 0)
		view.camera.look_at(ch.global_position + Vector3(0, 0.38, 0))
		await get_tree().create_timer(0.8).timeout
		view.get_viewport().get_texture().get_image().save_png("user://retrato_%d.png" % s)
	get_tree().quit()


# ---------------------------------------------------------------- tema

func _box_style(bg: Color, border: Color, bw := 2, bottom := 0, radius := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	if bottom > 0:
		sb.border_width_bottom = bottom
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	if bottom > 0:
		# relieve: el borde de abajo cambia entre normal (4-6) y pulsado (2); el
		# margen lo compensa para que el botón mida siempre lo mismo (antes
		# encogía al pulsarlo)
		sb.content_margin_bottom = 3 + maxi(0, 6 - bottom)
	sb.anti_aliasing = false
	return sb


func _make_theme() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Verdana", "Tahoma", "Arial"])
	font.font_weight = 800
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.hinting = TextServer.HINTING_LIGHT
	theme_ui = Theme.new()
	theme_ui.default_font = font
	theme_ui.default_font_size = 11
	theme_ui.set_color("font_color", "Label", C_CREAM)
	theme_ui.set_color("font_outline_color", "Label", C_INK)
	theme_ui.set_constant("outline_size", "Label", 3)
	# botones: tabla de madera pintada con relieve
	theme_ui.set_stylebox("normal", "Button", _box_style(C_TURQ, C_INK, 2, 4))
	theme_ui.set_stylebox("hover", "Button", _box_style(C_TURQ.lightened(0.18), C_INK, 2, 4))
	theme_ui.set_stylebox("pressed", "Button", _box_style(C_TURQ.darkened(0.15), C_INK, 2, 2))
	theme_ui.set_stylebox("disabled", "Button", _box_style(Color(0.35, 0.33, 0.3), C_INK, 2, 4))
	theme_ui.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme_ui.set_color("font_color", "Button", C_CREAM)
	theme_ui.set_color("font_hover_color", "Button", Color.WHITE)
	theme_ui.set_color("font_disabled_color", "Button", Color(0.65, 0.62, 0.58))
	theme_ui.set_color("font_outline_color", "Button", C_INK)
	theme_ui.set_constant("outline_size", "Button", 3)
	var sign := _box_style(C_WOOD, C_WOOD_D, 3, 5, 4)
	sign.shadow_color = Color(0, 0, 0, 0.45)
	sign.shadow_size = 4
	sign.shadow_offset = Vector2(0, 3)
	sign.content_margin_left = 10
	sign.content_margin_right = 10
	sign.content_margin_top = 6
	sign.content_margin_bottom = 8
	theme_ui.set_stylebox("panel", "PanelContainer", sign)
	theme_ui.set_color("font_color", "TooltipLabel", C_CREAM)
	theme_ui.set_stylebox("panel", "TooltipPanel", _box_style(C_WOOD_D, C_GOLD, 1))


func _yellow(b: Button) -> Button:
	b.add_theme_stylebox_override("normal", _box_style(C_GOLD, C_INK, 2, 4))
	b.add_theme_stylebox_override("hover", _box_style(C_GOLD.lightened(0.2), C_INK, 2, 4))
	b.add_theme_stylebox_override("pressed", _box_style(C_GOLD.darkened(0.15), C_INK, 2, 2))
	b.add_theme_color_override("font_color", C_INK)
	b.add_theme_color_override("font_hover_color", C_INK)
	b.add_theme_constant_override("outline_size", 0)
	return b


# ---------------------------------------------------------------- iconos pixel

## Traduce la clave original antes de separar el símbolo del texto.
func _symbol_button(button: Button, text: String, values: Array = []) -> void:
	button.set_meta("symbol_key", text)
	button.set_meta("symbol_values", values)
	var symbols := {"💬": "chat", "✋": "pass_hand", "⇧": "stand", "+": "add", "▶": "arrow_right", "▸": "arrow_right", "‹": "arrow_left", "▾": "arrow_down"}
	var translated := tr(text)
	for symbol in symbols:
		if text.contains(symbol):
			button.icon = _icon(symbols[symbol])
			button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT if symbol in ["▶", "▸", "▾", "✋", "⇧"] else HORIZONTAL_ALIGNMENT_LEFT
			translated = translated.replace(symbol, "").strip_edges()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.text = translated
	if not values.is_empty():
		button.text = translated % values
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _translate_symbol_buttons(node: Node) -> void:
	if node is Button and node.has_meta("symbol_key"):
		_symbol_button(node, node.get_meta("symbol_key"), node.get_meta("symbol_values", []))
	for child in node.get_children():
		_translate_symbol_buttons(child)

func _icon(kind: String, col := Color.WHITE) -> ImageTexture:
	var key := kind + col.to_html()
	if _icons.has(key):
		return _icons[key]
	if kind in ["pause", "gear", "play_pause", "previous", "next", "arrow_left", "arrow_right", "arrow_up", "arrow_down", "home", "music", "eye", "tile", "dance", "clap", "point", "wave", "stretch", "choca", "brindis", "sit", "shove", "chat", "pass_hand", "stand", "add", "inicio_jugar", "inicio_sala", "inicio_personaje", "inicio_armario", "inicio_salir"]:
		var asset: String = {"eye": "aumento_info", "tile": "aumento_puntos"}.get(kind, kind)
		var source: Texture2D = load("res://arte/interfaz/%s.png" % asset)
		_icons[key] = ImageTexture.create_from_image(source.get_image())
		return _icons[key]
	if kind == "coin":
		var coin_image: Image = load("res://arte/interfaz/moneda.png").get_image()
		var coin_texture := ImageTexture.create_from_image(coin_image)
		_icons[key] = coin_texture
		return coin_texture
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match kind:
		"glass":
			for y in range(2, 15):
				for x in range(3, 13):
					var edge := x == 3 or x == 12 or y == 14
					img.set_pixel(x, y, C_INK if edge else Color(0.85, 0.95, 1, 0.35))
			for y in range(6, 14):
				for x in range(4, 12):
					img.set_pixel(x, y, col)
			for y in range(6, 13):
				img.set_pixel(5, y, col.lightened(0.4))
			for x in range(4, 12):
				img.set_pixel(x, 6, col.lightened(0.25))
		"tile":
			for y in range(1, 15):
				for x in range(4, 12):
					var edge := x == 4 or x == 11 or y == 1 or y == 14
					img.set_pixel(x, y, C_INK if edge else C_CREAM)
			for x in range(5, 11):
				img.set_pixel(x, 7, C_INK)
			for p in [[6, 3], [9, 5], [6, 10], [9, 10], [6, 12], [9, 12]]:
				img.set_pixel(p[0], p[1], col)
		"eye":
			for x in range(1, 15):
				var h := int(4 - abs(x - 7.5) / 2.0)
				for y in range(8 - h, 8 + h + 1):
					img.set_pixel(x, y, C_CREAM)
				img.set_pixel(x, 8 - h, C_INK)
				img.set_pixel(x, 8 + h, C_INK)
			for y in range(6, 11):
				for x in range(6, 10):
					img.set_pixel(x, y, col)
			img.set_pixel(7, 8, C_INK)
			img.set_pixel(8, 8, C_INK)
		"gear":
			# tuerca de ajustes: corona con 8 dientes y agujero en el centro
			for y in 16:
				for x in 16:
					var v := Vector2(x - 7.5, y - 7.5)
					var d := v.length()
					var tooth: bool = fmod(v.angle() + TAU + PI / 8.0, PI / 4.0) < PI / 8.0
					var outer: float = 7.4 if tooth else 5.6
					if d < outer:
						img.set_pixel(x, y, C_INK)
					if d < outer - 1.1:
						img.set_pixel(x, y, col)
					if d < 2.6:
						img.set_pixel(x, y, C_INK)
					if d < 1.6:
						img.set_pixel(x, y, Color(0, 0, 0, 0))
		"dance", "clap", "point", "wave", "stretch", "shove", "sit", "choca", "brindis":
			_emote_icon(img, kind, col)
		"music":
			# corchea doble para la radio
			for y in range(3, 12):
				img.set_pixel(6, y, col)
				img.set_pixel(12, y - 1, col)
			for x in range(6, 13):
				img.set_pixel(x, 2 + (x - 6) / 6, col)
				img.set_pixel(x, 3 + (x - 6) / 6, col)
			for c in [Vector2(4.5, 12.5), Vector2(10.5, 11.5)]:
				for y in 16:
					for x in 16:
						if Vector2(x - c.x, (y - c.y) * 1.3).length() < 2.3:
							img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_icons[key] = tex
	return tex


## Monigote de 16x16 para cada emote: cabeza, cuerpo y brazos en la pose.
func _emote_icon(img: Image, kind: String, col: Color) -> void:
	var px := func(x: int, y: int):
		if x >= 0 and x < 16 and y >= 0 and y < 16:
			img.set_pixel(x, y, col)
	var line := func(a: Vector2, b: Vector2):
		for k in 13:
			var q := a.lerp(b, k / 12.0)
			px.call(int(round(q.x)), int(round(q.y)))
	var head := func(cx: int, cy: int):
		for y in range(cy - 1, cy + 2):
			for x in range(cx - 1, cx + 2):
				px.call(x, y)
	match kind:
		"dance":
			head.call(8, 2)
			line.call(Vector2(8, 4), Vector2(7, 9))
			line.call(Vector2(8, 5), Vector2(4, 3))     # brazo arriba
			line.call(Vector2(8, 5), Vector2(12, 7))
			line.call(Vector2(7, 9), Vector2(4, 13))
			line.call(Vector2(7, 9), Vector2(11, 12))
			line.call(Vector2(11, 12), Vector2(12, 14))
			px.call(13, 1)                                 # nota musical
			line.call(Vector2(14, 0), Vector2(14, 3))
		"clap":
			# dos manos que chocan con chispas
			for y in range(5, 12):
				px.call(6, y)
				px.call(9, y)
			line.call(Vector2(6, 5), Vector2(7, 4))
			line.call(Vector2(9, 5), Vector2(8, 4))
			line.call(Vector2(5, 12), Vector2(10, 12))
			px.call(3, 3)
			px.call(12, 3)
			px.call(2, 7)
			px.call(13, 7)
		"point":
			head.call(4, 3)
			line.call(Vector2(4, 5), Vector2(4, 11))
			line.call(Vector2(4, 6), Vector2(13, 6))      # brazo señalando
			px.call(14, 5)
			px.call(14, 7)
			line.call(Vector2(4, 11), Vector2(2, 15))
			line.call(Vector2(4, 11), Vector2(6, 15))
		"wave":
			head.call(7, 4)
			line.call(Vector2(7, 6), Vector2(7, 11))
			line.call(Vector2(7, 7), Vector2(11, 3))
			line.call(Vector2(7, 7), Vector2(4, 10))
			px.call(13, 1)
			px.call(13, 4)
			px.call(12, 0)  # movimiento
			line.call(Vector2(7, 11), Vector2(5, 15))
			line.call(Vector2(7, 11), Vector2(9, 15))
		"stretch":
			head.call(8, 5)
			line.call(Vector2(8, 7), Vector2(8, 12))
			line.call(Vector2(8, 7), Vector2(5, 1))
			line.call(Vector2(8, 7), Vector2(11, 1))
			line.call(Vector2(8, 12), Vector2(6, 15))
			line.call(Vector2(8, 12), Vector2(10, 15))
		"shove":
			head.call(4, 4)
			line.call(Vector2(4, 6), Vector2(5, 11))
			line.call(Vector2(4, 7), Vector2(9, 6))
			line.call(Vector2(4, 8), Vector2(9, 8))
			for y in range(3, 12):                          # el otro, que se va
				px.call(12, y)
			line.call(Vector2(12, 3), Vector2(14, 1))
			line.call(Vector2(5, 11), Vector2(2, 15))
			line.call(Vector2(5, 11), Vector2(7, 15))
		"choca":
			# dos manos arriba que chocan, con chispas
			line.call(Vector2(3, 15), Vector2(6, 6))
			line.call(Vector2(13, 15), Vector2(10, 6))
			for y in range(2, 7):
				px.call(6, y)
				px.call(10, y)
			px.call(7, 2)
			px.call(9, 2)
			px.call(8, 0)
			px.call(4, 1)
			px.call(12, 1)
		"brindis":
			# dos vasos que se tocan arriba
			for y in range(4, 11):
				px.call(3 + (10 - y) / 3, y)
				px.call(7 + (10 - y) / 3, y)
				px.call(9 - (10 - y) / 3, y)
				px.call(13 - (10 - y) / 3, y)
			line.call(Vector2(4, 10), Vector2(7, 10))
			line.call(Vector2(9, 10), Vector2(12, 10))
			px.call(8, 1)
			px.call(6, 2)
			px.call(10, 2)
		"sit":
			head.call(6, 2)
			line.call(Vector2(6, 4), Vector2(6, 9))
			line.call(Vector2(6, 9), Vector2(10, 9))
			line.call(Vector2(10, 9), Vector2(10, 14))
			line.call(Vector2(3, 10), Vector2(3, 15))     # silla
			line.call(Vector2(3, 11), Vector2(12, 11))


func _drink_icon(id: String) -> ImageTexture:
	var key := "drink:" + id
	if not _icons.has(key):
		var source: Texture2D = load("res://arte/interfaz/%s.png" % id)
		_icons[key] = ImageTexture.create_from_image(source.get_image())
	return _icons[key]

func _icon_rect(tex: Texture2D, size := 16) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.custom_minimum_size = Vector2(size, size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _card_icon(id: String) -> ImageTexture:
	var kind: String = CARD_KIND[id]
	if kind == "coin":
		return _icon("coin")
	var key := "card:" + kind
	if not _icons.has(key):
		var asset := "aumento_puntos" if kind == "pts" else "aumento_info"
		var source: Texture2D = load("res://arte/interfaz/%s.png" % asset)
		_icons[key] = ImageTexture.create_from_image(source.get_image())
	return _icons[key]

func _card_color(id: String) -> Color:
	return {"pts": C_RED, "coin": Color(0.85, 0.6, 0.1), "info": C_TURQ}[CARD_KIND[id]]


# ---------------------------------------------------------------- HUD

func _ui_minimo(control: Control) -> Vector2:
	if accesibilidad != null:
		accesibilidad._recorrer(control)
	return control.get_combined_minimum_size()

func _key_name(accion: String) -> String:
	return OS.get_keycode_string(menus.settings.teclas[accion] if menus != null else Accesibilidad.TECLAS[accion])

func _lbl(text: Variant = "", size := 10, col := C_CREAM) -> Label:
	var l := Label.new()
	if text is Callable:
		_live_text(l, text)
	else:
		l.text = text
	l.set_meta("a11y_base", size)
	l.add_theme_font_size_override("font_size", roundi(size * (accesibilidad.escala if accesibilidad != null else 1.0)))
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _live_text(control: Control, calcular: Callable) -> void:
	control.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	control.set("text", calcular.call())
	var vivo := preload("res://scripts/texto_vivo.gd").new()
	vivo.calcular = calcular
	control.add_child(vivo)


func _build_hud() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	hud = root
	root.theme = theme_ui
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cam_hint = _lbl("Alt: soltar el ratón", 8, Color(C_CREAM, 0.55))
	_cam_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cam_hint.visible = false
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	root.add_child(_cam_hint)

	# marcador: letrero de madera
	var board := PanelContainer.new()
	board.position = Vector2(6, 6)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(board)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 0)
	board.add_child(bv)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 4)
	bv.add_child(bh)
	score_us = _team_plate(bh, 0, C_TURQ)
	score_them = _team_plate(bh, 1, C_RED)
	meta_lbl = _lbl("", 9, C_GOLD)
	meta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(meta_lbl)

	# monedas y aumentos
	var wallet := PanelContainer.new()
	wallet_panel = wallet
	wallet.mouse_filter = Control.MOUSE_FILTER_PASS
	wallet.position = Vector2(472, 6)
	wallet.custom_minimum_size = Vector2(166, 54)   # sitio para muchas cartas de aumento   # alto fijo: no crece al aparecer las bebidas
	root.add_child(wallet)
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 2)
	wallet.add_child(wv)
	var wh := HBoxContainer.new()
	wh.alignment = BoxContainer.ALIGNMENT_END
	wv.add_child(wh)
	wh.add_child(_icon_rect(_icon("coin"), 14))
	coin_lbl = _lbl("0", 12, C_GOLD)
	wh.add_child(coin_lbl)
	cards_row = HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_END
	cards_row.add_theme_constant_override("separation", 2)
	wv.add_child(cards_row)

	# cartel de turno
	turn_banner = PanelContainer.new()
	turn_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(turn_banner)
	turn_lbl = _lbl("", 11)
	turn_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	turn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_banner.add_child(turn_lbl)

	# placas con nombre sobre cada jugador
	for s in 4:
		var plate := PanelContainer.new()
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_theme_stylebox_override("panel", _box_style(Color(0.12, 0.07, 0.04, 0.8), C_WOOD, 1, 0, 2))
		var l := _lbl(seat_names[s], 9)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # un «Ron» no sale como «Rum»
		plate.add_child(l)
		plate.visible = s != 0
		root.add_child(plate)
		name_plates.append(plate)

	pause_btn = Button.new()
	pause_btn.icon = _icon("pause")
	pause_btn.custom_minimum_size = Vector2(26, 26)
	pause_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pause_btn.tooltip_text = "Pausa (Esc)"
	pause_btn.position = Vector2(612, 8)   # arriba a la derecha (se recoloca en _process)
	pause_btn.pressed.connect(toggle_pause)
	root.add_child(pause_btn)

	# pasar o cantar chivo
	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 4)
	root.add_child(action_box)

	# bebidas y ver mesa
	drink_box = HBoxContainer.new()
	drink_box.position = Vector2(8, 322)
	drink_box.add_theme_constant_override("separation", 4)
	root.add_child(drink_box)
	view_btn = Button.new()
	view_btn.text = "Ver mesa"
	view_btn.icon = _icon("eye", C_TURQ)
	view_btn.position = Vector2(560, 326)
	view_btn.pressed.connect(func(): view.toggle_top(); _refresh())
	root.add_child(view_btn)
	chat_btn = Button.new()
	_symbol_button(chat_btn, "💬")
	chat_btn.tooltip_text = tr("Frases rápidas")
	chat_btn.position = Vector2(522, 326)
	chat_btn.custom_minimum_size = Vector2(32, 26)
	chat_btn.visible = false
	chat_btn.pressed.connect(_toggle_chat)
	root.add_child(chat_btn)

	emote_btn = Button.new()
	emote_btn.icon = _icon("dance", C_CREAM)
	emote_btn.tooltip_text = "Gestos (1-7)"
	emote_btn.custom_minimum_size = Vector2(32, 26)
	emote_btn.expand_icon = true
	emote_btn.visible = false
	emote_btn.pressed.connect(_toggle_emotes)
	root.add_child(emote_btn)

	big_banner = _lbl("", 28, C_GOLD)
	big_banner.add_theme_constant_override("outline_size", 6)
	big_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_banner.size = Vector2(W, 40)
	big_banner.position = Vector2(0, 140)
	big_banner.pivot_offset = Vector2(CX, 20)
	big_banner.visible = false
	root.add_child(big_banner)

	tint = ColorRect.new()
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.color = Color(1, 1, 1, 0)
	root.add_child(tint)
	root.move_child(tint, 0)

	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)

	# recoger las fichas de golpe tras barajar (abajo, centrado)
	draw_btn = _yellow(Button.new())
	draw_btn.text = "RECOGER MIS FICHAS"
	draw_btn.icon = _icon("tile", C_RED)
	draw_btn.add_theme_font_size_override("font_size", 13)
	draw_btn.custom_minimum_size = Vector2(190, 32)
	draw_btn.visible = false
	draw_btn.pressed.connect(_auto_collect)
	root.add_child(draw_btn)
	_build_stand_ui(root)
	# la pausa por encima de todo (también de la elección de aumento): siempre se puede salir
	root.move_child(pause_btn, -1)


## Botón PARARSE y, de pie, la barra con SENTARSE, emotes y EMPUJAR.
func _build_stand_ui(root: Control) -> void:
	stand_btn = Button.new()
	_symbol_button(stand_btn, "PARARSE  ⇧")
	stand_btn.tooltip_text = "Te levantas con tus fichas escondidas"   # I9: el globo largo tapaba el botón
	stand_btn.visible = false
	stand_btn.pressed.connect(_stand_up)
	root.add_child(stand_btn)
	stand_ui = Control.new()
	stand_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	stand_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stand_ui.visible = false
	root.add_child(stand_ui)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	bar.position = Vector2(8, 324)
	stand_ui.add_child(bar)
	sit_btn = _yellow(Button.new())
	sit_btn.custom_minimum_size.y = 28   # mismo alto con o sin icono
	sit_btn.text = "SENTARSE"
	sit_btn.icon = _icon("sit", C_INK)
	sit_btn.tooltip_text = "E"
	sit_btn.pressed.connect(func(): view.pie.sit_down())
	bar.add_child(sit_btn)
	for e in EMOTES:
		var b := Button.new()
		b.icon = _icon(e[0], C_CREAM)
		b.tooltip_text = "%s (%s)" % [tr(e[1]), _key_name("gesto%d" % (EMOTES.find(e) + 1))]
		b.set_meta("gesto", EMOTES.find(e) + 1)
		b.custom_minimum_size = Vector2(30, 28)
		b.expand_icon = true
		var id: String = e[0]
		b.pressed.connect(func(): _emote(id))
		b.mouse_entered.connect(func(): _float(tr(e[1]), b.global_position + Vector2(15, -6), C_CREAM))
		bar.add_child(b)
	shove_btn = Button.new()
	shove_btn.text = "EMPUJAR"
	shove_btn.icon = _icon("shove", C_CREAM)
	shove_btn.add_theme_stylebox_override("normal", _box_style(C_RED, C_INK, 2, 4))
	shove_btn.add_theme_stylebox_override("hover", _box_style(C_RED.lightened(0.2), C_INK, 2, 4))
	shove_btn.position = Vector2(8, 292)
	shove_btn.pressed.connect(func(): _emote("shove"))
	stand_ui.add_child(shove_btn)
	stand_hint = _lbl("", 9, Color(C_CREAM, 0.85))
	stand_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stand_hint.size = Vector2(W, 14)
	stand_hint.position = Vector2(0, 308)
	stand_ui.add_child(stand_hint)
	view.pie.stood_up.connect(func(): sfx.play("knock", -10.0))
	view.pie.pose_changed.connect(_send_pose)
	view.pie.step.connect(func(): sfx.play("step", -12.0, 0.15))
	view.pie.table_bump.connect(func(f: float):
		view.bump_table(f)
		shake = max(shake, 2.0 + f)
		_float("¡Ojo con la mesa!", Vector2(CX, 200), C_CREAM)
		if online:
			red.enviar(Red.OP_EMOTE, {"id": "mesazo"}))
	view.pie.stood_up.connect(_capture_mouse.bind(true))
	# tapar tus fichas cuando alguien se para (online)
	cover_btn = Button.new()
	cover_btn.text = "TAPAR MIS FICHAS"
	cover_btn.visible = false
	cover_btn.pressed.connect(_toggle_cover)
	root.add_child(cover_btn)
	view.pie.sat_down.connect(_on_sat_down)
	view.pie.bumped.connect(_on_bumped)


## Online, sentado: tu cabeza (modo cámara) para que los demás te vean mirar.
var _head_sent := Vector2.ZERO
var _head_ms := 0
func _send_head() -> void:
	if not online or view.pie.mode != "sentado":
		return
	var h: Vector2 = view.seat_look if (playing and not menus.visible) else Vector2.ZERO
	if h.distance_to(_head_sent) < 0.04 or Time.get_ticks_msec() - _head_ms < 150:
		return
	_head_ms = Time.get_ticks_msec()
	_head_sent = h
	red.enviar(Red.OP_POSE, {"st": 0, "hy": snappedf(h.x, 0.01), "hp": snappedf(h.y, 0.01)})


func _send_pose() -> void:
	if not online or not view.pie.standing():
		return
	if Time.get_ticks_msec() - _pose_ms < 100:
		return
	_pose_ms = Time.get_ticks_msec()
	var p: Dictionary = {"st": 2 if view.pie.mode in ["de_pie", "caminando_a_silla", "caido"] else 1}
	if p.st == 2:
		p.a = arma.armado
		p.x = snappedf(view.pie.pos.x, 0.01)
		p.z = snappedf(view.pie.pos.y, 0.01)
		p.yaw = snappedf(view.pie.yaw, 0.01)
		p.p = snappedf(view.pie.pitch, 0.02)   # hacia dónde miras: los demás ven tu cabeza moverse
	red.enviar(Red.OP_POSE, p)


## Online: poses de los demás (de pie, levantándose o sentados) y quién tapó.
func _on_poses(d: Dictionary) -> void:
	if not online:
		return
	var ps: Array = d.get("poses", [])
	var tap: Array = d.get("tapado", [])
	for k in [1, 2, 3]:
		if k < ps.size():
			var q: Dictionary = ps[k]
			view.pie.set_remote(k, int(q.get("st", 0)), Vector2(float(q.get("x", 0)), float(q.get("z", 0))), float(q.get("yaw", 0)), float(q.get("p", 0)), bool(q.get("c", false)))
			if view.heads[k] != null:
				view.heads[k].armado = bool(q.get("a", false)) and int(q.get("st", 0)) == 2
				var de: Array = online_v.get("armas_de", [])
				view.heads[k].arma_tipo = str(de[k]) if k < de.size() and str(de[k]) in arma.ARMAS else "pistola"
				view.heads[k].seat_head = Vector2(float(q.get("hy", 0)), float(q.get("hp", 0))) if int(q.get("st", 0)) == 0 else Vector2.ZERO
		if k < tap.size():
			view.cover_hand(k, bool(tap[k]))
	if tap.size() > 0:
		_my_cover = bool(tap[0])


func _toggle_cover() -> void:
	_my_cover = not _my_cover
	red.enviar(Red.OP_TAPAR, {"on": _my_cover})
	view.cover_hand(0, _my_cover)
	sfx.play("clack", -6.0)


func _stand_up() -> void:
	if view.pie.standing() or not g.phase in ["play", "shop"] or view.animating:
		return
	selected = -1
	view.top_view = false
	view.pie.stand_up()
	view._sig = ""   # tus fichas se van contigo, escondidas
	if g.phase == "play":
		_float("Te paras con tus fichas escondidas…", view.seat_screen_pos(0) + Vector2(0, -40), C_GOLD)
	if online:
		red.enviar(Red.OP_POSE, {"st": 1})
	elif g.phase == "play":
		# los bots se dan cuenta y tapan sus fichas (a veces alguno se descuida)
		for s in [1, 2, 3]:
			var d := randf_range(0.3, 1.9)
			var notices := randf() < 0.85
			get_tree().create_timer(d).timeout.connect(func():
				if not view.pie.standing():
					return
				if notices:
					view.cover_hand(s, true)
					if randf() < 0.5:
						_float(["¡Tapa, tapa!", "¡Ojo, que se paró!", "¿Pa' dónde vas?"].pick_random(), view.seat_screen_pos(s), C_CREAM)
				else:
					view.heads[s].act("laugh"))
	_refresh()


## De pie en PC el ratón se captura: mover el ratón mueve la vista, sin pulsar.
## Tab lo suelta para pulsar botones (y clic en la mesa lo vuelve a capturar).
func _capture_mouse(on: bool) -> void:
	if OS.has_feature("mobile") or autotest:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _on_sat_down() -> void:
	_capture_mouse(false)
	view._sig = ""   # tus fichas vuelven a la bandeja (antes se quedaban invisibles)
	_float("De vuelta en tu silla", view.seat_screen_pos(0) + Vector2(0, -40), C_CREAM)
	if online:
		red.enviar(Red.OP_POSE, {"st": 0})
	else:
		for s in [1, 2, 3]:
			view.cover_hand(s, false)
	_refresh()


func _on_bumped(s: int) -> void:
	view.heads[s].act("stagger")
	# lo empujas tú: se va en la dirección del choque
	var de := Vector3(view.pie.pos.x, view.heads[s].global_position.y, view.pie.pos.y)
	view.heads[s].empujar(view.heads[s].global_position - de, 1.0)
	sfx.play("knock", -4.0)
	shake = max(shake, 2.5)
	_float(["¡Oye, cuidado!", "¡Ey, compai!", "¡Mira por dónde vas!"].pick_random(), view.seat_screen_pos(s), C_CREAM)


## Emote de pie: online lo ven todos; en local, los bots reaccionan.
func _emote(id: String) -> void:
	var near := _nearest_person()
	if id == "shove":
		if near < 0:
			return
		view.heads[near].act("stagger")
		sfx.play("knock", -2.0)
		_float("¡Empujón!", view.seat_screen_pos(near), C_RED.lightened(0.3))
	view.pie.emote(id)
	sfx.play("card", -8.0)
	if id == "choca" and near > 0:
		# chocar manos con quien tienes al lado: los dos a la vez
		get_tree().create_timer(0.3).timeout.connect(func():
			sfx.play("slam", -8.0, 0.1)
			shake = max(shake, 1.5)
			_float("¡Choca esa!", view.seat_screen_pos(near), C_GOLD))
	if online:
		red.enviar(Red.OP_EMOTE, {"id": id, "target": near})
		return
	match id:
		"choca":
			if near > 0:
				view.heads[near].act("choca")
		"brindis":
			# tu compañero te devuelve el brindis (y a veces los rivales también)
			get_tree().create_timer(0.4).timeout.connect(func():
				view.heads[2].act("brindis")
				sfx.play("clink", -4.0, 0.1))
			if randf() < 0.4:
				var r: int = [1, 3].pick_random()
				get_tree().create_timer(0.8).timeout.connect(func(): view.heads[r].act("brindis"))
		"dance":
			for s in [1, 2, 3]:
				get_tree().create_timer(0.3 + s * 0.2).timeout.connect(func(): view.heads[s].act(["laugh", "clap", "dance"].pick_random()))
		"clap":
			view.heads[2].act("thumbs")
		"wave":
			var w: int = [1, 2, 3].pick_random()
			get_tree().create_timer(0.4).timeout.connect(func(): view.heads[w].act("wave"))
		"point":
			var target := _looked_person()
			if target > 0:
				get_tree().create_timer(0.3).timeout.connect(func():
					view.heads[target].act("facepalm")
					_float("¿Qué? ¿Yo?", view.seat_screen_pos(target), C_CREAM))
		"shove":
			if near > 0:
				get_tree().create_timer(0.5).timeout.connect(func(): _float("¡Respeta la mesa!", view.seat_screen_pos(near), C_CREAM))


var _golpe_t := -99.0


## Persona de pie delante de ti y a mano (menos de 0,95 m y de frente) o -1.
func _golpe_target() -> int:
	var pie = view.pie
	var fwd := Vector2(-sin(pie.yaw), -cos(pie.yaw))
	var best := -1
	var bd := 0.95
	for k in pie.remote:
		var r: Dictionary = pie.remote[k]
		if r.st != 2 or r.get("caido", false):
			continue
		var d: Vector2 = r.cur - pie.pos
		if d.length() < bd and d.length() > 0.01 and fwd.angle_to(d.normalized()) < deg_to_rad(55):
			bd = d.length()
			best = k
	return best


## Manotazo cómico (online decide el servidor si cae al suelo).
func _golpe(t: int) -> void:
	if t_anim - _golpe_t < 2.05:   # reloj del juego (como el servidor)
		_float("Espera un poco…", Vector2(CX, 210), Color(C_CREAM, 0.8))
		return
	_golpe_t = t_anim
	view.pie.emote("shove")
	view.fp_punch()
	sfx.play("slam", -6.0, 0.1)
	if online:
		red.enviar(Red.OP_GOLPE, {"target": t, "run": view.pie.vel.length() > 1.2})


## Señalar: tu brazo apunta al punto del colmado al que miras (los demás lo ven).
func _senalar(at: Vector2) -> void:
	var hit: Dictionary = view.aim_point(at)
	if hit.is_empty():
		return
	view.point_marker(hit.pos)
	sfx.play("hover", -6.0)
	if online:
		red.enviar(Red.OP_EMOTE, {"id": "point", "px": snappedf(hit.pos.x, 0.01), "pz": snappedf(hit.pos.z, 0.01), "target": hit.get("seat", -1)})
	elif hit.get("seat", -1) > 0:
		var ts: int = hit.seat
		get_tree().create_timer(0.3).timeout.connect(func():
			view.heads[ts].act("facepalm")
			_float("¿Qué? ¿Yo?", view.seat_screen_pos(ts), C_CREAM))


## Silla de la persona más cercana (a menos de 0,8 m) o -1.
func _nearest_person() -> int:
	var best := -1
	var bd := 0.8
	for s in [1, 2, 3]:
		var d: float = view.pie.pos.distance_to(view.pie.person_pos(s))
		if d < bd:
			bd = d
			best = s
	return best


## A quién miras ahora mismo (el más centrado en pantalla) o -1.
func _looked_person() -> int:
	var best := -1
	var bd := 140.0
	for s in [1, 2, 3]:
		if view.camera.is_position_behind(view.heads[s].global_position):
			continue
		var d: float = view.seat_screen_pos(s).distance_to(Vector2(CX, 180))
		if d < bd:
			bd = d
			best = s
	return best


## Entrada de pie: arrastrar para mirar; en móvil, joystick a la izquierda.
func _stand_input(ev: InputEvent) -> void:
	# con la pistola: clic derecho apunta, clic izquierdo dispara
	if arma.armado and ev is InputEventMouseButton:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if ev.pressed:
				_capture_mouse(true)
			return
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			arma.apuntar(ev.pressed)
			return
		if ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			arma.disparar()
			return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			var chair_xz := Vector2(view.my_chair.global_position.x, view.my_chair.global_position.z)
			if view.pie.mode == "de_pie" and view.pie.pos.distance_to(chair_xz) < CHAIR_REACH and view.chair_hit(ev.position):
				view.pie.sit_down(true)   # tocar tu silla en el móvil
				return
			if ev.position.x < 220 and ev.position.y > 140 and _joy_id == -2:
				_joy_id = ev.index
				_joy_center = ev.position
				_joy_vec = Vector2.ZERO
			elif _look_id == -2:
				_look_id = ev.index
				_look_last = ev.position
		else:
			if ev.index == _joy_id:
				_joy_id = -2
				_joy_vec = Vector2.ZERO
			if ev.index == _look_id:
				_look_id = -2
		return
	if ev is InputEventScreenDrag:
		if ev.index == _joy_id:
			_joy_vec = ((ev.position - _joy_center) / 40.0).limit_length(1.0)
		elif ev.index == _look_id:
			_look_acc += (ev.position - _look_last) * 2.0
			_look_last = ev.position
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_Q:
				if _nearest_person() >= 0:
					_emote("shove")
		return
	# de pie, apuntando a la radio del colmado: cambiarla (la de la sala, online)
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and _radio_aim:
		_tocar_radio()
		return
	# clic en tu silla (resaltada): te sientas; si estás a un paso, vas andando hasta ella
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and _chair_aim:
		view.pie.sit_down(true)
		sfx.play("clack", -8.0)
		return
	# clic izquierdo con el ratón capturado: manotazo a quien tengas delante y
	# cerca (de pie), o señalar el punto al que apuntas
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT 			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and view.pie.mode == "de_pie":
		var t := _golpe_target()
		if t > 0:
			_golpe(t)
		else:
			_senalar(Vector2(CX, 180))
		return
	if ev is InputEventMouseButton and ev.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and view.pie.mode == "de_pie":
		_capture_mouse(true)   # clic en la escena: vuelves a mirar con el ratón
		return
	if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look_acc += ev.relative * 1.6


const TEAM_PLATE_W := 72.0


var _team_titles: Array = [null, null]


## Título de la placa de cada pareja: online, el nombre que le pusieron en la
## sala (O11); si no, NOSOTROS/ELLOS.
func _team_title(team: int) -> String:
	var eq = online_v.get("equipos", []) if online else []
	var nombre: String = str(eq[team]) if eq is Array and team < eq.size() else ""
	if nombre == "":
		nombre = tr("NOSOTROS" if team == 0 else "ELLOS")
	return ("◆ " if team == 0 else "● ") + nombre


func _team_plate(parent: Control, team: int, col: Color) -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box_style(col, C_INK, 2, 3, 2))
	# O11: las dos placas miden siempre lo mismo (antes 72 px contra 62 px
	# según el texto); el título se recorta si no cabe en vez de ensancharla
	p.custom_minimum_size = Vector2(TEAM_PLATE_W, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	p.add_child(v)
	var t := _lbl(func(): return _team_title(team), 8)
	_team_titles[team] = t
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(t)
	var n := _lbl("0", 16)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.pivot_offset = Vector2(28, 10)
	v.add_child(n)
	return n


## Con el texto grande «◆ NOSOTROS» no cabe en la placa: se achica la letra
## (hasta 6 px) en vez de cortarlo con puntos suspensivos.
func _encajar_titulo(t: Label) -> void:
	var esc: float = accesibilidad.escala if accesibilidad != null else 1.0
	var tam := roundi(int(t.get_meta("a11y_base", 8)) * esc)
	var fuente := t.get_theme_font("font")
	while tam > 6 and fuente.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > TEAM_PLATE_W - 14:
		tam -= 1
	if t.get_theme_font_size("font_size") != tam:
		t.add_theme_font_size_override("font_size", tam)


# ---------------------------------------------------------------- bucle

var _ventana_t := 0.0


## O01: --cuadrante=0..3 coloca la ventana en esa cuarta parte de la pantalla
## (las 4 ventanas de prueba quedan en mosaico sin arrastrarlas una a una).
func _colocar_cuadrante() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--cuadrante="):
			continue
		var q := clampi(int(a.trim_prefix("--cuadrante=")), 0, 3)
		var pantalla := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		var tam := Vector2i(pantalla.size.x / 2, pantalla.size.y / 2)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# el borde y la barra de título de Windows van aparte: se resta su tamaño
		var marco := DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
		DisplayServer.window_set_size(tam - marco)
		DisplayServer.window_set_position(pantalla.position + Vector2i((q % 2) * tam.x, (q / 2) * tam.y) + Vector2i(marco.x / 2, marco.y - marco.x / 2))
		return


func _process(delta: float) -> void:
	view.pulse_glasses(playing and _puede_beber())
	t_anim += delta
	# recordar si la ventana está maximizada (una vez por segundo)
	_ventana_t += delta
	if _ventana_t > 1.0 and not autotest and not Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--cuadrante=")):
		_ventana_t = 0.0
		var wm := DisplayServer.window_get_mode()
		var v_now := "max" if wm == DisplayServer.WINDOW_MODE_MAXIMIZED else ("normal" if wm == DisplayServer.WINDOW_MODE_WINDOWED else "")
		if v_now != "" and menus.settings.get("ventana", "") != v_now:
			menus.settings.ventana = v_now
			menus.save()
	shake = max(shake - delta * 18.0, 0.0)
	flash = max(flash - delta * 2.5, 0.0)
	dizzy = max(dizzy - delta, 0.0)
	var sway: float = min(dizzy, 1.0) * 0.02
	var sk: float = shake * shake_mult
	view.camera.h_offset = randf_range(-sk, sk) * 0.002 + sin(t_anim * 1.8) * sway * shake_mult
	view.camera.v_offset = randf_range(-sk, sk) * 0.002 + sin(t_anim * 1.1) * sway * 0.5 * shake_mult
	var my_turn: bool = g.phase == "play" and g.turn == 0 and not autotest and not view.animating
	var legal: Array = g.legal_moves(0).map(func(m): return m.tile) if my_turn else []
	view.set_show_ends(my_turn and selected >= 0)
	var held := selected if selected >= 0 else (_press_i if _dragging else -1)
	if held >= 0 and held < g.hands[0].size():
		view.marker_dbl = g.hands[0][held].x == g.hands[0][held].y
		view.marker_tile = g.hands[0][held]
	view.sync(g, legal, selected, seat_names)
	tiles_cam.global_transform = view.camera.global_transform
	tiles_cam.fov = view.camera.fov
	tiles_cam.h_offset = view.camera.h_offset
	tiles_cam.v_offset = view.camera.v_offset
	# pausa en la esquina de arriba a la derecha y el monedero a su lado: los
	# carteles del centro (turno, «ELIGE UN AUMENTO») ya no quedan debajo
	pause_btn.position = Vector2(W - pause_btn.size.x - 6, 8)
	wallet_panel.position.x = pause_btn.position.x - 4 - wallet_panel.size.x
	var marcador: Control = score_us.get_parent().get_parent().get_parent().get_parent().get_parent()
	var izquierda: float = marcador.position.x + marcador.size.x + 6
	var derecha: float = (wallet_panel.position.x if wallet_panel.visible else pause_btn.position.x) - 6
	# si no cabe en el ancho del cartel (230), se achica la letra antes de crecer
	var tam_turno: int = roundi(int(turn_lbl.get_meta("a11y_base", 11)) * (accesibilidad.escala if accesibilidad != null else 1.0))
	while tam_turno > 8 and turn_lbl.get_theme_font("font").get_string_size(turn_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_turno).x > 214:
		tam_turno -= 1
	if turn_lbl.get_theme_font_size("font_size") != tam_turno:
		turn_lbl.add_theme_font_size_override("font_size", tam_turno)
	var ancho_texto: float = turn_lbl.get_theme_font("font").get_string_size(turn_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, turn_lbl.get_theme_font_size("font_size")).x
	# solo se parte en líneas si de verdad no cabe; si no, sin ajuste: con el
	# ajuste puesto y un ancho medido a 0 (texto recién cambiado) salía letra a letra
	var hueco: float = minf(214.0, maxf(100, derecha - izquierda - 16))   # más largo: dos líneas, no más ancho
	if ancho_texto > hueco:
		turn_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		turn_lbl.custom_minimum_size.x = hueco
	else:
		turn_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		turn_lbl.custom_minimum_size.x = 0
	turn_lbl.size = Vector2.ZERO
	# ancho fijo para los textos de siempre: el cartel no cambia de tamaño con cada aviso
	turn_banner.custom_minimum_size = Vector2(minf(230.0, hueco + 16), 24)
	turn_banner.reset_size()
	turn_banner.position = Vector2(clampf(CX - turn_banner.size.x / 2, izquierda, maxf(izquierda, derecha - turn_banner.size.x)), 8)
	_place_plates()
	view_btn.position = Vector2(W - view_btn.size.x - 6, 360 - view_btn.size.y - 6)
	chat_btn.position = Vector2(view_btn.position.x - chat_btn.size.x - 12, 360 - chat_btn.size.y - 6)
	if g.phase == "lobby":
		chat_btn.position = Vector2(W - chat_btn.size.x - 6, 44)   # en la sala de espera, arriba: no pisa su panel
	# «Ver la mesa»: abajo a la izquierda con su tamaño real (antes se medía
	# antes de tiempo y los botones Volver y Desde arriba quedaban fuera de la pantalla)
	if is_instance_valid(_review_bar):
		_review_bar.reset_size()
		_review_bar.position = Vector2(6, 354 - _review_bar.size.y)
	# las bebidas solo se toman en la mesa: con la tienda o la libreta encima pisaban «Ver la mesa»
	drink_box.visible = false and not is_instance_valid(_review_bar) and not view.pie.standing() and g.phase == "play" and overlay.get_child_count() == 0
	# con la tienda o la libreta abiertas ya está su «Ver la mesa»: no dos botones iguales
	view_btn.visible = (view.top_view or not overlay.visible) and not is_instance_valid(_review_bar) and not view.pie.standing() and not tranque.activo
	# con el tamaño mínimo: recién rehecho, size aún vale 0 y los botones salían un fotograma fuera
	action_box.position = Vector2(W - maxf(action_box.size.x, action_box.get_combined_minimum_size().x) - 8, 236)
	draw_btn.visible = playing and g.phase == "draw" and not view.animating and my_picks.size() < 7 and not _collecting and not paused
	# de pie: caminar (WASD / flechas / joystick) y mirar (arrastrar)
	var standing: bool = view.pie.standing()
	var mv := Vector2.ZERO
	if standing and not paused:
		mv.x = float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
		mv.y = float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
		mv += Vector2(_joy_vec.x, -_joy_vec.y)
	view.pie.running = standing and not paused and (Input.is_key_pressed(KEY_SHIFT) or _joy_vec.length() > 0.97)
	# corriendo, la vista se abre un poco (sensación de velocidad)
	var fov_goal: float = 60.0 if view.pie.running and view.pie.vel.length() > view.pie.SPEED * 1.1 else 54.0
	var in_game: bool = playing and not menus.visible
	if not in_game:
		zoom = 1.0
		view.seat_look = Vector2.ZERO
	fov_goal /= zoom
	if standing or (in_game and not view.top_view):
		view.camera.fov = lerp(view.camera.fov, fov_goal, min(delta * 8.0, 1.0))
	elif view.camera.fov != 54.0:
		view.camera.fov = 54.0
	view.apply_seat_look(in_game and not standing)
	_send_head()
	# con los ajustes abiertos (desde la pausa) la cámara es de los menús
	view.pie.drive_cam = not menus.visible and not arma.yo_muerto
	view.pie.update(delta, mv, _look_acc if not paused else Vector2.ZERO)
	_look_acc = Vector2.ZERO
	# una cuenta cortada a medias (otra mano, «Ver la mesa»…) no deja su
	# «CONTAR TODAS» ni el contador encima de la tienda
	# online la tienda puede llegar mientras aún cuentas: la cuenta acaba sola debajo
	if view.counting and overlay.get_child_count() > 0 and is_instance_valid(_count_ui) and not view.count_remote:
		_count_ui.queue_free()
		view.count_fast = true
	if not view.counting:
		if is_instance_valid(_count_ui):
			_count_ui.queue_free()
		if is_instance_valid(_count_lbl) and not _count_lbl.has_meta("hecho"):
			_count_lbl.queue_free()
	# el ratón solo se queda capturado de pie, sin pausa ni menús (si no, los
	# botones no reciben clics: p. ej. pausar mientras te levantas)
	if _cam_hold and (not cam_mode or g.phase != "play" or g.turn != 0 or view.animating or _press_i < 0 or _press_i >= g.hands[0].size()):
		_cam_devolver()
	var cam_want := _cam_mode_ok()
	if cam_want != cam_mode:
		cam_mode = cam_want
		if view.pie.mode == "sentado":
			_capture_mouse(cam_mode)
		if not cam_mode:
			view.hover_index = -1
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not cam_mode and (not view.pie.standing() or paused or menus.visible or not playing):
		_capture_mouse(false)
	# en PC cada botón enseña su tecla (cambia si la reasignas en Accesibilidad)
	if not OS.has_feature("mobile"):
		var t_rec: String = tr("RECOGER MIS FICHAS") + "  [%s]" % _tecla_txt("recoger")
		if draw_btn.text != t_rec:
			draw_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			draw_btn.text = t_rec
		var t_par: String = tr("PARARSE") + "  [%s]" % _tecla_txt("pararse")
		if stand_btn.text != t_par:
			stand_btn.text = t_par
	if is_instance_valid(_cam_hint):
		_cam_hint.visible = cam_mode and not draw_btn.visible
		var txt_hint: String = (tr("Suelta el clic en una punta · fuera de ella, vuelve a tu mano") if _cam_hold_raton else tr("Clic o %s: soltar en la punta · Clic derecho: devolver") % _tecla_txt("usar")) if _cam_hold else tr("Alt: soltar el ratón")
		if _cam_hint.text != txt_hint:
			_cam_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			_cam_hint.text = txt_hint
			_cam_hint.reset_size()
		_cam_hint.position = Vector2(CX - _cam_hint.size.x / 2, 344)
	# apuntar a tu silla: con el ratón capturado se apunta con el centro de la pantalla
	_chair_aim = false
	if view.pie.mode == "de_pie" and not paused and not menus.visible:
		var aim := Vector2(CX, 180) if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else get_global_mouse_position()
		var chair_xz := Vector2(view.my_chair.global_position.x, view.my_chair.global_position.z)
		_chair_aim = view.pie.pos.distance_to(chair_xz) < CHAIR_REACH and view.chair_hit(aim)
	view.set_chair_glow(_chair_aim)
	_radio_aim = false
	if view.pie.mode == "de_pie" and not paused and not menus.visible and not _chair_aim:
		var aim_r := Vector2(CX, 180) if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else get_global_mouse_position()
		_radio_aim = view.radio_dist() < 1.6 and view.radio_hit(aim_r)
	# Colmadón FM suena más fuerte cerca de la radio
	radio.set_cercania(clampf(1.25 - view.radio_dist() * 0.32, 0.3, 1.0) if playing else 1.0)
	if standing and not g.phase in ["play", "shop"] and view.pie.mode == "de_pie":
		view.pie.sit_down(true)   # empieza otra mano: de vuelta a la silla
	# en la tienda de pie, el panel se esconde (vas al mostrador); sentado vuelve
	if g.phase == "shop" and overlay.get_child_count() > 0 and not is_instance_valid(_review_bar):
		overlay.visible = not standing
	elif not overlay.visible and g.phase != "shop" and not is_instance_valid(_review_bar) and not demo:
		# reglamento: al acabar la tienda, la ventana siguiente (aumentos…) te sale
		# donde estés; antes quedaba escondida si seguías de pie en el mostrador
		overlay.visible = true
		_capture_mouse(false)   # para poder tocar las cartas aunque vengas andando
	_tick_mostrador()
	view.pool_aro_revisar(playing and g.phase == "draw")
	# reglamento: toda espera con segundos enseña la cuenta atrás
	if is_instance_valid(_count_hint) and view.counting and not view.count_fast:
		_count_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_count_hint.text = tr("¡Te toca contar! Toca cada ficha · %d s") % maxi(0, ceili(30.0 - view.count_idle))
	stand_btn.visible = playing and g.phase == "play" and not standing and not view.animating and not view.top_view \
		and not paused and overlay.get_child_count() == 0 and _press_i < 0 and not _dragging and g.revision.is_empty() 		and (not online or online_v.get("de_pie", false))
	emote_btn.visible = playing and g.phase == "play" and not standing and not view.top_view and not paused 		and overlay.get_child_count() == 0 and not view.counting
	if not emote_btn.visible and is_instance_valid(emote_panel):
		emote_panel.queue_free()
	var edge0: float = chat_btn.position.x if chat_btn.visible else view_btn.position.x
	emote_btn.position = Vector2(edge0 - emote_btn.size.x - 6, 360 - emote_btn.size.y - 6)
	# a la derecha, encima de gestos y chat y debajo de ¡CHIVO!/PASO: en la fila de
	# abajo tapaba tus fichas
	stand_btn.size = stand_btn.get_combined_minimum_size()   # con la tecla («[Espacio]») crece: que no se salga
	stand_btn.position = Vector2(W - stand_btn.size.x - 8, emote_btn.position.y - stand_btn.size.y - 6)
	# queda encima de tus vasos: con el puntero sobre uno, el clic es para beber
	var vaso_bajo: int = view.glass_at(_ptr_ui) if stand_btn.visible and not cam_mode else -1
	stand_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE if vaso_bajo >= 0 and view.glass_id(vaso_bajo) != "" else Control.MOUSE_FILTER_STOP
	stand_ui.visible = standing and view.pie.mode == "de_pie" and not paused
	var someone_up := false
	for k in view.pie.remote:
		if view.pie.remote[k].st != 0:
			someone_up = true
	cover_btn.visible = online and playing and g.phase == "play" and not standing and (someone_up or _my_cover)
	cover_btn.text = "DESTAPAR" if _my_cover else "TAPAR MIS FICHAS"
	cover_btn.position = Vector2(CX - cover_btn.size.x / 2, 286)
	if someone_up and not _my_cover and int(t_anim * 2.0) % 2 == 0:
		cover_btn.modulate = Color(1.3, 1.1, 0.8)
	else:
		cover_btn.modulate = Color.WHITE
	shove_btn.visible = _nearest_person() >= 0
	sit_btn.visible = view.pie.near_seat()
	if arma.armado and not OS.has_feature("mobile"):
		stand_hint.text = tr("Clic derecho: apuntar · Clic: disparar · WASD: caminar · %s: sentarse") % _tecla_txt("pararse")
	elif _radio_aim:
		stand_hint.text = tr("Toca la radio: cambiar de pista o apagarla") if OS.has_feature("mobile") else tr("Clic: cambiar la radio")
	elif _chair_aim:
		stand_hint.text = tr("Toca la silla para sentarte") if OS.has_feature("mobile") else tr("Clic: sentarte")
	elif not view.pie.near_seat():
		stand_hint.text = tr("Vuelve a tu silla para sentarte")
	elif OS.has_feature("mobile"):
		stand_hint.text = tr("Joystick: caminar · arrastra: mirar")
	else:
		stand_hint.text = tr("Ratón: mirar · WASD: caminar · Mayús: correr · %s: sentarse · %s: soltar ratón") % [_tecla_txt("pararse"), _tecla_txt("mirar")]
	stand_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stand_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stand_hint.position = Vector2(0, 306)
	stand_hint.size = Vector2((chat_btn.position.x - 10) if chat_btn.visible else 632.0, 14)
	stand_hint.position.y = minf(306, 320 - stand_hint.get_minimum_size().y)
	if is_instance_valid(counter_ui):   # el panel del mostrador ocupa esa franja
		stand_hint.position.y = counter_ui.position.y - 16
	# a la derecha: en el centro tapaba las fichas que vas cogiendo
	draw_btn.size = draw_btn.get_combined_minimum_size()
	draw_btn.position = Vector2(W - draw_btn.size.x - 8, 272)   # encima del chat
	# online: el reloj de la elección del aumento
	# online, sin elegir aumento y casi sin tiempo: se elige uno al azar con su
	# animación (antes el servidor lo elegía y se pasaba directo a barajar)
	if online and g.phase == "pick" and not _picking and not _card_nodes.is_empty() and _deadline_ms > 0 			and _deadline_ms - Time.get_ticks_msec() < 700 and overlay.get_child_count() > 2:
		var ids: Array = _card_nodes.keys().filter(func(k): return is_instance_valid(_card_nodes[k]))
		if not ids.is_empty():
			_float("¡Se acabó el tiempo! Elige el colmadero…", Vector2(CX, 60), C_GOLD)
			_pick(ids.pick_random())
	if is_instance_valid(shop_timer):
		var left2: int = maxi(0, ceili((_deadline_ms - Time.get_ticks_msec()) / 1000.0))
		var listos: int = online_v.get("listos", []).count(true) if online_v.get("listos", []) is Array else 0
		shop_timer.text = tr("La siguiente mano empieza en %d s") % left2 + ("" if listos == 0 else "  ·  " + tr("listos %d de 4") % listos)
		shop_timer.add_theme_color_override("font_color", C_RED.lightened(0.3) if left2 <= 5 else C_GOLD)
	if is_instance_valid(_wait_lbl):
		_update_wait_count()
	if is_instance_valid(pick_timer):
		var left: int = maxi(0, ceili((_deadline_ms - Time.get_ticks_msec()) / 1000.0))
		pick_timer.text = tr("Te quedan %d s para elegir") % left
		pick_timer.add_theme_color_override("font_color", C_RED.lightened(0.3) if left <= 5 else C_GOLD)
	for f in floats:
		f.t += delta
		f.pos.y -= delta * 16.0
	floats = floats.filter(func(f): return f.t < 1.5)
	_send_mano()
	_tick_away()
	_tick_pensada()
	_tick_revision()
	_tick_baile()
	_tick_ojos()
	_drain_events()
	_tick_reloj()
	_tick_consejos()
	_tick_lobby_sillas()
	_tick_peticion()
	if autotest:
		_autotest_step()
	arma.tick(delta)
	if OS.get_cmdline_user_args().has("--revisar-reparto"):
		_revisar_reparto()
	# fuera de la jugada nadie tiene una ficha en la mano: si la mano acababa
	# mientras un bot (o un ausente) jugueteaba, la ficha seguía en su mano
	# todo el reparto siguiente
	# empezó otra mano con la cuenta aún en marcha (online quien ganó puede
	# seguir contando): se corta y la mesa se rehace, sin fichas boca arriba
	if view.counting and g.phase in ["pick", "draw"]:
		view.restore_table()
	if g.phase != "play":
		for k in [1, 2, 3]:
			if view.heads[k] != null and view.heads[k].fiddle != 0:
				view.set_fiddle(k, 0)
				if autotest:
					print("FICHA QUE SE QUEDABA EN LA MANO: silla %d en fase %s" % [k, g.phase])
	if g.phase != "play" and arma.muerto.has(true):
		arma.reiniciar()
	# el turno de quien está tumbado espera a que vuelva a su silla
	if playing and not online and not paused and g.phase == "play" and not busy and not view.animating and not arma.muerto[g.turn]:
		# tú pasas a mano (botón PASO): así los demás saben que no llevas
		if g.turn != 0 or autotest:
			busy = true
			_auto_turn()
	queue_redraw()


func _place_plates() -> void:
	for s in [1, 2, 3]:
		var plate: PanelContainer = name_plates[s]
		var p: Vector2 = view.plate_screen_pos(s)
		var head_pos: Vector3 = view.heads[s].global_position + Vector3(0, 0.78, 0)
		# de pie, quien queda a tu espalda no tiene placa (salía reflejada en pantalla)
		plate.visible = not view.top_view and view.heads[s].visible and not view.camera.is_position_behind(head_pos)
		# fuera de la vista (de pie, mirando a otro lado): sin placa pegada al borde
		if plate.visible and not Rect2(-40, -40, 720, 440).has_point(view.plate_screen_pos(s)):
			plate.visible = false
		if not plate.visible:
			continue
		plate.position = (p - plate.size / 2).clamp(Vector2(4, 36), Vector2(636, 300) - plate.size)
		if turn_banner.visible and Rect2(plate.position, plate.size).intersects(Rect2(turn_banner.position, turn_banner.size)):
			plate.position.y = minf(turn_banner.position.y + turn_banner.size.y + 4, 300 - plate.size.y)
		var away := _away_rect()
		if away.has_area() and Rect2(plate.position, plate.size).intersects(away):
			plate.position.y = minf(away.end.y + 4, 300 - plate.size.y)
		# no tapar el marcador (arriba izquierda) ni el monedero (arriba derecha)
		if plate.position.y < 72 and (plate.position.x < 165 or plate.position.x + plate.size.x > wallet_panel.position.x - 5):
			plate.position.y = 72
		var active: bool = g.phase == "play" and g.turn == s
		var l: Label = plate.get_child(0)
		l.add_theme_color_override("font_color", C_GOLD if active else C_CREAM)
		var txt: String = seat_names[s]
		# ancho reservado para «Nombre · 2 bebidas»: la placa no crece al comprar
		var reserva: String = txt + " · " + tr("%d bebidas") % 2
		var ancho_placa: float = l.get_theme_font("font").get_string_size(reserva, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x + 14
		if absf(plate.custom_minimum_size.x - ancho_placa) > 0.5:
			plate.custom_minimum_size.x = ancho_placa
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if g.drinks[s].size() > 0:
			txt += " · " + (tr("%d bebida") if g.drinks[s].size() == 1 else tr("%d bebidas")) % g.drinks[s].size()
		# Ficha marcada: los números a los que ha pasado cada rival en esta mano
		if s % 2 == 1 and g.phase == "play" and g.has_card(0, "marcada"):
			var nums: Array = g.seen_lacks(0, s).keys()
			if not nums.is_empty():
				nums.sort()
				txt += "\n" + tr("Pasó: %s") % "  ".join(nums.map(func(n): return str(n)))
		l.text = txt
	# dos placas que se montan (dos personas juntas de pie, o de lado): la de
	# más abajo baja lo justo para que se lean las dos
	var vis: Array = name_plates.filter(func(pl): return pl.visible)
	vis.sort_custom(func(a, b): return a.position.y < b.position.y)
	for i in vis.size():
		for j in range(i):
			var a: Control = vis[j]
			var b: Control = vis[i]
			if Rect2(a.position, a.size).intersects(Rect2(b.position, b.size)):
				b.position.y = min(a.position.y + a.size.y + 2, 300 - b.size.y)


## Online: lo que haces con tus fichas en tu turno (mirarlas, una en la mano,
## llevarla a una punta), para que los demás te vean juguetear con ella.
func _send_mano() -> void:
	if online:
		_fiddle_online_bots()
	if not online or not red.en_sala() or not online_v.get("manos", false):
		return
	var st := 0
	var side := 0
	if g.phase == "play" and g.turn != 0 and _dragging and not view.pie.standing():
		st = 2   # F10: reacomodas fuera de tu turno (los demás ven tu mano, sin caras)
	elif g.phase == "play" and g.turn == 0 and not view.pie.standing():
		if _dragging:
			st = 3
			side = _drag_side
		elif selected >= 0:
			st = 2
		elif view.hover_index >= 0:
			st = 1
	var sig := "%d,%d" % [st, side]
	if sig == _mano_sent or Time.get_ticks_msec() - _mano_ms < 90:
		return
	_mano_sent = sig
	_mano_ms = Time.get_ticks_msec()
	red.enviar(Red.OP_MANO, {"st": st, "side": side})


## ¿Tiene el bot 3 o más fichas de un mismo número?
func _bot_pensaria(s: int) -> bool:
	var cuenta := {}
	for t in g.hands[s]:
		for n in ([t.x] if t.x == t.y else [t.x, t.y]):
			cuenta[n] = cuenta.get(n, 0) + 1
	return cuenta.values().any(func(c): return c >= 3)


## La pensada a la vista: tamborilea la mesa y se rasca la cabeza.
func _pensada(s: int) -> void:
	if s < 1 or s > 3 or view.heads[s] == null:
		return
	view.heads[s].act("tap")
	_float(tr("%s se la está pensando…") % seat_names[s], view.seat_screen_pos(s) + Vector2(0, -14), Color(C_CREAM, 0.9))


var _pensada_vista := -1
var _pensada_ms := 0


var counter_ui: PanelContainer
var _counter_sig := ""


## Mostrador: de pie en la tienda y junto al colmadero, le pides las bebidas.
func _tick_mostrador() -> void:
	var cerca: bool = not _tranque_pending and not view.counting and ui_phase == "shop" and overlay.get_child_count() > 0 and g.phase == "shop" and view.pie.mode == "de_pie" and g.mode != "clasico" 		and view.pie.pos.distance_to(view.counter_spot()) < 0.85
	if not cerca:
		if is_instance_valid(counter_ui):
			counter_ui.queue_free()
		_counter_sig = ""
		return
	var sig := str(g.coins[0], g.drinks[0])
	if sig == _counter_sig and is_instance_valid(counter_ui):
		return
	if _counter_sig == "":
		view.colmadero.talk(1.2)
		_float(tr(["¿Qué le sirvo, compai?", "¡Dígame, mi amor!", "¿Lo de siempre?"].pick_random()), Vector2(CX, 120), C_CREAM)
	_counter_sig = sig
	if is_instance_valid(counter_ui):
		counter_ui.queue_free()
	_capture_mouse(false)   # para tocar las bebidas
	counter_ui = PanelContainer.new()
	counter_ui.add_theme_stylebox_override("panel", _box_style(Color(0.12, 0.07, 0.04, 0.92), C_GOLD, 3, 4, 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	counter_ui.add_child(v)
	var t := _lbl(func(): return tr("MOSTRADOR · tienes %d monedas · bebidas %d/%d") % [g.coins[0], g.drinks[0].size(), ColmadoGame.MAX_DRINKS], 11, C_GOLD)
	t.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.add_child(t)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	v.add_child(row)
	for id in ColmadoGame.DRINKS:
		var b := Button.new()
		b.icon = _drink_icon(id)
		b.text = "%s · %d" % [tr(ColmadoGame.DRINKS[id].name), g.drink_cost(0, id)]
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.tooltip_text = tr(ColmadoGame.DRINKS[id].desc)
		b.disabled = not g.can_buy(0, id)
		var did: String = id
		b.pressed.connect(func():
			_buy(did)
			view.colmadero.talk(0.8)
			_float(["¡Aquí tiene!", "¡Bien fría!", "¡Buen provecho!"].pick_random(), Vector2(CX, 120), C_CREAM))
		row.add_child(b)
	var nx := _yellow(Button.new())
	_symbol_button(nx, "SIGUIENTE MANO  ▶")
	nx.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	nx.pressed.connect(func():
		view.pie.sit_down(true)
		_next_hand())
	v.add_child(nx)
	hud.add_child(counter_ui)
	counter_ui.size = counter_ui.get_combined_minimum_size()
	# abajo, justo encima de la barra de gestos: así no tapa la cara del colmadero
	counter_ui.position = Vector2(CX - counter_ui.size.x / 2, 320 - counter_ui.size.y)


var _te_miran := -1


## Online: un ojo sobre quien mira fichas ajenas; si te miran a ti, aviso para tapar.
func _tick_ojos() -> void:
	var me_mira := -1
	for k in [1, 2, 3]:
		var mira := false
		if online and playing and g.phase == "play":
			for s in [0, 1, 2, 3]:
				if view.watching(k, s, _my_cover):
					mira = true
					if s == 0:
						me_mira = k
		view.set_eye(k, mira)
	if me_mira != _te_miran:
		_te_miran = me_mira
		if me_mira > 0:
			_float(tr("¡%s te está mirando las fichas! Tápalas") % seat_names[me_mira], Vector2(CX, 250), C_RED.lightened(0.3))
			sfx.play("knock", -6.0)


var _bailando_antes := 0
var _baile_ms := 0


## Baile en grupo (2026-10-04): si dos o más bailan a la vez y cerca (de pie o
## alrededor de la mesa), arrancan juntos al mismo compás, con confeti.
func _tick_baile() -> void:
	var quien: Array = []   # [silla, posición en el suelo]
	for k in [1, 2, 3]:
		if view.heads[k] != null and view.heads[k]._action == "dance":
			var hp: Vector3 = view.heads[k].global_position
			quien.append([k, Vector2(hp.x, hp.z)])
	if view.pie.emote_bob == "dance":
		quien.append([0, view.pie.pos if view.pie.standing() else Vector2(0, 1.1)])
	var juntos: Array = []
	for a in quien:
		for b in quien:
			if a[0] != b[0] and a[1].distance_to(b[1]) < 2.4:
				if not juntos.has(a[0]):
					juntos.append(a[0])
	if juntos.size() > _bailando_antes and juntos.size() >= 2:
		# alguien se une: todos a empezar juntos
		for k in juntos:
			if k == 0:
				view.pie._emote_t = 0.0
			else:
				view.heads[k]._action_t = 0.0
		if Time.get_ticks_msec() - _baile_ms > 3000:
			_baile_ms = Time.get_ticks_msec()
			_float(tr("¡Baile en grupo! (%d)") % juntos.size(), Vector2(CX, 90), C_GOLD)
			_burst(Vector2(CX, 100), C_GOLD, 40)
			_burst(Vector2(CX, 100), C_TURQ.lightened(0.3), 30)
			sfx.play("aura2", -8.0, 0.0)
	_bailando_antes = juntos.size()


## Online: si una persona tarda más de 8 s en su turno, se ve su pensada (y
## sigue tamborileando cada pocos segundos mientras piensa).
func _tick_pensada() -> void:
	if not online or g.phase != "play" or g.turn == 0 or view.animating:
		_pensada_vista = -1
		return
	var seats: Array = online_v.get("seats", [])
	var s: int = g.turn
	if s >= seats.size() or seats[s].get("bot", true) or seats[s].get("away", false):
		return
	if view.pie.remote.has(s) and view.pie.remote[s].st != 0:
		return
	var pasado: int = Time.get_ticks_msec() - _turno_ms
	if pasado > 8000 and _pensada_vista != _turno_ms:
		_pensada_vista = _turno_ms   # una vez por turno
		_pensada_ms = Time.get_ticks_msec()
		_pensada(s)
	elif _pensada_vista >= 0 and Time.get_ticks_msec() - _pensada_ms > 2600 and view.heads[s]._action == "":
		_pensada_ms = Time.get_ticks_msec()
		view.heads[s].act("tap")


var _turno_visto := -1
var _turno_ms := 0


## Online: los bots (y quien está ausente o sin conexión) no mandan lo que
## hacen con sus fichas: aquí se imita como en la partida local.
func _fiddle_online_bots() -> void:
	if g.phase != "play":
		_turno_visto = -1
		return
	if g.turn != _turno_visto:
		_turno_visto = g.turn
		_turno_ms = Time.get_ticks_msec()
	var seats: Array = online_v.get("seats", [])
	var s: int = g.turn
	if s < 1 or s > 3 or s >= seats.size() or view.animating:
		return
	var st: Dictionary = seats[s]
	if st.get("bot", false) or st.get("away", false) or not st.get("connected", true):
		view.set_fiddle(s, 1 if Time.get_ticks_msec() - _turno_ms < 450 else 2)


func _auto_turn() -> void:
	# los bots juguetean como una persona: miran sus fichas, cogen una y le dan
	# vueltas antes de jugarla (lo mismo que se ve online de un amigo)
	var s: int = g.turn
	if s != 0 and g.phase == "play":
		view.set_fiddle(s, 1)
		var lleva: bool = not g.legal_moves(s).is_empty()
		get_tree().create_timer(randf_range(0.25, 0.4)).timeout.connect(func():
			if g.phase == "play" and g.turn == s and lleva:
				view.set_fiddle(s, 2))
	await get_tree().create_timer(0.65).timeout
	# la pensada (la única seña válida): con 3 o más fichas de un número, a veces
	# el bot tarda un poco más a la vista de todos, para avisar a su compañero
	if s != 0 and g.phase == "play" and g.turn == s and not autotest and _bot_pensaria(s) and randf() < 0.5:
		_pensada(s)
		await get_tree().create_timer(2.2).timeout
	while paused:
		await get_tree().process_frame
	if g.phase == "play" and not view.animating and (g.turn != 0 or autotest):
		g.bot_turn()
	busy = false
	_refresh()


func _drain_events() -> void:
	for e in g.events:
		var p: Vector2 = view.seat_screen_pos(e.seat)
		view.on_event(e)
		view.react(e, g)
		match e.k:
			"pass":
				_float("¡Paso!", p, C_CREAM)
				sfx.play("knock", -2.0)
			"play":
				view.set_aura(0, 0)
				_jerga_jugada(e, p)
			"aura":
				view.set_aura(e.seat, int(e.level))
			"bonus":
				_epic_points(int(e.pts), str(e.get("why", "")), e.seat)
			"revision":
				var acc_r: int = int(e.accused)
				if int(e.seat) == 0:
					_float(tr("Revisas las fichas de %s…") % seat_names[acc_r], Vector2(CX, 56), C_GOLD)
				elif acc_r == 0:
					_float(tr("%s revisa tus fichas…") % seat_names[int(e.seat)], Vector2(CX, 150), C_GOLD)   # I9: ya no pisa el cartel de turno
				else:
					_float(tr("%s revisa las fichas de %s…") % [seat_names[int(e.seat)], seat_names[acc_r]], Vector2(CX, 56), C_CREAM)
			"revision_no":
				if int(e.seat) == 0:
					var rt = e.tile
					var bajo: float = revision_ui.position.y + revision_ui.size.y + 18 if is_instance_valid(revision_ui) else 150.0
					_float(tr("El %s no iba · busca otra") % ("%d-%d" % ([rt[0], rt[1]] if rt is Array else [rt.x, rt.y])), Vector2(CX, bajo), Color(1, 0.6, 0.5))
					sfx.play("knock", -6.0)
					if is_instance_valid(revision_ui):
						var sh := revision_ui.create_tween()
						for k in 3:
							sh.tween_property(revision_ui, "position:x", revision_ui.position.x + 5, 0.04)
							sh.tween_property(revision_ui, "position:x", revision_ui.position.x - 5, 0.04)
						sh.tween_property(revision_ui, "position:x", revision_ui.position.x, 0.04)
			"chivo_caught":
				view.bump_table(1.6)   # F12: el manotazo del que canta hace temblar la mesa
				_float("¡UTE VA!" if e.kind == "pase" else "¡CHIVO CANTADO!", p, C_RED.lightened(0.3))
				if e.kind == "pase" and e.has("tile"):
					var ct = e.tile
					var ctt := "%d-%d" % ([ct[0], ct[1]] if ct is Array else [ct.x, ct.y])
					if e.get("visto", true):
						_float(tr("¡Te cogí! El %s sí iba") % ctt, Vector2(CX, 120), C_GOLD)
					else:
						_float(tr("¡Sí llevaba! Era el %s") % ctt, Vector2(CX, 120), C_GOLD)
				sfx.play("slam", 0.0, 0.0)
				if e.kind == "ficha":
					var bad: Vector2i = e.tile
					get_tree().create_timer(0.2).timeout.connect(func(): view.highlight_chivo(bad))
				else:
					_float("¡Renuncio! Pasó teniendo ficha", view.seat_screen_pos(e.cheater), C_CREAM)
			"chivo_false":
				_float(tr("Falsa alarma · -%d monedas") % ColmadoGame.CHIVO_FALSE_FINE, p, C_CREAM)
				# acusaste de renuncio a quien no llevaba: ves su mano para comprobarlo
				if e.has("accused"):
					var acc: int = e.accused
					_float("No iba: ¡de verdad no llevaba!", view.seat_screen_pos(acc), C_GOLD)
					if e.seat == 0 and e.has("hand"):
						view.reveal_hand(acc, e.hand, 4.5)
			"skip":
				_float("¡Agua fría! Pierde turno", p, Color(0.6, 0.9, 1.0))
			"again":
				_float("Café: ¡otra!", p, C_GOLD)
			"lucky":
				_float("¡Doble suerte!", p, C_GOLD)
			"drink":
				_float(tr("¡%s!") % tr(ColmadoGame.DRINKS[e.id].name), p, DRINK_COLOR[e.id].lightened(0.3))
				if e.id == "ron":
					_float("¡Mano caliente! +50 %", Vector2(CX, 150), C_GOLD)
				_drink_sounds(e.seat, e.id)
			"end":
				var session := _game_session
				var es_tranque: bool = g.last_result.get("reason", "") == "tranque"
				_tranque_pending = es_tranque
				view.set_aura(0, 0)
				if es_tranque:
					# tranque con suspenso: nadie sabe aún quién gana (ni el «+puntos»
					# ni el cartel grande); se revela ficha a ficha en tranque.gd
					shake = 4.0
					get_tree().create_timer(1.2).timeout.connect(func():
						if session == _game_session and playing and g.phase in ["shop", "over"]:
							await tranque.jugar()
							_tranque_pending = false)
					continue
				# V1: un dominó (y su capicúa) se verifica antes de contar
				var verifica: bool = g.last_result.get("reason", "") == "dominó"
				_ver_pending = verifica
				# tras el golpe y voltear las fichas, la pareja ganadora cuenta
				get_tree().create_timer(1.5).timeout.connect(func():
					if verifica and session == _game_session and playing:
						await _verificar(session)
					if session == _game_session and playing and g.phase in ["shop", "over"] and not g.last_result.is_empty() 							and not g.last_result.reason in ["salida", "corrido", "acusado"]:
						# si ganaste tú, las cuentas tú (tocando cada ficha); si no, quien ganó
						var gana := int(g.last_result.seat)
						view.count_hand(g, gana == 0 and not autotest, _cuenta_ajena(gana))
						if _cuenta_ajena(gana):
							_count_ajena_ui(gana))
				shake = 6.0
				flash = 1.0
				view.bump_table(1.2)   # F12: el golpe del dominó mueve las fichas sueltas
				_float("+%d" % e.pts, p, C_GOLD)
				# ganó tu pareja: tu compañero brinda contigo (pulsa 7 para devolvérselo)
				if not online and g.last_result.get("team", 1) == 0:
					get_tree().create_timer(3.3).timeout.connect(func():
						if playing and g.phase in ["shop", "over"]:
							view.heads[2].act("brindis")
							_float("Don Fello brinda contigo · 7: brindar", view.seat_screen_pos(2), C_CREAM))
				_show_big_banner()
				get_tree().create_timer(0.35).timeout.connect(func(): sfx.play("win" if g.last_result.team == 0 else "lose", -4.0, 0.0))
	g.events.clear()


## Clin del vaso, tres tragos y el efecto de la bebida. Si bebes tú, además
## la pantalla toma el color de la bebida.
func _drink_sounds(seat: int, id: String) -> void:
	sfx.play("clink", -6.0)
	for k in 3:
		get_tree().create_timer(0.6 + k * 0.28).timeout.connect(func(): sfx.play("gulp", -4.0, 0.12))
	if id == "cafe":
		get_tree().create_timer(1.9).timeout.connect(func(): sfx.play("steam", -8.0))
	if seat != 0:
		return
	await get_tree().create_timer(1.5).timeout
	var col: Color = {"cafe": Color(1, 0.85, 0.5), "ron": Color(1, 0.55, 0.15), "morir": Color(1, 0.6, 0.7), "agua": Color(0.55, 0.85, 1)}[id]
	tint.color = Color(col, 0.0)
	var tw := create_tween()
	tw.tween_property(tint, "color:a", 0.32, 0.15)
	tw.tween_property(tint, "color:a", 0.0, 1.4 if id != "ron" else 3.0)
	match id:
		"ron":
			dizzy = 3.5
			_float("¡Ay, qué rico!", view.seat_screen_pos(0) + Vector2(0, -30), col)
		"cafe":
			_float("¡Despierto!", view.seat_screen_pos(0) + Vector2(0, -30), col)
		"agua":
			shake = 3.0
			_float("¡Brrr!", view.seat_screen_pos(0) + Vector2(0, -30), col)
		"morir":
			_float("¡Mmm!", view.seat_screen_pos(0) + Vector2(0, -30), col)


func _show_big_banner() -> void:
	var r: Dictionary = g.last_result
	var txt: String = {"dominó": "¡DOMINÓ!", "tranque": "¡TRANQUE!", "chivo": "¡CHIVO CANTADO!", "renuncio": "¡RENUNCIO!",
		"salida": "¡PASE DE SALIDA!", "corrido": "¡PASE CORRIDO!", "acusado": "¡NO IBA!"}.get(r.reason, "¡DOMINÓ!")
	if r.get("capicua", false):
		txt = "¡CAPICÚA!"
	big_banner.text = txt
	big_banner.add_theme_color_override("font_color", C_GOLD if r.team == 0 else C_RED.lightened(0.2))
	big_banner.visible = true
	big_banner.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(big_banner, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(big_banner, "scale", Vector2.ONE, 0.12)
	tw.tween_interval(1.0)
	tw.tween_callback(func(): big_banner.visible = false)


## Jerga del colmado al jugar (confirmado 2026-10-04): «la caja» (doble
## cero), «el burro» (doble seis), «se acostó» (un doble), «la mano» (quien sale).
func _jerga_jugada(e: Dictionary, p: Vector2) -> void:
	if e.get("chivo", false) or not e.has("tile"):
		return
	var t = e.tile
	var a: int = int(t[0]) if t is Array else int(t.x)
	var b: int = int(t[1]) if t is Array else int(t.y)
	var quien: String = tr("Tú") if int(e.seat) == 0 else str(seat_names[int(e.seat)])
	if g.chain.size() == 1:
		_float(tr("%s es la mano") % quien, p + Vector2(0, -14), C_GOLD)
	if a == b and a == 0:
		_float("¡La caja!", p + Vector2(0, 16), C_CREAM)
	elif a == b and a == 6:
		_float("¡El burro!", p + Vector2(0, 16), C_CREAM)
	elif a == b and randf() < 0.45:
		_float(["¡Se acostó!", "Acostao…", "¡Doble pa' la mesa!"].pick_random(), p + Vector2(0, 16), C_CREAM)


var tranque_ui: Control
var tranque: Node   # tranque con suspenso (scripts/tranque.gd)
var arma: Node      # la pistola de tus piernas (scripts/arma.gd)
var _tranque_pending := false
var _ver_pending := false   # V1: verificando el dominó o la capicúa
var _ver_mio := false       # ya diste VISTO (o reclamaste)


## Reglamento V1: al cerrarse la mano en dominó todo se para; se resaltan las
## puntas y la bandeja vacía de quien dominó, y cada uno da VISTO ✓ o RECLAMAR
## (el colmadero vuelve a enseñar la jugada). Reloj de 20 s; luego se cuenta.
func _verificar(session: int) -> void:
	_ver_mio = false
	var capi: bool = g.last_result.get("capicua", false)
	var quien := int(g.last_result.get("seat", 0))
	view.set_show_ends(true)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	box.position = Vector2(CX - 150, 236)   # I9: sobre tu lado de la mesa (vacío tras dominar), sin tapar caras
	box.size = Vector2(300, 80)
	hud.add_child(box)
	var titulo := _lbl("¡CAPICÚA!" if capi else "¡DOMINÓ!", 13, C_GOLD)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_stylebox_override("normal", _fondo_texto())
	box.add_child(titulo)
	var expl: String = tr("Te quedaste sin fichas") if quien == 0 else tr("%s se quedó sin fichas") % seat_names[quien]
	if capi:
		expl += " · " + tr("la última casaba por las dos puntas (%d y %d)") % [g.left_end, g.right_end]
	var l := _lbl(expl, 10, C_CREAM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	l.add_theme_stylebox_override("normal", _fondo_texto())
	box.add_child(l)
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 8)
	box.add_child(fila)
	var visto := Button.new()
	visto.text = tr("VISTO ✓")
	visto.custom_minimum_size = Vector2(104, 26)
	var recl := Button.new()
	recl.text = tr("RECLAMAR")
	recl.custom_minimum_size = Vector2(104, 26)
	fila.add_child(visto)
	fila.add_child(recl)
	var estado := _lbl("", 9, C_CREAM)
	estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	estado.add_theme_stylebox_override("normal", _fondo_texto())
	box.add_child(estado)
	var reclamado := [false]
	visto.pressed.connect(func():
		_ver_mio = true
		visto.disabled = true
		recl.disabled = true
		if online:
			red.enviar(Red.OP_VERIFICAR, {"ok": true}))
	recl.pressed.connect(func():
		_ver_mio = true
		reclamado[0] = true
		visto.disabled = true
		recl.disabled = true
		if online:
			red.enviar(Red.OP_VERIFICAR, {"reclamar": true})
		_ver_reclamo(0))
	var t0 := Time.get_ticks_msec()
	var limite := 20.0
	var auto := autotest or OS.get_cmdline_user_args().has("--recorrido")
	while playing and session == _game_session:
		var pasado := (Time.get_ticks_msec() - t0) / 1000.0
		if auto and not _ver_mio and pasado > 1.0:
			visto.pressed.emit()
		var quedan := ceili(limite - pasado)
		var ver: Dictionary = online_v.get("ver", {}) if online else {}
		if online:
			if online_v.has("ver"):
				quedan = int(ver.get("quedan", quedan))
			elif pasado > 1.5:
				break   # el servidor ya cerró la verificación
			var oks: Array = ver.get("ok", [])
			var marcas: Array = []
			for k in oks.size():
				marcas.append(("✓ " if oks[k] else "… ") + (tr("Tú") if k == 0 else seat_names[k]))
			estado.text = "  ".join(marcas) + " · %d s" % maxi(0, quedan)
		else:
			estado.text = (tr("Visto ✓") if _ver_mio else tr("Compruébalo en la mesa")) + " · %d s" % maxi(0, quedan)
			if _ver_mio and (not reclamado[0] or pasado > 4.0):
				# sin conexión: los bots ya lo vieron; si reclamaste, se ve la revisión
				if not reclamado[0] or pasado > 5.0:
					break
		if pasado > limite + (3.0 if online else 0.0):
			break
		await get_tree().process_frame
	if is_instance_valid(box):
		box.queue_free()
	view.set_show_ends(false)
	_ver_pending = false


## Alguien reclamó: el colmadero señala la mesa y repite por qué vale.
func _ver_reclamo(s: int) -> void:
	view.colmadero.talk(2.0)
	view.colmadero.act("point")
	var capi: bool = g.last_result.get("capicua", false)
	var quien: String = tr("Tú") if s == 0 else seat_names[s]
	_float(tr("%s reclama: el colmadero revisa la mesa…") % quien, Vector2(CX, 172), C_CREAM)
	get_tree().create_timer(2.2).timeout.connect(func():
		if not playing:
			return
		if capi:
			_float(tr("Puntas %d y %d: capicúa buena ✓") % [g.left_end, g.right_end], Vector2(CX, 172), C_GOLD)
		else:
			_float(tr("Bandeja vacía: dominó bueno ✓"), Vector2(CX, 172), C_GOLD))
var _game_session := 0


## Pantalla del tranque (2026-10-05): todos ven la mesa desde arriba con las
## fichas de cada jugador boca arriba (verdes las de la pareja que gana, rojas
## las de la que pierde), los puntos junto a cada mano y la cuenta de las
## parejas. Dura 30 s o hasta que todos la den por vista (online, lo cuenta el
## servidor). Gana la pareja que suma MENOS.
func _tranque_screen(r: Dictionary) -> void:
	var session := _game_session
	var tq: Dictionary = r.tranque
	_float(["¡Se trancó el juego!", "¡Tranque! A contar…", "¡Esto se trancó!"].pick_random(), Vector2(CX, 70), C_GOLD)
	var pips: Array = tq.pips
	var teams: Array = tq.teams
	var us: bool = int(r.team) == 0
	var win_c := Color(0.25, 0.95, 0.35)
	var lose_c := Color(1.0, 0.25, 0.2)
	if accesibilidad.daltonico:
		win_c = Accesibilidad.AZUL
		lose_c = Accesibilidad.NARANJA
	var tint := {}
	for s in 4:
		tint[s] = win_c if (s % 2 == 0) == us else lose_c
	view.show_hands_tinted(true, tint)
	view.set_top(true)
	if is_instance_valid(tranque_ui):
		tranque_ui.queue_free()
	tranque_ui = Control.new()
	tranque_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	tranque_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(tranque_ui)
	sfx.play("knock", -2.0)
	await get_tree().create_timer(0.5).timeout   # la cámara llega arriba
	if session != _game_session:
		return
	if not is_instance_valid(tranque_ui):
		_tranque_pending = false
		return
	# puntos junto a la mano de cada uno
	for s in 4:
		var col: Color = win_c if (s % 2 == 0) == us else lose_c
		var chip := _lbl(("✓ " if (s % 2 == 0) == us else "× ") + str(pips[s]), 18, col.lightened(0.25))
		chip.add_theme_constant_override("outline_size", 6)
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.size = chip.get_combined_minimum_size().max(Vector2(60, 26))
		var at: Vector2 = view.tray_screen_pos(s)
		at += (at - Vector2(CX, 180)).normalized() * 30.0   # por fuera de la mano
		chip.position = (at - chip.size / 2).clamp(Vector2(4, 30), Vector2(636, 326) - chip.size)
		chip.pivot_offset = chip.size / 2
		chip.scale = Vector2.ZERO
		tranque_ui.add_child(chip)
		var ct := chip.create_tween()
		ct.tween_interval(0.25 * s)
		ct.tween_callback(func(): sfx.play("tick", -6.0, 0.0))
		ct.tween_property(chip, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# cuenta de las parejas, a un lado para no tapar la mesa
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box_style(Color(0.12, 0.07, 0.04, 0.92), C_GOLD, 3, 4, 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var title := _lbl(func(): return tr("TRANQUE · nadie puede jugar"), 13, C_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := _lbl(func(): return tr("Gana la pareja que suma MENOS puntos"), 9, Color(C_CREAM, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var names: Array = seat_names
	var l0 := _lbl(func(): return ("✓ " if us else "× ") + tr("Nosotros: %s %d + %s %d = %d") % [tr("Tú"), pips[0], names[2], pips[2], teams[0]], 11, (win_c if us else lose_c).lightened(0.3))
	var l1 := _lbl(func(): return ("× " if us else "✓ ") + tr("Ellos: %s %d + %s %d = %d") % [names[1], pips[1], names[3], pips[3], teams[1]], 11, (lose_c if us else win_c).lightened(0.3))
	for l in [l0, l1]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var win_txt := ""
	if bool(tq.tie):
		var who_open: String = tr("vosotros") if int(tq.opener) % 2 == 0 else tr("ellos")
		win_txt = tr("Empate a %d: gana la pareja que salió (%s)") % [teams[0], who_open]
		if r.get("bonus", []).has("Tranque seguro"):
			win_txt = tr("Empate a %d: ¡Tranque seguro!") % teams[0]
	else:
		win_txt = tr("¡Gana tu pareja!") if us else tr("Ganan los rivales")
	var wl := _lbl("✓ " + win_txt, 13, win_c.lightened(0.3))
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(wl)
	var info := _lbl("", 9, Color(C_CREAM, 0.85))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var ok_btn := _yellow(Button.new())
	ok_btn.text = tr("VISTO")
	v.add_child(ok_btn)
	tranque_ui.add_child(p)
	p.size = p.get_combined_minimum_size()
	# abajo a la izquierda: entre la mano de la izquierda y la tuya no hay fichas
	p.position = Vector2(8, 354 - p.size.y)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_callback(func(): sfx.play("win" if us else "lose", -6.0, 0.0))
	var mine_ok := [false]
	ok_btn.pressed.connect(func():
		if mine_ok[0]:
			return
		mine_ok[0] = true
		ok_btn.disabled = true
		sfx.play("clack", -6.0)
		if online:
			red.enviar(Red.OP_TRANQUE_OK))
	# 30 s o hasta que todos lo den por visto
	var t0 := Time.get_ticks_msec()
	var limit := 1.0 if autotest else 30.0
	while session == _game_session and is_instance_valid(tranque_ui) and playing and g.phase in ["shop", "over"]:
		var left: float = limit - (Time.get_ticks_msec() - t0) / 1000.0
		var oks: Array = online_v.get("tranque_ok", []) if online else []
		var vistos: int = oks.count(true) if online else (1 if mine_ok[0] else 0)
		var total: int = oks.size() if online else 1
		info.text = tr("Vistos %d de %d · %d s") % [vistos, total, maxi(0, ceili(left))]
		if left <= 0.0 or (vistos >= total and total > 0):
			break
		await get_tree().process_frame
	if session != _game_session:
		return
	view.show_hands_tinted(false)
	view.set_top(false)
	if is_instance_valid(tranque_ui):
		var ui := tranque_ui
		var ft := ui.create_tween()
		ft.tween_property(ui, "modulate:a", 0.0, 0.3)
		ft.tween_callback(ui.queue_free)
	await get_tree().create_timer(0.5).timeout   # la cámara vuelve antes de contar
	if session == _game_session:
		_tranque_pending = false


var _auto_wait := 0.0
func _autotest_step() -> void:
	_auto_wait += get_process_delta_time()
	if _auto_wait < 1.6:
		return
	_auto_wait = 0.0
	if demo:
		_demo_step()
		return
	shots += 1
	get_viewport().get_texture().get_image().save_png("user://shot_%02d.png" % shots)
	match g.phase:
		"pick":
			if avatar == "" and shots > 1:
				_choose_avatar("rafa")
			elif shots > 2:
				_pick(g.offers[0][0])
		"draw":
			if not view.animating:
				for k in 7:
					var free: Array = range(28).filter(func(x): return not view.pool_taken.has(x))
					if my_picks.size() < 7 and not free.is_empty():
						_draw_pick(free.pick_random())
		"shop":
			if ui_phase == "shop" and overlay.get_child_count() > 0:
				for d in ["cafe", "agua", "ron"]:
					g.buy(0, d)
				_next_hand()
		"over":
			print("PARTIDA TERMINADA ", g.scores, " manos ", g.hand_no)
			get_tree().quit()


var _demo_game := 1
var _demo_showing := false
const DEMO_SHOW := 4.0   # segundos mirando la mesa al final de cada mano


## Prueba: en cada reparto (desde la 2.ª mano) cuenta las fichas que hay en
## la escena y dónde cuelgan; deberían ser solo las 28 del montón.
var _reparto_visto := -1
var _reparto_t := 0.0
func _revisar_reparto() -> void:
	if g.phase != "draw" or g.hand_no < 2 or _reparto_visto == g.hand_no:
		_reparto_t = 0.0
		return
	_reparto_t += get_process_delta_time()
	if _reparto_t < 3.0:
		return
	_reparto_visto = g.hand_no
	var donde := {}
	var tam := Vector3(view.TW, view.TL, view.TD)
	var pila: Array = [view]
	if view._tiles_host:
		pila.append(view._tiles_host)
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		for c in n.get_children():
			pila.append(c)
		var es_ficha: bool = n is MeshInstance3D and n.mesh is BoxMesh and ((n.mesh as BoxMesh).size.is_equal_approx(tam) or (n.mesh as BoxMesh).size.is_equal_approx(Vector3(0.055, 0.016, 0.11)))
		if es_ficha and n.is_visible_in_tree():
			var raiz: Node = n.get_parent().get_parent()
			var clave := str(raiz.name) if raiz != null else "?"
			if (n.mesh as BoxMesh).size.x < 0.06:
				clave = "en_la_mano"
			donde[clave] = donde.get(clave, 0) + 1
	print("REPARTO mano %d: fichas visibles por sitio %s · manos_root %d · cadena %d" % [g.hand_no, donde, view.hands_root.get_child_count(), view.chain_root.get_child_count()])
	get_viewport().get_texture().get_image().save_png("user://reparto_mano_%d_%d.png" % [g.hand_no, OS.get_process_id()])


func _demo_step() -> void:
	if _demo_showing:
		return
	match g.phase:
		"pick":
			if avatar == "":
				_choose_avatar("rafa")
			else:
				_pick(g.offers[0].pick_random())
		"draw":
			if not view.animating:
				_finish_draw_auto()
		"shop":
			if ui_phase == "shop" and overlay.get_child_count() > 0:
				await _demo_show_table()
				for d in ["cafe", "agua", "ron", "morir"].filter(func(x): return randf() < 0.3):
					g.buy(0, d)
				_next_hand()
		"over":
			if ui_phase == "over" and overlay.get_child_count() > 0:
				await _demo_show_table()
				_demo_game += 1
				_restart()


## Enseña la mesa como quedó (desde tu silla y desde arriba) y guarda las fotos.
func _demo_show_table() -> void:
	_demo_showing = true
	var dir := ProjectSettings.globalize_path("res://capturas/demo")
	DirAccess.make_dir_recursive_absolute(dir)
	if not FileAccess.file_exists(dir + "/.gdignore"):  # que Godot no importe las fotos
		FileAccess.open(dir + "/.gdignore", FileAccess.WRITE).close()
	var id := "p%02d_m%02d" % [_demo_game, g.hand_no]
	view.restore_table()
	overlay.visible = false
	big_banner.visible = false
	var tag := _lbl("FOTO %s · %d fichas en la mesa · %s" % [id, g.chain.size(), g.last_result.get("reason", "")], 11, C_GOLD)
	tag.position = Vector2(10, 340)
	hud.add_child(tag)
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/%s_silla.png" % id)
	view.set_top(true)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/%s_arriba.png" % id)
	print("FOTO ", id, " · fichas ", g.chain.size(), " · ", g.chain)
	await get_tree().create_timer(DEMO_SHOW - 1.0).timeout
	view.set_top(false)
	tag.queue_free()
	overlay.visible = true
	_demo_showing = false


var _epica_hasta_ms := 0


func _float(text: String, pos: Vector2, col: Color) -> void:
	# avisos a la vez en el mismo sitio: el nuevo se apila encima en vez de taparlos
	var p := pos + Vector2(0, -12)
	# el +30 grande ocupa el centro (número y título): los avisos van debajo
	var epica := Time.get_ticks_msec() < _epica_hasta_ms
	if epica and p.y > 95.0 and p.y < 232.0:
		p.y = 240.0
	# con «ESTÁS AUSENTE» arriba, los avisos que caerían encima van debajo
	var away := _away_rect()
	# (pos.y es la línea base y el aviso sube unos 24 px mientras se apaga)
	if away.has_area() and p.y > away.position.y - 4.0 and p.y < away.end.y + 36.0:
		p.y = away.end.y + 36.0
	var paso := 18.0 if epica or away.has_area() else -18.0
	# margen de 0,5 px: con 18 justos el redondeo dejaba 17,9999 y no salía nunca
	var movido := true
	var vueltas := 0
	while movido and vueltas < 32:
		movido = false
		vueltas += 1
		for f in floats:
			if f.t < 1.2 and absf(f.pos.y - p.y) < 17.5 and absf(f.pos.x - p.x) < 200.0:
				p.y = f.pos.y + paso
				movido = true
	floats.append({"text": tr(text), "pos": Vector2(p.x, clampf(p.y, 20.0, 300.0)), "t": 0.0, "col": col})


## Bonus de fin de mano. "Cierre ruidoso +6" es clave tal cual; "Mano ligera −3"
## (local o del servidor) se traduce por su formato "Mano ligera −%d".
func _tr_bonus(b: String) -> String:
	var t := tr(b)
	if t != b:
		return t
	var m := RegEx.create_from_string("^(.*[+−])(\\d+)$").search(b)
	return tr(m.get_string(1) + "%d") % int(m.get_string(2)) if m else b


# ---------------------------------------------------------------- entrada

var _aqui_ms := 0
var away_banner: PanelContainer


## Online ausente: cualquier toque, tecla o movimiento del ratón te devuelve.
var _count_hint: Label = null   # «¡Te toca contar!» con los segundos que quedan
var _ptr_ui := Vector2(-999, -999)   # último puntero (antes de que lo coja un botón)


func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion or ev is InputEventMouseButton:
		_ptr_ui = ev.position
	if accesibilidad != null and accesibilidad.capturar(ev):
		return
	# Tab y otras teclas asignadas deben funcionar aunque un botón tenga foco.
	if accesibilidad != null and playing and not paused and not menus.visible and ev is InputEventKey \
			and ev.pressed and not ev.echo and ev.keycode in menus.settings.teclas.values() \
			and not get_viewport().gui_get_focus_owner() is LineEdit:
		_unhandled_input(ev)
	if not online or not _soy_ausente():
		return
	if ev is InputEventMouseMotion or ev is InputEventMouseButton or ev is InputEventKey or ev is InputEventScreenTouch or ev is InputEventScreenDrag:
		if Time.get_ticks_msec() - _aqui_ms > 1000:
			_aqui_ms = Time.get_ticks_msec()
			red.enviar(Red.OP_AQUI)


func _soy_ausente() -> bool:
	var seats: Array = online_v.get("seats", [])
	return not seats.is_empty() and bool(seats[0].get("away", false))


## Cartel «ESTÁS AUSENTE» arriba en el centro mientras lo estés, solo con la
## mano en juego (O14: ni al elegir aumento ni en la tienda). Va justo debajo
## del cartel de turno y es compacto; las placas y los avisos flotantes se
## apartan de él (O12).
func _tick_away() -> void:
	var ausente: bool = online and playing and _soy_ausente()
	var on: bool = ausente and g.phase in ["play", "draw"]
	if on and not is_instance_valid(away_banner):
		away_banner = PanelContainer.new()
		var sb := _box_style(C_RED, C_INK, 2, 3, 3)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		away_banner.add_theme_stylebox_override("panel", sb)
		away_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := _lbl(func(): return tr("ESTÁS AUSENTE · tus turnos duran 5 s
Toca la pantalla o mueve el ratón para volver"), 9)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		away_banner.add_child(l)
		hud.add_child(away_banner)
	elif not on and is_instance_valid(away_banner):
		away_banner.queue_free()
		away_banner = null
		if not ausente:
			_float("¡De vuelta! Tu turno vuelve a 30 s", Vector2(CX, 70), C_GOLD)
	if is_instance_valid(away_banner):
		away_banner.modulate.a = 1.0
		away_banner.reset_size()
		var arriba: float = turn_banner.position.y + turn_banner.size.y + 4 if turn_banner.visible else 8.0
		away_banner.position = Vector2(CX - away_banner.size.x / 2, arriba)


## Hueco que ocupa el cartel de ausente (vacío si no se ve).
func _away_rect() -> Rect2:
	if is_instance_valid(away_banner) and away_banner.visible:
		return Rect2(away_banner.position, away_banner.size)
	return Rect2()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE and playing and not menus.visible:
		toggle_pause()
		return
	if not playing or paused or menus.visible:
		return
	if ev is InputEventKey:
		if accesibilidad.coincide(ev, "pararse"):
			if view.pie.standing() and view.pie.mode == "de_pie" and not view.pie.near_seat():
				# reglamento P3: lejos de tu silla no te sienta; te avisa
				_float(tr("Vuelve a tu silla para sentarte"), Vector2(CX, 120), C_GOLD)
				sfx.play("knock", -10.0)
			elif view.pie.standing():
				view.pie.sit_down()
			elif stand_btn.visible:
				stand_btn.pressed.emit()
			get_viewport().set_input_as_handled()
			return
		if accesibilidad.coincide(ev, "mirar"):
			if view.pie.standing():
				_capture_mouse(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
			else:
				view_btn.pressed.emit()
			get_viewport().set_input_as_handled()
			return
		if not view.pie.standing():
			if accesibilidad.coincide(ev, "usar"):
				_usar()
				get_viewport().set_input_as_handled()
				return
			if accesibilidad.coincide(ev, "recoger"):
				if draw_btn.visible and not draw_btn.disabled:
					draw_btn.pressed.emit()
				get_viewport().set_input_as_handled()
				return
			for par in [["paso", "paso"], ["cantar", "cantar"]]:
				if accesibilidad.coincide(ev, par[0]):
					for b in action_box.get_children():
						if b is Button and b.get_meta("tecla", "") == par[1] and b.visible and not b.disabled:
							b.pressed.emit()
					get_viewport().set_input_as_handled()
					return
		if accesibilidad.coincide(ev, "chat"):
			if chat_btn.visible:
				chat_btn.pressed.emit()
			get_viewport().set_input_as_handled()
			return
		for i in range(7):
			if accesibilidad.coincide(ev, "gesto%d" % (i + 1)):
				if view.pie.standing():
					_emote(EMOTES[i][0])
				elif emote_btn.visible:
					_seated_emote(EMOTES[i][0])
				get_viewport().set_input_as_handled()
				return
	# rueda: zoom (de pie y sentado)
	if ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom = clampf(zoom * (1.12 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12), 1.0, 2.5)
		return
	if view.pie.standing():
		_stand_input(ev)
		return
	# modo cámara: el ratón gira la cabeza (con el límite del cuello) y lo de
	# abajo resalta o arrastra con la mira del centro; el clic derecho queda
	# para apuntar con el arma
	if cam_mode and ev is InputEventMouseMotion:
		view.seat_look = (view.seat_look + Vector2(-ev.relative.x, -ev.relative.y) * CAM_SENS).clamp(CAM_MIN, CAM_MAX)
	elif cam_mode and ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT:
		if ev.pressed and _cam_hold:
			_cam_devolver()
		return
	# sentado: clic derecho arrastrado = mirar alrededor (el puntero sigue
	# sirviendo para las fichas); un clic derecho sin arrastrar vuelve al centro
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT:
		if ev.pressed:
			_rlook = true
			_rlook_moved = 0.0
		else:
			_rlook = false
			if _rlook_moved < 6.0:
				view.seat_look = Vector2.ZERO
				zoom = 1.0
		return
	if ev is InputEventMouseMotion and _rlook:
		_rlook_moved += ev.relative.length()
		view.seat_look = (view.seat_look + Vector2(-ev.relative.x, -ev.relative.y) * 0.004).clamp(Vector2(-0.9, -0.45), Vector2(0.9, 0.35))
		return
	# tranque: tocar tus fichas para girarlas (derecho: amagar) o las de otro para quitárselas
	if tranque.activo and ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if tranque.clic(_ptr(ev), ev.button_index == MOUSE_BUTTON_RIGHT):
			get_viewport().set_input_as_handled()
		return
	if tranque.activo and ev is InputEventScreenTouch and ev.pressed:
		tranque.clic(ev.position)
		return
	# reglamento C4: durante la cuenta todos miran la mesa, pero pueden girar la
	# cabeza (clic derecho arrastrado, o el ratón en modo cámara)
	if view.counting:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT:
			_rlook = ev.pressed
			return
		if ev is InputEventMouseMotion and (_rlook or cam_mode):
			view.seat_look = (view.seat_look + Vector2(-ev.relative.x, -ev.relative.y) * CAM_SENS).clamp(CAM_MIN, CAM_MAX)
			return
	# durante la cuenta, un toque la acelera
	if view.counting and ((ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed)):
		if view.count_remote:
			# F13: cuenta otra persona; tú puedes coger una ficha para mirarla
			var v: int = view.count_inspect(_ptr(ev))
			if v >= 0:
				_float("%d" % v, _ptr(ev) + Vector2(0, -18), C_CREAM)
			elif v == -1:
				_float("Aún boca abajo", _ptr(ev) + Vector2(0, -18), C_CREAM)
		elif view.count_manual and not view.count_fast:
			if view.count_pick(_ptr(ev)):
				sfx.play("clack", -6.0)
		elif view.count_inspect(_ptr(ev)) == -2:
			view.count_fast = true   # sin tocar ficha: la cuenta de los bots se acelera
		return
	if view.animating or overlay.get_child_count() > 0:
		return
	var p: Vector2 = _ptr(ev) if (ev is InputEventMouse or ev is InputEventScreenTouch or ev is InputEventScreenDrag) else get_global_mouse_position()
	var my_turn: bool = g.phase == "play" and g.turn == 0 and not busy
	if g.phase == "draw":
		if ev is InputEventMouseMotion:
			view.pool_hover(p)
		elif (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			var idx: int = view.pool_tile_at(p)
			if idx >= 0:
				_draw_pick(idx)
		return
	# mover: resaltar ficha o arrastrarla
	if ev is InputEventMouseMotion or ev is InputEventScreenDrag:
		if _press_i >= 0 and (my_turn or _puede_acomodar()):
			if not _dragging and p.distance_to(_press_pos) > 6:
				_dragging = true
				selected = -1
				view.start_drag(_press_i)
				sfx.play("pick", -6.0)
				_refresh()
			if _dragging:
				view.drag_to(p)
				var side := _drop_side(p)
				_drag_side = side if side != 99 else 0
				view.set_hover_side(_drag_side)
		else:
			_glass_hover(p)
			view.hover_index = _tile_at(p) if my_turn and not view.top_view else -1
			if view.hover_index != _last_hover and view.hover_index >= 0:
				sfx.play("hover", -14.0, 0.15)
			_last_hover = view.hover_index
		return
	var pressed: bool = (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed) \
		or (ev is InputEventScreenTouch and ev.pressed)
	var released: bool = (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed) \
		or (ev is InputEventScreenTouch and not ev.pressed)
	if released and _cam_hold:
		# reglamento: mantener y soltar. Si la cogiste con el clic, al soltar el
		# botón se coloca en la punta que apuntas; fuera de una punta vuelve a la mano
		if _cam_hold_raton and not _usando:
			_cam_hold_raton = false
			if _drop_side(p, _press_i) == 99:
				_cam_devolver()
			else:
				_cam_soltar(p)
		return
	if released and _press_i >= 0:
		var i := _press_i
		_press_i = -1
		if _dragging:
			_dragging = false
			var side := _drop_side(p, i) if my_turn else 99
			var slot: int = view.drag_slot
			view.end_drag()
			if side == 99 and slot >= 0 and i < g.hands[0].size():
				_acomodar(i, slot)
			elif side != 99 and my_turn and i < g.hands[0].size():
				var t: Vector2i = g.hands[0][i]
				# la misma regla que el juego: si casa en la punta donde la sueltas
				# es jugada (también con las dos puntas iguales), si no, chivo
				if g.fits(t, side):
					_act_play(t, side)
				elif _act_chivo(t, side):
					_float("Chivo metido… ¿se darán cuenta?", view.seat_screen_pos(0) + Vector2(0, -24), Color(1, 0.6, 0.5))
				elif t.x == t.y:
					_float("Un doble no se puede meter de chivo", view.seat_screen_pos(0), Color(1, 0.55, 0.45))
				else:
					_float("No puedes dominar con chivo", view.seat_screen_pos(0), Color(1, 0.55, 0.45))
			_refresh()
		elif my_turn:
			_click_tile(i)
		return
	if not pressed:
		return
	if _cam_hold:
		_cam_soltar(p)
		return
	if view.top_view:
		view.set_top(false)
		return
	if my_turn and selected >= 0:
		for side in [-1, 1]:
			if p.distance_to(view.end_screen_pos(side)) < 26:
				_play_side(side)
				return
	# la pistola de tus piernas: la coges y te levantas con ella
	if arma.apunta_lap(p):
		arma.coger()
		return
	# la radio del colmado también se toca sentado, si se ve
	if view.radio_hit(p):
		_tocar_radio()
		return
	# beber tocando tu vaso en la mesa (en tu turno)
	var gi: int = view.glass_at(p)
	if gi >= 0:
		if _puede_beber():
			_drink(view.glass_id(gi))
		else:
			_float("Se bebe en tu turno", p, C_CREAM)
		return
	if my_turn or _puede_acomodar():
		var i := _tile_at(p)
		if i >= 0:
			_press_i = i
			_press_pos = p
			if cam_mode and my_turn:
				_cam_coger(i)
			return
	if view.hits_table(p) and selected < 0:
		view.set_top(true)
		return
	selected = -1
	_refresh()


## Dónde apunta el jugador: la mira del centro en el modo cámara, si no el ratón o el dedo.
func _ptr(ev: InputEvent) -> Vector2:
	if cam_mode or not "position" in ev:
		return Vector2(CX, 180)
	return ev.position


## ¿Toca el modo cámara? Solo en PC, sentado y en plena mano (robando o
## jugando), sin menús, tienda, cuenta ni chat delante. Alt lo suelta.
func _cam_mode_ok() -> bool:
	if OS.has_feature("mobile") or autotest or not playing or paused or menus.visible or not menus.settings.get("camara", true) or arma.yo_muerto:
		return false
	if _cam_bloqueado:
		return false
	if view.pie.mode != "sentado" or not g.phase in ["play", "draw"] or view.top_view:
		return false
	# un consejo del colmadero abierto suelta el ratón para poder pulsar «Entendido»
	if overlay.get_child_count() > 0 or tranque.activo or view.counting or is_instance_valid(_review_bar) or is_instance_valid(_consejo_ui):
		return false
	if Input.is_key_pressed(KEY_ALT) or not (DisplayServer.window_is_focused() or OS.get_cmdline_user_args().has("--prueba-camara") or OS.get_cmdline_user_args().has("--prueba-arma") or not _cam_bloqueado and OS.get_cmdline_user_args().has("--recorrido")):
		return false
	if is_instance_valid(chat_panel) and chat_panel.visible:
		return false
	return not get_viewport().gui_get_focus_owner() is LineEdit


## Nombre corto de la tecla de una acción, para enseñarlo en su botón.
func _tecla_txt(accion: String) -> String:
	var k: int = menus.settings.teclas.get(accion, 0)
	return tr("Espacio") if k == KEY_SPACE else OS.get_keycode_string(k)


## Modo cámara: coges la ficha apuntada. Sube a tu mano (tu brazo la lleva)
## y la llevas mirando; los demás ven tu mano con la ficha yendo a esa punta.
func _cam_coger(i: int) -> void:
	_cam_hold = true
	_cam_hold_raton = not _usando
	_dragging = true
	selected = -1
	view.start_drag(i)
	view.drag_to(Vector2(CX, 180))
	sfx.play("pick", -6.0)
	_refresh()


## Sueltas la ficha que llevas: en una punta se juega (o es chivo, como al
## arrastrar); encima de tu bandeja vuelve a la mano; en otro sitio, aviso.
func _cam_soltar(p: Vector2) -> void:
	var i := _press_i
	var side := _drop_side(p, i)
	if side == 99:
		if view.hand_rects().any(func(r: Rect2): return r.grow(14).has_point(p)) or p.y > 300:
			_cam_devolver()
		else:
			_float("Llévala a una punta (o clic derecho para devolverla)", Vector2(CX, 220), C_CREAM)
		return
	_cam_hold = false
	_dragging = false
	_press_i = -1
	view.end_drag()
	if g.phase == "play" and g.turn == 0 and i >= 0 and i < g.hands[0].size():
		var t: Vector2i = g.hands[0][i]
		if g.fits(t, side):
			_act_play(t, side)
		elif _act_chivo(t, side):
			_float("Chivo metido… ¿se darán cuenta?", view.seat_screen_pos(0) + Vector2(0, -24), Color(1, 0.6, 0.5))
		elif t.x == t.y:
			_float("Un doble no se puede meter de chivo", view.seat_screen_pos(0), Color(1, 0.55, 0.45))
		else:
			_float("No puedes dominar con chivo", view.seat_screen_pos(0), Color(1, 0.55, 0.45))
	_refresh()


## La ficha que llevabas vuelve a tu bandeja.
func _cam_devolver() -> void:
	if not _cam_hold:
		return
	_cam_hold = false
	_dragging = false
	_press_i = -1
	view.end_drag()
	sfx.play("clack", -10.0)
	_refresh()


## Tecla «usar»: lo mismo que un clic en la mira (pulsar y soltar).
func _usar() -> void:
	if not cam_mode:
		return
	_usando = true
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = Vector2(CX, 180)
		_unhandled_input(ev)
	_usando = false


## Reglamento F10: fuera de tu turno también puedes reacomodar tu mano (sentado, jugando).
func _puede_acomodar() -> bool:
	return g.phase == "play" and not busy and not cam_mode and not view.top_view and not view.pie.standing()


## Mueve la ficha i al hueco slot de tu bandeja y recuerda el orden elegido.
func _acomodar(i: int, slot: int) -> void:
	var h: Array = g.hands[0]
	var t = h[i]
	h.remove_at(i)
	h.insert(clampi(slot, 0, h.size()), t)
	_mi_orden = h.duplicate()
	sfx.play("clack", -8.0)


## El servidor manda la mano en su orden: se respeta el que tú elegiste.
func _respetar_orden() -> void:
	if _mi_orden.is_empty() or g.hands.is_empty():
		return
	var h: Array = g.hands[0]
	var nuevo: Array = []
	for t in _mi_orden:
		if h.has(t) and not nuevo.has(t):
			nuevo.append(t)
	for t in h:
		if not nuevo.has(t):
			nuevo.append(t)
	g.hands[0] = nuevo
	_mi_orden = nuevo.duplicate()


func _tile_at(p: Vector2) -> int:
	var rects: Array = view.hand_rects()
	for i in rects.size():
		if rects[i].has_point(p):
			return i
	return -1


## Lado donde caería la ficha arrastrada si la sueltas aquí (99 = ninguno).
func _drop_side(p: Vector2, i := -1) -> int:
	if i < 0:
		i = _press_i
	if i < 0 or i >= g.hands[0].size():
		return 99
	var t: Vector2i = g.hands[0][i]
	var moves: Array = g.legal_moves(0).filter(func(m): return m.tile == t)
	if g.chain.is_empty():
		return 0 if not moves.is_empty() and view.hits_table(p) else 99
	# cualquier punta vale: si la ficha no casa, será un chivo
	var best := 99
	var best_d := 46.0
	for side in [-1, 1]:
		var d: float = p.distance_to(view.end_screen_pos(side))
		if d < best_d:
			best_d = d
			best = side
	return best


func _click_tile(i: int) -> void:
	var t: Vector2i = g.hands[0][i]
	var sides: Array = g.legal_moves(0).filter(func(m): return m.tile == t)
	if sides.is_empty():
		_float("No cabe · arrástrala si quieres meter chivo", view.seat_screen_pos(0) + Vector2(0, -20), Color(1, 0.55, 0.45))
		selected = -1
	elif sides.size() == 1:
		selected = -1
		_act_play(t, sides[0].side)
	else:
		selected = -1 if selected == i else i
	_refresh()


func _play_side(side: int) -> void:
	if selected >= 0 and selected < g.hands[0].size():
		var t: Vector2i = g.hands[0][selected]
		selected = -1
		_act_play(t, side)
	_refresh()


# ---------------------------------------------------------------- interfaz

var marcador_tq: Array = []   # tranque: el marcador de antes hasta que se cierra su pantalla


func _refresh() -> void:
	var sc: Array = marcador_tq if marcador_tq.size() == 2 else g.scores
	score_us.text = str(sc[0])
	for team in 2:
		if is_instance_valid(_team_titles[team]):
			_team_titles[team].text = _team_title(team)
			_encajar_titulo(_team_titles[team])
	score_them.text = str(sc[1])
	for team in 2:
		if g.scores[team] != _last_scores[team]:
			var l: Label = score_us if team == 0 else score_them
			var tw := create_tween()
			tw.tween_property(l, "scale", Vector2(1.5, 1.5), 0.12)
			tw.tween_property(l, "scale", Vector2.ONE, 0.2)
	_last_scores = g.scores.duplicate()
	meta_lbl.text = tr("META %d · MANO %d") % [g.target, g.hand_no]
	wallet_panel.visible = g.mode != "clasico"
	coin_lbl.text = str(g.coins[0])
	# solo se rehacen si cambian: borrarlos y crearlos en cada refresco hacía que
	# parpadearan (un fotograma sin botones)
	var sig_cards := str(g.cards[0])
	if sig_cards != _sig_cards:
		_sig_cards = sig_cards
		_rebuild_cards()
	_refresh_buttons()

	# cartel de turno
	turn_banner.visible = g.phase == "play" or g.phase == "draw"
	if g.phase == "draw":
		turn_lbl.text = tr("Elige tus fichas · %d/7") % my_picks.size()
		_turn_base = turn_lbl.text
		_tick_reloj()   # el reloj en el mismo fotograma: antes salía un fotograma sin él (parpadeo)
		turn_lbl.add_theme_color_override("font_color", C_INK)
		turn_lbl.add_theme_constant_override("outline_size", 0)
		turn_banner.add_theme_stylebox_override("panel", _box_style(C_GOLD, C_INK, 2, 3, 3))
	if g.phase == "play":
		var mine: bool = g.turn == 0
		var txt: String = tr("TU TURNO") if mine else tr("Juega %s…") % seat_names[g.turn]
		if mine and g.chain.is_empty() and g.first_hand:
			txt = tr("TU TURNO · sale el doble seis")
		if mine and selected >= 0:
			txt = tr("Toca la punta donde la pones")
		if mine and view.pie.standing():
			txt = tr("¡TE TOCA! Siéntate para jugar")
		if not mine and view.pie.remote.has(g.turn) and view.pie.remote[g.turn].st != 0:
			txt = tr("%s está de pie: espera o siéntalo de un manotazo") % seat_names[g.turn]
		if mine and not view.pie.standing() and not g.chain.is_empty() and g.legal_moves(0).is_empty():
			txt = tr("No llevas: toca PASO (o mete un chivo…)")
		txt = ("▶ " if mine else "● ") + txt
		turn_lbl.text = txt
		_turn_base = txt
		_tick_reloj()
		turn_lbl.add_theme_color_override("font_color", C_INK if mine or accesibilidad.daltonico else C_CREAM)
		turn_lbl.add_theme_constant_override("outline_size", 0 if mine else 3)
		var fondo: Color = (Accesibilidad.AZUL if mine else Accesibilidad.NARANJA) if accesibilidad.daltonico else (C_GOLD if mine else Color(0.12, 0.07, 0.04, 0.85))
		turn_banner.add_theme_stylebox_override("panel", _box_style(fondo, C_INK, 2, 3, 3))

	_tick_reloj()

	if g.phase != ui_phase:
		ui_phase = g.phase
		# O17: «Ver la mesa» (Tu pareja ganó por… · Desde arriba · Volver) es de
		# entre manos: si empieza la siguiente sin pulsar Volver, se cierra
		if is_instance_valid(_review_bar) and not g.phase in ["shop", "over"]:
			_close_review()
		_build_overlay()


var _sig_cards := ""
var _sig_drinks := ""
var _sig_action := ""


func _rebuild_cards() -> void:
	for c in cards_row.get_children():
		c.queue_free()
	for id in g.cards[0]:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", _box_style(_card_color(id), C_INK, 1, 2, 2))
		chip.tooltip_text = "%s: %s" % [tr(ColmadoGame.CARDS[id].name), tr(ColmadoGame.CARDS[id].desc)]
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.add_child(_icon_rect(_card_icon(id), 12))
		cards_row.add_child(chip)


## Bebidas y botones de tu turno: se rehacen solo si cambia lo que muestran.
func _refresh_buttons() -> void:
	view_btn.text = "Volver" if view.top_view else "Ver mesa"
	var can_drink: bool = g.phase == "play" and g.turn == 0 and not busy
	var sig_d := str(g.drinks[0], can_drink)
	var show_act: bool = g.phase == "play" and g.turn == 0 and not busy and not g.chain.is_empty() and not view.pie.standing() and g.revision.is_empty()
	var sig_a := str(show_act, g.last_pass_seat == 3, g.legal_moves(0).is_empty() if show_act else false, g.mode)
	if sig_d != _sig_drinks:
		_sig_drinks = sig_d
		for c in drink_box.get_children():
			c.queue_free()
		for d in g.drinks[0]:
			var b := Button.new()
			b.icon = _drink_icon(d)
			b.text = ColmadoGame.DRINKS[d].name
			b.tooltip_text = ColmadoGame.DRINKS[d].desc
			b.disabled = not (g.phase == "play" and g.turn == 0 and not busy)
			b.pressed.connect(_drink.bind(d))
			drink_box.add_child(b)
	if sig_a != _sig_action:
		_sig_action = sig_a
		for c in action_box.get_children():
			c.queue_free()
		if show_act:
			# el anterior pasó: «¡Ute va!» (renuncio); si puso ficha: «¡Chivo!»
			var after_pass: bool = g.last_pass_seat == 3
			var cb := Button.new()
			cb.text = "¡UTE VA!" if after_pass else "¡CHIVO!"
			if after_pass:
				cb.tooltip_text = tr("¿Crees que pasó teniendo ficha?\nSi es verdad: %s.\nSi no llevaba: ves su mano, pagas %d monedas\ny su pareja gana %d puntos.") % [tr("perdéis la partida" if g.mode == "clasico" else "ganáis la mano"), ColmadoGame.CHIVO_FALSE_FINE, ColmadoGame.PASE_PTS]
			else:
				cb.tooltip_text = tr("Canta si el jugador anterior\nmetió una ficha que no casa.\nSi fallas, pagas %d monedas.") % ColmadoGame.CHIVO_FALSE_FINE
			cb.custom_minimum_size = Vector2(124, 26)   # mismo ancho que PASO con su tecla: no cambia al aparecer
			cb.add_theme_stylebox_override("normal", _box_style(C_RED, C_INK, 2, 4))
			cb.add_theme_stylebox_override("hover", _box_style(C_RED.lightened(0.2), C_INK, 2, 4))
			cb.pressed.connect(_call_chivo)
			cb.set_meta("tecla", "cantar")
			if not OS.has_feature("mobile"):
				cb.text = tr(cb.text) + "  [%s]" % _tecla_txt("cantar")
				cb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			action_box.add_child(cb)
			if after_pass:
				cb.pivot_offset = Vector2(62, 13)
				var tw := cb.create_tween().set_loops(3)
				tw.tween_property(cb, "scale", Vector2(1.08, 1.08), 0.18)
				tw.tween_property(cb, "scale", Vector2.ONE, 0.18)
			# PASO: tocar la mesa. Pasar teniendo ficha es renuncio (te pueden cantar «¡Ute va!»)
			var none: bool = g.legal_moves(0).is_empty()
			var pb := _yellow(Button.new()) if none else Button.new()
			_symbol_button(pb, "PASO  ✋")
			pb.tooltip_text = "No llevo: toco la mesa." if none else tr("¡Ojo! Llevas ficha: pasar así es renuncio.\nSi el siguiente te canta «¡Ute va!»,\n%s.") % tr("perdéis la partida" if g.mode == "clasico" else "perdéis la mano")
			pb.custom_minimum_size = Vector2(124, 30 if none else 24)
			pb.add_theme_font_size_override("font_size", 13 if none else 11)
			pb.pressed.connect(_pass_button)
			pb.set_meta("tecla", "paso")
			if not OS.has_feature("mobile"):
				pb.text += "  [%s]" % _tecla_txt("paso")
			action_box.add_child(pb)


func _call_chivo() -> void:
	sfx.play("knock", 0.0, 0.0)
	var ute: bool = g.last_pass_seat == 3
	_float("¡UTE VA!" if ute else "¡CHIVO!", view.seat_screen_pos(0) + Vector2(0, -30), C_RED.lightened(0.3))
	if online:
		red.enviar(Red.OP_CANTAR)
	else:
		g.call_chivo(0, ute)   # «¡Ute va!»: primero revisas sus fichas
	_refresh()


# ---------------------------------------------------------------- «¡Ute va!»: revisar las fichas

var revision_ui: PanelContainer
var _rev_t0 := 0
var _rev_lbl: Label
const REVISION_SECS := 25


## ¿Estás revisando ahora las fichas de quien pasó? Devuelve la silla acusada o -1.
func _revisando() -> int:
	var r: Dictionary = g.revision
	if r.is_empty() or int(r.get("caller", -1)) != 0 or g.phase != "play":
		return -1
	return int(r.accused)


## Panel de la revisión (2026-10-04): las fichas de quien pasó se dan la vuelta
## para ti; eliges la que SÍ iba o «No llevaba». Manda la verdad.
func _tick_revision() -> void:
	var acc := _revisando()
	if acc < 0:
		if is_instance_valid(revision_ui):
			revision_ui.queue_free()
		return
	var left: int = REVISION_SECS - (Time.get_ticks_msec() - _rev_t0) / 1000
	if online and g.revision.has("secs"):
		left = maxi(0, ceili((_deadline_rev_ms - Time.get_ticks_msec()) / 1000.0))
	if not is_instance_valid(revision_ui):
		_build_revision(acc)
	if is_instance_valid(_rev_lbl):
		_rev_lbl.text = tr("Te quedan %d s") % maxi(left, 0)
	# en local se acaba el tiempo: decide la verdad
	if not online and left <= 0:
		_revisar(Vector2i(-1, -1), true)


var _deadline_rev_ms := 0


func _build_revision(acc: int) -> void:
	_rev_t0 = Time.get_ticks_msec()
	var hand: Array = g.hands[acc].filter(func(t): return t.x >= 0)
	view.reveal_hand(acc, hand, REVISION_SECS + 1.0)
	sfx.play("card", -4.0)
	revision_ui = PanelContainer.new()
	revision_ui.add_theme_stylebox_override("panel", _box_style(Color(0.12, 0.07, 0.04, 0.94), C_RED, 3, 4, 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	revision_ui.add_child(v)
	var t := _lbl(func(): return tr("¡UTE VA! Revisa las fichas de %s") % seat_names[acc], 13, C_GOLD)
	t.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var ends := _lbl(func(): return tr("En la mesa: %d y %d · toca la que SÍ iba") % [g.left_end, g.right_end], 10, C_CREAM)
	ends.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	ends.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ends)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	v.add_child(row)
	for tile in hand:
		var b := Button.new()
		b.icon = view._tile_tex(tile)
		b.expand_icon = true
		b.custom_minimum_size = Vector2(26, 46)
		b.tooltip_text = "%d-%d" % [tile.x, tile.y]
		var tt: Vector2i = tile
		b.pressed.connect(func(): _revisar(tt))
		row.add_child(b)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var none := Button.new()
	none.text = "NO LLEVABA"
	none.tooltip_text = "Confirmas que no tenía ninguna que fuera (si sí llevaba el juego te la enseña)"
	none.pressed.connect(func(): _revisar(Vector2i(-1, -1), true))
	h.add_child(none)
	_rev_lbl = _lbl("", 10, C_GOLD)
	h.add_child(_rev_lbl)
	hud.add_child(revision_ui)
	revision_ui.size = revision_ui.get_combined_minimum_size()
	revision_ui.position = Vector2(CX - revision_ui.size.x / 2, 70)


func _revisar(tile: Vector2i, none := false) -> void:
	if _revisando() < 0:
		return
	sfx.play("clack", -4.0)
	if online:
		red.enviar(Red.OP_REVISAR, {"none": true} if none else {"tile": [tile.x, tile.y]})
		return
	g.resolve_revision(0, tile, none)
	_refresh()


## PASO: sin jugada es un pase normal; con jugada, un renuncio (chivo de pase).
func _pass_button() -> void:
	if g.phase != "play" or g.turn != 0 or busy:
		return
	var none: bool = g.legal_moves(0).is_empty()
	if online:
		red.enviar(Red.OP_PASAR if none else Red.OP_PASAR_CON_FICHA)
		return
	if none:
		g.pass_turn(0)
	else:
		g.pass_fake(0)
	_refresh()


## Robar: tú coges una y cada bot coge otra a tu ritmo.
func _draw_pick(idx: int) -> void:
	if g.phase != "draw" or my_picks.size() >= 7 or view.pool_taken.has(idx):
		return
	if online:
		red.enviar(Red.OP_ROBAR, {"idx": idx})
		return
	view.take_pool_tile(idx, 0, my_picks.size())
	my_picks.append(idx)
	for s in [1, 2, 3]:
		var free: Array = range(28).filter(func(x): return not view.pool_taken.has(x))
		if free.is_empty():
			break
		var b: int = free.pick_random()
		var slot: int = bot_picks[s].size()
		bot_picks[s].append(b)
		view.pool_taken[b] = s
		get_tree().create_timer(0.12 * s).timeout.connect(func(): view.take_pool_tile(b, s, slot))
	_refresh()
	if my_picks.size() == 7:
		await get_tree().create_timer(0.8).timeout
		g.finish_draw([my_picks, bot_picks[1], bot_picks[2], bot_picks[3]])
		my_picks = []
		bot_picks = [[], [], [], []]
		_refresh()


## Recoge solas las fichas que te faltan, una tras otra (como si las fueras
## tocando), sin tener que pulsar cada una.
func _auto_collect() -> void:
	if _collecting or g.phase != "draw":
		return
	_collecting = true
	sfx.play("shuffle", -6.0, 0.05)
	var guard := 0
	while g.phase == "draw" and my_picks.size() < 7 and guard < 40 and playing:
		guard += 1
		while view.animating:
			await get_tree().process_frame
		var free: Array = range(28).filter(func(x): return not view.pool_taken.has(x))
		if free.is_empty():
			break
		var before := my_picks.size()
		_draw_pick(free.pick_random())
		# online: esperar a que el servidor confirme la ficha antes de pedir otra
		var t0 := Time.get_ticks_msec()
		while online and my_picks.size() == before and g.phase == "draw" and Time.get_ticks_msec() - t0 < 1500:
			await get_tree().process_frame
		await get_tree().create_timer(0.13).timeout
	_collecting = false


func _finish_draw_auto() -> void:
	if g.phase == "draw":
		g.finish_draw(g.auto_picks([]))
		my_picks = []
		bot_picks = [[], [], [], []]
		_refresh()


## Tocar la radio: online la cambia para toda la sala; sin conexión, la tuya.
func _tocar_radio() -> void:
	sfx.play("clack", -10.0)
	view.radio_node.create_tween().tween_property(view.radio_node, "scale", Vector3.ONE * 1.08, 0.06)
	view.radio_node.create_tween().tween_property(view.radio_node, "scale", Vector3.ONE, 0.12).set_delay(0.06)
	if radio.emisora != "fm":
		_float("Tienes puesta tu música: cambia a Colmadón FM en la radio de ajustes", Vector2(CX, 90), C_CREAM)
		return
	if online:
		red.enviar(Red.OP_RADIO, {})
	else:
		radio.tocar_local()
	await get_tree().create_timer(0.35).timeout
	_float(radio.titulo(), Vector2(CX, 90), C_GOLD)


func _puede_beber() -> bool:
	return g.phase == "play" and g.turn == 0 and not busy and not view.pie.standing()


var glass_tip: Label


## Vaso bajo el puntero: se levanta y dice qué es y qué hace.
func _glass_hover(p: Vector2) -> void:
	var gi: int = view.glass_at(p) if playing and not paused else -1
	view.set_glass_hover(gi)
	if gi < 0:
		if is_instance_valid(glass_tip):
			glass_tip.visible = false
		return
	var id: String = view.glass_id(gi)
	if not is_instance_valid(glass_tip):
		glass_tip = _lbl("", 9, C_CREAM)
		glass_tip.add_theme_stylebox_override("normal", _box_style(Color(0.12, 0.07, 0.04, 0.92), C_GOLD, 1, 0, 3))
		glass_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glass_tip.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		hud.add_child(glass_tip)
	var accion: String = tr("toca para beber") if _puede_beber() else tr("se bebe en tu turno")
	glass_tip.text = "%s · %s\n%s" % [tr(ColmadoGame.DRINKS[id].name), accion, tr(ColmadoGame.DRINKS[id].desc)]
	glass_tip.visible = true
	glass_tip.size = Vector2.ZERO
	glass_tip.size = glass_tip.get_combined_minimum_size()
	# hacia el centro de la pantalla y por encima: no tapa PARARSE ni los gestos
	var tx: float = p.x + 12.0 if p.x < CX else p.x - 12.0 - glass_tip.size.x
	glass_tip.position = Vector2(tx, p.y - glass_tip.size.y - 40.0).clamp(Vector2(4, 4), Vector2(530, 356) - glass_tip.size)


func _drink(id: String) -> void:
	if is_instance_valid(glass_tip):
		glass_tip.visible = false
	if online:
		red.enviar(Red.OP_BEBER, {"id": id})
		return
	g.use_drink(0, id)
	_refresh()


func _clear_overlay() -> void:
	_lobby_sig = ""
	for c in overlay.get_children():
		c.queue_free()


func _dim() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.02, 0.62)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)


func _sign(title: Variant, y := 14.0) -> void:
	# I9: el «¡N PUNTOS!» de la cuenta se quedaba encima del letrero
	if is_instance_valid(_count_lbl):
		_count_lbl.queue_free()
	var p := PanelContainer.new()
	var sb := _box_style(C_GOLD, C_INK, 3, 5, 3)
	p.add_theme_stylebox_override("panel", sb)
	var l := _lbl(title, 15, C_INK)
	l.add_theme_constant_override("outline_size", 0)
	p.add_child(l)
	overlay.add_child(p)
	p.size = p.get_combined_minimum_size()   # centrado desde el primer fotograma
	p.position = Vector2(CX - p.size.x / 2, y)
	p.rotation = -0.02
	p.resized.connect(func(): p.position.x = CX - p.size.x / 2)


func _build_overlay() -> void:
	var session := _game_session
	_clear_overlay()
	match g.phase:
		"lobby":
			_build_lobby()
		"pick":
			if avatar == "":
				_build_avatar_picker()
				return
			_dim()
			_sign(func(): return tr("MANO %d · ELIGE UN AUMENTO") % g.hand_no)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.position = Vector2(0, 70)
			row.size = Vector2(W, 220)
			overlay.add_child(row)
			var i := 0
			_card_nodes.clear()
			for id in g.offers[0]:
				var card := _make_card(id)
				_card_nodes[id] = card
				row.add_child(card)
				card.modulate.a = 0.0
				var tw := create_tween()
				tw.tween_interval(0.08 * i)
				tw.tween_property(card, "modulate:a", 1.0, 0.2)
				i += 1
			var hint := _lbl("Los aumentos se suman toda la partida", 9, C_GOLD)
			hint.position = Vector2(0, 300)
			hint.size = Vector2(W, 14)
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			overlay.add_child(hint)
			# online hay 30 s para elegir (si no, el servidor elige por ti); en
			# la partida local no hay prisa
			if online:
				pick_timer = _lbl("", 11, C_GOLD)
				pick_timer.position = Vector2(0, 316)
				pick_timer.size = Vector2(W, 16)
				pick_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				overlay.add_child(pick_timer)
		"shop":
			await _wait_count()
			if playing and session == _game_session and g.phase == "shop":
				if g.mode == "clasico":
					_build_between()
				else:
					_build_shop()
		"over":
			await _wait_count()
			if not playing or session != _game_session or g.phase != "over":
				return
			_clear_overlay()
			_dim()
			_build_notebook()


## Espera a que se vean el golpe final y la cuenta de las fichas.
func _wait_count() -> void:
	await get_tree().create_timer(1.7).timeout
	while (_tranque_pending or _ver_pending) and playing:
		await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	# O15: la cuenta de otra persona va a su ritmo (si deja de tocar, a los 40 s
	# se cuentan solas): la tienda no la corta ni la adelanta
	while view.counting and (view.count_remote or Time.get_ticks_msec() - t0 < 15000):
		await get_tree().process_frame


var _count_lbl: Label


## Cada ficha contada: su valor salta sobre ella y sube el contador grande.
func _on_count_tick(pips: int, total: int, at: Vector2) -> void:
	var team: int = int(g.last_result.get("team", 0))
	var col: Color = C_GOLD if team == 0 else C_RED.lightened(0.25)
	_float("+%d" % pips, at, col)
	sfx.play("tick", -6.0, 0.0)
	if not is_instance_valid(_count_lbl):
		# I9: arriba en el centro (donde va el cartel de turno), con fondo; ya no
		# tapa la cara ni la placa de quien está enfrente
		_count_lbl = _lbl("", 15, col)
		_count_lbl.add_theme_constant_override("outline_size", 5)
		_count_lbl.add_theme_stylebox_override("normal", _fondo_texto())
		_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_count_lbl.size = Vector2(200, 24)
		_count_lbl.position = Vector2(CX - 100, 7)   # termina antes de la placa de enfrente (y 36)
		_count_lbl.pivot_offset = Vector2(100, 12)
		hud.add_child(_count_lbl)
	var who: String = seat_names[int(g.last_result.get("seat", 0))]
	var yo: bool = int(g.last_result.get("seat", 0)) == 0
	_count_lbl.text = tr("Cuentas: %d") % total if yo else tr("Cuenta %s: %d") % [who, total]
	var tw := _count_lbl.create_tween()
	tw.tween_property(_count_lbl, "scale", Vector2(1.18, 1.18), 0.05)
	tw.tween_property(_count_lbl, "scale", Vector2.ONE, 0.1)


var _count_ui: Control


## Fondo oscuro redondeado para textos que flotan sobre la escena (I9).
func _fondo_texto() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.03, 0.78)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb


## Gana tu pareja: te toca contar. Toca cada ficha (o cuéntalas todas de golpe).
func _on_count_ready() -> void:
	if is_instance_valid(_count_ui):
		_count_ui.queue_free()
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_count_ui = box
	hud.add_child(box)
	var l := _lbl("¡Te toca contar! Toca cada ficha", 13, C_GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_stylebox_override("normal", _fondo_texto())   # I9: se leía mal sobre el borde de la mesa
	box.add_child(l)
	_count_hint = l
	var b := Button.new()
	b.text = "CONTAR TODAS"
	b.add_theme_font_size_override("font_size", 10)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): view.count_fast = true)
	box.add_child(b)
	box.position = Vector2(200, 300)
	box.size = Vector2(240, 50)
	var tw := l.create_tween().set_loops(4)
	tw.tween_property(l, "modulate:a", 0.5, 0.35)
	tw.tween_property(l, "modulate:a", 1.0, 0.35)


## Online: la cuenta la hace otra persona (quien ganó, si no es un bot ni
## está ausente): aquí se ve a su ritmo y la tienda espera a que acabe.
func _cuenta_ajena(gana: int) -> bool:
	if not online or gana == 0:
		return false
	var seats: Array = online_v.get("seats", [])
	if gana >= seats.size():
		return false
	var st: Dictionary = seats[gana]
	return not st.get("bot", true) and not st.get("away", false) and st.get("connected", true)


func _count_ajena_ui(gana: int) -> void:
	if is_instance_valid(_count_ui):
		_count_ui.queue_free()
	var l := _lbl(tr("%s está contando…") % seat_names[gana], 13, C_GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, 312)
	l.size = Vector2(W, 18)
	_count_ui = l
	hud.add_child(l)


## Fin de la cuenta: el total golpea (más fuerte cuanto más grande).
func _on_count_done(total: int) -> void:
	if is_instance_valid(_count_ui):
		_count_ui.queue_free()
	if not is_instance_valid(_count_lbl):
		return
	var r: Dictionary = g.last_result
	var extra := ""
	if int(r.pts) != total:
		extra = "  →  " + tr("%d con aumentos") % int(r.pts)
	_count_lbl.text = tr("¡%d PUNTOS!") % total + extra
	_count_lbl.set_meta("hecho", true)   # se desvanece sola
	sfx.play("boom" if total >= 25 else "coin", -4.0, 0.0)
	shake = max(shake, 3.0 + min(total, 60) * 0.1)
	_burst(Vector2(CX, 72), C_GOLD if r.team == 0 else C_RED.lightened(0.25), 30 + min(total, 60))
	var lbl := _count_lbl
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.5, 1.5), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.18)
	tw.tween_interval(1.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.3)
	tw.tween_callback(lbl.queue_free)


## Pantalla de carga: mientras gira una ficha y sale un dicho, se preparan
## de verdad las 28 texturas de fichas en alta definición.
func _loading_screen() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var root := Control.new()
	root.theme = theme_ui
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.06, 0.04)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	# vetas de madera
	for i in 14:
		var r := ColorRect.new()
		r.color = Color(0.16, 0.1, 0.06, 0.6)
		r.position = Vector2(0, 12 + i * 26 + randf_range(-4, 4))
		r.size = Vector2(W, 2)
		root.add_child(r)
	var title := _lbl("COLMADÓN", 34, Color(1.0, 0.45, 0.6))
	title.add_theme_color_override("font_outline_color", Color(0.45, 0.05, 0.2))
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 46)
	title.size = Vector2(W, 44)
	root.add_child(title)
	var tile := TextureRect.new()
	tile.texture = view._tile_tex(Vector2i(6, 6))
	tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.stretch_mode = TextureRect.STRETCH_SCALE
	tile.size = Vector2(40, 80)
	tile.position = Vector2(300, 120)
	tile.pivot_offset = Vector2(20, 40)
	root.add_child(tile)
	var spin := create_tween().set_loops()
	spin.tween_property(tile, "rotation", TAU, 1.6).from(0.0)
	var dicho_key: String = DICHOS.pick_random()
	var dicho := _lbl(func(): return tr("«%s»") % tr(dicho_key), 12, C_CREAM)
	dicho.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dicho.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dicho.position = Vector2(80, 228)
	dicho.size = Vector2(480, 40)
	root.add_child(dicho)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.05, 0.03, 0.02)
	bar_bg.position = Vector2(170, 290)
	bar_bg.size = Vector2(300, 10)
	root.add_child(bar_bg)
	var bar := ColorRect.new()
	bar.color = C_GOLD
	bar.position = Vector2(172, 292)
	bar.size = Vector2(0, 6)
	root.add_child(bar)
	var what := _lbl("Abriendo el colmado…", 9, Color(C_CREAM, 0.7))
	what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	what.position = Vector2(0, 304)
	what.size = Vector2(W, 14)
	root.add_child(what)
	var t0 := Time.get_ticks_msec()
	for i in 28:
		view.precache_tile(i)
		bar.size.x = 296.0 * (i + 1) / 28.0
		if i == 14:
			what.text = "Barajando las fichas…"
		if i == 20 and OS.get_cmdline_user_args().has("--prueba-menus"):
			get_viewport().get_texture().get_image().save_png("user://menu_carga.png")
		await get_tree().process_frame
	# que se pueda leer el dicho
	while Time.get_ticks_msec() - t0 < 2200:
		await get_tree().process_frame
	var fade := create_tween()
	fade.tween_property(root, "modulate:a", 0.0, 0.4)
	await fade.finished
	spin.kill()
	layer.queue_free()


## La libreta del colmadero: la cuenta de la partida.
func _build_notebook() -> void:
	var won: bool = g.last_result.team == 0
	var paper := PanelContainer.new()
	var sb := _box_style(Color(0.98, 0.96, 0.88), C_INK, 2, 4, 2)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	sb.content_margin_left = 22
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	paper.add_theme_stylebox_override("panel", sb)
	paper.position = Vector2(170, 22)
	paper.custom_minimum_size = Vector2(300, 0)
	paper.rotation = -0.025
	overlay.add_child(paper)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	paper.add_child(v)
	var ink := Color(0.12, 0.2, 0.55)
	var resultado_color: Color = (Accesibilidad.AZUL.darkened(0.5) if won else Accesibilidad.NARANJA.darkened(0.4)) if accesibilidad.daltonico else (Color(0.1, 0.5, 0.25) if won else C_RED)
	var t := _lbl(func(): return ("✓ " if won else "× ") + tr("¡GANAMOS!" if won else "Nos ganaron…"), 18, resultado_color)
	t.add_theme_constant_override("outline_size", 0)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := _lbl("La cuenta del colmadero", 9, Color(0.4, 0.35, 0.3))
	sub.add_theme_constant_override("outline_size", 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var rows := [
		["", "Nosotros", "Ellos"],
		["Puntos", str(g.scores[0]), str(g.scores[1])],
		["Manos ganadas", str(g.stats.manos[0]), str(g.stats.manos[1])],
		["Dominós", str(g.stats.dominos[0]), str(g.stats.dominos[1])],
		["Tranques", str(g.stats.tranques[0]), str(g.stats.tranques[1])],
		["Capicúas", str(g.stats.capicuas[0]), str(g.stats.capicuas[1])],
		["Chivos cantados", str(g.stats.chivos[0]), str(g.stats.chivos[1])],
		["Pases de +30", str(g.stats.get("pases", [0, 0])[0]), str(g.stats.get("pases", [0, 0])[1])],
		["Bebidas tomadas", str(g.stats.bebidas[0]), str(g.stats.bebidas[1])],
		["Mejor mano", str(g.stats.max_mano[0]), str(g.stats.max_mano[1])],
	]
	for i in rows.size():
		var h := HBoxContainer.new()
		v.add_child(h)
		for k in 3:
			var l := _lbl(rows[i][k], 11 if i > 0 else 10, ink if k > 0 else Color(0.2, 0.15, 0.1))
			l.add_theme_constant_override("outline_size", 0)
			l.custom_minimum_size = Vector2(130 if k == 0 else 70, 0)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if k == 0 else HORIZONTAL_ALIGNMENT_CENTER
			h.add_child(l)
		var line := ColorRect.new()
		line.color = Color(0.55, 0.7, 0.9, 0.6)
		line.custom_minimum_size = Vector2(0, 1)
		v.add_child(line)
	# pesos para el armario (se guardan entre partidas)
	var earned: int = (40 if won else 15) + g.stats.capicuas[0] * 10 + g.stats.chivos[0] * 5 + g.stats.dominos[0] * 3
	if won:
		menus.profile["ganadas"] = int(menus.profile.get("ganadas", 0)) + 1
	menus.add_pesos(earned)
	var pe := _lbl(func(): return tr("+%d pesos para el armario  (tienes %d)") % [earned, int(menus.profile.pesos)], 11, Color(0.6, 0.4, 0.05))
	pe.add_theme_constant_override("outline_size", 0)
	pe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(pe)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 8)
	v.add_child(hb)
	var again := _yellow(Button.new())
	again.text = "REVANCHA"
	again.custom_minimum_size = Vector2(84, 0)   # en inglés y a 960×540 no se corta
	again.pressed.connect(_restart)
	hb.add_child(again)
	if online:
		_build_revancha_notice(again, v)
	var out := Button.new()
	out.text = "Volver al colmado"
	out.custom_minimum_size = Vector2(136, 0)
	out.pressed.connect(func(): quit_to_menu())
	hb.add_child(out)
	var rv := _review_button(Vector2.ZERO)
	hb.add_child(rv)
	paper.scale = Vector2(0.8, 0.8)
	create_tween().tween_property(paper, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Sigue las vistas del servidor sin reconstruir la libreta ni volver a dar pesos.
func _build_revancha_notice(again: Button, notebook: VBoxContainer) -> void:
	var badge := Label.new()
	badge.name = "RevanchaContador"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", Color.WHITE)
	var circle := StyleBoxFlat.new()
	circle.bg_color = C_RED
	circle.set_corner_radius_all(10)
	badge.add_theme_stylebox_override("normal", circle)
	again.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -10
	badge.offset_top = -10
	badge.offset_right = 10
	badge.offset_bottom = 10
	var notice := _lbl("", 10, C_INK)
	notice.name = "RevanchaAviso"
	notice.add_theme_constant_override("outline_size", 0)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	notice.clip_text = true
	notebook.add_child(notice)
	var update := _update_revancha_notice.bind(again, badge, notice)
	red.estado.connect(update)
	again.tree_exiting.connect(func():
		if red.estado.is_connected(update):
			red.estado.disconnect(update))
	_update_revancha_notice(online_v, again, badge, notice)


func _update_revancha_notice(v: Dictionary, again: Button, badge: Label, notice: Label) -> void:
	var votes: Array = v.get("revancha", [])
	var seats: Array = v.get("seats", [])
	var names: PackedStringArray = []
	for s in mini(votes.size(), seats.size()):
		if votes[s] and not seats[s].get("bot", false):
			names.append(str(seats[s].get("name", "")))
	badge.text = str(names.size())
	badge.visible = v.get("phase", "") == "over" and not names.is_empty()
	again.disabled = not votes.is_empty() and bool(votes[0])
	notice.text = ""
	if names.size() == 1:
		notice.text = tr("%s quiere la revancha") % names[0]
	elif names.size() > 1:
		notice.text = tr("Quieren revancha: %s") % ", ".join(names)
	notice.tooltip_text = notice.text


# ---------------------------------------------------------------- partida, pausa y menús

func start_game(instant := false, game_mode := "") -> void:
	view.mesa_activa = true
	_game_session += 1
	if game_mode != "":
		g.mode = game_mode
	g.target = menus.meta_actual()   # 100 o 200, lo que se eligió en la pizarra
	menus.close()
	_close_review()
	playing = true
	paused = false
	hud.visible = true
	sharp_rect.visible = true
	view.show_arms = true
	avatar = "custom"
	view.set_avatar_cfg(menus.profile)
	view.reset_table()
	if instant:
		view.cam_set("mesa")
	else:
		view.cam_to("mesa", 1.1)
	g.new_game()
	ui_phase = ""
	my_picks = []
	bot_picks = [[], [], [], []]
	view.set_aura(0, 0)
	view.pie.mode = "sentado"
	view.reset_chair()
	view.set_room_seat(0)
	view.covered.clear()
	_refresh()


func toggle_pause() -> void:
	# pausar de pie: te quedas donde estás (antes te sentaba de golpe); solo
	# se suelta el ratón para pulsar los botones y se vuelve a capturar al seguir
	paused = not paused
	if view.pie.mode == "de_pie":
		_capture_mouse(not paused)
	if is_instance_valid(pause_ui):
		pause_ui.queue_free()
	if not paused:
		return
	sfx.play("card", -6.0)
	pause_ui = Control.new()
	pause_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(pause_ui)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.02, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_ui.add_child(dim)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.position = Vector2(245, 105)
	pause_ui.add_child(col)
	var title := _lbl("PAUSA", 20, C_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	col.add_child(menus._sign_button("SEGUIR", C_GOLD, toggle_pause, 14))
	var aj: Button = menus._sign_button("AJUSTES", Color(0.45, 0.28, 0.14), func():
		pause_ui.queue_free()
		hud.visible = false
		sharp_rect.visible = false
		view.show_arms = false
		menus.open("ajustes", true))
	aj.icon = _icon("gear", C_GOLD)
	col.add_child(aj)
	col.add_child(menus._sign_button("SALIR AL COLMADO", C_RED, quit_to_menu))


## Vuelve a la partida desde los ajustes abiertos en la pausa.
func resume_from_menu() -> void:
	paused = false
	hud.visible = true
	sharp_rect.visible = true
	view.show_arms = true
	if view.pie.standing():
		# de pie: la cámara vuelve a tus ojos (la pone pie.update en el siguiente fotograma)
		if view.pie.mode == "de_pie":
			_capture_mouse(true)
	else:
		view.cam_to("mesa", 0.8)


func quit_to_menu(dest := "inicio") -> void:
	view.mesa_activa = false
	_game_session += 1
	_tranque_pending = false
	if is_instance_valid(tranque_ui):
		tranque_ui.queue_free()
	tranque_ui = null
	if online and (g.phase == "over" or g.phase == "lobby"):
		red.olvidar_sala()   # partida acabada o sin empezar: no hay nada a lo que volver
	if online:
		online = false
		radio.set_compartida(false)
		chat_btn.visible = false
		if is_instance_valid(chat_panel):
			chat_panel.queue_free()
		red.salir()
		g = ColmadoGame.new()
		seat_names = SEAT_NAMES_LOCAL.duplicate()
		var presets := {1: "yeya", 2: "fello", 3: "chichi"}
		for k in [1, 2, 3]:
			if _look_sig[k] != "":
				view.set_seat_look(k, presets[k])
			_look_sig[k] = ""
			view.set_seat_empty(k, false)
	playing = false
	paused = false
	if is_instance_valid(pause_ui):
		pause_ui.queue_free()
	_close_review()
	_clear_overlay()
	hud.visible = false
	sharp_rect.visible = false
	view.show_arms = false
	view.set_top(false)
	view.pie.mode = "sentado"
	view.reset_chair()
	view.set_room_seat(0)
	_capture_mouse(false)
	view.pie.remote.clear()
	view.covered.clear()
	g.new_game()
	view.reset_table()
	ui_phase = g.phase
	_lobby_sig = ""
	menus.open(dest)


func apply_settings() -> void:
	var st: Dictionary = menus.settings
	if accesibilidad != null:
		accesibilidad.aplicar()
		view.accesible = accesibilidad.daltonico
		sit_btn.tooltip_text = _key_name("pararse")
		view_btn.tooltip_text = tr("Mirar") + " (" + _key_name("mirar") + ")"
		chat_btn.tooltip_text = tr("Frases rápidas") + " (" + _key_name("chat") + ")"
		emote_btn.tooltip_text = "\n".join(EMOTES.map(func(e): return tr(e[1]) + " (" + _key_name("gesto%d" % (EMOTES.find(e) + 1)) + ")"))
		for ref in accesibilidad._controles:
			var control = ref.get_ref()
			if is_instance_valid(control) and control.has_meta("gesto"):
				var numero: int = control.get_meta("gesto")
				control.tooltip_text = tr(EMOTES[numero - 1][1]) + " (" + _key_name("gesto%d" % numero) + ")"
		for par in [[score_us, Accesibilidad.AZUL if accesibilidad.daltonico else C_TURQ], [score_them, Accesibilidad.NARANJA if accesibilidad.daltonico else C_RED]]:
			par[0].get_parent().get_parent().add_theme_stylebox_override("panel", _box_style(par[1], C_INK, 2, 3, 2))
		if playing and is_instance_valid(meta_lbl):
			_refresh.call_deferred()
	# Volumen = todo el juego; Efectos = fichas, vasos y el ambiente del colmado
	AudioServer.set_bus_volume_db(0, linear_to_db(max(float(st.vol), 0.0001)))
	sfx.set_volumes(st.fx, st.fx)
	radio.set_volumen(st.mus)
	if radio.emisora != str(st.emisora):
		radio.poner(str(st.emisora))
	shake_mult = 0.0 if st.menos_movimiento else st.shake
	preload("res://scripts/character.gd").peso = 0.3 if st.menos_movimiento else 1.0
	# Ignora «finos» de ajustes antiguos: la mesa usa siempre píxeles grandes.
	st.pixels = "grandes"
	sv3d.size = Vector2i(roundi(W), 360)
	view.px_scale = 1.0
	var fs: bool = st.fullscreen
	# solo se toca la ventana si cambia la pantalla completa: una ventana
	# maximizada (grande pero no pantalla completa) se queda como está
	var cur := DisplayServer.window_get_mode()
	var is_fs: bool = cur == DisplayServer.WINDOW_MODE_FULLSCREEN or cur == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fs != is_fs and not autotest:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)
	# idioma: "" = el del sistema (Godot usa el inglés si no es español)
	var loc: String = str(st.get("idioma", ""))
	var antes := TranslationServer.get_locale()
	TranslationServer.set_locale(loc if loc != "" else OS.get_locale())
	RegistroFallos.contexto()
	if antes != TranslationServer.get_locale() and playing and is_instance_valid(meta_lbl):
		# Solo refresca el HUD: ui_phase conserva la pantalla actual. La libreta
		# no se reconstruye y los pesos se conceden una sola vez.
		_sig_cards = ""
		_sig_drinks = ""
		_sig_action = ""
		_refresh.call_deferred()


## Botón para mirar la mesa tal como quedó (quién ganó, si hubo chivo…).
func _review_button(pos: Vector2) -> Button:
	var b := Button.new()
	b.text = "Ver la mesa"
	b.icon = _icon("eye", C_TURQ)
	b.position = pos
	b.custom_minimum_size = Vector2(120, 28)
	b.pressed.connect(_review_table)
	return b


var _review_bar: Control


func _review_table() -> void:
	if _tranque_pending:
		return
	_close_review()
	view.restore_table()
	sfx.play("card", -6.0)
	overlay.visible = false
	big_banner.visible = false
	# barra pequeña abajo a la izquierda: no tapa la mesa ni sus fichas
	_review_bar = PanelContainer.new()
	var sb := _box_style(Color(0.12, 0.07, 0.04, 0.82), C_WOOD, 2, 3, 5)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	_review_bar.add_theme_stylebox_override("panel", sb)
	hud.add_child(_review_bar)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	_review_bar.add_child(v)
	var r: Dictionary = g.last_result
	var who := "Tu pareja ganó" if r.get("team", 0) == 0 else "Los rivales ganaron"
	var how: String = {"dominó": "dominó", "tranque": "tranque", "chivo": "chivo cantado", "renuncio": "renuncio"}.get(r.get("reason", ""), str(r.get("reason", "")))
	var l := _lbl(func(): return tr("%s por %s") % [tr(who), tr(how)], 9)
	v.add_child(l)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	v.add_child(h)
	var top := Button.new()
	top.text = tr("Desde abajo") if view.top_view else tr("Desde arriba")
	top.add_theme_font_size_override("font_size", 10)
	top.pressed.connect(func():
		view.toggle_top()
		top.text = tr("Desde abajo") if view.top_view else tr("Desde arriba"))
	h.add_child(top)
	var back := _yellow(Button.new())
	back.text = "Volver"
	back.add_theme_font_size_override("font_size", 10)
	back.pressed.connect(_close_review)
	h.add_child(back)
	_review_bar.position = Vector2(6, 354 - _review_bar.get_combined_minimum_size().y)


## Cierra «Ver la mesa» y devuelve la pantalla que había (tienda o libreta).
## También se llama al salir al colmado o empezar otra partida, para que
## nunca se quede la interfaz escondida.
func _close_review() -> void:
	if is_instance_valid(_review_bar):
		_review_bar.queue_free()
		view.set_top(false)
	_review_bar = null
	overlay.visible = true


func _build_avatar_picker() -> void:
	_dim()
	_sign("ELIGE TU JUGADOR")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.position = Vector2(0, 66)
	row.size = Vector2(W, 230)
	overlay.add_child(row)
	for id in View3D.Character.AVATARS:
		row.add_child(_avatar_card(id))
	var hint := _lbl("Así te verán los demás en la mesa", 10, C_GOLD)
	hint.position = Vector2(0, 306)
	hint.size = Vector2(W, 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(hint)


func _avatar_card(id: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(150, 210)
	b.add_theme_stylebox_override("normal", _box_style(C_CREAM, C_INK, 3, 6, 5))
	b.add_theme_stylebox_override("hover", _box_style(Color.WHITE, C_GOLD, 3, 6, 5))
	b.add_theme_stylebox_override("pressed", _box_style(C_CREAM.darkened(0.1), C_INK, 3, 3, 5))
	b.pivot_offset = Vector2(75, 105)
	b.pressed.connect(_choose_avatar.bind(id))
	b.mouse_entered.connect(func(): create_tween().tween_property(b, "scale", Vector2(1.05, 1.05), 0.1))
	b.mouse_exited.connect(func(): create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))
	# retrato vivo: el personaje parpadea y respira
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.size = Vector2i(140, 170)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	b.add_child(sv)
	var ch = View3D.Character.new()
	sv.add_child(ch)
	ch.setup(id)
	var cam := Camera3D.new()
	sv.add_child(cam)
	cam.transform = Transform3D(Basis(), Vector3(0, 0.5, -0.85)).looking_at(Vector3(0, 0.36, 0))
	cam.fov = 40
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = C_TURQ.darkened(0.35)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.6, 0.55)
	cam.environment = env
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.6, PI + 0.4, 0)
	sv.add_child(light)
	var v := VBoxContainer.new()
	v.position = Vector2(5, 5)
	v.size = Vector2(140, 200)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var portrait := TextureRect.new()
	portrait.texture = sv.get_texture()
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.custom_minimum_size = Vector2(140, 170)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(portrait)
	var n := _lbl(View3D.Character.AVATAR_NAMES[id].to_upper(), 13, C_INK)
	n.add_theme_constant_override("outline_size", 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	return b


func _choose_avatar(id: String) -> void:
	avatar = id
	view.set_avatar(id)
	ui_phase = ""
	_refresh()


func _make_card(id: String) -> Button:
	var c: Dictionary = ColmadoGame.CARDS[id]
	var col := _card_color(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(138, 222)   # alto fijo (antes crecía con descripciones largas)
	b.add_theme_stylebox_override("normal", _box_style(C_CREAM, C_INK, 3, 6, 5))
	b.add_theme_stylebox_override("hover", _box_style(Color.WHITE, C_GOLD, 3, 6, 5))
	b.add_theme_stylebox_override("pressed", _box_style(C_CREAM.darkened(0.1), C_INK, 3, 3, 5))
	b.pivot_offset = Vector2(69, 95)
	b.pressed.connect(_pick.bind(id))
	b.mouse_entered.connect(func(): create_tween().tween_property(b, "scale", Vector2(1.06, 1.06), 0.1))
	b.mouse_exited.connect(func(): create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_right = -6
	v.offset_top = 6
	v.offset_bottom = -8
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", _box_style(col, C_INK, 2, 2, 3))
	head.custom_minimum_size = Vector2(126, 72)   # ancho desde el primer fotograma (saltaba de 60 a 126)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	head.add_child(_icon_rect(_card_icon(id), 48))
	var name_l := _lbl(func(): return tr(c.name).to_upper(), 11, C_INK)
	name_l.add_theme_constant_override("outline_size", 0)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	var desc := _lbl(c.desc, 10, C_WOOD_D)
	desc.add_theme_constant_override("outline_size", 0)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.custom_minimum_size = Vector2(120, 0)
	# los textos largos («Ficha marcada») bajan de tamaño hasta caber en la carta
	desc.add_theme_font_size_override("font_size", _fit_font(tr(c.desc), 120.0, 84.0, 10, 7))
	_live_text(desc, func():
		desc.add_theme_font_size_override("font_size", _fit_font(tr(c.desc), 120.0, 84.0, 10, 7))
		return tr(c.desc))
	v.add_child(desc)
	return b


## Tamaño de letra más grande (entre max_fs y min_fs) con el que el texto cabe
## en un recuadro de ancho w y alto h.
func _fit_font(text: String, w: float, h: float, max_fs: int, min_fs: int) -> int:
	for fs in range(max_fs, min_fs - 1, -1):
		var sz: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
		if sz.y <= h:
			return fs
	return min_fs


func _build_shop() -> void:
	_clear_overlay()
	_dim()
	_sign("EL COLMADO")
	var r: Dictionary = g.last_result
	var who := "Tu pareja gana" if r.team == 0 else "Los rivales ganan"
	var gain := ColmadoGame.WIN_COINS if r.team == 0 else ColmadoGame.LOSE_COINS
	if r.team == 0 and g.has_card(0, "bolsillo"):
		gain += 8  # Bolsillo: +8 monedas al ganar (game.gd, _end_hand)
	var purchases: Array = g.bot_purchases.duplicate(true)
	var info := _lbl(func():
		var lines: Array = [tr("%s la mano por %s · +%d pts") % [tr(who), tr(r.reason), r.pts]]
		if not r.bonus.is_empty():
			lines.append(" · ".join(r.bonus.map(_tr_bonus)))
		var others: Array = purchases.map(func(bp): return tr("%s compró %s") % [seat_names[bp[0]], tr(ColmadoGame.DRINKS[bp[1]].name)])
		if not others.is_empty():
			lines.append(" · ".join(others))
		return "\n".join(lines), 9)
	info.position = Vector2(CX - 175, 48)
	info.size = Vector2(350, 40)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_stylebox_override("normal", _fondo_texto())   # I9: tapa la placa de enfrente, mejor con fondo que encima
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(info)

	var wallet := HBoxContainer.new()
	wallet.alignment = BoxContainer.ALIGNMENT_CENTER
	wallet.position = Vector2(0, 92)
	wallet.size = Vector2(W, 18)
	overlay.add_child(wallet)
	wallet.add_child(_icon_rect(_icon("coin"), 16))
	wallet.add_child(_lbl(func(): return tr("%d  (+%d)   ·   Bebidas %d/%d") % [g.coins[0], gain, g.drinks[0].size(), ColmadoGame.MAX_DRINKS], 12, C_GOLD))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.position = Vector2(0, 118)
	row.size = Vector2(W, 170)
	overlay.add_child(row)
	for id in ColmadoGame.DRINKS:
		row.add_child(_drink_card(id))
	var next := _yellow(Button.new())
	_symbol_button(next, "SIGUIENTE MANO  ▶")
	next.add_theme_font_size_override("font_size", 12)
	next.position = Vector2(178, 312)
	next.custom_minimum_size = Vector2(140, 28)
	next.pressed.connect(_next_hand)
	overlay.add_child(next)
	overlay.add_child(_review_button(Vector2(40, 312)))
	# ir andando al mostrador a pedirle al colmadero (2026-10-04)
	if not online or online_v.get("de_pie", false):
		var go := Button.new()
		go.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_live_text(go, func(): return tr("IR AL MOSTRADOR ▸").replace("▸", "").strip_edges())
		go.icon = _drink_icon("ron")
		go.tooltip_text = "Te levantas y vas a pedirle la bebida al colmadero"
		go.position = Vector2(344, 312)
		go.custom_minimum_size = Vector2(130, 28)
		go.pressed.connect(func():
			_stand_up()
			_float("Ve al mostrador a pedir", Vector2(CX, 120), C_GOLD))
		overlay.add_child(go)
	_add_shop_timer()


## Online: cuánto queda para que empiece la mano siguiente (antes la tienda
## desaparecía sin avisar).
func _add_shop_timer() -> void:
	if not online:
		return
	shop_timer = _lbl("", 10, C_GOLD)
	shop_timer.position = Vector2(0, 296)
	shop_timer.size = Vector2(W, 14)
	shop_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(shop_timer)


## Dominó clásico: entre mano y mano, solo el resultado y seguir (no hay colmado).
func _build_between() -> void:
	_clear_overlay()
	_dim()
	var r: Dictionary = g.last_result
	_sign(func(): return tr("MANO %d") % g.hand_no)
	var who := "Tu pareja gana" if r.team == 0 else "Los rivales ganan"
	var info := _lbl(func(): return tr("%s la mano por %s · +%d pts") % [tr(who), tr(r.reason), r.pts], 13, C_GOLD if r.team == 0 else C_CREAM)
	info.position = Vector2(0, 120)
	info.size = Vector2(W, 20)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(info)
	var sc := _lbl(func(): return tr("Nosotros %d  ·  Ellos %d   (meta %d)") % [g.scores[0], g.scores[1], g.target], 12, C_CREAM)
	sc.position = Vector2(0, 150)
	sc.size = Vector2(W, 20)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(sc)
	var next := _yellow(Button.new())
	_symbol_button(next, "SIGUIENTE MANO  ▶")
	next.add_theme_font_size_override("font_size", 12)
	next.position = Vector2(250, 312)
	next.custom_minimum_size = Vector2(140, 28)
	next.pressed.connect(_next_hand)
	overlay.add_child(next)
	overlay.add_child(_review_button(Vector2(110, 312)))
	_add_shop_timer()


func _drink_card(id: String) -> Control:
	var d: Dictionary = ColmadoGame.DRINKS[id]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box_style(C_CREAM, C_INK, 3, 5, 4))
	p.custom_minimum_size = Vector2(130, 170)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", _box_style(C_TURQ.darkened(0.2), C_INK, 2, 2, 3))
	head.custom_minimum_size = Vector2(0, 52)
	v.add_child(head)
	head.add_child(_icon_rect(_drink_icon(id), 40))
	var n := _lbl(func(): return tr(d.name).to_upper(), 10, C_INK)
	n.add_theme_constant_override("outline_size", 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var desc := _lbl(d.desc, 9, C_WOOD_D)
	desc.add_theme_constant_override("outline_size", 0)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.custom_minimum_size = Vector2(112, 36)
	desc.add_theme_font_size_override("font_size", _fit_font(tr(d.desc), 112.0, 54.0, 9, 7))
	_live_text(desc, func():
		desc.add_theme_font_size_override("font_size", _fit_font(tr(d.desc), 112.0, 54.0, 9, 7))
		return tr(d.desc))
	v.add_child(desc)
	# hueco elástico: el botón del precio queda abajo y alineado en las cuatro
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(gap)
	var b := Button.new()
	b.icon = _icon("coin")
	b.text = "%d" % g.drink_cost(0, id)
	b.disabled = not g.can_buy(0, id)
	b.pressed.connect(_buy.bind(id))
	v.add_child(b)
	return p


func _pick(id: String) -> void:
	if _picking:
		return
	_picking = true
	sfx.play("card", -4.0)
	# online se manda ya (que no se pase el reloj durante la animación)
	if online:
		red.enviar(Red.OP_CARTA, {"id": id})
	await _pick_anim(id)
	_picking = false
	if online:
		if g.phase == "pick":
			_wait_others("Esperando a que los demás elijan…")
		return
	if g.phase != "pick" or not playing:
		return  # saliste de la partida durante la animación
	g.human_pick(id)
	_refresh()


## La carta elegida salta al centro con rayos y chispas doradas, tiembla y
## vuela a tus aumentos (arriba a la derecha); las otras caen y se apagan.
func _pick_anim(id: String) -> void:
	var src: Control = _card_nodes.get(id)
	if not is_instance_valid(src):
		return
	var start: Vector2 = src.global_position
	var col := _card_color(id)
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP   # nada de dobles clics mientras vuela
	hud.add_child(layer)
	for k in _card_nodes:
		var c: Button = _card_nodes[k]
		if not is_instance_valid(c):
			continue
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if k == id:
			c.modulate.a = 0.0
		else:
			c.pivot_offset = c.size / 2
			var ft := c.create_tween().set_parallel(true)
			ft.tween_property(c, "modulate:a", 0.0, 0.3)
			ft.tween_property(c, "rotation", randf_range(-0.35, 0.35), 0.3)
			ft.tween_property(c, "scale", Vector2(0.8, 0.8), 0.3)
	var center := Vector2(CX, 172)
	var rays := TextureRect.new()
	rays.texture = _rays_tex(col.lightened(0.3))
	rays.size = Vector2(320, 320)
	rays.position = center - rays.size / 2
	rays.pivot_offset = rays.size / 2
	rays.modulate.a = 0.0
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rays)
	var card := _make_card(id)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(card)
	card.size = Vector2(138, 190)
	card.pivot_offset = Vector2(69, 95)
	card.position = start
	var shine := ColorRect.new()
	shine.color = Color(1, 1, 0.9, 0.0)
	shine.set_anchors_preset(Control.PRESET_FULL_RECT)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(shine)
	var tw := card.create_tween()
	tw.tween_property(card, "position", center - card.pivot_offset, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "scale", Vector2(1.32, 1.32), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		sfx.play("aura2", -4.0, 0.0)
		sfx.play("coin", -6.0, 0.0)
		shake = max(shake, 4.0)
		_burst(center, col.lightened(0.4), 70)
		_burst(center, Color(1, 1, 0.85), 30)
		var rt := rays.create_tween().set_parallel(true)
		rt.tween_property(rays, "modulate:a", 0.9, 0.15)
		rt.tween_property(rays, "rotation", 1.2, 1.2)
		shine.color.a = 0.85
		shine.create_tween().tween_property(shine, "color:a", 0.0, 0.35))
	tw.tween_property(card, "rotation", 0.07, 0.07)
	tw.tween_property(card, "rotation", -0.07, 0.09)
	tw.tween_property(card, "rotation", 0.0, 0.07)
	tw.tween_interval(0.4)
	# vuela a tus aumentos, arriba a la derecha
	var dest: Vector2 = cards_row.global_position + Vector2(cards_row.size.x - 8, 8)
	tw.tween_property(card, "position", dest - card.pivot_offset, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(card, "scale", Vector2(0.1, 0.1), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(card, "rotation", 0.8, 0.42)
	tw.parallel().tween_property(rays, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		sfx.play("clack", -6.0)
		_burst(dest, C_GOLD, 16))
	await tw.finished
	await get_tree().create_timer(0.15).timeout
	layer.queue_free()


## Chispas cuadradas que salen disparadas desde un punto.
func _burst(at: Vector2, col: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.9
	p.spread = 180.0
	p.direction = Vector2.UP
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 340.0
	p.gravity = Vector2(0, 420)
	p.damping_min = 40.0
	p.damping_max = 90.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(col, 1.0))
	ramp.set_color(1, Color(col, 0.0))
	p.color_ramp = ramp
	hud.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.3).timeout.connect(p.queue_free)


var _rays_cache := {}


## Rayos de luz alrededor de un centro (para los momentos épicos).
func _rays_tex(col: Color) -> ImageTexture:
	var key := col.to_html()
	if _rays_cache.has(key):
		return _rays_cache[key]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var v := Vector2(x - n / 2.0 + 0.5, y - n / 2.0 + 0.5)
			var r := v.length() / (n / 2.0)
			if r > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var ray: float = 1.0 if fmod(v.angle() + TAU, TAU / 14.0) < TAU / 28.0 else 0.25
			var a: float = ray * (1.0 - r) * (1.0 - r) + max(0.0, 0.5 - r) * 0.8
			img.set_pixel(x, y, Color(col, clamp(a, 0.0, 1.0)))
	var tex := ImageTexture.create_from_image(img)
	_rays_cache[key] = tex
	return tex


## +30 de los pases (y de la acusación falsa) en el centro de la pantalla:
## golpe, rayos que giran, chispas y el número volando al marcador.
func _epic_points(pts: int, why: String, seat: int) -> void:
	_epica_hasta_ms = Time.get_ticks_msec() + 2000
	var bajo := 240.0
	for f in floats:   # avisos recién salidos en el centro: bajan para dejarle sitio
		if f.t < 0.6 and f.pos.y > 95.0 and f.pos.y < 232.0:
			f.pos.y = bajo
			bajo += 18.0
		elif f.t < 0.6 and absf(f.pos.y - bajo) < 18.0:
			bajo = f.pos.y + 18.0
	var team := seat % 2
	var col: Color = C_GOLD if team == 0 else C_RED.lightened(0.25)
	var title: String = {"salida": "¡PASE DE SALIDA!", "corrido": "¡PASE CORRIDO! NADIE FUE", "acusado": "¡NO IBA! ACUSACIÓN FALSA"}.get(why, "")
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(layer)
	var center := Vector2(CX, 150)
	var rays := TextureRect.new()
	rays.texture = _rays_tex(col)
	rays.size = Vector2(300, 300)
	rays.position = center - rays.size / 2
	rays.pivot_offset = rays.size / 2
	rays.modulate.a = 0.0
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rays)
	var num := _lbl("+%d" % pts, 58, col)
	num.add_theme_constant_override("outline_size", 12)
	num.add_theme_color_override("font_outline_color", C_INK)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.size = Vector2(240, 80)
	num.position = center - num.size / 2
	num.pivot_offset = num.size / 2
	num.scale = Vector2(0.1, 0.1)
	layer.add_child(num)
	var sub := _lbl(title, 15, Color.WHITE)
	sub.add_theme_constant_override("outline_size", 6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(W, 24)
	sub.position = Vector2(0, center.y + 42)
	sub.pivot_offset = Vector2(CX, 12)
	sub.modulate.a = 0.0
	layer.add_child(sub)
	sfx.play("boom", -2.0, 0.0)
	get_tree().create_timer(0.12).timeout.connect(func(): sfx.play("win" if team == 0 else "lose", -6.0, 0.0))
	shake = max(shake, 9.0)
	flash = 0.6
	_burst(center, col, 90)
	_burst(center, Color(1, 1, 0.9), 40)
	var rt := rays.create_tween().set_parallel(true)
	rt.tween_property(rays, "modulate:a", 0.95, 0.12)
	rt.tween_property(rays, "rotation", 2.0, 1.9)
	rt.tween_property(rays, "scale", Vector2(1.25, 1.25), 1.9)
	var tw := num.create_tween()
	tw.tween_property(num, "scale", Vector2(1.45, 1.45), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(num, "rotation", -0.08, 0.2)
	tw.tween_property(num, "scale", Vector2.ONE, 0.14)
	tw.parallel().tween_property(num, "rotation", 0.0, 0.14)
	tw.parallel().tween_property(sub, "modulate:a", 1.0, 0.15)
	tw.tween_interval(0.9)
	# vuela al marcador de la pareja que lo gana
	var plate: Label = score_us if team == 0 else score_them
	var dest: Vector2 = plate.global_position + plate.size / 2
	tw.tween_property(num, "position", dest - num.pivot_offset, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(num, "scale", Vector2(0.25, 0.25), 0.45)
	tw.parallel().tween_property(sub, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(rays, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		sfx.play("coin", -4.0, 0.0)
		_burst(dest, col, 24)
		var pt := plate.create_tween()
		pt.tween_property(plate, "scale", Vector2(1.7, 1.7), 0.12)
		pt.tween_property(plate, "scale", Vector2.ONE, 0.25)
		layer.queue_free())


func _buy(id: String) -> void:
	if _tranque_pending:
		return
	if g.can_buy(0, id):
		sfx.play("coin", -6.0, 0.0)
		get_tree().create_timer(0.12).timeout.connect(func(): sfx.play("clink", -10.0))
	if online:
		red.enviar(Red.OP_COMPRAR, {"id": id})
		return
	g.buy(0, id)
	if g.phase == "shop":
		_build_shop()
	_refresh()


func _next_hand() -> void:
	if _tranque_pending:
		return
	_close_review()
	if online:
		red.enviar(Red.OP_LISTO)
		_wait_others("Esperando a los demás para la siguiente mano…")
		return
	g.new_hand()
	_refresh()


func _restart() -> void:
	if online:
		red.enviar(Red.OP_REVANCHA)
		return
	_clear_overlay()
	start_game(true)


# ---------------------------------------------------------------- partida online

## Avisos de la sala que manda el servidor: quién entra, se va o vuelve, y
## las frases del chat rápido (bocadillo sobre quien la dice).
func _avisos_sala(v: Dictionary) -> void:
	for e in v.get("events", []):
		var k: String = e.get("k", "")
		if k == "emote":
			_emote_recibido(e)
			continue
		if k == "golpe":
			_golpe_recibido(e)
			continue
		if k == "disparo":
			arma.evento_disparo(e)
			continue
		if k == "revive":
			continue
		if k == "colmadero":
			var cs := int(e.seat)
			view.colmadero.talk(1.5)
			view.colmadero.act("point")
			if cs == 0:
				_float("¡Respeten mi colmado! A tu silla", Vector2(CX, 120), C_RED.lightened(0.3))
				view.pie.sit_down(true)
			else:
				_float(tr("El colmadero manda a %s a su silla") % seat_names[cs], Vector2(CX, 120), C_CREAM)
			sfx.play("knock", -2.0)
			continue
		if k in ["revela", "amago", "entrega", "arrebata", "tq_ganador"]:
			tranque.evento(e)
			continue
		if k == "reclamo":
			if int(e.get("seat", 0)) != 0:
				_ver_reclamo(int(e.get("seat", 0)))
			continue
		if k.begins_with("silla_") or k.begins_with("equipo_"):
			_avisos_sillas(e)
			continue
		if not k in ["joined", "left", "back", "frase"]:
			continue
		var s := int(e.seat)
		var who: String = tr("Tú") if s == 0 else str(e.get("name", seat_names[s]))
		# sin personaje visible: encima de la mesa (en la sala de espera está vacía;
		# a 120 tapaba la cara y el nombre de tu pareja)
		var sitio := Vector2(CX, 200) if g.phase == "lobby" else Vector2(CX, 120)
		var p: Vector2 = view.seat_screen_pos(s) if view.heads[s] == null or s == 0 or view.heads[s].visible else sitio
		match k:
			"joined":
				if s != 0:
					_float(tr("¡%s se sentó!") % who, p, C_GOLD)
					sfx.play("knock", -6.0)
			"left":
				_float(tr("%s se fue · juega un bot") % who, p, C_CREAM)
			"back":
				if s != 0:
					_float(tr("%s volvió") % who, p, C_GOLD)
			"frase":
				_bocadillo(str(e.get("text", "")), s)
				if s != 0 and view.heads[s] != null:
					view.heads[s].talk(1.6)


## Emote de otro jugador: su personaje lo hace; si te empujan a ti, lo notas.
## Manotazo online: quien pega lanza el brazo; quien lo recibe se tambalea o
## cae al suelo (3 s). Si te lo dan a ti y caes, tu cámara va al suelo.
func _golpe_recibido(e: Dictionary) -> void:
	var s := int(e.seat)
	var t := int(e.get("target", -1))
	var cae: bool = e.get("cae", false)
	if s != 0 and view.heads[s] != null:
		view.heads[s].act("shove")
	sfx.play("slam", -4.0, 0.1)
	if t == 0:
		shake = max(shake, 6.0 if cae else 3.5)
		if cae:
			view.pie.knockdown(3.0)
			_float("¡Al suelo! Te levantas en un momento", Vector2(CX, 150), C_RED.lightened(0.3))
		else:
			var away: Vector2 = view.pie.pos - view.pie.person_pos(s)
			view.pie.vel += away.normalized() * 2.5
			_float(tr("¡%s te dio un manotazo!") % seat_names[s], Vector2(CX, 150), C_RED.lightened(0.3))
	elif t > 0 and view.heads[t] != null:
		if cae:
			view.heads[t].emotion("susto", 3.0)
			_float(tr("¡%s al suelo!") % seat_names[t], view.seat_screen_pos(t), C_GOLD)
			# los demás se ríen
			for k in [1, 2, 3]:
				if k != t and k != s and randf() < 0.7:
					var kk: int = k
					get_tree().create_timer(0.4 + randf() * 0.5).timeout.connect(func(): view.heads[kk].act("laugh"))
		else:
			view.heads[t].act("stagger")
			_float(tr("¡Ay!"), view.seat_screen_pos(t), C_CREAM)


func _emote_recibido(e: Dictionary) -> void:
	var s := int(e.seat)
	var id := str(e.get("id", ""))
	if id == "mesazo":
		view.bump_table(2.0)
		if s != 0:
			_float(tr("¡%s chocó con la mesa!") % seat_names[s], view.seat_screen_pos(s), C_CREAM)
		return
	# señalar un punto: su brazo apunta allí y se ve una marca en el suelo
	if id == "point" and e.has("px"):
		var pt := Vector3(float(e.px), 0.0, float(e.pz))
		view.point_marker(pt)
		if s != 0 and view.heads[s] != null:
			view.heads[s].point_at = pt
		if int(e.get("target", -1)) == 0:
			_float(tr("¡%s te señala!") % seat_names[s], Vector2(CX, 150), C_GOLD)
	if s != 0 and view.heads[s] != null:
		view.heads[s].act(id)
	if id == "choca" and e.has("target"):
		var tc := int(e.target)
		if tc == 0:
			_float(tr("¡%s choca contigo!") % seat_names[s], Vector2(CX, 150), C_GOLD)
			sfx.play("slam", -8.0, 0.1)
		elif tc > 0 and view.heads[tc] != null:
			view.heads[tc].act("choca")
	if id == "shove" and e.has("target"):
		var t := int(e.target)
		if t == 0:
			shake = max(shake, 5.0)
			sfx.play("knock", -2.0)
			_float("¡Te empujaron!", Vector2(CX, 150), C_RED.lightened(0.3))
			if view.pie.walking():
				var away: Vector2 = view.pie.pos - view.pie.person_pos(s)
				view.pie.vel += away.normalized() * 3.0
		elif view.heads[t] != null:
			view.heads[t].act("stagger")


func _bocadillo(texto: String, s: int) -> void:
	var p: Vector2 = view.seat_screen_pos(s) + Vector2(0, -36 if s != 0 else -60)
	var b := PanelContainer.new()
	b.add_theme_stylebox_override("panel", _box_style(C_CREAM, C_INK, 2, 3, 6))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _lbl(texto, 11, C_INK)
	l.add_theme_constant_override("outline_size", 0)
	b.add_child(l)
	hud.add_child(b)
	sfx.play("hover", -4.0, 0.15)
	# colocado ya con su tamaño (antes salía un fotograma arriba a la izquierda)
	b.reset_size()
	b.size = b.get_combined_minimum_size()
	b.position = (p - Vector2(b.size.x / 2, b.size.y)).clamp(Vector2(4, 40), Vector2(636, 300) - b.size)
	b.pivot_offset = b.size / 2
	b.scale = Vector2(0.6, 0.6)
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.4)
	tw.tween_property(b, "modulate:a", 0.0, 0.4)
	tw.tween_callback(b.queue_free)


func _toggle_chat() -> void:
	if is_instance_valid(chat_panel):
		chat_panel.queue_free()
		return
	sfx.play("card", -8.0)
	chat_panel = PanelContainer.new()
	chat_panel.add_theme_stylebox_override("panel", _box_style(Color(0.12, 0.07, 0.04, 0.92), C_WOOD, 2, 3, 6))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	chat_panel.add_child(grid)
	for f in FRASES:
		var b := Button.new()
		b.text = f[1]
		b.add_theme_font_size_override("font_size", 10)
		var id: String = f[0]
		b.pressed.connect(func():
			red.enviar(Red.OP_FRASE, {"id": id})
			chat_panel.queue_free())
		grid.add_child(b)
	hud.add_child(chat_panel)
	chat_panel.size = _ui_minimo(chat_panel)
	var y: float = 76.0 if g.phase == "lobby" else 320.0 - chat_panel.size.y
	chat_panel.position = Vector2(636 - chat_panel.size.x, y)


## Gestos sentado: bailar en la silla, aplaudir, señalar, saludar, estirarse.
## Online los ven todos; en local, los bots reaccionan.
func _toggle_emotes() -> void:
	if is_instance_valid(emote_panel):
		emote_panel.queue_free()
		return
	sfx.play("card", -8.0)
	emote_panel = PanelContainer.new()
	emote_panel.add_theme_stylebox_override("panel", _box_style(Color(0.12, 0.07, 0.04, 0.92), C_WOOD, 2, 3, 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	emote_panel.add_child(row)
	for e in EMOTES:
		var b := Button.new()
		b.icon = _icon(e[0], C_CREAM)
		b.tooltip_text = "%s (%s)" % [tr(e[1]), _key_name("gesto%d" % (EMOTES.find(e) + 1))]
		b.custom_minimum_size = Vector2(30, 28)
		b.expand_icon = true
		var id: String = e[0]
		b.pressed.connect(func():
			_seated_emote(id)
			if is_instance_valid(emote_panel):
				emote_panel.queue_free())
		row.add_child(b)
	hud.add_child(emote_panel)
	emote_panel.position = Vector2(emote_btn.position.x + emote_btn.size.x - emote_panel.get_combined_minimum_size().x, emote_btn.position.y - 40)


func _seated_emote(id: String) -> void:
	var e: Array = EMOTES.filter(func(x): return x[0] == id)
	if not e.is_empty():
		_float(tr(e[0][1]), view.seat_screen_pos(0) + Vector2(0, -40), C_GOLD)
	_emote(id)


## Online: segundos que quedan en el cartel del turno; últimos 5, en rojo y con tic.
func _tick_reloj() -> void:
	if not online or not turn_banner.visible or _turn_base == "":
		return
	if g.phase == "play" and online_v.get("reloj_parado", false):
		# le toca a alguien de pie: su reloj está parado (lo manda el servidor)
		_deadline_ms = Time.get_ticks_msec() + int(online_v.get("secs", 0)) * 1000
		turn_lbl.text = "%s · %s" % [tr(_turn_base), tr("reloj parado")]
		turn_lbl.add_theme_color_override("font_color", C_INK if g.turn == 0 or accesibilidad.daltonico else C_CREAM)
		return
	var left: int = maxi(0, ceili((_deadline_ms - Time.get_ticks_msec()) / 1000.0))
	var mine: bool = g.phase == "draw" or (g.phase == "play" and g.turn == 0)
	turn_lbl.text = "%s · %d s" % [tr(_turn_base), left]
	if mine and left <= 5 and left > 0:
		turn_lbl.add_theme_color_override("font_color", Accesibilidad.NARANJA if accesibilidad.daltonico else C_RED)
		if left != _tic_last:
			_tic_last = left
			sfx.play("hover", -6.0, 0.0)
	elif mine:
		turn_lbl.add_theme_color_override("font_color", C_INK)


# ---------------------------------------------------------------- tutorial

## Consejos del colmadero: la primera vez que pasa cada cosa (sin conexión) sale
## un cartel que lo explica jugando. Cada uno se ve una sola vez (perfil).
const CONSEJOS := {
	"aumentos": ["Aumentos", "Cada mano eliges una carta. Se acumulan durante toda la partida: piensa qué te conviene a la larga."],
	"robar": ["Robar", "Las fichas están boca abajo sobre la mesa. Toca las 7 que quieras."],
	"camara": ["Modo cámara", "Mueves la vista con el ratón y juegas con la mira del centro (clic o E). Mantén Alt para soltar el ratón y pulsar botones; Tab enseña la mesa desde arriba."],
	"turno": ["Tu turno", "Arrastra a una punta una ficha que case (o haz clic en ella). Gana la mano la pareja que se queda sin fichas."],
	"no_llevo": ["No llevas", "Ninguna ficha casa: toca PASO. También puedes meter un chivo (poner una que no casa), pero si el siguiente lo canta, perdéis la mano."],
	"cantar": ["¡Chivo!", "Si el jugador anterior puso una ficha que no casa, canta ¡CHIVO! y la mano es vuestra. Si pasó teniendo ficha, el botón dice ¡UTE VA!. Si cantas sin razón, pagas monedas."],
	"tienda": ["Bebidas", "Con las monedas que ganas compras bebidas. Cada una rompe una regla en tu turno: tócala en la mano para bebértela."],
	"beber": ["Tienes bebida", "Tus bebidas salen abajo cuando te toca. Tócala para bebértela antes de jugar."],
}
var _consejo_ui: Control = null
var _consejo_id := ""


func _consejos_activos() -> bool:
	if online:
		return false
	if OS.get_cmdline_user_args().has("--con-consejos"):   # para probarlos con el bot
		return playing
	if autotest or demo:
		return false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--prueba") or a == "--recorrido" or a == "--retratos":
			return false
	return playing


func _consejo_pendiente() -> String:
	var vistos: Array = menus.profile.get("consejos", [])
	var aum: bool = g.mode != "clasico"
	var mi_turno: bool = g.phase == "play" and g.turn == 0 and not busy and g.revision.is_empty() and not view.pie.standing()
	var orden := []
	if g.phase == "pick" and aum:
		orden.append("aumentos")
	if g.phase == "draw":
		orden.append("robar")
	if mi_turno and not OS.has_feature("mobile") and menus.settings.get("camara", true):
		orden.append("camara")
	if mi_turno:
		if g.chain.is_empty() or not g.legal_moves(0).is_empty():
			orden.append("turno")
		if not g.chain.is_empty():
			if g.legal_moves(0).is_empty():
				orden.append("no_llevo")
			elif vistos.has("turno"):
				orden.append("cantar")
		if aum and not g.drinks[0].is_empty():
			orden.append("beber")
	if g.phase == "shop" and aum:
		orden.append("tienda")
	for id in orden:
		if not vistos.has(id):
			return id
	return ""


func _tick_consejos() -> void:
	if is_instance_valid(_consejo_ui):
		# el momento ya pasó (cambió la fase o dejó de ser tu turno): se quita sin marcarlo
		if not _consejos_activos() or _consejo_pendiente() != _consejo_id:
			_consejo_ui.queue_free()
			_consejo_ui = null
		return
	if not _consejos_activos() or paused:
		return
	var id := _consejo_pendiente()
	if id != "":
		_show_consejo(id)


func _show_consejo(id: String) -> void:
	_consejo_id = id
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box_style(Color(0.12, 0.2, 0.16, 0.96), C_GOLD, 2, 3))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	var t := _lbl(func(): return tr("Consejo del colmadero") + " · " + tr(CONSEJOS[id][0]), 11, C_GOLD)
	v.add_child(t)
	var body := _lbl(CONSEJOS[id][1], 9, C_CREAM)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(250, 0)
	v.add_child(body)
	var ok := _yellow(Button.new())
	ok.text = "Entendido"
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.pressed.connect(func():
		var vistos: Array = menus.profile.get("consejos", [])
		if not vistos.has(id):
			vistos.append(id)
		menus.profile["consejos"] = vistos
		menus.save()
		sfx.play("clack", -6.0)
		if is_instance_valid(p):
			p.queue_free())
	v.add_child(ok)
	# capa propia, por encima de la elección de aumento y de los paneles
	var capa := CanvasLayer.new()
	capa.layer = 30
	add_child(capa)
	var raiz := Control.new()
	raiz.theme = theme_ui
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(raiz)
	raiz.add_child(p)
	p.tree_exited.connect(capa.queue_free)
	p.size = p.get_combined_minimum_size()
	# a la derecha, debajo del nombre del rival: no tapa la mesa ni tus fichas
	p.position = Vector2(W - p.size.x - 8, 96)
	if id == "tienda":   # en la tienda, arriba: abajo están las bebidas y los botones
		p.position = Vector2(CX - p.size.x / 2, 4)
	p.modulate.a = 0.0
	p.create_tween().tween_property(p, "modulate:a", 1.0, 0.25)
	_consejo_ui = p


## Juega una ficha que casa (online la manda al servidor).
func _act_play(t: Vector2i, side: int) -> void:
	if online:
		red.enviar(Red.OP_JUGAR, {"tile": [t.x, t.y], "side": side})
	elif not g.play(0, t, side):
		_float("Esa ficha no casa ahí", view.seat_screen_pos(0) + Vector2(0, -20), Color(1, 0.55, 0.45))


## Mete un chivo si se puede (mismas condiciones que game.gd).
func _act_chivo(t: Vector2i, side: int) -> bool:
	if not online:
		return g.play_chivo(0, t, side)
	if g.chain.is_empty() or g.hands[0].size() <= 1 or t.x == t.y or g.fits(t, side):
		return false
	red.enviar(Red.OP_JUGAR, {"tile": [t.x, t.y], "side": side})
	return true


## Cartel de espera mientras los demás deciden (online). Debajo, cuántos
## están listos («2 de 4 listos»); se actualiza en _process con cada estado.
var _wait_lbl: Label = null


func _wait_others(texto: String) -> void:
	_clear_overlay()
	_dim()
	var l := _lbl(texto, 13, C_GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, 160)
	l.size = Vector2(W, 20)
	overlay.add_child(l)
	_wait_lbl = _lbl("", 11, C_GOLD.lightened(0.3))
	_wait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wait_lbl.position = Vector2(0, 182)
	_wait_lbl.size = Vector2(W, 16)
	overlay.add_child(_wait_lbl)
	_update_wait_count()


## Cuántos están listos: al elegir aumento, los que ya eligieron (el servidor
## manda «picked»); en la tienda, los que pulsaron siguiente mano y los bots.
func _wait_ready_count() -> int:
	var n := 0
	var seats: Array = online_v.get("seats", [])
	var lista: Array = []
	if g.phase == "pick":
		lista = online_v.get("picked", []) if online_v.get("picked", []) is Array else []
	elif g.phase == "shop":
		lista = online_v.get("listos", []) if online_v.get("listos", []) is Array else []
	for k in lista.size():
		var bot: bool = k < seats.size() and seats[k] is Dictionary and seats[k].get("bot", false)
		if bool(lista[k]) or (g.phase == "shop" and bot):
			n += 1
	return n


func _update_wait_count() -> void:
	if not is_instance_valid(_wait_lbl):
		return
	_wait_lbl.text = tr("%d de 4 listos") % _wait_ready_count()
	# el reloj sigue a la vista mientras esperas a los demás (antes desaparecía)
	if online and g.phase in ["pick", "shop"] and _deadline_ms > 0:
		var left: int = maxi(0, ceili((_deadline_ms - Time.get_ticks_msec()) / 1000.0))
		_wait_lbl.text += "  ·  " + tr("quedan %d s") % left
		_wait_lbl.add_theme_color_override("font_color", C_RED.lightened(0.3) if left <= 5 else C_GOLD.lightened(0.3))


## Entra a la mesa en una sala online (ya conectado y dentro de la sala).
func start_online() -> void:
	view.mesa_activa = true
	menus.close()
	_close_review()
	online = true
	online_v = {}
	playing = true
	paused = false
	hud.visible = true
	sharp_rect.visible = true
	view.show_arms = true
	avatar = "custom"
	view.set_avatar_cfg(menus.profile)
	view.reset_table()
	view.cam_to("mesa", 1.1)
	g = ColmadoGame.new()
	g.phase = "lobby"
	ui_phase = ""
	my_picks = []
	_refresh()


var _reconectando := false


## Se cortó la conexión: primero se intenta volver a la misma sala (tu bot
## juega mientras); solo si no se puede, vuelta al colmado.
func _on_desconectado() -> void:
	if not (online and playing) or _reconectando:
		return
	_reconectando = true
	var aviso := _lbl("Se cortó la conexión · reconectando…", 13, C_GOLD)
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.size = Vector2(W, 20)
	aviso.position = Vector2(0, 96)
	hud.add_child(aviso)
	var err: String = await red.reconectar()
	if is_instance_valid(aviso):
		aviso.queue_free()
	_reconectando = false
	if not (online and playing):
		return
	if err == "":
		_float("¡De vuelta en la mesa!", Vector2(CX, 120), C_GOLD)
		return
	_float(err, Vector2(CX, 180), C_RED.lightened(0.3))
	await get_tree().create_timer(1.5).timeout
	quit_to_menu()


## Móvil: al volver de segundo plano (WhatsApp, copiar el código…) se
## comprueba la conexión y, si se cayó, se reconecta.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_translate_symbol_buttons(self)
	if what == NOTIFICATION_APPLICATION_RESUMED and online and playing and red != null and not red.conectado():
		_on_desconectado()


func _ficha(a) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1])) if a != null else Vector2i(-1, -1)


## Estado que manda el servidor: se copia en g (girado: tú eres la silla 0)
## y los eventos pasan por el mismo camino que en la partida local.
func _on_estado(v: Dictionary) -> void:
	if not online:
		return
	online_v = v
	red.comprobar_perfil(v)
	# Colmadón FM de la sala: todos en la misma pista y el mismo punto
	if v.get("radio") is Dictionary:
		var rd: Dictionary = v.radio
		radio.set_compartida(true)
		radio.sync_sala(bool(rd.get("on", true)), int(rd.get("pista", 0)), float(rd.get("t", 0.0)))
	chat_btn.visible = true
	_avisos_sala(v)
	_deadline_ms = Time.get_ticks_msec() + int(v.get("secs", 0)) * 1000
	# en la sala de espera, las sillas sin jugador están vacías (los bots se
	# sientan al empezar la partida)
	# (un amigo que acaba de entrar sin su aspecto todavía tampoco se ve: antes
	# salía un instante con la cara del bot de esa silla)
	for k in [1, 2, 3]:
		var sk: Dictionary = v.seats[k]
		var sin_cara: bool = not sk.bot and not (sk.avatar is Dictionary and sk.avatar.has("skin"))
		view.set_seat_empty(k, v.phase == "lobby" and (sk.bot or sin_cara))
	# nombres y caras de cada silla
	for k in 4:
		var st: Dictionary = v.seats[k]
		if k == 0:
			continue
		var nombre: String = st.name if st.name != "" else "…"
		if not st.bot and not st.connected:
			nombre = tr("%s (bot)") % nombre
		elif st.get("away", false):
			nombre = tr("%s (ausente)") % nombre
		seat_names[k] = nombre
		# aspecto del amigo si lo mandó completo; si no, la cara de bot de esa silla
		var cara = st.avatar if not st.bot and st.avatar is Dictionary and st.avatar.has("skin") else st.preset
		var sig := JSON.stringify(cara, "", true)
		if sig != _look_sig[k]:
			_look_sig[k] = sig
			view.set_seat_look(k, Red.look_de_json(cara) if cara is Dictionary else cara)
	# tu silla en la sala: el colmado se ve desde ella (el anfitrión mira al mostrador);
	# O06: también en la sala de espera, nada más entrar
	var yo := int(v.get("yo", 0))
	if yo != view.room_seat and not view.pie.standing():
		if _cambio_silla_propio and v.phase == "lobby":
			view.girar_sala(yo)   # te cambiaste de silla: el colmado gira hasta tu sitio nuevo
		else:
			view.set_room_seat(yo)
	_cambio_silla_propio = false
	if v.phase == "lobby":
		g.phase = "lobby"
		_refresh()
		if ui_phase == "lobby":
			_build_lobby()
		return
	g.phase = v.phase
	g.mode = str(v.get("modo", "aumentos"))
	g.last_pass_seat = int(v.get("last_pass_seat", -1))
	if g.hand_no != int(v.hand_no) or v.get("phase", "") == "draw":
		_mi_orden = []   # mano nueva: su orden empieza de cero
	g.hand_no = int(v.hand_no)
	g.first_hand = v.first_hand
	g.turn = int(v.turn)
	g.opener = int(v.opener)
	g.last_seat = int(v.last_seat)
	g.chain = v.chain.map(_ficha)
	g.origin = int(v.origin)
	g.target = int(v.get("meta", 100))
	# «¡Ute va!» en revisión (quien acusa ve las fichas del acusado)
	var rv = v.get("revision", null)
	if rv is Dictionary:
		g.revision = {"caller": int(rv.caller), "accused": int(rv.accused), "secs": int(rv.get("secs", 25))}
		if int(rv.caller) == 0 and not is_instance_valid(revision_ui):
			_deadline_rev_ms = Time.get_ticks_msec() + int(rv.get("secs", 25)) * 1000
	else:
		g.revision = {}
	g.left_end = int(v.left_end)
	g.right_end = int(v.right_end)
	g.scores = [int(v.scores[0]), int(v.scores[1])]
	g.coins = v.coins.map(func(x): return int(x))
	g.cards = v.cards.map(func(x): return Array(x))
	g.drinks = v.drinks.map(func(x): return Array(x))
	g.offers[0] = Array(v.offers)
	g.reveal_partner = v.reveal_partner
	g.revealed = v.revealed.map(_ficha)
	g.extra_turn = v.extra_turn
	g.hands = v.hands.map(func(h): return h.map(_ficha))
	_respetar_orden()
	# pases que recuerda este jugador (con Ficha marcada, todos los de los rivales)
	var pases: Array = v.get("pases", [[], [], [], []])
	for k in 4:
		var d := {}
		for n in pases[k]:
			d[int(n)] = true
		g.lacks[k] = d
		g.last_pass[k] = d
	if v.has("last_result"):
		var lr: Dictionary = v.last_result
		g.last_result = {"seat": int(lr.seat), "team": int(lr.team), "pts": int(lr.pts), "reason": lr.reason, "bonus": Array(lr.bonus), "capicua": lr.capicua}
	g.bot_purchases = v.bot_purchases.map(func(b): return [int(b[0]), b[1]])
	var st := {}
	for k2 in v.stats:
		st[k2] = [int(v.stats[k2][0]), int(v.stats[k2][1])]
	g.stats = st
	# robar: fichas que se lleva cada uno del montón (cuando ya está en la mesa)
	if g.phase == "draw" and not view.animating:
		# en el orden en que se cogieron (como el servidor arma las manos)
		var orden: Array = v.get("robo_orden", [])
		if orden.size() != v.pool_taken.size():
			orden = v.pool_taken.keys()
		var huecos := {}
		for key in orden:
			var idx := int(key)
			var seat := int(v.pool_taken[str(idx)])
			var slot: int = huecos.get(seat, 0)
			huecos[seat] = slot + 1
			if not view.pool_taken.has(idx):
				# las tuyas llegan de cara (el servidor solo te enseña las tuyas)
				var mias: Dictionary = v.get("mis_robo", {})
				if seat == 0 and mias.has(str(idx)):
					view.pool_cara(idx, Vector2i(int(mias[str(idx)][0]), int(mias[str(idx)][1])))
				view.take_pool_tile(idx, seat, slot)
				if seat == 0 and view.pool_taken.has(idx):
					my_picks.append(idx)
	elif g.phase != "draw":
		my_picks = []
	for e in v.events:
		var ev: Dictionary = e.duplicate()
		ev.seat = int(ev.seat)
		for k3 in ["by", "cheater", "pts", "side", "accused", "level"]:
			if ev.has(k3):
				ev[k3] = int(ev[k3])
		if ev.has("tile"):
			ev.tile = _ficha(ev.tile)
		if ev.has("hand"):
			ev.hand = Array(ev.hand).map(_ficha)
		if not ev.k in ["draw", "joined", "left", "back", "frase", "emote", "revela", "amago", "entrega", "arrebata", "tq_ganador", "reclamo"] and not ev.k.begins_with("silla_") and not ev.k.begins_with("equipo_"):
			g.events.append(ev)
	_refresh()


## Sala de espera: es la propia mesa. El panel se monta una vez y luego solo se
## actualiza con cada estado (antes se rehacía entero y parpadeaba).
var _lobby_sig := ""   # se vacía para forzar montarlo de nuevo


var _code_visible := false   # O02: el código de la sala, tapado hasta pulsar «Ver código»
var _lobby: Dictionary = {}   # nodos del panel de la sala (se actualizan sin rehacerlo)
var _team_edit: LineEdit = null
var _team_sig := ""
var _seat_btns: Array = [null, null, null, null]   # «Sentarme aquí» sobre cada silla
var _ready_tags: Array = [null, null, null, null]   # «✓ LISTO» sobre cada silla
var _peticion_ui: Control = null
var _peticion_sig := ""


## Nombres de equipo de la sala (O11 + acuerdo): [el tuyo, el rival].
func _lobby_nombres() -> Array:
	var ns = online_v.get("nombres", [])
	if ns is Array and ns.size() == 2:
		return ns
	return [{"estado": "vacio", "nombre": "", "propone": -1, "turno": -1, "rechazado": "", "humanos": 1},
		{"estado": "vacio", "nombre": "", "propone": -1, "turno": -1, "rechazado": "", "humanos": 0}]


func _send_team_name() -> void:
	if not is_instance_valid(_team_edit) or not online or g.phase != "lobby":
		return
	var t := _team_edit.text.strip_edges()
	if t == "":
		_float("Escribe un nombre para tu pareja", Vector2(CX, 200), C_GOLD)
		return
	# reglamento S5: los dos equipos no pueden llamarse igual
	var eq: Array = online_v.get("equipos", ["", ""])
	if eq.size() > 1 and str(eq[1]).to_lower() == t.to_lower():
		_float(tr("Ese nombre ya lo tienen los rivales"), Vector2(CX, 200), C_CREAM)
		sfx.play("knock", -6.0)
		return
	red.enviar(Red.OP_EQUIPO, {"name": t})
	sfx.play("chalk", -6.0)


func _build_lobby() -> void:
	var v := online_v
	if v.is_empty():
		return  # aún no llegó el primer estado de la sala
	if _lobby_sig != "" and _lobby.has("panel") and is_instance_valid(_lobby.panel):
		_refresh_lobby()
		return
	_clear_overlay()
	_lobby_sig = "montado"
	_lobby = {}
	_team_sig = ""
	_peticion_sig = ""
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box_style(C_GOLD, C_INK, 3, 5, 6))
	p.custom_minimum_size.y = 113   # alto fijo: no crece con la fila del nombre del equipo
	overlay.add_child(p)
	_lobby.panel = p
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 3)
	p.add_child(col)
	# fila de arriba: quién hay (cuatro sillas) y el código, tapado (O02, streamers)
	var arriba := HBoxContainer.new()
	arriba.alignment = BoxContainer.ALIGNMENT_CENTER
	arriba.add_theme_constant_override("separation", 6)
	col.add_child(arriba)
	var sillas := HBoxContainer.new()
	sillas.add_theme_constant_override("separation", 2)
	sillas.mouse_filter = Control.MOUSE_FILTER_PASS
	sillas.tooltip_text = tr("Personas en la sala. Si faltan, los bots juegan las sillas libres.")
	arriba.add_child(sillas)
	var puntos: Array = []
	for k in 4:
		var pt := ColorRect.new()
		pt.custom_minimum_size = Vector2(7, 7)
		pt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sillas.add_child(pt)
		puntos.append(pt)
	_lobby.puntos = puntos
	var info := _lbl("", 10, C_INK)
	info.add_theme_constant_override("outline_size", 0)
	info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sillas.add_child(info)
	_lobby.info = info
	arriba.add_child(_lobby_sep())
	var code := _lbl("", 13, C_INK)
	code.add_theme_constant_override("outline_size", 0)
	code.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	code.custom_minimum_size = Vector2(84, 0)
	code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arriba.add_child(code)
	_lobby.code = code
	var ver := Button.new()
	ver.icon = _icon("eye", C_CREAM)
	ver.focus_mode = Control.FOCUS_NONE
	ver.pressed.connect(func():
		_code_visible = not _code_visible
		_refresh_lobby())
	arriba.add_child(ver)
	_lobby.ver = ver
	var copy := Button.new()
	copy.text = tr("¡Copiado!")
	copy.custom_minimum_size.x = copy.get_combined_minimum_size().x   # sitio para «¡Copiado!»: no crece al pulsarlo
	copy.text = "Copiar"
	copy.focus_mode = Control.FOCUS_NONE
	copy.tooltip_text = tr("Copia el código para pasárselo a tus amigos")
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(str(online_v.get("code", "")))
		sfx.play("card", -6.0)
		copy.text = "¡Copiado!")
	arriba.add_child(copy)
	col.add_child(_chalk_rule())
	# nombre de tu pareja (se acuerda entre los dos) y el de los rivales
	var equipos := HBoxContainer.new()
	equipos.alignment = BoxContainer.ALIGNMENT_CENTER
	equipos.add_theme_constant_override("separation", 8)
	col.add_child(equipos)
	var team := VBoxContainer.new()
	team.add_theme_constant_override("separation", 2)
	equipos.add_child(team)
	_lobby.team = team
	var rival := _lbl("", 10, Color(C_INK, 0.75))
	rival.add_theme_constant_override("outline_size", 0)
	rival.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	equipos.add_child(rival)
	_lobby.rival = rival
	col.add_child(_chalk_rule())
	# abajo: LISTO (con cuántos lo están), ¡A JUGAR! del anfitrión y salir
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var listo := Button.new()
	listo.toggle_mode = true
	listo.custom_minimum_size = Vector2(104, 26)   # sitio para «✓ LISTO 4/4»
	listo.add_theme_font_size_override("font_size", 12)
	listo.pressed.connect(func():
		var yo_listo: bool = bool(online_v.get("listos_sala", [false])[0])
		red.enviar(Red.OP_LISTO_SALA, {"on": not yo_listo})
		sfx.play("clack", -6.0))
	row.add_child(listo)
	_lobby.listo = listo
	var cuenta := _lbl("", 9, C_INK)   # (queda para quien la lea; el número va en el botón)
	cuenta.visible = false
	row.add_child(cuenta)
	_lobby.cuenta = cuenta
	var go := _yellow(Button.new())
	go.text = "¡A JUGAR!"
	go.add_theme_font_size_override("font_size", 13)
	go.add_theme_stylebox_override("disabled", _box_style(Color(0.6, 0.55, 0.4), Color(C_INK, 0.6), 2, 4))
	go.add_theme_color_override("font_disabled_color", Color(C_INK, 0.5))
	go.pressed.connect(func():
		if not bool(online_v.get("todos_listos", false)):
			return
		sfx.play("clack", -4.0)
		red.enviar(Red.OP_EMPEZAR))
	row.add_child(go)
	_lobby.go = go
	var espera := _lbl("", 10, C_INK)
	espera.add_theme_constant_override("outline_size", 0)
	# sitio reservado: al salir «Esperando al anfitrión…» no empuja LISTO ni la casita
	espera.custom_minimum_size.x = espera.get_theme_font("font").get_string_size(tr("Esperando al anfitrión…"), HORIZONTAL_ALIGNMENT_LEFT, -1, espera.get_theme_font_size("font_size")).x + 2
	row.add_child(espera)
	_lobby.espera = espera
	var out := Button.new()
	out.icon = _icon("home", C_CREAM)
	out.focus_mode = Control.FOCUS_NONE
	out.tooltip_text = tr("Volver a la pizarra: sales de la sala (para cambiar modo, meta o tu personaje)")
	out.pressed.connect(func(): quit_to_menu("amigos"))
	row.add_child(out)
	var hueco := Control.new()   # el borde de abajo del panel es grueso: que no pise los botones
	hueco.custom_minimum_size = Vector2(0, 3)
	col.add_child(hueco)
	# siempre centrado y apoyado abajo, crezca o encoja (sin ocultarlo: parpadeaba)
	p.resized.connect(func(): p.position = Vector2(CX - p.size.x / 2, minf(226, 352 - p.size.y)))
	# «Sentarme aquí» y «✓ LISTO» sobre cada silla
	for k in [1, 2, 3]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 9)
		b.add_theme_stylebox_override("normal", _box_style(Color(0.1, 0.42, 0.4, 0.92), C_INK, 1, 2, 3))
		b.add_theme_stylebox_override("hover", _box_style(Color(0.14, 0.55, 0.52), C_GOLD, 1, 2, 3))
		b.pressed.connect(_pedir_silla.bind(k))
		b.mouse_entered.connect(func(): sfx.play("hover", -12.0, 0.0))
		overlay.add_child(b)
		# el más largo de «Sentarme aquí» / «Pedir su silla»: no cambia al sentarse alguien
		for t_largo in [tr("Sentarme aquí"), tr("Pedir su silla")]:
			b.text = "⇄ " + t_largo
			b.custom_minimum_size.x = maxf(b.custom_minimum_size.x, b.get_combined_minimum_size().x)
		_seat_btns[k] = b
		var tag := _lbl("", 9, C_CREAM)
		tag.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(tag)
		_ready_tags[k] = tag
	_refresh_lobby()
	p.reset_size()
	p.position = Vector2(CX - p.size.x / 2, minf(226, 352 - p.size.y))


## Separador vertical entre los dos lados de una fila del panel.
func _lobby_sep() -> Control:
	var r := ColorRect.new()
	r.color = Color(C_INK, 0.25)
	r.custom_minimum_size = Vector2(1, 14)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


func _chalk_rule() -> Control:
	var r := ColorRect.new()
	r.color = Color(C_INK, 0.25)
	r.custom_minimum_size = Vector2(0, 1)
	return r


## Actualiza el panel con el último estado (sin rehacerlo).
func _refresh_lobby() -> void:
	if not _lobby.has("panel") or not is_instance_valid(_lobby.panel):
		return
	var v := online_v
	var host: bool = v.get("me_host", false)
	_lobby.code.text = " ".join(str(v.get("code", "------")).split("")) if _code_visible else "• • • • • •"
	_lobby.ver.tooltip_text = tr("Ocultar código") if _code_visible else tr("Ver código")
	var humanos := 0
	for st in v.seats:
		if not st.bot:
			humanos += 1
	_lobby.info.text = "%d/4" % humanos
	for k in 4:
		_lobby.puntos[k].color = C_INK if k < humanos else Color(C_INK, 0.2)
	_refresh_team()
	var ns := _lobby_nombres()
	var riv: Dictionary = ns[1]
	if int(riv.get("humanos", 0)) == 0:
		_lobby.rival.text = tr("vs %s") % tr("ELLOS")
	elif riv.estado == "aceptado":
		_lobby.rival.text = tr("vs %s") % str(riv.nombre)
	else:
		_lobby.rival.text = tr("vs …")
	_lobby.rival.tooltip_text = tr("Los rivales aún eligen su nombre") if riv.estado != "aceptado" and int(riv.get("humanos", 0)) > 0 else tr("Vuestros rivales")
	_lobby.rival.mouse_filter = Control.MOUSE_FILTER_PASS
	# listos
	var listos: Array = v.get("listos_sala", [false, false, false, false])
	var n_listos := 0
	for k in 4:
		if not v.seats[k].bot and k < listos.size() and listos[k]:
			n_listos += 1
	_lobby.cuenta.text = tr("Listos %d de %d") % [n_listos, humanos]
	var yo_listo: bool = listos.size() > 0 and bool(listos[0])
	var puedo: bool = ns[0].estado == "aceptado"
	var lb: Button = _lobby.listo
	lb.set_pressed_no_signal(yo_listo)
	lb.disabled = not puedo
	lb.text = (tr("✓ LISTO") if yo_listo else tr("LISTO")) + "  %d/%d" % [n_listos, humanos]
	lb.tooltip_text = tr("Primero acordad el nombre de tu pareja") if not puedo else (tr("Pulsa otra vez si aún no estás listo") if yo_listo else tr("Avisa de que estás listo para jugar"))
	if yo_listo:
		lb.add_theme_stylebox_override("normal", _box_style(Color(0.25, 0.62, 0.3), C_INK, 2, 3))
		lb.add_theme_stylebox_override("pressed", _box_style(Color(0.25, 0.62, 0.3), C_INK, 2, 3))
		lb.add_theme_color_override("font_color", C_CREAM)
		lb.add_theme_color_override("font_pressed_color", C_CREAM)
	else:
		for st_name in ["normal", "pressed"]:
			lb.remove_theme_stylebox_override(st_name)
		lb.remove_theme_color_override("font_color")
		lb.remove_theme_color_override("font_pressed_color")
	# ¡A JUGAR!: solo el anfitrión, y habilitado cuando todos están listos
	var todos: bool = v.get("todos_listos", false)
	_lobby.go.visible = host
	_lobby.go.disabled = not todos
	_lobby.espera.visible = not host
	if host:
		var faltan: Array = []
		for k in 4:
			if not v.seats[k].bot and not (k < listos.size() and listos[k]):
				faltan.append(tr("Tú") if k == 0 else str(v.seats[k].name))
		_lobby.go.tooltip_text = tr("Todos listos: ¡a jugar!") if todos else tr("Faltan por estar listos: %s") % ", ".join(faltan)
	else:
		_lobby.espera.text = tr("Esperando al anfitrión…") if todos else ""
		_lobby.espera.visible = todos
	_refresh_peticion()
	# encoge o crece con lo que muestra (el nombre cambia de una fila a dos)
	_lobby.panel.reset_size()


## La parte del nombre de tu pareja: se rehace solo si cambia su estado.
func _refresh_team() -> void:
	var ns := _lobby_nombres()
	var me: Dictionary = ns[0]
	var sig := JSON.stringify(me)
	if sig == _team_sig and _lobby.team.get_child_count() > 0:
		return
	_team_sig = sig
	var box: VBoxContainer = _lobby.team
	var texto_previo := _team_edit.text if is_instance_valid(_team_edit) else ""
	for c in box.get_children():
		box.remove_child(c)   # fuera ya: si no, el panel no encoge hasta el fotograma siguiente
		c.queue_free()
	_team_edit = null
	var estado := str(me.get("estado", "vacio"))
	var propone := int(me.get("propone", -1))
	var turno := int(me.get("turno", -1))
	var nombre := str(me.get("nombre", ""))
	var rechazado := str(me.get("rechazado", ""))
	var solo: bool = int(me.get("humanos", 1)) < 2
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 6)
	box.add_child(fila)
	var nota := _lbl("", 9, Color(C_INK, 0.8))
	nota.add_theme_constant_override("outline_size", 0)
	nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nota.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	match estado:
		"aceptado":
			var l := _lbl(nombre, 12, C_INK)
			l.add_theme_constant_override("outline_size", 0)
			l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			fila.add_child(l)
			fila.add_child(_icon_rect(_lock_icon(), 10))
			l.tooltip_text = tr("Nombre acordado: ya no se cambia") if not solo else tr("Nombre puesto: ya no se cambia")
			l.mouse_filter = Control.MOUSE_FILTER_PASS
		"propuesto":
			if propone == 0:
				var l2 := _lbl("«%s» …" % nombre, 11, C_INK)
				l2.add_theme_constant_override("outline_size", 0)
				l2.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
				fila.add_child(l2)
				l2.tooltip_text = tr("Esperando a que tu pareja diga si le gusta…")
				l2.mouse_filter = Control.MOUSE_FILTER_PASS
				_pulso(l2)
			else:
				var l3 := _lbl("¿«%s»?" % nombre, 11, C_INK)
				l3.tooltip_text = tr("Tu pareja propone este nombre. Si dices que no, te toca proponer a ti")
				l3.mouse_filter = Control.MOUSE_FILTER_PASS
				l3.add_theme_constant_override("outline_size", 0)
				l3.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
				fila.add_child(l3)
				var si := _yellow(Button.new())
				si.text = "✓"
				si.tooltip_text = tr("Me gusta")
				si.pressed.connect(func():
					red.enviar(Red.OP_EQUIPO_RESP, {"ok": true})
					sfx.play("win", -10.0, 0.0))
				fila.add_child(si)
				var no := Button.new()
				no.text = "✗"
				no.tooltip_text = tr("No me gusta: te toca a ti proponer uno")
				no.pressed.connect(func():
					red.enviar(Red.OP_EQUIPO_RESP, {"ok": false})
					sfx.play("knock", -8.0))
				fila.add_child(no)
				_aparecer(fila)
		_:
			if turno >= 0 and turno != 0:
				var l4 := _lbl(tr("Tu pareja elige el nombre…"), 10, C_INK)
				l4.add_theme_constant_override("outline_size", 0)
				fila.add_child(l4)
				_pulso(l4)
				if rechazado != "":
					l4.tooltip_text = tr("No te gustó «%s»: ahora propone tu pareja") % rechazado
					l4.mouse_filter = Control.MOUSE_FILTER_PASS
			else:
				_team_edit = LineEdit.new()
				_team_edit.max_length = 8
				_team_edit.placeholder_text = tr("Nombre del equipo")
				_team_edit.tooltip_text = tr("Antes de LISTO, poned nombre a vuestra pareja (máx. 8 letras)")
				_team_edit.custom_minimum_size = Vector2(126, 0)   # que quepa «Nombre del equipo»
				_team_edit.add_theme_font_size_override("font_size", 10)
				_team_edit.text = texto_previo
				_team_edit.text_submitted.connect(func(_t): _send_team_name())
				fila.add_child(_team_edit)
				var ok := _yellow(Button.new())
				ok.text = "✓"
				ok.tooltip_text = tr("Proponer: tu pareja tendrá que aceptarlo") if not solo else tr("Confirmar: tu pareja es un bot, vale al momento")
				ok.pressed.connect(_send_team_name)
				fila.add_child(ok)
				if rechazado != "":
					nota.text = tr("No le gustó «%s»: otro") % rechazado
	if nota.text != "":
		box.add_child(nota)


## Candado pequeño (nombre fijo), dibujado en código como los demás iconos.
func _lock_icon() -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var ink := C_INK
	for x in range(2, 6):
		img.set_pixel(x, 0, ink)
	for y in range(1, 4):
		img.set_pixel(1, y, ink)
		img.set_pixel(6, y, ink)
	for y in range(3, 8):
		for x in range(0, 8):
			img.set_pixel(x, y, ink)
	img.set_pixel(3, 5, C_GOLD)
	img.set_pixel(4, 5, C_GOLD)
	return ImageTexture.create_from_image(img)


## Latido suave para lo que espera (sin destellos).
func _pulso(c: CanvasItem) -> void:
	var tw := c.create_tween().set_loops()
	tw.tween_property(c, "modulate:a", 0.55, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)


## Entrada con un pequeño rebote (lo nuevo que pide respuesta).
func _aparecer(c: Control) -> void:
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.2)


## Pides la silla k (local): libre = te sientas; de una persona = se lo pides.
var _silla_pedida_t := -10.0


func _pedir_silla(k: int) -> void:
	if not online or g.phase != "lobby":
		return
	# muchos clics seguidos: uno por cambio (el giro dura ~1 s)
	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora - _silla_pedida_t < 1.2:
		return
	_silla_pedida_t = ahora
	red.enviar(Red.OP_SILLA, {"seat": k})
	sfx.play("chair", -6.0)


## Botones de las sillas y «✓ LISTO» de cada uno: cada fotograma, sobre su silla.
func _tick_lobby_sillas() -> void:
	if g.phase != "lobby" or not online or not _lobby.has("panel") or not is_instance_valid(_lobby.panel):
		return
	var v := online_v
	var listos: Array = v.get("listos_sala", [])
	var pet = v.get("peticion", null)
	var hay_pet: bool = pet is Dictionary
	for k in [1, 2, 3]:
		var b: Button = _seat_btns[k]
		var tag: Label = _ready_tags[k]
		if not is_instance_valid(b) or not is_instance_valid(tag):
			continue
		var st: Dictionary = v.seats[k]
		var pos: Vector2 = view.seat_screen_pos(k)
		b.text = ("⇄ " + tr("Sentarme aquí")) if st.bot else ("⇄ " + tr("Pedir su silla"))
		b.tooltip_text = tr("Silla libre: te sientas al momento") if st.bot else tr("%s tendrá que aceptar el cambio") % str(st.name)
		b.visible = not hay_pet and not view.pie.standing()
		b.size = b.get_combined_minimum_size()
		# las sillas libres: el botón donde estaría la cabeza; las ocupadas, debajo del nombre
		# siempre por encima del panel de la sala
		var techo: float = _lobby.panel.position.y - b.size.y - 4
		b.position = (pos + Vector2(-b.size.x / 2, 8 if st.bot else 14)).clamp(Vector2(4, 40), Vector2(636 - b.size.x, techo))
		var esta: bool = not st.bot and k < listos.size() and listos[k]
		tag.visible = not st.bot
		tag.text = tr("✓ LISTO") if esta else tr("… no listo")
		tag.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55) if esta else Color(C_CREAM, 0.7))
		tag.size = tag.get_combined_minimum_size()
		tag.position = Vector2(b.position.x + (b.size.x - tag.size.x) / 2, b.position.y - tag.size.y)
	# mientras la cámara gira (cambio de silla) dos sillas pueden caer en el mismo
	# sitio de la pantalla: esos botones se esconden hasta que se separan
	for i in [1, 2, 3]:
		for j in range(i + 1, 4):
			var bi: Button = _seat_btns[i]
			var bj: Button = _seat_btns[j]
			if is_instance_valid(bi) and is_instance_valid(bj) and bi.visible and bj.visible 					and bi.get_rect().intersects(bj.get_rect()):
				bi.visible = false
				bj.visible = false
				_ready_tags[i].visible = false
				_ready_tags[j].visible = false


## Cambio de silla pendiente: a quien se lo piden, tarjeta con Aceptar/Rechazar y
## cuenta atrás; a quien pidió, «esperando…»; a los demás, quién pide a quién.
func _refresh_peticion() -> void:
	var pet = online_v.get("peticion", null)
	var sig := JSON.stringify(pet) if pet is Dictionary else ""
	if pet is Dictionary:
		sig = str(int(pet.de), int(pet.a))   # los segundos los cuenta _tick_peticion
	if sig == _peticion_sig and (sig == "" or is_instance_valid(_peticion_ui)):
		return
	_peticion_sig = sig
	if is_instance_valid(_peticion_ui):
		_peticion_ui.queue_free()
	_peticion_ui = null
	if not pet is Dictionary:
		return
	var de := int(pet.de)
	var a := int(pet.a)
	var nombre_de: String = tr("Tú") if de == 0 else seat_names[de]
	var nombre_a: String = tr("ti") if a == 0 else seat_names[a]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box_style(Color(0.12, 0.2, 0.16, 0.97), C_GOLD, 2, 4, 5))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	var titulo := ""
	if a == 0:
		titulo = tr("%s quiere sentarse en tu silla") % nombre_de
	elif de == 0:
		titulo = tr("Esperando a que %s acepte el cambio…") % seat_names[a]
	else:
		titulo = tr("%s pide la silla de %s") % [nombre_de, nombre_a]
	var l := _lbl(titulo, 11, C_GOLD)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	if a == 0:
		var sub := _lbl(tr("Os cambiáis de silla (y de pareja si cambia el lado)"), 9, C_CREAM)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sub)
	var barra := ProgressBar.new()
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(220, 5)
	barra.max_value = float(pet.get("total", 15))
	barra.value = float(pet.get("secs", 15))
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0, 0, 0, 0.4)
	var lleno := StyleBoxFlat.new()
	lleno.bg_color = C_GOLD
	barra.add_theme_stylebox_override("background", fondo)
	barra.add_theme_stylebox_override("fill", lleno)
	v.add_child(barra)
	if a == 0:
		var fila := HBoxContainer.new()
		fila.alignment = BoxContainer.ALIGNMENT_CENTER
		fila.add_theme_constant_override("separation", 10)
		v.add_child(fila)
		var si := _yellow(Button.new())
		si.text = "Aceptar ✓"
		si.pressed.connect(func():
			red.enviar(Red.OP_SILLA_RESP, {"ok": true})
			sfx.play("clack", -6.0))
		fila.add_child(si)
		var no := Button.new()
		no.text = "Rechazar ✗"
		no.pressed.connect(func():
			red.enviar(Red.OP_SILLA_RESP, {"ok": false})
			sfx.play("knock", -8.0))
		fila.add_child(no)
		sfx.play("knock", -2.0)
	overlay.add_child(p)
	p.reset_size()
	p.position = Vector2(CX - p.size.x / 2, 34)
	p.pivot_offset = p.size / 2
	p.scale = Vector2(0.85, 0.85)
	p.modulate.a = 0.0
	var tw := p.create_tween().set_parallel()
	tw.tween_property(p, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	_peticion_ui = p
	p.set_meta("barra", barra)
	p.set_meta("hasta", Time.get_ticks_msec() + int(pet.get("secs", 15)) * 1000)


## La barra de la petición baja sola entre estados.
func _tick_peticion() -> void:
	if not is_instance_valid(_peticion_ui):
		return
	var barra: ProgressBar = _peticion_ui.get_meta("barra")
	barra.value = maxf(0.0, (int(_peticion_ui.get_meta("hasta")) - Time.get_ticks_msec()) / 1000.0)


## Avisos de la sala sobre sillas y nombres (llegan como eventos).
func _avisos_sillas(e: Dictionary) -> void:
	var k: String = e.get("k", "")
	var s := int(e.get("seat", 0))
	var t := int(e.get("target", -1))
	var quien: String = tr("Tú") if s == 0 else str(online_v.seats[s].name) if s < online_v.get("seats", []).size() else ""
	match k:
		"equipo_pide":
			if s != 0:
				_float(tr("Tu pareja propone «%s»") % str(e.get("name", "")), Vector2(CX, 200), C_GOLD)
				sfx.play("chalk", -4.0)
		"equipo_repetido":
			if s == 0:
				_float(tr("Ese nombre ya lo tienen los rivales"), Vector2(CX, 200), C_CREAM)
				sfx.play("knock", -6.0)
		"equipo_no":
			if t == 0:
				_float(tr("A tu pareja no le gustó «%s»") % str(e.get("name", "")), Vector2(CX, 200), C_CREAM)
				sfx.play("knock", -6.0)
		"equipo_ok":
			if s == 0 or s == 2:
				_float(tr("¡Equipo %s!") % str(e.get("name", "")), Vector2(CX, 190), C_GOLD)
				sfx.play("win", -8.0, 0.0)
		"silla_pide":
			if t != 0 and s != 0:
				sfx.play("knock", -10.0)
		"silla_no":
			if s == 0:
				_float(tr("No respondió a tiempo") if e.get("tarde", false) else tr("%s prefiere quedarse en su silla") % (seat_names[t] if t >= 0 and t < 4 else ""), Vector2(CX, 200), C_CREAM)
		"silla_mov", "silla_cambio":
			# s = dónde está ahora quien se movió, t = de dónde venía (o con quién cambió)
			if s == 0 or t == 0:
				_cambio_silla_propio = true   # el giro del colmado lo hace set_room_seat
			else:
				call_deferred("_salto_silla", s)   # después de poner su aspecto en la silla nueva
				call_deferred("_salto_silla", t)
				_float(tr("%s se cambió de silla") % quien, Vector2(CX, 200), C_CREAM)
			sfx.play("chair", -4.0)


var _cambio_silla_propio := false


## Quien se sienta en otra silla: se levanta y se vuelve a sentar con un saltito.
func _salto_silla(k: int) -> void:
	if k <= 0 or k > 3 or view.heads[k] == null:
		return
	var h: Node3D = view.heads[k]
	var y0 := h.position.y
	var tw := h.create_tween()
	tw.tween_property(h, "position:y", y0 + 0.12, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(h, "position:y", y0, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- dibujo

func _draw() -> void:
	# de pie con el ratón capturado: punto de mira (dorado si apuntas a tu silla)
	if cam_mode:
		var cc := Vector2(CX, 180)
		var sobre: bool = view.hover_index >= 0 or _press_i >= 0 or _dragging or arma.apunta_lap(cc)
		draw_circle(cc, 2.2, Color(C_INK, 0.6))
		draw_circle(cc, 1.3, C_GOLD if sobre else Color(C_CREAM, 0.9))
		if sobre:
			draw_arc(cc, 6.0, 0, TAU, 24, Color(C_INK, 0.6), 2.5)
			draw_arc(cc, 6.0, 0, TAU, 24, C_GOLD, 1.2)
	if view.pie.mode == "de_pie" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not paused:
		var c := Vector2(CX, 180)
		if _chair_aim:
			draw_arc(c, 5.0, 0, TAU, 20, Color(C_INK, 0.7), 3.0)
			draw_arc(c, 5.0, 0, TAU, 20, C_GOLD, 1.5)
		else:
			draw_circle(c, 2.0, Color(C_INK, 0.6))
			draw_circle(c, 1.2, Color(C_CREAM, 0.85))
	if _joy_id != -2 and view.pie.standing():
		draw_circle(_joy_center, 40.0, Color(0, 0, 0, 0.25))
		draw_arc(_joy_center, 40.0, 0, TAU, 32, Color(C_CREAM, 0.6), 2.0)
		draw_circle(_joy_center + _joy_vec * 40.0, 14.0, Color(C_GOLD, 0.8))
	for f in floats:
		var a: float = clamp(1.5 - f.t, 0.0, 1.0)
		var s: float = 1.0 + max(0.0, 0.25 - f.t) * 2.0
		var col: Color = f.col
		col.a = a
		var outline := Color(C_INK, a)
		var fs := roundi(12 * s * (accesibilidad.escala if accesibilidad != null else 1.0))
		var tw_px: float = font.get_string_size(f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0
		while tw_px > 632.0 and fs > 8:   # frase larga: se achica en vez de cortarse
			fs -= 1
			tw_px = font.get_string_size(f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0
		var fx: float = clamp(f.pos.x - tw_px / 2, 4.0, 636.0 - tw_px)
		draw_string_outline(font, Vector2(fx, f.pos.y), f.text, HORIZONTAL_ALIGNMENT_CENTER, tw_px, fs, 4, outline)
		draw_string(font, Vector2(fx, f.pos.y), f.text, HORIZONTAL_ALIGNMENT_CENTER, tw_px, fs, col)
