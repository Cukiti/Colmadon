extends SceneTree
const Character = preload("res://scripts/character.gd")
func _initialize() -> void:
	var count := 0
	for id in ["fello", "yeya", "chichi", "nena", "tito", "rafa", "colmadero"]:
		var ch = Character.new()
		ch.setup(id)
		assert(ch._aseprite_face != null)
		assert(ch._aseprite_face.get_size() == Vector2i(640, 64))
		var baseline: Image = (load("res://arte/personajes/%s/caras_16.png" % id) as Texture2D).get_image()
		for i in 10:
			var face: Image = ch._aseprite_frame(i)
			assert(face.get_size() == Vector2i(64, 64))
			var enlarged := baseline.get_region(Rect2i(i * 16, 0, 16, 16))
			enlarged.resize(64, 64, Image.INTERPOLATE_NEAREST)
			face.convert(Image.FORMAT_RGBA8)
			enlarged.convert(Image.FORMAT_RGBA8)
			assert(face.get_data() != enlarged.get_data(), "Solo se amplió la cara: " + id)
			count += 1
		var textures: Array = [ch.tex_open, ch.tex_blink, ch.tex_wink, ch.tex_talk, ch.tex_talk_wide, ch.tex_expr.enfado, ch.tex_expr.susto, ch.tex_expr.risa]
		for i in 8:
			assert(textures[i].get_image().get_data() == ch._aseprite_frame(i).get_data())
		ch._set_flush(true)
		assert(ch.tex_open.get_image().get_data() == ch._aseprite_frame(8).get_data())
		assert(ch.tex_blink.get_image().get_data() == ch._aseprite_frame(9).get_data())
		ch._set_flush(false)
		assert(ch.tex_open.get_image().get_data() == ch._aseprite_frame(0).get_data())
		ch.free()
	var custom = Character.new()
	var cfg: Dictionary = Character.PRESETS.nena.duplicate(true)
	cfg.skin = Color(0.33, 0.21, 0.14)
	custom.setup_cfg(cfg)
	assert(custom._aseprite_face == null)
	assert(custom.tex_open.get_size() == Vector2(16, 16))
	custom.free()
	print("ASEPRITE 64: ", count, " estados con detalle real; habla, emociones, rubor y personalización SIN FALLOS")
	quit()
