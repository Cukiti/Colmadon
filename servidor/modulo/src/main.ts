// Punto de entrada del módulo de Nakama para Colmadón.
let InitModule: nkruntime.InitModule = function (ctx, logger, nk, initializer) {
	initializer.registerRpc("crear_sala", rpcCrearSala);
	initializer.registerRpc("unirse_sala", rpcUnirseSala);
	initializer.registerRpc("listar_salas", rpcListarSalas);
	initializer.registerRpc("sala_viva", rpcSalaViva);
	initializer.registerRpc("borrar_cuenta", rpcBorrarCuenta);
	initializer.registerMatch("colmadon", {
		matchInit: salaInit,
		matchJoinAttempt: salaJoinAttempt,
		matchJoin: salaJoin,
		matchLeave: salaLeave,
		matchLoop: salaLoop,
		matchTerminate: salaTerminate,
		matchSignal: salaSignal,
	});
	logger.info("Colmadón: módulo cargado (salas con código)");
};
// que el compilador no la elimine: Nakama busca InitModule en el ámbito global
!InitModule && (InitModule as any).bind(null);
