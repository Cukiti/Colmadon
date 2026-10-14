// Prueba de las reglas del servidor (como tests/prueba_logica.gd): partidas
// completas solo con bots comprobando que no se pierden fichas y que la
// línea casa. Uso: npm test
declare const process: any;

let fallos = 0;
function fallo(msg: string): void {
	fallos++;
	if (fallos <= 10) console.log("FALLO " + msg);
}

function comprobar(p: Estado): void {
	if (p.phase !== "play") return;
	let n = p.chain.length;
	for (let s = 0; s < 4; s++) n += p.hands[s].length;
	if (n !== 28) fallo("hay " + n + " fichas en juego en vez de 28");
	const vistas: { [k: string]: boolean } = {};
	const todas = p.chain.slice();
	for (let s = 0; s < 4; s++) for (const t of p.hands[s]) todas.push(t);
	for (const t of todas) {
		const k = Math.min(t[0], t[1]) + "-" + Math.max(t[0], t[1]);
		if (vistas[k]) fallo("ficha repetida " + k);
		vistas[k] = true;
	}
	if (p.chain.length > 0) {
		if (p.chain[0][0] !== p.left_end) fallo("punta izquierda no coincide");
		if (p.chain[p.chain.length - 1][1] !== p.right_end) fallo("punta derecha no coincide");
	}
}

const finales: { [k: string]: number } = {};
let manos = 0;
const PARTIDAS = 3000;
let maxManos = 0;
for (let n = 0; n < PARTIDAS; n++) {
	const p = rNuevaPartida([true, true, true, true]);
	let guarda = 0;
	while (p.phase !== "over" && guarda < 20000) {
		guarda++;
		if (p.phase === "pick") {
			for (let s = 0; s < 4; s++) if (!p.picked[s]) rBotEligeCarta(p, s);
		} else if (p.phase === "draw") {
			// por turnos, como en la mesa
			for (let s = 0; s < 4; s++) if (rFichasRobadas(p, s) < 7) rRobarAzar(p, s);
		} else if (p.phase === "play") {
			const antes = p.chain.length;
			rTurnoBot(p);
			comprobar(p);
			const ultimo = p.events[p.events.length - 1];
			if (ultimo && ultimo.k === "play" && !ultimo.chivo && p.chain.length === antes) fallo("jugada sin ficha nueva");
		} else if (p.phase === "shop") {
			manos++;
			finales[p.last_result.reason] = (finales[p.last_result.reason] || 0) + 1;
			rNuevaMano(p);
		}
		p.events = [];
	}
	if (p.phase !== "over") fallo("partida sin terminar");
	else {
		manos++;
		finales[p.last_result.reason] = (finales[p.last_result.reason] || 0) + 1;
		maxManos = Math.max(maxManos, p.hand_no);
		if (Math.max(p.scores[0], p.scores[1]) < p.meta) fallo("terminó sin llegar a la meta");
	}
}
const pc = (k: string) => (100 * (finales[k] || 0) / manos).toFixed(1) + " %";
console.log("PARTIDAS " + PARTIDAS + " · manos " + manos + " · media " + (manos / PARTIDAS).toFixed(2) + " manos (máx " + maxManos + ")");
console.log("FINALES dominó " + pc("dominó") + " · tranque " + pc("tranque") + " · chivo " + pc("chivo"));

// reglas sueltas
const q = rNuevaPartida([false, true, true, true]);
for (let s = 0; s < 4; s++) rElegirCarta(q, s, q.offers[s][0]);
if (q.phase !== "draw") fallo("no pasa a robar tras elegir las 4 cartas");
if (rRobar(q, 0, 3) !== true || rRobar(q, 1, 3) !== false) fallo("se puede robar una ficha ya cogida");
for (let i = 0; i < 6; i++) rRobarAzar(q, 0);
if (rRobarAzar(q, 0)) fallo("se pueden robar más de 7");
for (let s = 1; s < 4; s++) for (let i = 0; i < 7; i++) rRobarAzar(q, s);
if (q.phase !== "play") fallo("no empieza la mano tras robar 28");
const dobleQueNoCasa = q.hands[q.turn].filter((t) => t[0] === t[1] && !(t[0] === 6));
if (rMeterChivo(q, q.turn, [6, 6], 1)) fallo("chivo con la mesa vacía");
if (q.turn !== 0 && rJugar(q, 0, q.hands[0][0], 1)) fallo("se puede jugar fuera de turno");

// cartas nuevas: Ficha marcada, Doble suerte y Tranque seguro
function mesa(cartas: string[][], manos: Ficha[][], cadena: Ficha[], ultimo: number, turno: number): Estado {
	const m = rNuevaPartida([true, true, true, true]);
	m.phase = "play";
	m.first_hand = false;
	m.cards = cartas;
	m.hands = manos;
	m.chain = cadena;
	m.left_end = cadena[0][0];
	m.right_end = cadena[cadena.length - 1][1];
	m.last_seat = ultimo;
	m.turn = turno;
	return m;
}
// Tranque por parejas (2026-10-04): pareja 0 = 1 + 23, pareja 1 = 2 + 2 → gana la pareja 1 (sale la silla 1)
const manosTranque = (): Ficha[][] => [[[0, 1]], [[0, 2]], [[6, 6], [5, 6]], [[1, 1]]];
let t1 = mesa([[], [], [], []], manosTranque(), [[4, 4]], 0, 0);
rTerminarMano(t1, -1, [-1, -1], false, -1, "");
if (t1.last_result.team !== 1 || t1.last_result.seat !== 1 || JSON.stringify(t1.last_result.tranque.teams) !== "[24,4]") fallo("tranque por parejas: " + JSON.stringify(t1.last_result));
// empate 3-3: gana la pareja que salió (la del 1) y sale quien salió
const manosEmpate = (): Ficha[][] => [[[0, 3]], [[0, 1]], [[0, 0]], [[0, 2]]];
t1 = mesa([[], [], [], []], manosEmpate(), [[4, 4]], 0, 0);
t1.opener = 1;
rTerminarMano(t1, -1, [-1, -1], false, -1, "");
if (t1.last_result.team !== 1 || t1.last_result.seat !== 1 || !t1.last_result.tranque.tie) fallo("tranque empatado: gana quien salió: " + JSON.stringify(t1.last_result));
// Tranque seguro: el empate es para la pareja con la carta (sale la silla 2, la que menos tiene)
t1 = mesa([["tranque"], [], [], []], manosEmpate(), [[4, 4]], 0, 0);
t1.opener = 1;
rTerminarMano(t1, -1, [-1, -1], false, -1, "");
if (t1.last_result.team !== 0 || t1.last_result.seat !== 2 || t1.last_result.bonus.indexOf("Tranque seguro") < 0) fallo("Tranque seguro gana el empate: " + JSON.stringify(t1.last_result));
// meta 200
const m200 = mesa([[], [], [], []], [[[4, 1]], [[6, 6]], [[5, 5]], [[6, 5]]], [[4, 4]], 0, 0);
m200.meta = 200;
m200.scores = [140, 0];
rJugar(m200, 0, [4, 1], 1);
if (m200.phase === "over") fallo("meta 200: se acabó antes de tiempo");
// Ficha marcada: el rival pasa y la última ficha es de quien la tiene → +3 si gana su pareja
const t2 = mesa([["marcada"], [], [], []], [[[3, 3], [6, 6]], [[0, 1]], [[2, 5]], [[0, 0]]], [[4, 5]], 0, 1);
if (!rPasar(t2, 1) || t2.marks[0] !== 1) fallo("Ficha marcada no cuenta el pase del rival");
rTerminarMano(t2, 0, [3, 3], false, -1, "");
if (t2.last_result.bonus.indexOf("Ficha marcada +3") < 0) fallo("Ficha marcada no suma +3");
// Ficha marcada: sin la carta, de un rival solo se recuerda su último pase
const t5 = mesa([["marcada"], [], [], []], [[[0, 0]], [[0, 1]], [[2, 2]], [[0, 2]]], [[4, 5]], 0, 1);
t5.lacks[1] = { "1": true, "2": true, "4": true, "5": true };
t5.last_pass[1] = { "4": true, "5": true };
if (Object.keys(rPasesVistos(t5, 0, 1)).length !== 4) fallo("con Ficha marcada no se ven todos los pases");
if (Object.keys(rPasesVistos(t5, 2, 1)).length !== 2) fallo("sin Ficha marcada se ven pases viejos del rival");
if (Object.keys(rPasesVistos(t5, 3, 1)).length !== 4) fallo("no se ven todos los pases del compañero");
// Doble suerte: tras el 4-4, el 3-3 de la otra punta se juega solo
const manosSuerte = (): Ficha[][] => [[[4, 4], [3, 3], [1, 2]], [[0, 1], [3, 5]], [[2, 5]], [[0, 0]]];
const t3 = mesa([["suerte"], [], [], []], manosSuerte(), [[3, 4]], 3, 0);
if (!rJugar(t3, 0, [4, 4], 1) || t3.hands[0].length !== 1 || t3.chain.length !== 3 || t3.left_end !== 3 || t3.turn !== 1) fallo("Doble suerte no juega el doble de la otra punta");
const t4 = mesa([[], [], [], []], manosSuerte(), [[3, 4]], 3, 0);
rJugar(t4, 0, [4, 4], 1);
if (t4.hands[0].length !== 2 || t4.turn !== 1) fallo("sin Doble suerte se juega un doble de más");

// ---------------------------------------------------------------- chivo, pase y jugada: una sola regla
// el caso que vio el usuario (2026-10-04): tras un 5-3 las dos puntas son 3 y su 6-3
// soltado en la punta «repetida» contaba como chivo y se lo cantaron
const manosIguales = (): Ficha[][] => [[[6, 3], [1, 2], [4, 4]], [[0, 0], [0, 1]], [[0, 2], [0, 3]], [[0, 4], [0, 5]]];
for (const lado of [-1, 1]) {
	const q3 = mesa([[], [], [], []], manosIguales(), [[3, 5], [5, 3]], 3, 0);
	if (rMeterChivo(q3, 0, [6, 3], lado)) fallo("puntas iguales: el 6-3 en la punta " + lado + " se aceptó como chivo");
	if (!rJugar(q3, 0, [6, 3], lado) || q3.chivo !== null) fallo("puntas iguales: el 6-3 no se juega en la punta " + lado);
	if ((lado < 0 ? q3.left_end : q3.right_end) !== 6) fallo("puntas iguales: la punta no pasa a 6");
}
const q4 = mesa([[], [], [], []], manosIguales(), [[3, 5], [5, 3]], 3, 0);
if (rJugar(q4, 0, [1, 2], 1)) fallo("se juega como buena una ficha que no casa");
if (!rMeterChivo(q4, 0, [1, 2], 1) || q4.chivo === null) fallo("no se puede meter un chivo de verdad");
const q5 = mesa([[], [], [], []], [[[1, 2], [1, 1]], [[0, 0]], [[0, 2]], [[0, 4]]], [[3, 5], [5, 3]], 3, 0);
if (!rPasarConFicha(q5, 0) || q5.chivo !== null) fallo("pasar sin jugada se registró como renuncio");
// capicúa solo con puntas distintas
for (const caso of [[3, 3, false], [3, 6, true]] as [number, number, boolean][]) {
	const qc = mesa([[], [], [], []], [[[6, 3]], [[0, 0]], [[0, 2]], [[0, 4]]], [[caso[0], 9], [9, caso[1]]], 3, 0);
	rJugar(qc, 0, [6, 3], 1);
	if (!!(qc.last_result && qc.last_result.capicua) !== caso[2]) fallo("capicúa con puntas " + caso[0] + " y " + caso[1] + ": " + JSON.stringify(qc.last_result));
}
// «¡Ute va!» con revisión (2026-10-04): la silla 3 pasa teniendo el 3-5 (puntas 3 y 4) y la 0 canta
function mesaUte(): Estado {
	const u = mesa([[], [], [], []], [[[0, 0], [1, 1]], [[0, 1]], [[0, 2]], [[3, 5], [6, 6]]], [[3, 9], [9, 4]], 2, 3);
	if (!rPasarConFicha(u, 3)) fallo("no se puede pasar con ficha para probar el ute va");
	u.turn = 0;
	return u;
}
let u1 = mesaUte();
rCantarChivo(u1, 0, true);
if (u1.revision === null || u1.revision.accused !== 3) fallo("ute va: no empieza la revisión");
if (rJugar(u1, 0, [0, 0], 1)) fallo("ute va: se puede jugar durante la revisión");
if (rResolverRevision(u1, 0, [6, 6]) !== "no_iba" || u1.revision === null) fallo("ute va: el 6-6 no iba y no se avisa");
if (rResolverRevision(u1, 0, [3, 5]) !== "cazado" || u1.last_result.reason !== "chivo") fallo("ute va: elegir la que sí iba no caza el renuncio");
u1 = mesaUte();
rCantarChivo(u1, 0, true);
if (rResolverRevision(u1, 0, null) !== "cazado") fallo("ute va: «No llevaba» pero sí llevaba: debe contar igual (manda la verdad)");
// pase de verdad (sin jugada): «No llevaba» es falsa alarma
const u2 = mesa([[], [], [], []], [[[0, 0], [1, 1]], [[4, 1]], [[0, 2]], [[5, 6], [6, 6]]], [[3, 9], [9, 4]], 2, 3);
rPasar(u2, 3);
u2.turn = 0;
rCantarChivo(u2, 0, true);
if (rResolverRevision(u2, 0, null) !== "falso") fallo("ute va: pase de verdad y «No llevaba» no es falsa alarma");

// al azar: ninguna ficha que casa en la punta elegida acaba como chivo
for (let n = 0; n < 3000; n++) {
	const todas: Ficha[] = [];
	for (let a = 0; a <= 6; a++) for (let b = a; b <= 6; b++) todas.push([a, b]);
	rBarajar(todas);
	const ends = [Math.floor(Math.random() * 7), Math.floor(Math.random() * 7)];
	const cad: Ficha[] = [[ends[0], 9], [9, ends[1]]];
	const qq = mesa([[], [], [], []], [todas.slice(0, 5), todas.slice(5, 10), todas.slice(10, 15), todas.slice(15, 20)], cad, 3, 0);
	const t = qq.hands[0][Math.floor(Math.random() * 5)];
	const lado = Math.random() < 0.5 ? -1 : 1;
	const casa = rCasa(qq, t, lado);
	const fin = lado < 0 ? qq.left_end : qq.right_end;
	if (casa !== (t[0] === fin || t[1] === fin)) fallo("rCasa se equivoca con " + t + " en " + fin);
	const fueChivo = rMeterChivo(qq, 0, t, lado);
	if (fueChivo && casa) fallo("chivo aceptado con una ficha que casa: " + t + " en " + fin);
	if (!fueChivo && !casa && t[0] !== t[1] && rJugar(qq, 0, t, lado)) fallo("jugada aceptada con una ficha que no casa: " + t + " en " + fin);
}

console.log(fallos === 0 ? "SIN FALLOS" : fallos + " FALLOS");
if (fallos > 0) process.exit(1);
