// Reglas de Colmadón para el servidor: traducción de scripts/game.gd.
// Diferencia con game.gd: allí la silla 0 es siempre la persona y las demás
// son bots; aquí cualquier silla puede ser persona o bot (p.bot[s]), y lo que
// solo ve un jugador (Ojo pícaro, Morir soñando) se guarda por silla; los
// bots usan esa información (game.gd la guarda igual en seen y sees_partner).
// Todo es un objeto plano (sin clases) para que Nakama lo guarde sin problemas.

type Ficha = number[]; // [a, b]

interface Evento {
	k: string;
	seat: number;
	[clave: string]: any;
}

interface Jugada {
	tile: Ficha;
	side: number;
}

interface Estado {
	phase: string; // pick, draw, play, shop, over
	mode: string; // aumentos (cartas y bebidas) o clasico (dominó de siempre)
	pass_streak: number; // pases seguidos desde la última ficha (aura de quien la puso)
	last_pass_seat: number; // quien pasó en la última acción (-1 si fue una ficha)
	bot: boolean[];
	hands: Ficha[][];
	chain: Ficha[];
	opener: number;
	last_seat: number;
	pool: Ficha[];
	pool_taken: { [idx: string]: number }; // índice del montón → silla
	robo_orden?: number[]; // índices del montón en el orden en que se cogieron
	chivo: { seat: number; kind: string; tile: Ficha } | null;
	revision: { caller: number; accused: number } | null; // «¡Ute va!» de una persona: revisa las fichas de quien pasó
	drank_ron: boolean[];
	hot_hand: boolean;
	hot_team: number;
	marks: number[]; // Ficha marcada: pases de rivales provocados esta mano
	stats: { [clave: string]: number[] };
	lacks: { [n: string]: boolean }[];
	last_pass: { [n: string]: boolean }[]; // solo los números de su último pase
	played_nums: { [n: string]: number }[];
	origin: number;
	left_end: number;
	right_end: number;
	turn: number;
	scores: number[];
	coins: number[];
	cards: string[][];
	drinks: string[][];
	offers: string[][];
	picked: boolean[];
	skip_next: boolean[];
	extra_turn: boolean;
	revealed: Ficha[][]; // fichas de rivales que ve cada silla (Ojo pícaro)
	reveal_partner: boolean[]; // Morir soñando: ve la mano de su compañero
	first_hand: boolean;
	starter_next: number;
	hand_no: number;
	last_result: any;
	meta: number; // puntos para ganar: 100 o 200
	bot_purchases: any[];
	events: Evento[];
}

const R_TARGET = 100; // meta por defecto (la partida guarda la suya en p.meta: 100 o 200)
const R_WIN_COINS = 10;
const R_LOSE_COINS = 4;
const R_MAX_DRINKS = 2;
const R_HOT_HAND = 0.5;
const R_LIGHT_CUT = 0.25;
const R_CHIVO_FALSE_FINE = 10;
const R_MARK_PTS = 3; // Ficha marcada: puntos por cada pase de un rival tras tu ficha
const R_PASE_PTS = 30; // pase de salida, pase corrido y acusación falsa de renuncio

const R_CARDS: { [id: string]: { name: string; desc: string } } = {
	doble: { name: "Doble fuerte", desc: "Dominas con un doble: +30 puntos." },
	capicua: { name: "Capicúa", desc: "Dominas con capicúa: +25 puntos." },
	cierre: { name: "Cierre ruidoso", desc: "Cada vez que dominas: +6 puntos." },
	pasador: { name: "Pasador", desc: "Cada vez que pasas: +4 monedas." },
	bolsillo: { name: "Bolsillo", desc: "Ganas la mano: +8 monedas." },
	ojo: { name: "Ojo pícaro", desc: "Al empezar cada mano ves 1 ficha de cada rival." },
	ligera: { name: "Mano ligera", desc: "Si perdéis, tus fichas dan un 25 % menos a los rivales." },
	fiado: { name: "Fiado", desc: "Las bebidas te cuestan 3 monedas menos." },
	marcada: { name: "Ficha marcada", desc: "Ves a qué números pasa cada rival. +3 por cada pase tras tu ficha si ganáis." },
	suerte: { name: "Doble suerte", desc: "Juegas un doble y llevas el de la otra punta: pones los dos." },
	tranque: { name: "Tranque seguro", desc: "Tranque empatado a puntos: lo ganáis vosotros." },
};
const R_CARD_IDS = ["doble", "capicua", "cierre", "pasador", "bolsillo", "ojo", "ligera", "fiado", "marcada", "suerte", "tranque"];

const R_DRINKS: { [id: string]: { name: string; cost: number } } = {
	cafe: { name: "Café", cost: 14 },
	ron: { name: "Ron", cost: 4 },
	morir: { name: "Morir soñando", cost: 5 },
	agua: { name: "Agua fría", cost: 11 },
};

// ---------------------------------------------------------------- utilidades

function rAzar<T>(lista: T[]): T {
	return lista[Math.floor(Math.random() * lista.length)];
}

function rBarajar<T>(lista: T[]): void {
	for (let i = lista.length - 1; i > 0; i--) {
		const j = Math.floor(Math.random() * (i + 1));
		const t = lista[i];
		lista[i] = lista[j];
		lista[j] = t;
	}
}

function rIgual(a: Ficha, b: Ficha): boolean {
	return a[0] === b[0] && a[1] === b[1];
}

function rIndice(lista: Ficha[], t: Ficha): number {
	for (let i = 0; i < lista.length; i++) {
		if (rIgual(lista[i], t)) return i;
	}
	return -1;
}

function rQuitar(lista: Ficha[], t: Ficha): boolean {
	const i = rIndice(lista, t);
	if (i < 0) return false;
	lista.splice(i, 1);
	return true;
}

function rQuitarTexto(lista: string[], id: string): boolean {
	const i = lista.indexOf(id);
	if (i < 0) return false;
	lista.splice(i, 1);
	return true;
}

function rCuatro<T>(f: () => T): T[] {
	return [f(), f(), f(), f()];
}

// ---------------------------------------------------------------- partida

function rNuevaPartida(bot: boolean[], modo?: string, meta?: number): Estado {
	const p: Estado = {
		phase: "pick",
		meta: meta === 200 ? 200 : R_TARGET,
		mode: modo === "clasico" ? "clasico" : "aumentos",
		pass_streak: 0,
		last_pass_seat: -1,
		bot: bot.slice(),
		hands: rCuatro(() => [] as Ficha[]),
		chain: [],
		opener: 0,
		last_seat: 0,
		pool: [],
		pool_taken: {},
		robo_orden: [],
		chivo: null,
		revision: null,
		drank_ron: [false, false, false, false],
		hot_hand: false,
		hot_team: -1,
		marks: [0, 0, 0, 0],
		stats: { manos: [0, 0], dominos: [0, 0], tranques: [0, 0], capicuas: [0, 0], chivos: [0, 0], bebidas: [0, 0], max_mano: [0, 0], pases: [0, 0] },
		lacks: rCuatro(() => ({})),
		last_pass: rCuatro(() => ({})),
		played_nums: rCuatro(() => ({})),
		origin: 0,
		left_end: -1,
		right_end: -1,
		turn: 0,
		scores: [0, 0],
		coins: [0, 0, 0, 0],
		cards: rCuatro(() => [] as string[]),
		drinks: rCuatro(() => [] as string[]),
		offers: rCuatro(() => [] as string[]),
		picked: [false, false, false, false],
		skip_next: [false, false, false, false],
		extra_turn: false,
		revealed: rCuatro(() => [] as Ficha[]),
		reveal_partner: [false, false, false, false],
		first_hand: true,
		starter_next: 0,
		hand_no: 0,
		last_result: null,
		bot_purchases: [],
		events: [],
	};
	rNuevaMano(p);
	return p;
}

function rNuevaMano(p: Estado): void {
	p.hand_no += 1;
	p.phase = "pick";
	p.revealed = rCuatro(() => [] as Ficha[]);
	p.reveal_partner = [false, false, false, false];
	p.skip_next = [false, false, false, false];
	p.extra_turn = false;
	p.picked = [false, false, false, false];
	p.pool_taken = {};
	p.robo_orden = [];
	p.hands = rCuatro(() => [] as Ficha[]);
	if (p.mode === "clasico") {
		// sin aumentos: directo a barajar
		p.offers = rCuatro(() => [] as string[]);
		p.picked = [true, true, true, true];
		rBarajarMonton(p);
		return;
	}
	for (let s = 0; s < 4; s++) {
		let opciones = R_CARD_IDS.filter((k) => p.cards[s].indexOf(k) < 0);
		if (opciones.length < 3) opciones = R_CARD_IDS.slice();
		rBarajar(opciones);
		p.offers[s] = opciones.slice(0, 3);
	}
}

/** Cada silla elige su aumento entre sus 3 ofertas. Cuando eligen las 4, se baraja el montón. */
function rElegirCarta(p: Estado, seat: number, id: string): boolean {
	if (p.phase !== "pick" || p.picked[seat] || p.offers[seat].indexOf(id) < 0) return false;
	p.cards[seat].push(id);
	p.picked[seat] = true;
	if (p.picked.every((x) => x)) rBarajarMonton(p);
	return true;
}

function rBarajarMonton(p: Estado): void {
	p.pool = [];
	for (let a = 0; a < 7; a++) for (let b = a; b < 7; b++) p.pool.push([a, b]);
	rBarajar(p.pool);
	p.phase = "draw";
}

function rFichasRobadas(p: Estado, seat: number): number {
	let n = 0;
	for (const k in p.pool_taken) if (p.pool_taken[k] === seat) n++;
	return n;
}

/** Robar: la silla coge la ficha boca abajo idx del montón. Al tener todos 7, empieza la mano. */
function rRobar(p: Estado, seat: number, idx: number): boolean {
	if (p.phase !== "draw" || idx < 0 || idx >= 28 || p.pool_taken[String(idx)] !== undefined) return false;
	if (rFichasRobadas(p, seat) >= 7) return false;
	p.pool_taken[String(idx)] = seat;
	(p.robo_orden ??= []).push(idx);
	p.events.push({ k: "draw", seat: seat, idx: idx });
	if (Object.keys(p.pool_taken).length === 28) rTerminarRobo(p);
	return true;
}

/** Ficha libre al azar del montón (para bots o si se acaba el tiempo). */
function rRobarAzar(p: Estado, seat: number): boolean {
	const libres: number[] = [];
	for (let i = 0; i < 28; i++) if (p.pool_taken[String(i)] === undefined) libres.push(i);
	if (libres.length === 0) return false;
	return rRobar(p, seat, rAzar(libres));
}

function rTerminarRobo(p: Estado): void {
	p.hands = rCuatro(() => [] as Ficha[]);
	// en el orden en que cada uno las cogió: así la mano queda como en su bandeja
	let orden: number[] = p.robo_orden ?? [];
	if (orden.length !== 28) {
		orden = [];
		for (let i = 0; i < 28; i++) orden.push(i);
	}
	for (let k = 0; k < 28; k++) p.hands[p.pool_taken[String(orden[k])]].push(p.pool[orden[k]].slice());
	rEmpezarMano(p);
	p.phase = "play";
}

function rEmpezarMano(p: Estado): void {
	p.chivo = null;
	p.revision = null;
	p.pass_streak = 0;
	p.last_pass_seat = -1;
	p.drank_ron = [false, false, false, false];
	p.hot_hand = false;
	p.hot_team = -1;
	p.marks = [0, 0, 0, 0];
	p.chain = [];
	p.left_end = -1;
	p.right_end = -1;
	p.lacks = rCuatro(() => ({}));
	p.last_pass = rCuatro(() => ({}));
	p.played_nums = rCuatro(() => ({}));
	if (p.first_hand) {
		for (let s = 0; s < 4; s++) if (rIndice(p.hands[s], [6, 6]) >= 0) p.turn = s;
	} else {
		p.turn = p.starter_next;
	}
	for (let s = 0; s < 4; s++) {
		if (rTieneCarta(p, s, "ojo")) {
			for (const r of [(s + 1) % 4, (s + 3) % 4]) p.revealed[s].push(rAzar(p.hands[r]).slice());
		}
	}
}

function rTieneCarta(p: Estado, seat: number, id: string): boolean {
	return p.cards[seat].indexOf(id) >= 0;
}

function rPuntos(p: Estado, seat: number): number {
	let n = 0;
	for (const t of p.hands[seat]) n += t[0] + t[1];
	return n;
}

/**
 * ¿Casa la ficha en esa punta? (-1 izquierda, 1 derecha). La ÚNICA regla de qué
 * casa (como fits() en game.gd): con las dos puntas iguales casa en las dos
 * (rJugadas solo da una para no repetir; antes eso convertía en chivo una
 * ficha buena soltada en la otra punta).
 */
function rCasa(p: Estado, t: Ficha, side: number): boolean {
	if (p.chain.length === 0) return !p.first_hand || rIgual(t, [6, 6]);
	const e = side < 0 ? p.left_end : p.right_end;
	return t[0] === e || t[1] === e;
}

function rJugadas(p: Estado, seat: number): Jugada[] {
	const res: Jugada[] = [];
	for (const t of p.hands[seat]) {
		if (p.chain.length === 0) {
			if (p.first_hand && !rIgual(t, [6, 6])) continue;
			res.push({ tile: t, side: 0 });
		} else {
			if (t[0] === p.left_end || t[1] === p.left_end) res.push({ tile: t, side: -1 });
			if ((t[0] === p.right_end || t[1] === p.right_end) && p.left_end !== p.right_end) res.push({ tile: t, side: 1 });
		}
	}
	return res;
}

function rCaducarChivo(p: Estado, seat: number): void {
	if (p.chivo !== null && seat === (p.chivo.seat + 1) % 4) p.chivo = null;
}

function rOlvidarRevelada(p: Estado, t: Ficha): void {
	for (let s = 0; s < 4; s++) rQuitar(p.revealed[s], t);
}

/** Meter un chivo: ficha que no casa. No se puede dominar con chivo ni meter un doble. */
function rMeterChivo(p: Estado, seat: number, t: Ficha, side: number): boolean {
	if (p.phase !== "play" || p.turn !== seat || p.revision !== null) return false;
	if (p.chain.length === 0 || p.hands[seat].length <= 1 || t[0] === t[1]) return false;
	if (rIndice(p.hands[seat], t) < 0) return false;
	if (rCasa(p, t, side < 0 ? -1 : 1)) return false; // si casa ahí no es chivo
	rCaducarChivo(p, seat);
	rQuitar(p.hands[seat], t);
	rOlvidarRevelada(p, t);
	p.last_seat = seat;
	const o = t.slice();
	if (side < 0) {
		p.chain.unshift(o);
		p.origin += 1;
		p.left_end = o[0];
	} else {
		p.chain.push(o);
		p.right_end = o[1];
	}
	p.chivo = { seat: seat, kind: "ficha", tile: o };
	p.pass_streak = 0;
	p.last_pass_seat = -1;
	p.events.push({ k: "play", seat: seat, chivo: true, tile: o, side: side < 0 ? -1 : 1 });
	rAvanzar(p);
	return true;
}

/** Pasar teniendo jugada: también es chivo. */
function rPasarConFicha(p: Estado, seat: number): boolean {
	if (p.phase !== "play" || p.turn !== seat || p.chain.length === 0 || p.revision !== null) return false;
	if (rJugadas(p, seat).length === 0) return rPasar(p, seat); // sin jugada no hay renuncio
	rCaducarChivo(p, seat);
	rAnotarPase(p, seat);
	p.chivo = { seat: seat, kind: "pase", tile: [-1, -1] };
	p.events.push({ k: "pass", seat: seat, by: p.last_seat });
	if (rTrasPase(p, seat)) return true;
	rAvanzar(p);
	return true;
}

/**
 * Cantar chivo o «¡Ute va!»: si es verdad, la mano la gana la pareja de quien
 * cantó (en el clásico, un renuncio cazado pierde la partida entera). Si no,
 * multa; y si acusó de renuncio a quien de verdad no llevaba, ve su mano y la
 * pareja del acusado gana R_PASE_PTS.
 */
function rCantarChivo(p: Estado, caller: number, revisar?: boolean): boolean {
	if (p.phase !== "play" || p.turn !== caller || p.revision !== null) return false;
	const acusado = (caller + 3) % 4;
	// «¡Ute va!» de una persona (2026-10-04): primero revisa las fichas de quien pasó (ver rResolverRevision)
	if (revisar && p.last_pass_seat === acusado) {
		p.revision = { caller: caller, accused: acusado };
		p.events.push({ k: "revision", seat: caller, accused: acusado });
		return false;
	}
	if (p.chivo !== null && p.chivo.seat === acusado) {
		const c = p.chivo;
		p.events.push({ k: "chivo_caught", seat: caller, cheater: c.seat, kind: c.kind, tile: c.tile });
		p.chivo = null;
		rTerminarMano(p, -1, [-1, -1], false, caller, c.kind === "pase" && p.mode === "clasico" ? "renuncio" : "chivo");
		return true;
	}
	p.coins[caller] = Math.max(p.coins[caller] - R_CHIVO_FALSE_FINE, 0);
	if (p.last_pass_seat === acusado) {
		p.events.push({ k: "chivo_false", seat: caller, accused: acusado, hand: p.hands[acusado].map((t) => t.slice()) });
		rPuntosAlMomento(p, acusado, R_PASE_PTS, "acusado");
	} else {
		p.events.push({ k: "chivo_false", seat: caller });
	}
	return false;
}

/**
 * Fin de la revisión del «¡Ute va!» (manda la verdad): una ficha que casa →
 * renuncio cazado; una que no casa → «esa no iba» (puede buscar otra);
 * «No llevaba» (ninguna) → falsa alarma si de verdad no llevaba; si sí, se
 * enseña cuál y el renuncio cuenta igual. Devuelve "cazado", "falso", "no_iba" o "".
 */
function rResolverRevision(p: Estado, caller: number, t: Ficha | null): string {
	if (p.revision === null || p.revision.caller !== caller) return "";
	const acc = p.revision.accused;
	if (t !== null) {
		if (rIndice(p.hands[acc], t) < 0) return "";
		if (!(rCasa(p, t, -1) || rCasa(p, t, 1))) {
			p.events.push({ k: "revision_no", seat: caller, tile: t });
			return "no_iba";
		}
	}
	p.revision = null;
	const real = p.chivo !== null && p.chivo.seat === acc && p.chivo.kind === "pase";
	if (real) {
		let ense: Ficha = t !== null ? t : [-1, -1];
		if (t === null) for (const x of p.hands[acc]) if (rCasa(p, x, -1) || rCasa(p, x, 1)) { ense = x; break; }
		p.events.push({ k: "chivo_caught", seat: caller, cheater: acc, kind: "pase", tile: ense, visto: t !== null });
		p.chivo = null;
		rTerminarMano(p, -1, [-1, -1], false, caller, p.mode === "clasico" ? "renuncio" : "chivo");
		return "cazado";
	}
	p.coins[caller] = Math.max(p.coins[caller] - R_CHIVO_FALSE_FINE, 0);
	p.events.push({ k: "chivo_false", seat: caller, accused: acc, hand: p.hands[acc].map((x) => x.slice()) });
	rPuntosAlMomento(p, acc, R_PASE_PTS, "acusado");
	return "falso";
}

/**
 * Tras un pase (de verdad o renuncio): sube el aura de quien puso la última
 * ficha y reparte los puntos de pase. Devuelve true si la partida se acabó.
 * Pase de salida: la primera ficha de la mano hace pasar al siguiente.
 * Pase corrido: tras tu ficha pasan los otros tres (nadie fue).
 */
function rTrasPase(p: Estado, seat: number): boolean {
	p.last_pass_seat = seat;
	if (p.chain.length === 0) return false;
	p.pass_streak += 1;
	const dueno = p.last_seat;
	p.events.push({ k: "aura", seat: dueno, level: p.pass_streak });
	if (p.chain.length === 1 && p.pass_streak === 1 && seat === (p.opener + 1) % 4) {
		if (rPuntosAlMomento(p, dueno, R_PASE_PTS, "salida")) return true;
	}
	if (p.pass_streak === 3) {
		if (rPuntosAlMomento(p, dueno, R_PASE_PTS, "corrido")) return true;
	}
	return false;
}

/** Puntos al momento (pases y acusación falsa). Si llegan a la meta, se acaba la partida. */
function rPuntosAlMomento(p: Estado, seat: number, pts: number, why: string): boolean {
	const team = seat % 2;
	p.scores[team] += pts;
	p.stats.pases[team] += 1;
	p.events.push({ k: "bonus", seat: seat, pts: pts, why: why });
	if (p.scores[team] < p.meta) return false;
	p.last_result = { seat: seat, team: team, pts: pts, reason: why, bonus: [], capicua: false };
	p.starter_next = seat;
	p.first_hand = false;
	p.phase = "over";
	p.events.push({ k: "end", seat: seat, pts: pts });
	return true;
}

function rJugar(p: Estado, seat: number, t: Ficha, side: number): boolean {
	if (p.phase !== "play" || p.turn !== seat || p.revision !== null) return false;
	if (rIndice(p.hands[seat], t) < 0) return false;
	if (p.chain.length > 0 && side === 0) side = rCasa(p, t, -1) ? -1 : 1; // sin punta: donde case
	if (!rCasa(p, t, side)) return false;
	rCaducarChivo(p, seat);
	let capi = false;
	if (p.chain.length > 0) {
		const fl = t[0] === p.left_end || t[1] === p.left_end;
		const fr = t[0] === p.right_end || t[1] === p.right_end;
		capi = fl && fr && p.left_end !== p.right_end; // capicúa solo con puntas distintas (2026-10-04)
	}
	rQuitar(p.hands[seat], t);
	rOlvidarRevelada(p, t);
	p.last_seat = seat;
	p.pass_streak = 0;
	p.last_pass_seat = -1;
	for (const n of [t[0], t[1]]) p.played_nums[seat][String(n)] = (p.played_nums[seat][String(n)] || 0) + 1;
	let o: Ficha;
	if (p.chain.length === 0) {
		o = t.slice();
		p.chain = [o];
		p.opener = seat;
		p.origin = 0;
		p.left_end = o[0];
		p.right_end = o[1];
	} else if (side < 0) {
		o = t[1] === p.left_end ? t.slice() : [t[1], t[0]];
		p.chain.unshift(o);
		p.origin += 1;
		p.left_end = o[0];
	} else {
		o = t[0] === p.right_end ? t.slice() : [t[1], t[0]];
		p.chain.push(o);
		p.right_end = o[1];
	}
	p.events.push({ k: "play", seat: seat, tile: o, side: p.chain.length === 1 ? 0 : side });
	if (p.hands[seat].length === 0) {
		rTerminarMano(p, seat, t, capi, -1, "");
		return true;
	}
	const suerte = rDobleSuerte(p, seat, t);
	if (suerte !== null) {
		p.events.push({ k: "lucky", seat: seat });
		return rJugar(p, seat, suerte, suerte[0] === p.left_end ? -1 : 1);
	}
	if (p.extra_turn) {
		p.extra_turn = false;
		if (rJugadas(p, seat).length > 0) {
			p.events.push({ k: "again", seat: seat });
			return true;
		}
	}
	rAvanzar(p);
	return true;
}

/** Doble suerte: tras jugar un doble, si te queda el doble de la otra punta se juega solo (como mucho uno: el siguiente ya no casa). */
function rDobleSuerte(p: Estado, seat: number, t: Ficha): Ficha | null {
	let res: Ficha | null = null;
	if (t[0] !== t[1] || !rTieneCarta(p, seat, "suerte")) return res;
	for (const x of p.hands[seat]) {
		if (x[0] === x[1] && (x[0] === p.left_end || x[0] === p.right_end) && (res === null || x[0] > res[0])) res = x;
	}
	return res;
}

function rAnotarPase(p: Estado, seat: number): void {
	p.lacks[seat][String(p.left_end)] = true;
	p.lacks[seat][String(p.right_end)] = true;
	const ultimo: { [n: string]: boolean } = {};
	ultimo[String(p.left_end)] = true;
	ultimo[String(p.right_end)] = true;
	p.last_pass[seat] = ultimo;
	// Ficha marcada: el rival pasa justo después de la ficha de quien la tiene
	if (p.last_seat % 2 !== seat % 2 && rTieneCarta(p, p.last_seat, "marcada")) p.marks[p.last_seat] += 1;
}

/** Lo que «viewer» recuerda de los pases de «target» (lo usan los bots): de su compañero, todo; de un rival, solo su último pase, salvo con Ficha marcada, que los ve todos. */
function rPasesVistos(p: Estado, viewer: number, target: number): { [n: string]: boolean } {
	if (viewer % 2 === target % 2 || rTieneCarta(p, viewer, "marcada")) return p.lacks[target];
	return p.last_pass[target];
}

/** Pasar sin jugada (si tiene jugada, usa rPasarConFicha). */
function rPasar(p: Estado, seat: number): boolean {
	if (p.phase !== "play" || p.turn !== seat || rJugadas(p, seat).length > 0 || p.revision !== null) return false;
	rCaducarChivo(p, seat);
	if (rTieneCarta(p, seat, "pasador")) p.coins[seat] += 4;
	rAnotarPase(p, seat);
	p.events.push({ k: "pass", seat: seat, by: p.last_seat });
	if (rTrasPase(p, seat)) return true;
	rAvanzar(p);
	return true;
}

function rTrancado(p: Estado): boolean {
	if (p.chain.length === 0) return false;
	for (let s = 0; s < 4; s++) if (rJugadas(p, s).length > 0) return false;
	return true;
}

function rAvanzar(p: Estado): void {
	if (rTrancado(p)) {
		rTerminarMano(p, -1, [-1, -1], false, -1, "");
		return;
	}
	let nxt = (p.turn + 1) % 4;
	while (p.skip_next[nxt]) {
		p.skip_next[nxt] = false;
		rCaducarChivo(p, nxt);
		p.events.push({ k: "skip", seat: nxt });
		nxt = (nxt + 1) % 4;
	}
	p.turn = nxt;
}

function rTerminarMano(p: Estado, domino_seat: number, t: Ficha, capi: boolean, forced_winner: number, forced_reason: string): void {
	let pts = 0;
	for (let s = 0; s < 4; s++) pts += rPuntos(p, s);
	let win_seat = domino_seat;
	let reason = "dominó";
	const bonus: string[] = [];
	let tranque: any = null;
	if (forced_winner >= 0) {
		win_seat = forced_winner;
		reason = forced_reason;
		// chivo cazado: solo cuentan las fichas de la pareja tramposa
		if (reason === "chivo" || reason === "renuncio") pts = rPuntos(p, (win_seat + 1) % 4) + rPuntos(p, (win_seat + 3) % 4);
	} else if (domino_seat < 0) {
		// tranque (2026-10-04): gana la PAREJA con menos puntos; en empate, la que salió (o la que tenga Tranque seguro)
		reason = "tranque";
		const parejas = [rPuntos(p, 0) + rPuntos(p, 2), rPuntos(p, 1) + rPuntos(p, 3)];
		const empate = parejas[0] === parejas[1];
		let gana = p.opener % 2;
		if (!empate) gana = parejas[0] < parejas[1] ? 0 : 1;
		else {
			const otra = 1 - (p.opener % 2);
			const cartaOtra = rTieneCarta(p, otra, "tranque") || rTieneCarta(p, otra + 2, "tranque");
			const cartaSalio = rTieneCarta(p, p.opener % 2, "tranque") || rTieneCarta(p, (p.opener % 2) + 2, "tranque");
			if (cartaOtra && !cartaSalio) {
				gana = otra;
				bonus.push("Tranque seguro");
			}
		}
		win_seat = empate && gana === p.opener % 2 ? p.opener : rMenorDePareja(p, gana);
		tranque = { pips: [rPuntos(p, 0), rPuntos(p, 1), rPuntos(p, 2), rPuntos(p, 3)], teams: parejas, tie: empate, opener: p.opener };
	} else {
		if (rTieneCarta(p, win_seat, "cierre")) {
			pts += 6;
			bonus.push("Cierre ruidoso +6");
		}
		if (t[0] === t[1] && rTieneCarta(p, win_seat, "doble")) {
			pts += 30;
			bonus.push("Doble fuerte +30");
		}
		if (capi && rTieneCarta(p, win_seat, "capicua")) {
			pts += 25;
			bonus.push("¡Capicúa! +25");
		}
	}
	const team = win_seat % 2;
	// renuncio cazado en el clásico: la pareja de quien cantó gana la partida
	if (reason === "renuncio") p.scores[team] = Math.max(p.scores[team], p.meta - pts);
	// Ficha marcada: puntos por cada pase de un rival tras tu ficha, si gana tu pareja
	for (let s = 0; s < 4; s++) {
		if (s % 2 === team && p.marks[s] > 0) {
			pts += p.marks[s] * R_MARK_PTS;
			bonus.push("Ficha marcada +" + p.marks[s] * R_MARK_PTS);
		}
	}
	for (let s = 0; s < 4; s++) {
		if (s % 2 !== team && rTieneCarta(p, s, "ligera") && rPuntos(p, s) > 0) {
			const off = Math.round(rPuntos(p, s) * R_LIGHT_CUT);
			pts -= off;
			bonus.push("Mano ligera −" + off);
		}
	}
	if (p.hot_hand && team === p.hot_team) {
		const extra = Math.round(pts * R_HOT_HAND);
		pts += extra;
		bonus.push("Mano caliente +" + extra);
	}
	p.scores[team] += pts;
	p.stats.manos[team] += 1;
	p.stats.max_mano[team] = Math.max(p.stats.max_mano[team], pts);
	if (reason === "dominó") p.stats.dominos[team] += 1;
	else if (reason === "tranque") p.stats.tranques[team] += 1;
	else if (reason === "chivo" || reason === "renuncio") p.stats.chivos[team] += 1;
	if (capi && domino_seat >= 0) p.stats.capicuas[team] += 1;
	for (let s = 0; s < 4 && p.mode !== "clasico"; s++) {
		if (s % 2 === team) p.coins[s] += R_WIN_COINS + (rTieneCarta(p, s, "bolsillo") ? 8 : 0);
		else p.coins[s] += R_LOSE_COINS;
	}
	p.last_result = { seat: win_seat, team: team, pts: pts, reason: reason, bonus: bonus, capicua: capi && domino_seat >= 0 };
	if (tranque !== null) p.last_result.tranque = tranque;
	p.starter_next = win_seat;
	p.first_hand = false;
	p.events.push({ k: "end", seat: win_seat, pts: pts });
	if (p.scores[team] >= p.meta) {
		p.phase = "over";
	} else {
		p.phase = "shop";
		if (p.mode === "clasico") p.bot_purchases = [];
		else rTiendaBots(p);
	}
}

/** Jugador de una pareja con menos puntos (empate: el primero en orden de juego desde quien trancó). */
function rMenorDePareja(p: Estado, team: number): number {
	let best = 999;
	let res = team;
	for (let k = 0; k < 4; k++) {
		const s = (p.last_seat + k) % 4;
		if (s % 2 === team && rPuntos(p, s) < best) {
			best = rPuntos(p, s);
			res = s;
		}
	}
	return res;
}

// ---------------------------------------------------------------- colmado (tienda) y bebidas

function rPrecio(p: Estado, seat: number, id: string): number {
	return R_DRINKS[id].cost - (rTieneCarta(p, seat, "fiado") ? 3 : 0);
}

function rPuedeComprar(p: Estado, seat: number, id: string): boolean {
	return R_DRINKS[id] !== undefined && p.coins[seat] >= rPrecio(p, seat, id) && p.drinks[seat].length < R_MAX_DRINKS;
}

function rComprar(p: Estado, seat: number, id: string): boolean {
	if (p.phase !== "shop" || !rPuedeComprar(p, seat, id)) return false;
	p.coins[seat] -= rPrecio(p, seat, id);
	p.drinks[seat].push(id);
	return true;
}

function rBeber(p: Estado, seat: number, id: string): boolean {
	if (p.phase !== "play" || p.turn !== seat || p.revision !== null || !rQuitarTexto(p.drinks[seat], id)) return false;
	p.stats.bebidas[seat % 2] += 1;
	if (id === "cafe") p.extra_turn = true;
	else if (id === "morir") p.reveal_partner[seat] = true;
	else if (id === "agua") p.skip_next[(seat + 1) % 4] = true;
	else if (id === "ron") {
		p.drank_ron[seat] = true;
		p.hot_hand = true;
		p.hot_team = seat % 2;
	}
	p.events.push({ k: "drink", seat: seat, id: id });
	return true;
}

// ---------------------------------------------------------------- bots
// Misma lógica que la sección de bots de scripts/game.gd. Aquí lo que ve cada
// silla ya se guarda por silla (p.revealed[s], p.reveal_partner[s]).

// Pesos del bot al elegir jugada (ver rNotaJugada); iguales que en game.gd.
const R_BOT_W_NEXT = 16; // que el rival siguiente no pueda jugar
const R_BOT_W_PREV = 6; // que el rival de después tampoco
const R_BOT_W_PARTNER = 6; // no dejar al compañero sin jugada
const R_BOT_PIPS = 0.6; // soltar fichas pesadas (por punto)
const R_BOT_DOUBLE = 6; // soltar un doble...
const R_BOT_DOUBLE_K = 0.75; // ...y más cuantas más fichas de su número han salido
const R_BOT_SALIDA = 1; // dar al compañero los números que ya jugó
const R_BOT_LOCK = 4; // trancar: por punto de ventaja estimada (máx ±40)
let R_BOT_NOISE = 1.5; // azar en la nota de cada jugada (0 en la prueba de paridad)
// Peso de cada bebida al comprar (las que el bot no conoce pesan 1)
const R_BOT_DRINK_WEIGHT: { [id: string]: number } = { cafe: 3, agua: 3, ron: 2, morir: 1.5 };

interface VistaBot {
	owner: { [k: string]: number }; // "a-b" (a <= b) → silla que la tiene; -1 = en la mesa
	on_table: number[];
	slots: number[]; // fichas que no conoce de cada jugador
	known_pips: number[];
	can: number[][]; // can[jugador][número]: probabilidad de que pueda jugarlo
	avg: number; // puntos medios de una ficha oculta
}

function rClave(a: number, b: number): string {
	return Math.min(a, b) + "-" + Math.max(a, b);
}

/** Bot que juega en pareja: tapa al rival, no cierra al compañero, suelta dobles a tiempo y solo tranca si cree que gana. */
function rTurnoBot(p: Estado): void {
	const seat = p.turn;
	if (p.revision !== null) return; // una persona revisa un «¡Ute va!»
	// ¿el anterior metió chivo? lo ven 6 de cada 10 veces; con ron, 2 de 10
	if (p.chivo !== null && p.chivo.seat === (seat + 3) % 4) {
		const ve = p.drank_ron[seat] ? 0.2 : 0.6;
		if (Math.random() < ve && rCantarChivo(p, seat)) return;
	}
	rBotBebe(p, seat, rJugadas(p, seat));
	const jugadas = rJugadas(p, seat);
	if (jugadas.length === 0) {
		// sin jugada: a veces se arriesga con un chivo
		const normales = p.hands[seat].filter((x) => x[0] !== x[1]);
		// (en el clásico los bots juegan limpio: allí un renuncio pierde la partida)
		if (p.mode !== "clasico" && p.chain.length > 0 && p.hands[seat].length > 2 && normales.length > 0 && Math.random() < 0.04) {
			if (rMeterChivo(p, seat, rAzar(normales), rAzar([-1, 1]))) return;
		}
		rPasar(p, seat);
		return;
	}
	if (p.mode !== "clasico" && p.hands[seat].length > 3 && Math.random() < 0.004) {
		rPasarConFicha(p, seat);
		return;
	}
	rJugarMejor(p, seat, jugadas);
}

/** Lo que haría un bot con la silla, sin beber ni chivos: para quien se queda sin tiempo. */
function rJugadaAutomatica(p: Estado): void {
	const seat = p.turn;
	if (p.revision !== null) return;
	const jugadas = rJugadas(p, seat);
	if (jugadas.length === 0) {
		rPasar(p, seat);
		return;
	}
	rJugarMejor(p, seat, jugadas);
}

function rJugarMejor(p: Estado, seat: number, jugadas: Jugada[]): void {
	const vista = rVistaBot(p, seat);
	let mejor = jugadas[0];
	let mejorNota = -Infinity;
	for (const m of jugadas) {
		const nota = rNotaJugada(p, seat, m, vista);
		if (nota > mejorNota) {
			mejorNota = nota;
			mejor = m;
		}
	}
	rJugar(p, seat, mejor.tile, mejor.side);
}

function rAzarConPeso<T>(ids: T[], pesos: number[]): T {
	let total = 0;
	for (const x of pesos) total += x;
	let r = Math.random() * total;
	for (let i = 0; i < ids.length; i++) {
		r -= pesos[i];
		if (r < 0) return ids[i];
	}
	return ids[ids.length - 1];
}

/** Elección de carta de un bot: al azar con pesos según cómo va (igual que bot_pick_card de game.gd). */
function rBotEligeCarta(p: Estado, seat: number): void {
	const diff = p.scores[seat % 2] - p.scores[1 - (seat % 2)];
	const pesos: number[] = [];
	for (const id of p.offers[seat]) {
		let x = 1;
		if (id === "cierre" || id === "doble" || id === "capicua") {
			if (diff < 0) x += 0.5;
		} else if (id === "ligera") {
			if (diff > 0) x += 0.5;
		} else if (id === "bolsillo" || id === "pasador" || id === "fiado") {
			if (p.coins[seat] < 11) x += 0.5;
		} else if (id === "ojo") {
			x += 0.3;
		}
		if (rTieneCarta(p, seat, id)) x *= 0.5;
		pesos.push(x);
	}
	rElegirCarta(p, seat, rAzarConPeso(p.offers[seat], pesos));
}

/** Compra de un bot (igual que bot_buy de game.gd). Devuelve la bebida o "". */
function rBotCompra(p: Estado, s: number): string {
	if (p.drinks[s].length >= R_MAX_DRINKS || Math.random() >= 0.7) return "";
	const diff = p.scores[s % 2] - p.scores[1 - (s % 2)];
	const ids: string[] = [];
	const pesos: number[] = [];
	for (const d of Object.keys(R_DRINKS)) {
		if (!rPuedeComprar(p, s, d)) continue;
		let x = R_BOT_DRINK_WEIGHT[d] !== undefined ? R_BOT_DRINK_WEIGHT[d] : 1;
		if (d === "ron" && diff < -20) x += 2;
		if (d === "agua" && diff > 20) x += 1;
		if (p.drinks[s].indexOf(d) >= 0) x *= 0.4;
		ids.push(d);
		pesos.push(x);
	}
	if (ids.length === 0) return "";
	const d = rAzarConPeso(ids, pesos);
	rComprar(p, s, d);
	return d;
}

function rTiendaBots(p: Estado): void {
	p.bot_purchases = [];
	for (let s = 0; s < 4; s++) {
		if (!p.bot[s]) continue;
		const d = rBotCompra(p, s);
		if (d !== "") p.bot_purchases.push([s, d]);
	}
}

function rBotBebe(p: Estado, seat: number, jugadas: Jugada[]): void {
	if (p.drinks[seat].length === 0) return;
	const rival = (seat + 1) % 4;
	const comp = (seat + 2) % 4;
	for (const d of p.drinks[seat].slice()) {
		let usar = false;
		// ver la mano del compañero vale más al principio de la mano
		if (d === "morir") usar = !p.reveal_partner[seat];
		// frena al rival que va a dominar o deja jugar antes al compañero
		else if (d === "agua") usar = p.hands[rival].length <= 2 || p.hands[comp].length <= 1 || Math.random() < 0.15;
		else if (d === "cafe") usar = jugadas.length >= 2 && p.hands[seat].length <= 4;
		else if (d === "ron") {
			// apuesta: solo si su pareja lleva menos fichas que los rivales
			const mias = p.hands[seat].length + p.hands[comp].length;
			const suyas = p.hands[rival].length + p.hands[(seat + 3) % 4].length;
			usar = !p.hot_hand && mias < suyas;
		} else usar = Math.random() < 0.2; // bebida que el bot no conoce
		if (usar) {
			rBeber(p, seat, d);
			return;
		}
	}
}

/** Lo que sabe la silla: fichas que salieron, las que ha visto y la probabilidad de que cada jugador pueda jugar cada número. */
function rVistaBot(p: Estado, seat: number): VistaBot {
	const comp = (seat + 2) % 4;
	const owner: { [k: string]: number } = {};
	const on_table = [0, 0, 0, 0, 0, 0, 0];
	for (const t of p.chain) {
		owner[rClave(t[0], t[1])] = -1;
		on_table[t[0]] += 1;
		if (t[0] !== t[1]) on_table[t[1]] += 1;
	}
	const slots: number[] = [];
	const known_pips = [0, 0, 0, 0];
	const can: number[][] = [];
	// pases que recuerda (de los rivales, solo el último sin Ficha marcada)
	const falta: { [n: string]: boolean }[] = [];
	for (let q = 0; q < 4; q++) falta.push(rPasesVistos(p, seat, q));
	for (let q = 0; q < 4; q++) {
		slots.push(p.hands[q].length);
		can.push([0, 0, 0, 0, 0, 0, 0]);
	}
	for (let q = 0; q < 4; q++) {
		for (const t of p.hands[q]) {
			if (q === seat || (q === comp && p.reveal_partner[seat]) || rIndice(p.revealed[seat], t) >= 0) {
				owner[rClave(t[0], t[1])] = q;
				slots[q] -= 1;
				known_pips[q] += t[0] + t[1];
				can[q][t[0]] = 1;
				can[q][t[1]] = 1;
			}
		}
	}
	const unknown: Ficha[] = [];
	let hidden_pips = 0;
	for (let a = 0; a < 7; a++) {
		for (let b = a; b < 7; b++) {
			if (owner[rClave(a, b)] === undefined) {
				unknown.push([a, b]);
				hidden_pips += a + b;
			}
		}
	}
	for (let n = 0; n < 7; n++) {
		let u = 0;
		for (const k of unknown) if (k[0] === n || k[1] === n) u++;
		// las fichas ocultas con n solo pueden estar en quien no ha pasado a n
		let total = 0;
		for (let q = 0; q < 4; q++) if (q !== seat && !falta[q][String(n)]) total += slots[q];
		for (let q = 0; q < 4; q++) {
			if (q === seat || can[q][n] > 0 || slots[q] === 0 || falta[q][String(n)] || u === 0) continue;
			let miss = 1;
			for (let i = 0; i < u; i++) {
				if (total - i <= 0) {
					miss = 0;
					break;
				}
				miss *= Math.max(total - slots[q] - i, 0) / (total - i);
			}
			can[q][n] = 1 - miss;
		}
	}
	return { owner: owner, on_table: on_table, slots: slots, known_pips: known_pips, can: can, avg: hidden_pips / Math.max(unknown.length, 1) };
}

/** Probabilidad de que un jugador no pueda jugar en ninguna de las puntas a, b. */
function rBloqueado(fila: number[], a: number, b: number): number {
	if (a === b) return 1 - fila[a];
	return (1 - fila[a]) * (1 - fila[b]);
}

function rPuntasDespues(p: Estado, t: Ficha, side: number): number[] {
	if (p.chain.length === 0) return [t[0], t[1]];
	if (side < 0) return [t[1] === p.left_end ? t[0] : t[1], p.right_end];
	return [p.left_end, t[0] === p.right_end ? t[1] : t[0]];
}

function rNotaJugada(p: Estado, seat: number, m: Jugada, vista?: VistaBot): number {
	const v = vista !== undefined ? vista : rVistaBot(p, seat);
	const t = m.tile;
	const resto = p.hands[seat].filter((x) => !rIgual(x, t));
	if (resto.length === 0) return 10000; // ¡dominó!
	const puntas = rPuntasDespues(p, t, m.side);
	const a = puntas[0];
	const b = puntas[1];
	const comp = (seat + 2) % 4;
	const sig = (seat + 1) % 4;
	const ant = (seat + 3) % 4;
	// soltar las fichas pesadas
	let nota = (t[0] + t[1]) * R_BOT_PIPS;
	// soltar los dobles a tiempo
	if (t[0] === t[1]) nota += R_BOT_DOUBLE + R_BOT_DOUBLE_K * v.on_table[t[0]];
	// variedad: que me queden fichas para las puntas que dejo
	for (const x of resto) if (puntas.indexOf(x[0]) >= 0 || puntas.indexOf(x[1]) >= 0) nota += 3;
	// tapar a los rivales (más si están a punto de dominar) sin tapar al compañero
	nota += R_BOT_W_NEXT * (p.hands[sig].length <= 2 ? 2 : 1) * rBloqueado(v.can[sig], a, b);
	nota += R_BOT_W_PREV * (p.hands[ant].length <= 2 ? 2 : 1) * rBloqueado(v.can[ant], a, b);
	nota -= R_BOT_W_PARTNER * (p.hands[comp].length <= 2 ? 2 : 1) * rBloqueado(v.can[comp], a, b);
	// darle al compañero los números que ya ha jugado (su «salida»)
	for (const e of puntas) nota += (p.played_nums[comp][String(e)] || 0) * R_BOT_SALIDA;
	// ¿esta ficha tranca el juego? solo si cree que su pareja gana el tranque
	if (rTranca(v.owner, t, a, b)) nota += Math.min(Math.max(rVentajaTranque(p, seat, resto, v) * R_BOT_LOCK, -40), 40);
	return nota + Math.random() * R_BOT_NOISE;
}

/** ¿Tras jugar t quedan las puntas a y b sin ninguna ficha fuera de la mesa? */
function rTranca(owner: { [k: string]: number }, t: Ficha, a: number, b: number): boolean {
	const jugada = rClave(t[0], t[1]);
	for (let x = 0; x < 7; x++) {
		for (const k of [rClave(a, x), rClave(b, x)]) {
			if (k !== jugada && owner[k] !== -1) return false;
		}
	}
	return true;
}

/** Ventaja estimada de su pareja en un tranque: pareja rival menos la suya; el empate es de quien salió (o de quien tenga Tranque seguro). */
function rVentajaTranque(p: Estado, seat: number, resto: Ficha[], v: VistaBot): number {
	const est = [0, 0, 0, 0];
	for (let q = 0; q < 4; q++) est[q] = v.known_pips[q] + v.slots[q] * v.avg;
	let mias = 0;
	for (const x of resto) mias += x[0] + x[1];
	const comp = (seat + 2) % 4;
	const dePareja = est[(seat + 1) % 4] + est[(seat + 3) % 4] - mias - est[comp];
	let empateNuestro = p.opener % 2 === seat % 2;
	const cartaNuestra = rTieneCarta(p, seat, "tranque") || rTieneCarta(p, comp, "tranque");
	const cartaSuya = rTieneCarta(p, (seat + 1) % 4, "tranque") || rTieneCarta(p, (seat + 3) % 4, "tranque");
	if (cartaNuestra && !cartaSuya) empateNuestro = true;
	else if (cartaSuya && !cartaNuestra) empateNuestro = false;
	return dePareja + (empateNuestro ? 0.5 : -0.5);
}
