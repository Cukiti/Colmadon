extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func label(parent: Node, text: String, pos: Vector2, size: int) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("fff0ce"))
	parent.add_child(l)
func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(3.0).timeout
	main.set_process(false)
	var locale := TranslationServer.get_locale()
	var sample := Button.new()
	TranslationServer.set_locale("en")
	main._symbol_button(sample, "PASO  ✋")
	assert(sample.text == "PASS" and sample.icon != null)
	main._symbol_button(sample, "SIGUIENTE MANO  ▶")
	assert(sample.text == "NEXT HAND" and sample.icon != null)
	main._symbol_button(sample, "+ Nuevo")
	assert(sample.text == "New" and sample.icon != null)
	TranslationServer.set_locale("es")
	main._symbol_button(sample, "PASO  ✋")
	assert(sample.text == "PASO")
	TranslationServer.set_locale(locale)
	sample.free()
	print("Botones con iconos conservan traducciones ES/EN")
	var layer := CanvasLayer.new()
	layer.layer = 200
	root.add_child(layer)
	var bg := ColorRect.new()
	bg.size = root.size
	bg.color = Color("233d39")
	layer.add_child(bg)
	label(layer, "COLMADON · CATALOGO DE ICONOS ACTUALES", Vector2(10, 5), 11)
	var groups := [
		["ASEPRITE · controles", ["pause", "gear", "previous", "play_pause", "next"]],
		["ASEPRITE · juego", ["coin", "cafe", "ron", "morir", "agua", "pts", "info"]],
		["ASEPRITE · acciones y posturas", ["tile", "eye", "music", "sit", "shove"]],
		["ASEPRITE · gestos", ["dance", "clap", "point", "wave", "stretch", "choca", "brindis"]],
		["ASEPRITE · pizarra", ["domino", "clasico", "amigos", "reto"]],
		["ASEPRITE · navegacion principal", ["arrow_left", "arrow_right", "arrow_up", "arrow_down", "home"]],
		["ASEPRITE · simbolos de botones", ["chat", "pass_hand", "stand", "add"]]
	]
	for row in groups.size():
		var y: int = 28 + row * 46
		label(layer, groups[row][0], Vector2(10, y), 8)
		for col in groups[row][1].size():
			var id: String = groups[row][1][col]
			var x: int = 16 + col * 85
			var tex: Texture2D
			if row == 4: tex = main.menus._chalk_icon(id)
			elif id in ["cafe", "ron", "morir", "agua"]: tex = main._drink_icon(id)
			elif id == "pts": tex = main._card_icon("doble")
			elif id == "info": tex = main._card_icon("ojo")
			else: tex = main._icon(id, Color("ffcf58"))
			var image := TextureRect.new()
			image.texture = tex
			image.position = Vector2(x, y + 12)
			image.size = Vector2(24, 24)
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			layer.add_child(image)
			label(layer, id, Vector2(x + 26, y + 18), 7)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://capturas/catalogo_iconos.png")
	print("Catalogo agrupado generado")
	layer.hide()
	main.overlay.hide()
	main.hud.hide()
	main.playing = false
	main.menus.open("inicio")
	await create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://capturas/iconos_inicio.png")
	main.menus.close()
	main.hud.show()
	main.playing = true
	main.paused = false
	main.pause_btn.pressed.emit()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://capturas/iconos_pausa.png")
	assert(main.paused and is_instance_valid(main.pause_ui))
	main.pause_btn.pressed.emit()
	assert(not main.paused)
	print("Inicio y pausa renderizados; boton de pausa abre y cierra correctamente")
	main.hud.hide()
	main.playing = false
	main.menus.open("personaje")
	await create_timer(1.2).timeout
	var checked := false
	for button in main.menus.find_children("*", "Button", true, false):
		if button.get_meta("option_next", false) and button.is_visible_in_tree():
			var value: Label = button.get_parent().get_child(2)
			var before := value.text
			button.pressed.emit()
			assert(value.text != before)
			checked = true
			break
	assert(checked)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://capturas/navegacion_aseprite_personaje.png")
	print("Flecha del editor cambia la opcion correctamente")
	main.menus.close()
	main.playing = true
	main.hud.show()
	main.overlay.hide()
	main.view.cam_set("mesa")
	main.emote_btn.position = Vector2(560, 326)
	main.emote_btn.show()
	main._toggle_emotes()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://capturas/gestos_aseprite_botones.png")
	assert(main.emote_panel.get_child(0).get_child_count() == 7)
	main.emote_panel.get_child(0).get_child(3).pressed.emit()
	await process_frame
	assert(not is_instance_valid(main.emote_panel))
	print("Siete botones de gestos renderizados; Saludar ejecuta y cierra el panel")
	main.hud.hide()
	main.playing = false
	main.menus.open("modos")
	await create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://capturas/pizarra_aseprite.png")
	var icons: Array = main.menus.find_children("Icon", "TextureRect", true, false)
	assert(icons.size() == 4)
	print("Cuatro iconos de tiza renderizados en el menu de modos")
	quit()
