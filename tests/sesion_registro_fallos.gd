extends SceneTree
## Fixture de proceso para cierre brusco y recuperación. Solo escribe registros
## aislados; no instancia main ni toca perfiles, ajustes, cuentas o red online.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var r = root.get_node("RegistroFallos")
	r.motor.escribir("fixture_cierre", {"marca": "CIERRE_BRUSCO_PRUEBA"})
	if OS.get_cmdline_user_args().has("--verificar-recuperacion"):
		var ok: bool = r.ultimo_fallo != "" and r.texto_para_copiar().contains("CIERRE_BRUSCO_PRUEBA") and r.texto_para_copiar().contains("SESION INTERRUMPIDA")
		print("CIERRE BRUSCO ", "SIN FALLOS" if ok else "FALLO")
		quit(0 if ok else 1)
		return
	print("FIXTURE REGISTRO LISTO PID=", OS.get_process_id(), " LOG=", r.ruta)
	# Si no se mata para la prueba, sale normalmente tras 5 minutos.
	await create_timer(300).timeout
	quit()
