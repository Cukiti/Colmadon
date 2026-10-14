// Salas con código y partida autoritativa: el servidor guarda la mesa, valida
// cada jugada, mueve a los bots y manda a cada jugador solo lo que puede ver.
// Cada jugador recibe la mesa «girada» para que él sea siempre la silla 0
// (así el cliente funciona igual que en la partida local).

const SALA_TICK = 5; // vueltas por segundo
const OP_PERFIL = 1, OP_EMPEZAR = 2, OP_CARTA = 10, OP_ROBAR = 11, OP_JUGAR = 12, OP_PASAR = 13;
const OP_PASAR_CON_FICHA = 14, OP_CANTAR = 15, OP_BEBER = 16, OP_COMPRAR = 17, OP_LISTO = 18, OP_REVANCHA = 19;
const OP_FRASE = 20; // chat rápido: {id} de la lista cerrada SALA_FRASES
const OP_POSE = 21, OP_EMOTE = 22, OP_TAPAR = 23; // de pie: posición, emotes y tapar fichas
const OP_MANO = 24;
const OP_AQUI = 25;
const OP_TRANQUE_OK = 28; // «visto» en la pantalla del tranque (cuando todos lo dan, se cierra)
const OP_EQUIPO = 31; // sala de espera: propones el nombre de tu pareja {name} (máx. SALA_EQUIPO_MAX letras)
const OP_LISTO_SALA = 32; // sala de espera: {on} estás listo (hace falta el nombre de tu pareja aceptado)
const OP_SILLA = 33; // sala de espera: {seat} (silla local) quieres sentarte ahí; si es de una persona, se lo pide
const OP_SILLA_RESP = 34; // sala de espera: {ok} respuesta a quien te pidió tu silla
const OP_REVELAR = 36; // tranque: {idx} giras tu ficha número idx (en tu turno de revelar)
const OP_AMAGO = 37; // tranque: {idx} amagas (levantas la ficha y la vuelves a bajar)
const OP_ENTREGAR = 38; // tranque: entregas tus fichas al ganador
const OP_ARREBATAR = 39; // tranque: el ganador le quita las fichas a {seat} (silla local)
const OP_EQUIPO_RESP = 35;
const OP_PRUEBA_TRANQUE = 99; // solo con COLMADON_PRUEBAS=1 (servidor local): tranca la mano ya // sala de espera: {ok} te gusta (o no) el nombre que propuso tu pareja
const OP_RADIO = 30; // tocar la radio del colmado: siguiente pista y, tras la última, apagada
const OP_CUENTA = 29; // quien ganó cuenta a mano: {tile: [a, b]} la ficha que toca, o {all: true}
const OP_GOLPE = 27; // de pie: manotazo a otra persona de pie y cerca {target: silla local, run: venía corriendo}
const T_GOLPE = 2, T_CAIDO = 3, T_DOBLE_GOLPE = 3, T_ABUSO = 10; // segundos
const OP_REVISAR = 26; // «¡Ute va!»: {tile: [a, b]} la que sí iba, o {none: true} «No llevaba»
// armas (solo en salas privadas que las activen): tiro validado por el servidor
const OP_DISPARO = 40; // {o: [x,y,z], n: [x,y,z]} (tus coordenadas) y, si tocaste a alguien, {target: silla local, zona}
const OP_REVIVIR = 41; // muerto: «Volver al colmado» (apareces en el suelo donde caíste)
const OP_VERIFICAR = 43; // V1: dominó/capicúa: {ok: true} VISTO o {reclamar: true}
const OP_BALAS = 42; // {n, arma}: balas que traes (compradas con pesos) y el arma elegida
const SALA_ARMAS: { [id: string]: { dano: { [z: string]: number }; cad: number } } = {
	pistola: { dano: { cabeza: 100, pecho: 34, brazo: 20, pierna: 20 }, cad: 1 },
	revolver: { dano: { cabeza: 100, pecho: 50, brazo: 25, pierna: 25 }, cad: 4 },
};
const SALA_MAX_BALAS = 12;
const T_MUERTO = 90; // segundos que espera el turno de un muerto (luego juega su bot)
const T_BOT_VUELVE = 8; // un bot muerto vuelve a su silla a los 8 s
const T_REVISION = 25; // segundos para revisar las fichas del acusado // «estoy aquí»: el ausente tocó la pantalla o movió el ratón // lo que hace con sus fichas: {st: 0 nada, 1 las mira, 2 una en la mano, 3 la lleva a una punta; side: -1/0/1}
const OP_SALA = 100, OP_ESTADO = 101, OP_AVISO = 102, OP_POSES = 103, OP_MANOS = 104;
const OP_CUENTAS = 105; // la cuenta de quien ganó, para los demás: {seat (ya girada), tile | all}

// de pie (coordenadas del suelo de la vista 3D, en sillas del servidor)
const T_LEVANTARSE = 2.4; // lo que tarda en ponerse de pie: hasta entonces no ve nada
const SALA_EMOTES = ["dance", "clap", "point", "wave", "stretch", "shove", "choca", "brindis", "mesazo"];
const SALA_SALA = { x0: -2.9, x1: 2.9, z0: -2.1, z1: 2.25 }; // paredes del colmado
const BOT_TAPA = 0.85; // probabilidad de que un bot tape sus fichas al ver a alguien de pie

// tiempos (segundos)
const T_CARTA = 30, T_ROBAR = 25, T_TURNO = 30, T_TIENDA = 45;
const T_BOT_TURNO = 0.75, T_BOT_ROBO = 0.3, T_BOT_CARTA = 1.2;
const SALA_VACIA_SEG = 120; // sin nadie conectado, la sala se cierra
const SALA_EQUIPO_MAX = 8; // letras del nombre de equipo (O11)
const T_PETICION_SILLA = 15; // segundos para aceptar un cambio de silla (si no, se rechaza)
const SALA_SOLO_BOTS_SEG = 60; // en partida sin ninguna persona: los bots no siguen y se cierra antes
const T_FRASE = 3; // como mucho una frase cada 3 s por jugador
const SALA_MAX_MENSAJE = 2048; // bytes, antes de convertir/parsear JSON
const SALA_MAX_POR_TICK = 12; // por presencia: también cuenta mensajes inválidos
const T_AVISO_ENTRADA = 3; // «joined» espera al perfil (nombre) como mucho 3 s
const FALLOS_PARA_AUSENTE = 1; // un tiempo agotado y queda ausente (2026-10-04)
const T_TQ_INTRO = 2.5; // tranque: la cámara sube y se ven las fichas boca abajo
const T_TQ_TURNO = 8; // tranque: sin tocar nada en tu turno de revelar, se giran solas
const T_TQ_AUTO = 0.9; // tranque: una ficha cada tanto cuando se giran solas
const T_TQ_BOT = 1.1; // tranque: ritmo de los bots
const T_TQ_ENTRE = 2.5; // tranque: pausa entre el turno de uno y el siguiente
const T_TQ_MIN = 0.35;
const T_TQ_FINAL = 3; // tranque: tras la última ficha (cámara lenta), pausa antes de anunciar al ganador // tranque: mínimo entre dos fichas de la misma persona
const T_VER = 20; // V1: verificar el dominó o la capicúa (o hasta que todos den VISTO)
const T_VER_RECLAMO = 6; // al reclamar, el colmadero enseña la jugada este tiempo más
const T_TQ_ENTREGAR = 10; // tranque: para entregar o arrebatar; luego el ganador las toma todas a la vez
const T_TRANQUE = 30; // la pantalla del tranque: 30 s (o hasta que todos la den por vista); la tienda dura eso más
const T_CONGELADO = 60; // de pie en su turno: su reloj se para como mucho 60 s (luego sigue y, si se acaba, juega su bot)
const T_AUSENTE = 5; // ausente: sus turnos duran 5 s y luego juega su bot (vuelve con cualquier toque)

// chat rápido: solo estas frases (sin texto libre, así no hay que moderar)
const SALA_FRASES: { [id: string]: string } = {
	capicua: "¡Capicúa!",
	pasate: "¡Pásate, compai!",
	chivo_visto: "Ese chivo te lo vi",
	buena: "¡Buena jugada!",
	ay: "¡Ay, mi madre!",
	tranque: "Esto se tranca",
	bebe: "¡Échate un trago!",
	gracias: "Gracias, compai",
};

interface Silla {
	userId: string | null; // null = bot
	name: string;
	avatar: any;
	presence: nkruntime.Presence | null; // null = desconectado
}

interface EstadoSala {
	entrada?: { tick: number; total: number; ops: { [op: string]: number } }[];
	code: string;
	publica: boolean;
	host: string;
	seats: Silla[];
	game: Estado | null;
	deadline: number; // tick en que se acaba el tiempo de la fase o del turno
	botWait: number; // tick a partir del cual puede actuar el siguiente bot
	listos: boolean[]; // tienda: quién pulsó «siguiente mano»
	revFin: number; // tick en que se acaba la revisión de un «¡Ute va!» (0 = no hay)
	golpeListo: number[]; // tick desde el que cada silla puede volver a golpear
	golpesDe: number[][]; // ticks de los golpes recientes de cada silla (abuso)
	golpeadoEn: number[]; // tick del último golpe recibido por cada silla (dos seguidos: al suelo)
	caidoHasta: number[]; // tick hasta el que cada silla está en el suelo
	revancha: boolean[];
	tick: number;
	vaciaDesde: number;
	faseVista: string; // fase/turno del reloj actual: si cambia, el reloj se reinicia
	turnosVistos: number; // jugadas y pases contados (cada uno abre un turno nuevo)
	eventosVistos: number; // eventos de la partida ya revisados por salaReloj
	total: number; // segundos totales de la fase o del turno actual (turn_deadline_secs)
	congelado: number; // ticks que lleva parado el reloj de este turno (le toca y está de pie)
	tranqueOk: boolean[]; // pantalla del tranque: quién la dio por vista
	paradoVisto: boolean; // lo último que se mandó de reloj_parado (si cambia, se manda la vista)
	ausente: boolean[]; // se le acabó el tiempo: sus turnos duran T_AUSENTE y luego juega su bot
	fallosTiempo: number[]; // veces seguidas que se le acabó el tiempo
	ultimaFrase: number[]; // tick de la última frase de cada silla
	radio?: { on: boolean; pista: number; inicio: number; ultimo: number }; // Colmadón FM de la sala
	porAnunciar: number[]; // tick límite para anunciar «joined» (0 = nada pendiente)
	avisos: Evento[]; // eventos de la sala (joined, left, back, frase) para la próxima vista
	modo: string; // aumentos o clasico (lo elige quien crea la sala)
	meta: number; // 100 o 200 (lo elige quien crea la sala)
	poses: Pose[]; // de pie o sentado, por silla (coordenadas del servidor)
	tapado: boolean[]; // fichas tapadas (contra quien mira de pie)
	tapaEn: number[]; // bots: tick en que tapan (0 = nada pendiente)
	posesCambio: boolean; // hay poses nuevas que mandar
	miradas: string; // quién ve las fichas de quién (si cambia, se reenvía la mesa)
	equipos?: string[]; // nombre ACEPTADO de cada pareja (sillas pares e impares); "" = NOSOTROS/ELLOS
	nombres?: NombreEquipo[]; // sala de espera: negociación del nombre de cada pareja
	listosSala?: boolean[]; // sala de espera: quién pulsó LISTO
	peticion?: PeticionSilla | null; // un cambio de silla esperando respuesta
	ver?: { mano: number; hasta: number; ok: boolean[]; reclamo: number; fin: boolean } | null; // V1
	tq?: TranqueSala | null; // tranque con suspenso: revelar por turnos, visto y entregar
	pruebas?: boolean; // servidor local de pruebas: admite OP_PRUEBA_TRANQUE
	armas?: boolean; // la sala permite armas (lo elige quien la crea; nunca en públicas)
	vida?: number[];
	muerto?: boolean[];
	muertoDesde?: number[];
	cuerpo?: number[][]; // dónde quedó tirado cada muerto (x, z del servidor)
	balas?: number[];
	armaDe?: string[];
	disparoListo?: number[];
}

interface TranqueSala {
	mano: number; // mano del tranque
	etapa: string; // "revelar" | "visto" | "entregar" | "fin"
	orden: number[]; // turnos de revelar (empieza quien trancó)
	i: number; // a quién le toca en orden
	rev: number[][]; // índices de fichas ya giradas de cada silla
	auto: number; // tick de la próxima acción automática
	hasta: number; // tick en que se acaba el tiempo del paso actual
	entregadas: boolean[]; // fichas que ya están con el ganador
	ganador: number;
	scoresAntes: number[]; // marcador sin la mano del tranque (mientras se revela)
	amagoBot?: boolean;
	finEn?: number; // tick desde el que se puede anunciar al ganador (tras la última ficha)
}

interface NombreEquipo {
	estado: string; // "vacio" | "propuesto" | "aceptado"
	nombre: string; // lo propuesto o lo aceptado
	propone: number; // silla que lo propuso (-1 = nadie)
	turno: number; // silla a la que le toca proponer (-1 = cualquiera de la pareja)
	rechazado: string; // el último nombre que no gustó (se enseña tachado)
	humanos: string; // quiénes forman la pareja (si cambia, se negocia de nuevo)
}

interface PeticionSilla {
	de: number; // silla que pide
	a: number; // silla pedida (de una persona)
	hasta: number; // tick en que caduca
}

interface Pose {
	st: number; // 0 sentado, 1 levantándose, 2 de pie
	x: number;
	z: number;
	yaw: number;
	pitch: number; // cabeceo de la mirada (para mover su cabeza)
	desde: number; // tick en que empezó a levantarse
	hy?: number; // sentado: giro de la cabeza (modo cámara)
	hp?: number; // sentado: cabeceo de la cabeza
	a?: boolean; // de pie con el arma en la mano (solo en salas con armas)
}

const SALA_ORDEN = [0, 2, 1, 3];
// cada bot tiene siempre el mismo nombre y la misma cara (según su silla real)
const SALA_BOT_NOMBRE = ["Tato", "Yeya", "Don Fello", "Chichí"];
const SALA_BOT_CARA = ["rafa", "yeya", "fello", "chichi"];
const SALA_LETRAS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // sin 0/O ni 1/I

function salaCodigo(): string {
	let c = "";
	for (let i = 0; i < 6; i++) c += SALA_LETRAS.charAt(Math.floor(Math.random() * SALA_LETRAS.length));
	return c;
}

function salaRot(s: number, yo: number): number {
	return (s - yo + 4) % 4;
}

function salaEtiqueta(e: EstadoSala): string {
	let n = 0;
	for (const s of e.seats) if (s.userId !== null && s.presence !== null) n++;
	const host = salaSillaDe(e, e.host);
	return JSON.stringify({ code: e.code.toLowerCase(), publica: e.publica === true,
		open: n < 4, players: n, anfitrion: host < 0 ? "" : salaNombre(e, host),
		modo: e.modo, meta: e.meta, estado: e.game === null ? "esperando" : "jugando",
		mano: e.game === null ? 0 : e.game.hand_no });
}

/**
 * Entre vueltas, Nakama guarda el estado en su formato interno: modificar sus
 * listas (push, splice…) cambia una copia que se pierde. Por eso cada
 * llamada trabaja sobre una copia en JavaScript normal y la devuelve.
 */
function salaCopia(state: nkruntime.MatchState): EstadoSala {
	const e = JSON.parse(JSON.stringify(state)) as EstadoSala;
	if (!e.poses) {
		e.poses = [0, 1, 2, 3].map(() => salaPoseSentada());
		e.tapado = [false, false, false, false];
		e.tapaEn = [0, 0, 0, 0];
		e.posesCambio = false;
		e.miradas = "";
	}
	return e;
}

function salaSillaDe(e: EstadoSala, userId: string): number {
	for (let i = 0; i < 4; i++) if (e.seats[i].userId === userId) return i;
	return -1;
}

/** Silla sin persona (vacía o desconectada): su bot juega a su ritmo. */
function salaEsBot(e: EstadoSala, s: number): boolean {
	return e.seats[s].userId === null || e.seats[s].presence === null;
}

/** Persona conectada pero ausente: tiene T_AUSENTE por turno (luego juega su bot). */
function salaAusente(e: EstadoSala, s: number): boolean {
	return e.ausente[s] && !salaEsBot(e, s);
}

/** Tick en que empezó la fase o el turno de ahora. */
function salaInicio(e: EstadoSala): number {
	return e.deadline - e.total * SALA_TICK;
}

/** Nombre para los avisos (quien no mandó su perfil sale como «Jugador»). */
function salaNombre(e: EstadoSala, s: number): string {
	return e.seats[s].name || "Jugador";
}

/** Evento de la sala para todos (la silla se gira en la vista de cada uno). */
function salaAviso(e: EstadoSala, k: string, s: number, extra?: any): void {
	const ev: Evento = { k: k, seat: s };
	if (extra) for (const c in extra) ev[c] = extra[c];
	e.avisos.push(ev);
}

/** Vuelve a jugar él (y no su bot) tras quedarse ausente. */
function salaQuitarAusente(e: EstadoSala, s: number): boolean {
	e.fallosTiempo[s] = 0;
	if (!e.ausente[s]) return false;
	e.ausente[s] = false;
	if (e.game !== null) {
		e.game.bot[s] = e.seats[s].userId === null || e.seats[s].presence === null;
		// vuelve en su turno: tiempo normal desde ya
		if (e.game.phase === "play" && e.game.turn === s) {
			e.deadline = e.tick + T_TURNO * SALA_TICK;
			e.total = T_TURNO;
		}
	}
	return true;
}

/** Se le acabó el tiempo a una persona: a la segunda seguida queda ausente. */
function salaFalloTiempo(e: EstadoSala, s: number): void {
	if (salaEsBot(e, s) || e.ausente[s]) return;
	e.fallosTiempo[s] += 1;
	if (e.fallosTiempo[s] >= FALLOS_PARA_AUSENTE) {
		e.ausente[s] = true;
		if (e.game !== null) e.game.bot[s] = true;
	}
}

// ---------------------------------------------------------------- RPC

const rpcCrearSala: nkruntime.RpcFunction = function (ctx, logger, nk, payload) {
	let modo = "aumentos";
	let meta = 100;
	let publica = false;
	let armas = false;
	try {
		const d = JSON.parse(payload || "{}");
		if (d.modo === "clasico") modo = "clasico";
		if (Number(d.meta) === 200) meta = 200;
		publica = d.publica === true;
		armas = d.armas === true && !publica;
	} catch (err) {
		modo = "aumentos";
	}
	let code = salaCodigo();
	for (let i = 0; i < 5; i++) {
		if (nk.matchList(1, true, null, null, null, "+label.code:" + code.toLowerCase()).length === 0) break;
		code = salaCodigo();
	}
	const matchId = nk.matchCreate("colmadon", { code: code, modo: modo, meta: meta, publica: publica, armas: armas });
	logger.info("Sala " + code + " creada por " + ctx.userId);
	return JSON.stringify({ code: code, match_id: matchId });
};

const rpcUnirseSala: nkruntime.RpcFunction = function (ctx, logger, nk, payload) {
	let code = "";
	try {
		code = String(JSON.parse(payload).code || "").toUpperCase().replace(/[^A-Z0-9]/g, "");
	} catch (err) {
		throw Error("código no válido");
	}
	if (code.length !== 6) throw Error("el código tiene 6 letras");
	const salas = nk.matchList(1, true, null, null, null, "+label.code:" + code.toLowerCase());
	if (salas.length === 0) return JSON.stringify({ error: "No hay ninguna sala con ese código" });
	return JSON.stringify({ code: code, match_id: salas[0].matchId });
};

/**
 * O02: «VOLVER A LA SALA» solo si la sala sigue y esta cuenta puede volver.
 * Responde {viva}; nunca dice nada de las demás sillas.
 */
const rpcSalaViva: nkruntime.RpcFunction = function (ctx, logger, nk, payload) {
	let code = "";
	try {
		code = String(JSON.parse(payload || "{}").code || "").toUpperCase().replace(/[^A-Z0-9]/g, "");
	} catch (err) {
		return JSON.stringify({ viva: false });
	}
	if (code.length !== 6) return JSON.stringify({ viva: false });
	const salas = nk.matchList(1, true, null, null, null, "+label.code:" + code.toLowerCase());
	if (salas.length === 0) return JSON.stringify({ viva: false });
	let r: any = null;
	try { r = JSON.parse(nk.matchSignal(salas[0].matchId, JSON.stringify({ silla: ctx.userId || "" })) || "{}"); } catch (_) { r = null; }
	return JSON.stringify({ viva: !!(r && r.puede === true) });
};

// ---------------------------------------------------------------- partida

const rpcListarSalas: nkruntime.RpcFunction = function (ctx, logger, nk, payload) {
	let d: any;
	try { d = JSON.parse(payload || "{}"); } catch (_) { throw Error("Filtros no válidos"); }
	if (!d || typeof d !== "object" || Array.isArray(d)) throw Error("Filtros no válidos");
	let query = "+label.publica:T";
	// Solo valores cerrados: nunca concatenar texto libre a la consulta.
	if (d.modo === "clasico" || d.modo === "aumentos") query += " +label.modo:" + d.modo;
	if (d.meta === 100 || d.meta === 200) query += " +label.meta:" + d.meta;
	if (d.solo_libres === true) query += " +label.open:T";
	if (d.estado === "esperando" || d.estado === "jugando") query += " +label.estado:" + d.estado;
	const salas: any[] = [];
	for (const match of nk.matchList(50, true, null, null, null, query)) {
		let l: any;
		try { l = JSON.parse(match.label || "{}"); } catch (_) { continue; }
		// También comprobar privacidad al serializar, incluso ante etiquetas antiguas.
		if (!l || l.publica !== true) continue;
		if ((d.modo === "clasico" || d.modo === "aumentos") && l.modo !== d.modo) continue;
		if ((d.meta === 100 || d.meta === 200) && l.meta !== d.meta) continue;
		if (d.solo_libres === true && l.open !== true) continue;
		if ((d.estado === "esperando" || d.estado === "jugando") && l.estado !== d.estado) continue;
		salas.push({ code: String(l.code).toUpperCase(), anfitrion: l.anfitrion,
			modo: l.modo, meta: l.meta, jugadores: l.players, estado: l.estado,
			mano: l.mano, puede_entrar: l.open === true && l.estado === "esperando" });
	}
	salas.sort((a, b) => (a.estado === b.estado ? 0 : a.estado === "esperando" ? -1 : 1)
		|| b.jugadores - a.jugadores || (a.code < b.code ? -1 : a.code > b.code ? 1 : 0));
	return JSON.stringify({ salas: salas.slice(0, 50) });
};

const salaInit: nkruntime.MatchInitFunction<EstadoSala> = function (ctx, logger, nk, params) {
	const e: EstadoSala = {
		code: String(params.code || salaCodigo()),
		publica: params.publica === true,
		host: "",
		seats: [0, 1, 2, 3].map(() => ({ userId: null, name: "", avatar: null, presence: null } as Silla)),
		game: null,
		deadline: 0,
		botWait: 0,
		listos: [false, false, false, false],
		revFin: 0,
		golpeListo: [0, 0, 0, 0],
		golpesDe: [[], [], [], []],
		golpeadoEn: [-9999, -9999, -9999, -9999],
		caidoHasta: [0, 0, 0, 0],
		revancha: [false, false, false, false],
		tick: 0,
		vaciaDesde: 0,
		faseVista: "",
		turnosVistos: 0,
		eventosVistos: 0,
		total: 0,
		congelado: 0,
		paradoVisto: false,
		tranqueOk: [false, false, false, false],
		ausente: [false, false, false, false],
		fallosTiempo: [0, 0, 0, 0],
		ultimaFrase: [-9999, -9999, -9999, -9999],
		radio: { on: true, pista: 0, inicio: 0, ultimo: -9999 },
		porAnunciar: [0, 0, 0, 0],
		avisos: [],
		modo: params.modo === "clasico" ? "clasico" : "aumentos",
		meta: Number(params.meta) === 200 ? 200 : 100,
		armas: params.armas === true && params.publica !== true,
		vida: [100, 100, 100, 100],
		muerto: [false, false, false, false],
		muertoDesde: [0, 0, 0, 0],
		cuerpo: [[0, 0], [0, 0], [0, 0], [0, 0]],
		balas: [0, 0, 0, 0],
		armaDe: ["pistola", "pistola", "pistola", "pistola"],
		disparoListo: [0, 0, 0, 0],
		poses: [0, 1, 2, 3].map(() => salaPoseSentada()),
		tapado: [false, false, false, false],
		tapaEn: [0, 0, 0, 0],
		posesCambio: false,
		miradas: "",
		equipos: ["", ""],
		nombres: [salaNombreVacio(), salaNombreVacio()],
		listosSala: [false, false, false, false],
		peticion: null,
		pruebas: !!(ctx.env && ctx.env["COLMADON_PRUEBAS"] === "1"),
	};
	return { state: e, tickRate: SALA_TICK, label: salaEtiqueta(e) };
};

const salaJoinAttempt: nkruntime.MatchJoinAttemptFunction<EstadoSala> = function (ctx, logger, nk, dispatcher, tick, state, presence, metadata) {
	const e = salaCopia(state);
	if (salaSillaDe(e, presence.userId) >= 0) return { state: e, accept: true }; // vuelve a su silla
	if (e.game !== null) return { state: e, accept: false, rejectMessage: "La partida ya empezó" };
	for (let i = 0; i < 4; i++) if (e.seats[i].userId === null) return { state: e, accept: true };
	return { state: e, accept: false, rejectMessage: "La sala está llena" };
};

const salaJoin: nkruntime.MatchJoinFunction<EstadoSala> = function (ctx, logger, nk, dispatcher, tick, state, presences) {
	const e = salaCopia(state);
	e.tick = tick;
	for (const pr of presences) {
		let s = salaSillaDe(e, pr.userId);
		if (s >= 0) {
			// vuelve a su silla (misma cuenta): recupera fichas, cartas y turno
			if (e.seats[s].presence === null && e.porAnunciar[s] === 0) salaAviso(e, "back", s, { name: salaNombre(e, s) });
		} else {
			// el anfitrión en la 0; el primer amigo es su compañero (2); luego rivales
			for (const i of SALA_ORDEN) {
			if (e.seats[i].userId === null) {
					s = i;
					break;
				}
			}
			if (s < 0) continue;
			// en partida, ocupa la silla de un bot desde ya
			// el nombre llega con el perfil (OP_PERFIL); hasta entonces, vacío
			e.seats[s] = { userId: pr.userId, name: "", avatar: null, presence: pr };
			// «joined» sale cuando llega su nombre (OP_PERFIL) o, si no, a los 3 s
			e.porAnunciar[s] = tick + T_AVISO_ENTRADA * SALA_TICK;
		}
		e.seats[s].presence = pr;
		e.ausente[s] = false;
		e.fallosTiempo[s] = 0;
		if (e.host === "") e.host = pr.userId;
		if (e.game !== null) e.game.bot[s] = false;
		else {
			salaListos(e)[s] = false; // el que entra tiene que marcar LISTO
			salaRevisarParejas(e);
		}
	}
	dispatcher.matchLabelUpdate(salaEtiqueta(e));
	salaEnviarTodo(e, dispatcher, nk);
	return { state: e };
};

const salaLeave: nkruntime.MatchLeaveFunction<EstadoSala> = function (ctx, logger, nk, dispatcher, tick, state, presences) {
	const e = salaCopia(state);
	e.tick = tick;
	for (const pr of presences) {
		const s = salaSillaDe(e, pr.userId);
		if (s < 0) continue;
		// sesión vieja que se cierra después de que la cuenta ya volvió con otra
		const actual = e.seats[s].presence;
		if (actual === null || actual.sessionId !== pr.sessionId) continue;
		if (e.porAnunciar[s] === 0) salaAviso(e, "left", s, { name: salaNombre(e, s) });
		e.porAnunciar[s] = 0;
		e.ausente[s] = false;
		e.fallosTiempo[s] = 0;
		e.poses[s] = salaPoseSentada();
		e.posesCambio = true;
		if (e.game === null) {
			// en el vestíbulo se libera la silla
			e.seats[s] = { userId: null, name: "", avatar: null, presence: null };
			salaListos(e)[s] = false;
			const pe = e.peticion;
			if (pe && (pe.de === s || pe.a === s)) e.peticion = null;
			salaRevisarParejas(e);
		} else {
			// en partida juega un bot hasta que vuelva
			e.seats[s].presence = null;
			e.game.bot[s] = true;
		}
		if (e.host === pr.userId) {
			e.host = "";
			for (const o of e.seats) if (o.presence !== null && o.userId !== null) {
				e.host = o.userId;
				break;
			}
		}
	}
	dispatcher.matchLabelUpdate(salaEtiqueta(e));
	salaEnviarTodo(e, dispatcher, nk);
	return { state: e };
};

const salaLoop: nkruntime.MatchLoopFunction<EstadoSala> = function (ctx, logger, nk, dispatcher, tick, state, messages) {
	const e = salaCopia(state);
	e.tick = tick;
	let cambio = false;
	for (const m of messages) {
		const s = salaSillaDe(e, m.sender.userId);
		if (s < 0 || e.seats[s].presence === null || e.seats[s].presence!.sessionId !== m.sender.sessionId) continue;
		if (!salaAdmitir(e, s, m.opCode)) continue;
		let datos: any = {};
		try {
			if (m.data === null || m.data === undefined || (typeof m.data !== "string" && m.data.byteLength > SALA_MAX_MENSAJE)) continue;
			const texto = nk.binaryToString(m.data);
			if (texto.length > SALA_MAX_MENSAJE) continue;
			datos = JSON.parse(texto);
		} catch (err) {
			continue;
		}
		if (!salaDatosValidos(m.opCode, datos)) continue;
		// Poses y manos pueden emitirse sin entrada humana: no reactivan al ausente.
		if (m.opCode !== OP_POSE && m.opCode !== OP_MANO && salaQuitarAusente(e, s)) cambio = true;
		try {
			if (salaMensaje(e, s, m.opCode, datos, dispatcher, nk, logger)) cambio = true;
		} catch (err) {
			// Una entrada rota no debe cerrar el match; no registrar su payload.
			logger.warn("Colmadón: operación de cliente rechazada por error interno");
		}
	}
	// cambio de silla sin respuesta a tiempo: se rechaza
	if (e.game === null && e.peticion && tick >= e.peticion.hasta) {
		salaAviso(e, "silla_no", e.peticion.de, { target: e.peticion.a, tarde: true });
		e.peticion = null;
		cambio = true;
	}
	// «joined» de quien no mandó su nombre a tiempo
	for (let s = 0; s < 4; s++) {
		if (e.porAnunciar[s] > 0 && tick >= e.porAnunciar[s]) {
			salaAnunciarEntrada(e, s);
			cambio = true;
		}
	}
	// personas conectadas (los bots no tienen presencia)
	let conectados = 0;
	for (const s of e.seats) if (s.presence !== null) conectados++;
	if (e.game !== null && conectados === 0) {
		// O09: sin ninguna persona la partida no sigue solo con bots: se para
		// (los relojes no corren por si alguien vuelve a tiempo) y la sala se cierra
		e.deadline++;
		e.botWait++;
	} else if (e.game !== null) {
		if (salaAvanzar(e)) cambio = true;
		if (salaTranque(e)) cambio = true;
		if (salaVer(e)) cambio = true;
		// Fuera de mano/tienda, todos sentados y destapados.
		if (e.game.phase !== "play" && e.game.phase !== "shop" && e.poses.some((q) => q.st !== 0)) {
			e.poses = [0, 1, 2, 3].map(() => salaPoseSentada());
			e.tapado = [false, false, false, false];
			e.tapaEn = [0, 0, 0, 0];
			e.posesCambio = true;
		}
		if (salaPasoPoses(e, dispatcher)) cambio = true;
	}
	if (e.avisos.length > 0) cambio = true;
	if (cambio) salaEnviarTodo(e, dispatcher, nk);
	if (salaEtiqueta(e) !== salaEtiqueta(state as EstadoSala)) dispatcher.matchLabelUpdate(salaEtiqueta(e));
	// sala vacía: se cierra (antes si estaba en partida: nadie juega solo con bots)
	if (conectados === 0) {
		if (e.vaciaDesde === 0) e.vaciaDesde = tick;
		const limite = e.game !== null ? SALA_SOLO_BOTS_SEG : SALA_VACIA_SEG;
		if (tick - e.vaciaDesde > limite * SALA_TICK) {
			logger.info("Sala " + e.code + " cerrada: no queda ninguna persona");
			return null;
		}
	} else {
		e.vaciaDesde = 0;
	}
	return { state: e };
};

const salaTerminate: nkruntime.MatchTerminateFunction<EstadoSala> = function (ctx, logger, nk, dispatcher, tick, state, graceSeconds) {
	return { state: state };
};

/** Preguntas a la sala desde un RPC. {silla: userId}: ¿puede volver esa cuenta? */
const salaSignal: nkruntime.MatchSignalFunction<EstadoSala> = function (ctx, logger, nk, dispatcher, tick, state, data) {
	let d: any = null;
	try { d = JSON.parse(data || "{}"); } catch (_) { return { state: state, data: "" }; }
	if (!salaObjeto(d) || typeof d.silla !== "string") return { state: state, data: "" };
	const e = state as EstadoSala;
	return { state: state, data: JSON.stringify({ puede: salaPuedeVolver(e, d.silla) }) };
};

/** O02: vuelve a su silla (aunque la partida siga), o entra si la sala espera y hay sitio. */
function salaPuedeVolver(e: EstadoSala, userId: string): boolean {
	if (userId !== "" && salaSillaDe(e, userId) >= 0) return true;
	if (e.game !== null) return false;
	for (const s of e.seats) if (s.userId === null) return true;
	return false;
}

function salaObjeto(d: any): boolean {
	return d !== null && typeof d === "object" && !Array.isArray(d);
}

function salaEntero(n: any, min: number, max: number): boolean {
	return typeof n === "number" && isFinite(n) && Math.floor(n) === n && n >= min && n <= max;
}

function salaNumero(n: any): boolean {
	return typeof n === "number" && isFinite(n) && Math.abs(n) <= 10000;
}

function salaVec3(v: any): boolean {
	return Array.isArray(v) && v.length === 3 && v.every((x: any) => typeof x === "number" && isFinite(x) && Math.abs(x) < 50);
}

/** Contrato del protocolo: no convertir null, booleanos, texto ni fracciones a números. */
function salaDatosValidos(op: number, d: any): boolean {
	if (!salaObjeto(d)) return false;
	const id = typeof d.id === "string" && d.id.length > 0 && d.id.length <= 32;
	switch (op) {
		case OP_PERFIL: return typeof d.name === "string" && d.name.length <= 64 && (d.avatar === undefined || d.avatar === null || salaObjeto(d.avatar));
		case OP_CARTA: return id;
		case OP_BEBER: case OP_COMPRAR: return id && Object.prototype.hasOwnProperty.call(R_DRINKS, d.id);
		case OP_FRASE: return id; // salaFrase conserva el aviso de id inexistente, ya limitado
		case OP_ROBAR: return salaEntero(d.idx, 0, 27);
		case OP_JUGAR: return salaFicha(d.tile) !== null && salaEntero(d.side, -1, 1);
		case OP_REVISAR: return d.none === true ? d.tile === undefined : (d.none === undefined || d.none === false) && salaFicha(d.tile) !== null;
		case OP_POSE: return salaEntero(d.st, 0, 2) && (d.st !== 2 || (salaNumero(d.x) && salaNumero(d.z) && salaNumero(d.yaw) && (d.p === undefined || salaNumero(d.p))));
		case OP_MANO: return salaEntero(d.st, 0, 3) && salaEntero(d.side, -1, 1);
		case OP_RADIO: return true;
		case OP_EQUIPO: return typeof d.name === "string" && d.name.length <= 32;
		case OP_LISTO_SALA: return typeof d.on === "boolean";
		case OP_SILLA: return salaEntero(d.seat, 1, 3);
		case OP_REVELAR: case OP_AMAGO: return salaEntero(d.idx, 0, 27);
		case OP_ENTREGAR: case OP_PRUEBA_TRANQUE: return true;
		case OP_ARREBATAR: return salaEntero(d.seat, 1, 3);
		case OP_SILLA_RESP: case OP_EQUIPO_RESP: return typeof d.ok === "boolean";
		case OP_CUENTA: return d.all === true ? d.tile === undefined : d.all === undefined && salaFicha(d.tile) !== null;
		case OP_TAPAR: return typeof d.on === "boolean";
		case OP_GOLPE: return salaEntero(d.target, 1, 3) && (d.run === undefined || typeof d.run === "boolean");
		case OP_DISPARO: return salaVec3(d.o) && salaVec3(d.n) && (d.target === undefined || (salaEntero(d.target, 1, 3) && typeof d.zona === "string" && d.zona.length <= 8));
		case OP_REVIVIR: return true;
		case OP_VERIFICAR: return !!d && (d.ok === true || d.reclamar === true);
		case OP_BALAS: return salaEntero(d.n, 0, SALA_MAX_BALAS) && typeof d.arma === "string" && d.arma.length <= 16;
		case OP_EMOTE: return id && SALA_EMOTES.indexOf(d.id) >= 0 && (d.target === undefined || salaEntero(d.target, -1, 3)) &&
			(d.px === undefined && d.pz === undefined || salaNumero(d.px) && salaNumero(d.pz));
		case OP_EMPEZAR: case OP_PASAR: case OP_PASAR_CON_FICHA: case OP_CANTAR:
		case OP_LISTO: case OP_REVANCHA: case OP_AQUI: case OP_TRANQUE_OK: return true;
		default: return false; // incluye OP_ESTADO/OP_MANOS: son solo del servidor
	}
}

/** Solo campos cosméticos que entiende look_de_json; nunca reenviar objetos del cliente. */
function salaAvatar(d: any): any {
	if (!salaObjeto(d)) return null;
	const avatar: any = {};
	for (const k of ["skin", "hair", "shirt", "pants"]) {
		if (typeof d[k] === "string" && /^#[a-fA-F0-9]{6}$/.test(d[k])) avatar[k] = d[k];
	}
	for (const k of ["hat", "pattern", "cuerpo", "glasses", "earrings", "chain", "lips"]) {
		if (typeof d[k] === "string" && d[k].length <= 16 || typeof d[k] === "boolean") avatar[k] = d[k];
	}
	for (const k of ["mustache", "beard"]) if (typeof d[k] === "boolean") avatar[k] = d[k];
	return avatar;
}

/** Nombre de equipo: solo letras, números y espacios, máx. SALA_EQUIPO_MAX; vacío = el de siempre. */
function salaNombreEquipo(t: string): string {
	let r = "";
	for (const c of t) if (/[A-Za-z0-9 ÁÉÍÓÚÜÑáéíóúüñ]/.test(c)) r += c;
	return r.replace(/ +/g, " ").trim().substring(0, SALA_EQUIPO_MAX).trim();
}

function salaNombreVacio(): NombreEquipo {
	return { estado: "vacio", nombre: "", propone: -1, turno: -1, rechazado: "", humanos: "" };
}

function salaNombres(e: EstadoSala): NombreEquipo[] {
	if (!e.nombres) e.nombres = [salaNombreVacio(), salaNombreVacio()];
	return e.nombres;
}

function salaListos(e: EstadoSala): boolean[] {
	if (!e.listosSala) e.listosSala = [false, false, false, false];
	return e.listosSala;
}

/** Personas de la pareja p (sillas p y p+2). */
function salaHumanosPareja(e: EstadoSala, p: number): number[] {
	return [p, p + 2].filter((s) => e.seats[s].userId !== null);
}

/** Reglamento S4 (13 oct): el nombre es del EQUIPO (sus dos sillas), no de las
 * personas. Si alguien entra, sale o se cambia de silla, el nombre aceptado se
 * queda y quien llega lo toma; nadie pierde su LISTO. Solo se reinicia una
 * propuesta a medias si quien la hizo (o a quien le tocaba) ya no está en el equipo. */
function salaRevisarParejas(e: EstadoSala): void {
	if (!e.equipos) e.equipos = ["", ""];
	const ns = salaNombres(e);
	for (let p = 0; p < 2; p++) {
		const firma = salaHumanosPareja(e, p).map((s) => s + ":" + e.seats[s].userId).join(",");
		if (ns[p].humanos === firma) continue;
		ns[p].humanos = firma;
		const ne = ns[p];
		if (ne.estado === "aceptado") continue;
		const humanos = salaHumanosPareja(e, p);
		const sigue = (s: number) => s >= 0 && humanos.indexOf(s) >= 0;
		if ((ne.estado === "propuesto" && !sigue(ne.propone)) || (ne.turno >= 0 && !sigue(ne.turno))) {
			const h = ne.humanos;
			ns[p] = salaNombreVacio();
			ns[p].humanos = h;
		}
	}
}

/** O11 + acuerdo: propones el nombre; tu pareja (si es persona) lo acepta o no. Aceptado ya no cambia. */
function salaEquipo(e: EstadoSala, s: number, d: any): boolean {
	if (e.game !== null) return false;
	const n = salaNombreEquipo(String(d.name));
	if (n === "") return false;
	const p = s % 2;
	// reglamento S5: los dos equipos no pueden llamarse igual
	const rival = (e.equipos ? e.equipos[1 - p] : "") || salaNombres(e)[1 - p].nombre;
	if (rival !== "" && rival.toLowerCase() === n.toLowerCase()) {
		salaAviso(e, "equipo_repetido", s, { name: n });
		return false;
	}
	const ne = salaNombres(e)[p];
	if (ne.estado === "aceptado") return false;
	if (ne.turno >= 0 && ne.turno !== s) return false; // le toca proponer a tu pareja
	if (ne.estado === "propuesto" && ne.propone !== s) return false; // contesta primero a lo suyo
	ne.nombre = n;
	ne.propone = s;
	if (salaHumanosPareja(e, p).length < 2) {
		// tu pareja es un bot: vale tal cual
		ne.estado = "aceptado";
		ne.turno = -1;
		e.equipos![p] = n;
		salaAviso(e, "equipo_ok", s, { name: n });
	} else {
		ne.estado = "propuesto";
		salaAviso(e, "equipo_pide", s, { name: n });
	}
	return true;
}

/** Respuesta al nombre que propuso tu pareja: sí = aceptado y fijo; no = te toca proponer a ti. */
function salaEquipoResp(e: EstadoSala, s: number, d: any): boolean {
	if (e.game !== null) return false;
	const p = s % 2;
	const ne = salaNombres(e)[p];
	if (ne.estado !== "propuesto" || ne.propone === s) return false;
	if (d.ok === true) {
		ne.estado = "aceptado";
		ne.turno = -1;
		e.equipos![p] = ne.nombre;
		salaAviso(e, "equipo_ok", s, { name: ne.nombre });
	} else {
		salaAviso(e, "equipo_no", s, { name: ne.nombre, target: ne.propone });
		ne.rechazado = ne.nombre;
		ne.estado = "vacio";
		ne.nombre = "";
		ne.propone = -1;
		ne.turno = s;
	}
	return true;
}

/** LISTO: solo con el nombre de tu pareja aceptado. */
function salaListoSala(e: EstadoSala, s: number, d: any): boolean {
	if (e.game !== null) return false;
	const on = d.on === true;
	if (on && salaNombres(e)[s % 2].estado !== "aceptado") return false;
	if (salaListos(e)[s] === on) return false;
	salaListos(e)[s] = on;
	return true;
}

/** Todas las personas listas (lo que habilita «¡A JUGAR!»). */
function salaTodosListos(e: EstadoSala): boolean {
	for (let s = 0; s < 4; s++) if (e.seats[s].userId !== null && !salaListos(e)[s]) return false;
	return true;
}

/** Cambia las sillas a y b de sitio (con todo lo de cada uno): el LISTO viaja con cada persona. */
function salaCambiarSillas(e: EstadoSala, a: number, b: number): void {
	const t = e.seats[a];
	e.seats[a] = e.seats[b];
	e.seats[b] = t;
	const l = salaListos(e);
	const la = l[a];
	l[a] = l[b];
	l[b] = la;
	const pa = e.porAnunciar[a];
	e.porAnunciar[a] = e.porAnunciar[b];
	e.porAnunciar[b] = pa;
	e.peticion = null;
	salaRevisarParejas(e);
}

/** Quieres sentarte en la silla k (local): libre (bot) = al momento; de una persona = se lo pides. */
function salaSilla(e: EstadoSala, s: number, d: any): boolean {
	if (e.game !== null) return false;
	const t = (s + Number(d.seat)) % 4;
	if (t === s) return false;
	if (e.seats[t].userId === null) {
		salaCambiarSillas(e, s, t);
		salaAviso(e, "silla_mov", t, { target: s }); // seat = donde está ahora, target = de dónde venía
		return true;
	}
	if (e.peticion) return false; // una petición a la vez en la sala
	e.peticion = { de: s, a: t, hasta: e.tick + T_PETICION_SILLA * SALA_TICK };
	salaAviso(e, "silla_pide", s, { target: t });
	return true;
}

/** Respuesta de quien recibió la petición: sí = se cambian; no = se queda. */
function salaSillaResp(e: EstadoSala, s: number, d: any): boolean {
	const pe = e.peticion;
	if (e.game !== null || !pe || pe.a !== s) return false;
	if (d.ok === true) {
		const de = pe.de;
		salaCambiarSillas(e, de, s);
		// ya cambiados: quien pidió está en s y quien aceptó en de
		salaAviso(e, "silla_cambio", s, { target: de });
	} else {
		salaAviso(e, "silla_no", pe.de, { target: s });
		e.peticion = null;
	}
	return true;
}

/** Contadores por silla/tick; se conservan al reconectar para no evadir el límite. */
function salaAdmitir(e: EstadoSala, s: number, op: number): boolean {
	if (!e.entrada) e.entrada = [0, 1, 2, 3].map(() => ({ tick: -1, total: 0, ops: {} }));
	let c = e.entrada[s];
	if (c.tick !== e.tick) c = e.entrada[s] = { tick: e.tick, total: 0, ops: {} };
	if (++c.total > SALA_MAX_POR_TICK) return false;
	const key = String(op);
	const limite = op === OP_POSE || op === OP_MANO ? 2 : op === OP_PERFIL || op === OP_TAPAR ? 1 : 8;
	c.ops[key] = (c.ops[key] || 0) + 1;
	return c.ops[key] <= limite;
}

/** Mensaje de un jugador. Devuelve true si cambió algo. */
function salaMensaje(e: EstadoSala, s: number, op: number, d: any, dispatcher: nkruntime.MatchDispatcher, nk: nkruntime.Nakama, logger: nkruntime.Logger): boolean {
	if (!salaEntero(s, 0, 3) || !salaDatosValidos(op, d)) return false;
	const g = e.game;
	if (op === OP_PERFIL) {
		e.seats[s].name = String(d.name || e.seats[s].name).substring(0, 16);
		e.seats[s].avatar = salaAvatar(d.avatar);
		if (e.porAnunciar[s] > 0) salaAnunciarEntrada(e, s);
		return true;
	}
	if (op === OP_FRASE) return salaFrase(e, s, d, dispatcher);
	if (op === OP_AQUI) return false;
	if (op === OP_REVELAR || op === OP_AMAGO || op === OP_ENTREGAR || op === OP_ARREBATAR) return salaTranqueMensaje(e, s, op, d);
	if (op === OP_PRUEBA_TRANQUE) {
		if (!e.pruebas || g === null || g.phase !== "play") return false;
		rTerminarMano(g, -1, [-1, -1] as any, false, -1, "");
		return true;
	}
	if (op === OP_VERIFICAR) return salaVerMensaje(e, s, d);
	if (op === OP_TRANQUE_OK) {
		if (g === null || (g.phase !== "shop" && g.phase !== "over") || !g.last_result || g.last_result.reason !== "tranque" || e.tranqueOk[s]) return false;
		if (e.tq && e.tq.mano === g.hand_no && e.tq.etapa !== "visto") return false; // VISTO va después de revelar
		e.tranqueOk[s] = true;
		return true;
	}
	if (op === OP_GOLPE) return salaGolpe(e, s, d); // ya lo devolvió salaQuitarAusente (cualquier mensaje)
	if (op === OP_DISPARO) return salaDisparo(e, s, d);
	if (op === OP_REVIVIR) return salaRevivir(e, s);
	if (op === OP_BALAS) {
		if (!e.balas || !e.armaDe) return false;
		e.balas[s] = Math.max(0, Math.min(SALA_MAX_BALAS, Number(d.n)));
		e.armaDe[s] = SALA_ARMAS[d.arma] ? d.arma : "pistola";
		return true;
	}
	if (op === OP_POSE) return e.muerto && e.muerto[s] ? false : salaPose(e, s, d);
	if (op === OP_RADIO) return salaRadio(e);
	if (op === OP_EQUIPO) return salaEquipo(e, s, d);
	if (op === OP_EQUIPO_RESP) return salaEquipoResp(e, s, d);
	if (op === OP_LISTO_SALA) return salaListoSala(e, s, d);
	if (op === OP_SILLA) return salaSilla(e, s, d);
	if (op === OP_SILLA_RESP) return salaSillaResp(e, s, d);
	if (op === OP_CUENTA) {
		salaCuenta(e, s, d, dispatcher);
		return false; // la mesa no cambia: los demás ven la cuenta al ritmo de quien ganó
	}
	if (op === OP_MANO) {
		salaMano(e, s, d, dispatcher);
		return false; // la mesa no cambia: solo se reenvía a los demás
	}
	if (op === OP_TAPAR) {
		e.tapado[s] = d && d.on === true;
		e.posesCambio = true;
		return true;
	}
	if (op === OP_EMOTE) {
		const id = String(d && d.id !== undefined ? d.id : "");
		if (SALA_EMOTES.indexOf(id) < 0) return false;
		// El cliente antiguo interpreta shove con target como un empujón real.
		// Reutilizar toda la autoridad/cooldown del golpe; sin target es cosmético.
		if (id === "shove" && d.target >= 1) return salaGolpe(e, s, d);
		if (e.tick - e.ultimaFrase[s] < 1 * SALA_TICK) return false; // como mucho uno por segundo
		e.ultimaFrase[s] = e.tick;
		const t = Number(d.target);
		const extra: any = { id: id };
		if (t >= 1 && t <= 3) extra.target = (t + s) % 4; // silla del que la recibe, en sillas del servidor
		// señalar un punto del colmado: a coordenadas comunes (cada uno lo recibe girado)
		const px = Number(d.px), pz = Number(d.pz);
		if (id === "point" && isFinite(px) && isFinite(pz)) {
			const gp = salaGirar(Math.max(-4, Math.min(4, px)), Math.max(-4, Math.min(4, pz)), s);
			extra.px = gp[0];
			extra.pz = gp[1];
		}
		salaAviso(e, "emote", s, extra);
		return true;
	}
	if (op === OP_EMPEZAR) {
		if (g !== null || e.seats[s].userId !== e.host || !salaTodosListos(e)) return false;
		salaEmpezar(e);
		dispatcher.matchLabelUpdate(salaEtiqueta(e));
		return true;
	}
	if (g === null) return false;
	// Para actuar sobre el turno propio hay que estar sentado (igual que el cliente).
	if ([OP_JUGAR, OP_PASAR, OP_PASAR_CON_FICHA, OP_CANTAR, OP_BEBER, OP_REVISAR].indexOf(op) >= 0 && (e.poses[s].st !== 0 || e.caidoHasta[s] > e.tick || (e.muerto !== undefined && e.muerto[s]))) return false;
	let ok = false;
	if (op === OP_CARTA) ok = rElegirCarta(g, s, String(d.id));
	else if (op === OP_ROBAR) ok = rRobar(g, s, Number(d.idx));
	else if (op === OP_JUGAR) ok = salaFicha(d.tile) !== null && rJugarOChivo(g, s, salaFicha(d.tile) as Ficha, Number(d.side));
	else if (op === OP_PASAR) ok = rPasar(g, s);
	else if (op === OP_PASAR_CON_FICHA) ok = rJugadas(g, s).length > 0 && rPasarConFicha(g, s);
	else if (op === OP_CANTAR) ok = g.phase === "play" && g.turn === s && g.revision === null && (rCantarChivo(g, s, true) || true);
	else if (op === OP_REVISAR) {
		const nada = d && d.none === true;
		const ft = nada ? null : salaFicha(d && d.tile);
		ok = (nada || ft !== null) && rResolverRevision(g, s, ft) !== "";
	}
	else if (op === OP_BEBER) ok = rBeber(g, s, String(d.id));
	else if (op === OP_COMPRAR) ok = rComprar(g, s, String(d.id));
	else if (op === OP_LISTO) {
		if (g.phase === "shop") {
			e.listos[s] = true;
			ok = true;
		}
	} else if (op === OP_REVANCHA) {
		if (g.phase === "over") {
			e.revancha[s] = true;
			ok = true;
		}
	}
	if (!ok && op !== OP_LISTO && op !== OP_REVANCHA) {
		const pr = e.seats[s].presence;
		if (pr !== null) dispatcher.broadcastMessage(OP_AVISO, JSON.stringify({ text: "No se puede hacer eso ahora" }), [pr], null, true);
	}
	return ok;
}

function salaPoseSentada(): Pose {
	return { st: 0, x: 0, z: 0, yaw: 0, pitch: 0, desde: 0, hy: 0, hp: 0 };
}

/** Gira un punto del suelo k cuartos de vuelta: (x, z) → (z, −x), como pasa de la silla 0 a la 1. */
function salaGirar(x: number, z: number, k: number): number[] {
	let a = x, b = z;
	for (let i = 0; i < ((k % 4) + 4) % 4; i++) {
		const t = a;
		a = b;
		b = -t;
	}
	return [a, b];
}

/** Pose que manda un jugador (en sus coordenadas: él en la silla 0). */
function salaPose(e: EstadoSala, s: number, d: any): boolean {
	const st = Number(d && d.st);
	if (!(st === 0 || st === 1 || st === 2)) return false;
	// sentado y sigue sentado: solo mueve la cabeza (modo cámara), en cualquier fase
	if (st === 0 && e.poses[s].st === 0) {
		const hy = Number(d.hy), hp = Number(d.hp);
		if (!isFinite(hy) || !isFinite(hp)) return false;
		e.poses[s].hy = Math.max(-1.3, Math.min(1.3, hy));
		e.poses[s].hp = Math.max(-0.7, Math.min(0.6, hp));
		e.posesCambio = true;
		return false;
	}
	// de pie: durante la mano y en la tienda (ir al mostrador); en lo demás, sentado
	if (e.game === null || (e.game.phase !== "play" && e.game.phase !== "shop")) {
		if (e.poses[s].st === 0) return false;
		e.poses[s] = salaPoseSentada();
		e.posesCambio = true;
		return true;
	}
	const p = e.poses[s];
	if (st === 2 && p.st === 0) return false; // primero levantarse; desde lo decide el servidor
	if (st === 1 && p.st === 0) {
		p.desde = e.tick;
		// los bots ven que se para y tapan sus fichas (casi siempre)
		for (let b = 0; b < 4; b++) {
			if (b !== s && salaEsBot(e, b) && !e.tapado[b] && Math.random() < BOT_TAPA) e.tapaEn[b] = e.tick + Math.floor((0.3 + Math.random() * 1.6) * SALA_TICK);
		}
	}
	p.st = st;
	if (st === 2) {
		const x = Number(d.x), z = Number(d.z), yaw = Number(d.yaw);
		if (!isFinite(x) || !isFinite(z) || !isFinite(yaw)) return false;
		// a coordenadas del colmado (las de la silla 0) y luego dentro de sus paredes:
		// cada uno ve el colmado girado según su silla, así que sus paredes son estas
		const g = salaGirar(x, z, s);
		p.x = Math.max(SALA_SALA.x0, Math.min(SALA_SALA.x1, g[0]));
		p.z = Math.max(SALA_SALA.z0, Math.min(SALA_SALA.z1, g[1]));
		p.yaw = yaw + (s * Math.PI) / 2;
		const pitch = Number(d.p);
		p.pitch = isFinite(pitch) ? Math.max(-1.3, Math.min(0.7, pitch)) : 0; // hacia dónde mira (arriba/abajo)
		p.a = e.armas === true && d.a === true; // armado (los demás le ven el arma en la mano)
	}
	if (st === 0) {
		p.desde = 0;
		// nadie de pie: los bots destapan
		if (e.poses.every((q) => q.st === 0)) {
			for (let b = 0; b < 4; b++) {
				if (salaEsBot(e, b)) e.tapado[b] = false;
				e.tapaEn[b] = 0;
			}
		}
	}
	e.posesCambio = true;
	return false; // la mesa no cambia (las poses van aparte, con OP_POSES)
}

/**
 * Lo que hace un jugador con sus fichas (mirarlas, una en la mano, llevarla a
 * una punta): se reenvía al momento a los demás, con la silla girada para
 * cada uno. Solo en su turno; fuera de él se reenvía «nada».
 */
function salaMano(e: EstadoSala, s: number, d: any, dispatcher: nkruntime.MatchDispatcher): void {
	let st = Math.floor(Number(d && d.st));
	let side = Math.floor(Number(d && d.side));
	if (!(st >= 0 && st <= 3)) st = 0;
	if (!(side >= -1 && side <= 1)) side = 0;
	const g = e.game;
	if (g === null || g.phase !== "play") {
		st = 0;
		side = 0;
	} else if (g.turn !== s) {
		// F10: fuera de tu turno puedes reacomodar tu mano (st 1-2), no ir a una punta
		st = Math.min(st, 2);
		side = 0;
	}
	for (let yo = 0; yo < 4; yo++) {
		const pr = e.seats[yo].presence;
		if (yo === s || pr === null) continue;
		dispatcher.broadcastMessage(OP_MANOS, JSON.stringify({ seat: (s - yo + 4) % 4, st: st, side: side }), [pr], null, true);
	}
}

/** Radio compartida (2026-10-09): pista 0 → 1 → 2 → apagada → 0. Una vez por segundo como mucho. */
const SALA_PISTAS = 3;
function salaRadio(e: EstadoSala): boolean {
	if (!e.radio) e.radio = { on: true, pista: 0, inicio: 0, ultimo: -9999 };
	const r = e.radio;
	if (e.tick - r.ultimo < SALA_TICK) return false;
	r.ultimo = e.tick;
	if (!r.on) {
		r.on = true;
		r.pista = 0;
	} else if (r.pista + 1 >= SALA_PISTAS) {
		r.on = false;
	} else {
		r.pista++;
	}
	r.inicio = e.tick;
	return true;
}

/**
 * Cuenta de fin de mano (2026-10-09): quien ganó la hace tocando cada ficha;
 * los demás la ven a su ritmo. Solo vale de quien ganó y con la mano acabada.
 */
function salaCuenta(e: EstadoSala, s: number, d: any, dispatcher: nkruntime.MatchDispatcher): void {
	const g = e.game;
	if (g === null || (g.phase !== "shop" && g.phase !== "over") || !g.last_result || g.last_result.seat !== s) return;
	const tile = d && d.all === true ? null : salaFicha(d.tile);
	for (let yo = 0; yo < 4; yo++) {
		const pr = e.seats[yo].presence;
		if (yo === s || pr === null) continue;
		const m: any = { seat: (s - yo + 4) % 4 };
		if (tile === null) m.all = true;
		else m.tile = tile;
		dispatcher.broadcastMessage(OP_CUENTAS, JSON.stringify(m), [pr], null, true);
	}
}

/**
 * Manotazo de pie (2026-10-04): solo entre dos personas de pie y cerca (1 m),
 * uno cada T_GOLPE. Se tambalea; si venía corriendo o es el segundo golpe que
 * recibe en T_DOBLE_GOLPE, cae al suelo T_CAIDO. Al tercer golpe en T_ABUSO,
 * el colmadero manda a su silla a quien pega.
 */
function salaGolpe(e: EstadoSala, s: number, d: any): boolean {
	const g = e.game;
	if (g === null || (g.phase !== "play" && g.phase !== "shop")) return false;
	const tl = Number(d && d.target);
	if (!(tl >= 1 && tl <= 3)) return false;
	const t = (tl + s) % 4;
	const ps = e.poses[s], pt = e.poses[t];
	if (ps.st !== 2 || pt.st !== 2 || salaEsBot(e, t)) return false;
	if (e.tick < e.golpeListo[s] || e.tick < e.caidoHasta[s] || e.tick < e.caidoHasta[t]) return false;
	if (Math.sqrt((ps.x - pt.x) * (ps.x - pt.x) + (ps.z - pt.z) * (ps.z - pt.z)) > 1.0) return false;
	e.golpeListo[s] = e.tick + T_GOLPE * SALA_TICK;
	const cae = d.run === true || e.tick - e.golpeadoEn[t] < T_DOBLE_GOLPE * SALA_TICK;
	e.golpeadoEn[t] = e.tick;
	if (cae) {
		e.caidoHasta[t] = e.tick + T_CAIDO * SALA_TICK;
		e.posesCambio = true; // todos lo ven en el suelo (también quien entre ahora)
	}
	salaAviso(e, "golpe", s, { target: t, cae: cae });
	e.golpesDe[s] = e.golpesDe[s].filter((x) => e.tick - x < T_ABUSO * SALA_TICK);
	e.golpesDe[s].push(e.tick);
	if (e.golpesDe[s].length >= 3) {
		// «¡Respeten mi colmado!»: a su silla
		e.golpesDe[s] = [];
		e.poses[s] = salaPoseSentada();
		e.posesCambio = true;
		salaAviso(e, "colmadero", s, {});
	}
	return true;
}

/** Un tiro: el servidor comprueba que quien dispara puede (de pie, vivo, con
 * balas y a su ritmo) y que la línea del tiro pasa cerca de donde está ahora
 * el objetivo (si se movió, falla). Luego quita vida según la zona. */
function salaDisparo(e: EstadoSala, s: number, d: any): boolean {
	const g = e.game;
	if (!e.armas || g === null || (g.phase !== "play" && g.phase !== "shop")) return false;
	if (!e.vida || !e.muerto || !e.balas || !e.armaDe || !e.disparoListo || !e.muertoDesde || !e.cuerpo) return false;
	const ps = e.poses[s];
	if (ps.st !== 2 || e.muerto[s] || e.balas[s] <= 0 || e.tick < e.disparoListo[s] || e.caidoHasta[s] > e.tick) return false;
	const arma = SALA_ARMAS[e.armaDe[s]] || SALA_ARMAS.pistola;
	e.balas[s]--;
	e.disparoListo[s] = e.tick + arma.cad;
	// a coordenadas del servidor (tu silla 0 → la tuya)
	const og = salaGirar(Number(d.o[0]), Number(d.o[2]), s), ng = salaGirar(Number(d.n[0]), Number(d.n[2]), s);
	const o = [og[0], Number(d.o[1]), og[1]];
	let n = [ng[0], Number(d.n[1]), ng[1]];
	const nl = Math.sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]);
	if (nl < 0.5) return false;
	n = n.map((x) => x / nl);
	// el tiro sale de donde estás
	if (Math.sqrt((o[0] - ps.x) * (o[0] - ps.x) + (o[2] - ps.z) * (o[2] - ps.z)) > 0.8) return false;
	const ev: any = { o: o, n: n };
	if (d.target !== undefined) {
		const t = (Number(d.target) + s) % 4;
		const zona = String(d.zona);
		const dano = arma.dano[zona];
		if (dano !== undefined && !e.muerto[t] && salaTiroCerca(e, t, o, n)) {
			e.vida[t] = Math.max(0, e.vida[t] - dano);
			ev.target = t;
			ev.zona = zona;
			ev.vida = e.vida[t];
			if (e.vida[t] <= 0) {
				e.muerto[t] = true;
				e.muertoDesde[t] = e.tick;
				const pt = e.poses[t];
				const dir = salaDirSilla(t);
				e.cuerpo[t] = pt.st === 2 ? [pt.x, pt.z] : [dir[0] * 1.7, dir[1] * 1.7];
				ev.muerto = true;
				e.posesCambio = true;
			}
		}
	}
	salaAviso(e, "disparo", s, ev);
	return true;
}

/** ¿Pasa la línea del tiro a menos de 0,75 m del cuerpo del objetivo (según el servidor)? */
function salaTiroCerca(e: EstadoSala, t: number, o: number[], n: number[]): boolean {
	const pt = e.poses[t];
	const dir = salaDirSilla(t);
	const c = pt.st === 2 ? [pt.x, 1.15, pt.z] : [dir[0] * 1.02, 1.05, dir[1] * 1.02];
	const v = [c[0] - o[0], c[1] - o[1], c[2] - o[2]];
	const k = v[0] * n[0] + v[1] * n[1] + v[2] * n[2];
	if (k <= 0) return false;
	const p = [o[0] + n[0] * k - c[0], o[1] + n[1] * k - c[1], o[2] + n[2] * k - c[2]];
	return Math.sqrt(p[0] * p[0] + p[1] * p[1] + p[2] * p[2]) < 0.75;
}

/** Un muerto vuelve: aparece en el suelo donde cayó, se levanta y tiene que ir a sentarse. */
function salaRevivir(e: EstadoSala, s: number): boolean {
	if (!e.muerto || !e.muerto[s] || !e.vida || !e.cuerpo) return false;
	e.muerto[s] = false;
	e.vida[s] = 100;
	const c = e.cuerpo[s];
	e.poses[s] = { st: 2, x: c[0], z: c[1], yaw: Math.atan2(c[0], c[1]), pitch: 0, desde: e.tick, hy: 0, hp: 0 };
	e.caidoHasta[s] = e.tick + 2 * SALA_TICK;
	e.posesCambio = true;
	salaAviso(e, "revive", s, {});
	return true;
}

/** Fuera de la jugada (nueva mano): nadie muerto y la vida llena. */
function salaArmasNuevaMano(e: EstadoSala): boolean {
	if (!e.muerto || !e.vida) return false;
	let cambio = false;
	for (let k = 0; k < 4; k++) {
		if (e.muerto[k]) {
			e.muerto[k] = false;
			e.poses[k] = salaPoseSentada();
			e.posesCambio = true;
			salaAviso(e, "revive", k, {});
			cambio = true;
		}
		e.vida[k] = 100;
	}
	return cambio;
}

/** Dirección (x, z) de una silla del servidor desde el centro de la mesa. */
function salaDirSilla(s: number): number[] {
	return [[0, 1], [1, 0], [0, -1], [-1, 0]][s];
}

/** ¿Ve «yo» las fichas de «s»? Está de pie del todo, detrás de él y cerca, y «s» no las tapó. */
function salaVeFichas(e: EstadoSala, yo: number, s: number): boolean {
	if (!e.poses || yo === s) return false;
	const p = e.poses[yo];
	if (p.st !== 2 || e.tick - p.desde < T_LEVANTARSE * SALA_TICK) return false;
	if (e.tapado[s] || e.poses[s].st !== 0) return false;
	const d = salaDirSilla(s);
	const sx = d[0] * 1.1, sz = d[1] * 1.1;
	const vx = p.x - sx, vz = p.z - sz;
	const detras = vx * d[0] + vz * d[1];
	return detras > -0.05 && Math.sqrt(vx * vx + vz * vz) < 1.1;
}

/** Firma de quién ve a quién: si cambia, hay que reenviar la mesa con las fichas. */
function salaFirmaMiradas(e: EstadoSala): string {
	let f = "";
	for (let yo = 0; yo < 4; yo++) for (let s = 0; s < 4; s++) f += salaVeFichas(e, yo, s) ? "1" : "0";
	return f;
}

/** Bots que tapan con retraso; poses a todos (giradas para cada uno). */
function salaPasoPoses(e: EstadoSala, dispatcher: nkruntime.MatchDispatcher): boolean {
	if (e.muerto && e.muertoDesde) {
		const g = e.game;
		if (g === null || (g.phase !== "play" && g.phase !== "shop")) salaArmasNuevaMano(e);
		for (let k = 0; k < 4; k++) {
			if (e.muerto[k] && salaEsBot(e, k) && e.tick - e.muertoDesde[k] >= T_BOT_VUELVE * SALA_TICK) {
				e.muerto[k] = false;
				if (e.vida) e.vida[k] = 100;
				e.posesCambio = true;
				salaAviso(e, "revive", k, {});
			}
		}
	}
	// se levantó del suelo: avisar en las poses
	for (let k = 0; k < 4; k++) {
		if (e.caidoHasta[k] !== 0 && e.tick >= e.caidoHasta[k]) {
			e.caidoHasta[k] = 0;
			e.posesCambio = true;
		}
	}
	for (let b = 0; b < 4; b++) {
		if (e.tapaEn[b] > 0 && e.tick >= e.tapaEn[b]) {
			e.tapaEn[b] = 0;
			e.tapado[b] = true;
			e.posesCambio = true;
		}
	}
	if (e.posesCambio) {
		e.posesCambio = false;
		for (let yo = 0; yo < 4; yo++) {
			const pr = e.seats[yo].presence;
			if (pr === null) continue;
			const poses = [0, 1, 2, 3].map((k) => {
				const q = e.poses[(k + yo) % 4];
				const l = salaGirar(q.x, q.z, -yo);
				return { st: q.st, x: l[0], z: l[1], yaw: q.yaw - (yo * Math.PI) / 2, p: q.pitch || 0, c: e.caidoHasta[(k + yo) % 4] > e.tick, hy: q.st === 0 ? q.hy || 0 : 0, hp: q.st === 0 ? q.hp || 0 : 0, a: q.st === 2 && q.a === true };
			});
			const tapado = [0, 1, 2, 3].map((k) => e.tapado[(k + yo) % 4]);
			dispatcher.broadcastMessage(OP_POSES, JSON.stringify({ poses: poses, tapado: tapado }), [pr], null, true);
		}
	}
	const firma = salaFirmaMiradas(e);
	if (firma !== e.miradas) {
		e.miradas = firma;
		return true; // la mesa de alguien cambia: ahora ve (o deja de ver) unas fichas
	}
	return false;
}

function salaAnunciarEntrada(e: EstadoSala, s: number): void {
	e.porAnunciar[s] = 0;
	salaAviso(e, "joined", s, { name: salaNombre(e, s) });
}

/** Chat rápido: solo ids de SALA_FRASES y como mucho una cada T_FRASE segundos. */
function salaFrase(e: EstadoSala, s: number, d: any, dispatcher: nkruntime.MatchDispatcher): boolean {
	const id = String(d && d.id !== undefined ? d.id : "");
	const pr = e.seats[s].presence;
	if (!Object.prototype.hasOwnProperty.call(SALA_FRASES, id)) {
		if (pr !== null) dispatcher.broadcastMessage(OP_AVISO, JSON.stringify({ text: "Esa frase no existe" }), [pr], null, true);
		return false;
	}
	if (e.tick - e.ultimaFrase[s] < T_FRASE * SALA_TICK) return false; // demasiado seguido: se ignora
	e.ultimaFrase[s] = e.tick;
	salaAviso(e, "frase", s, { id: id, text: SALA_FRASES[id] });
	return true;
}

function salaFicha(t: any): Ficha | null {
	if (!Array.isArray(t) || t.length !== 2) return null;
	const a = t[0], b = t[1];
	if (!salaEntero(a, 0, 6) || !salaEntero(b, 0, 6)) return null;
	return [a, b];
}

/** Jugada normal si casa en ese lado; si no, es un chivo (el cliente arrastra a cualquier punta). */
function rJugarOChivo(g: Estado, s: number, t: Ficha, side: number): boolean {
	// la misma regla que el juego: si casa en esa punta (también con las dos puntas iguales) es jugada
	if (g.chain.length === 0 || rCasa(g, t, side < 0 ? -1 : 1)) return rJugar(g, s, t, g.chain.length === 0 ? 0 : side < 0 ? -1 : 1);
	return rMeterChivo(g, s, t, side);
}

function salaEmpezar(e: EstadoSala): void {
	const bots = [0, 1, 2, 3].map((s) => salaEsBot(e, s));
	for (let i = 0; i < 4; i++) {
		if (e.seats[i].userId === null) e.seats[i].name = SALA_BOT_NOMBRE[i];
	}
	e.game = rNuevaPartida(bots, e.modo, e.meta);
	e.listos = [false, false, false, false];
	e.revancha = [false, false, false, false];
	e.faseVista = "";
	e.turnosVistos = 0;
	e.eventosVistos = 0;
	salaReloj(e);
}

/**
 * Reinicia el reloj cuando empieza una fase o un turno nuevo (venga el cambio
 * de un mensaje, de un bot o de un tiempo agotado). Se llama antes de mandar
 * cada vista, así `secs` y `turn_deadline_secs` siempre son los de ahora.
 */
function salaReloj(e: EstadoSala): void {
	const g = e.game;
	if (g === null) {
		e.faseVista = "";
		e.total = 0;
		e.deadline = e.tick;
		return;
	}
	// cada jugada o pase abre un turno nuevo (aunque vuelva a la misma silla)
	for (let i = e.eventosVistos; i < g.events.length; i++) {
		const k = g.events[i].k;
		if (k === "play" || k === "pass" || k === "again") e.turnosVistos++;
	}
	e.eventosVistos = g.events.length;
	let clave = g.hand_no + ":" + g.phase;
	if (g.phase === "play") clave += ":" + e.turnosVistos + ":" + g.turn;
	if (clave === e.faseVista) return;
	e.faseVista = clave;
	let total = 0;
	let bot = 0;
	if (g.phase === "pick") {
		total = T_CARTA;
		bot = T_BOT_CARTA;
	} else if (g.phase === "draw") {
		total = T_ROBAR;
		bot = T_BOT_ROBO;
	} else if (g.phase === "play") {
		// pasar es decisión del jugador (los demás ven que no lleva): no pasa solo
		total = salaAusente(e, g.turn) ? T_AUSENTE : T_TURNO;
		bot = T_BOT_TURNO;
	} else if (g.phase === "shop") {
		// tras un tranque, su pantalla (hasta 30 s) va antes de la tienda
		total = T_TIENDA; // tras un tranque no corre hasta que acaba su flujo (salaTranque)
		e.tranqueOk = [false, false, false, false];
		e.listos = [false, false, false, false];
		e.revancha = [false, false, false, false];
	} else if (g.phase === "over") {
		total = 0; // la revancha no tiene tiempo
		e.tranqueOk = [false, false, false, false];
		e.listos = [false, false, false, false];
		e.revancha = [false, false, false, false];
	}
	e.total = total;
	e.deadline = e.tick + total * SALA_TICK;
	e.botWait = e.tick + bot * SALA_TICK;
	e.congelado = 0;
}

/** Le toca a una persona que está de pie: su reloj se para (hasta T_CONGELADO). */
function salaRelojParado(e: EstadoSala): boolean {
	const g = e.game;
	if (g === null || g.phase !== "play" || g.revision !== null) return false;
	const s = g.turn;
	if (salaEsBot(e, s) || salaAusente(e, s)) return false;
	return e.poses[s].st !== 0 && e.congelado < T_CONGELADO * SALA_TICK;
}

/** Bots, tiempos límite y cambios de fase. Devuelve true si cambió algo. */
function salaAvanzar(e: EstadoSala): boolean {
	const g = e.game as Estado;
	const t = e.tick;
	salaReloj(e);
	const vence = t >= e.deadline;
	const botListo = t >= e.botWait;
	if (g.phase === "pick") {
		let cambio = false;
		for (let s = 0; s < 4; s++) {
			if (g.picked[s]) continue;
			const bot = salaEsBot(e, s);
			const aus = salaAusente(e, s) && t >= salaInicio(e) + T_AUSENTE * SALA_TICK;
			if (bot ? botListo || vence : vence || aus) {
				if (!bot && !aus) salaFalloTiempo(e, s);
				rBotEligeCarta(g, s);
				cambio = true;
			}
		}
		return cambio;
	}
	if (g.phase === "draw") {
		if (!botListo && !vence) return false;
		let cambio = false;
		for (let s = 0; s < 4; s++) {
			if ((g.phase as string) !== "draw") break;
			if (rFichasRobadas(g, s) >= 7) continue;
			const aus = salaAusente(e, s) && t >= salaInicio(e) + T_AUSENTE * SALA_TICK;
			if ((vence || aus) && !salaEsBot(e, s)) {
				// se le acabó el tiempo (o está ausente): se le reparten de golpe las que le faltan
				if (!aus) salaFalloTiempo(e, s);
				while ((g.phase as string) === "draw" && rFichasRobadas(g, s) < 7) rRobarAzar(g, s);
				cambio = true;
			} else if (salaEsBot(e, s) || vence) {
				rRobarAzar(g, s);
				cambio = true;
			}
		}
		e.botWait = t + T_BOT_ROBO * SALA_TICK;
		return cambio;
	}
	if (g.phase === "play") {
		// revisión de un «¡Ute va!»: 25 s; si se acaba (o se fue), decide la verdad
		if (g.revision !== null) {
			if (e.revFin === 0) e.revFin = t + T_REVISION * SALA_TICK;
			if (t >= e.revFin || salaEsBot(e, g.revision.caller)) {
				rResolverRevision(g, g.revision.caller, null);
				e.revFin = 0;
				return true;
			}
			return false;
		}
		e.revFin = 0;
		const s = g.turn;
		// muerto en su turno: el turno espera (un bot vuelve solo; una persona,
		// hasta T_MUERTO; después corre su reloj y juega su bot)
		if (e.muerto && e.muertoDesde && e.muerto[s]) {
			if (salaEsBot(e, s)) return false;
			if (t - e.muertoDesde[s] < T_MUERTO * SALA_TICK) {
				e.deadline++;
				return t % SALA_TICK === 0;
			}
		}
		if (salaEsBot(e, s)) {
			if (t < e.botWait) return false;
			rTurnoBot(g);
			return true;
		}
		const parado = salaRelojParado(e);
		const avisar = parado !== e.paradoVisto; // se paró o vuelve a correr: todos lo ven ya
		e.paradoVisto = parado;
		if (parado) {
			// de pie en su turno: el reloj no corre; los demás esperan o lo sientan de un manotazo
			e.congelado++;
			e.deadline++;
			return avisar || e.congelado % SALA_TICK === 1; // la vista, al pararse y una vez por segundo
		}
		if (avisar) return true;
		if (t >= e.deadline) {
			if (salaAusente(e, s)) {
				// ausente: pasaron sus 5 s; juega (o pasa) su bot este turno, sin chivos ni bebidas
				rJugadaAutomatica(g);
				return true;
			}
			salaFalloTiempo(e, s); // queda ausente
			if (rJugadas(g, s).length === 0) {
				// pasar es decisión del jugador: no se pasa por él al momento; queda
				// ausente y tiene T_AUSENTE más (luego pasa su bot)
				e.deadline = t + T_AUSENTE * SALA_TICK;
				e.total = T_AUSENTE;
				return true;
			}
			rJugadaAutomatica(g);
			return true;
		}
		return false;
	}
	if (g.phase === "shop") {
		// tranque: la tienda no corre hasta que se revelen y entreguen las fichas
		if (salaTranqueActivo(e) || salaVerActivo(e)) {
			e.deadline = e.tick + T_TIENDA * SALA_TICK;
			e.listos = [false, false, false, false];
			return false;
		}
		let todos = true;
		for (let s = 0; s < 4; s++) if (!salaEsBot(e, s) && !salaAusente(e, s) && !e.listos[s]) todos = false; // el ausente no hace esperar
		if (todos || vence) {
			rNuevaMano(g);
			e.listos = [false, false, false, false];
			return true;
		}
		return false;
	}
	if (g.phase === "over") {
		let humanos = 0, votos = 0;
		for (let s = 0; s < 4; s++) {
			if (!salaEsBot(e, s) && !salaAusente(e, s)) {
				humanos++;
				if (e.revancha[s]) votos++;
			}
		}
		if (humanos > 0 && votos === humanos) {
			salaEmpezar(e);
			return true;
		}
	}
	return false;
}

// ---------------------------------------------------------------- verificar dominó y capicúa (V1)

/** ¿Se está verificando el cierre de la mano? La tienda y la cuenta esperan. */
function salaVerActivo(e: EstadoSala): boolean {
	return !!e.ver && !e.ver.fin && e.game !== null && e.game.hand_no === e.ver.mano;
}

/** Cada tick: empieza al acabar en dominó y se cierra con todos VISTO o al vencer. */
function salaVer(e: EstadoSala): boolean {
	const g = e.game;
	if (g === null || (g.phase !== "shop" && g.phase !== "over") || !g.last_result || g.last_result.reason !== "dominó") return false;
	if (!e.ver || e.ver.mano !== g.hand_no) {
		e.ver = { mano: g.hand_no, hasta: e.tick + T_VER * SALA_TICK, ok: [false, false, false, false], reclamo: -1, fin: false };
		return true;
	}
	const v = e.ver;
	if (v.fin) return false;
	let todos = true;
	for (let s = 0; s < 4; s++) if (!v.ok[s] && !salaTqAutomatico(e, s)) todos = false;
	if (todos || e.tick >= v.hasta) {
		v.fin = true;
		if (g.phase === "shop") {
			e.total = T_TIENDA;
			e.deadline = e.tick + T_TIENDA * SALA_TICK;
		}
		return true;
	}
	return false;
}

function salaVerMensaje(e: EstadoSala, s: number, d: any): boolean {
	if (!salaVerActivo(e)) return false;
	const v = e.ver!;
	if (d.reclamar === true && v.reclamo < 0) {
		// el colmadero vuelve a enseñar la última jugada y las puntas; luego cuenta como visto
		v.reclamo = s;
		v.hasta = Math.max(v.hasta, e.tick + T_VER_RECLAMO * SALA_TICK);
		salaAviso(e, "reclamo", s, {});
	}
	if (v.ok[s]) return d.reclamar === true;
	v.ok[s] = true;
	return true;
}

// ---------------------------------------------------------------- tranque con suspenso

/** ¿Está en marcha el flujo del tranque (revelar, visto o entregar)? La tienda espera. */
function salaTranqueActivo(e: EstadoSala): boolean {
	return !!e.tq && e.tq.etapa !== "fin" && e.game !== null && e.game.hand_no === e.tq.mano;
}

/** Quien no puede decidir (bot, ausente o desconectado): el servidor juega por él. */
function salaTqAutomatico(e: EstadoSala, s: number): boolean {
	return salaEsBot(e, s) || salaAusente(e, s) || e.seats[s].presence === null;
}

/** Empieza el flujo cuando una mano acaba en tranque. */
function salaTranqueEmpezar(e: EstadoSala): boolean {
	const g = e.game;
	if (g === null || (g.phase !== "shop" && g.phase !== "over") || !g.last_result || g.last_result.reason !== "tranque") return false;
	if (e.tq && e.tq.mano === g.hand_no) return false;
	const orden: number[] = [];
	for (let k = 0; k < 4; k++) orden.push((g.last_seat + k) % 4); // empieza quien trancó
	e.tq = {
		mano: g.hand_no,
		etapa: "revelar",
		orden: orden,
		i: 0,
		rev: [[], [], [], []],
		auto: e.tick + T_TQ_INTRO * SALA_TICK,
		hasta: e.tick + (T_TQ_INTRO + T_TQ_TURNO) * SALA_TICK,
		entregadas: [false, false, false, false],
		ganador: g.last_result.seat,
		scoresAntes: g.scores.slice(),
	};
	// los puntos aún no se ven: el marcador de antes de la mano
	const eq = g.last_result.team;
	e.tq.scoresAntes[eq] = Math.max(0, g.scores[eq] - g.last_result.pts);
	e.tranqueOk = [false, false, false, false];
	return true;
}

/** Gira la siguiente ficha sin girar de la silla s (la de más a la izquierda). */
function salaTqRevelarSiguiente(e: EstadoSala, s: number): boolean {
	const g = e.game!;
	const tq = e.tq!;
	for (let i = 0; i < g.hands[s].length; i++) {
		if (tq.rev[s].indexOf(i) < 0) return salaTqRevelar(e, s, i);
	}
	return false;
}

function salaTqRevelar(e: EstadoSala, s: number, i: number): boolean {
	const g = e.game!;
	const tq = e.tq!;
	if (i < 0 || i >= g.hands[s].length || tq.rev[s].indexOf(i) >= 0) return false;
	tq.rev[s].push(i);
	const ultima = salaTqUltima(e);
	if (ultima) tq.finEn = e.tick + T_TQ_FINAL * SALA_TICK; // que se vea el giro lento
	salaAviso(e, "revela", s, { idx: i, tile: g.hands[s][i], ultima: ultima });
	return true;
}

/** ¿Era la última ficha de todo el tranque? (la que decide: va a cámara lenta) */
function salaTqUltima(e: EstadoSala): boolean {
	const g = e.game!;
	const tq = e.tq!;
	for (let s = 0; s < 4; s++) if (tq.rev[s].length < g.hands[s].length) return false;
	return true;
}

/** Cada tick: turnos de revelar, VISTO y entregar. Devuelve true si cambió algo. */
function salaTranque(e: EstadoSala): boolean {
	let cambio = salaTranqueEmpezar(e);
	if (!salaTranqueActivo(e)) return cambio;
	const g = e.game!;
	const tq = e.tq!;
	const t = e.tick;
	if (tq.etapa === "revelar") {
		if (t < tq.auto) return cambio;
		const s = tq.orden[tq.i];
		if (tq.rev[s].length >= g.hands[s].length) {
			// terminó su turno: pausa y le toca al siguiente
			if (tq.i >= 3 && tq.finEn && t < tq.finEn) return cambio; // aún se está girando la última
			tq.i++;
			if (tq.i >= 4) {
				tq.etapa = "visto";
				tq.hasta = t + T_TRANQUE * SALA_TICK;
				e.tranqueOk = [false, false, false, false];
				salaAviso(e, "tq_ganador", tq.ganador, {});
			} else {
				tq.auto = t + T_TQ_ENTRE * SALA_TICK;
				tq.hasta = tq.auto + T_TQ_TURNO * SALA_TICK;
			}
			return true;
		}
		if (salaTqAutomatico(e, s)) {
			// a veces amaga antes de girar (como haría una persona)
			if (salaEsBot(e, s) && Math.random() < 0.25 && !tq.amagoBot) {
				tq.amagoBot = true;
				salaAviso(e, "amago", s, { idx: tq.rev[s].length });
				tq.auto = t + T_TQ_BOT * SALA_TICK;
				return true;
			}
			tq.amagoBot = false;
			salaTqRevelarSiguiente(e, s);
			tq.auto = t + T_TQ_BOT * SALA_TICK;
			return true;
		}
		if (t >= tq.hasta) {
			// tardó demasiado: se giran solas, una a una
			salaTqRevelarSiguiente(e, s);
			tq.auto = t + T_TQ_AUTO * SALA_TICK;
			return true;
		}
		return cambio;
	}
	if (tq.etapa === "visto") {
		let todos = true;
		for (let s = 0; s < 4; s++) if (!e.tranqueOk[s] && !salaTqAutomatico(e, s)) todos = false;
		if (todos || t >= tq.hasta) {
			tq.etapa = "entregar";
			tq.hasta = t + T_TQ_ENTREGAR * SALA_TICK;
			tq.auto = t + T_TQ_BOT * SALA_TICK;
			tq.entregadas[tq.ganador] = true; // las suyas ya están delante de él
			return true;
		}
		return cambio;
	}
	if (tq.etapa === "entregar") {
		let quedan = false;
		for (let s = 0; s < 4; s++) if (!tq.entregadas[s]) quedan = true;
		if (!quedan) {
			tq.etapa = "fin";
			if (g.phase === "shop") {
				e.total = T_TIENDA;
				e.deadline = t + T_TIENDA * SALA_TICK;
			}
			return true;
		}
		// se acabó el tiempo: el ganador se queda con todas las que falten a la vez
		if (t >= tq.hasta) {
			for (const s of tq.orden) if (!tq.entregadas[s]) salaTqEntregar(e, s, true);
			return true;
		}
		if (t < tq.auto) return cambio;
		// bots que pierden: entregan; ganador bot: arrebata
		for (const s of tq.orden) {
			if (tq.entregadas[s]) continue;
			if (salaTqAutomatico(e, s) && !salaTqAutomatico(e, tq.ganador)) {
				salaTqEntregar(e, s, false);
				tq.auto = t + T_TQ_BOT * SALA_TICK;
				return true;
			}
			if (salaTqAutomatico(e, tq.ganador)) {
				salaTqEntregar(e, s, true);
				tq.auto = t + T_TQ_BOT * SALA_TICK;
				return true;
			}
		}
		return cambio;
	}
	return cambio;
}

/** Las fichas de s pasan al ganador: entregadas (s las da) o arrebatadas (el ganador las toma). */
function salaTqEntregar(e: EstadoSala, s: number, arrebata: boolean): boolean {
	const tq = e.tq!;
	if (tq.entregadas[s]) return false;
	tq.entregadas[s] = true;
	if (arrebata) salaAviso(e, "arrebata", tq.ganador, { target: s });
	else salaAviso(e, "entrega", s, { target: tq.ganador });
	return true;
}

/** Mensajes del flujo del tranque. */
function salaTranqueMensaje(e: EstadoSala, s: number, op: number, d: any): boolean {
	if (!salaTranqueActivo(e)) return false;
	const tq = e.tq!;
	if (op === OP_REVELAR) {
		if (tq.etapa !== "revelar" || tq.orden[tq.i] !== s || e.tick < tq.auto - T_TQ_ENTRE * SALA_TICK) return false;
		if (!salaTqRevelar(e, s, Number(d.idx))) return false;
		tq.hasta = e.tick + T_TQ_TURNO * SALA_TICK;
		tq.auto = e.tick + T_TQ_MIN * SALA_TICK; // un respiro entre ficha y ficha
		return true;
	}
	if (op === OP_AMAGO) {
		if (tq.etapa !== "revelar" || tq.orden[tq.i] !== s) return false;
		if (e.tick - e.ultimaFrase[s] < 1 * SALA_TICK) return false;
		e.ultimaFrase[s] = e.tick;
		tq.hasta = e.tick + T_TQ_TURNO * SALA_TICK;
		salaAviso(e, "amago", s, { idx: Number(d.idx) });
		return true;
	}
	if (op === OP_ENTREGAR) {
		if (tq.etapa !== "entregar" || s === tq.ganador) return false;
		return salaTqEntregar(e, s, false);
	}
	if (op === OP_ARREBATAR) {
		if (tq.etapa !== "entregar" || s !== tq.ganador) return false;
		return salaTqEntregar(e, (s + Number(d.seat)) % 4, true);
	}
	return false;
}

/** Lo que ve cada uno del tranque (sillas giradas). */
function salaTranqueVista(e: EstadoSala, yo: number): any {
	if (!salaTranqueActivo(e) && !(e.tq && e.game && e.game.hand_no === e.tq.mano)) return null;
	const tq = e.tq!;
	const glob = (k: number) => (k + yo) % 4;
	return {
		etapa: tq.etapa,
		turno: tq.etapa === "revelar" ? salaRot(tq.orden[Math.min(tq.i, 3)], yo) : -1,
		orden: tq.orden.map((s) => salaRot(s, yo)),
		rev: [0, 1, 2, 3].map((k) => tq.rev[glob(k)].slice()),
		secs: Math.max(0, Math.ceil((tq.hasta - e.tick) / SALA_TICK)),
		entregadas: [0, 1, 2, 3].map((k) => tq.entregadas[glob(k)]),
		ganador: tq.etapa === "revelar" ? -1 : salaRot(tq.ganador, yo),
	};
}

// ---------------------------------------------------------------- lo que ve cada jugador

function salaEnviarTodo(e: EstadoSala, dispatcher: nkruntime.MatchDispatcher, nk: nkruntime.Nakama): void {
	salaReloj(e); // el reloj de la vista siempre es el de la fase/turno de ahora
	const eventos = (e.game !== null ? e.game.events : []).concat(e.avisos);
	for (let s = 0; s < 4; s++) {
		const pr = e.seats[s].presence;
		if (pr === null) continue;
		dispatcher.broadcastMessage(OP_ESTADO, JSON.stringify(salaVista(e, s, eventos)), [pr], null, true);
	}
	if (e.game !== null) e.game.events = [];
	e.eventosVistos = 0;
	e.avisos = [];
}

/** Eventos girados para que la silla de quien los recibe sea la 0. */
function salaEventosGirados(eventos: Evento[], yo: number): any[] {
	return eventos.map((ev) => {
		const c: any = {};
		for (const k in ev) c[k] = ev[k];
		c.seat = salaRot(ev.seat, yo);
		if (ev.by !== undefined) c.by = salaRot(ev.by, yo);
		if (ev.cheater !== undefined) c.cheater = salaRot(ev.cheater, yo);
		if (ev.accused !== undefined) c.accused = salaRot(ev.accused, yo);
		if (ev.target !== undefined) c.target = salaRot(ev.target, yo);
		if (ev.o !== undefined && ev.n !== undefined) {
			const lo = salaGirar(ev.o[0], ev.o[2], -yo), ln = salaGirar(ev.n[0], ev.n[2], -yo);
			c.o = [lo[0], ev.o[1], lo[1]];
			c.n = [ln[0], ev.n[1], ln[1]];
		}
		if (ev.px !== undefined) {
			const l = salaGirar(ev.px, ev.pz, -yo);
			c.px = l[0];
			c.pz = l[1];
		}
		// acusación falsa de renuncio: la mano del acusado solo la ve quien acusó
		if (ev.hand !== undefined && ev.seat !== yo) delete c.hand;
		return c;
	});
}

function salaVista(e: EstadoSala, yo: number, eventos: Evento[]): any {
	const r = (s: number) => salaRot(s, yo);
	const glob = (k: number) => (k + yo) % 4; // silla local k → silla del servidor
	const sillas = [0, 1, 2, 3].map((k) => {
		const x = e.seats[glob(k)];
		const bot = x.userId === null;
		return {
			name: bot ? SALA_BOT_NOMBRE[glob(k)] : x.name,
			avatar: bot ? null : x.avatar,
			preset: SALA_BOT_CARA[glob(k)],
			bot: bot,
			connected: x.presence !== null,
			host: x.userId !== null && x.userId === e.host,
			away: e.ausente[glob(k)], // ausente: juega su bot hasta que mande algo
		};
	});
	const v: any = {
		code: e.code,
		modo: e.modo || "aumentos",
		meta: e.meta || 100,
		yo: yo, // tu silla en la sala: el colmado se ve girado desde ella
		// nombres de equipo: [el tuyo, el de los rivales] ("" = NOSOTROS/ELLOS)
		equipos: e.equipos ? [e.equipos[yo % 2], e.equipos[(yo + 1) % 2]] : ["", ""],
		sillas_sala: true, // este servidor entiende LISTO, cambio de silla y acuerdo del nombre
		de_pie: true, // este servidor entiende OP_POSE / OP_EMOTE / OP_TAPAR
		manos: true, // y OP_MANO (lo que hace cada uno con sus fichas)
		armas: e.armas === true, // la sala permite armas
		vida: e.vida ? [0, 1, 2, 3].map((k) => e.vida![glob(k)]) : [100, 100, 100, 100],
		muertos: e.muerto ? [0, 1, 2, 3].map((k) => e.muerto![glob(k)]) : [false, false, false, false],
		balas: e.balas ? e.balas[yo] : 0,
		armas_de: e.armaDe ? [0, 1, 2, 3].map((k) => e.armaDe![glob(k)]) : ["pistola", "pistola", "pistola", "pistola"], // el arma de cada uno (la ven los demás)
		me_host: e.seats[yo].userId === e.host,
		seats: sillas,
		secs: Math.max(0, Math.ceil((e.deadline - e.tick) / SALA_TICK)), // lo que queda de la fase o del turno
		turn_deadline_secs: e.total, // el total de esa fase o turno (para la barra)
		reloj_parado: salaRelojParado(e), // le toca y está de pie: su reloj no corre
		// radio de la sala: qué suena y cuántos segundos lleva (todos en el mismo punto)
		radio: e.radio ? { on: e.radio.on, pista: e.radio.pista, t: (e.tick - e.radio.inicio) / SALA_TICK } : { on: true, pista: 0, t: e.tick / SALA_TICK },
	};
	const g = e.game;
	if (g === null) {
		v.phase = "lobby";
		v.secs = 0;
		v.turn_deadline_secs = 0;
		v.listos_sala = [0, 1, 2, 3].map((k) => salaListos(e)[glob(k)]);
		v.todos_listos = salaTodosListos(e);
		// nombre de cada pareja: [la tuya, la rival], con sillas locales
		const ns = salaNombres(e);
		v.nombres = [yo % 2, (yo + 1) % 2].map((p) => ({
			estado: ns[p].estado,
			nombre: ns[p].nombre,
			propone: ns[p].propone >= 0 ? r(ns[p].propone) : -1,
			turno: ns[p].turno >= 0 ? r(ns[p].turno) : -1,
			rechazado: p === yo % 2 ? ns[p].rechazado : "",
			humanos: salaHumanosPareja(e, p).length,
		}));
		const pe = e.peticion;
		v.peticion = pe ? { de: r(pe.de), a: r(pe.a), secs: Math.max(0, Math.ceil((pe.hasta - e.tick) / SALA_TICK)), total: T_PETICION_SILLA } : null;
		v.events = salaEventosGirados(eventos, yo);
		return v;
	}
	const mismaPareja = yo % 2 === 0;
	const parejas = (a: number[]) => (mismaPareja ? a.slice() : [a[1], a[0]]);
	const finMano = g.phase === "shop" || g.phase === "over";
	v.phase = g.phase;
	v.hand_no = g.hand_no;
	v.first_hand = g.first_hand;
	v.turn = r(g.turn);
	v.opener = r(g.opener);
	v.last_seat = r(g.last_seat);
	v.last_pass_seat = g.last_pass_seat >= 0 ? r(g.last_pass_seat) : -1; // para el botón «¡Ute va!»
	v.chain = g.chain;
	v.origin = g.origin;
	v.left_end = g.left_end;
	v.right_end = g.right_end;
	const tqv = salaTranqueVista(e, yo);
	const revelando = tqv !== null && tqv.etapa === "revelar";
	v.tranque = tqv;
	v.scores = parejas(revelando ? e.tq!.scoresAntes : g.scores);
	v.extra_turn = g.extra_turn && g.turn === yo;
	v.reveal_partner = g.reveal_partner[yo];
	v.revealed = g.revealed[yo];
	// pases que recuerda este jugador de cada silla (todos los de los rivales con Ficha marcada)
	v.pases = [0, 1, 2, 3].map((k) => Object.keys(rPasesVistos(g, yo, glob(k))).map(Number).sort());
	v.coins = [0, 1, 2, 3].map((k) => g.coins[glob(k)]);
	v.cards = [0, 1, 2, 3].map((k) => g.cards[glob(k)]);
	v.drinks = [0, 1, 2, 3].map((k) => g.drinks[glob(k)]);
	v.offers = g.picked[yo] ? [] : g.offers[yo];
	v.picked = [0, 1, 2, 3].map((k) => g.picked[glob(k)]);
	v.listos = [0, 1, 2, 3].map((k) => e.listos[glob(k)]);
	// pantalla del tranque: quién la dio por vista (los bots y los ausentes cuentan como vista)
	if (salaVerActivo(e)) {
		const vr = e.ver!;
		v.ver = {
			ok: [0, 1, 2, 3].map((k) => vr.ok[glob(k)] || salaTqAutomatico(e, glob(k))),
			reclamo: vr.reclamo < 0 ? -1 : [0, 1, 2, 3].find((k) => glob(k) === vr.reclamo),
			quedan: Math.max(0, Math.ceil((vr.hasta - e.tick) / SALA_TICK)),
		};
	}
	v.tranque_ok = [0, 1, 2, 3].map((k) => e.tranqueOk[glob(k)] || salaEsBot(e, glob(k)) || salaAusente(e, glob(k)));
	// Misma rotación que seats: solo solicitudes de personas, nunca bots.
	v.revancha = [0, 1, 2, 3].map((k) => g.phase === "over" && e.seats[glob(k)].userId !== null && e.revancha[glob(k)]);
	// manos: la propia entera; las demás, solo lo que se ve (huecos = null)
	v.hands = [0, 1, 2, 3].map((k) => {
		const s = glob(k);
		const revisa = g.revision !== null && g.revision.caller === yo && g.revision.accused === s; // «¡Ute va!»: ve las fichas del acusado
		const ve = s === yo || (finMano && !revelando) || revisa || (g.reveal_partner[yo] && s === (yo + 2) % 4) || salaVeFichas(e, yo, s);
		// tranque: de los demás solo las que ya giró cada uno
		return g.hands[s].map((t, i) => (ve || (revelando && e.tq!.rev[s].indexOf(i) >= 0) || rIndice(g.revealed[yo], t) >= 0 ? t : null));
	});
	const tomado: { [idx: string]: number } = {};
	for (const k in g.pool_taken) tomado[k] = r(g.pool_taken[k]);
	v.pool_taken = tomado;
	// las fichas que YA cogiste del montón, de cara (solo las tuyas): las ves en tu bandeja
	const mias: { [idx: string]: Ficha } = {};
	if (g.phase === "draw") for (const k in g.pool_taken) if (g.pool_taken[k] === yo && g.pool[Number(k)]) mias[k] = g.pool[Number(k)].slice() as Ficha;
	v.mis_robo = mias;
	v.robo_orden = (g.robo_orden ?? []).slice(); // para que cada ficha caiga en su hueco
	if (g.last_result !== null && revelando) {
		v.last_result = { seat: -1, team: -1, pts: 0, reason: "tranque", bonus: [], capicua: false, oculto: true };
	} else if (g.last_result !== null) {
		const lr = g.last_result;
		v.last_result = { seat: r(lr.seat), team: (lr.team + yo) % 2, pts: lr.pts, reason: lr.reason, bonus: lr.bonus, capicua: lr.capicua };
		// tranque: puntos de cada uno y de cada pareja, girados para quien mira
		if (lr.tranque) {
			const tq = lr.tranque;
			v.last_result.tranque = {
				pips: [0, 1, 2, 3].map((k) => tq.pips[(k + yo) % 4]),
				teams: [tq.teams[yo % 2], tq.teams[(yo + 1) % 2]],
				tie: tq.tie,
				opener: r(tq.opener),
			};
		}
	}
	v.bot_purchases = g.bot_purchases.map((b: any[]) => [r(b[0]), b[1]]);
	v.revision = g.revision === null ? null : { caller: r(g.revision.caller), accused: r(g.revision.accused), secs: Math.max(0, Math.ceil((e.revFin - e.tick) / SALA_TICK)) };
	const st: any = {};
	for (const k in g.stats) st[k] = parejas(g.stats[k]);
	v.stats = st;
	// tranque: el «end» no dice aún quién gana ni cuántos puntos
	v.events = salaEventosGirados(eventos, yo).map((ev: any) => {
		if (ev.k === "end" && g.last_result && g.last_result.reason === "tranque") {
			ev.seat = -1;
			ev.pts = 0;
			ev.tranque = true;
		}
		return ev;
	});
	return v;
}
