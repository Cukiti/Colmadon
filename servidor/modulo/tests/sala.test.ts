// Pruebas de la sala (sala.ts) sin Nakama real: ctx, logger y nk mínimos y un
// dispatcher que guarda todo lo que se envía. Cubre avisos de sala, reloj del
// turno, jugadores ausentes, chat rápido y reconexión. Uso: npm test
declare const process: any;

let fallosSala = 0;
let pruebasSala = 0;
function comprueba(ok: boolean, msg: string): void {
	pruebasSala++;
	if (ok) return;
	fallosSala++;
	if (fallosSala <= 20) console.log("FALLO " + msg);
}

// ---------------------------------------------------------------- Nakama simulado

interface Enviado {
	op: number;
	data: any;
	to: string[]; // userIds
}

let enviados: Enviado[] = [];
let etiqueta = "";
let estado: any = null;
let tick = 0;

const ctxFalso = {} as nkruntime.Context;
const loggerFalso = { info() {}, warn() {}, error() {}, debug() {} } as any as nkruntime.Logger;
const nkFalso = { binaryToString: (d: any) => String(d) } as any as nkruntime.Nakama;
function guardar(op: number, data: any, presences: nkruntime.Presence[] | null | undefined): void {
	enviados.push({ op: op, data: JSON.parse(String(data)), to: (presences || []).map((p) => p.userId) });
}
const dispatcherFalso = {
	broadcastMessage: guardar,
	broadcastMessageDeferred: guardar,
	matchKick() {},
	matchLabelUpdate(l: string) {
		etiqueta = l;
	},
} as any as nkruntime.MatchDispatcher;

function presencia(userId: string, sesion?: string): nkruntime.Presence {
	return { userId: userId, sessionId: userId + "-" + (sesion || "1"), username: "u_" + userId, node: "nodo" };
}

function nuevaSala(): void {
	enviados = [];
	tick = 0;
	estado = salaInit(ctxFalso, loggerFalso, nkFalso, { code: "ABCDEF" }).state;
}

function entrar(p: nkruntime.Presence): void {
	const r = salaJoinAttempt(ctxFalso, loggerFalso, nkFalso, dispatcherFalso, tick, estado, p, {});
	comprueba(r !== null && r.accept, "no deja entrar a " + p.userId);
	estado = (r as any).state;
	estado = (salaJoin(ctxFalso, loggerFalso, nkFalso, dispatcherFalso, tick, estado, [p]) as any).state;
}

function salir(p: nkruntime.Presence): void {
	estado = (salaLeave(ctxFalso, loggerFalso, nkFalso, dispatcherFalso, tick, estado, [p]) as any).state;
}

type Msg = [nkruntime.Presence, number, any];

function vuelta(msgs?: Msg[]): void {
	tick++;
	const mensajes = (msgs || []).map((m) => ({
		sender: m[0],
		persistence: false,
		status: "",
		opCode: m[1],
		data: JSON.stringify(m[2] || {}) as any,
		reliable: true,
		receiveTimeMs: 0,
	}));
	const r = salaLoop(ctxFalso, loggerFalso, nkFalso, dispatcherFalso, tick, estado, mensajes);
	if (r === null) throw Error("la sala se cerró");
	estado = r.state;
}

function esperar(seg: number): void {
	for (let i = 0; i < Math.round(seg * SALA_TICK); i++) vuelta();
}

/** Vistas (OP_ESTADO) que recibió un usuario desde la posición `desde` de enviados. */
function vistasDe(userId: string, desde?: number): any[] {
	return enviados.slice(desde || 0).filter((x) => x.op === OP_ESTADO && x.to.indexOf(userId) >= 0).map((x) => x.data);
}

function ultimaVista(userId: string): any {
	const v = vistasDe(userId);
	return v[v.length - 1];
}

function eventosDe(userId: string, desde: number, k?: string): any[] {
	const r: any[] = [];
	for (const v of vistasDe(userId, desde)) for (const ev of v.events || []) if (k === undefined || ev.k === k) r.push(ev);
	return r;
}

function juego(): Estado {
	return (estado as EstadoSala).game as Estado;
}

/** Lo que mandaría una persona atenta en su silla (o null si no le toca nada). */
function accionDe(s: number): [number, any] | null {
	const g = juego();
	if (g === null) return null;
	if (g.phase === "pick" && !g.picked[s]) return [OP_CARTA, { id: g.offers[s][0] }];
	if (g.phase === "draw" && rFichasRobadas(g, s) < 7) {
		for (let i = 0; i < 28; i++) if (g.pool_taken[String(i)] === undefined) return [OP_ROBAR, { idx: i }];
	}
	if (g.phase === "play" && g.turn === s) {
		const j = rJugadas(g, s);
		if (j.length === 0) return [OP_PASAR, {}];
		return [OP_JUGAR, { tile: j[0].tile, side: j[0].side }];
	}
	if (g.phase === "shop" && !(estado as EstadoSala).listos[s]) return [OP_LISTO, {}];
	if (g.phase === "over" && !(estado as EstadoSala).revancha[s]) return [OP_REVANCHA, {}];
	return null;
}

/** Una vuelta en la que las personas indicadas hacen lo que les toca. */
function vueltaAtentos(atentos: [nkruntime.Presence, number][]): void {
	const msgs: Msg[] = [];
	for (const a of atentos) {
		const acc = accionDe(a[1]);
		if (acc !== null) msgs.push([a[0], acc[0], acc[1]]);
	}
	vuelta(msgs);
}

function igual(a: any, b: any): boolean {
	return JSON.stringify(a) === JSON.stringify(b);
}

// ---------------------------------------------------------------- 1. avisos de sala y chat rápido en el vestíbulo


/** Antes de EMPEZAR: cada pareja con personas acuerda un nombre y todos marcan LISTO (en una vuelta). */
function todosListos(): void {
	const e = estado as EstadoSala;
	if (e.game !== null) return;
	const msgs: Msg[] = [];
	for (let p = 0; p < 2; p++) {
		const hs = [p, p + 2].filter((s) => e.seats[s].presence !== null);
		if (hs.length === 0) continue;
		msgs.push([e.seats[hs[0]].presence!, OP_EQUIPO, { name: "EQUIPO" + p }]);
		if (hs.length > 1) msgs.push([e.seats[hs[1]].presence!, OP_EQUIPO_RESP, { ok: true }]);
	}
	for (let s = 0; s < 4; s++) if (e.seats[s].presence !== null) msgs.push([e.seats[s].presence!, OP_LISTO_SALA, { on: true }]);
	vuelta(msgs);
}
const A = presencia("A"), B = presencia("B"), C = presencia("C");
nuevaSala();
let marca = enviados.length;
entrar(A);
comprueba(eventosDe("A", marca, "joined").length === 0, "joined antes de saber el nombre");
marca = enviados.length;
vuelta([[A, OP_PERFIL, { name: "Ana" }]]);
let ev = eventosDe("A", marca, "joined");
comprueba(ev.length === 1 && ev[0].seat === 0 && ev[0].name === "Ana", "joined de Ana para ella misma: " + JSON.stringify(ev));
comprueba(ultimaVista("A").phase === "lobby", "la vista del vestíbulo no dice lobby");
comprueba(ultimaVista("A").secs === 0 && ultimaVista("A").turn_deadline_secs === 0, "el vestíbulo tiene reloj");

marca = enviados.length;
entrar(B);
vuelta([[B, OP_PERFIL, { name: "Beto" }]]);
ev = eventosDe("A", marca, "joined");
comprueba(ev.length === 1 && ev[0].seat === 2 && ev[0].name === "Beto", "A no ve llegar a Beto en la silla 2: " + JSON.stringify(ev));
ev = eventosDe("B", marca, "joined");
comprueba(ev.length === 1 && ev[0].seat === 0 && ev[0].name === "Beto", "Beto no se ve a sí mismo en la 0: " + JSON.stringify(ev));

// C entra y nunca manda su perfil: el aviso sale igualmente a los 3 s
marca = enviados.length;
entrar(C);
esperar(T_AVISO_ENTRADA + 0.4);
ev = eventosDe("A", marca, "joined");
comprueba(ev.length === 1 && ev[0].seat === 1 && ev[0].name === "Jugador", "joined sin perfil para A: " + JSON.stringify(ev));
ev = eventosDe("B", marca, "joined");
comprueba(ev.length === 1 && ev[0].seat === 3, "joined de C no está girado para B: " + JSON.stringify(ev));
comprueba(eventosDe("C", marca, "joined").length === 1, "C no recibe su propio joined");

marca = enviados.length;
salir(C);
ev = eventosDe("A", marca, "left");
comprueba(ev.length === 1 && ev[0].seat === 1 && ev[0].name === "Jugador", "left de C para A: " + JSON.stringify(ev));
ev = eventosDe("B", marca, "left");
comprueba(ev.length === 1 && ev[0].seat === 3, "left de C para B: " + JSON.stringify(ev));
comprueba((estado as EstadoSala).seats[1].userId === null, "en el vestíbulo no se libera la silla de quien se va");

// chat rápido en el vestíbulo
marca = enviados.length;
vuelta([[A, OP_FRASE, { id: "capicua" }]]);
ev = eventosDe("B", marca, "frase");
comprueba(ev.length === 1 && ev[0].seat === 2 && ev[0].id === "capicua" && ev[0].text === "¡Capicúa!", "frase de A para B: " + JSON.stringify(ev));
ev = eventosDe("A", marca, "frase");
comprueba(ev.length === 1 && ev[0].seat === 0, "A no ve su propia frase");
marca = enviados.length;
vuelta([[A, OP_FRASE, { id: "buena" }]]);
esperar(1);
comprueba(eventosDe("B", marca, "frase").length === 0, "se pueden mandar 2 frases en menos de 3 s");
marca = enviados.length;
vuelta([[A, OP_FRASE, { id: "hola, texto libre" }], [B, OP_FRASE, { id: "<script>" }]]);
comprueba(eventosDe("A", marca, "frase").length === 0, "se reenvía una frase que no está en la lista");
comprueba(enviados.slice(marca).some((x) => x.op === OP_AVISO && x.to[0] === "B"), "no se avisa de una frase no válida");
esperar(T_FRASE);
marca = enviados.length;
vuelta([[A, OP_FRASE, { id: "gracias" }], [B, OP_FRASE, { id: "pasate" }]]);
ev = eventosDe("A", marca, "frase");
comprueba(ev.length === 2 && ev[0].id === "gracias" && ev[1].id === "pasate" && ev[1].seat === 2, "frases tras esperar 3 s: " + JSON.stringify(ev));
// todas las frases de la lista son válidas
for (const id of ["capicua", "pasate", "chivo_visto", "buena", "ay", "tranque", "bebe", "gracias"]) {
	comprueba(SALA_FRASES[id] !== undefined, "falta la frase " + id);
}

// ---------------------------------------------------------------- 2. reloj de cada fase

marca = enviados.length;
todosListos(); vuelta([[A, OP_EMPEZAR, {}]]);
let v = ultimaVista("A");
comprueba(v.phase === "pick" && v.secs === T_CARTA && v.turn_deadline_secs === T_CARTA, "reloj al elegir carta: " + v.secs + "/" + v.turn_deadline_secs);
esperar(T_BOT_CARTA + 0.4); // eligen los bots
comprueba(juego().picked[1] && juego().picked[3] && !juego().picked[0], "los bots no eligen carta");
v = ultimaVista("A");
comprueba(v.secs < T_CARTA && v.secs > T_CARTA - 3, "el reloj de la carta no baja: " + v.secs);
// la última carta la elige una persona: el reloj pasa al de robar en esa misma vista
vuelta([[A, OP_CARTA, { id: juego().offers[0][0] }]]);
vuelta([[B, OP_CARTA, { id: juego().offers[2][0] }]]);
v = ultimaVista("B");
comprueba(v.phase === "draw" && v.secs === T_ROBAR && v.turn_deadline_secs === T_ROBAR, "reloj al empezar a robar: " + v.phase + " " + v.secs + "/" + v.turn_deadline_secs);
const atentos: [nkruntime.Presence, number][] = [[A, 0], [B, 2]];
let guarda = 0;
while (juego().phase === "draw" && guarda++ < 500) vueltaAtentos(atentos);
v = ultimaVista("A");
comprueba(v.phase === "play" && v.secs === v.turn_deadline_secs && v.secs === T_TURNO, "reloj al empezar la mano: " + v.secs + "/" + v.turn_deadline_secs);
// que le toque a A y juegue: la vista de esa jugada ya trae el reloj del turno siguiente
guarda = 0;
while (!(juego().phase === "play" && juego().turn === 0) && guarda++ < 500) vueltaAtentos([[B, 2]]);
comprueba(juego().turn === 0, "nunca le tocó a A");
esperar(1);
v = ultimaVista("A");
comprueba(juego().turn === 0, "a A le jugó el bot estando conectado");
marca = enviados.length;
vueltaAtentos([[A, 0]]);
v = vistasDe("A", marca)[0];
comprueba(v !== undefined && v.turn !== 0, "la jugada de A no pasa el turno");
if (v !== undefined) {
	const esperado = juego().phase !== "play" ? -1 : v.turn_deadline_secs;
	comprueba(esperado < 0 || (v.secs === v.turn_deadline_secs && v.secs > 0), "tras la jugada de A el reloj es el del turno anterior: " + v.secs + "/" + v.turn_deadline_secs);
}

// ---------------------------------------------------------------- 3. reconexión

// B se va a mitad de partida: su silla la juega un bot
marca = enviados.length;
salir(B);
ev = eventosDe("A", marca, "left");
comprueba(ev.length === 1 && ev[0].seat === 2 && ev[0].name === "Beto", "left de Beto en partida: " + JSON.stringify(ev));
v = ultimaVista("A");
comprueba(v.seats[2].connected === false && v.seats[2].bot === false, "la silla de Beto no figura desconectada");
comprueba(juego().bot[2] === true, "no juega un bot por Beto");
// esperar a que el bot juegue un turno de Beto
let jugoElBot = false;
guarda = 0;
while (!jugoElBot && guarda++ < 3000) {
	marca = enviados.length;
	vueltaAtentos([[A, 0]]);
	for (const x of eventosDe("A", marca)) if ((x.k === "play" || x.k === "pass") && x.seat === 2) jugoElBot = true;
}
comprueba(jugoElBot, "nadie juega por Beto mientras está fuera");
// que la mano esté en juego para comprobar las fichas
guarda = 0;
while (juego().phase !== "play" && guarda++ < 3000) vueltaAtentos([[A, 0]]);
// Beto vuelve con otra sesión (misma cuenta)
const B2 = presencia("B", "2");
marca = enviados.length;
entrar(B2);
ev = eventosDe("A", marca, "back");
comprueba(ev.length === 1 && ev[0].seat === 2 && ev[0].name === "Beto", "back de Beto: " + JSON.stringify(ev));
comprueba(eventosDe("A", marca, "joined").length === 0, "al volver se anuncia como joined");
v = ultimaVista("B");
comprueba(v.seats[0].name === "Beto" && v.seats[0].connected === true, "Beto no recupera su silla");
comprueba(igual(v.hands[0], juego().hands[2]), "Beto no recupera sus fichas");
comprueba(igual(v.cards[0], juego().cards[2]), "Beto no recupera sus cartas");
comprueba(juego().bot[2] === false, "sigue jugando el bot por Beto");
// la sesión vieja se cierra tarde: no debe sacarlo de la silla
marca = enviados.length;
salir(B);
comprueba((estado as EstadoSala).seats[2].presence !== null, "la sesión vieja desconecta a Beto");
comprueba(eventosDe("A", marca, "left").length === 0, "la sesión vieja manda left");
// recupera su turno: le toca y espera por él (no juega el bot)
guarda = 0;
while (!(juego().phase === "play" && juego().turn === 2) && guarda++ < 3000) vueltaAtentos([[A, 0]]);
comprueba(juego().phase === "play" && juego().turn === 2, "no le vuelve a tocar a Beto");
const cadena = juego().chain.length;
esperar(2);
comprueba(juego().turn === 2 && juego().chain.length === cadena, "el bot juega por Beto aunque volvió");
v = ultimaVista("B");
comprueba(v.turn === 0, "en la vista de Beto no es su turno");
marca = enviados.length;
vueltaAtentos([[B2, 2]]);
ev = eventosDe("A", marca).filter((x) => (x.k === "play" || x.k === "pass") && x.seat === 2);
comprueba(ev.length === 1, "Beto no puede jugar su turno al volver");
comprueba(enviados.slice(marca).every((x) => x.op !== OP_AVISO), "el servidor rechaza la jugada de Beto");
// frase en partida, girada
marca = enviados.length;
vuelta([[B2, OP_FRASE, { id: "chivo_visto" }]]);
ev = eventosDe("A", marca, "frase");
comprueba(ev.length === 1 && ev[0].seat === 2 && ev[0].id === "chivo_visto", "frase en partida: " + JSON.stringify(ev));

// tienda: 45 s y el reloj llega en la vista que cierra la mano
let vistaTienda: any = null;
guarda = 0;
while (vistaTienda === null && guarda++ < 5000) {
	marca = enviados.length;
	vueltaAtentos(juego().phase === "shop" ? [] : [[A, 0], [B2, 2]]);
	for (const x of vistasDe("A", marca)) if (x.phase === "shop" && vistaTienda === null) vistaTienda = x;
	if (juego().phase === "over") break;
}
if (vistaTienda !== null) {
	const tTienda = T_TIENDA; // tras un tranque, la tienda no corre hasta que acaba su flujo
	comprueba(vistaTienda.secs === tTienda && vistaTienda.turn_deadline_secs === tTienda, "reloj de la tienda: " + vistaTienda.secs + "/" + vistaTienda.turn_deadline_secs);
	esperar(2);
	comprueba(juego().phase === "shop", "la tienda se cierra sin que nadie pulse listo");
	if ((estado as EstadoSala).tq) (estado as EstadoSala).tq!.etapa = "fin"; // si fue tranque, su flujo ya acabó
	const ver = (estado as EstadoSala).ver;
	if (ver && !ver.fin) {
		// V1: dominó → hay que verificar; la vista lo dice y la tienda espera
		comprueba(!!ultimaVista("A").ver, "V1: la vista no trae la verificación");
		vuelta([[A, OP_VERIFICAR, { reclamar: true }], [B2, OP_VERIFICAR, { ok: true }]]);
		comprueba(eventosDe("A", 0, "reclamo").length >= 1, "V1: el reclamo no avisa");
		vuelta();
		comprueba((estado as EstadoSala).ver!.fin, "V1: con todos vistos la verificación no se cierra");
	}
	vuelta([[A, OP_LISTO, {}], [B2, OP_LISTO, {}]]);
	vuelta();
	v = ultimaVista("A");
	comprueba(v.phase === "pick" && v.secs === T_CARTA, "tras la tienda el reloj no es el de la carta: " + v.phase + " " + v.secs);
} else {
	comprueba(juego().phase === "over", "no se llega a la tienda");
}

// ---------------------------------------------------------------- 4. ausente (2026-10-04): un tiempo agotado y sus turnos duran 5 s

const D = presencia("D");
nuevaSala();
entrar(D);
vuelta([[D, OP_PERFIL, { name: "Dani" }]]);
todosListos(); vuelta([[D, OP_EMPEZAR, {}]]);
esperar(T_CARTA + 0.4); // tiempo agotado (carta)
comprueba(juego().picked[0], "no se elige carta al acabarse el tiempo");
comprueba((estado as EstadoSala).ausente[0], "un tiempo agotado no lo marca ausente");
v = ultimaVista("D");
comprueba(v.seats[0].away === true, "la vista no trae away: true");
// robar: ausente, se le reparten las suyas a los 5 s (no a los 25)
esperar(T_AUSENTE + 0.6);
comprueba(juego().phase === "play", "ausente: no se le reparte a los 5 s de robar (fase " + juego().phase + ")");
// su turno: 5 s y luego su bot (ni antes ni mucho después)
guarda = 0;
while (!(juego().phase === "play" && juego().turn === 0) && guarda++ < 3000) vuelta();
const cadenaD = juego().chain.length;
const pasesD = juego().stats.pases.slice();
vuelta();
comprueba(ultimaVista("D").turn_deadline_secs === T_AUSENTE, "el turno del ausente no dura " + T_AUSENTE + " s: " + ultimaVista("D").turn_deadline_secs);
esperar(T_AUSENTE - 1.5);
comprueba(juego().phase === "play" && juego().turn === 0 && juego().chain.length === cadenaD, "el bot juega por el ausente antes de sus 5 s");
esperar(2.5);
comprueba(!(juego().phase === "play" && juego().turn === 0 && juego().chain.length === cadenaD), "el bot no juega por el ausente a los 5 s");
// la tienda no espera al ausente; cualquier mensaje lo devuelve (también OP_AQUI)
vuelta([[D, OP_AQUI, {}]]);
comprueba(!(estado as EstadoSala).ausente[0] && juego().bot[0] === false, "OP_AQUI no quita el ausente");
comprueba(ultimaVista("D").seats[0].away === false, "la vista sigue con away: true");

// un tiempo agotado y luego juega: el contador vuelve a 0
const F = presencia("F");
nuevaSala();
entrar(F);
vuelta([[F, OP_PERFIL, { name: "Fefa" }]]);
todosListos(); vuelta([[F, OP_EMPEZAR, {}]]);
esperar(T_CARTA + 0.4);
comprueba((estado as EstadoSala).fallosTiempo[0] === 1, "no cuenta el tiempo agotado de la carta");
guarda = 0;
while (juego().phase === "draw" && guarda++ < 500) vueltaAtentos([[F, 0]]);
comprueba((estado as EstadoSala).fallosTiempo[0] === 0 && !(estado as EstadoSala).ausente[0], "jugar no reinicia el contador de tiempos agotados");

// sin jugada posible NO pasa solo: pasar es decisión del jugador (OP_PASAR).
// Si se le acaba el turno entero, pasa el servidor y no cuenta como tiempo agotado.
guarda = 0;
let vioPase = false;
while (!vioPase && guarda++ < 20000) {
	const g = juego();
	// la partida acabó sin quedarse sin jugada: otra (antes la prueba fallaba por azar)
	if (g.phase === "over") {
		vuelta([[F, OP_REVANCHA, {}]]);
		continue;
	}
	if (g.phase === "play" && g.turn === 0 && rJugadas(g, 0).length === 0 && g.chain.length > 0) {
		marca = enviados.length;
		vuelta();
		v = ultimaVista("F");
		comprueba(v.turn_deadline_secs === T_TURNO, "sin jugada el turno no dura " + T_TURNO + " s: " + v.turn_deadline_secs);
		esperar(T_TURNO + 1);
		comprueba(juego().turn === 0 && juego().chain.length === g.chain.length, "pasó solo al acabarse el tiempo (pasar es decisión del jugador)");
		comprueba((estado as EstadoSala).ausente[0], "el turno agotado sin jugada no lo marca ausente");
		vuelta([[F, OP_PASAR, {}]]);
		comprueba(juego().turn !== 0 || juego().phase !== "play", "OP_PASAR no pasa");
		comprueba((estado as EstadoSala).fallosTiempo[0] === 0, "pasar a mano no reinicia los tiempos agotados");
		vioPase = true;
		break;
	}
	vueltaAtentos([[F, 0]]);
}
comprueba(vioPase, "nunca se quedó sin jugada para probar el pase");

// ---------------------------------------------------------------- de pie: poses, tapar y mirar fichas

const P = presencia("P"), Q = presencia("Q");
nuevaSala();
entrar(P);
entrar(Q); // Q es la pareja de P (silla 2); las sillas 1 y 3 son bots
vuelta([[P, OP_PERFIL, { name: "Pepa" }], [Q, OP_PERFIL, { name: "Quique" }]]);
todosListos(); vuelta([[P, OP_EMPEZAR, {}]]);
guarda = 0;
while (juego().phase !== "play" && guarda++ < 500) vueltaAtentos([[P, 0], [Q, 2]]);
comprueba(juego().phase === "play", "no se llegó a jugar para probar de pie");
const es = () => estado as EstadoSala;
// P se levanta; Yeya (silla 1, bot) no tapa en esta prueba
vuelta([[P, OP_POSE, { st: 1 }]]);
es().tapaEn[1] = 0;
es().tapado[1] = false;
comprueba(es().poses[0].st === 1, "no quedó levantándose");
// de pie detrás de la silla 1 (en +X): aún levantándose, no ve nada
vuelta([[P, OP_POSE, { st: 2, x: 1.6, z: 0, yaw: Math.PI / 2 }]]);
let vp = ultimaVista("P");
// (con Ojo pícaro ya se ve 1 ficha de cada rival: «no ve» = como mucho 1)
const vistas = (h: any[]) => h.filter((t: any) => t !== null).length;
comprueba(vistas(vp.hands[1]) <= 1, "ve fichas antes de terminar de levantarse");
esperar(T_LEVANTARSE + 0.4);
es().tapado[1] = false;
es().tapaEn[1] = 0;
vuelta([[P, OP_POSE, { st: 2, x: 1.6, z: 0.05, yaw: Math.PI / 2, a: true }]]);
comprueba(es().poses.every((q: any) => q.a !== true), "armado en una sala sin armas");
vuelta();
vp = ultimaVista("P");
comprueba(vp.hands[1].length > 0 && vp.hands[1].every((t: any) => t !== null), "detrás de Yeya sin tapar no ve sus fichas");
comprueba(vistas(vp.hands[3]) <= 1, "ve las fichas de la silla 3 desde el otro lado");
comprueba(vistas(ultimaVista("Q").hands[1]) <= 1, "Q ve fichas por estar P de pie");
// Q recibe la pose de P girada: P es su silla 2 local y (1.6, 0.05) pasa a (−1.6, −0.05)
const posesQ = enviados.filter((x) => x.op === OP_POSES && x.to.indexOf("Q") >= 0);
const ultQ = posesQ[posesQ.length - 1].data;
comprueba(ultQ.poses[2].st === 2 && Math.abs(ultQ.poses[2].x + 1.6) < 0.01 && Math.abs(ultQ.poses[2].z + 0.05) < 0.01, "pose girada mal para Q: " + JSON.stringify(ultQ.poses[2]));
// Yeya tapa: deja de verlas
es().tapado[1] = true;
es().posesCambio = true;
vuelta();
comprueba(vistas(ultimaVista("P").hands[1]) <= 1, "sigue viendo fichas tapadas");
// fuera de la sala, posición absurda: se queda dentro de las paredes
vuelta([[P, OP_POSE, { st: 2, x: 99, z: -99, yaw: 0 }]]);
comprueba(es().poses[0].x <= 2.9 && es().poses[0].z >= -2.1, "pose fuera de las paredes");
// Q (silla 2) ve el colmado girado: su «delante» (z local +2.25) es la pared del mostrador (z −2.1 en el colmado)
vuelta([[Q, OP_POSE, { st: 1 }]]);
vuelta([[Q, OP_POSE, { st: 2, x: 0, z: 2.25, yaw: 0, p: -0.4 }]]);
comprueba(Math.abs(es().poses[2].z + 2.1) < 0.001 && es().poses[2].pitch === -0.4, "pose de la silla 2 mal girada o fuera de las paredes: " + JSON.stringify(es().poses[2]));
vuelta([[Q, OP_POSE, { st: 0 }]]);
// emote con objetivo: llega a todos con la silla girada
marca = enviados.length;
vuelta([[P, OP_EMOTE, { id: "wave", target: 1 }]]);
const em = eventosDe("Q", marca, "emote");
comprueba(em.length === 1 && em[0].id === "wave" && em[0].seat === 2 && em[0].target === 3, "emote mal: " + JSON.stringify(em));
vuelta([[P, OP_EMOTE, { id: "bomba" }]]);
// lo que hace con sus fichas: a Q le llega con la silla girada; fuera de su turno (F10) reacomoda, sin punta
marca = enviados.length;
const turnoP = juego().turn === 0;
vuelta([[P, OP_MANO, { st: 2, side: 1 }]]);
const manosQ = enviados.slice(marca).filter((x) => x.op === OP_MANOS && x.to.indexOf("Q") >= 0);
comprueba(manosQ.length === 1 && manosQ[0].data.seat === 2 && manosQ[0].data.st === 2 && manosQ[0].data.side === (turnoP ? 1 : 0), "mano mal reenviada a Q: " + JSON.stringify(manosQ));
comprueba(enviados.slice(marca).every((x) => x.op !== OP_MANOS || x.to.indexOf("P") < 0), "a P le llega su propia mano");
marca = enviados.length;
vuelta([[P, OP_MANO, { st: 99, side: -7 }]]);
const raro = enviados.slice(marca).filter((x) => x.op === OP_MANOS)[0];
comprueba(raro === undefined, "mano absurda rechazada sin reenviar: " + JSON.stringify(raro));
// golpes de pie (2026-10-04): P y Q de pie y cerca
vuelta([[P, OP_POSE, { st: 2, x: 0, z: 1.5, yaw: 0 }]]);
vuelta([[Q, OP_POSE, { st: 1 }]]);
vuelta([[Q, OP_POSE, { st: 2, x: 0, z: -1.9, yaw: 0 }]]); // Q es la silla 2: su (0, −1,9) es (0, 1,9) en el colmado
marca = enviados.length;
vuelta([[P, OP_GOLPE, { target: 2 }]]);
let gp = eventosDe("Q", marca, "golpe");
comprueba(gp.length === 1 && gp[0].target === 0 && gp[0].cae === false, "primer golpe mal: " + JSON.stringify(gp));
vuelta([[P, OP_GOLPE, { target: 2 }]]); // antes de 2 s: no vale
comprueba(es().caidoHasta[2] === 0, "se puede golpear sin esperar");
esperar(2.1);
marca = enviados.length;
vuelta([[P, OP_GOLPE, { target: 2 }]]); // segundo seguido: al suelo
gp = eventosDe("P", marca, "golpe");
comprueba(gp.length === 1 && gp[0].cae === true && es().caidoHasta[2] > 0, "el segundo golpe no tumba: " + JSON.stringify(gp));
const posesP = enviados.filter((x) => x.op === OP_POSES && x.to.indexOf("P") >= 0);
comprueba(posesP[posesP.length - 1].data.poses[2].c === true, "las poses no dicen que está en el suelo");
esperar(T_CAIDO + 0.3);
comprueba(es().caidoHasta[2] === 0, "no se levanta del suelo");
// tercer golpe en poco tiempo: el colmadero lo manda a su silla
esperar(0.1);
marca = enviados.length;
vuelta([[P, OP_GOLPE, { target: 2 }]]);
comprueba(eventosDe("Q", marca, "colmadero").length === 1 && es().poses[0].st === 0, "el colmadero no manda a su silla al que abusa");
vuelta([[Q, OP_POSE, { st: 0 }]]);
// se sienta: todos sentados y los bots destapan
vuelta([[P, OP_POSE, { st: 0 }]]);
comprueba(es().poses[0].st === 0 && !es().tapado[1], "al sentarse no se destapan los bots");

// de pie en su turno: el reloj se para (como mucho T_CONGELADO) y vuelve a correr al sentarse
if (juego().phase === "play") {
	juego().turn = 0;
	juego().revision = null;
	es().faseVista = "";
	vuelta([[P, OP_POSE, { st: 1 }]]);
	vuelta([[P, OP_POSE, { st: 2, x: 0, z: 1.5, yaw: 0 }]]);
	esperar(T_TURNO + 5);
	comprueba(juego().turn === 0 && ultimaVista("P").reloj_parado === true, "de pie en su turno el reloj no se para (turno " + juego().turn + ")");
	comprueba(ultimaVista("Q").reloj_parado === true, "su compañero no ve el reloj parado");
	vuelta([[P, OP_POSE, { st: 0 }]]);
	comprueba(ultimaVista("P").reloj_parado === false, "sentado, el reloj sigue parado");
	esperar(T_TURNO + 1);
	comprueba(juego().turn !== 0 || ultimaVista("P").secs <= T_AUSENTE, "sentado, el reloj no vuelve a correr");
}

// ---------------------------------------------------------------- revancha visible, por persona y girada

nuevaSala();
entrar(A);
entrar(B);
entrar(C); // sillas 0, 2, 1; la 3 sigue siendo bot
todosListos(); vuelta([[A, OP_EMPEZAR, {}]]);
juego().phase = "over";
salaReloj(estado);
salaEnviarTodo(estado, dispatcherFalso, nkFalso);
for (const id of ["A", "B", "C"]) {
	comprueba(igual(ultimaVista(id).revancha, [false, false, false, false]), "revancha inicial en " + id);
}
vuelta([[A, OP_REVANCHA, {}]]);
for (const id of ["A", "B", "C"]) {
	const v = ultimaVista(id);
	comprueba(v.revancha.filter(Boolean).length === 1, "primer voto llega a " + id);
	comprueba(v.revancha[salaRot(0, v.yo)], "voto de A girado para " + id);
}
vuelta([[A, OP_REVANCHA, {}]]);
comprueba(ultimaVista("B").revancha.filter(Boolean).length === 1, "repetir no duplica el voto");
vuelta([[B, OP_REVANCHA, {}]]);
for (const id of ["A", "B", "C"]) {
	const v = ultimaVista(id);
	comprueba(v.phase === "over" && v.revancha.filter(Boolean).length === 2, "dos votos en " + id);
	comprueba(v.revancha[salaRot(2, v.yo)], "voto de B girado para " + id);
	comprueba(!v.revancha[salaRot(3, v.yo)], "el bot no cuenta para " + id);
}
// Reconectar recupera los votos desde la vista, sin depender de eventos pasados.
salir(C);
entrar(C);
comprueba(ultimaVista("C").revancha.filter(Boolean).length === 2, "reconexión recupera los votos");
vuelta([[C, OP_REVANCHA, {}]]);
for (const id of ["A", "B", "C"]) {
	const v = ultimaVista(id);
	comprueba(v.phase !== "over", "la revancha arranca sin esperar al bot para " + id);
	comprueba(igual(v.revancha, [false, false, false, false]), "contador reiniciado para " + id);
}
comprueba(igual(estado.revancha, [false, false, false, false]), "votos internos reiniciados");
vuelta([[A, OP_REVANCHA, {}]]);
comprueba(igual(estado.revancha, [false, false, false, false]), "no se vota fuera del final");

// ---------------------------------------------------------------- resultado

// VISTO también debe poder reconocer el tranque que termina la partida.
nuevaSala();
entrar(A);
todosListos(); vuelta([[A, OP_EMPEZAR, {}]]);
for (const phase of ["shop", "over"]) {
	juego().phase = phase;
	juego().last_result = { reason: "tranque" };
	salaReloj(estado);
	estado.tranqueOk[0] = false;
	vuelta(); // empieza el flujo del tranque (revelar)
	vuelta([[A, OP_TRANQUE_OK, {}]]);
	comprueba(!estado.tranqueOk[0], "VISTO antes de revelar las fichas en " + phase);
	estado.tq.etapa = "visto";
	vuelta([[A, OP_TRANQUE_OK, {}]]);
	comprueba(estado.tranqueOk[0], "VISTO acepta tranque en " + phase);
	estado.tq = null;
}
juego().last_result = { reason: "dominó" };
estado.tranqueOk[0] = false;
vuelta([[A, OP_TRANQUE_OK, {}]]);
comprueba(!estado.tranqueOk[0], "VISTO solo reconoce tranques");

// ---------------------------------------------------------------- mensajes hostiles: reproducir antes de blindar
function vueltaCruda(p: nkruntime.Presence, op: number, texto: string, cantidad = 1): boolean {
	tick++;
	const mensajes: any[] = [];
	for (let i = 0; i < cantidad; i++) mensajes.push({ sender: p, opCode: op, data: texto, reliable: true });
	try {
		const r = salaLoop(ctxFalso, loggerFalso, nkFalso, dispatcherFalso, tick, estado, mensajes);
		if (r === null) return false;
		estado = r.state;
		return true;
	} catch (_) { return false; }
}
const operacionesCliente = [1, 2, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28];
for (const op of operacionesCliente) {
	nuevaSala(); entrar(A);
	comprueba(vueltaCruda(A, op, "null"), "JSON null no tira sala: op " + op);
}
nuevaSala(); entrar(A);
comprueba(vueltaCruda(A, OP_EMPEZAR, "{") && juego() === null, "JSON roto no ejecuta EMPEZAR");
nuevaSala(); entrar(A);
comprueba(vueltaCruda(presencia("A", "vieja"), OP_EMPEZAR, "{}") && juego() === null, "sesión vieja no actúa por otra presencia");
nuevaSala(); entrar(A); todosListos(); vuelta([[A, OP_EMPEZAR, {}]]);
juego().phase = "draw"; juego().pool_taken = {};
comprueba(vueltaCruda(A, OP_ROBAR, '{"idx":0.5}') && Object.keys(juego().pool_taken).length === 0, "robo fraccionario no corrompe el pozo");
comprueba(vueltaCruda(A, OP_ROBAR, '{"idx":"0"}') && Object.keys(juego().pool_taken).length === 0, "robo no convierte texto a índice");
nuevaSala(); entrar(A); entrar(B); todosListos(); vuelta([[A, OP_EMPEZAR, {}]]);
juego().phase = "play"; juego().turn = 0; juego().revision = null;
comprueba(vueltaCruda(A, OP_GOLPE, '{"target":1.5}') && es().golpeListo[0] === 0, "golpe a silla fraccionaria no tira sala");
comprueba(vueltaCruda(A, OP_POSE, '{"st":2}') && es().poses[0].st === 0, "pose incompleta no cambia estado");
comprueba(vueltaCruda(A, OP_POSE, '{"st":2,"x":0,"z":1.4,"yaw":0}') && es().poses[0].st !== 2, "no se salta levantamiento para espiar fichas");
comprueba(vueltaCruda(A, OP_PERFIL, JSON.stringify({ name: "X", avatar: { invasor: { hands: [[6, 6]] }, skin: 123 } })) &&
	(es().seats[0].avatar === null || es().seats[0].avatar.invasor === undefined), "perfil no reenvía objetos arbitrarios");
nuevaSala(); entrar(A); entrar(B);
const antesInundacion = enviados.length;
comprueba(vueltaCruda(A, OP_MANO, '{"st":0,"side":0}', 500), "inundación no tira sala");
comprueba(enviados.slice(antesInundacion).filter((x) => x.op === OP_MANOS).length <= 4, "inundación de manos acotada por jugador/tick");
nuevaSala(); entrar(A);
comprueba(vueltaCruda(A, OP_PERFIL, JSON.stringify({ name: "enorme", avatar: { basura: "x".repeat(10000) } })) && es().seats[0].name === "", "payload enorme rechazado antes de aplicarlo");
nuevaSala(); entrar(A);
es().ausente[0] = true;
comprueba(vueltaCruda(A, 999, '{}') && es().ausente[0], "op desconocida no reactiva ausente");

// Matriz de tipos de raíz para TODOS los códigos, también los de salida.
for (const op of operacionesCliente.concat([OP_SALA, OP_ESTADO, OP_AVISO, OP_POSES, OP_MANOS, -1, 999])) {
	for (const raiz of ["null", "[]", "42", "true", '"texto"', "{"]) {
		nuevaSala(); entrar(A); es().ausente[0] = true;
		comprueba(vueltaCruda(A, op, raiz) && juego() === null && es().ausente[0], "raíz inválida ignorada " + op + "/" + raiz);
	}
}
const Dseg = presencia("Dseg");
function prepararSeguridad(): void {
	nuevaSala(); entrar(A); entrar(B); entrar(C); entrar(Dseg);
	todosListos(); vuelta([[A, OP_EMPEZAR, {}]]);
	const g = juego();
	g.phase = "play"; g.turn = 0; g.revision = null;
	g.chain = [[6, 6]]; g.left_end = 6; g.right_end = 6;
	g.hands = [[[6, 5], [0, 0]], [[1, 1], [1, 2]], [[2, 2], [2, 3]], [[3, 3], [3, 4]]];
	g.revealed = [[], [], [], []]; g.reveal_partner = [false, false, false, false];
	g.events = []; g.bot = [false, false, false, false];
	salaReloj(es()); es().deadline = tick + 1000;
}
for (const caso of [
	[OP_ROBAR, {idx: null}], [OP_ROBAR, {idx: -1}], [OP_ROBAR, {idx: 28}], [OP_ROBAR, {idx: 1e100}],
	[OP_JUGAR, {tile: "65", side: 1}], [OP_JUGAR, {tile: [6.5, 5], side: 1}],
	[OP_JUGAR, {tile: [6, 5], side: "1"}], [OP_JUGAR, {tile: [6, 5], side: null}], [OP_JUGAR, {tile: [6, 5], side: 900}],
	[OP_CARTA, {id: {}}], [OP_BEBER, {id: "__proto__"}], [OP_COMPRAR, {id: "constructor"}],
	[OP_GOLPE, {target: 1.5}], [OP_GOLPE, {target: -1}], [OP_GOLPE, {target: 99}], [OP_GOLPE, {target: 2, run: "true"}],
	[OP_POSE, {st: 2, x: null, z: 1, yaw: 0}], [OP_POSE, {st: 2, x: 1e100, z: 1, yaw: 0}],
	[OP_POSE, {st: 2, x: 0, z: 1, yaw: 0, p: "0"}], [OP_TAPAR, {on: 1}],
	[OP_EMOTE, {id: "shove", target: 1.5}], [OP_EMOTE, {id: "point", px: null, pz: 0}],
	[OP_MANO, {st: 1.5, side: 0}], [OP_REVISAR, {none: true, tile: [6, 5]}]
] as [number, any][]) {
	prepararSeguridad();
	const antes = JSON.stringify([juego(), es().poses, es().tapado, es().golpeListo]);
	comprueba(vueltaCruda(A, caso[0], JSON.stringify(caso[1])) && antes === JSON.stringify([juego(), es().poses, es().tapado, es().golpeListo]), "campos inválidos no mutan juego " + JSON.stringify(caso));
}
prepararSeguridad();
comprueba(vueltaCruda(A, OP_POSE, '{"st":2,"x":1e309,"z":0,"yaw":0}') && es().poses[0].st === 0, "Infinity JSON rechazado");
comprueba(salaFicha([NaN, 6]) === null && salaFicha([Infinity, 6]) === null && salaFicha({length: 2, 0: 6, 1: 5}) === null, "NaN/Infinity y objeto parecido a ficha rechazados");
// Pertenencia, turno, fase y silla: campos adicionales nunca eligen actor.
prepararSeguridad();
const manoAntes = JSON.stringify(juego().hands);
vuelta([[B, OP_JUGAR, {tile: [6, 5], side: 1, seat: 0}]]);
vuelta([[A, OP_JUGAR, {tile: [1, 1], side: 1, seat: 1}]]);
comprueba(JSON.stringify(juego().hands) === manoAntes && juego().chain.length === 1, "no jugar por silla ajena/fuera de turno o con ficha inexistente");
vuelta([[A, OP_POSE, {st: 1}]]);
vuelta([[A, OP_JUGAR, {tile: [6, 5], side: 1}]]);
comprueba(JSON.stringify(juego().hands) === manoAntes, "levantado no juega fichas");
vuelta([[A, OP_POSE, {st: 0}]]);
vuelta([[A, OP_JUGAR, {tile: [6, 5], side: 1, seat: 1}]]);
comprueba(juego().hands[0].length === 1 && juego().hands[1].length === 2, "jugada válida usa solo silla de la sesión");
for (const op of [OP_ROBAR, OP_CARTA, OP_LISTO, OP_REVANCHA, OP_COMPRAR]) {
	prepararSeguridad();
	const antes = JSON.stringify(juego());
	vuelta([[A, op, {idx: 0, id: "cafe"}]]);
	comprueba(antes === JSON.stringify(juego()) && !es().listos[0] && !es().revancha[0], "fase equivocada no actúa " + op);
}
// Golpes válidos y objetivos rechazados por estado/distancia/presencia.
for (const tipo of ["lejos", "sentado", "bot", "fraccionario"]) {
	prepararSeguridad();
	es().poses[0] = {st: 2, x: 0, z: 1.5, yaw: 0, pitch: 0, desde: 0};
	es().poses[2] = {st: tipo === "sentado" ? 0 : 2, x: tipo === "lejos" ? 2 : 0, z: 1.7, yaw: 0, pitch: 0, desde: 0};
	if (tipo === "bot") es().seats[2].presence = null;
	vuelta([[A, OP_GOLPE, {target: tipo === "fraccionario" ? 2.5 : 2}]]);
	comprueba(es().golpeListo[0] === 0 && es().caidoHasta[2] === 0, "golpe inválido " + tipo);
}
// Flujo válido tras basura y otra silla no se ve limitada por el atacante.
prepararSeguridad();
const inicioSpam = enviados.length;
vueltaCruda(A, OP_MANO, '{"st":2,"side":1}', 500);
comprueba(enviados.slice(inicioSpam).filter((x) => x.op === OP_MANOS).length === 6, "dos manos por tick a tres destinatarios");
vuelta([[B, OP_FRASE, {id: "buena"}]]);
comprueba(eventosDe("B", inicioSpam, "frase").length === 1, "atacante no consume límite de compañero");
const posesAntesSpam = JSON.stringify(es().poses);
vueltaCruda(A, OP_POSE, '{"st":2,"x":null,"z":0,"yaw":0}', 500);
comprueba(posesAntesSpam === JSON.stringify(es().poses), "spam inválido de poses no cambia postura");
// Ocultación por receptor en las cuatro rotaciones; pozo nunca viaja.
prepararSeguridad();
for (let yo = 0; yo < 4; yo++) {
	const vista = salaVista(es(), yo, []);
	comprueba(igual(vista.hands[0], juego().hands[yo]), "mano propia visible silla " + yo);
	comprueba(vista.hands.slice(1).every((h: any[]) => h.every((t) => t === null)) && vista.pool === undefined, "manos/pozo ocultos silla " + yo);
	const eventos = salaEventosGirados([{k: "chivo_false", seat: 0, hand: [[6, 5]]}], yo);
	comprueba(yo === 0 ? eventos[0].hand !== undefined : eventos[0].hand === undefined, "evento privado solo para acusador " + yo);
}
juego().revision = {caller: 0, accused: 1} as any;
comprueba(salaVista(es(), 0, []).hands[1].every((t: any) => t !== null) && salaVista(es(), 2, []).hands[3].every((t: any) => t === null), "revisión solo revela mano a quien acusa");
juego().revision = null; juego().reveal_partner[0] = true;
comprueba(igual(salaVista(es(), 0, []).hands[2], juego().hands[2]) && salaVista(es(), 1, []).hands[1].every((t: any) => t === null), "bebida revela compañero solo a dueño");
juego().phase = "shop";
comprueba(salaVista(es(), 0, []).hands.every((h: any[]) => h.every((t) => t !== null)), "fin de mano conserva revelación prevista");

// El emote antiguo «shove» también aplica empuje en el cliente: no debe ser
// una vía alternativa que esquive las comprobaciones de OP_GOLPE.
for (const tipo of ["sentado", "lejos"]) {
	prepararSeguridad();
	es().poses[0] = {st: 2, x: 0, z: 1.5, yaw: 0, pitch: 0, desde: 0};
	es().poses[2] = {st: tipo === "sentado" ? 0 : 2, x: tipo === "lejos" ? 2 : 0, z: 1.7, yaw: 0, pitch: 0, desde: 0};
	const marcaShove = enviados.length;
	vuelta([[A, OP_EMOTE, {id: "shove", target: 2}]]);
	comprueba(eventosDe("B", marcaShove, "emote").length === 0 && eventosDe("B", marcaShove, "golpe").length === 0, "emote shove no empuja a " + tipo);
}

// Un shove cercano válido usa el MISMO cooldown y evento que OP_GOLPE.
prepararSeguridad();
es().poses[0] = {st: 2, x: 0, z: 1.5, yaw: 0, pitch: 0, desde: 0};
es().poses[2] = {st: 2, x: 0, z: 1.7, yaw: 0, pitch: 0, desde: 0};
const marcaCercano = enviados.length;
vuelta([[A, OP_EMOTE, {id: "shove", target: 2}]]);
vuelta([[A, OP_GOLPE, {target: 2}]]);
comprueba(eventosDe("B", marcaCercano, "golpe").length === 1 && eventosDe("B", marcaCercano, "emote").length === 0, "shove cercano usa golpe y comparte cooldown");
// Cada familia inundada: las retransmisiones están acotadas, sin castigar a B.
for (const dato of [[OP_PERFIL, {name: "A"}], [OP_FRASE, {id: "buena"}], [OP_EMOTE, {id: "wave"}], [OP_POSE, {st: 1}], [OP_TAPAR, {on: true}]] as [number, any][]) {
	prepararSeguridad();
	const inicio = enviados.length;
	comprueba(vueltaCruda(A, dato[0], JSON.stringify(dato[1]), 500), "inundación segura op " + dato[0]);
	comprueba(enviados.length - inicio <= 8, "inundación sin cientos de avisos op " + dato[0]);
}
prepararSeguridad();
let decodificados = 0;
const nkContador = {binaryToString(d: any) { decodificados++; return String(d); }} as any as nkruntime.Nakama;
const basura: any[] = [];
for (let i = 0; i < 500; i++) basura.push({sender: A, opCode: 800 + i, data: "{", reliable: true});
basura.push({sender: B, opCode: OP_FRASE, data: '{"id":"gracias"}', reliable: true});
const marcaBasura = enviados.length;
const trasBasura = salaLoop(ctxFalso, loggerFalso, nkContador, dispatcherFalso, ++tick, estado, basura);
comprueba(trasBasura !== null && decodificados <= 13, "límite previo al parseo incluye ops desconocidas/JSON roto");
estado = (trasBasura as any).state;
comprueba(eventosDe("B", marcaBasura, "frase").length === 1, "otro jugador funciona dentro del mismo tick de ataque");
// Fallo de decodificación y excepción inesperada del envío no tiran el loop.
prepararSeguridad();
const nkRoto = {binaryToString() {throw Error("contenido privado de prueba");}} as any as nkruntime.Nakama;
const unMensaje: any[] = [{sender: A, opCode: OP_MANO, data: '{"st":1,"side":0}', reliable: true}];
comprueba(salaLoop(ctxFalso, loggerFalso, nkRoto, dispatcherFalso, ++tick, estado, unMensaje) !== null, "error de decodificación no tira matchLoop");
let falloEnvio = true;
const dispatcherRoto = {
	broadcastMessage(op: number, data: any, pr: any) {
		if (falloEnvio) {falloEnvio = false; throw Error("error simulado del envío");}
		guardar(op, data, pr);
	}, matchLabelUpdate() {}
} as any as nkruntime.MatchDispatcher;
comprueba(salaLoop(ctxFalso, loggerFalso, nkFalso, dispatcherRoto, ++tick, estado, unMensaje) !== null, "excepción en manejador no tira matchLoop");
// Matriz positiva: todas las formas del protocolo del cliente siguen admitidas.
for (const dato of [[OP_PERFIL, {name: "Ana", avatar: {skin: "#aa7733", mustache: true, hat: "calvo"}}],
	[OP_CARTA, {id: "fiado"}], [OP_ROBAR, {idx: 0}], [OP_JUGAR, {tile: [6, 5], side: -1}],
	[OP_BEBER, {id: "cafe"}], [OP_COMPRAR, {id: "agua"}], [OP_FRASE, {id: "gracias"}],
	[OP_POSE, {st: 0}], [OP_POSE, {st: 1}], [OP_POSE, {st: 2, x: 0.34, z: 1.4, yaw: 0, p: -0.4}],
	[OP_MANO, {st: 3, side: -1}], [OP_TAPAR, {on: false}], [OP_GOLPE, {target: 2, run: true}],
	[OP_EMOTE, {id: "point", px: 1, pz: 0, target: -1}], [OP_REVISAR, {none: true}], [OP_REVISAR, {tile: [1, 2]}]
] as [number, any][]) comprueba(salaDatosValidos(dato[0], dato[1]), "contrato válido " + dato[0]);

// Listado: simula un índice que incluso entrega etiquetas privadas/antiguas.
const etiquetasPrueba = [
	{code:"aaaaaa", publica:true, modo:"clasico", meta:100, open:true, players:1, anfitrion:"A", estado:"esperando", mano:0},
	{code:"bbbbbb", publica:true, modo:"aumentos", meta:200, open:false, players:4, anfitrion:"B", estado:"esperando", mano:0},
	{code:"cccccc", publica:true, modo:"clasico", meta:200, open:true, players:2, anfitrion:"C", estado:"jugando", mano:3},
	{code:"dddddd", publica:false, modo:"clasico", meta:100, open:true, players:1, estado:"esperando"},
	{code:"eeeeee", modo:"clasico", meta:100, open:true, players:1, estado:"esperando"},
];
let consultaLista = "";
const nkLista = {matchList(limit: number, authoritative: boolean, label: any, min: any, max: any, query: string) {
	consultaLista = query;
	comprueba(limit === 50 && authoritative, "listado limitado y autoritativo");
	return etiquetasPrueba.map(l => ({label:JSON.stringify(l)})).concat([{label:"{rota"}]);
}} as any as nkruntime.Nakama;
function listarPrueba(filtros: any): any[] {
	return JSON.parse(rpcListarSalas(ctxFalso, loggerFalso, nkLista, JSON.stringify(filtros)) as string).salas;
}
const todas = listarPrueba({});
comprueba(todas.length === 3, "privadas y etiquetas antiguas ocultas");
comprueba(todas[0].code === "BBBBBB" && todas[2].code === "CCCCCC", "esperando primero y orden por jugadores");
comprueba(todas.filter(r => r.estado === "jugando").every(r => !r.puede_entrar), "partidas en curso visibles sin entrada");
comprueba(listarPrueba({modo:"clasico"}).length === 2, "filtro modo");
comprueba(listarPrueba({meta:100}).length === 1, "filtro meta");
comprueba(listarPrueba({solo_libres:true}).length === 2, "filtro sitio libre");
comprueba(consultaLista.indexOf("+label.open:T") >= 0, "booleanos del índice Nakama usan T");
comprueba(listarPrueba({estado:"jugando"}).length === 1, "filtro jugando");
comprueba(listarPrueba({modo:"clasico",meta:200,solo_libres:true,estado:"esperando"}).length === 0, "filtros combinados");
listarPrueba({modo:"* +label.publica:false",meta:"100",estado:"*"});
comprueba(consultaLista === "+label.publica:T", "valores ajenos a filtros no entran en consulta");
const privadaInicial = salaInit(ctxFalso, loggerFalso, nkFalso, {code:"PRIVAD"}).state as EstadoSala;
comprueba(JSON.parse(salaEtiqueta(privadaInicial)).publica === false, "privada por defecto");
const publicaInicial = salaInit(ctxFalso, loggerFalso, nkFalso, {code:"PUBLIC",publica:true,modo:"clasico",meta:200}).state as EstadoSala;
comprueba(JSON.parse(salaEtiqueta(publicaInicial)).publica === true, "pública explícita");
publicaInicial.game = rNuevaPartida([false,true,true,true], "clasico", 200);
const rechazo = salaJoinAttempt(ctxFalso,loggerFalso,nkFalso,dispatcherFalso,tick,publicaInicial,presencia("nuevo"),{});
comprueba(rechazo !== null && !rechazo.accept, "nuevo jugador rechazado tras empezar aunque queden bots");

// Estabilidad: poses periódicas no demuestran actividad y la tienda permite caminar.
nuevaSala(); entrar(A); entrar(B); entrar(C); entrar(D);
es().modo = "clasico";
todosListos(); vuelta([[A, OP_EMPEZAR, {}]]);
for (let i = 0; i < 150 && juego().phase !== "play"; i++) vueltaAtentos([[A,0],[B,2],[C,1],[D,3]]);
comprueba(juego().phase === "play", "fixture estabilidad llega a play");
juego().turn = 0; juego().chain = [[1,1]]; juego().left_end = 1; juego().right_end = 1; juego().hands[0] = [[0,0]];
salaReloj(estado);
es().poses[0].st = 2; es().poses[0].desde = 1; es().congelado = T_CONGELADO * SALA_TICK; es().deadline = tick + 1;
vuelta();
comprueba(es().ausente[0], "vence turno de pie y queda ausente");
for (let i = 0; i < T_AUSENTE*SALA_TICK-1; i++) vuelta([[A,OP_POSE,{st:2,x:0,z:1.5,yaw:0}]]);
comprueba(es().ausente[0], "pose periódica no reactiva ausente");
vuelta([[A,OP_MANO,{st:0,side:0}]]);
comprueba(es().ausente[0], "mano neutra no reactiva ausente");
comprueba(juego().turn !== 0, "bot progresa pese a poses de ausente");
vuelta([[A,OP_AQUI,{}]]);
comprueba(!es().ausente[0], "entrada explícita devuelve al jugador");
juego().phase = "shop"; salaReloj(estado);
vuelta([[A,OP_POSE,{st:1}]]);
comprueba(es().poses[0].st === 1, "tienda no fuerza sentado tras levantarse");
es().tick += Math.ceil(T_LEVANTARSE*SALA_TICK); tick = es().tick;
vuelta([[A,OP_POSE,{st:2,x:0,z:1.5,yaw:0}]]);
comprueba(es().poses[0].st === 2, "tienda mantiene posición de pie");
// Cuatro personas de pie: límite de congelación y timeout sin reactivación por tráfico.
juego().phase = "play"; juego().turn = 0; juego().revision = null; juego().chain = [[1,1]];
juego().left_end = 1; juego().right_end = 1; juego().hands[0] = [[0,0]];
es().ausente = [false,false,false,false]; es().faseVista = "";
salaReloj(estado);
for (let s=0;s<4;s++) { es().poses[s].st=2; es().poses[s].desde=1; }
let inicioCongelado = tick;
for(let i=0;i<T_CONGELADO*SALA_TICK-1;i++) vuelta([[A,OP_POSE,{st:2,x:0,z:1.5,yaw:0}],[B,OP_POSE,{st:2,x:0,z:1.5,yaw:0}],[C,OP_POSE,{st:2,x:0,z:1.5,yaw:0}],[D,OP_POSE,{st:2,x:0,z:1.5,yaw:0}]]);
comprueba(juego().turn===0 && ultimaVista("A").reloj_parado, "cuatro de pie mantienen turno congelado hasta límite");
for(let i=0;i<(T_TURNO+T_AUSENTE+3)*SALA_TICK && juego().turn===0;i++) vuelta([[A,OP_POSE,{st:2,x:0,z:1.5,yaw:0}]]);
comprueba(juego().turn!==0 && es().ausente[0], "timeout completo con poses periódicas progresa y conserva ausente");
comprueba(tick-inicioCongelado <= (T_CONGELADO+T_TURNO+T_AUSENTE+2)*SALA_TICK, "límite de reloj parado no se reinicia indefinidamente");
// ---------------------------------------------------------------- O09: sin personas no sigue solo con bots
{
	const H = presencia("H");
	nuevaSala();
	entrar(H);
	vuelta([[H, OP_PERFIL, { name: "Hugo" }]]);
	todosListos(); vuelta([[H, OP_EMPEZAR, {}]]);
	vuelta([[H, OP_CARTA, { id: juego().offers[0][0] }]]);
	salir(H);
	const antes = JSON.stringify(juego());
	esperar(T_CARTA + T_ROBAR + 2);
	comprueba(JSON.stringify(juego()) === antes, "O09: sin personas los bots siguen jugando la partida");
	// vuelve a tiempo: la partida sigue donde estaba
	entrar(H);
	esperar(T_BOT_CARTA + T_CARTA + 1);
	comprueba(juego().phase !== "pick", "O09: al volver la persona, la partida no sigue (fase " + juego().phase + ")");
	// se va otra vez y nadie vuelve: la sala se cierra
	salir(H);
	let cerrada = false;
	let vueltas = 0;
	while (!cerrada && vueltas < (SALA_VACIA_SEG + 5) * SALA_TICK) {
		vueltas++;
		const r = salaLoop(ctxFalso, loggerFalso, nkFalso, dispatcherFalso, ++tick, estado, []);
		if (r === null) cerrada = true;
		else estado = r.state;
	}
	comprueba(cerrada, "O09: la sala sin personas no se cierra");
	comprueba(vueltas <= (SALA_SOLO_BOTS_SEG + 1) * SALA_TICK, "O09: la sala solo con bots tarda " + vueltas / SALA_TICK + " s en cerrarse");
}

// ---------------------------------------------------------------- tranque con suspenso
{
	const T1 = presencia("T1"), T2 = presencia("T2");
	nuevaSala();
	entrar(T1);
	entrar(T2); // pareja de T1 (silla 2); 1 y 3 son bots
	todosListos(); vuelta([[T1, OP_EMPEZAR, {}]]);
	const es = () => estado as EstadoSala;
	const g = juego();
	// mano trancada a mano: cada uno con dos fichas; trancó la silla 3
	g.hands = [[[0, 1], [2, 3]], [[4, 5], [6, 6]], [[0, 0], [1, 1]], [[5, 5], [3, 4]]] as any;
	g.last_seat = 3;
	g.phase = "shop";
	g.scores = [10, 0];
	g.last_result = { seat: 2, team: 0, pts: 52, reason: "tranque", bonus: [], capicua: false, tranque: { pips: [6, 21, 2, 17], teams: [8, 38], tie: false, opener: 0 } } as any;
	g.scores[0] += 52;
	salaReloj(estado);
	vuelta();
	comprueba(es().tq !== null && es().tq!.etapa === "revelar" && es().tq!.orden[0] === 3, "tranque: empieza a revelar quien trancó");
	let v = ultimaVista("T1");
	comprueba(v.tranque && v.tranque.etapa === "revelar" && v.tranque.turno === 3, "tranque: la vista dice a quién le toca: " + JSON.stringify(v.tranque));
	comprueba(v.hands[1].every((t: any) => t === null) && v.hands[0][0] !== null, "tranque: se ven fichas de otros sin revelar o no las tuyas");
	comprueba(v.last_result.oculto === true && v.scores[0] === 10, "tranque: se sabe quién gana o los puntos antes de revelar");
	vuelta([[T1, OP_REVELAR, { idx: 0 }]]);
	comprueba(es().tq!.rev[0].length === 0, "tranque: revelas fuera de tu turno");
	// los bots (3 y luego 1 tras T1... el orden es 3, 0, 1, 2) giran solos
	const hastaQue = (c: () => boolean, seg: number) => { for (let k = 0; k < seg * SALA_TICK && !c(); k++) vuelta(); };
	hastaQue(() => es().tq!.rev[3].length === 2, T_TQ_INTRO + T_TQ_BOT * 4 + 1);
	comprueba(es().tq!.rev[3].length === 2, "tranque: el bot no giró sus fichas: " + JSON.stringify(es().tq!.rev));
	hastaQue(() => es().tq!.orden[es().tq!.i] === 0 && es().tick >= es().tq!.auto, T_TQ_ENTRE + T_TQ_BOT + 1);
	comprueba(es().tq!.orden[es().tq!.i] === 0, "tranque: no le toca a T1 tras el bot");
	let marcaT = enviados.length;
	vuelta([[T1, OP_AMAGO, { idx: 1 }]]);
	comprueba(eventosDe("T2", marcaT, "amago").length === 1, "tranque: el amago no llega a los demás");
	vuelta([[T1, OP_REVELAR, { idx: 1 }]]);
	v = ultimaVista("T2");
	comprueba(v.hands[2][1] !== null && v.hands[2][0] === null, "tranque: T2 no ve justo la ficha que giró T1: " + JSON.stringify(v.hands[2]));
	// T1 no gira la otra: a los 8 s se gira sola
	esperar(T_TQ_TURNO + T_TQ_AUTO + 0.5);
	comprueba(es().tq!.rev[0].length === 2, "tranque: la ficha no se giró sola a los 8 s");
	// el bot 1 y luego T2 (que no hace nada: se giran solas)
	hastaQue(() => es().tq!.etapa === "visto", T_TQ_ENTRE * 3 + T_TQ_BOT * 5 + T_TQ_TURNO + T_TQ_AUTO * 3 + 2);
	comprueba(es().tq!.etapa === "visto", "tranque: no pasa a VISTO tras revelar todo: " + es().tq!.etapa);
	v = ultimaVista("T1");
	comprueba(v.tranque.ganador === 2 && v.last_result.oculto === undefined && v.scores[0] === 62, "tranque: tras revelar no se ve quién gana y los puntos");
	vuelta([[T1, OP_TRANQUE_OK, {}], [T2, OP_TRANQUE_OK, {}]]);
	vuelta();
	comprueba(es().tq!.etapa === "entregar", "tranque: con todos VISTO no pasa a entregar");
	comprueba(juego().phase === "shop" && es().deadline > es().tick + (T_TIENDA - 1) * SALA_TICK, "tranque: la tienda corre durante el tranque");
	marcaT = enviados.length;
	vuelta([[T1, OP_ENTREGAR, {}]]);
	comprueba(eventosDe("T2", marcaT, "entrega").length === 1 && es().tq!.entregadas[0], "tranque: T1 no entregó sus fichas");
	vuelta([[T2, OP_ARREBATAR, { seat: 1 }]]); // el ganador (2) le quita las suyas a la silla 3
	comprueba(es().tq!.entregadas[3], "tranque: el ganador no arrebata");
	hastaQue(() => es().tq!.etapa === "fin", T_TQ_BOT * 4 + 1);
	comprueba(es().tq!.etapa === "fin", "tranque: no acaba tras entregar todo: " + es().tq!.etapa);
	comprueba(!salaDatosValidos(OP_REVELAR, { idx: -1 }) && !salaDatosValidos(OP_ARREBATAR, { seat: 0 }), "tranque: datos no válidos admitidos");
}

// ---------------------------------------------------------------- tranque: se acaba el tiempo de entregar
{
	const W1 = presencia("W1"), W2 = presencia("W2"), W3 = presencia("W3"), W4 = presencia("W4");
	nuevaSala();
	entrar(W1); entrar(W2); entrar(W3); entrar(W4);
	todosListos(); vuelta([[W1, OP_EMPEZAR, {}]]);
	const es = () => estado as EstadoSala;
	const g = juego();
	g.hands = [[[0, 1]], [[4, 5]], [[0, 0]], [[5, 5]]] as any;
	g.last_seat = 0;
	g.phase = "shop";
	g.last_result = { seat: 0, team: 0, pts: 20, reason: "tranque", bonus: [], capicua: false, tranque: { pips: [1, 9, 0, 10], teams: [1, 19], tie: false, opener: 0 } } as any;
	salaReloj(estado);
	vuelta();
	es().tq!.etapa = "visto";
	vuelta([[W1, OP_TRANQUE_OK, {}], [W2, OP_TRANQUE_OK, {}], [W3, OP_TRANQUE_OK, {}], [W4, OP_TRANQUE_OK, {}]]);
	vuelta();
	comprueba(es().tq!.etapa === "entregar", "tiempo de entregar: no empieza");
	esperar(T_TQ_ENTREGAR - 0.5);
	comprueba(es().tq!.entregadas.filter((x) => x).length === 1, "tiempo de entregar: se las lleva antes de los 6 s");
	const marcaW = enviados.length;
	esperar(1.0);
	comprueba(eventosDe("W1", marcaW, "arrebata").length === 3, "tiempo de entregar: no se las lleva las tres a la vez: " + eventosDe("W1", marcaW, "arrebata").length);
	vuelta();
	comprueba(es().tq!.etapa === "fin", "tiempo de entregar: no acaba tras llevárselas todas");
}

// ---------------------------------------------------------------- O11: nombre de equipo acordado por la pareja
{
	const J = presencia("J"), P = presencia("P2"), K = presencia("K");
	nuevaSala();
	entrar(J);
	entrar(P); // pareja de J (silla 2)
	entrar(K); // rival, con un bot de pareja
	const es = () => estado as EstadoSala;
	const sj = salaSillaDe(es(), "J"), sk = salaSillaDe(es(), "K");
	comprueba(sj % 2 !== sk % 2, "O11: J y K deberían ser rivales para esta prueba");
	vuelta([[J, OP_LISTO_SALA, { on: true }]]);
	comprueba(!es().listosSala![sj], "LISTO sin nombre de equipo aceptado");
	vuelta([[J, OP_EQUIPO, { name: "  Los Tigres!! del Norte" }]]);
	let n = ultimaVista("P2").nombres[0];
	comprueba(n.estado === "propuesto" && n.nombre === "Los Tigr" && n.propone === 2, "O11: P2 ve la propuesta de J: " + JSON.stringify(n));
	comprueba(igual(ultimaVista("J").equipos, ["", ""]), "O11: un nombre propuesto no sale aún en el marcador");
	vuelta([[J, OP_EQUIPO_RESP, { ok: true }]]);
	comprueba(ultimaVista("J").nombres[0].estado === "propuesto", "O11: quien propone no puede aceptarse a sí mismo");
	vuelta([[P, OP_EQUIPO_RESP, { ok: false }]]);
	n = ultimaVista("J").nombres[0];
	comprueba(n.estado === "vacio" && n.rechazado === "Los Tigr" && n.turno === 2, "O11: al rechazar le toca a P2: " + JSON.stringify(n));
	vuelta([[J, OP_EQUIPO, { name: "Otra vez" }]]);
	comprueba(ultimaVista("J").nombres[0].estado === "vacio", "O11: J propone cuando le toca a su pareja");
	vuelta([[P, OP_EQUIPO, { name: "Leones" }]]);
	vuelta([[J, OP_EQUIPO_RESP, { ok: true }]]);
	n = ultimaVista("P2").nombres[0];
	comprueba(n.estado === "aceptado" && n.nombre === "Leones", "O11: nombre aceptado por los dos: " + JSON.stringify(n));
	comprueba(igual(ultimaVista("J").equipos, ["Leones", ""]) && igual(ultimaVista("K").equipos, ["", "Leones"]), "O11: el aceptado sale en el marcador de todos");
	vuelta([[P, OP_EQUIPO, { name: "Cambio" }]]);
	comprueba(ultimaVista("J").equipos[0] === "Leones", "O11: un nombre aceptado se cambia");
	vuelta([[K, OP_EQUIPO, { name: "Ñañas" }]]);
	comprueba(igual(ultimaVista("J").equipos, ["Leones", "Ñañas"]), "O11: con un bot de pareja el nombre vale al momento: " + JSON.stringify(ultimaVista("J").equipos));
	comprueba(!salaDatosValidos(OP_EQUIPO, { name: 5 }) && !salaDatosValidos(OP_EQUIPO, { name: "x".repeat(33) }), "O11: datos de equipo no válidos admitidos");
	// LISTO y ¡A JUGAR!
	vuelta([[J, OP_LISTO_SALA, { on: true }], [K, OP_LISTO_SALA, { on: true }]]);
	comprueba(ultimaVista("J").listos_sala.filter((x: boolean) => x).length === 2 && !ultimaVista("J").todos_listos, "LISTO: 2 de 3 y no todos");
	vuelta([[J, OP_EMPEZAR, {}]]);
	comprueba(juego() === null, "LISTO: empieza sin que estén todos listos");
	vuelta([[P, OP_LISTO_SALA, { on: true }]]);
	comprueba(ultimaVista("J").todos_listos === true, "LISTO: todos listos no se ve");
	vuelta([[P, OP_EMPEZAR, {}]]);
	comprueba(juego() === null, "LISTO: empieza quien no es anfitrión");
	vuelta([[J, OP_EMPEZAR, {}]]);
	comprueba(juego() !== null, "LISTO: con todos listos el anfitrión no puede empezar");
	vuelta([[J, OP_EQUIPO, { name: "Otro" }]]);
	comprueba(igual(ultimaVista("J").equipos, ["Leones", "Ñañas"]), "O11: en partida no se cambia el nombre ni se pierde: " + JSON.stringify(ultimaVista("J").equipos));
}

// ---------------------------------------------------------------- cambio de silla en la sala de espera
{
	const H = presencia("H1"), M = presencia("M1"), N = presencia("N1");
	nuevaSala();
	entrar(H);
	const es = () => estado as EstadoSala;
	// solo: el anfitrión se pasa a la silla de un bot al momento
	vuelta([[H, OP_SILLA, { seat: 1 }]]);
	comprueba(salaSillaDe(es(), "H1") === 1, "silla libre: el anfitrión no se movió a la 1");
	comprueba(ultimaVista("H1").yo === 1, "silla libre: la vista no dice tu silla nueva");
	entrar(M); // ocupa la primera libre del orden
	const sm = salaSillaDe(es(), "M1");
	vuelta([[H, OP_EQUIPO, { name: "Uno" }]]);
	// H pide la silla de M: M tiene que aceptar
	let marcaS = enviados.length;
	vuelta([[H, OP_SILLA, { seat: (sm - 1 + 4) % 4 }]]);
	comprueba(es().peticion !== null && es().peticion!.a === sm, "petición: no se creó la petición a M");
	const pv = ultimaVista("M1").peticion;
	comprueba(pv !== null && pv.a === 0 && pv.secs === T_PETICION_SILLA, "petición: M no la ve dirigida a él: " + JSON.stringify(pv));
	comprueba(eventosDe("M1", marcaS, "silla_pide").length === 1, "petición: falta el aviso silla_pide");
	vuelta([[N, OP_SILLA_RESP, { ok: true }]]);
	vuelta([[H, OP_SILLA_RESP, { ok: true }]]);
	comprueba(salaSillaDe(es(), "H1") === 1, "petición: quien pide se acepta a sí mismo");
	vuelta([[M, OP_SILLA_RESP, { ok: false }]]);
	comprueba(salaSillaDe(es(), "H1") === 1 && es().peticion === null, "petición: rechazar no deja todo igual");
	vuelta([[H, OP_SILLA, { seat: (sm - 1 + 4) % 4 }]]);
	marcaS = enviados.length;
	vuelta([[M, OP_SILLA_RESP, { ok: true }]]);
	comprueba(salaSillaDe(es(), "H1") === sm && salaSillaDe(es(), "M1") === 1, "petición: aceptar no cambia las sillas");
	comprueba(eventosDe("H1", marcaS, "silla_cambio").length === 1, "petición: falta el aviso silla_cambio");
	// reglamento S4: el nombre aceptado es del equipo y se queda; una propuesta a medias de quien se fue se reinicia
	comprueba((es().nombres![1].estado === "aceptado" && es().equipos![1] === "Uno") || (es().nombres![1].estado === "vacio" && es().equipos![1] === ""), "al cambiar de pareja el nombre aceptado se queda en el equipo: " + JSON.stringify(es().nombres![1]));
	// la petición caduca
	vuelta([[H, OP_SILLA, { seat: (1 - sm + 4) % 4 }]]);
	marcaS = enviados.length;
	esperar(T_PETICION_SILLA + 0.5);
	comprueba(es().peticion === null && eventosDe("H1", marcaS, "silla_no").length === 1, "petición: no caduca a los 15 s");
	// en partida no hay cambios de silla
	todosListos(); vuelta([[H, OP_EMPEZAR, {}]]);
	const antes = salaSillaDe(es(), "H1");
	vuelta([[H, OP_SILLA, { seat: 1 }]]);
	comprueba(salaSillaDe(es(), "H1") === antes, "en partida se puede cambiar de silla");
	comprueba(!salaDatosValidos(OP_SILLA, { seat: 0 }) && !salaDatosValidos(OP_SILLA, { seat: 4 }) && !salaDatosValidos(OP_SILLA_RESP, { ok: 1 }), "datos de silla no válidos admitidos");
}

// ---------------------------------------------------------------- O02: «VOLVER A LA SALA» solo si se puede volver
{
	const V = presencia("V"), X = presencia("X");
	nuevaSala();
	entrar(V);
	vuelta([[V, OP_PERFIL, { name: "Vale" }]]);
	let señales: string[] = [];
	const nkViva = (existe: boolean) => ({
		matchList: (_l: number, _a: boolean, _x: any, _mi: any, _ma: any, q: string) => existe && q === "+label.code:abcdef" ? [{ matchId: "m1" }] : [],
		matchSignal: (_id: string, data: string) => { señales.push(data); return (salaSignal(ctxFalso, loggerFalso, nkFalso, dispatcherFalso, tick, estado, data) as any).data; },
	} as any as nkruntime.Nakama);
	const viva = (userId: string, existe = true, code = "ABCDEF") =>
		JSON.parse(rpcSalaViva({ userId: userId } as any, loggerFalso, nkViva(existe), JSON.stringify({ code: code })) as string).viva;
	comprueba(viva("V") === true, "O02: quien está en la sala puede volver");
	comprueba(viva("X") === true, "O02: sala esperando con sitio: se puede entrar");
	comprueba(viva("V", false) === false, "O02: sala que ya no existe no se ofrece");
	comprueba(viva("V", true, "abc") === false, "O02: código no válido");
	todosListos(); vuelta([[V, OP_EMPEZAR, {}]]);
	salir(V);
	comprueba(viva("V") === true, "O02: en partida, quien se fue conserva su silla y puede volver");
	comprueba(viva("X") === false, "O02: en partida, otra cuenta no puede entrar");
	comprueba(señales.every((d) => JSON.parse(d).silla !== undefined), "O02: la señal solo pregunta por la silla");
	comprueba((salaSignal(ctxFalso, loggerFalso, nkFalso, dispatcherFalso, tick, estado, "{rota") as any).data === "", "O02: señal rota no responde");
	void X;
}

// ---------------------------------------------------------------- armas (2026-10-11)
{
	// en una sala pública nunca hay armas, aunque se pidan
	comprueba(salaInit(ctxFalso, loggerFalso, nkFalso, { code: "PUBLIC", publica: true, armas: true }).state.armas === false, "armas en sala pública");
	const A = presencia("A1"), B = presencia("B1");
	enviados = [];
	tick = 0;
	estado = salaInit(ctxFalso, loggerFalso, nkFalso, { code: "ARMAS1", armas: true }).state;
	entrar(A);
	entrar(B); // B es la silla 2
	vuelta([[A, OP_PERFIL, { name: "Ana" }], [B, OP_PERFIL, { name: "Beto" }]]);
	todosListos(); vuelta([[A, OP_EMPEZAR, {}]]);
	let gd = 0;
	while (juego().phase !== "play" && gd++ < 500) vueltaAtentos([[A, 0], [B, 2]]);
	const ea = () => estado as EstadoSala;
	comprueba(juego().phase === "play" && ultimaVista("A1").armas === true, "la sala con armas no lo dice en la vista");
	// sin balas no se dispara
	vuelta([[A, OP_POSE, { st: 1 }]]);
	vuelta([[A, OP_POSE, { st: 2, x: 0, z: 1.5, yaw: 0 }]]);
	const o = [0, 1.6, 1.5];
	const hacia = (c: number[]) => { const v = [c[0] - o[0], c[1] - o[1], c[2] - o[2]]; const l = Math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]); return v.map((x) => x / l); };
	const aB = hacia([0, 1.05, -1.02]); // B sentado en la silla 2 (para A, delante)
	vuelta([[A, OP_DISPARO, { o: o, n: aB, target: 2, zona: "pecho" }]]);
	comprueba(ea().vida![2] === 100, "se dispara sin balas");
	vuelta([[A, OP_BALAS, { n: 99, arma: "pistola" }]]);
	comprueba(ea().balas![0] === 0, "OP_BALAS fuera de rango aceptado");
	vuelta([[A, OP_BALAS, { n: 4, arma: "pistola" }]]);
	comprueba(ea().balas![0] === 4 && ultimaVista("A1").balas === 4, "balas no guardadas");
	let marca = enviados.length;
	vuelta([[A, OP_DISPARO, { o: o, n: aB, target: 2, zona: "pecho" }]]);
	const ev = eventosDe("B1", marca, "disparo");
	comprueba(ea().vida![2] === 66 && ea().balas![0] === 3, "tiro al pecho mal: " + JSON.stringify(ea().vida));
	comprueba(ev.length === 1 && ev[0].seat === 2 && ev[0].target === 0 && ev[0].zona === "pecho", "a B no le llega bien el disparo: " + JSON.stringify(ev));
	comprueba(Array.isArray(ev[0].o) && Math.abs(ev[0].o[2] + 1.5) < 0.01, "el origen del tiro no llega girado a B: " + JSON.stringify(ev[0].o));
	// tiro desviado: gasta la bala y no hace daño aunque diga que tocó
	vuelta([[A, OP_DISPARO, { o: o, n: [1, 0, 0], target: 2, zona: "cabeza" }]]);
	comprueba(ea().vida![2] === 66 && ea().balas![0] === 2, "tiro desviado hace daño o no gasta bala");
	// desde lejos de donde estás: no vale
	vuelta([[A, OP_DISPARO, { o: [2, 1.6, -1], n: aB, target: 2, zona: "cabeza" }]]);
	comprueba(ea().vida![2] === 66 && ea().balas![0] === 1, "tiro desde otro sitio aceptado");
	// cabeza: muere; el turno de B espera y B no puede jugar
	juego().turn = 2;
	vuelta([[A, OP_DISPARO, { o: o, n: hacia([0, 1.5, -1.02]), target: 2, zona: "cabeza" }]]);
	comprueba(ea().muerto![2] === true && ea().vida![2] === 0 && ea().balas![0] === 0, "el tiro a la cabeza no mata");
	comprueba(ultimaVista("B1").muertos[0] === true && ultimaVista("A1").muertos[2] === true, "la vista no dice quién está muerto");
	const quedaba = ea().deadline - ea().tick;
	esperar(5);
	comprueba(juego().turn === 2 && ea().deadline - ea().tick >= quedaba - 1, "el turno del muerto no espera");
	const jugadas = rJugadas(juego(), 2);
	if (jugadas.length > 0) {
		vuelta([[B, OP_JUGAR, { tile: [jugadas[0].tile[0], jugadas[0].tile[1]], side: jugadas[0].side }]]);
		comprueba(juego().turn === 2, "un muerto puede jugar");
	}
	vuelta([[B, OP_POSE, { st: 2, x: 0, z: 0, yaw: 0 }]]);
	comprueba(ea().poses[2].st === 0, "un muerto se mueve");
	// vuelve: de pie en el suelo donde cayó, tumbado un momento
	marca = enviados.length;
	vuelta([[B, OP_REVIVIR, {}]]);
	comprueba(ea().muerto![2] === false && ea().vida![2] === 100 && ea().poses[2].st === 2 && ea().caidoHasta[2] > ea().tick, "revivir mal: " + JSON.stringify(ea().poses[2]));
	comprueba(Math.abs(ea().poses[2].z + 1.7) < 0.01, "no aparece donde cayó: " + JSON.stringify(ea().poses[2]));
	comprueba(eventosDe("A1", marca, "revive").length === 1, "A no ve que B vuelve");
	// un bot muerto vuelve solo a los 8 s
	vuelta([[A, OP_BALAS, { n: 2, arma: "revolver" }]]);
	esperar(1);
	vuelta([[A, OP_POSE, { st: 2, x: 0, z: 1.2, yaw: 0, a: true }]]);
	comprueba(ea().poses[0].st !== 2 || ea().poses[0].a === true, "el servidor no guarda que A va armado: " + JSON.stringify(ea().poses[0]));
	comprueba(salaVista(ea(), 0, []).armas_de[0] === "revolver" && salaVista(ea(), 1, []).armas_de[3] === "revolver", "los demás no ven el revólver de A: " + JSON.stringify(salaVista(ea(), 1, []).armas_de));
	vuelta([[A, OP_DISPARO, { o: o, n: hacia([1.02, 1.5, 0]), target: 1, zona: "cabeza" }]]);
	comprueba(ea().muerto![1] === true, "no muere el bot de la silla 1");
	esperar(T_BOT_VUELVE + 0.5);
	comprueba(ea().muerto![1] === false && ea().vida![1] === 100, "el bot no vuelve");
}

console.log("SALA " + pruebasSala + " comprobaciones");
console.log(fallosSala === 0 ? "SALA SIN FALLOS" : fallosSala + " FALLOS EN LA SALA");
if (fallosSala > 0) process.exit(1);
