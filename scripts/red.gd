extends Node
## Conexión con el servidor de Colmadón (Nakama): cuenta automática del
## dispositivo, salas con código y mensajes de la partida. El servidor decide
## todo; aquí solo se envían las jugadas y se recibe lo que ve este jugador.

signal estado(v: Dictionary)   # la mesa tal como la ve este jugador
signal aviso(texto: String)    # el servidor rechazó algo o hubo un problema
signal desconectado()
signal cuenta(d: Dictionary)   # quien ganó tocó una ficha de la cuenta (o todas)
signal manos(d: Dictionary)    # lo que hace otro con sus fichas (silla ya girada)
signal poses(d: Dictionary)    # quién está de pie y dónde (girado: tú en la silla 0) y quién tapó

const OP_PERFIL := 1
const OP_EMPEZAR := 2
const OP_CARTA := 10
const OP_ROBAR := 11
const OP_JUGAR := 12
const OP_PASAR := 13
const OP_PASAR_CON_FICHA := 14
const OP_CANTAR := 15
const OP_BEBER := 16
const OP_COMPRAR := 17
const OP_LISTO := 18
const OP_REVANCHA := 19
const OP_FRASE := 20  # chat rápido: {"id": "<id de frase>"} (lista cerrada en el servidor)
const OP_POSE := 21    # de pie: {"st": 0/1/2, "x", "z", "yaw"} (en tus coordenadas: tú en la silla 0)
const OP_EMOTE := 22   # {"id": baile, aplauso…, "target": silla}
const OP_TAPAR := 23   # {"on": true/false}: tapar tus fichas
const OP_MANO := 24    # lo que haces con tus fichas: {"st": 0 nada, 1 mirarlas, 2 una en la mano, 3 llevarla a una punta, "side": -1/0/1}
const OP_AQUI := 25    # «estoy aquí»: estabas ausente y tocaste o moviste el ratón
const OP_REVISAR := 26 # «¡Ute va!»: {"tile": [a, b]} la que sí iba, o {"none": true} «No llevaba»
const OP_TRANQUE_OK := 28   # «visto» en la pantalla del tranque
const OP_EQUIPO := 31  # sala de espera: propones el nombre de tu pareja {"name"} (máx. 8 letras)
const OP_LISTO_SALA := 32   # sala de espera: {"on"} estás listo
const OP_SILLA := 33        # sala de espera: {"seat"} (silla local) quieres sentarte ahí
const OP_SILLA_RESP := 34   # sala de espera: {"ok"} respuesta a quien pidió tu silla
const OP_EQUIPO_RESP := 35  # sala de espera: {"ok"} te gusta el nombre que propuso tu pareja
const OP_REVELAR := 36      # tranque: {"idx"} giras tu ficha
const OP_AMAGO := 37        # tranque: {"idx"} amagas
const OP_ENTREGAR := 38     # tranque: entregas tus fichas al ganador
const OP_ARREBATAR := 39    # tranque: el ganador le quita las fichas a {"seat"} (silla local)
const OP_RADIO := 30   # tocar la radio del colmado (siguiente pista o apagada)
const OP_CUENTA := 29  # quien ganó cuenta a mano: {"tile": [a, b]} o {"all": true}
const OP_GOLPE := 27   # de pie: manotazo {"target": silla, "run": venías corriendo}
const OP_DISPARO := 40  # {"o", "n"} y, si tocaste, {"target", "zona"}: decide el servidor
const OP_REVIVIR := 41  # muerto: «Volver al colmado»
const OP_VERIFICAR := 43  # V1: dominó/capicúa: {"ok": true} VISTO o {"reclamar": true}
const OP_BALAS := 42    # {"n", "arma"}: tus balas y el arma elegida
const OP_ESTADO := 101
const OP_POSES := 103
const OP_MANOS := 104  # lo mismo de otro jugador: {"seat" (ya girada), "st", "side"}
const OP_AVISO := 102
const OP_CUENTAS := 105  # la cuenta de quien ganó: {"seat" (ya girada), "tile" | "all"}

# servidor en Oracle Cloud (A1 gratis, Ashburn). La
# clave del servidor va dentro del juego en cualquier caso (no es secreta).
# --local usa el servidor del PC (servidor/Encender servidor.bat);
# user://servidor.cfg ([red] host/puerto/clave) lo cambia a mano.
const HOST := "129.80.114.69"
const PUERTO := 7350
const CLAVE := "WQLrh1O5cJKwbWy0rsFCmzo7"
const HOST_LOCAL := "127.0.0.1"
const CLAVE_LOCAL := "colmadon-dev"

var client: NakamaClient
var session: NakamaSession
var socket: NakamaSocket
var match_id := ""
var codigo := ""
var mi_nombre := ""
var _mi_look := {}
var _reenvio_ms := 0


## [host, puerto, clave] del servidor al que se conecta.
func _host() -> Array:
	# La selección explícita local tiene prioridad sobre cualquier configuración
	# persistente: las pruebas locales nunca deben acabar en la nube.
	if OS.get_cmdline_user_args().has("--local"):
		return [HOST_LOCAL, PUERTO, CLAVE_LOCAL]
	var cf := ConfigFile.new()
	if cf.load("user://servidor.cfg") == OK:
		return [str(cf.get_value("red", "host", HOST)), int(cf.get_value("red", "puerto", PUERTO)), str(cf.get_value("red", "clave", CLAVE))]
	for a in OS.get_cmdline_user_args():
		if a == "--local":
			return [HOST_LOCAL, PUERTO, CLAVE_LOCAL]
		if a.begins_with("--servidor="):
			return [a.trim_prefix("--servidor="), PUERTO, CLAVE]
	return [HOST, PUERTO, CLAVE]


## Entra en el servidor (crea la cuenta del dispositivo la primera vez).
## Devuelve "" si fue bien o el texto del problema.
func conectar(nombre: String) -> String:
	if socket != null and socket.is_connected_to_host():
		return ""
	var h := _host()
	RegistroFallos.red("conectando")
	# sin mensajes de depuración: llevan datos de la sesión
	client = Nakama.create_client(h[2], h[0], h[1], "http", 5, NakamaLogger.LOG_LEVEL.NONE)
	var id := Nakama.get_device_id()
	# en pruebas con dos ventanas en el mismo PC, cada una con su cuenta
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cuenta="):
			id += "-" + a.trim_prefix("--cuenta=")
	session = await client.authenticate_device_async(id)
	if session.is_exception():
		return tr("No se pudo conectar con el colmado (%s)") % _corto(session.get_exception())
	socket = Nakama.create_socket_from(client)
	var r = await socket.connect_async(session)
	if r.is_exception():
		return tr("No se pudo abrir la conexión (%s)") % _corto(r.get_exception())
	_atar_socket()
	RegistroFallos.red("conectado")
	return ""


func _atar_socket() -> void:
	socket.received_match_state.connect(_mensaje)
	socket.closed.connect(func():
		RegistroFallos.red("desconectado")
		desconectado.emit())


## Se cortó la conexión (wifi que va y viene, el móvil en segundo plano…):
## vuelve a abrir el socket y entra en la misma sala. El servidor guarda la
## silla por cuenta: recuperas fichas, cartas y turno (mientras, jugó tu bot).
## Devuelve "" si volvió o el texto del problema.
func reconectar(intentos := 4) -> String:
	if match_id == "" or session == null:
		return tr("No estabas en ninguna sala")
	var mid := match_id
	RegistroFallos.red("reconectando")
	var err := ""
	for k in intentos:
		await get_tree().create_timer(1.0 + k * 1.5).timeout
		socket = Nakama.create_socket_from(client)
		var r = await socket.connect_async(session)
		if r.is_exception():
			err = _corto(r.get_exception())
			continue
		var m = await socket.join_match_async(mid)
		if m.is_exception():
			err = _corto(m.get_exception())
			socket.close()
			continue
		_atar_socket()
		match_id = mid
		enviar(OP_PERFIL, {"name": mi_nombre, "avatar": _mi_look})
		RegistroFallos.red("reconectado")
		return ""
	match_id = ""
	return tr("No se pudo volver a la sala (%s)") % err


func conectado() -> bool:
	return socket != null and socket.is_connected_to_host()


## Borra la cuenta online de este dispositivo (RPC «borrar_cuenta») y olvida
## su id: la próxima vez que se juegue online se crea una cuenta nueva. Los
## personajes y los pesos se guardan en el dispositivo y no se tocan.
## Devuelve "" si fue bien o el texto del problema.
func borrar_cuenta() -> String:
	if en_sala():
		return tr("Sal de la sala antes de borrar tu cuenta")
	# sin id guardado y sin conexión nunca hubo cuenta: no hay nada que borrar
	if session == null and not FileAccess.file_exists(Nakama.DEVICE_ID_PATH):
		return ""
	var e := await conectar(mi_nombre)
	if e != "":
		return e
	var r = await client.rpc_async(session, "borrar_cuenta", "{}")
	if r.is_exception():
		return tr("No se pudo borrar la cuenta (%s)") % _corto(r.get_exception())
	# cerrar avisa con «desconectado», pero main.gd solo reacciona en partida
	if socket != null:
		socket.close()
	socket = null
	session = null
	match_id = ""
	codigo = ""
	DirAccess.remove_absolute(Nakama.DEVICE_ID_PATH)
	Nakama._device_id = ""  # Nakama lo guarda también en memoria
	return ""


## modo: "aumentos" (cartas y bebidas) o "clasico" (dominó de siempre).
func crear_sala(nombre: String, look: Dictionary, modo := "aumentos", meta := 100, publica := false, armas := false) -> String:
	var e := await conectar(nombre)
	if e != "":
		return e
	var r = await client.rpc_async(session, "crear_sala", JSON.stringify({"modo": modo, "meta": meta, "publica": publica, "armas": armas and not publica}))
	if r.is_exception():
		return tr("No se pudo crear la sala (%s)") % _corto(r.get_exception())
	var d: Dictionary = JSON.parse_string(r.payload)
	return await _entrar(d.match_id, d.code, nombre, look)


func listar_salas(nombre: String, filtros: Dictionary = {}) -> Dictionary:
	var e := await conectar(nombre)
	if e != "":
		return {"error": e}
	var r = await client.rpc_async(session, "listar_salas", JSON.stringify(filtros))
	if r.is_exception():
		return {"error": tr("No se pudo buscar la sala (%s)") % _corto(r.get_exception())}
	var d = JSON.parse_string(r.payload)
	if not d is Dictionary or not d.get("salas") is Array:
		return {"error": tr("Respuesta de salas no válida")}
	return d


## O02: ¿sigue viva la sala y puedes volver (tu silla, o espera con sitio)?
## 1 sí, 0 no (ya no está o no hay sitio), -1 no se sabe (sin conexión).
## Un servidor sin «sala_viva» solo puede decir si la sala existe.
func sala_viva(code: String, nombre: String) -> int:
	var e := await conectar(nombre)
	if e != "":
		return -1
	var r = await client.rpc_async(session, "sala_viva", JSON.stringify({"code": code}))
	if not r.is_exception():
		var d = JSON.parse_string(r.payload)
		return 1 if d is Dictionary and d.get("viva", false) == true else 0
	r = await client.rpc_async(session, "unirse_sala", JSON.stringify({"code": code}))
	if r.is_exception():
		return -1
	var d2 = JSON.parse_string(r.payload)
	return 1 if d2 is Dictionary and d2.has("match_id") else 0


func unirse(code: String, nombre: String, look: Dictionary) -> String:
	var e := await conectar(nombre)
	if e != "":
		return e
	var r
	var d: Dictionary = {}
	# una sala recién creada tarda ~1 s en aparecer en el índice del servidor:
	# si no sale, se vuelve a buscar antes de dar el código por malo
	for intento in 3:
		if intento > 0:
			await get_tree().create_timer(1.0).timeout
		r = await client.rpc_async(session, "unirse_sala", JSON.stringify({"code": code}))
		if r.is_exception():
			return tr("No se pudo buscar la sala (%s)") % _corto(r.get_exception())
		d = JSON.parse_string(r.payload)
		if not d.has("error"):
			break
	if d.has("error"):
		RegistroFallos.red("error", str(d.error))
		return d.error
	return await _entrar(d.match_id, d.code, nombre, look)


func _entrar(mid: String, code: String, nombre: String, look: Dictionary) -> String:
	var m = await socket.join_match_async(mid)
	if m.is_exception():
		var txt := _corto(m.get_exception())
		if txt.contains("ya empezó"):
			return tr("La partida ya empezó")
		return tr("La sala está llena") if txt.contains("llena") or txt.contains("full") else tr("No se pudo entrar en la sala (%s)") % txt
	match_id = mid
	codigo = code
	mi_nombre = nombre
	_mi_look = look_a_json(look)
	enviar(OP_PERFIL, {"name": nombre, "avatar": _mi_look})
	_recordar_sala(code)
	RegistroFallos.red("sala_entrada")
	return ""


# ---------------------------------------------------------------- volver a la última sala

const ULTIMA_SALA := "user://ultima_sala.cfg"
const ULTIMA_SALA_HORAS := 3.0   # pasado este tiempo la sala ya no se ofrece


## Guarda la sala en la que entraste: el inicio ofrece «VOLVER A LA SALA»
## si sales sin querer o se cierra el juego (el servidor te guarda la silla).
func _recordar_sala(code: String) -> void:
	var cf := ConfigFile.new()
	cf.set_value("sala", "codigo", code)
	cf.set_value("sala", "hora", Time.get_unix_time_from_system())
	cf.save(ULTIMA_SALA)


## {"codigo"} de la última sala si es reciente; vacío si no hay.
func ultima_sala() -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(ULTIMA_SALA) != OK:
		return {}
	var code := str(cf.get_value("sala", "codigo", ""))
	var hora := float(cf.get_value("sala", "hora", 0.0))
	if code == "" or Time.get_unix_time_from_system() - hora > ULTIMA_SALA_HORAS * 3600.0:
		return {}
	return {"codigo": code}


func olvidar_sala() -> void:
	if FileAccess.file_exists(ULTIMA_SALA):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ULTIMA_SALA))


## El perfil puede llegar antes de que el servidor te siente (y lo descarta):
## si la mesa aún no muestra tu nombre, se vuelve a mandar (como mucho 1 vez/s).
func comprobar_perfil(v: Dictionary) -> void:
	if mi_nombre == "" or v.get("seats", []).is_empty():
		return
	var yo: Dictionary = v.seats[0]
	if yo.name == mi_nombre and yo.avatar is Dictionary:
		return
	if Time.get_ticks_msec() - _reenvio_ms < 1000:
		return
	_reenvio_ms = Time.get_ticks_msec()
	enviar(OP_PERFIL, {"name": mi_nombre, "avatar": _mi_look})


func salir() -> void:
	if socket != null and match_id != "":
		RegistroFallos.red("sala_salida")
		await socket.leave_match_async(match_id)
	match_id = ""
	codigo = ""


func en_sala() -> bool:
	return match_id != ""


func enviar(op: int, datos := {}) -> void:
	if socket == null or match_id == "":
		return
	socket.send_match_state_async(match_id, op, JSON.stringify(datos))


func _mensaje(st) -> void:
	if st.match_id != match_id:
		return
	var d = JSON.parse_string(st.data)
	if typeof(d) != TYPE_DICTIONARY:
		return
	if st.op_code == OP_ESTADO:
		estado.emit(d)
	elif st.op_code == OP_POSES:
		poses.emit(d)
	elif st.op_code == OP_MANOS:
		manos.emit(d)
	elif st.op_code == OP_CUENTAS:
		cuenta.emit(d)
	elif st.op_code == OP_AVISO:
		RegistroFallos.red("error", str(d.get("text", "")))
		aviso.emit(str(d.get("text", "")))


func _corto(e) -> String:
	var t := str(e.message if e != null and "message" in e else e)
	RegistroFallos.red("error", t, int(e.status_code) if e is NakamaException else -1)
	# los errores del servidor («código no válido»…) también son claves del CSV
	return tr(t.substr(0, 60))


# ---------------------------------------------------------------- aspecto del personaje por la red

## Los colores no viajan en JSON: se mandan como "#rrggbb".
static func look_a_json(c: Dictionary) -> Dictionary:
	var out := {}
	for k in c:
		var v = c[k]
		out[k] = "#" + v.to_html(false) if v is Color else v
	return out


const LOOK_COLORES := ["skin", "hair", "shirt", "pants"]
const LOOK_TEXTOS := ["hat", "pattern", "cuerpo", "glasses", "earrings", "chain", "lips"]
const LOOK_SINO := ["mustache", "beard"]


static func look_de_json(c: Dictionary) -> Dictionary:
	var out := {"skin": Color(0.6, 0.42, 0.3), "hair": Color(0.1, 0.07, 0.05), "shirt": Color(0.12, 0.65, 0.68),
		"pants": Color(0.2, 0.2, 0.25), "hat": "calvo", "pattern": "guayabera"}
	for k in LOOK_COLORES:
		var v = c.get(k)
		if v is String and v.begins_with("#") and v.length() == 7 and Color.html_is_valid(v):
			out[k] = Color.html(v)
	for k in LOOK_TEXTOS:
		var v = c.get(k)
		if v is String and v.length() <= 16:
			out[k] = v
		elif v is bool:
			out[k] = v
	for k in LOOK_SINO:
		out[k] = c.get(k) == true
	if not out.hat in ["rizos", "mono", "calvo", "panuelo", "gorra", "paja"]:
		out.hat = "calvo"
	if not out.pattern in ["guayabera", "flores", "jersey", "rayas", "delantal"]:
		out.pattern = "guayabera"
	return out
