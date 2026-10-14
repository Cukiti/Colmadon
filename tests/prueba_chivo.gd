extends SceneTree
## Simula muchas manos para comprobar las reglas del chivo (sin gráficos).
## Uso: godot --headless --path . --script res://tests/prueba_chivo.gd

const Game := preload("res://scripts/game.gd")


func _init() -> void:
	randomize()
	var caught := 0
	var stayed := 0
	var trials := 400
	# 1) tú metes un chivo: ¿lo canta el bot que sigue?
	for n in trials:
		var g = Game.new()
		g.new_game()
		g.human_pick(g.offers[0][0])
		g.first_hand = false
		g.starter_next = 0
		g.finish_draw(g.auto_picks([]))
		# sale cualquier ficha y juegan hasta tu turno
		g.play(0, g.hands[0][0], 0)
		var guard := 0
		while g.phase == "play" and g.turn != 0 and guard < 20:
			g.bot_turn()
			guard += 1
		if g.phase != "play" or g.turn != 0 or g.hands[0].size() < 2:
			continue
		# busca una ficha que NO casa (los dobles no valen de chivo)
		var bad = null
		for t in g.hands[0]:
			if t.x != t.y and not g.legal_moves(0).any(func(m): return m.tile == t):
				bad = t
				break
		if bad == null:
			continue
		g.events.clear()
		if not g.play_chivo(0, bad, 1):
			print("FALLO chivo rechazado ", bad)
			continue
		if g.phase == "play" and g.turn == 1:
			g.bot_turn()
		var was_caught: bool = g.events.any(func(e): return e.k == "chivo_caught")
		if was_caught:
			caught += 1
			if not (g.last_result.reason == "chivo" and g.last_result.team == 1):
				print("FALLO resultado ", g.last_result)
		else:
			stayed += 1
			if not g.chivo.is_empty() and g.chivo.seat == 0:  # el que seguía jugó: tu chivo se queda
				print("FALLO chivo sigue pendiente ", g.chivo, " turno ", g.turn, " fase ", g.phase)
	print("CHIVO tuyo: cazado %d, se quedó %d (esperado ~60%% cazado)" % [caught, stayed])

	# 2) cantar en falso cuesta monedas
	var g2 = Game.new()
	g2.new_game()
	g2.human_pick(g2.offers[0][0])
	g2.finish_draw(g2.auto_picks([]))
	g2.coins[0] = 25
	g2.chivo = {}
	g2.turn = 0   # solo se canta en tu turno
	g2.call_chivo(0)
	print("FALSA ALARMA: monedas 25 -> %d (esperado 15)" % g2.coins[0])

	# 3) un chivo de hace dos turnos ya no se puede cantar
	var g3 = Game.new()
	g3.new_game()
	g3.human_pick(g3.offers[0][0])
	g3.finish_draw(g3.auto_picks([]))
	g3.chivo = {"seat": 2, "kind": "ficha", "tile": Vector2i(1, 1), "real": true}
	g3.turn = 0
	g3.coins[0] = 20
	var ok3: bool = g3.call_chivo(0)  # el 2 no es quien va antes del 0
	print("CHIVO VIEJO cantable: %s (esperado false)" % ok3)

	# 4) el ron despista: el bot caza menos
	var c_ron := 0
	for n in trials:
		var g4 = Game.new()
		g4.new_game()
		g4.human_pick(g4.offers[0][0])
		g4.finish_draw(g4.auto_picks([]))
		g4.chain = [Vector2i(2, 3)]
		g4.left_end = 2
		g4.right_end = 3
		g4.turn = 1
		g4.drank_ron[1] = true
		g4.chivo = {"seat": 0, "kind": "ficha", "tile": Vector2i(5, 6), "real": true}
		g4.events.clear()
		g4.bot_turn()
		if g4.events.any(func(e): return e.k == "chivo_caught"):
			c_ron += 1
	print("CON RON el bot caza %d de %d (esperado ~20%%)" % [c_ron, trials])

	# 5) chivo cazado: solo cuentan las fichas de la pareja tramposa
	var g5 = Game.new()
	g5.new_game()
	g5.human_pick(g5.offers[0][0])
	g5.finish_draw(g5.auto_picks([]))
	g5.cards = [[], [], [], []]
	g5.hot_hand = false
	g5.marks = [0, 0, 0, 0]
	g5.chivo = {"seat": 3, "kind": "ficha", "tile": Vector2i(5, 6), "real": true}
	g5.turn = 0
	var tramposos: int = g5.pip_sum(1) + g5.pip_sum(3)
	g5.call_chivo(0)
	print("PUNTOS DEL CHIVO: %d (esperado %d, sin las fichas de tu pareja)" % [g5.last_result.pts, tramposos])
	if g5.last_result.pts != tramposos:
		print("FALLO puntos del chivo")

	# 6) el caso del usuario (2026-10-04): tras un 5-3 las dos puntas son 3; su 6-3
	# soltado en cualquiera de las dos es jugada, nunca chivo
	var fallos := 0
	for lado in [-1, 1]:
		var g6 = _mesa([[Vector2i(6, 3), Vector2i(1, 2), Vector2i(4, 4)], [Vector2i(0, 0), Vector2i(0, 1)], [Vector2i(0, 2), Vector2i(0, 3)], [Vector2i(0, 4), Vector2i(0, 5)]], 3, 3)
		var r: String = g6.play_or_chivo(0, Vector2i(6, 3), lado)
		if r != "jugada" or not g6.chivo.is_empty() or (g6.left_end if lado < 0 else g6.right_end) != 6:
			print("FALLO puntas iguales: 6-3 en la punta %d → «%s», chivo %s" % [lado, r, g6.chivo])
			fallos += 1
	var g7 = _mesa([[Vector2i(6, 3), Vector2i(1, 2), Vector2i(4, 4)], [Vector2i(0, 0), Vector2i(0, 1)], [Vector2i(0, 2), Vector2i(0, 3)], [Vector2i(0, 4), Vector2i(0, 5)]], 3, 3)
	if g7.play_or_chivo(0, Vector2i(1, 2), 1) != "chivo":
		print("FALLO un chivo de verdad no se acepta")
		fallos += 1
	var g8 = _mesa([[Vector2i(6, 3), Vector2i(1, 2), Vector2i(4, 4)], [Vector2i(0, 0), Vector2i(0, 1)], [Vector2i(0, 2), Vector2i(0, 3)], [Vector2i(0, 4), Vector2i(0, 5)]], 3, 3)
	if g8.play_or_chivo(0, Vector2i(4, 4), 1) != "":
		print("FALLO un doble que no casa se acepta")
		fallos += 1
	# pasar sin jugada no es renuncio; pasar con jugada sí
	var g9 = _mesa([[Vector2i(1, 2), Vector2i(1, 1)], [Vector2i(0, 0)], [Vector2i(0, 2)], [Vector2i(0, 4)]], 3, 3)
	g9.pass_fake(0)
	if not g9.chivo.is_empty():
		print("FALLO pasar sin jugada se registró como renuncio")
		fallos += 1
	var g10 = _mesa([[Vector2i(6, 3), Vector2i(1, 1)], [Vector2i(0, 0)], [Vector2i(0, 2)], [Vector2i(0, 4)]], 3, 3)
	g10.pass_turn(0)
	if g10.chivo.get("kind", "") != "pase":
		print("FALLO pasar con jugada no quedó como renuncio")
		fallos += 1
	# un chivo que no pasó por play_chivo / pass_fake no se puede cantar
	var g12 = _mesa([[Vector2i(6, 3), Vector2i(1, 1)], [Vector2i(0, 0), Vector2i(1, 4)], [Vector2i(0, 2)], [Vector2i(0, 4)]], 3, 3)
	g12.turn = 1
	g12.chivo = {"seat": 0, "kind": "ficha", "tile": Vector2i(6, 3)}
	if g12.call_chivo(1):
		print("FALLO se cantó un chivo sin comprobar")
		fallos += 1
	# cantar fuera de tu turno no vale
	var g11 = _mesa([[Vector2i(6, 3), Vector2i(1, 1)], [Vector2i(0, 0), Vector2i(1, 4)], [Vector2i(0, 2)], [Vector2i(0, 4)]], 3, 3)
	g11.chivo = {"seat": 0, "kind": "ficha", "tile": Vector2i(1, 2), "real": true}
	if g11.call_chivo(1):
		print("FALLO se canta chivo fuera de turno")
		fallos += 1
	# al azar: ninguna ficha que casa acaba como chivo, ninguna que no casa como jugada
	for n in 3000:
		var todas: Array = []
		for a in 7:
			for b in range(a, 7):
				todas.append(Vector2i(a, b))
		todas.shuffle()
		var gz = _mesa([todas.slice(0, 5), todas.slice(5, 10), todas.slice(10, 15), todas.slice(15, 20)], randi() % 7, randi() % 7)
		var t: Vector2i = gz.hands[0][randi() % 5]
		var lado: int = [-1, 1][randi() % 2]
		var fin: int = gz.left_end if lado < 0 else gz.right_end
		var casa: bool = t.x == fin or t.y == fin
		var r2: String = gz.play_or_chivo(0, t, lado)
		if (r2 == "chivo" and casa) or (r2 == "jugada" and not casa):
			print("FALLO %s en la punta %d (%d): «%s»" % [t, lado, fin, r2])
			fallos += 1
	# capicúa solo con puntas distintas: 6-3 con puntas 3 y 3 no; con 3 y 6 sí
	for caso in [[3, 3, false], [3, 6, true]]:
		var gc = _mesa([[Vector2i(6, 3)], [Vector2i(0, 0)], [Vector2i(0, 2)], [Vector2i(0, 4)]], caso[0], caso[1])
		gc.play(0, Vector2i(6, 3), 1)
		if bool(gc.last_result.get("capicua", false)) != caso[2]:
			print("FALLO capicúa con puntas %d y %d: %s" % [caso[0], caso[1], gc.last_result.get("capicua")])
			fallos += 1
	# «¡Ute va!» con revisión: la 3 pasa teniendo el 3-5 (puntas 3 y 4) y la 0 canta
	var ute := func():
		var u = _mesa([[Vector2i(0, 0), Vector2i(1, 1)], [Vector2i(4, 1)], [Vector2i(0, 2)], [Vector2i(3, 5), Vector2i(6, 6)]], 3, 4)
		u.turn = 3
		u.pass_fake(3)
		u.turn = 0
		return u
	var u1 = ute.call()
	u1.call_chivo(0, true)
	if u1.revision.is_empty() or u1.play(0, Vector2i(0, 0), 1):
		print("FALLO ute va: no empieza la revisión o se puede jugar en ella")
		fallos += 1
	if u1.resolve_revision(0, Vector2i(6, 6)) != "no_iba" or u1.resolve_revision(0, Vector2i(3, 5)) != "cazado":
		print("FALLO ute va: elegir ficha")
		fallos += 1
	var u2 = ute.call()
	u2.call_chivo(0, true)
	if u2.resolve_revision(0, Vector2i(-1, -1), true) != "cazado":
		print("FALLO ute va: «No llevaba» pero sí llevaba debe contar igual")
		fallos += 1
	var u3 = _mesa([[Vector2i(0, 0), Vector2i(1, 1)], [Vector2i(4, 1)], [Vector2i(0, 2)], [Vector2i(5, 6), Vector2i(6, 6)]], 3, 4)
	u3.turn = 3
	u3.pass_turn(3)
	u3.turn = 0
	u3.call_chivo(0, true)
	if u3.resolve_revision(0, Vector2i(-1, -1), true) != "falso":
		print("FALLO ute va: pase de verdad y «No llevaba» no es falsa alarma")
		fallos += 1
	print("CHIVOS Y PASES: %d fallos" % fallos)
	quit()


## Mesa a mano: manos dadas, línea con puntas izq/der, turno de la silla 0.
func _mesa(manos: Array, izq: int, der: int):
	var g = Game.new()
	g.new_game()
	g.human_pick(g.offers[0][0])
	g.finish_draw(g.auto_picks([]))
	g.cards = [[], [], [], []]
	g.first_hand = false
	g.hands = manos
	g.chain = [Vector2i(izq, 9), Vector2i(9, der)]
	g.left_end = izq
	g.right_end = der
	g.turn = 0
	g.phase = "play"
	g.chivo = {}
	g.skip_next = [false, false, false, false]
	return g
