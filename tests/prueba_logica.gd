extends SceneTree
## Juega cientos de partidas solo con bots y comprueba en cada paso las reglas
## que nunca se deben romper. Uso:
## godot --headless --path . --script res://tests/prueba_logica.gd

const Game := preload("res://scripts/game.gd")

var fails := {}


func fail(kind: String, detail: String) -> void:
	if not fails.has(kind):
		fails[kind] = [0, detail]
	fails[kind][0] += 1


func check(g, ctx: String) -> void:
	# 1) siempre 28 fichas distintas entre manos y línea
	var all: Array = g.chain.duplicate()
	for s in 4:
		all.append_array(g.hands[s])
	var norm := {}
	for t in all:
		var k := Vector2i(min(t.x, t.y), max(t.x, t.y))
		if norm.has(k):
			fail("ficha repetida", "%s %s" % [ctx, k])
		norm[k] = true
	if g.phase == "play" and all.size() != 28:
		fail("no hay 28 fichas", "%s hay %d" % [ctx, all.size()])
	# 2) la línea casa (salvo chivos marcados)
	for i in range(1, g.chain.size()):
		if g.chain[i - 1].y != g.chain[i].x:
			if not g.get_meta("chivos", []).has(g.chain[i]) and not g.get_meta("chivos", []).has(g.chain[i - 1]):
				fail("línea no casa", "%s %s|%s" % [ctx, g.chain[i - 1], g.chain[i]])
	if not g.chain.is_empty():
		if g.left_end != g.chain[0].x or g.right_end != g.chain[-1].y:
			fail("puntas mal", "%s L%d R%d chain %s..%s" % [ctx, g.left_end, g.right_end, g.chain[0], g.chain[-1]])
		if g.origin < 0 or g.origin >= g.chain.size():
			fail("origen fuera", "%s origin %d size %d" % [ctx, g.origin, g.chain.size()])
	# 3) monedas y puntos
	for s in 4:
		if g.coins[s] < 0:
			fail("monedas negativas", ctx)
		if g.drinks[s].size() > 2:
			fail("más de 2 bebidas", ctx)
	if g.turn < 0 or g.turn > 3:
		fail("turno inválido", ctx)


func _init() -> void:
	randomize()
	var games := 300
	var hands_total := 0
	var reasons := {}
	var max_hands := 0
	for n in games:
		var g = Game.new()
		g.new_game()
		var steps := 0
		var prev_scores := [0, 0]
		while g.phase != "over" and steps < 5000:
			steps += 1
			match g.phase:
				"pick":
					g.human_pick(g.offers[0].pick_random())
				"draw":
					g.finish_draw(g.auto_picks([]))
					if g.first_hand and not g.hands[g.turn].has(Vector2i(6, 6)):
						fail("primera mano no sale el 6-6", "turno %d" % g.turn)
					hands_total += 1
				"play":
					var before: int = g.chain.size()
					var seat: int = g.turn
					var hand_before: int = g.hands[seat].size()
					g.bot_turn()   # el asiento 0 también juega como bot
					for e in g.events:
						if e.k == "play" and e.get("chivo", false):
							var cv: Array = g.get_meta("chivos", [])
							cv.append(g.chain[0] if g.chain.size() > 0 and g.last_seat == e.seat else Vector2i(-9, -9))
							cv.append_array(g.chain)  # tras un chivo no se exige casar
							g.set_meta("chivos", cv)
						if e.k == "end":
							reasons[g.last_result.reason] = reasons.get(g.last_result.reason, 0) + 1
					g.events.clear()
					if g.phase == "play" and g.chain.size() == before and g.hands[seat].size() != hand_before:
						fail("mano cambia sin jugar", "")
					check(g, "partida %d paso %d" % [n, steps])
				"shop":
					if g.scores[0] < prev_scores[0] or g.scores[1] < prev_scores[1]:
						fail("puntos bajan", "")
					prev_scores = g.scores.duplicate()
					if g.has_meta("chivos"):
						g.remove_meta("chivos")
					for s in 4:
						if g.hands[s].size() == 0 and g.last_result.reason == "dominó" and s != g.last_result.seat:
							fail("dominó mal atribuido", "")
					g.new_hand()
		if steps >= 5000:
			fail("partida no termina", "partida %d fase %s" % [n, g.phase])
		if g.scores[0] < g.target and g.scores[1] < g.target:
			fail("termina sin llegar a 100", str(g.scores))
		max_hands = max(max_hands, g.hand_no)
	_new_cards()
	print("PARTIDAS %d · manos %d · máx manos en una partida %d" % [games, hands_total, max_hands])
	print("FINALES ", reasons)
	if fails.is_empty():
		print("SIN FALLOS")
	for k in fails:
		print("FALLO %s ×%d  ej: %s" % [k, fails[k][0], fails[k][1]])
	quit()


func _table(cards: Array, hands: Array, chain: Array, last: int, turn: int):
	var g = Game.new()
	g.new_game()
	g.phase = "play"
	g.first_hand = false
	g.cards = cards
	g.hands = hands
	g.chain = chain
	g.left_end = chain[0].x
	g.right_end = chain[-1].y
	g.last_seat = last
	g.turn = turn
	return g


## Cartas nuevas (los mismos casos que servidor/modulo/tests/reglas.test.ts).
func _new_cards() -> void:
	var v := func(a, b): return Vector2i(a, b)
	var block_hands := func(): return [[v.call(0, 1)], [v.call(0, 2)], [v.call(6, 6), v.call(5, 6)], [v.call(1, 1)]]
	# Tranque por parejas (2026-10-04): pareja 0 = 1 + 23, pareja 1 = 2 + 2 → gana la pareja 1;
	# de ella sale la siguiente quien menos tiene (empate 2-2: el primero desde quien trancó, la silla 1)
	var g = _table([[], [], [], []], block_hands.call(), [v.call(4, 4)], 0, 0)
	g._end_hand(-1, Vector2i(-1, -1), false)
	if g.last_result.team != 1 or g.last_result.seat != 1 or g.last_result.tranque.teams != [24, 4]:
		fail("tranque por parejas", str(g.last_result))
	# empate 3-3: gana la pareja que salió (la del 1), y sale quien salió
	var tie_hands := func(): return [[v.call(0, 3)], [v.call(0, 1)], [v.call(0, 0)], [v.call(0, 2)]]
	g = _table([[], [], [], []], tie_hands.call(), [v.call(4, 4)], 0, 0)
	g.opener = 1
	g._end_hand(-1, Vector2i(-1, -1), false)
	if g.last_result.team != 1 or g.last_result.seat != 1 or not g.last_result.tranque.tie:
		fail("tranque empatado: gana quien salió", str(g.last_result))
	# Tranque seguro: el empate es para la pareja con la carta (sale su jugador con menos: la silla 2)
	g = _table([["tranque"], [], [], []], tie_hands.call(), [v.call(4, 4)], 0, 0)
	g.opener = 1
	g._end_hand(-1, Vector2i(-1, -1), false)
	if g.last_result.team != 0 or g.last_result.seat != 2 or not g.last_result.bonus.has("Tranque seguro"):
		fail("Tranque seguro gana el empate", str(g.last_result))
	# meta 200: con 150 no se acaba
	g = _table([[], [], [], []], [[v.call(4, 1)], [v.call(6, 6)], [v.call(5, 5)], [v.call(6, 5)]], [v.call(4, 4)], 0, 0)
	g.target = 200
	g.scores = [140, 0]
	g.play(0, v.call(4, 1), 1)
	if g.phase == "over":
		fail("meta 200: se acabó antes de tiempo", str(g.scores))
	# Ficha marcada: +3 por el pase del rival tras su ficha
	g = _table([["marcada"], [], [], []], [[v.call(3, 3), v.call(6, 6)], [v.call(0, 1)], [v.call(2, 5)], [v.call(0, 0)]], [v.call(4, 5)], 0, 1)
	g.pass_turn(1)
	if g.marks[0] != 1:
		fail("Ficha marcada no cuenta el pase", str(g.marks))
	g._end_hand(0, v.call(3, 3), false)
	if not g.last_result.bonus.has("Ficha marcada +3"):
		fail("Ficha marcada no suma +3", str(g.last_result))
	# Ficha marcada: sin la carta, de un rival solo se recuerda su último pase
	g = _table([["marcada"], [], [], []], [[v.call(0, 0)], [v.call(0, 1)], [v.call(2, 2)], [v.call(0, 2)]], [v.call(4, 5)], 0, 1)
	g.lacks[1] = {1: true, 2: true, 4: true, 5: true}
	g.last_pass[1] = {4: true, 5: true}
	if g.seen_lacks(0, 1).size() != 4 or g.seen_lacks(2, 1).size() != 2 or g.seen_lacks(3, 1).size() != 4:
		fail("Ficha marcada: pases vistos", "")
	# Doble suerte: tras el 4-4, el 3-3 de la otra punta se juega solo
	var lucky_hands := func(): return [[v.call(4, 4), v.call(3, 3), v.call(1, 2)], [v.call(0, 1), v.call(3, 5)], [v.call(2, 5)], [v.call(0, 0)]]
	g = _table([["suerte"], [], [], []], lucky_hands.call(), [v.call(3, 4)], 3, 0)
	g.play(0, v.call(4, 4), 1)
	if g.hands[0].size() != 1 or g.chain.size() != 3 or g.left_end != 3 or g.turn != 1:
		fail("Doble suerte no juega el doble de la otra punta", str(g.chain))
	g = _table([[], [], [], []], lucky_hands.call(), [v.call(3, 4)], 3, 0)
	g.play(0, v.call(4, 4), 1)
	if g.hands[0].size() != 2 or g.turn != 1:
		fail("sin Doble suerte se juega un doble de más", str(g.chain))
