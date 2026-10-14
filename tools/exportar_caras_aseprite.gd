extends SceneTree
## Exporta las caras originales como fuentes para crear los editables Aseprite.
const Character = preload("res://scripts/character.gd")
const STATES := ["neutral", "parpadeo", "guino", "hablar", "hablar_abierto", "enfado", "susto", "risa", "rubor", "rubor_parpadeo"]
func _initialize() -> void:
	for id in ["fello", "yeya", "chichi", "nena", "tito", "rafa", "colmadero"]:
		var character = Character.new()
		character.cfg = (Character.PRESETS[id] if Character.PRESETS.has(id) else Character.EXTRA_PRESETS[id]).duplicate(true)
		character.cfg.erase("face_sheet")
		var dir: String = "res://arte/personajes/" + id + "/fuentes"
		if FileAccess.file_exists(dir + "/neutral.png"):
			character.free()
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var images: Array[Image] = [character._paint_face(false), character._paint_face(true), character._paint_face(false, true), character._paint_face(false, false, 1), character._paint_face(false, false, 2), character._paint_expr("enfado"), character._paint_expr("susto"), character._paint_expr("risa")]
		for base in [0, 1]:
			var image := images[base].duplicate() as Image
			for x in [1, 2, 3, 12, 13, 14]:
				for y in [9, 10]:
					image.set_pixel(x, y, Color(0.85, 0.25, 0.25))
			images.append(image)
		for index in images.size():
			assert(images[index].save_png(dir + "/" + STATES[index] + ".png") == OK)
		var file := FileAccess.open(dir + "/piel.txt", FileAccess.WRITE)
		file.store_string(character.cfg.skin.to_html(false))
		file.close()
		character.free()
	print("FUENTES: referencias nuevas de personajes, diez caras originales cada uno")
	quit()



