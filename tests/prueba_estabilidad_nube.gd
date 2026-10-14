extends Node
## Integración explícita: -- --prueba-estabilidad --nube. Cuentas temporales, sin perfiles.
class Cliente extends "res://scripts/red.gd":
	var identidad := ""
	func conectar(_nombre: String) -> String:
		if socket != null and socket.is_connected_to_host(): return ""
		client = Nakama.create_client(CLAVE, HOST, PUERTO, "http", 5, NakamaLogger.LOG_LEVEL.NONE)
		session = await client.authenticate_device_async(identidad)
		if session.is_exception(): return "Autenticación de prueba falló"
		socket = Nakama.create_socket_from(client)
		if (await socket.connect_async(session)).is_exception(): return "Socket de prueba falló"
		_atar_socket()
		return ""
	func _recordar_sala(_code: String) -> void: pass

var clientes := []
var vistas := [{},{},{},{}]
var poses := [{},{},{},{}]
var ultimos := ["","","",""]
var checks := 0
var fallos := 0
func check(ok: bool, msg: String) -> void:
	checks += 1
	print("OK " if ok else "FALLO ",msg)
	if not ok: fallos += 1
func _ready() -> void:
	get_tree().create_timer(210).timeout.connect(func(): get_tree().quit(1))
	call_deferred("run")
func recibir_estado(v:Dictionary,i:int) -> void: vistas[i] = v
func recibir_pose(v:Dictionary,i:int) -> void: poses[i] = v
func esperar(cond:Callable,secs:=15.0) -> bool:
	var fin := Time.get_ticks_msec() + int(secs*1000)
	while not cond.call() and Time.get_ticks_msec()<fin:
		await get_tree().create_timer(0.1).timeout
	return cond.call()
func run() -> void:
	if not OS.get_cmdline_user_args().has("--nube"):
		get_tree().quit(1)
		return
	for i in 4:
		var c := Cliente.new()
		c.identidad = "qa-estabilidad-" + str(Time.get_ticks_usec()) + "-" + str(i)
		add_child(c)
		c.estado.connect(recibir_estado.bind(i))
		c.poses.connect(recibir_pose.bind(i))
		clientes.append(c)
	check(await clientes[0].crear_sala("QA reloj 0",{},"clasico",200,false)=="","crear sala")
	if clientes[0].match_id.is_empty(): get_tree().quit(1); return
	await get_tree().create_timer(1.5).timeout
	for i in range(1,4):
		check(await clientes[i].unirse(clientes[0].codigo,"QA reloj " + str(i),{})=="","unir cliente " + str(i))
	clientes[0].enviar(clientes[0].OP_EMPEZAR)
	var fin := Time.get_ticks_msec()+35000
	while vistas[0].get("phase","") != "play" and Time.get_ticks_msec()<fin:
		for i in 4: repartir(i)
		await get_tree().create_timer(0.3).timeout
	check(await esperar(func(): return vistas.all(func(v): return v.get("phase","")=="play")),"reparto cuatro humanos")
	var actor := -1
	for i in 4:
		if int(vistas[i].get("turn",-1))==0: actor=i
	if actor<0: get_tree().quit(1); return
	var c = clientes[actor]
	c.enviar(c.OP_POSE,{"st":1})
	await get_tree().create_timer(2.6).timeout
	var inicio := Time.get_ticks_msec()
	var congelado := false
	var descongelado := false
	while Time.get_ticks_msec()-inicio<96000:
		c.enviar(c.OP_POSE,{"st":2,"x":0,"z":1.5,"yaw":0})
		var v:Dictionary=vistas[actor]
		var t := Time.get_ticks_msec()-inicio
		if t>2000 and t<50000 and v.get("reloj_parado",false): congelado=true
		if t>65000 and not v.get("reloj_parado",true): descongelado=true
		if v.get("seats",[]).size()==4 and v.seats[0].get("away",false) and int(v.get("turn",0))!=0: break
		await get_tree().create_timer(0.25).timeout
	check(congelado,"reloj se congela de pie")
	check(descongelado,"límite 60 s vuelve a correr")
	check(vistas[actor].seats[0].get("away",false),"timeout marca ausente")
	check(int(vistas[actor].turn)!=0,"bot juega el turno agotado")
	for i in 8:
		c.enviar(c.OP_POSE,{"st":2,"x":0,"z":1.5,"yaw":0})
		c.enviar(c.OP_MANO,{"st":0,"side":0})
		await get_tree().create_timer(0.25).timeout
	check(vistas[actor].seats[0].get("away",false),"poses y manos no reactivan ausente")
	c.enviar(c.OP_AQUI)
	check(await esperar(func(): return not vistas[actor].seats[0].get("away",true)),"actividad explícita vuelve")
	c.enviar(c.OP_POSE,{"st":0})
	fin=Time.get_ticks_msec()+60000
	while vistas[0].get("phase","")=="play" and Time.get_ticks_msec()<fin:
		for i in 4:
			if vistas[i].get("phase","")=="play" and int(vistas[i].turn)==0: jugar(i)
		await get_tree().create_timer(0.25).timeout
	check(vistas[0].get("phase","")=="shop","fin de mano llega a tienda")
	if vistas[0].get("phase","")=="shop":
		clientes[0].enviar(c.OP_POSE,{"st":1})
		await get_tree().create_timer(2.6).timeout
		clientes[0].enviar(c.OP_POSE,{"st":2,"x":0,"z":1.5,"yaw":0})
		check(await esperar(func(): return poses[0].get("poses",[]).size()==4 and int(poses[0].poses[0].st)==2),"tienda conserva postura de pie")
	for cl in clientes:
		await cl.salir()
		if cl.socket != null: cl.socket.close()
	print("ESTABILIDAD NUBE ",checks," comprobaciones · ",fallos," fallos")
	get_tree().quit(0 if fallos==0 else 1)
func repartir(i:int) -> void:
	var v:Dictionary=vistas[i]
	if v.get("phase","")!="draw": return
	if v.pool_taken.values().filter(func(s): return int(s)==0).size()>=7: return
	for idx in 28:
		if idx%4==i and not v.pool_taken.has(str(idx)):
			var firma:=str(v.hand_no,":",idx)
			if ultimos[i]==firma: return
			ultimos[i]=firma
			clientes[i].enviar(clientes[i].OP_ROBAR,{"idx":idx})
			return
func jugar(i:int) -> void:
	var v:Dictionary=vistas[i]
	var firma:=JSON.stringify([v.hand_no,v.chain,v.hands[0]],"",true)
	if ultimos[i]==firma: return
	ultimos[i]=firma
	for t in v.hands[0]:
		if v.chain.is_empty():
			if not v.first_hand or (int(t[0])==6 and int(t[1])==6):
				clientes[i].enviar(clientes[i].OP_JUGAR,{"tile":t,"side":0}); return
			continue
		for side in [-1,1]:
			var end:=int(v.left_end if side==-1 else v.right_end)
			if int(t[0])==end or int(t[1])==end:
				clientes[i].enviar(clientes[i].OP_JUGAR,{"tile":t,"side":side}); return
	clientes[i].enviar(clientes[i].OP_PASAR)
