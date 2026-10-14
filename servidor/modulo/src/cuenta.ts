// Cuenta online del jugador: borrarla a petición suya (lo pide la política de
// privacidad, docs/tiendas/privacidad.md). La cuenta se crea sola con el id del
// dispositivo (scripts/red.gd); al borrarla, Nakama quita también todo lo que
// cuelga de ella (sesiones, almacenamiento, amigos).

/** RPC «borrar_cuenta»: borra la cuenta de quien llama. Solo la suya: el id sale de la sesión, nunca del mensaje. */
function rpcBorrarCuenta(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
	if (!ctx.userId) throw Error("hace falta una sesión");
	// sin registro de borrado (recorded = false): no se guarda nada de la cuenta
	nk.accountDeleteId(ctx.userId, false);
	// el log no lleva el id, el nombre ni el dispositivo: solo que pasó
	logger.info("Colmadón: una cuenta se borró a petición de su dueño");
	return JSON.stringify({ ok: true });
}
