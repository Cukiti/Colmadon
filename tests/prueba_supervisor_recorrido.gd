extends SceneTree
## Integración: controles reales y eventos de ratón, en perfil --autotest.
class BotPrueba extends "res://scripts/recorrido.gd":
	func _correr() -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(2.0).timeout
	main.set_process(false)
	var bot = BotPrueba.new(main, "prueba_supervisor")
	main.add_child(bot)
	# Identificación ES/EN sin tocar los botones del producto.
	var b := Button.new()
	b.text = "PASS"
	main.hud.add_child(b)
	assert(bot.boton("PASO") == b)
	b.text = "NEXT HAND"
	assert(bot.boton("SIGUIENTE MANO") == b)
	b.queue_free()
	await process_frame
	for lleva in [true, false]:
		var g = main.g
		g.new_game()
		g.human_pick(g.offers[0][0])
		g.first_hand = false
		g.starter_next = 0
		g.finish_draw(g.auto_picks([]))
		g.play(0, g.hands[0][0], 0)
		g.turn = 3
		var invalida := Vector2i(-1, -1)
		for x in 7:
			if x != g.left_end and x != g.right_end:
				invalida = Vector2i(x, x)
				break
		g.hands[3] = [Vector2i(g.left_end, g.left_end)] if lleva else [invalida]
		g.pass_fake(3) if lleva else g.pass_turn(3)
		g.turn = 0
		g.last_pass_seat = 3
		g.call_chivo(0, true)
		main.playing = true
		main._tick_revision()
		await create_timer(0.2).timeout
		assert(not g.revision.is_empty())
		assert(await bot._atender_pendientes())
		assert(g.revision.is_empty())
		assert(bot._fallos_bot == 0)
		print("REVISION RESUELTA ", "ficha válida" if lleva else "NO LLEVABA")
		await process_frame
	# Un objetivo imposible debe fallar y conservar evidencia; no dar OK.
	var fallos: int = bot._fallos_bot
	assert(not await bot.hasta(func(): return false, 0.1))
	assert(bot._fallos_bot == fallos + 1)
	assert(not await bot.hasta(func(): return false, 0.1, false))
	assert(bot._fallos_bot == fallos + 1) # sondeo opcional no cuenta como fallo
	assert(FileAccess.file_exists(bot.dir + "/espera_agotada_%d.json" % (bot._cobertura[-1].fotograma)))
	main.g.phase = "lobby"
	main.view.top_view = false
	main.view.counting = false
	main.paused = false
	bot._limite_progreso = 0.2
	var antes: float = bot._reloj
	fallos = bot._fallos_bot
	assert(not await bot._jugar_hasta(func(): return false, 5.0))
	assert(bot._fallos_bot == fallos + 3) # 2 recuperaciones y abandono
	assert(bot._reloj - antes < 5.0)
	print("RECUPERACION: dos intentos y abandono verificables")
	print("SUPERVISOR: ES/EN, ambas revisiones, timeout y sondeo SIN FALLOS")
	await bot.terminar()
