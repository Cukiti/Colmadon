extends Node
var fallos := 0
func check(ok: bool, msg: String) -> void:
	if not ok:
		fallos += 1
		print("FALLO ESTABILIDAD: ", msg)
func _ready() -> void:
	get_tree().create_timer(35).timeout.connect(func(): get_tree().quit(1))
	call_deferred("run")
func run() -> void:
	var m = load("res://main.tscn").instantiate()
	add_child(m)
	await get_tree().create_timer(2).timeout
	m.set_process(false)
	m.autotest = false
	m.online = true
	m.playing = true
	m.hud.visible = true
	var g = m.g
	g.phase = "play"
	g.turn = 1
	var v := {"seats":[],"phase":"play","modo":"clasico","hand_no":g.hand_no,"first_hand":true,"turn":1,"opener":0,"last_seat":0,"chain":[],"origin":0,"left_end":-1,"right_end":-1,"scores":[0,0],"coins":[0,0,0,0],"cards":[[],[],[],[]],"drinks":[[],[],[],[]],"offers":[],"reveal_partner":false,"revealed":[],"extra_turn":false,"hands":[[],[],[],[]],"stats":{},"bot_purchases":[],"events":[],"secs":30,"reloj_parado":true,"meta":200}
	var look := {"skin":"#aabbcc","hair":"#112233","shirt":"#445566","pants":"#778899","hat":"calvo","pattern":"rayas"}
	for s in 4:
		v.seats.append({"bot":false,"connected":true,"away":false,"name":"Prueba" + str(s),"avatar":look.duplicate(),"preset":"nena"})
	m._on_estado(v)
	var ch = m.view.heads[1]
	ch.act("wave")
	var reversed := {}
	var keys := look.keys()
	keys.reverse()
	for key in keys: reversed[key] = look[key]
	for s in 4: v.seats[s].avatar = reversed.duplicate()
	m._on_estado(v)
	check(m.view.heads[1] == ch, "aspecto idéntico con orden distinto recrea personaje")
	check(m.view.heads[1]._action == "wave", "se pierde gesto al recibir estado idéntico")
	m._tick_reloj()
	var text: String = m.turn_lbl.text
	m._on_estado(v)
	check(m.turn_lbl.text == text, "estado repetido borra sufijo de reloj parado")
	m.view.pie.set_remote(1,2,Vector2(1,1),0)
	m.view.heads[1]._action = ""
	m._turno_ms = Time.get_ticks_msec() - 9000
	m._pensada_vista = -1
	m._tick_pensada()
	check(m.view.heads[1]._action == "", "persona de pie tamborilea mesa por pensada")
	v.seats[0].away = true
	m.online_v = v
	m._tick_away()
	m.t_anim = 1.0
	m._tick_away()
	check(is_equal_approx(m.away_banner.modulate.a,1.0), "aviso ausente parpadea por modulación periódica")
	v.seats[0].away = false
	m._tick_away()
	m._tick_away()
	check(m.floats.filter(func(f): return str(f.get("text", "")).contains("De vuelta")).size() <= 1, "regreso duplicado antes de eliminar banner")
	m.view.pie.mode = "de_pie"
	v.turn = 0
	v.chain = [[6,6]]
	v.left_end = 6
	v.right_end = 6
	v.hands[0] = [[0,0]]
	m._on_estado(v)
	check(m.turn_lbl.text.contains("Siéntate"), "sin ficha legal se pide PASO a persona de pie")
	print("ESTABILIDAD ONLINE ", fallos, " fallos")
	m.online = false
	m.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if fallos == 0 else 1)