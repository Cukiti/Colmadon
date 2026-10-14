extends Node
## Efectos de sonido sintetizados en código (sin archivos): fichas, mesa,
## vasos, monedas y ambiente del colmado. Provisionales hasta tener audio final.

const RATE := 22050

var _streams := {}
var _players: Array = []
var _next := 0
var _ambient: AudioStreamPlayer
var fx_db := 0.0
var _loop: AudioStreamPlayer   # sonidos en bucle (redoble del tranque)


func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams = {
		"clack": _clack(0.0),
		"slam": _clack(1.0),
		"knock": _knock(),
		"pick": _tick(2400.0, 0.03, 0.35),
		"hover": _tick(3200.0, 0.015, 0.12),
		"shuffle": _shuffle(),
		"clink": _clink(),
		"gulp": _gulp(),
		"coin": _coin(),
		"card": _whoosh(),
		"win": _jingle([523.25, 659.25, 783.99, 1046.5], 0.11),
		"lose": _jingle([392.0, 349.23, 311.13], 0.16),
		"steam": _noise_burst(0.5, 0.15, 4000.0),
		"chalk": _chalk(),
		# aura de pases (sube de tono con cada nivel) y el +30 épico
		"aura1": _rise(320.0, 640.0, 0.35, 0.18),
		"aura2": _rise(300.0, 900.0, 0.45, 0.22),
		"aura3": _rise(260.0, 1500.0, 0.7, 0.28),
		"boom": _boom(),
		"tick": _tick(1800.0, 0.02, 0.3),
		"chair": _scrape(),
		"step": _step(),
		"latido": _heartbeat(),
		"redoble": _drumroll(),
		"disparo": _disparo(),
		"impacto": _tick(900.0, 0.05, 0.6),
	}
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = _ambience()
	_ambient.volume_db = -20.0
	add_child(_ambient)
	_ambient.play()
	_loop = AudioStreamPlayer.new()
	add_child(_loop)


## Al cerrar, todo callado: el ambiente en bucle seguía sonando al salir y
## Godot avisaba de un sonido sin liberar (ObjectDB) en las pruebas.
func _exit_tree() -> void:
	for p in _players + [_ambient, _loop]:
		if is_instance_valid(p):
			p.stop()
			p.stream = null


## Volúmenes de 0 a 1 (ajustes de la radio).
func set_volumes(fx: float, amb: float) -> void:
	fx_db = linear_to_db(max(fx, 0.0001))
	_ambient.volume_db = -20.0 + linear_to_db(max(amb, 0.0001))


func play(name: String, vol_db := 0.0, pitch_var := 0.08) -> void:
	if not _streams.has(name):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.volume_db = vol_db + fx_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


## Un sonido en bucle (solo uno a la vez): on = suena, off = se apaga suave.
func bucle(name: String, on: bool, vol_db := -10.0) -> void:
	if not on:
		if _loop.playing:
			var tw := _loop.create_tween()
			tw.tween_property(_loop, "volume_db", -60.0, 0.4)
			tw.tween_callback(_loop.stop)
		return
	if not _streams.has(name):
		return
	if _loop.playing and _loop.stream == _streams[name]:
		_loop.volume_db = vol_db + fx_db
		return
	_loop.stream = _streams[name]
	_loop.volume_db = vol_db + fx_db
	_loop.play()


# ---------------------------------------------------------------- síntesis


## Latido: dos golpes graves (pum-pum), para cuando se decide el tranque.
func _heartbeat() -> AudioStreamWAV:
	var b := _buf(0.6)
	for i in b.size():
		var t := float(i) / RATE
		var v := 0.0
		for st in [[0.0, 1.0], [0.18, 0.7]]:
			var u: float = t - st[0]
			if u >= 0.0:
				v += sin(TAU * (55.0 + 25.0 * exp(-u * 30.0)) * u) * exp(-u * 18.0) * st[1]
		b[i] = v * 0.9
	return _to_wav(b)


## Redoble suave de tambor (en bucle): golpecitos rápidos con ruido de parche.
func _drumroll() -> AudioStreamWAV:
	var b := _buf(1.0)
	var paso := 1.0 / 22.0
	for i in b.size():
		var t := float(i) / RATE
		var u := fmod(t, paso)
		var golpe := randf_range(-1, 1) * exp(-u * 160.0) * 0.5 + sin(TAU * 180.0 * u) * exp(-u * 90.0) * 0.4
		b[i] = golpe * (0.8 + 0.2 * sin(TAU * 3.0 * t))
	return _to_wav(b, true)

func _to_wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clamp(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


## Ficha de hueso contra madera: chasquido agudo + golpe sordo.
func _clack(strength: float) -> AudioStreamWAV:
	var b := _buf(0.25 + strength * 0.15)
	var thump_f := 140.0 - strength * 40.0
	for i in b.size():
		var t := float(i) / RATE
		var click := randf_range(-1, 1) * exp(-t * 900.0)
		var tone := (sin(TAU * 2100.0 * t) * 0.5 + sin(TAU * 3350.0 * t) * 0.3) * exp(-t * 90.0)
		var thump := sin(TAU * thump_f * t) * exp(-t * (30.0 - strength * 12.0)) * (0.7 + strength)
		b[i] = (click * 0.6 + tone * 0.35 + thump * 0.6) * 0.8
	return _to_wav(b)


## Dos toques con los nudillos en la mesa: «paso».
## Disparo de pistola: chasquido seco, golpe grave y cola corta del local.
func _disparo() -> AudioStreamWAV:
	var b := _buf(0.6)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var n := randf_range(-1, 1)
		lp = lerp(lp, n, 0.35)
		var v := n * exp(-t * 90.0) * 0.9 + lp * exp(-t * 9.0) * 0.5
		v += sin(TAU * (90.0 - t * 60.0) * t) * exp(-t * 22.0) * 0.9
		b[i] = clamp(v, -1.0, 1.0) * 0.85
	return _to_wav(b)


func _knock() -> AudioStreamWAV:
	var b := _buf(0.4)
	for i in b.size():
		var t := float(i) / RATE
		var v := 0.0
		for start in [0.0, 0.14]:
			var u: float = t - start
			if u >= 0.0:
				v += (sin(TAU * 110.0 * u) * 0.9 + sin(TAU * 260.0 * u) * 0.4) * exp(-u * 38.0)
				v += randf_range(-1, 1) * exp(-u * 600.0) * 0.4
		b[i] = v * 0.7
	return _to_wav(b)


func _tick(freq: float, length: float, vol: float) -> AudioStreamWAV:
	var b := _buf(length + 0.02)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(TAU * freq * t) + randf_range(-0.5, 0.5)) * exp(-t / length * 4.0) * vol
	return _to_wav(b)


## Barajar: muchas fichas chocando y arrastrándose.
func _shuffle() -> AudioStreamWAV:
	var b := _buf(1.4)
	var hits: Array = []
	for i in 70:
		hits.append([randf_range(0.0, 1.3), randf_range(1600.0, 3600.0), randf_range(0.15, 0.5)])
	for i in b.size():
		var t := float(i) / RATE
		var env: float = sin(clamp(t / 1.4, 0.0, 1.0) * PI)
		var v := randf_range(-1, 1) * 0.06 * env
		for h in hits:
			var u: float = t - h[0]
			if u >= 0.0 and u < 0.05:
				v += sin(TAU * h[1] * u) * exp(-u * 150.0) * h[2]
		b[i] = v * 0.7
	return _to_wav(b)


## Vaso: tintineo inarmónico.
func _clink() -> AudioStreamWAV:
	var b := _buf(0.6)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(TAU * 2637.0 * t) * 0.5 + sin(TAU * 3951.0 * t) * 0.3 + sin(TAU * 5274.0 * t) * 0.15) * exp(-t * 9.0) * 0.5
	return _to_wav(b)


## Trago: «glup» que baja de tono.
func _gulp() -> AudioStreamWAV:
	var b := _buf(0.22)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f: float = lerp(420.0, 140.0, t / 0.22)
		ph += TAU * f / RATE
		var env: float = sin(clamp(t / 0.22, 0.0, 1.0) * PI)
		b[i] = sin(ph) * env * 0.8
	return _to_wav(b)


## Tiza sobre pizarra: rasgueos cortos de ruido agudo.
func _chalk() -> AudioStreamWAV:
	var b := _buf(0.45)
	var hp := 0.0
	var prev := 0.0
	var strokes: Array = []
	for i in 5:
		strokes.append([randf_range(0.0, 0.36), randf_range(0.04, 0.08)])
	for i in b.size():
		var t := float(i) / RATE
		var n := randf_range(-1, 1)
		hp = n - prev   # paso alto: suena a roce
		prev = n
		var env := 0.0
		for st in strokes:
			var u: float = t - st[0]
			if u >= 0.0 and u < st[1]:
				env = max(env, sin(u / st[1] * PI))
		b[i] = hp * env * 0.18 * (0.7 + 0.3 * sin(t * 900.0))
	return _to_wav(b)


func _coin() -> AudioStreamWAV:
	var b := _buf(0.35)
	for i in b.size():
		var t := float(i) / RATE
		var f := 1318.5 if t < 0.07 else 1760.0
		b[i] = (1.0 if sin(TAU * f * t) > 0 else -1.0) * exp(-t * 9.0) * 0.25
	return _to_wav(b)


func _whoosh() -> AudioStreamWAV:
	var b := _buf(0.25)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var k: float = 0.05 + 0.4 * (t / 0.25)
		lp += (randf_range(-1, 1) - lp) * k
		b[i] = lp * sin(clamp(t / 0.25, 0.0, 1.0) * PI) * 0.9
	return _to_wav(b)


func _noise_burst(length: float, vol: float, _hz: float) -> AudioStreamWAV:
	var b := _buf(length)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (randf_range(-1, 1) - lp) * 0.5
		b[i] = lp * sin(clamp(t / length, 0.0, 1.0) * PI) * vol
	return _to_wav(b)


func _jingle(notes: Array, step: float) -> AudioStreamWAV:
	var b := _buf(step * notes.size() + 0.4)
	for i in b.size():
		var t := float(i) / RATE
		var v := 0.0
		for n in notes.size():
			var u: float = t - n * step
			if u >= 0.0:
				var f: float = notes[n]
				v += (sin(TAU * f * u) + 0.3 * sin(TAU * f * 2.0 * u)) * exp(-u * 5.0) * 0.22
		b[i] = v
	return _to_wav(b)


## Subida de energía: barrido de tono con trémolo y chispitas al final.
func _rise(f0: float, f1: float, length: float, vol: float) -> AudioStreamWAV:
	var b := _buf(length + 0.15)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var u: float = clamp(t / length, 0.0, 1.0)
		var f: float = lerp(f0, f1, u * u)
		ph += TAU * f / RATE
		var env: float = sin(u * PI * 0.5) * (1.0 if t < length else exp(-(t - length) * 30.0))
		var trem := 0.75 + 0.25 * sin(t * 38.0)
		var v := (sin(ph) + 0.35 * sin(ph * 2.0) + 0.15 * sin(ph * 3.0)) * env * trem * vol
		if u > 0.7:
			v += randf_range(-1, 1) * 0.04 * (u - 0.7) * 3.0
		b[i] = v
	return _to_wav(b)


## Pisada sobre el suelo de madera: golpe sordo y un crujido corto.
func _step() -> AudioStreamWAV:
	var b := _buf(0.16)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (randf_range(-1, 1) - lp) * 0.15
		b[i] = (sin(TAU * 85.0 * t) * 0.6 + lp * 0.8) * exp(-t * 32.0) * 0.5
	return _to_wav(b)


## Silla que se arrastra por el suelo de madera.
func _scrape() -> AudioStreamWAV:
	var b := _buf(0.5)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (randf_range(-1, 1) - lp) * 0.25
		var grain := 0.6 + 0.4 * sin(TAU * 38.0 * t + sin(t * 9.0) * 3.0)
		var env: float = sin(clamp(t / 0.5, 0.0, 1.0) * PI)
		b[i] = (lp * grain + sin(TAU * 140.0 * t) * 0.15 * grain) * env * 0.5
	return _to_wav(b)


## Golpe épico: bombo grave, platillo y campanita dorada.
func _boom() -> AudioStreamWAV:
	var b := _buf(1.4)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var kick := sin(TAU * (90.0 - 50.0 * min(t * 4.0, 1.0)) * t) * exp(-t * 5.0) * 0.8
		lp += (randf_range(-1, 1) - lp) * 0.7
		var crash := lp * exp(-t * 3.5) * 0.25
		var bell := (sin(TAU * 1568.0 * t) + 0.5 * sin(TAU * 2349.0 * t)) * exp(-t * 4.0) * 0.12 * (1.0 if t > 0.05 else 0.0)
		b[i] = kick + crash + bell
	return _to_wav(b)


## Ambiente del colmado: murmullo grave y algún vaso a lo lejos (en bucle).
func _ambience() -> AudioStreamWAV:
	var b := _buf(6.0)
	var brown := 0.0
	var clinks: Array = []
	for i in 4:
		clinks.append([randf_range(0.3, 5.5), randf_range(2400.0, 3600.0)])
	for i in b.size():
		var t := float(i) / RATE
		brown = clamp(brown + randf_range(-1, 1) * 0.02, -1.0, 1.0)
		var murmur := brown * (0.6 + 0.4 * sin(t * 1.7) * sin(t * 0.6))
		var v := murmur * 0.5
		for c in clinks:
			var u: float = t - c[0]
			if u >= 0.0 and u < 0.4:
				v += sin(TAU * c[1] * u) * exp(-u * 12.0) * 0.08
		# fundido en los bordes para que el bucle no haga clic
		var edge: float = min(t, 6.0 - t)
		b[i] = v * clamp(edge * 4.0, 0.0, 1.0)
	return _to_wav(b, true)
