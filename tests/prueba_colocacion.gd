extends SceneTree
## Coloca las líneas de cientos de manos reales (jugadas por bots) con el mismo
## código de la mesa y comprueba que ninguna ficha se sale ni se monta.
## Uso: godot --headless --path . --script res://tests/prueba_colocacion.gd

const Game := preload("res://scripts/game.gd")
const View := preload("res://scripts/view3d.gd")

var view


func _init() -> void:
	var semilla := 20261006
	var cantidad := 400
	var solo_mano := -1
	var guardar_caso := ""
	var caso_guardado := false
	var vista_script = View
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--semilla="):
			semilla = int(arg.get_slice("=", 1))
		elif arg.begins_with("--manos="):
			cantidad = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--mano="):
			solo_mano = maxi(0, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--guardar-caso="):
			guardar_caso = arg.trim_prefix("--guardar-caso=")
		elif arg.begins_with("--vista="):
			vista_script = load(arg.trim_prefix("--vista="))
			assert(vista_script != null, "No se pudo cargar la vista de comparación")
	if solo_mano >= 0:
		cantidad = solo_mano + 1
	seed(semilla)
	print("SEMILLA ", semilla)
	view = vista_script.new()
	# Solo usamos geometría: no construir la escena/renderizador de la mesa.

	var hands := 0
	var outside := 0
	var overlaps := 0
	var moved := 0
	var glued := 0
	var incompletas := 0
	var worst := ""
	var max_len := 0
	for n in cantidad:
		var g = Game.new()
		g.new_game()
		g.human_pick(g.offers[0][0])
		g.first_hand = n % 3 == 0
		g.starter_next = randi() % 4
		g.finish_draw(g.auto_picks([]))
		var guard := 0
		var escalon_antes: int = view.stuck_count
		var seen := {}   # posición de cada ficha la primera vez que se colocó
		var errores_mano := {"fuera": false, "montada": false, "pegada": false}
		var historial := []
		while g.phase == "play" and guard < 300:
			guard += 1
			g.bot_turn()
			g.events.clear()
			if solo_mano >= 0 and n != solo_mano:
				continue
			if guardar_caso != "" and not g.chain.is_empty():
				historial.append({"chain": g.chain.map(func(t): return [t.x, t.y]), "origin": g.origin,
					"opener": g.opener, "left_end": g.left_end, "right_end": g.right_end})
			if not g.chain.is_empty():
				for p in view.layout_chain(g):
					if seen.has(p.t) and (seen[p.t].pos.distance_to(p.pos) > 0.0001 or seen[p.t].y != p.y):
						moved += 1
					seen[p.t] = {"pos": p.pos, "y": p.y}
			var r := _check(g)
			for tipo in errores_mano:
				errores_mano[tipo] = errores_mano[tipo] or r[tipo]
			if r.montada and OS.get_cmdline_user_args().has("--montadas"):
				print("MONTADA_CASO mano %d paso %d · %s" % [n, guard, r.ejemplo])
			if r.ejemplo != "":
				if guardar_caso != "" and not caso_guardado:
					var fichero := FileAccess.open(guardar_caso, FileAccess.WRITE)
					assert(fichero != null, "No se pudo escribir el caso")
					fichero.store_string(JSON.stringify({"semilla": semilla, "mano": n, "pasos": historial}, "\t"))
					fichero.close()
					caso_guardado = true
				if worst == "":
					worst = "%s · mano %d, cadena %d fichas, origen %d, sale %d" % [r.ejemplo, n, g.chain.size(), g.origin, g.opener]
					if OS.get_cmdline_user_args().has("--diagnostico"):
						print("CASO ", worst, " · fichas ", view.layout_chain(g))
		# Terminar todas las manos: un contacto no debe ocultar una colisión
		# posterior ni cambiar la secuencia aleatoria de las manos siguientes.
		if n == solo_mano and not g.chain.is_empty():
			print("FINAL ", view.layout_chain(g))
		if OS.get_cmdline_user_args().has("--montadas") and view.stuck_count > escalon_antes:
			print("ESCALON_CASO mano %d" % n)
		if solo_mano >= 0 and n != solo_mano:
			continue
		if g.phase == "play":
			incompletas += 1
		outside += int(errores_mano.fuera)
		overlaps += int(errores_mano.montada)
		glued += int(errores_mano.pegada)
		max_len = max(max_len, g.chain.size())
		hands += 1
	print("MANOS %d · línea más larga %d" % [hands, max_len])
	print("FUERA DE LA MESA: %d · MONTADAS: %d · PEGADAS: %d · FICHAS QUE SE MOVIERON: %d" % [outside, overlaps, glued, moved])
	print("FICHAS EN ESCALÓN (línea encerrada): %d · DOBLES QUE GIRAN LA ESQUINA: %d · SUELTAS: %d" % [view.stuck_count, view.dbl_turn_count, view.suelta_count])
	if incompletas > 0:
		print("FALLO: %d manos no terminaron antes del límite" % incompletas)
	if worst != "":
		print("EJEMPLO: ", worst)
	view.free()
	view = null
	quit(1 if outside + overlaps + moved + incompletas > 0 else 0)


func _check(g) -> Dictionary:
	var resultado := {"fuera": false, "montada": false, "pegada": false, "ejemplo": ""}
	if g.chain.is_empty():
		return resultado
	var placed: Array = view.layout_chain(g)
	var rects: Array = []
	var idx_of := {}
	for i in g.chain.size():
		idx_of[g.chain[i]] = i
	var idxs: Array = []
	for p in placed:
		var t: Vector2i = p.t
		# huella real: el largo va en la dirección de "y" de la ficha
		var yv: Vector2 = p.y
		var size := Vector2(View.TL, View.TW) if abs(yv.x) > 0.5 else Vector2(View.TW, View.TL)
		var rc := Rect2(p.pos - size / 2, size)
		if rc.position.x < -View.BOARD or rc.position.y < -View.BOARD or rc.end.x > View.BOARD or rc.end.y > View.BOARD:
			resultado.fuera = true
			resultado.ejemplo = "FUERA %s en %s" % [t, p.pos]
		var ci: int = idx_of.get(t, -1)
		for q in rects.size():
			var o: Rect2 = rects[q]
			if rc.grow(-0.008).intersects(o):
				resultado.montada = true
				resultado.ejemplo = "MONTADA %s en %s" % [t, p.pos]
			# fichas que no casan entre sí deben dejar un hueco visible
			if abs(idxs[q] - ci) > 1 and rc.grow(0.012).intersects(o):
				resultado.pegada = true
				if resultado.ejemplo == "":
					resultado.ejemplo = "PEGADA %s en %s junto a %s en %s" % [t, p.pos, g.chain[idxs[q]], o.get_center()]
		rects.append(rc)
		idxs.append(ci)
	return resultado
