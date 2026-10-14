extends Node
## godot --headless --path . res://tests/prueba_revancha.tscn
## La libreta escucha vistas reales de Red sin arrancar una partida ni tocar perfiles.

var fallos := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		fallos += 1
		print("FALLO ", message)

func _ready() -> void:
	var main = load("res://scripts/main.gd").new()
	var red = load("res://scripts/red.gd").new()
	main.red = red
	var notebook := VBoxContainer.new()
	notebook.size = Vector2(300, 200)
	add_child(notebook)
	var again := Button.new()
	again.text = "REVANCHA"
	notebook.add_child(again)
	main._build_revancha_notice(again, notebook)
	var badge: Label = again.get_node("RevanchaContador")
	var notice: Label = notebook.get_node("RevanchaAviso")
	check(not badge.visible and not again.disabled, "compatible con vistas antiguas sin votos")
	var v := {"phase": "over", "revancha": [false, true, false, false], "seats": [
		{"name": "Ana", "bot": false}, {"name": "Potito", "bot": false},
		{"name": "Beto", "bot": false}, {"name": "Bot", "bot": true}]}
	TranslationServer.set_locale("es")
	red.estado.emit(v)
	check(badge.visible and badge.text == "1", "voto remoto visible")
	check(notice.text == "Potito quiere la revancha", "aviso con nombre remoto")
	check(not again.disabled, "el otro jugador puede votar")
	v.revancha[0] = true
	red.estado.emit(v)
	check(badge.text == "2" and again.disabled, "voto propio confirmado y botón conservado")
	red.estado.emit(v)
	check(badge.text == "2", "vista repetida no duplica votos")
	TranslationServer.set_locale("en")
	red.estado.emit(v)
	check(notice.text == "Want a rematch: Ana, Potito", "aviso traducido")
	await get_tree().process_frame
	await get_tree().process_frame
	check(badge.size == Vector2(20, 20), "círculo de 20 píxeles")
	check(badge.position.is_equal_approx(Vector2(again.size.x - 10, -10)), "esquina superior derecha")
	v.phase = "pick"
	v.revancha = [false, false, false, false]
	red.estado.emit(v)
	check(not badge.visible and notice.text == "" and not again.disabled, "reinicio de revancha")
	notebook.queue_free()
	await get_tree().process_frame
	check(red.estado.get_connections().is_empty(), "cerrar libreta desconecta su actualización")
	red.estado.emit(v)
	main.free()
	red.free()
	print("REVANCHA UI ", "SIN FALLOS" if fallos == 0 else str(fallos) + " FALLOS")
	get_tree().quit(0 if fallos == 0 else 1)
