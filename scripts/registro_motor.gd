extends Logger
## Solo campos técnicos. Nunca guarda stdout, mensajes arbitrarios, variables
## de la pila ni el texto libre de excepciones (puede contener datos personales).
const MAX_ARCHIVO := 256 * 1024
const MAX_COPIA := 32 * 1024
var ruta := ""
var archivo: FileAccess
var cabecera := ""
var cola: Array[String] = []
var bytes_cola := 0
var mutex := Mutex.new()
var _ocupado := false

func abrir(path: String, entorno: Dictionary) -> void:
	ruta = path
	archivo = FileAccess.open(path, FileAccess.WRITE)
	cabecera = JSON.stringify({"evento": "inicio", "entorno": entorno}) + "\n"
	if archivo:
		archivo.store_string(cabecera)
		archivo.flush()

func escribir(evento: String, datos := {}) -> void:
	var texto := JSON.stringify({"segundos": snappedf(Time.get_ticks_msec() / 1000.0, 0.01), "evento": evento, "datos": datos}) + "\n"
	mutex.lock()
	if _ocupado:
		mutex.unlock()
		return  # un fallo de E/S del propio registro no debe recursar
	_ocupado = true
	cola.append(texto)
	bytes_cola += texto.to_utf8_buffer().size()
	while bytes_cola > MAX_COPIA - 4096 and cola.size() > 1:
		bytes_cola -= cola.pop_front().to_utf8_buffer().size()
	if archivo:
		if archivo.get_position() + texto.to_utf8_buffer().size() > MAX_ARCHIVO:
			archivo.close()
			archivo = FileAccess.open(ruta, FileAccess.WRITE)
			if archivo:
				archivo.store_string(cabecera + "".join(cola))
		else:
			archivo.store_string(texto)
		if archivo:
			archivo.flush()
	_ocupado = false
	mutex.unlock()

func cerrar() -> void:
	mutex.lock()
	if archivo:
		archivo.close()
		archivo = null
	mutex.unlock()

static func categoria(texto: String) -> String:
	var t := texto.to_lower()
	for item in [["parse", "sintaxis"], ["invalid", "acceso_invalido"], ["null", "referencia_nula"], ["timeout", "tiempo_agotado"], ["connect", "conexion"], ["memory", "memoria"], ["shader", "shader"], ["resource", "recurso"]]:
		if t.contains(item[0]):
			return item[1]
	return "otro"

static func ubicacion(file: String, function: String, line: int) -> Dictionary:
	# Solo archivos distribuidos dentro del proyecto. Las rutas del SO se omiten.
	var path := file if file.begins_with("res://") and ResourceLoader.exists(file) else "motor"
	var fn := function if RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]{0,80}$").search(function) != null else "interna"
	return {"archivo": path, "funcion": fn, "linea": line}

func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	var pila: Array = []
	for backtrace in script_backtraces:
		for i in mini(backtrace.get_frame_count(), 12):
			pila.append(ubicacion(backtrace.get_frame_file(i), backtrace.get_frame_function(i), backtrace.get_frame_line(i)))
	escribir("error_motor", {"tipo": error_type, "categoria": categoria(code + " " + rationale), "origen": ubicacion(file, function, line), "pila": pila})

func _log_message(message: String, error: bool) -> void:
	if error:
		escribir("stderr", {"categoria": categoria(message)})
