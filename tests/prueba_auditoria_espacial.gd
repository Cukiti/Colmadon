extends SceneTree
const Audit := preload("res://scripts/auditoria_espacial.gd")
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(Audit.penetracion_circulo(Vector2(0, 0), 0.22, Rect2(-1, -1, 2, 2)) > 1.0)
	assert(Audit.penetracion_circulo(Vector2(1.22, 0), 0.22, Rect2(-1, -1, 2, 2)) < 0.001)
	var a := MeshInstance3D.new()
	a.mesh = BoxMesh.new()
	a.name = "SolidoA"
	root.add_child(a)
	var b := MeshInstance3D.new()
	b.mesh = BoxMesh.new()
	b.name = "SolidoB"
	root.add_child(b)
	b.position.x = 0.5
	assert(Audit.candidatos_solidos([a, b]).size() == 1)
	b.position.x = 2.0
	assert(Audit.candidatos_solidos([a, b]).is_empty())
	b.position.x = 0.5
	a.set_meta("audit_union", "ensamble")
	b.set_meta("audit_union", "ensamble")
	assert(Audit.candidatos_solidos([a, b]).is_empty())
	assert(not Audit.alineacion(b, Transform3D.IDENTITY).is_empty())
	b.transform = Transform3D.IDENTITY
	assert(Audit.alineacion(b, Transform3D.IDENTITY).is_empty())
	a.free()
	b.free()
	print("ESPACIAL: penetración, contacto permitido, solape, separación, ensamble y alineación SIN FALLOS")
	quit()
