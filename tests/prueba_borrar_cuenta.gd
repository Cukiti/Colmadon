extends Node
## Prueba de «Borrar mis datos online» contra un servidor de verdad (local):
## crea la cuenta del dispositivo, la borra con red.borrar_cuenta(), comprueba
## que ya no existe en el servidor, que se olvidó el id y que la siguiente vez
## se crea otra cuenta. Uso (servidor local en marcha):
## godot --headless --path . res://tests/prueba_borrar_cuenta.tscn -- --local

const Red := preload("res://scripts/red.gd")

var fallos := 0


func check(ok: bool, msg: String) -> void:
	if not ok:
		fallos += 1
		print("FALLO ", msg)


func _ready() -> void:
	var red = Red.new()
	add_child(red)
	# sin cuenta todavía: no hay nada que borrar (y no se crea ninguna)
	if FileAccess.file_exists(Nakama.DEVICE_ID_PATH):
		DirAccess.remove_absolute(Nakama.DEVICE_ID_PATH)
	Nakama._device_id = ""
	check(await red.borrar_cuenta() == "", "sin cuenta da error")
	check(not FileAccess.file_exists(Nakama.DEVICE_ID_PATH), "sin cuenta se creó un id")
	# con cuenta
	var e: String = await red.conectar("Prueba")
	check(e == "", "no conecta: " + e)
	if e != "":
		return _fin()
	var viejo: String = red.session.user_id
	var id_viejo := Nakama.get_device_id()
	check(FileAccess.file_exists(Nakama.DEVICE_ID_PATH), "no se guardó el id del dispositivo")
	e = await red.borrar_cuenta()
	check(e == "", "no borra: " + e)
	check(not FileAccess.file_exists(Nakama.DEVICE_ID_PATH), "el id del dispositivo sigue guardado")
	check(red.session == null and red.socket == null, "la sesión sigue abierta")
	# la cuenta ya no existe: entrar con el id viejo sin crear falla
	var c: NakamaClient = Nakama.create_client("colmadon-dev", "127.0.0.1", 7350, "http", 5, NakamaLogger.LOG_LEVEL.NONE)
	var s: NakamaSession = await c.authenticate_device_async(id_viejo, null, false)
	check(s.is_exception(), "la cuenta borrada sigue existiendo")
	# la próxima vez, cuenta nueva con otro id
	e = await red.conectar("Prueba")
	check(e == "" and red.session.user_id != viejo, "no se crea una cuenta nueva")
	check(Nakama.get_device_id() != id_viejo, "se reutiliza el id viejo")
	await red.borrar_cuenta()  # deja el servidor limpio
	_fin()


func _fin() -> void:
	print("BORRAR CUENTA ", "SIN FALLOS" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)
