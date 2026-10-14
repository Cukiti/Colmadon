extends SceneTree
const Audit = preload("res://scripts/auditoria_visual.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var panel := Control.new()
	root.add_child(panel)
	var a := Label.new()
	a.text = "Aviso largo que no cabe en esta zona"
	a.size = Vector2(40, 25)
	a.position = Vector2(10, 10)
	panel.add_child(a)
	var b := Label.new()
	b.text = "Otro aviso"
	b.position = Vector2(20, 10)
	panel.add_child(b)
	await process_frame
	var audit := Audit.new()
	var items := audit.inspeccionar(panel, Rect2(0, 0, 100, 60))
	assert(items.any(func(x): return x.tipo == "texto_fuera_pantalla"))
	assert(items.any(func(x): return x.tipo == "texto_solapado_candidato"))
	a.visible_ratio = 0.2
	b.hide()
	assert(audit.inspeccionar(panel, Rect2(0, 0, 100, 60)).is_empty())
	a.visible_ratio = 1
	a.text = "Bien"
	a.position = Vector2(5, 5)
	a.size = Vector2(80, 25)
	assert(audit.inspeccionar(panel, Rect2(0, 0, 100, 60)).is_empty())
	panel.free()
	print("VISUAL: recorte, solape, animación excluida y disposición válida SIN FALLOS")
	quit()
