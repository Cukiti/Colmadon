extends SceneTree
## Genera servidor/modulo/tests/paridad_bots.json: estados reales de partidas
## de bots con la nota de cada jugada legal (sin azar). La prueba del servidor
## (tests/paridad.test.ts, dentro de npm test) comprueba que reglas.ts da las
## mismas notas. Repetir tras cambiar la lógica de los bots:
## godot --headless --path . --script res://tests/paridad_bots.gd -- n=400

const Game := preload("res://scripts/game.gd")
const OUT := "res://servidor/modulo/tests/paridad_bots.json"


func _init() -> void:
	var n := 400
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="):
			n = int(a.substr(2))
	seed(7)
	var states: Array = []
	var games := 0
	while states.size() < n:
		games += 1
		var g = Game.new()
		g.new_game()
		var steps := 0
		while g.phase != "over" and steps < 5000 and states.size() < n:
			steps += 1
			match g.phase:
				"pick":
					g.human_pick(g.offers[0].pick_random())
					# más cartas al azar para que salgan todas las combinaciones
					for s in 4:
						if randf() < 0.5:
							g.cards[s].append(Game.CARDS.keys().pick_random())
				"draw":
					g.finish_draw(g.auto_picks([]))
				"play":
					var moves: Array = g.legal_moves(g.turn)
					if moves.size() >= 2 and randf() < 0.25:
						states.append(_snapshot(g, g.turn, moves))
					g.bot_turn()
				"shop":
					g.new_hand()
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"estados": states}))
	f.close()
	print("PARIDAD %d estados de %d partidas → %s" % [states.size(), games, OUT])
	quit()


func _t(t: Vector2i) -> Array:
	return [t.x, t.y]


func _tiles(a: Array) -> Array:
	return a.map(_t)


func _snapshot(g, seat: int, moves: Array) -> Dictionary:
	g.bot_noise = 0.0
	var view: Dictionary = g._bot_view(seat)
	var notes: Array = []
	for m in moves:
		notes.append({"tile": _t(m.tile), "side": m.side, "nota": g._move_score(seat, m, view)})
	g.bot_noise = 1.5
	var hands: Array = []
	var seen: Array = []
	for s in 4:
		hands.append(_tiles(g.hands[s]))
		seen.append(_tiles(g.seen[s]))
	return {"seat": seat, "hands": hands, "chain": _tiles(g.chain), "left_end": g.left_end,
		"right_end": g.right_end, "lacks": g.lacks.duplicate(true),
		"last_pass": g.last_pass.duplicate(true), "played_nums": g.played_nums.duplicate(true),
		"cards": g.cards.duplicate(true), "revealed": seen, "opener": g.opener,
		"reveal_partner": g.sees_partner.duplicate(), "moves": notes}
