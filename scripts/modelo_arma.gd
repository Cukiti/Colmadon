extends RefCounted
## Modelos de las armas, de bloques como todo el colmado pero con detalle:
## pistola (corredera con estrías, ventana de expulsión, miras con puntos,
## martillo, gatillo, guardamonte, riel, cargador y cachas de madera) y
## revólver (cañón con costilla, tambor con recámaras, martillo y culata curva).
## Cañón hacia −Z; el origen es donde la mano agarra la empuñadura.

static var _mats := {}


static func crear(tipo: String) -> Node3D:
	return _revolver() if tipo == "revolver" else _pistola()


static func _pistola() -> Node3D:
	var p := Node3D.new()
	var negro := _m("pavon", Color(0.2, 0.2, 0.23), 0.45, 0.45)
	var canto := _m("canto", Color(0.46, 0.47, 0.5), 0.55, 0.32)
	var hueco := _m("hueco", Color(0.02, 0.02, 0.02), 0.0, 1.0)
	var punto := _m("punto", Color(0.95, 0.95, 0.85), 0.0, 0.6, true)
	# corredera y armazón
	_b(p, Vector3(0.032, 0.03, 0.19), Vector3(0, 0.043, -0.066), negro)
	_b(p, Vector3(0.034, 0.004, 0.19), Vector3(0, 0.029, -0.066), canto)          # junta corredera-armazón
	_b(p, Vector3(0.029, 0.026, 0.16), Vector3(0, 0.014, -0.058), negro)          # armazón
	for i in 6:                                                                    # estrías de agarre
		_b(p, Vector3(0.034, 0.024, 0.003), Vector3(0, 0.044, 0.016 - i * 0.007), canto)
	_b(p, Vector3(0.004, 0.012, 0.036), Vector3(0.0155, 0.048, -0.062), hueco)     # ventana de expulsión
	_b(p, Vector3(0.002, 0.008, 0.03), Vector3(0.0175, 0.048, -0.062), canto)      # cañón visto por la ventana
	_b(p, Vector3(0.026, 0.004, 0.17), Vector3(0, 0.059, -0.066), canto)           # lomo pulido
	# cañón y boca
	_b(p, Vector3(0.016, 0.016, 0.012), Vector3(0, 0.042, -0.166), canto)
	_b(p, Vector3(0.008, 0.008, 0.004), Vector3(0, 0.042, -0.173), hueco)
	# miras: delantera con punto y trasera en U con dos puntos
	_b(p, Vector3(0.006, 0.009, 0.007), Vector3(0, 0.064, -0.152), negro)
	_b(p, Vector3(0.003, 0.003, 0.002), Vector3(0, 0.066, -0.156), punto)
	for x in [-0.009, 0.009]:
		_b(p, Vector3(0.007, 0.01, 0.008), Vector3(x, 0.064, 0.02), negro)
		_b(p, Vector3(0.003, 0.003, 0.002), Vector3(x, 0.065, 0.015), punto)
	# martillo y seguro
	var mart := _b(p, Vector3(0.01, 0.018, 0.009), Vector3(0, 0.05, 0.034), negro)
	mart.rotation.x = 0.45
	_b(p, Vector3(0.006, 0.005, 0.012), Vector3(0.017, 0.032, 0.012), canto)
	# riel bajo el cañón con ranuras
	_b(p, Vector3(0.022, 0.008, 0.06), Vector3(0, -0.002, -0.11), negro)
	for i in 3:
		_b(p, Vector3(0.024, 0.002, 0.006), Vector3(0, -0.006, -0.088 - i * 0.017), canto)
	# guardamonte y gatillo
	_b(p, Vector3(0.012, 0.005, 0.05), Vector3(0, -0.024, -0.04), negro)
	_b(p, Vector3(0.012, 0.026, 0.006), Vector3(0, -0.012, -0.065), negro)
	var gat := _b(p, Vector3(0.006, 0.018, 0.005), Vector3(0, -0.008, -0.033), canto)
	gat.rotation.x = 0.35
	# empuñadura inclinada: armazón, cachas de madera, cargador y su base
	var emp := Node3D.new()
	emp.position = Vector3(0, 0.0, 0.006)
	emp.rotation.x = -0.24
	p.add_child(emp)
	_b(emp, Vector3(0.026, 0.088, 0.042), Vector3(0, -0.044, 0.0), negro)
	var madera := _madera()
	for x in [-0.0155, 0.0155]:
		_b(emp, Vector3(0.005, 0.064, 0.034), Vector3(x, -0.045, 0.0), madera)
		_b(emp, Vector3(0.006, 0.004, 0.004), Vector3(x, -0.03, 0.0), canto)   # tornillo de la cacha
	_b(emp, Vector3(0.03, 0.01, 0.048), Vector3(0, -0.092, 0.002), canto)
	_b(emp, Vector3(0.022, 0.004, 0.036), Vector3(0, -0.098, 0.002), negro)
	return p


static func _revolver() -> Node3D:
	var p := Node3D.new()
	var acero := _m("acero", Color(0.62, 0.63, 0.66), 0.5, 0.28)
	var oscuro := _m("pavon", Color(0.2, 0.2, 0.23), 0.45, 0.45)
	var hueco := _m("hueco", Color(0.02, 0.02, 0.02), 0.0, 1.0)
	var punto := _m("punto", Color(0.95, 0.95, 0.85), 0.0, 0.6, true)
	# armazón
	_b(p, Vector3(0.026, 0.044, 0.07), Vector3(0, 0.032, -0.012), acero)
	_b(p, Vector3(0.024, 0.01, 0.05), Vector3(0, 0.058, -0.02), acero)
	# cañón largo con costilla y extractor
	_b(p, Vector3(0.017, 0.018, 0.14), Vector3(0, 0.044, -0.115), acero)
	_b(p, Vector3(0.006, 0.006, 0.14), Vector3(0, 0.056, -0.115), oscuro)
	_b(p, Vector3(0.012, 0.012, 0.08), Vector3(0, 0.026, -0.09), acero)
	_b(p, Vector3(0.008, 0.008, 0.004), Vector3(0, 0.044, -0.187), hueco)
	_b(p, Vector3(0.004, 0.012, 0.01), Vector3(0, 0.061, -0.178), oscuro)        # mira delantera
	_b(p, Vector3(0.002, 0.003, 0.002), Vector3(0, 0.066, -0.183), punto)
	_b(p, Vector3(0.012, 0.006, 0.008), Vector3(0, 0.064, 0.012), oscuro)        # mira trasera
	# tambor con seis recámaras
	var tambor := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.022
	cm.bottom_radius = 0.022
	cm.height = 0.042
	cm.radial_segments = 6
	tambor.mesh = cm
	tambor.material_override = acero
	tambor.rotation.x = PI / 2
	tambor.position = Vector3(0, 0.036, -0.03)
	p.add_child(tambor)
	for i in 6:
		var a := TAU * i / 6.0
		_b(p, Vector3(0.007, 0.007, 0.003), Vector3(cos(a) * 0.013, 0.036 + sin(a) * 0.013, -0.052), hueco)
		_b(p, Vector3(0.004, 0.004, 0.036), Vector3(cos(a + 0.52) * 0.021, 0.036 + sin(a + 0.52) * 0.021, -0.03), oscuro)   # estrías
	# martillo con espuela
	var mart := _b(p, Vector3(0.008, 0.016, 0.01), Vector3(0, 0.058, 0.024), oscuro)
	mart.rotation.x = 0.7
	# guardamonte redondo y gatillo
	_b(p, Vector3(0.01, 0.005, 0.036), Vector3(0, -0.01, -0.02), acero)
	_b(p, Vector3(0.01, 0.02, 0.005), Vector3(0, 0.0, -0.038), acero)
	var gat := _b(p, Vector3(0.005, 0.016, 0.005), Vector3(0, 0.004, -0.018), oscuro)
	gat.rotation.x = 0.4
	# culata curva de madera en dos tramos
	var madera := _madera()
	var c1 := Node3D.new()
	c1.position = Vector3(0, 0.014, 0.014)
	c1.rotation.x = -0.25
	p.add_child(c1)
	_b(c1, Vector3(0.028, 0.06, 0.036), Vector3(0, -0.028, 0.0), madera)
	var c2 := Node3D.new()
	c2.position = Vector3(0, -0.054, 0.0)
	c2.rotation.x = -0.2
	c1.add_child(c2)
	_b(c2, Vector3(0.029, 0.04, 0.038), Vector3(0, -0.016, 0.004), madera)
	_b(c2, Vector3(0.03, 0.006, 0.04), Vector3(0, -0.038, 0.004), acero)
	return p


static func _b(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _m(id: String, c: Color, metal: float, rough: float, luz := false) -> StandardMaterial3D:
	if _mats.has(id):
		return _mats[id]
	var mt := StandardMaterial3D.new()
	mt.albedo_color = c
	mt.metallic = metal
	mt.roughness = rough
	mt.metallic_specular = 0.6
	if luz:
		mt.emission_enabled = true
		mt.emission = c * 0.6
	_mats[id] = mt
	return mt


## Cachas de madera: vetas y cuadriculado en pixel art (textura de 8×16).
static func _madera() -> StandardMaterial3D:
	if _mats.has("madera"):
		return _mats.madera
	var img := Image.create(8, 16, false, Image.FORMAT_RGBA8)
	var base := Color(0.42, 0.22, 0.1)
	for y in 16:
		for x in 8:
			var c := base
			if (x + y) % 4 == 0 or (x - y + 16) % 4 == 0:
				c = base.darkened(0.28)                     # cuadriculado
			if y % 5 == 2 and x % 3 != 1:
				c = c.lightened(0.12)                       # veta
			if x == 0 or x == 7 or y == 0 or y == 15:
				c = base.darkened(0.4)                      # borde
			img.set_pixel(x, y, c)
	var mt := StandardMaterial3D.new()
	mt.albedo_texture = ImageTexture.create_from_image(img)
	mt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mt.roughness = 0.7
	_mats["madera"] = mt
	return mt
