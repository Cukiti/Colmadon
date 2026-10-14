extends SceneTree
## Ventana y perfil de pruebas: --script ... -- --autotest
func _initialize() -> void:
	call_deferred("run")

func botones(n: Node, texto: String) -> Array:
	var out := []
	if n is Button and n.text.contains(texto):
		out.append(n)
	for c in n.get_children():
		out.append_array(botones(c, texto))
	return out

func run() -> void:
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	await create_timer(2).timeout
	m.set_process(false)
	m.autotest = false
	TranslationServer.set_locale("en")
	await process_frame
	assert(m.stand_btn.text == "STAND UP")
	TranslationServer.set_locale("es")
	await process_frame
	assert(m.stand_btn.text == "PARARSE")
	for modo in ["clasico", "colmado"]:
		for remoto in [false, true]:
			m.start_game(true, modo)
			m.set_process(false)
			m._clear_overlay()
			m.g.phase = "shop"
			m.g.last_result = {"reason": "tranque", "team": 0, "seat": 0, "pts": 12, "bonus": [],
				"tranque": {"pips": [1, 8, 2, 9], "teams": [3, 17], "tie": false, "opener": 0}}
			m.online = remoto
			m.online_v = {"tranque_ok": [false, true, true, true]}
			m._tranque_pending = true
			m._tranque_screen(m.g.last_result)
			m._build_overlay()
			await create_timer(2.2).timeout
			assert(m.overlay.get_child_count() == 0)
			assert(botones(m.hud, "VISTO").size() == 1)
			root.get_texture().get_image().save_png("res://capturas/tranque_%s_%s.png" % [modo, remoto])
			var mano: int = m.g.hand_no
			m._next_hand()
			m._review_table()
			assert(m.g.hand_no == mano and not is_instance_valid(m._review_bar))
			if remoto:
				m.online_v.tranque_ok[0] = true
			else:
				botones(m.hud, "VISTO")[0].pressed.emit()
			await create_timer(0.9).timeout
			assert(not m._tranque_pending and not is_instance_valid(m.tranque_ui))
			assert(not botones(m.overlay, "SIGUIENTE MANO").is_empty())
			print("TRANQUE TRANSICION OK ", modo, " online=" , remoto)
			m.online = false
	# Vencimiento real de los 30 s sin pulsar VISTO.
	m._clear_overlay()
	m._tranque_pending = true
	m._tranque_screen(m.g.last_result)
	m._build_overlay()
	await create_timer(31.5).timeout
	assert(not m._tranque_pending and not botones(m.overlay, "SIGUIENTE MANO").is_empty())
	print("TRANQUE TIMEOUT 30 s OK")
	m._tranque_pending = true
	m._tranque_screen(m.g.last_result)
	m._build_overlay()
	m.quit_to_menu()
	m.start_game(true, "clasico")
	await create_timer(2).timeout
	assert(not m._tranque_pending and not is_instance_valid(m.tranque_ui))
	assert(botones(m.overlay, "SIGUIENTE MANO").is_empty())
	print("TRANQUE SALIR Y REINICIAR OK")
	m.queue_free()
	await process_frame
	print("TRANQUE: controles bloqueados hasta VISTO local/online SIN FALLOS")
	quit()
