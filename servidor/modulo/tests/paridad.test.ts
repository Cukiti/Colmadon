// Paridad de los bots: las notas de rNotaJugada deben ser las mismas que las de
// _move_score en scripts/game.gd para los estados de paridad_bots.json (los
// genera tests/paridad_bots.gd con Godot). Uso: npm test
declare const process: any;
declare const require: any;

const datos = JSON.parse(require("fs").readFileSync("tests/paridad_bots.json", "utf8"));
R_BOT_NOISE = 0;
let malos = 0;
let notas = 0;
for (const e of datos.estados) {
	const p = rNuevaPartida([true, true, true, true]);
	p.phase = "play";
	p.first_hand = false;
	p.turn = e.seat;
	p.hands = e.hands;
	p.chain = e.chain;
	p.left_end = e.left_end;
	p.right_end = e.right_end;
	p.lacks = e.lacks;
	p.last_pass = e.last_pass;
	p.played_nums = e.played_nums;
	p.cards = e.cards;
	p.opener = e.opener || 0; // el empate del tranque es de la pareja que salió
	p.revealed = e.revealed;
	p.reveal_partner = e.reveal_partner;
	const vista = rVistaBot(p, e.seat);
	for (const m of e.moves) {
		notas++;
		const nota = rNotaJugada(p, e.seat, { tile: m.tile, side: m.side }, vista);
		if (Math.abs(nota - m.nota) > 1e-6) {
			malos++;
			if (malos <= 5) console.log("FALLO paridad: silla " + e.seat + " ficha " + m.tile + " lado " + m.side + ": game.gd " + m.nota + " · reglas.ts " + nota);
		}
	}
}
console.log("PARIDAD " + datos.estados.length + " estados · " + notas + " jugadas · " + (malos === 0 ? "SIN FALLOS" : malos + " FALLOS"));
if (malos > 0) process.exit(1);
