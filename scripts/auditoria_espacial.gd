extends RefCounted
## Observador del recorrido: nunca mueve objetos ni cambia colisiones.
## Las cajas envolventes generan candidatos, no prueban contacto de mallas.
var repetidos := {}
var emitidos := {}
var muestras := 0
var fotos := 0
var inventario := {}

static func penetracion_circulo(p: Vector2, radio: float, caja: Rect2) -> float:
	var cercano := p.clamp(caja.position, caja.end)
	if caja.has_point(p):
		return radio + minf(minf(p.x - caja.position.x, caja.end.x - p.x), minf(p.y - caja.position.y, caja.end.y - p.y))
	return maxf(0.0, radio - p.distance_to(cercano))

static func caja_mundo(n: Node3D) -> AABB:
	var cajas: Array[AABB] = []
	_cajas(n, cajas)
	if cajas.is_empty():
		return AABB()
	var salida := cajas[0]
	for c in cajas.slice(1):
		salida = salida.merge(c)
	return salida

static func _cajas(n: Node, out: Array[AABB]) -> void:
	if n is Node3D and not n.is_visible_in_tree():
		return
	if n is MeshInstance3D and n.mesh != null:
		out.append(n.global_transform * n.get_aabb())
	for c in n.get_children():
		_cajas(c, out)

static func candidatos_solidos(nodos: Array) -> Array:
	var salida := []
	for i in nodos.size():
		for j in range(i + 1, nodos.size()):
			var a: Node3D = nodos[i]
			var b: Node3D = nodos[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			if a.get_meta("audit_union", "") != "" and a.get_meta("audit_union") == b.get_meta("audit_union", ""):
				continue # piezas que se ensamblan expresamente
			var inter := caja_mundo(a).intersection(caja_mundo(b))
			if inter.size.x > 0.015 and inter.size.y > 0.015 and inter.size.z > 0.015:
				salida.append({"tipo": "solape_volumen_candidato", "clave": str(a.get_path(), "|", b.get_path()), "detalle": "Cajas envolventes se cruzan; verificar mallas", "a": str(a.get_path()), "b": str(b.get_path()), "interseccion": str(inter)})
	return salida

static func alineacion(n: Node3D, esperado: Transform3D, tolerancia := 0.02) -> Dictionary:
	var distancia := n.global_position.distance_to(esperado.origin)
	var giro := n.global_basis.get_rotation_quaternion().angle_to(esperado.basis.orthonormalized().get_rotation_quaternion())
	if distancia <= tolerancia and giro <= deg_to_rad(2.0):
		return {}
	return {"tipo": "objeto_desalineado", "clave": str(n.get_path()), "detalle": "Objeto fuera de su posición/orientación prevista", "objeto": str(n.get_path()), "posicion": str(n.global_position), "esperado": str(esperado.origin), "distancia_m": distancia, "giro_grados": rad_to_deg(giro)}

static func mallas(n: Node, out: Array) -> void:
	if n is Node3D and not n.is_visible_in_tree():
		return
	if n is MeshInstance3D and n.mesh is BoxMesh:
		out.append(n)
	for c in n.get_children():
		mallas(c, out)

func inspeccionar(main) -> Array:
	var v = main.view
	var pie = v.pie
	var alertas: Array = []
	muestras += 1
	if pie.mode == "de_pie":
		for i in pie.boxes.size():
			var profundidad := penetracion_circulo(pie.pos, pie.RADIUS, pie.boxes[i])
			if profundidad > 0.02:
				alertas.append({"tipo": "cuerpo_en_obstaculo", "clave": "mueble_%d" % i, "detalle": "Cuerpo del jugador penetra obstáculo de caminar", "posicion": str(pie.pos), "obstaculo": str(pie.boxes[i]), "penetracion_m": profundidad})
		var margen: Rect2 = pie.room_r.grow(-pie.RADIUS + 0.02)
		if not margen.has_point(pie.pos):
			alertas.append({"tipo": "cuerpo_fuera_sala", "clave": "sala", "detalle": "Radio del jugador fuera del límite de sala", "posicion": str(pie.pos)})
		for s in [1, 2, 3]:
			var radio: float = 0.3 if not pie.remote.has(s) or pie.remote[s].st == 0 else 0.24
			var profundidad: float = pie.RADIUS + radio - pie.pos.distance_to(pie.person_pos(s))
			if profundidad > 0.03:
				alertas.append({"tipo": "cuerpos_solapados", "clave": "persona_%d" % s, "detalle": "Radios de jugador y persona se penetran", "penetracion_m": profundidad})
		for silla in v.loose_chairs():
			var p := Vector2(silla.global_position.x, silla.global_position.z)
			var profundidad: float = pie.RADIUS + 0.2 - pie.pos.distance_to(p)
			if profundidad > 0.03:
				alertas.append({"tipo": "cuerpo_en_silla", "clave": str(silla.get_path()), "detalle": "Jugador dentro del radio de silla vacía", "penetracion_m": profundidad})
	# Sillas en reposo: se comparan en mundo 3D, nunca por perspectiva de pantalla.
	for s in [1, 2, 3]:
		var silla = v.seat_chairs[s]
		var persona = v.heads[s]
		if not is_instance_valid(silla) or not is_instance_valid(persona) or persona._chair_out or persona.stand_k > 0.01:
			continue
		if pie.remote.has(s) and pie.remote[s].st != 0:
			continue
		var direccion: Vector3 = v._seat_dir(s)
		var local_esperado := Transform3D(Basis(Vector3.UP, atan2(direccion.x, direccion.z)), direccion * 1.02 + Vector3(0, v.TABLE_Y, 0))
		var esperado: Transform3D = v.global_transform * local_esperado
		var alerta := alineacion(silla, esperado)
		if not alerta.is_empty():
			alertas.append(alerta)
	# Bordes y bandejas tienen distribución regular declarada por la vista.
	for rail in v.rail_meshes:
		if not is_instance_valid(rail) or not rail.mesh is BoxMesh:
			continue
		var p: Vector3 = v.to_local(rail.global_position)
		var radio: float = v.BOARD + 0.03 if rail.mesh.size.x > 1.0 else (v.TRAY + 0.05 if rail.mesh.size.z < 0.02 else v.TRAY)
		if rail.mesh.size.z > 0.1:
			continue # base completa de mesa: no es una bandeja ni un borde
		var direccion := Vector3(0, 0, signf(p.z)) if absf(p.z) >= absf(p.x) else Vector3(signf(p.x), 0, 0)
		var altura: float = v.TABLE_Y if rail.mesh.size.z > 0.08 else v.TABLE_Y + 0.02
		var objetivo := direccion * radio + Vector3(0, altura, 0)
		var error: float = p.distance_to(objetivo)
		var giro: float = rail.basis.orthonormalized().get_rotation_quaternion().angle_to(Basis(Vector3.UP, atan2(direccion.x, direccion.z)).get_rotation_quaternion())
		if error > 0.02 or giro > deg_to_rad(2.0):
			alertas.append({"tipo": "bandeja_borde_descentrado", "clave": str(rail.get_path()), "detalle": "Borde o bandeja fuera de su radio previsto", "error_m": error, "posicion": str(p), "esperado": str(objetivo), "giro_grados": rad_to_deg(giro)})
	var centro_tablero: Vector3 = v.to_local(v.board_mi.global_position)
	var centro_colision: Vector2 = pie.boxes[0].get_center()
	var diferencia: float = Vector2(centro_tablero.x, centro_tablero.z).distance_to(centro_colision)
	if diferencia > 0.04:
		alertas.append({"tipo": "colision_mesa_descentrada", "clave": "mesa", "detalle": "Centro visual de mesa y caja de caminar no coinciden", "error_m": diferencia, "mesa": str(centro_tablero), "colision": str(centro_colision)})
	if main.g.phase == "play" and not v.animating and not v.counting:
		for tile in v._chain_nodes:
			var n = v._chain_nodes[tile]
			if not is_instance_valid(n) or absf(n.position.y - (v.TABLE_Y + v.TD / 2 + 0.002)) > 0.01:
				continue # vuelos y cuenta tienen posiciones intencionadas
			var centro := Vector2(n.position.x, n.position.z)
			var eje := Vector2(n.basis.y.x, n.basis.y.z).normalized()
			var perpendicular := Vector2(-eje.y, eje.x)
			for x in [-1, 1]:
				for y in [-1, 1]:
					var esquina: Vector2 = centro + eje * v.TL / 2 * x + perpendicular * v.TW / 2 * y
					if maxf(absf(esquina.x), absf(esquina.y)) > v.BOARD + 0.015:
						alertas.append({"tipo": "ficha_fuera_tablero", "clave": str(tile), "detalle": "Esquina de ficha asentada fuera del tablero", "ficha": str(tile), "esquina": str(esquina)})
	# Cabeza del colmadero frente a geometría del entorno; nunca comparar sus propias piezas.
	if is_instance_valid(v.colmadero) and is_instance_valid(v.colmadero.head):
		var cabeza: AABB = caja_mundo(v.colmadero.head)
		var entorno: Array = []
		mallas(v, entorno)
		for objeto in entorno:
			if v.colmadero.is_ancestor_of(objeto):
				continue
			var caja: AABB = objeto.global_transform * objeto.get_aabb()
			var inter := cabeza.intersection(caja)
			if inter.size.x > 0.015 and inter.size.y > 0.015 and inter.size.z > 0.015:
				alertas.append({"tipo":"cabeza_colmadero_solapada_candidato", "clave":str(objeto.get_path()), "detalle":"Cabeza del colmadero intersecta caja de geometría del entorno; revisar malla y perspectiva", "objeto":str(objeto.get_path()), "interseccion":str(inter), "recomendacion":"Separar cabeza y tabla/estante manteniendo profundidad coherente desde la cámara del mostrador."})
	# Soportes declarados: evita confundir vuelos, adornos colgados y animaciones con flotación.
	for objeto in main.get_tree().get_nodes_in_group("audit_soporte"):
		if objeto is Node3D and objeto.is_visible_in_tree() and objeto.has_meta("audit_soporte_y"):
			var base_y: float = caja_mundo(objeto).position.y
			var soporte_y: float = objeto.get_meta("audit_soporte_y")
			if base_y - soporte_y > 0.025:
				alertas.append({"tipo":"objeto_flotante_candidato", "clave":str(objeto.get_path()), "detalle":"Base del objeto separada de su soporte declarado", "separacion_m":base_y-soporte_y, "recomendacion":"Apoyar el objeto y alinear sombra y superficie; comprobar que no sea un vuelo intencionado."})
	# Extensible sin exigir que cada pieza de una persona/mueble sea disjunta.
	var solidos: Array = main.get_tree().get_nodes_in_group("audit_solido").filter(func(n): return n is Node3D and n.is_visible_in_tree())
	inventario = {"muestras": muestras, "obstaculos_caminar": pie.boxes.size(), "sillas_previstas": 3, "bordes_bandejas": 12, "otros_objetos": "NO_REVISADO salvo registro audit_solido", "simetria": "solo disposición declarada de mobiliario de mesa", "solidos_registrados": solidos.size(), "limite_solidos": 64}
	if solidos.size() > 64:
		alertas.append({"tipo": "cobertura_espacial_limitada", "clave": "solidos", "detalle": "Más de 64 sólidos registrados; se inspeccionan los primeros 64"})
	alertas.append_array(candidatos_solidos(solidos.slice(0, 64)))
	return alertas

func revisar(bot) -> void:
	if not bot.m.playing or bot.m.paused:
		return
	var actual := {}
	for a in inspeccionar(bot.m):
		var clave: String = a.tipo + "|" + a.clave
		actual[clave] = int(repetidos.get(clave, 0)) + 1
		var minimo: int = 90 if bot._auditoria_por_frame else 3
		if actual[clave] < minimo or emitidos.has(clave):
			continue
		emitidos[clave] = true
		bot.hallazgo(a.tipo, a.detalle + " · " + JSON.stringify(a), a.clave)
		var base := "espacial_%d" % bot.frame
		a["fotograma"] = bot.frame
		a["estado"] = "CANDIDATO_PENDIENTE_REVISION"
		if fotos < 12:
			bot.foto(base)
			fotos += 1
			a["captura"] = base + ".png"
		var f := FileAccess.open(bot.dir + "/espacial.jsonl", FileAccess.READ_WRITE) if FileAccess.file_exists(bot.dir + "/espacial.jsonl") else FileAccess.open(bot.dir + "/espacial.jsonl", FileAccess.WRITE)
		f.seek_end()
		f.store_line(JSON.stringify(a))
		f.close()
	repetidos = actual
	FileAccess.open(bot.dir + "/cobertura_espacial.json", FileAccess.WRITE).store_string(JSON.stringify(inventario, "\t"))
