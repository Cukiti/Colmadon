extends Node
## Registro compartible, independiente del godot.log bruto. No envía datos.
const Motor := preload("res://scripts/registro_motor.gd")
const CONSERVAR := 5
var carpeta := "user://logs/fallos"
var ruta := ""
var marca := ""
var ultimo_fallo := ""
var motor
var _candado := TCPServer.new()
var _contexto := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var prueba := false
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.contains("res://tests/") or arg in ["--autotest", "--recorrido", "--retratos"] or arg.begins_with("--prueba"):
			prueba = true
		if arg.begins_with("--registro-prueba="):
			var token := arg.trim_prefix("--registro-prueba=")
			if RegEx.create_from_string("^[a-z0-9_-]{1,48}$").search(token) != null:
				carpeta = "user://logs/pruebas_fallos/" + token
			prueba = true
	if prueba and carpeta == "user://logs/fallos":
		carpeta = "user://logs/pruebas_fallos/general"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta))
	recuperar()
	var id := str(int(Time.get_unix_time_from_system() * 1000000)) + "_" + Crypto.new().generate_random_bytes(4).hex_encode()
	ruta = carpeta.path_join("sesion_" + id + ".jsonl")
	marca = ruta + ".pendiente"
	motor = Motor.new()
	var entorno := {"juego": str(ProjectSettings.get_setting("application/config/version", "0.1.0")), "godot": Engine.get_version_info().string,
		"sistema": OS.get_name(), "version_so": OS.get_version(), "modelo": OS.get_model_name(),
		"gpu": RenderingServer.get_video_adapter_name(), "renderizador": RenderingServer.get_current_rendering_method(),
		"resolucion": str(DisplayServer.window_get_size()), "idioma": TranslationServer.get_locale()}
	motor.abrir(ruta, entorno)
	OS.add_logger(motor)
	print("DIAGNOSTICO INICIO ", JSON.stringify(entorno))
	# El puerto solo actúa como candado local de vida: no se acepta ninguna
	# conexión, no se transmite el registro ni se consulta un servidor externo.
	if _candado.listen(0, "127.0.0.1") == OK:
		var f := FileAccess.open(marca, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify({"log": ruta.get_file(), "puerto": _candado.get_local_port()}))
			f.flush()
	_limpiar()

func recuperar() -> void:
	var d := DirAccess.open(carpeta)
	if d == null:
		return
	var nombres := d.get_files()
	nombres.sort()
	for nombre in nombres:
		if not nombre.ends_with(".jsonl.pendiente"):
			continue
		var path := carpeta.path_join(nombre)
		var datos = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not datos is Dictionary:
			continue
		var log_name := str(datos.get("log", ""))
		if RegEx.create_from_string("^sesion_[0-9]+_[a-f0-9]{8}\\.jsonl$").search(log_name) == null or nombre != log_name + ".pendiente":
			continue
		var puerto := int(datos.get("puerto", 0))
		if puerto <= 0 or puerto > 65535:
			continue
		var prueba := TCPServer.new()
		if prueba.listen(puerto, "127.0.0.1") != OK:
			continue  # ventana viva: conserva su archivo y su marca
		var previo := carpeta.path_join(log_name)
		var copia := carpeta.path_join(log_name.replace("sesion_", "fallo_"))
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(previo), ProjectSettings.globalize_path(copia)) == OK:
			ultimo_fallo = copia
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		prueba.stop()  # conserva el candado durante copia/borrado: dos arranques no compiten
	for nombre in nombres:
		if nombre.begins_with("fallo_") and nombre.ends_with(".jsonl"):
			var path := carpeta.path_join(nombre)
			if ultimo_fallo == "" or path > ultimo_fallo:
				ultimo_fallo = path

func contexto() -> void:
	if motor == null:
		return
	var datos := {"resolucion": str(DisplayServer.window_get_size()), "idioma": TranslationServer.get_locale()}
	var firma := str(datos)
	if firma != _contexto:
		_contexto = firma
		motor.escribir("contexto", datos)

func red(evento: String, categoria := "", codigo := -1) -> void:
	# Lista cerrada: nunca se registran nombre, código, cuenta, host o payload.
	if evento not in ["conectando", "conectado", "desconectado", "reconectando", "reconectado", "sala_entrada", "sala_salida", "error"]:
		return
	if motor == null:
		return
	var datos := {"categoria": Motor.categoria(categoria)} if categoria != "" else {}
	if codigo >= 0 and codigo <= 599:
		datos["codigo"] = codigo
	motor.escribir("red_" + evento, datos)

func texto_para_copiar() -> String:
	if motor == null or not FileAccess.file_exists(ruta):
		return ""
	var seleccion := ultimo_fallo if FileAccess.file_exists(ultimo_fallo) else ruta
	var f := FileAccess.open(seleccion, FileAccess.READ)
	if f == null:
		return ""
	var inicio := f.get_line() + "\n"
	var limite: int = Motor.MAX_COPIA - inicio.to_utf8_buffer().size() - 256
	var recortado := f.get_length() - f.get_position() > limite
	if recortado:
		f.seek(f.get_length() - limite)
		f.get_line()  # no copiar medio evento ni cortar UTF-8
	var texto := (f.get_buffer(f.get_length() - f.get_position())).get_string_from_utf8()
	return ("COLMADON · SESION INTERRUMPIDA\n" if seleccion == ultimo_fallo else "COLMADON · SESION ACTUAL\n") + inicio + ("[registro recortado: últimos eventos]\n" if recortado else "") + texto

func copiar() -> bool:
	var texto := texto_para_copiar()
	if texto == "" or not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		return false
	DisplayServer.clipboard_set(texto)
	_compartir_android(texto)
	return true

func _compartir_android(texto: String) -> void:
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime") or not Engine.has_singleton("JavaClassWrapper"):
		return  # PC o exportación sin puente Java: queda copiado
	var runtime = Engine.get_singleton("AndroidRuntime")
	var wrapper = Engine.get_singleton("JavaClassWrapper")
	var activity = runtime.getActivity()
	var intent_class = wrapper.wrap("android.content.Intent")
	if activity == null or intent_class == null:
		return
	var mostrar := func():
		var intent = intent_class.Intent()
		intent.setAction(intent_class.ACTION_SEND)
		intent.setType("text/plain")
		intent.putExtra(intent_class.EXTRA_TEXT, texto)
		var chooser = intent_class.createChooser(intent, tr("Compartir registro de fallos"))
		if chooser.resolveActivity(activity.getPackageManager()) != null:
			activity.startActivity(chooser)
	activity.runOnUiThread(runtime.createRunnableFromGodotCallable(mostrar))

func _limpiar() -> void:
	var d := DirAccess.open(carpeta)
	if d == null:
		return
	for prefijo in ["sesion_", "fallo_"]:
		var cerrados: Array[String] = []
		for nombre in d.get_files():
			if RegEx.create_from_string("^" + prefijo + "[0-9]+_[a-f0-9]{8}\\.jsonl$").search(nombre) != null and carpeta.path_join(nombre) != ruta and not FileAccess.file_exists(carpeta.path_join(nombre + ".pendiente")):
				cerrados.append(nombre)
		cerrados.sort()
		while cerrados.size() > CONSERVAR:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(carpeta.path_join(cerrados.pop_front())))

func _exit_tree() -> void:
	if motor == null:
		return
	motor.escribir("salida_normal")
	OS.remove_logger(motor)
	motor.cerrar()
	if FileAccess.file_exists(marca):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(marca))
	_candado.stop()
