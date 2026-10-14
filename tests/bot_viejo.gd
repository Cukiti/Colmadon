extends "res://scripts/game.gd"
## Solo para tests/simulacion_equilibrio.gd: la lógica de bot anterior a
## «bots más listos» (2026-10-04, ya con la memoria de pases de Ficha
## marcada), copiada tal cual, para medir el bot nuevo contra el viejo en la
## misma mesa. La pareja `old_team` juega con
## la lógica vieja; la otra, con la nueva de game.gd.

var old_team := -1  # 2 = las dos parejas juegan con la lógica vieja


func bot_turn() -> void:
	if turn % 2 != old_team and old_team != 2:
		super.bot_turn()
		return
	var seat := turn
	# ¿el anterior metió chivo? lo ven 6 de cada 10 veces; con ron, 2 de 10
	if not chivo.is_empty() and chivo.seat == (seat + 3) % 4:
		var sees: float = 0.2 if drank_ron[seat] else 0.6
		if randf() < sees:
			if call_chivo(seat):
				return
	var moves := legal_moves(seat)
	_old_bot_drink(seat, moves)
	moves = legal_moves(seat)
	if moves.is_empty():
		var plain: Array = hands[seat].filter(func(x): return x.x != x.y)
		if not chain.is_empty() and hands[seat].size() > 2 and not plain.is_empty() and randf() < 0.04:
			if play_chivo(seat, plain.pick_random(), [-1, 1].pick_random()):
				return
		pass_turn(seat)
		return
	if hands[seat].size() > 3 and randf() < 0.004:
		pass_fake(seat)
		return
	var best: Dictionary = moves[0]
	var best_score := -INF
	for m in moves:
		var sc := _old_move_score(seat, m)
		if sc > best_score:
			best_score = sc
			best = m
	play(seat, best.tile, best.side)


## Compra vieja: 70 % de las veces, una al azar entre café, ron y agua.
func old_bot_buy(s: int) -> String:
	if randf() < 0.7:
		var opts: Array = ["cafe", "ron", "agua"].filter(func(d): return can_buy(s, d))
		if not opts.is_empty():
			var d: String = opts.pick_random()
			buy(s, d)
			return d
	return ""


func _old_bot_drink(seat: int, moves: Array) -> void:
	if drinks[seat].is_empty():
		return
	var rival := (seat + 1) % 4
	for d in drinks[seat]:
		var use := false
		match d:
			"agua":
				use = hands[rival].size() <= 2 or randf() < 0.15
			"cafe":
				use = moves.size() >= 2 and hands[seat].size() <= 4
			"ron":
				var mine: int = hands[seat].size() + hands[(seat + 2) % 4].size()
				var theirs: int = hands[rival].size() + hands[(seat + 3) % 4].size()
				use = not hot_hand and mine < theirs
		if use:
			use_drink(seat, d)
			return


func _old_move_score(seat: int, m: Dictionary) -> float:
	var t: Vector2i = m.tile
	var rest: Array = hands[seat].filter(func(x): return x != t)
	if rest.is_empty():
		return 10000.0
	var ends := _ends_after(t, m.side)
	var partner := (seat + 2) % 4
	var nxt := (seat + 1) % 4
	var prev := (seat + 3) % 4
	var lacks_nxt := seen_lacks(seat, nxt)
	var lacks_prev := seen_lacks(seat, prev)
	var score := float(t.x + t.y) * 0.8
	if t.x == t.y:
		score += 6.0
	for x in rest:
		if ends.has(x.x) or ends.has(x.y):
			score += 3.0
	for e in ends:
		if lacks_nxt.has(e):
			score += 8.0
		if lacks_prev.has(e):
			score += 5.0
		if lacks[partner].has(e):
			score -= 7.0
		score += played_nums[partner].get(e, 0) * 2.0
	if lacks_nxt.has(ends[0]) and lacks_nxt.has(ends[1]):
		score += 14.0
	return score + randf() * 1.5
