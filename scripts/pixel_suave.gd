extends Node
## Suavizado B: conserva el 65 % del render original y mezcla un 35 % de MSAA.
## Ambos renders comparten mundo: el juego y las animaciones se ejecutan una vez.
const AMOUNT := 0.35
const MIX_SHADER := preload("res://shaders/pixel_suave.gdshader")

var source: SubViewport
var source_camera: Camera3D
var smooth: SubViewport
var smooth_camera: Camera3D

func setup(viewport: SubViewport, screen: TextureRect, camera: Camera3D) -> void:
	source = viewport
	source_camera = camera
	smooth = SubViewport.new()
	smooth.name = "PixelSuaveViewport"
	smooth.world_3d = source.find_world_3d()
	smooth.size = source.size
	smooth.msaa_3d = Viewport.MSAA_4X
	smooth.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(smooth)
	smooth_camera = Camera3D.new()
	smooth.add_child(smooth_camera)
	smooth_camera.current = true
	var material := ShaderMaterial.new()
	material.shader = MIX_SHADER
	material.set_shader_parameter("original_tex", source.get_texture())
	material.set_shader_parameter("smooth_tex", smooth.get_texture())
	material.set_shader_parameter("amount", AMOUNT)
	screen.material = material
	_sync_camera()
	RenderingServer.frame_pre_draw.connect(_sync_camera)

func _sync_camera() -> void:
	if not is_instance_valid(source_camera):
		return
	smooth.size = source.size
	smooth_camera.global_transform = source_camera.global_transform
	smooth_camera.projection = source_camera.projection
	smooth_camera.fov = source_camera.fov
	smooth_camera.size = source_camera.size
	smooth_camera.near = source_camera.near
	smooth_camera.far = source_camera.far
	smooth_camera.keep_aspect = source_camera.keep_aspect
	smooth_camera.frustum_offset = source_camera.frustum_offset
	smooth_camera.h_offset = source_camera.h_offset
	smooth_camera.v_offset = source_camera.v_offset
	smooth_camera.cull_mask = source_camera.cull_mask
	smooth_camera.environment = source_camera.environment
	smooth_camera.attributes = source_camera.attributes

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync_camera):
		RenderingServer.frame_pre_draw.disconnect(_sync_camera)
