extends SceneTree
func _initialize() -> void:
	var old := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	old.fill(Color.TRANSPARENT)
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5).length()
			if d < 7.5: old.set_pixel(x, y, Color(0.12, 0.07, 0.04))
			if d < 6.5: old.set_pixel(x, y, Color(0.85, 0.6, 0.12))
			if d < 5.0: old.set_pixel(x, y, Color(1.0, 0.8, 0.22))
	for y in range(5, 11):
		old.set_pixel(7, y, Color(0.8, 0.55, 0.1))
		old.set_pixel(8, y, Color(0.8, 0.55, 0.1))
	old.set_pixel(5, 4, Color.WHITE)
	old.set_pixel(4, 5, Color.WHITE)
	var current: Image = load("res://arte/interfaz/moneda.png").get_image()
	var preview := Image.create(384, 192, false, Image.FORMAT_RGBA8)
	preview.fill(Color("304740"))
	for i in 2:
		var icon: Image = old if i == 0 else current
		var large := icon.duplicate()
		large.resize(128, 128, Image.INTERPOLATE_NEAREST)
		preview.blend_rect(large, Rect2i(0, 0, 128, 128), Vector2i(32 + i * 192, 16))
		preview.blend_rect(icon, Rect2i(0, 0, 16, 16), Vector2i(88 + i * 192, 160))
	preview.save_png("res://capturas/moneda_aseprite_comparativa.png")
	print("Comparativa: anterior izquierda, Aseprite derecha; abajo tamaño nativo 16x16")
	quit()
