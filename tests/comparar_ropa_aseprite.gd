extends SceneTree
const Character = preload("res://scripts/character.gd")
const Soft = preload("res://scripts/pixel_suave.gd")
func _initialize() -> void:
	call_deferred("build")
func label(text: String, position: Vector2, font_size: int) -> void:
	var title := Label.new()
	title.text = text
	title.position = position
	title.add_theme_font_size_override("font_size", font_size)
	title.add_theme_color_override("font_color", Color("eadcc2"))
	root.add_child(title)
func portrait(id: String, new_clothes: bool, position: Vector2) -> void:
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.size = Vector2i(128, 112)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var ch = Character.new()
	sv.add_child(ch)
	if new_clothes:
		ch.setup(id)
	else:
		var before: Dictionary = Character.PRESETS[id].duplicate(true)
		before["face_sheet"] = "res://arte/personajes/%s/caras_16.png" % id
		before["shirt_texture"] = "res://arte/personajes/%s/ropa_16.png" % id
		ch.setup_cfg(before)
	ch.set_process(false)
	var camera := Camera3D.new()
	sv.add_child(camera)
	camera.position = Vector3(0, 0.43, -1.45)
	camera.look_at(Vector3(0, 0.3, 0))
	camera.fov = 40
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("304740")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff0d4")
	env.ambient_light_energy = 0.55
	camera.environment = env
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.6, PI + 0.4, 0)
	light.light_energy = 0.9
	sv.add_child(light)
	var image := TextureRect.new()
	image.texture = sv.get_texture()
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.position = position
	image.size = Vector2(384, 336)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	root.add_child(image)
	var soft = Soft.new()
	root.add_child(soft)
	soft.setup(sv, image, camera)
func build() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1240, 860)
	var background := ColorRect.new()
	background.color = Color("18221f")
	background.size = Vector2(1240, 860)
	root.add_child(background)
	label("ASEPRITE · ANTES 16 × 16 / AHORA 64 × 64", Vector2(24, 14), 27)
	label("Misma pose, luz y suavizado B · arriba: 16 × 16 · abajo: 64 × 64", Vector2(24, 52), 20)
	for i in 3:
		var id: String = ["fello", "yeya", "chichi"][i]
		var x := 24 + i * 408
		label(["DON FELLO · GUAYABERA", "YEYA · FLORES", "CHICHÍ · CAMISETA 7"][i], Vector2(x, 92), 21)
		portrait(id, false, Vector2(x, 126))
		portrait(id, true, Vector2(x, 490))
	label("Bolsillos, alforzas y botones", Vector2(24, 834), 17)
	label("Flores completas y hojas", Vector2(432, 834), 17)
	label("Número con borde y costuras", Vector2(840, 834), 17)
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://capturas/personajes_64_comparativa.png") == OK)
	print("Comparativa de ropa guardada correctamente")
	quit()

