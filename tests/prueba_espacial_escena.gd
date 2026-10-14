extends SceneTree
const Audit := preload("res://scripts/auditoria_espacial.gd")
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
	main.view.set_process(false)
	main.view.pie.set_process(false)
	var audit := Audit.new()
	var inicial := audit.inspeccionar(main)
	assert(inicial.is_empty(), "Reposo inicial debe estar limpio: " + str(inicial))
	var silla = main.view.seat_chairs[1]
	var antes: Vector3 = silla.position
	silla.position.x += 0.1
	assert(audit.inspeccionar(main).any(func(a): return a.tipo == "objeto_desalineado"))
	silla.position = antes
	main.view.pie.mode = "de_pie"
	main.view.pie.pos = Vector2.ZERO
	assert(audit.inspeccionar(main).any(func(a): return a.tipo == "cuerpo_en_obstaculo"))
	main.view.pie.mode = "levantando"
	assert(not audit.inspeccionar(main).any(func(a): return a.tipo == "cuerpo_en_obstaculo"))
	main.view.pie.mode = "sentado"
	var bandeja = main.view.rail_meshes[2]
	antes = bandeja.position
	bandeja.position.x += 0.1
	assert(audit.inspeccionar(main).any(func(a): return a.tipo == "bandeja_borde_descentrado"))
	bandeja.position = antes
	main.view.board_mi.position.x += 0.1
	assert(audit.inspeccionar(main).any(func(a): return a.tipo == "colision_mesa_descentrada"))
	main.view.board_mi.position.x -= 0.1
	assert(audit.inspeccionar(main).is_empty())
	var bot = BotPrueba.new(main, "prueba_espacial")
	main.add_child(bot)
	bot.set_process(false)
	main.playing = true
	var persistente := Audit.new()
	antes = silla.position
	silla.position.x += 0.1
	persistente.revisar(bot)
	persistente.revisar(bot)
	assert(persistente.emitidos.is_empty())
	silla.position = antes
	persistente.revisar(bot) # la incidencia transitoria se descarta
	silla.position.x += 0.1
	for i in 4:
		persistente.revisar(bot)
	assert(persistente.emitidos.size() == 1)
	assert(persistente.fotos == 1)
	assert(FileAccess.file_exists(bot.dir + "/espacial.jsonl"))
	assert(FileAccess.file_exists(bot.dir + "/espacial_0.png"))
	silla.position = antes
	print("PERSISTENCIA: transitorio descartado, hallazgo persistente único con foto/JSON")
	print("ESCENA ESPACIAL: reposo, silla desplazada, penetración, transición excluida, bandeja y colisión descentradas SIN FALLOS")
	await bot.terminar()
