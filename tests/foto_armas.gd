extends SceneTree
## Foto de cerca de las armas (pistola y revólver) para revisar el modelo.
## Uso: godot --path . --script res://tests/foto_armas.gd  → user://foto_armas.png

func _init() -> void:
	_foto.call_deferred()


func _foto() -> void:
	var Modelo := load("res://scripts/modelo_arma.gd")
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.3, 0.27)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.55, 0.5)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation = Vector3(-0.8, 0.6, 0)
	sol.light_energy = 1.4
	vp.add_child(sol)
	var cam := Camera3D.new()
	cam.position = Vector3(0, -0.02, 0.62)
	cam.fov = 40
	vp.add_child(cam)
	var vistas := [["pistola", Vector3(-0.15, 0.06, 0), PI / 2], ["revolver", Vector3(0.14, 0.06, 0), PI / 2],
		["pistola", Vector3(-0.15, -0.13, 0), -0.6], ["revolver", Vector3(0.15, -0.13, 0), -0.6]]
	for v in vistas:
		var a: Node3D = Modelo.crear(v[0])
		a.position = v[1]
		a.rotation.y = v[2]
		vp.add_child(a)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png("user://foto_armas.png")
	print("FOTO ARMAS GUARDADA")
	quit()
