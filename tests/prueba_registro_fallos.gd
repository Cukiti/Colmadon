extends Node
var fallos := 0

func check(ok: bool, nota: String) -> void:
	if not ok:
		fallos += 1
		print("FALLO REGISTRO: ", nota)

func _ready() -> void:
	var r = RegistroFallos
	# Esta parte verifica la sesión actual aunque una ejecución anterior del
	# propio test haya dejado el fallo simulado que se comprueba al final.
	r.ultimo_fallo = ""
	check(r.carpeta.begins_with("user://logs/pruebas_fallos/"), "carpeta aislada")
	check(FileAccess.file_exists(r.marca), "marca al arrancar")
	var inicio = JSON.parse_string(FileAccess.get_file_as_string(r.ruta).split("\n")[0])
	for key in ["juego", "godot", "sistema", "version_so", "modelo", "gpu", "renderizador", "resolucion", "idioma"]:
		check(inicio.entorno.has(key), "entorno " + key)
	# Registrar excepciones con contenido privado no debe copiar ese contenido.
	var privado := "AndersonPrivado 192.0.2.55 https://privado.example token=SECRETO id-dispositivo=UUID-PRIVADO C:/Users/NombrePrivado"
	r.motor._log_message(privado, false)
	r.motor._log_message(privado, true)
	var pila_vacia: Array[ScriptBacktrace] = []
	r.motor._log_error("funcion_prueba", "res://tests/prueba_registro_fallos.gd", 12, "Invalid key '" + privado + "'", privado, false, 0, pila_vacia)
	for e in ["conectando", "conectado", "desconectado", "reconectando", "reconectado", "sala_entrada", "sala_salida"]:
		r.red(e)
	r.red("error", "timeout " + privado, 503)
	r.red(privado, privado)
	var texto: String = r.texto_para_copiar()
	for dato in ["AndersonPrivado", "192.0.2.55", "privado.example", "SECRETO", "UUID-PRIVADO", "NombrePrivado"]:
		check(not texto.contains(dato), "datos privados omitidos")
	check(texto.contains("error_motor") and texto.contains("funcion_prueba"), "error con ubicación")
	check(texto.contains("red_error") and texto.contains("503") and texto.contains("tiempo_agotado"), "error de red útil")
	push_warning("Shader: aviso controlado del test DATO-FICTICIO-OCULTO")
	texto = r.texto_para_copiar()
	check(texto.contains('"categoria":"shader"') and not texto.contains("DATO-FICTICIO-OCULTO"), "Logger intercepta motor sin guardar mensaje libre")
	var red = load("res://scripts/red.gd").new()
	add_child(red)
	red._corto(NakamaException.new("timeout " + privado, 503))
	red.socket = Nakama.create_socket("127.0.0.1", 1)
	red._atar_socket()
	red.socket.closed.emit()  # señal real del adaptador, sin abrir una conexión
	check(r.texto_para_copiar().contains("red_desconectado"), "adaptador registra desconexión")
	check(not r.texto_para_copiar().contains("UUID-PRIVADO"), "adaptador no filtra excepción privada")
	red.queue_free()
	# Una segunda ventana no debe interpretar la primera como cerrada.
	var otro = load("res://scripts/registro_fallos.gd").new()
	add_child(otro)
	check(not FileAccess.file_exists(r.ruta.replace("sesion_", "fallo_")), "sesión viva no archivada")
	var marca_otro: String = otro.marca
	otro.queue_free()
	await get_tree().process_frame
	check(not FileAccess.file_exists(marca_otro), "salida normal retira marca")
	r.recuperar()
	check(not FileAccess.file_exists(marca_otro.replace("sesion_", "fallo_").trim_suffix(".pendiente")), "salida normal no produce fallo")
	r.ultimo_fallo = ""
	# Retención: el disco y el portapapeles tienen límites independientes.
	for i in 1800:
		r.motor.escribir("prueba_limite", {"numero": i, "relleno": "x".repeat(150)})
	texto = r.texto_para_copiar()
	check(texto.to_utf8_buffer().size() <= r.Motor.MAX_COPIA, "copia <= 32 KiB")
	check(texto.contains("inicio") and texto.contains("1799"), "cabecera y eventos recientes")
	var f := FileAccess.open(r.ruta, FileAccess.READ)
	check(f.get_length() <= r.Motor.MAX_ARCHIVO, "archivo <= 256 KiB")
	var worker := Thread.new()
	worker.start(func():
		for i in 100:
			r.motor._log_message("timeout " + privado, true))
	worker.wait_to_finish()
	check(not r.texto_para_copiar().contains("SECRETO"), "captura segura desde otro hilo")
	for i in 8:
		var viejo := FileAccess.open(r.carpeta.path_join("sesion_%08d_%08x.jsonl" % [i, i]), FileAccess.WRITE)
		viejo.store_string("registro antiguo de prueba\n")
		viejo.close()
	r._limpiar()
	var cerrados := 0
	for nombre in DirAccess.open(r.carpeta).get_files():
		if nombre.begins_with("sesion_") and nombre.ends_with(".jsonl") and r.carpeta.path_join(nombre) != r.ruta:
			cerrados += 1
	check(cerrados <= r.CONSERVAR and FileAccess.file_exists(r.ruta), "retención conserva sesión activa")
	# Marca de un proceso ya terminado: conserva exactamente su registro y lo
	# prioriza para copiar, incluso tras modificar el registro actual.
	var nombre_muerto := "sesion_7777777777777777_77777777.jsonl"
	var ruta_muerto: String = r.carpeta.path_join(nombre_muerto)
	var muerto := FileAccess.open(ruta_muerto, FileAccess.WRITE)
	muerto.store_string("{\"evento\":\"inicio\",\"entorno\":{\"prueba\":true}}\n{\"evento\":\"CIERRE_SIMULADO\"}\n")
	muerto.close()
	var lock := TCPServer.new()
	lock.listen(0, "127.0.0.1")
	var pendiente := FileAccess.open(ruta_muerto + ".pendiente", FileAccess.WRITE)
	pendiente.store_string(JSON.stringify({"log": nombre_muerto, "puerto": lock.get_local_port()}))
	pendiente.close()
	lock.stop()
	r.recuperar()
	check(not FileAccess.file_exists(ruta_muerto + ".pendiente"), "marca interrumpida retirada tras copia")
	check(FileAccess.get_file_as_string(r.ultimo_fallo) == FileAccess.get_file_as_string(ruta_muerto), "copia de fallo exacta")
	r.motor.escribir("sesion_actual_posterior")
	check(r.texto_para_copiar().contains("CIERRE_SIMULADO") and not r.texto_para_copiar().contains("sesion_actual_posterior"), "copia prioriza fallo anterior")
	print("REGISTRO FALLOS ", "SIN FALLOS" if fallos == 0 else str(fallos) + " FALLOS")
	get_tree().quit(1 if fallos else 0)
