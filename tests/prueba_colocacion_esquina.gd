extends SceneTree
## Regresión de dos dobles separados por una ficha junto a la esquina.
## --vista=res://... permite demostrar el fallo con la implementación anterior.
## Sin --headless: -- --prueba-arte --visual guarda la mesa real en capturas/.
const Game := preload("res://scripts/game.gd")
const View := preload("res://scripts/view3d.gd")

func _initialize() -> void:
	call_deferred("run")

func replay(g, v) -> int:
	# Secuencia real de la mano 315, semilla 20261006. El orden entre
	# ambos brazos importa: no basta con colocar su cadena final de golpe.
	var caso: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/colocacion_esquina.json"))
	var fallos := 0
	v._lay = {}
	var anteriores := {}
	for paso in caso.pasos:
		g.chain = paso.chain.map(func(t): return Vector2i(int(t[0]), int(t[1])))
		g.origin = int(paso.origin)
		g.opener = int(paso.opener)
		g.left_end = int(paso.left_end)
		g.right_end = int(paso.right_end)
		for p in v.layout_chain(g):
			if anteriores.has(p.t):
				if anteriores[p.t].pos != p.pos or anteriores[p.t].y != p.y:
					print("FICHA MOVIDA ", p.t)
					fallos += 1
			anteriores[p.t] = p.duplicate()
		var escalones: int = v.stuck_count
		v.layout_chain(g)
		if v.stuck_count != escalones:
			print("SONDA DE PUNTAS CONTADA COMO FICHA")
			fallos += 1
	return fallos

func check(g, v) -> int:
	var fallos := 0
	var posiciones: Array = v.layout_chain(g)
	for i in posiciones.size():
		var p: Dictionary = posiciones[i]
		var size := Vector2(View.TL, View.TW) if abs(p.y.x) > 0.5 else Vector2(View.TW, View.TL)
		var r := Rect2(p.pos - size / 2, size)
		if r.position.x < -View.BOARD or r.position.y < -View.BOARD or r.end.x > View.BOARD or r.end.y > View.BOARD:
			fallos += 1
		for j in i:
			var q: Dictionary = posiciones[j]
			var qs := Vector2(View.TL, View.TW) if abs(q.y.x) > 0.5 else Vector2(View.TW, View.TL)
			var qr := Rect2(q.pos - qs / 2, qs)
			if r.grow(-0.008).intersects(qr) or (i - j > 1 and r.grow(0.012).intersects(qr)):
				print("CONTACTO ESQUINA ", p.t, " junto a ", q.t)
				fallos += 1
	return fallos

func run() -> void:
	var vista_script = View
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--vista="):
			vista_script = load(arg.trim_prefix("--vista="))
	var v = vista_script.new()
	var g = Game.new()
	var fallos := replay(g, v) + check(g, v)
	print("ESQUINA 22 FICHAS · ", fallos, " FALLOS")
	var final_layout: Dictionary = v._lay.duplicate(true)
	var sufijo := "_anterior" if vista_script != View else ""
	v.free()
	if OS.get_cmdline_user_args().has("--visual"):
		var m = load("res://main.tscn").instantiate()
		root.add_child(m)
		await create_timer(2).timeout
		m.set_process(false)
		m.autotest = false
		m.paused = true
		m.ui.visible = false
		m.view.cam_set("mesa")
		m.g.hands = [[], [], [], []]
		m.g.phase = "play"
		replay(m.g, m.view)
		m.view._lay = final_layout  # dibujar también el resultado anterior al comparar
		m.view.animating = true  # dibujar el estado final sin vuelos
		m.view._build_chain(m.g)
		await create_timer(0.5).timeout
		root.get_texture().get_image().save_png("res://capturas/colocacion_esquina%s.png" % sufijo)
		m.view.set_top(true)
		await create_timer(1).timeout
		root.get_texture().get_image().save_png("res://capturas/colocacion_esquina%s_arriba.png" % sufijo)
	quit(1 if fallos else 0)
