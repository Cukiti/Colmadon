// Prueba del RPC «borrar_cuenta» (cuenta.ts) con un Nakama simulado: borra la
// cuenta de quien llama (no la que diga el mensaje), sin sesión no borra nada y
// el log no lleva datos personales. Uso: npm test
declare const process: any;

let fallosCuenta = 0;
function compruebaCuenta(ok: boolean, msg: string): void {
	if (ok) return;
	fallosCuenta++;
	console.log("FALLO " + msg);
}

let borradas: { id: string; recorded: any }[] = [];
let lineas: string[] = [];
const nkCuenta = {
	accountDeleteId(id: string, recorded?: boolean) {
		borradas.push({ id: id, recorded: recorded });
	},
} as any as nkruntime.Nakama;
const apunta = (m: string) => lineas.push(m);
const loggerCuenta = { info: apunta, warn: apunta, error: apunta, debug: apunta } as any as nkruntime.Logger;

// con sesión: borra la cuenta de la sesión aunque el mensaje pida otra
const ctxCuenta = { userId: "u-123", username: "ron_dominguez", vars: {} } as any as nkruntime.Context;
const resp = JSON.parse(rpcBorrarCuenta(ctxCuenta, loggerCuenta, nkCuenta, JSON.stringify({ userId: "otra" })));
compruebaCuenta(resp.ok === true, "no responde ok");
compruebaCuenta(borradas.length === 1 && borradas[0].id === "u-123", "no borra la cuenta de quien llama: " + JSON.stringify(borradas));
compruebaCuenta(borradas[0].recorded === false, "guarda registro del borrado");
compruebaCuenta(lineas.length === 1, "no deja una línea en el log");
for (const l of lineas) compruebaCuenta(l.indexOf("u-123") < 0 && l.indexOf("ron_dominguez") < 0, "el log lleva datos personales: " + l);

// sin sesión: error y nada borrado
borradas = [];
let fallo = false;
try {
	rpcBorrarCuenta({} as any as nkruntime.Context, loggerCuenta, nkCuenta, "");
} catch (e) {
	fallo = true;
}
compruebaCuenta(fallo && borradas.length === 0, "sin sesión borra algo o no da error");

console.log(fallosCuenta === 0 ? "CUENTA SIN FALLOS" : fallosCuenta + " FALLOS EN CUENTA");
if (fallosCuenta > 0) process.exit(1);
