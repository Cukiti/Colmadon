extends SceneTree
## Juega miles de partidas solo con bots (scripts/game.gd, sin nada visual) y
## mide el equilibrio de cartas de aumento y bebidas. Uso:
## godot --headless --path . --script res://tests/simulacion_equilibrio.gd
## Opciones (después de «--»): n=2000 (partidas por experimento), seed=1,
## rapido (solo la línea base y los experimentos principales),
## secciones=1,2,4 (elige qué experimentos se juegan; 6 = bot nuevo contra viejo),
## cartas=marcada,suerte (solo esas cartas en los experimentos 2 y 3).
##
## Experimentos (la pareja «prueba» se alterna entre la 0 y la 1 para quitar
## la ventaja de asiento):
##  1. Línea base: todos eligen cartas al azar y compran como los bots.
##  2. Carta sola: la pareja prueba tiene solo la carta X; la otra, ninguna.
##  3. Preferir carta: la pareja prueba coge X siempre que se la ofrecen; la
##     otra no la coge nunca (la decisión real del jugador).
##  4. Bebida sola: la pareja prueba compra solo X; la otra no compra nada.
##     Se mide la ganancia de victoria por cada 10 monedas gastadas.
##  5. Bebida contra bebida: la pareja prueba compra solo X; la otra solo Y.
##  6. Bot nuevo contra bot viejo: una pareja juega con la lógica de game.gd y
##     la otra con la anterior (tests/bot_viejo.gd).

const Game := preload("res://scripts/game.gd")
const BotViejo := preload("res://tests/bot_viejo.gd")

var n_games := 2000
var sections := [1, 2, 3, 4, 5, 6]
var only_cards: Array = []


func _init() -> void:
	var seed_val := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="):
			n_games = int(a.substr(2))
		elif a.begins_with("seed="):
			seed_val = int(a.substr(5))
		elif a == "rapido":
			sections = [1, 2, 4]
		elif a.begins_with("secciones="):
			sections = Array(a.substr(10).split(",")).map(func(x): return int(x))
		elif a.begins_with("cartas="):
			only_cards = Array(a.substr(7).split(","))
	seed(seed_val)
	var t0 := Time.get_ticks_msec()
	_print_constants()
	if 1 in sections:
		_baseline()
	if 2 in sections:
		_cards_alone()
	if 3 in sections:
		_cards_prefer()
	if 4 in sections:
		_drinks_alone()
	if 5 in sections:
		_drinks_vs()
	if 6 in sections:
		_new_vs_old()
	print("\n_Tiempo: %.1f s, %d partidas por experimento._" % [(Time.get_ticks_msec() - t0) / 1000.0, n_games])
	quit()


# ---------------------------------------------------------------- políticas

## cfg por pareja: {"cards": "random" | "bot" | "solo:X" | "none" | "prefer:X" | "avoid:X",
##                  "shop": "bot" | "viejo" | "none" | "solo:X"}
## old_team: pareja que juega con la lógica de bot vieja (-1 = ninguna).
func play_game(cfg: Array, old_team := -1) -> Dictionary:
	var g = Game.new() if old_team < 0 else BotViejo.new()
	if old_team >= 0:
		g.old_team = old_team
	g.new_game()
	var res := {"hands": 0, "reasons": {}, "spent": [0, 0], "used": [{}, {}],
		"hand_log": [], "pts_hand": [0, 0], "winner": -1, "steps": 0}
	var hand_cards: Array = []
	var steps := 0
	while g.phase != "over" and steps < 5000:
		steps += 1
		match g.phase:
			"pick":
				g.human_pick(g.offers[0][0])
				for s in 4:
					_apply_card_policy(g, s, cfg[s % 2].cards)
				hand_cards = []
				for team in 2:
					var cs := {}
					for s in [team, team + 2]:
						for c in g.cards[s]:
							cs[c] = true
					hand_cards.append(cs)
			"draw":
				g.finish_draw(g.auto_picks([]))
			"play":
				g.bot_turn()
				for e in g.events:
					if e.k == "drink":
						var u: Dictionary = res.used[e.seat % 2]
						u[e.id] = u.get(e.id, 0) + 1
					elif e.k == "end":
						var r: String = g.last_result.reason
						res.reasons[r] = res.reasons.get(r, 0) + 1
						res.hands += 1
						res.pts_hand[g.last_result.team] += g.last_result.pts
						res.hand_log.append({"team": g.last_result.team, "cards": hand_cards})
				g.events.clear()
			"shop":
				# deshace la compra automática de los bots y aplica la política
				for p in g.bot_purchases:
					g.coins[p[0]] += g.drink_cost(p[0], p[1])
					g.drinks[p[0]].erase(p[1])
				g.bot_purchases.clear()
				for s in 4:
					res.spent[s % 2] += _apply_shop_policy(g, s, cfg[s % 2].shop)
				g.new_hand()
	res.steps = steps
	res.winner = 0 if g.scores[0] >= g.scores[1] else 1
	res.scores = g.scores.duplicate()
	return res


func _apply_card_policy(g, s: int, pol: String) -> void:
	var offers: Array = g.offers[s]
	var pick: String
	if pol == "random":
		pick = offers.pick_random()
	elif pol == "bot":
		g.cards[s].pop_back()
		g.cards[s].append(g.bot_pick_card(s))
		return
	elif pol == "none":
		g.cards[s].clear()
		return
	elif pol.begins_with("solo:"):
		g.cards[s] = [pol.substr(5)]
		return
	elif pol.begins_with("prefer:"):
		var x := pol.substr(7)
		pick = x if offers.has(x) else offers.pick_random()
	elif pol.begins_with("avoid:"):
		var x := pol.substr(6)
		var rest: Array = offers.filter(func(c): return c != x)
		pick = rest.pick_random() if not rest.is_empty() else offers.pick_random()
	g.cards[s][-1] = pick


func _apply_shop_policy(g, s: int, pol: String) -> int:
	var before: int = g.coins[s]
	if pol == "bot":
		# igual que _bots_shop, pero para los 4 asientos
		g.bot_buy(s)
	elif pol == "viejo":
		# compra del bot anterior: 70 % de las veces, al azar entre café, ron y agua
		if randf() < 0.7:
			var opts: Array = ["cafe", "ron", "agua"].filter(func(d): return g.can_buy(s, d))
			if not opts.is_empty():
				g.buy(s, opts.pick_random())
	elif pol.begins_with("solo:"):
		var d := pol.substr(5)
		while g.can_buy(s, d):
			g.buy(s, d)
	return before - g.coins[s]


# ---------------------------------------------------------------- medición

## Juega n partidas con la pareja prueba alternando de asiento. Devuelve la
## tasa de victoria de la pareja prueba y más datos.
func run(test: Dictionary, other: Dictionary, n := -1, other_old := false) -> Dictionary:
	if n < 0:
		n = n_games
	var wins := 0
	var hands := 0
	var spent := 0.0
	var used := 0
	var margin := 0.0
	var reasons := {}
	for i in n:
		var tt := i % 2
		var cfg: Array = [test, other] if tt == 0 else [other, test]
		var r := play_game(cfg, (1 - tt) if other_old else -1)
		if r.winner == tt:
			wins += 1
		hands += r.hands
		spent += r.spent[tt]
		for k in r.used[tt]:
			used += r.used[tt][k]
		margin += float(r.pts_hand[tt] - r.pts_hand[1 - tt]) / max(r.hands, 1)
		for k in r.reasons:
			reasons[k] = reasons.get(k, 0) + r.reasons[k]
	var wr := float(wins) / n
	return {"wr": wr, "se": sqrt(wr * (1.0 - wr) / n), "hands": float(hands) / n,
		"spent": spent / n, "used": float(used) / n, "margin": margin / n, "reasons": reasons}


func pct(x: float) -> String:
	return "%.1f %%" % (x * 100.0)


func pp(x: float) -> String:
	return "%+.1f" % (x * 100.0)


func _print_constants() -> void:
	print("## Valores actuales de game.gd\n")
	print("Meta %d · ganador %d monedas · perdedor %d · falsa alarma −%d\n" % [Game.TARGET, Game.WIN_COINS, Game.LOSE_COINS, Game.CHIVO_FALSE_FINE])
	print("| Bebida | Precio |")
	print("|---|---|")
	for d in Game.DRINKS:
		print("| %s | %d |" % [Game.DRINKS[d].name, Game.DRINKS[d].cost])


func _baseline() -> void:
	print("\n## 1. Línea base (cartas y compras como los bots)\n")
	var n := n_games * 2
	var hands := 0
	var reasons := {}
	var max_h := 0
	var team_wins := [0, 0]
	var hist := {}
	# por carta: manos en que solo una pareja la tiene y cuántas gana esa pareja
	var excl := {}
	for c in Game.CARDS:
		excl[c] = [0, 0]
	for i in n:
		var r := play_game([{"cards": "bot", "shop": "bot"}, {"cards": "bot", "shop": "bot"}])
		hands += r.hands
		max_h = max(max_h, r.hands)
		hist[r.hands] = hist.get(r.hands, 0) + 1
		team_wins[r.winner] += 1
		for k in r.reasons:
			reasons[k] = reasons.get(k, 0) + r.reasons[k]
		for h in r.hand_log:
			for c in Game.CARDS:
				var a: bool = h.cards[0].has(c)
				var b: bool = h.cards[1].has(c)
				if a != b:
					excl[c][0] += 1
					if (h.team == 0) == a:
						excl[c][1] += 1
	print("Partidas: %d · manos: %d · **media %.2f manos por partida** (máx %d)\n" % [n, hands, float(hands) / n, max_h])
	print("| Fin de mano | Manos | % |")
	print("|---|---|---|")
	for k in ["dominó", "tranque", "chivo"]:
		print("| %s | %d | %s |" % [k, reasons.get(k, 0), pct(float(reasons.get(k, 0)) / hands)])
	var keys := hist.keys()
	keys.sort()
	var dist := []
	for k in keys:
		dist.append("%d manos: %s" % [k, pct(float(hist[k]) / n)])
	print("\nDuración: " + ", ".join(dist))
	print("\nPareja 0 gana %s (control de asiento)\n" % pct(float(team_wins[0]) / n))
	print("Observacional, por mano: cuando solo una pareja tiene la carta, ¿cuántas manos gana?\n")
	print("| Carta | Manos comparadas | Gana la pareja que la tiene |")
	print("|---|---|---|")
	for c in Game.CARDS:
		var e: Array = excl[c]
		print("| %s | %d | %s |" % [Game.CARDS[c].name, e[0], pct(float(e[1]) / max(e[0], 1))])


func _card_list() -> Array:
	return only_cards if not only_cards.is_empty() else Game.CARDS.keys()


func _cards_alone() -> void:
	print("\n## 2. Carta sola frente a ninguna carta (compras de bot)\n")
	print("| Carta | Victoria con la carta | ± | Margen pts/mano | Manos/partida |")
	print("|---|---|---|---|---|")
	var ctl := run({"cards": "none", "shop": "bot"}, {"cards": "none", "shop": "bot"})
	print("| (control: nadie tiene cartas) | %s | %s | %+.2f | %.2f |" % [pct(ctl.wr), pct(ctl.se), ctl.margin, ctl.hands])
	for c in _card_list():
		var r := run({"cards": "solo:" + c, "shop": "bot"}, {"cards": "none", "shop": "bot"})
		print("| %s | %s | %s | %+.2f | %.2f |" % [Game.CARDS[c].name, pct(r.wr), pct(r.se), r.margin, r.hands])


func _cards_prefer() -> void:
	print("\n## 3. Preferir la carta frente a evitarla (partida normal)\n")
	print("| Carta | Victoria de quien la prefiere | ± |")
	print("|---|---|---|")
	for c in _card_list():
		var r := run({"cards": "prefer:" + c, "shop": "bot"}, {"cards": "avoid:" + c, "shop": "bot"})
		print("| %s | %s | %s |" % [Game.CARDS[c].name, pct(r.wr), pct(r.se)])


func _drinks_alone() -> void:
	print("\n## 4. Bebida sola frente a no comprar (cartas al azar)\n")
	print("| Bebida | Precio | Victoria | ± | Monedas gastadas/partida | Bebidas usadas/partida | pp de victoria por 10 monedas |")
	print("|---|---|---|---|---|---|---|")
	var mix := run({"cards": "random", "shop": "bot"}, {"cards": "random", "shop": "none"})
	print("| (mezcla de bot) | — | %s | %s | %.1f | %.2f | %s |" % [pct(mix.wr), pct(mix.se), mix.spent, mix.used, pp((mix.wr - 0.5) * 10.0 / max(mix.spent, 0.01))])
	for d in Game.DRINKS:
		var r := run({"cards": "random", "shop": "solo:" + d}, {"cards": "random", "shop": "none"})
		print("| %s | %d | %s | %s | %.1f | %.2f | %s |" % [Game.DRINKS[d].name, Game.DRINKS[d].cost, pct(r.wr), pct(r.se), r.spent, r.used, pp((r.wr - 0.5) * 10.0 / max(r.spent, 0.01))])


func _drinks_vs() -> void:
	print("\n## 5. Bebida contra bebida (victoria de la fila frente a la columna)\n")
	var ids := ["cafe", "ron", "agua", "morir"]
	var head: String = "| | " + " | ".join(ids.map(func(d): return Game.DRINKS[d].name)) + " |"
	print(head)
	print("|---" + "|---".repeat(ids.size()) + "|")
	var m := {}
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var r := run({"cards": "random", "shop": "solo:" + ids[i]}, {"cards": "random", "shop": "solo:" + ids[j]})
			m[ids[i] + "|" + ids[j]] = r.wr
			m[ids[j] + "|" + ids[i]] = 1.0 - r.wr
	for a in ids:
		var row: String = "| " + Game.DRINKS[a].name + " |"
		for b in ids:
			row += " — |" if a == b else " %s |" % pct(m[a + "|" + b])
		print(row)


func _new_vs_old() -> void:
	print("\n## 6. Bot nuevo contra bot viejo (cambiando de asiento)\n")
	print("| Prueba | Victoria del bot nuevo | ± | Margen pts/mano | Manos/partida |")
	print("|---|---|---|---|---|")
	var old := {"cards": "random", "shop": "viejo"}
	var full := run({"cards": "bot", "shop": "bot"}, old, -1, true)
	print("| Completo (juego, cartas y compras nuevos) | %s | %s | %+.2f | %.2f |" % [pct(full.wr), pct(full.se), full.margin, full.hands])
	var only := run(old, old, -1, true)
	print("| Solo la forma de jugar (mismas cartas y compras) | %s | %s | %+.2f | %.2f |" % [pct(only.wr), pct(only.se), only.margin, only.hands])
	var none := {"cards": "none", "shop": "none"}
	var bare := run(none, none, -1, true)
	print("| Sin cartas ni bebidas | %s | %s | %+.2f | %.2f |" % [pct(bare.wr), pct(bare.se), bare.margin, bare.hands])
	var ojo := {"cards": "solo:ojo", "shop": "none"}
	var r_ojo := run(ojo, ojo, -1, true)
	print("| Las dos parejas con Ojo pícaro, sin bebidas | %s | %s | %+.2f | %.2f |" % [pct(r_ojo.wr), pct(r_ojo.se), r_ojo.margin, r_ojo.hands])
	var morir := {"cards": "none", "shop": "solo:morir"}
	var r_morir := run(morir, morir, -1, true)
	print("| Las dos parejas solo con Morir soñando | %s | %s | %+.2f | %.2f |" % [pct(r_morir.wr), pct(r_morir.se), r_morir.margin, r_morir.hands])
