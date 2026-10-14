extends RefCounted
## Reglas del dominó por parejas + capa de aumentos y bebidas. Sin nada visual,
## para poder reutilizarlo en bots y en el servidor.

const TARGET := 100              # meta por defecto
var target := TARGET             # meta de esta partida: 100 o 200 (se elige al empezar)
const WIN_COINS := 10
const LOSE_COINS := 4
const MAX_DRINKS := 2

const CARDS := {
	"doble": {"name": "Doble fuerte", "desc": "Dominas con un doble: +30 puntos."},
	"capicua": {"name": "Capicúa", "desc": "Dominas con capicúa: +25 puntos."},
	"cierre": {"name": "Cierre ruidoso", "desc": "Cada vez que dominas: +6 puntos."},
	"pasador": {"name": "Pasador", "desc": "Cada vez que pasas: +4 monedas."},
	"bolsillo": {"name": "Bolsillo", "desc": "Ganas la mano: +8 monedas."},
	"ojo": {"name": "Ojo pícaro", "desc": "Al empezar cada mano ves 1 ficha de cada rival."},
	"ligera": {"name": "Mano ligera", "desc": "Si perdéis, tus fichas dan un 25 % menos a los rivales."},
	"fiado": {"name": "Fiado", "desc": "Las bebidas te cuestan 3 monedas menos."},
	"marcada": {"name": "Ficha marcada", "desc": "Ves a qué números pasa cada rival. +3 por cada pase tras tu ficha si ganáis."},
	"suerte": {"name": "Doble suerte", "desc": "Juegas un doble y llevas el de la otra punta: pones los dos."},
	"tranque": {"name": "Tranque seguro", "desc": "Tranque empatado a puntos: lo ganáis vosotros."},
}
const DRINKS := {
	"cafe": {"name": "Café", "desc": "Este turno juegas 2 fichas seguidas.", "cost": 14},
	"ron": {"name": "Ron", "desc": "Mano caliente: si tu pareja gana esta mano, +50 % de puntos.", "cost": 4},
	"morir": {"name": "Morir soñando", "desc": "Ves la mano de tu compañero esta mano.", "cost": 5},
	"agua": {"name": "Agua fría", "desc": "El rival siguiente pierde su próximo turno.", "cost": 11},
}

var phase := "pick"  # pick, draw, play, shop, over
# «aumentos»: con cartas y bebidas · «clasico»: dominó de siempre, sin cartas ni
# bebidas, y el renuncio cazado pierde la partida entera
var mode := "aumentos"
# pases seguidos desde la última ficha (aura de quien la puso): con el
# tercero, nadie fue y su pareja se lleva PASE_PTS
var pass_streak := 0
var last_pass_seat := -1   # quien pasó en la última acción (-1 si fue una ficha)
const PASE_PTS := 30       # pase de salida, pase corrido y acusación falsa de renuncio
var hands: Array = [[], [], [], []]
var chain: Array = []
var opener := 0   # quien puso la primera ficha (la línea crece hacia él)
var last_seat := 0  # quien jugó la última ficha
# robar: las 28 fichas boca abajo en la mesa; cada uno elige las suyas
var pool: Array = []
# chivo pendiente: {seat, kind ("ficha" o "pase"), tile}. Solo lo puede cantar
# el jugador que sigue, en su turno; si actúa sin cantarlo, el chivo se queda.
var chivo := {}
var drank_ron := [false, false, false, false]
const HOT_HAND := 0.5   # Ron: si gana la pareja que lo bebió, un 50 % más de puntos
const LIGHT_CUT := 0.25  # Mano ligera: parte de tus puntos que no cuenta si perdéis
var hot_hand := false
var hot_team := -1      # pareja que bebió ron esta mano
const MARK_PTS := 3      # Ficha marcada: puntos por cada pase de un rival tras tu ficha
var marks := [0, 0, 0, 0]  # Ficha marcada: pases de rivales provocados esta mano
# para la libreta del final: por pareja (0 = nosotros, 1 = ellos)
var stats := {}
const CHIVO_FALSE_FINE := 10
# lo que se sabe en la mesa (lo usan los bots y las reacciones)
var lacks: Array = [{}, {}, {}, {}]    # números a los que cada jugador ha pasado
var last_pass: Array = [{}, {}, {}, {}]  # solo los números de su último pase
var played_nums: Array = [{}, {}, {}, {}]  # números que ha jugado cada uno
var origin := 0   # índice de la primera ficha dentro de chain
var left_end := -1
var right_end := -1
var turn := 0
var scores := [0, 0]
var coins := [0, 0, 0, 0]
var cards: Array = [[], [], [], []]
var drinks: Array = [[], [], [], []]
var offers: Array = [[], [], [], []]
var skip_next := [false, false, false, false]
var extra_turn := false
var revealed: Array = []          # lo que ve la persona (silla 0) con Ojo pícaro
var reveal_partner := false       # la persona (silla 0) ve la mano de su compañero
# lo mismo por silla, para que los bots también usen esa información
var seen: Array = [[], [], [], []]           # fichas de rivales que ve cada silla
var sees_partner := [false, false, false, false]  # Morir soñando, por silla
var first_hand := true
var starter_next := 0
var hand_no := 0
var last_result := {}
var tranque_info := {}
var revision := {}       # «¡Ute va!» de una persona: {caller, accused} mientras revisa las fichas   # puntos de cada uno y de cada pareja en el último tranque (para la pantalla)
var bot_purchases: Array = []
var events: Array = []


func new_game(game_mode := "") -> void:
	if game_mode != "":
		mode = game_mode
	stats = {"manos": [0, 0], "dominos": [0, 0], "tranques": [0, 0], "capicuas": [0, 0], "chivos": [0, 0], "bebidas": [0, 0], "max_mano": [0, 0], "pases": [0, 0]}
	scores = [0, 0]
	coins = [0, 0, 0, 0]
	cards = [[], [], [], []]
	drinks = [[], [], [], []]
	first_hand = true
	hand_no = 0
	# nada de la partida anterior: si no, la mesa la volvía a dibujar al elegir el aumento
	chain = []
	left_end = -1
	right_end = -1
	last_result = {}
	chivo = {}
	new_hand()


func new_hand() -> void:
	hand_no += 1
	phase = "pick"
	hands = [[], [], [], []]   # como en el servidor: las manos se vacían al empezar otra
	revealed.clear()
	reveal_partner = false
	seen = [[], [], [], []]
	sees_partner = [false, false, false, false]
	skip_next = [false, false, false, false]
	extra_turn = false
	if mode == "clasico":
		# sin aumentos: directo a barajar
		offers = [[], [], [], []]
		_make_pool()
		phase = "draw"
		return
	for s in 4:
		var pool: Array = CARDS.keys().filter(func(k): return not cards[s].has(k))
		if pool.size() < 3:
			pool = CARDS.keys()
		pool.shuffle()
		offers[s] = pool.slice(0, 3)


func human_pick(id: String) -> void:
	cards[0].append(id)
	for s in range(1, 4):
		cards[s].append(bot_pick_card(s))
	_make_pool()
	phase = "draw"


func _make_pool() -> void:
	pool.clear()
	for a in 7:
		for b in range(a, 7):
			pool.append(Vector2i(a, b))
	pool.shuffle()


## Reparte según lo que eligió cada uno en la mesa: picks[seat] = índices de pool.
func finish_draw(picks: Array) -> void:
	for s in 4:
		hands[s] = []
		for idx in picks[s]:
			hands[s].append(pool[idx])
	_start_hand()
	phase = "play"


## Elección automática (bots o pruebas): los que no eligieron reciben al azar.
func auto_picks(human: Array) -> Array:
	var free: Array = []
	for i in pool.size():
		if not human.has(i):
			free.append(i)
	free.shuffle()
	var picks: Array = [human.duplicate(), [], [], []]
	while picks[0].size() < 7:
		picks[0].append(free.pop_back())
	for s in range(1, 4):
		for k in 7:
			picks[s].append(free.pop_back())
	return picks


func _start_hand() -> void:
	chivo = {}
	revision = {}
	pass_streak = 0
	last_pass_seat = -1
	drank_ron = [false, false, false, false]
	hot_hand = false
	hot_team = -1
	marks = [0, 0, 0, 0]
	chain.clear()
	left_end = -1
	right_end = -1
	lacks = [{}, {}, {}, {}]
	last_pass = [{}, {}, {}, {}]
	played_nums = [{}, {}, {}, {}]
	if first_hand:
		for s in 4:
			if hands[s].has(Vector2i(6, 6)):
				turn = s
	else:
		turn = starter_next
	for s in 4:
		if has_card(s, "ojo"):
			for r in [(s + 1) % 4, (s + 3) % 4]:
				var t: Vector2i = hands[r].pick_random()
				seen[s].append(t)
				if s == 0:
					revealed.append(t)


## La ficha ya está en la mesa: nadie la «ve» en una mano.
func _forget_seen(t: Vector2i) -> void:
	revealed.erase(t)
	for s in 4:
		seen[s].erase(t)


func has_card(seat: int, id: String) -> bool:
	return cards[seat].has(id)


func pip_sum(seat: int) -> int:
	var p := 0
	for t in hands[seat]:
		p += t.x + t.y
	return p


## ¿Casa la ficha en esa punta? (-1 izquierda, 1 derecha; con la mesa vacía,
## solo vale salir y en la primera mano solo con el doble seis). Es la ÚNICA
## regla de qué casa: jugar, meter chivo y cantarlo la usan todas. Ojo: con las
## dos puntas iguales casa en las dos (legal_moves solo da una para no repetir).
func fits(t: Vector2i, side: int) -> bool:
	if chain.is_empty():
		return not first_hand or t == Vector2i(6, 6)
	var e: int = left_end if side < 0 else right_end
	return t.x == e or t.y == e


## Jugada de una persona soltando la ficha en una punta: si casa ahí es una
## jugada normal; si no, es un chivo (si se puede meter). Devuelve "jugada",
## "chivo" o "" (no se pudo).
func play_or_chivo(seat: int, t: Vector2i, side: int) -> String:
	if chain.is_empty():
		return "jugada" if play(seat, t, 0) else ""
	if fits(t, side):
		return "jugada" if play(seat, t, side) else ""
	return "chivo" if play_chivo(seat, t, side) else ""


func legal_moves(seat: int) -> Array:
	var res: Array = []
	for t in hands[seat]:
		if chain.is_empty():
			if first_hand and t != Vector2i(6, 6):
				continue
			res.append({"tile": t, "side": 0})
		else:
			if t.x == left_end or t.y == left_end:
				res.append({"tile": t, "side": -1})
			if (t.x == right_end or t.y == right_end) and left_end != right_end:
				res.append({"tile": t, "side": 1})
	return res


func _expire_chivo(seat: int) -> void:
	if not chivo.is_empty() and seat == (chivo.seat + 1) % 4:
		chivo = {}


## Quién puede cantar el chivo ahora mismo (el jugador en turno, si el
## anterior metió uno).
func chivo_callable_by(seat: int) -> bool:
	return phase == "play" and turn == seat


## Meter un chivo: poner una ficha que no casa. No se puede dominar con chivo
## ni meter un doble (un doble que no casa se ve a la legua).
func play_chivo(seat: int, t: Vector2i, side: int) -> bool:
	if phase != "play" or turn != seat or not hands[seat].has(t) or not revision.is_empty():
		return false
	if chain.is_empty() or hands[seat].size() <= 1 or t.x == t.y:
		return false
	# si casa en esa punta no es chivo: es una jugada (antes, con las dos
	# puntas iguales, una ficha buena en la punta «repetida» contaba como chivo)
	if fits(t, -1 if side < 0 else 1):
		return false
	_expire_chivo(seat)
	hands[seat].erase(t)
	_forget_seen(t)
	last_seat = seat
	if side < 0:
		chain.push_front(t)
		origin += 1
		left_end = t.x
	else:
		chain.push_back(t)
		right_end = t.y
	chivo = {"seat": seat, "kind": "ficha", "tile": t, "real": true}
	pass_streak = 0
	last_pass_seat = -1
	events.append({"k": "play", "seat": seat, "chivo": true})
	_advance()
	return true


## Pasar teniendo jugada: también es chivo.
## Pasar teniendo jugada: es renuncio (chivo de pase). Para los demás es un
## pase como cualquier otro.
func pass_fake(seat: int) -> void:
	if phase != "play" or turn != seat or not revision.is_empty():
		return
	# sin jugada no hay renuncio: es un pase normal
	if legal_moves(seat).is_empty():
		pass_turn(seat)
		return
	_expire_chivo(seat)
	_note_pass(seat)
	chivo = {"seat": seat, "kind": "pase", "tile": Vector2i(-1, -1), "real": true}
	events.append({"k": "pass", "seat": seat, "by": last_seat})
	if _after_pass(seat):
		return
	_advance()


## Cantar chivo o «¡Ute va!». Si es verdad, la mano se acaba y la gana la
## pareja de quien cantó (en el clásico, un renuncio cazado pierde la partida
## entera). Si no, quien cantó paga la multa; y si acusó de renuncio a quien
## de verdad no llevaba, ve su mano y la pareja del acusado gana PASE_PTS.
func call_chivo(caller: int, review := false) -> bool:
	if phase != "play" or turn != caller or not revision.is_empty():
		return false
	var accused := (caller + 3) % 4
	# «¡Ute va!» de una persona (2026-10-04): antes de nada revisa las fichas de
	# quien pasó y elige la que sí iba (o «No llevaba»); ver resolve_revision
	if review and last_pass_seat == accused:
		revision = {"caller": caller, "accused": accused}
		events.append({"k": "revision", "seat": caller, "accused": accused})
		return false
	if not chivo.is_empty() and chivo.seat == accused and chivo.get("real", false):
		var kind: String = chivo.kind
		events.append({"k": "chivo_caught", "seat": caller, "cheater": accused, "kind": kind, "tile": chivo.tile})
		chivo = {}
		_end_hand(-1, Vector2i(-1, -1), false, caller, "renuncio" if kind == "pase" and mode == "clasico" else "chivo")
		return true
	coins[caller] = max(coins[caller] - CHIVO_FALSE_FINE, 0)
	if last_pass_seat == accused:
		events.append({"k": "chivo_false", "seat": caller, "accused": accused, "hand": hands[accused].duplicate()})
		_bonus_points(accused, PASE_PTS, "acusado")
	else:
		events.append({"k": "chivo_false", "seat": caller})
	return false


## Fin de la revisión del «¡Ute va!». Manda la verdad (confirmado 2026-10-04):
##   · elige una ficha que casa en una punta → renuncio cazado;
##   · elige una que no casa → «esa no iba» y puede buscar otra ("no_iba");
##   · «No llevaba» (none) → si de verdad no llevaba, falsa alarma; si sí
##     llevaba, se le enseña cuál y el renuncio cuenta igual.
## Devuelve "cazado", "falso", "no_iba" o "" (no vale).
func resolve_revision(caller: int, tile: Vector2i, none := false) -> String:
	if revision.is_empty() or int(revision.caller) != caller:
		return ""
	var acc: int = revision.accused
	if not none:
		if not hands[acc].has(tile):
			return ""
		if not (fits(tile, -1) or fits(tile, 1)):
			events.append({"k": "revision_no", "seat": caller, "tile": tile})
			return "no_iba"
	revision = {}
	var real: bool = not chivo.is_empty() and chivo.seat == acc and chivo.kind == "pase" and chivo.get("real", false)
	if real:
		var shown := tile
		if none:
			for t in hands[acc]:
				if fits(t, -1) or fits(t, 1):
					shown = t
					break
		events.append({"k": "chivo_caught", "seat": caller, "cheater": acc, "kind": "pase", "tile": shown, "visto": not none})
		chivo = {}
		_end_hand(-1, Vector2i(-1, -1), false, caller, "renuncio" if mode == "clasico" else "chivo")
		return "cazado"
	coins[caller] = max(coins[caller] - CHIVO_FALSE_FINE, 0)
	events.append({"k": "chivo_false", "seat": caller, "accused": acc, "hand": hands[acc].duplicate()})
	_bonus_points(acc, PASE_PTS, "acusado")
	return "falso"


## Tras un pase (de verdad o renuncio): sube el aura de quien puso la última
## ficha y reparte los puntos de pase. Devuelve true si la partida se acabó.
##   · Pase de salida: la primera ficha de la mano hace pasar al siguiente.
##   · Pase corrido: tras tu ficha pasan los otros tres (nadie fue).
func _after_pass(seat: int) -> bool:
	last_pass_seat = seat
	if chain.is_empty():
		return false
	pass_streak += 1
	var owner := last_seat
	events.append({"k": "aura", "seat": owner, "level": pass_streak})
	if chain.size() == 1 and pass_streak == 1 and seat == (opener + 1) % 4:
		if _bonus_points(owner, PASE_PTS, "salida"):
			return true
	if pass_streak == 3:
		if _bonus_points(owner, PASE_PTS, "corrido"):
			return true
	return false


## Puntos al momento (pases y acusación falsa). Si llegan a la meta, la
## partida se acaba ahí mismo. Devuelve true si se acabó.
func _bonus_points(seat: int, pts: int, why: String) -> bool:
	var team := seat % 2
	scores[team] += pts
	if not stats.is_empty():
		stats.pases[team] += 1
	events.append({"k": "bonus", "seat": seat, "pts": pts, "why": why})
	if scores[team] < target:
		return false
	last_result = {"seat": seat, "team": team, "pts": pts, "reason": why, "bonus": [], "capicua": false}
	starter_next = seat
	first_hand = false
	phase = "over"
	events.append({"k": "end", "seat": seat, "pts": pts})
	return true


func play(seat: int, t: Vector2i, side: int) -> bool:
	# solo jugadas que casan: nunca se cuela una ficha mal puesta como jugada buena
	if phase != "play" or turn != seat or not hands[seat].has(t) or not revision.is_empty():
		return false
	if not chain.is_empty() and side == 0:
		side = -1 if fits(t, -1) else 1   # sin punta elegida: donde case
	if not fits(t, side):
		return false
	_expire_chivo(seat)
	var capi := false
	if not chain.is_empty():
		var fl: bool = t.x == left_end or t.y == left_end
		var fr: bool = t.x == right_end or t.y == right_end
		# capicúa: la última ficha cabía por los dos lados y las puntas eran
		# distintas (con las dos iguales no vale; confirmado 2026-10-04)
		capi = fl and fr and left_end != right_end
	hands[seat].erase(t)
	_forget_seen(t)
	last_seat = seat
	pass_streak = 0
	last_pass_seat = -1
	for n in [t.x, t.y]:
		played_nums[seat][n] = played_nums[seat].get(n, 0) + 1
	if chain.is_empty():
		chain = [t]
		opener = seat
		origin = 0
		left_end = t.x
		right_end = t.y
	elif side < 0:
		var o: Vector2i = t if t.y == left_end else Vector2i(t.y, t.x)
		chain.push_front(o)
		origin += 1
		left_end = o.x
	else:
		var o: Vector2i = t if t.x == right_end else Vector2i(t.y, t.x)
		chain.push_back(o)
		right_end = o.y
	events.append({"k": "play", "seat": seat, "tile": t})
	if hands[seat].is_empty():
		_end_hand(seat, t, capi)
		return true
	var lucky := _lucky_double(seat, t)
	if lucky.x >= 0:
		events.append({"k": "lucky", "seat": seat})
		play(seat, lucky, -1 if lucky.x == left_end else 1)
		return true
	if extra_turn:
		extra_turn = false
		if not legal_moves(seat).is_empty():
			events.append({"k": "again", "seat": seat})
			return true
	_advance()
	return true


## Doble suerte: tras jugar un doble, si te queda el doble de la otra punta se
## juega solo (como mucho uno: el siguiente ya no casa). (-1, -1) si no hay.
func _lucky_double(seat: int, t: Vector2i) -> Vector2i:
	var res := Vector2i(-1, -1)
	if t.x != t.y or not has_card(seat, "suerte"):
		return res
	for x in hands[seat]:
		if x.x == x.y and (x.x == left_end or x.x == right_end) and x.x > res.x:
			res = x
	return res


func _note_pass(seat: int) -> void:
	lacks[seat][left_end] = true
	lacks[seat][right_end] = true
	last_pass[seat] = {left_end: true, right_end: true}
	# Ficha marcada: el rival pasa justo después de la ficha de quien la tiene
	if last_seat % 2 != seat % 2 and has_card(last_seat, "marcada"):
		marks[last_seat] += 1


## Lo que «viewer» recuerda de los pases de «target» (lo usan los bots): de su
## compañero, todo; de un rival, solo su último pase, salvo con Ficha marcada,
## que los ve todos. La persona usará esto para pintar la carta.
func seen_lacks(viewer: int, target: int) -> Dictionary:
	if viewer % 2 == target % 2 or has_card(viewer, "marcada"):
		return lacks[target]
	return last_pass[target]


func pass_turn(seat: int) -> void:
	if phase != "play" or turn != seat or not revision.is_empty():
		return
	# pasar teniendo jugada es renuncio, no un pase normal
	if not legal_moves(seat).is_empty():
		pass_fake(seat)
		return
	_expire_chivo(seat)
	if has_card(seat, "pasador"):
		coins[seat] += 4
	_note_pass(seat)
	# «by»: quien jugó antes y le tapó la jugada
	events.append({"k": "pass", "seat": seat, "by": last_seat})
	if _after_pass(seat):
		return
	_advance()


func _is_blocked() -> bool:
	if chain.is_empty():
		return false
	for s in 4:
		if not legal_moves(s).is_empty():
			return false
	return true


func _advance() -> void:
	if _is_blocked():
		_end_hand(-1, Vector2i(-1, -1), false)
		return
	var nxt := (turn + 1) % 4
	while skip_next[nxt]:
		skip_next[nxt] = false
		_expire_chivo(nxt)
		events.append({"k": "skip", "seat": nxt})
		nxt = (nxt + 1) % 4
	turn = nxt


func _end_hand(domino_seat: int, t: Vector2i, capi: bool, forced_winner := -1, forced_reason := "") -> void:
	var pts := 0
	for s in 4:
		pts += pip_sum(s)
	var win_seat := domino_seat
	var reason := "dominó"
	var bonus: Array = []
	if forced_winner >= 0:
		win_seat = forced_winner
		reason = forced_reason
		# chivo cazado: solo cuentan las fichas de la pareja tramposa
		if reason == "chivo" or reason == "renuncio":
			pts = pip_sum((win_seat + 1) % 4) + pip_sum((win_seat + 3) % 4)
	elif domino_seat < 0:
		# tranque (confirmado 2026-10-04): gana la PAREJA con menos puntos (sus
		# dos manos juntas); en empate, la pareja que salió en esta mano, salvo
		# que la otra tenga «Tranque seguro». De la pareja ganadora sale la
		# siguiente quien tenga menos puntos (en empate: quien salió, o el
		# primero en orden de juego desde quien trancó).
		reason = "tranque"
		var team_pips := [pip_sum(0) + pip_sum(2), pip_sum(1) + pip_sum(3)]
		var wteam: int = opener % 2
		var tie: bool = team_pips[0] == team_pips[1]
		if not tie:
			wteam = 0 if team_pips[0] < team_pips[1] else 1
		else:
			var other: int = 1 - opener % 2
			if (has_card(other, "tranque") or has_card(other + 2, "tranque")) and not (has_card(opener % 2, "tranque") or has_card(opener % 2 + 2, "tranque")):
				wteam = other
				bonus.append("Tranque seguro")
		win_seat = opener if (tie and wteam == opener % 2) else _lowest_of_team(wteam)
		tranque_info = {"pips": [pip_sum(0), pip_sum(1), pip_sum(2), pip_sum(3)], "teams": team_pips, "tie": tie, "opener": opener}
	else:
		if has_card(win_seat, "cierre"):
			pts += 6
			bonus.append("Cierre ruidoso +6")
		if t.x == t.y and has_card(win_seat, "doble"):
			pts += 30
			bonus.append("Doble fuerte +30")
		if capi and has_card(win_seat, "capicua"):
			pts += 25
			bonus.append("¡Capicúa! +25")
	var team := win_seat % 2
	# renuncio cazado en el clásico: la pareja de quien cantó gana la partida
	if reason == "renuncio":
		scores[team] = max(scores[team], target - pts)
	for s in 4:
		if s % 2 == team and marks[s] > 0:
			pts += marks[s] * MARK_PTS
			bonus.append("Ficha marcada +%d" % (marks[s] * MARK_PTS))
	# Mano ligera: las fichas del perdedor que la tiene cuentan un cuarto menos
	for s in 4:
		if s % 2 != team and has_card(s, "ligera") and pip_sum(s) > 0:
			var off := roundi(pip_sum(s) * LIGHT_CUT)
			pts -= off
			bonus.append("Mano ligera −%d" % off)
	if hot_hand and team == hot_team:
		var extra := roundi(pts * HOT_HAND)
		pts += extra
		bonus.append("Mano caliente +%d" % extra)
	scores[team] += pts
	if not stats.is_empty():
		stats.manos[team] += 1
		stats.max_mano[team] = max(stats.max_mano[team], pts)
		match reason:
			"dominó":
				stats.dominos[team] += 1
			"tranque":
				stats.tranques[team] += 1
			"chivo", "renuncio":
				stats.chivos[team] += 1
		if capi and domino_seat >= 0:
			stats.capicuas[team] += 1
	for s in 4:
		if mode == "clasico":
			break  # sin colmado: no hay monedas
		if s % 2 == team:
			coins[s] += WIN_COINS + (8 if has_card(s, "bolsillo") else 0)
		else:
			coins[s] += LOSE_COINS
	last_result = {"seat": win_seat, "team": team, "pts": pts, "reason": reason, "bonus": bonus, "capicua": capi and domino_seat >= 0}
	if reason == "tranque":
		last_result.tranque = tranque_info
	starter_next = win_seat
	first_hand = false
	events.append({"k": "end", "seat": win_seat, "pts": pts})
	if scores[team] >= target:
		phase = "over"
	else:
		phase = "shop"
		if mode == "clasico":
			bot_purchases.clear()
		else:
			_bots_shop()


## Jugador de una pareja con menos puntos en la mano (empate: el primero en
## orden de juego desde quien trancó).
func _lowest_of_team(team: int) -> int:
	var best := 999
	var res := team
	for k in 4:
		var s := (last_seat + k) % 4
		if s % 2 == team and pip_sum(s) < best:
			best = pip_sum(s)
			res = s
	return res


func drink_cost(seat: int, id: String) -> int:
	return DRINKS[id].cost - (3 if has_card(seat, "fiado") else 0)


func can_buy(seat: int, id: String) -> bool:
	return coins[seat] >= drink_cost(seat, id) and drinks[seat].size() < MAX_DRINKS


func buy(seat: int, id: String) -> void:
	if phase == "shop" and can_buy(seat, id):   # solo en el colmado, como en el servidor
		coins[seat] -= drink_cost(seat, id)
		drinks[seat].append(id)


func _bots_shop() -> void:
	bot_purchases.clear()
	for s in range(1, 4):
		var d := bot_buy(s)
		if d != "":
			bot_purchases.append([s, d])


func use_drink(seat: int, id: String) -> void:
	# como en el servidor: solo en tu turno de juego y si la tienes
	if phase != "play" or turn != seat or not drinks[seat].has(id) or not revision.is_empty():
		return
	drinks[seat].erase(id)
	if not stats.is_empty():
		stats.bebidas[seat % 2] += 1
	match id:
		"cafe":
			extra_turn = true
		"morir":
			sees_partner[seat] = true
			if seat == 0:
				reveal_partner = true
		"agua":
			skip_next[(seat + 1) % 4] = true
		"ron":
			drank_ron[seat] = true
			hot_hand = true
			hot_team = seat % 2
	events.append({"k": "drink", "seat": seat, "id": id})


# ---------------------------------------------------------------- bots

# Pesos del bot al elegir jugada (ver _move_score). Ajustados con
# tests/simulacion_equilibrio.gd (sección 6) para que el bot gane al anterior
# alrededor del 58-60 % sin volverse imbatible.
const BOT_W_NEXT := 16.0     # que el rival siguiente no pueda jugar
const BOT_W_PREV := 6.0      # que el rival de después tampoco
const BOT_W_PARTNER := 6.0   # no dejar al compañero sin jugada
const BOT_PIPS := 0.6        # soltar fichas pesadas (por punto)
const BOT_DOUBLE := 6.0      # soltar un doble...
const BOT_DOUBLE_K := 0.75   # ...y más cuantas más fichas de su número han salido
const BOT_SALIDA := 1.0      # dar al compañero los números que ya jugó
const BOT_LOCK := 4.0        # trancar: por punto de ventaja estimada (máx ±40)
var bot_noise := 1.5         # azar en la nota de cada jugada (0 en la prueba de paridad)
# Peso de cada bebida al comprar (las que el bot no conoce pesan 1)
const BOT_DRINK_WEIGHT := {"cafe": 3.0, "agua": 3.0, "ron": 2.0, "morir": 1.5}


## Bot que juega en pareja. Lleva la cuenta de lo que sabe de la mesa (fichas
## jugadas, números a los que pasó cada uno, lo que vio con Ojo pícaro y la
## mano del compañero si bebió Morir soñando) y con eso estima quién puede
## jugar cada número: tapa al rival que no lleva un número, no le cierra el
## juego a su compañero, suelta los dobles antes de que se queden sin salida
## y solo tranca si cree que su pareja gana el tranque.
func bot_turn() -> void:
	var seat := turn
	if not revision.is_empty():
		return   # una persona está revisando un «¡Ute va!»
	# ¿el anterior metió chivo? lo ven 6 de cada 10 veces; con ron, 2 de 10
	if not chivo.is_empty() and chivo.seat == (seat + 3) % 4:
		var sees: float = 0.2 if drank_ron[seat] else 0.6
		if randf() < sees:
			if call_chivo(seat):
				return
	var moves := legal_moves(seat)
	_bot_drink(seat, moves)
	moves = legal_moves(seat)
	if moves.is_empty():
		# sin jugada: a veces se arriesga con un chivo
		var plain: Array = hands[seat].filter(func(x): return x.x != x.y)
		# (en el clásico los bots juegan limpio: allí un renuncio pierde la partida)
		if mode != "clasico" and not chain.is_empty() and hands[seat].size() > 2 and not plain.is_empty() and randf() < 0.04:
			if play_chivo(seat, plain.pick_random(), [-1, 1].pick_random()):
				return
		pass_turn(seat)
		return
	if mode != "clasico" and hands[seat].size() > 3 and randf() < 0.004:
		pass_fake(seat)
		return
	var view := _bot_view(seat)
	var best: Dictionary = moves[0]
	var best_score := -INF
	for m in moves:
		var sc := _move_score(seat, m, view)
		if sc > best_score:
			best_score = sc
			best = m
	play(seat, best.tile, best.side)


## Carta de aumento de un bot: al azar entre sus 3 ofertas, pero con más peso
## para la que le conviene (puntos si va perdiendo, Mano ligera si va ganando,
## monedas si está pelado). Las cartas que no conoce pesan lo normal.
func bot_pick_card(s: int) -> String:
	var diff: int = scores[s % 2] - scores[1 - s % 2]
	var w: Array = []
	for id in offers[s]:
		var x := 1.0
		match id:
			"cierre", "doble", "capicua":
				if diff < 0:
					x += 0.5
			"ligera":
				if diff > 0:
					x += 0.5
			"bolsillo", "pasador", "fiado":
				if coins[s] < 11:
					x += 0.5
			"ojo":
				x += 0.3
		if cards[s].has(id):
			x *= 0.5
		w.append(x)
	return _weighted_pick(offers[s], w)


## Compra de un bot en el colmado: 7 de cada 10 veces compra una bebida que
## pueda pagar, al azar con pesos (ron si hay que remontar, agua si va
## ganando, menos peso a la que ya lleva). Devuelve la bebida o "".
func bot_buy(s: int) -> String:
	if drinks[s].size() >= MAX_DRINKS or randf() >= 0.7:
		return ""
	var diff: int = scores[s % 2] - scores[1 - s % 2]
	var ids: Array = []
	var w: Array = []
	for d in DRINKS:
		if not can_buy(s, d):
			continue
		var x: float = BOT_DRINK_WEIGHT.get(d, 1.0)
		if d == "ron" and diff < -20:
			x += 2.0
		if d == "agua" and diff > 20:
			x += 1.0
		if drinks[s].has(d):
			x *= 0.4
		ids.append(d)
		w.append(x)
	if ids.is_empty():
		return ""
	var pick: String = _weighted_pick(ids, w)
	buy(s, pick)
	return pick


func _weighted_pick(ids: Array, w: Array):
	var total := 0.0
	for x in w:
		total += x
	var r := randf() * total
	for i in ids.size():
		r -= w[i]
		if r < 0.0:
			return ids[i]
	return ids[-1]


func _bot_drink(seat: int, moves: Array) -> void:
	if drinks[seat].is_empty():
		return
	var rival := (seat + 1) % 4
	var partner := (seat + 2) % 4
	for d in drinks[seat]:
		var use := false
		match d:
			"morir":
				# ver la mano del compañero vale más al principio de la mano
				use = not sees_partner[seat]
			"agua":
				# frena al rival que va a dominar o deja jugar antes al compañero
				use = hands[rival].size() <= 2 or hands[partner].size() <= 1 or randf() < 0.15
			"cafe":
				use = moves.size() >= 2 and hands[seat].size() <= 4
			"ron":
				# apuesta: solo si su pareja lleva menos fichas que los rivales
				var mine: int = hands[seat].size() + hands[partner].size()
				var theirs: int = hands[rival].size() + hands[(seat + 3) % 4].size()
				use = not hot_hand and mine < theirs
			_:
				use = randf() < 0.2  # bebida que el bot no conoce
		if use:
			use_drink(seat, d)
			return


func _norm(t: Vector2i) -> Vector2i:
	return Vector2i(mini(t.x, t.y), maxi(t.x, t.y))


## Lo que sabe la silla `seat`: qué fichas ya salieron, dónde están las que ha
## visto (las suyas, las de Ojo pícaro y la mano del compañero con Morir
## soñando) y, para cada jugador y número, la probabilidad de que pueda
## jugarlo («can»). Un número del que ya salieron todas las fichas está muerto.
func _bot_view(seat: int) -> Dictionary:
	var partner := (seat + 2) % 4
	var owner := {}   # ficha (normalizada) -> silla que la tiene; -1 = en la mesa
	var on_table := [0, 0, 0, 0, 0, 0, 0]
	for t in chain:
		var k := _norm(t)
		owner[k] = -1
		on_table[k.x] += 1
		if k.y != k.x:
			on_table[k.y] += 1
	var slots: Array = []       # fichas que no conoce de cada jugador
	var known_pips := [0, 0, 0, 0]
	var can: Array = []
	# pases que recuerda (de los rivales, solo el último sin Ficha marcada)
	var miss_nums: Array = []
	for q in 4:
		miss_nums.append(seen_lacks(seat, q))
	for p in 4:
		slots.append(hands[p].size())
		can.append([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	for p in 4:
		for t in hands[p]:
			if p == seat or (p == partner and sees_partner[seat]) or seen[seat].has(t):
				owner[_norm(t)] = p
				slots[p] -= 1
				known_pips[p] += t.x + t.y
				can[p][t.x] = 1.0
				can[p][t.y] = 1.0
	var unknown: Array = []
	var hidden_pips := 0
	for a in 7:
		for b in range(a, 7):
			var k := Vector2i(a, b)
			if not owner.has(k):
				unknown.append(k)
				hidden_pips += a + b
	for n in 7:
		var u := 0
		for k in unknown:
			if k.x == n or k.y == n:
				u += 1
		# las fichas ocultas con n solo pueden estar en quien no ha pasado a n
		var total := 0
		for q in 4:
			if q != seat and not miss_nums[q].has(n):
				total += slots[q]
		for p in 4:
			if p == seat or can[p][n] > 0.0 or slots[p] == 0 or miss_nums[p].has(n) or u == 0:
				continue
			var miss := 1.0
			for i in u:
				if total - i <= 0:
					miss = 0.0
					break
				miss *= maxf(total - slots[p] - i, 0) / float(total - i)
			can[p][n] = 1.0 - miss
	return {"owner": owner, "on_table": on_table, "slots": slots, "known_pips": known_pips,
		"can": can, "avg": float(hidden_pips) / maxi(unknown.size(), 1)}


## Probabilidad de que un jugador no pueda jugar en ninguna de las puntas a, b.
func _blocked(row: Array, a: int, b: int) -> float:
	if a == b:
		return 1.0 - row[a]
	return (1.0 - row[a]) * (1.0 - row[b])


func _ends_after(t: Vector2i, side: int) -> Array:
	if chain.is_empty():
		return [t.x, t.y]
	if side < 0:
		return [t.x if t.y == left_end else t.y, right_end]
	return [left_end, t.y if t.x == right_end else t.x]


func _move_score(seat: int, m: Dictionary, view: Dictionary = {}) -> float:
	if view.is_empty():
		view = _bot_view(seat)
	var t: Vector2i = m.tile
	var rest: Array = hands[seat].filter(func(x): return x != t)
	if rest.is_empty():
		return 10000.0  # ¡dominó!
	var ends := _ends_after(t, m.side)
	var a: int = ends[0]
	var b: int = ends[1]
	var partner := (seat + 2) % 4
	var nxt := (seat + 1) % 4
	var prev := (seat + 3) % 4
	var can: Array = view.can
	# soltar las fichas pesadas
	var score := float(t.x + t.y) * BOT_PIPS
	# soltar los dobles a tiempo: cuantas más fichas de su número han salido,
	# más fácil es que el doble se quede sin salida
	if t.x == t.y:
		score += BOT_DOUBLE + BOT_DOUBLE_K * view.on_table[t.x]
	# variedad: que me queden fichas para las puntas que dejo
	for x in rest:
		if ends.has(x.x) or ends.has(x.y):
			score += 3.0
	# tapar a los rivales (más si están a punto de dominar) sin tapar al compañero
	score += BOT_W_NEXT * (2.0 if hands[nxt].size() <= 2 else 1.0) * _blocked(can[nxt], a, b)
	score += BOT_W_PREV * (2.0 if hands[prev].size() <= 2 else 1.0) * _blocked(can[prev], a, b)
	score -= BOT_W_PARTNER * (2.0 if hands[partner].size() <= 2 else 1.0) * _blocked(can[partner], a, b)
	# darle al compañero los números que ya ha jugado (su «salida»)
	for e in ends:
		score += played_nums[partner].get(e, 0) * BOT_SALIDA
	# ¿esta ficha tranca el juego? solo si cree que su pareja gana el tranque
	if _locks(view.owner, t, a, b):
		score += clampf(_lock_edge(seat, rest, view) * BOT_LOCK, -40.0, 40.0)
	return score + randf() * bot_noise


## ¿Tras jugar t quedan las puntas a y b sin ninguna ficha fuera de la mesa?
func _locks(owner: Dictionary, t: Vector2i, a: int, b: int) -> bool:
	var played := _norm(t)
	for x in 7:
		for k in [_norm(Vector2i(a, x)), _norm(Vector2i(b, x))]:
			if k != played and owner.get(k, 0) != -1:
				return false
	return true


## Ventaja estimada de su pareja en un tranque: puntos de la pareja rival
## menos los de la suya; el empate lo gana la pareja que salió (o la que
## tenga «Tranque seguro»).
func _lock_edge(seat: int, rest: Array, view: Dictionary) -> float:
	var est := [0.0, 0.0, 0.0, 0.0]
	for p in 4:
		est[p] = view.known_pips[p] + view.slots[p] * view.avg
	var mine := 0.0
	for x in rest:
		mine += x.x + x.y
	var partner := (seat + 2) % 4
	var team_edge: float = est[(seat + 1) % 4] + est[(seat + 3) % 4] - mine - est[partner]
	var we_tie: bool = opener % 2 == seat % 2
	var we_card: bool = has_card(seat, "tranque") or has_card(partner, "tranque")
	var they_card: bool = has_card((seat + 1) % 4, "tranque") or has_card((seat + 3) % 4, "tranque")
	if we_card and not they_card:
		we_tie = true
	elif they_card and not we_card:
		we_tie = false
	return team_edge + (0.5 if we_tie else -0.5)


func _move_value(m: Dictionary) -> int:
	var t: Vector2i = m.tile
	return t.x + t.y + (8 if t.x == t.y else 0)
