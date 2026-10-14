extends Node
## La radio del mostrador: música del juego («Colmadón FM», compuesta en código
## mientras no haya música final) o la música del propio jugador («Tu música»).
##
## Tu música: canciones MP3, OGG o WAV que el jugador pone en su carpeta
## user://musica (en PC se abre con un botón; en móvil se añaden con el
## selector de archivos y se copian ahí). Solo suenan en su dispositivo: nunca
## se envían por la red ni se reparten con el juego, así que no hay problema de
## derechos para Colmadón (igual que un reproductor de música).

##
## Online (2026-10-09) Colmadón FM es de la sala: el servidor dice qué pista
## suena y desde cuándo, y todos la oyen en el mismo punto; cualquiera toca la
## radio del colmado para pasar de pista o apagarla. «Tu música» sigue siendo
## solo tuya (si la pones, dejas de oír la de la sala).

signal cambio   # cambió la emisora, la canción o si suena

const DIR := "user://musica"
const EXTS := ["mp3", "ogg", "wav"]
const RATE := 22050

var player: AudioStreamPlayer
var emisora := "fm"     # fm, mia, off
var canciones: PackedStringArray = []
var actual := 0
const PISTAS := 3
var _fm: Array = []   # AudioStreamWAV de cada pista de Colmadón FM
var _hilo: Thread
var _vol := 0.6
var _cerca := 1.0     # 0..1: más fuerte cerca de la radio del colmado
var pista := 0
var fm_on := true
# radio de la sala (online)
var compartida := false
var _sala := {"on": true, "pista": 0, "t": 0.0, "ms": 0}
var _revisar := 0.0


func _process(dt: float) -> void:
	# Colmadón FM compuesta: se montan las pistas y, si sigue puesta, suena
	if _hilo != null and not _hilo.is_alive():
		var datos: Array = _hilo.wait_to_finish()
		_hilo = null
		_fm.clear()
		for data in datos:
			var w := AudioStreamWAV.new()
			w.format = AudioStreamWAV.FORMAT_16_BITS
			w.mix_rate = RATE
			w.data = data
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_end = data.size() / 2
			_fm.append(w)
		if emisora == "fm":
			_tocar_fm()
			cambio.emit()
	# en la sala, cada poco se comprueba que sigue al compás de los demás
	if compartida and emisora == "fm":
		_revisar -= dt
		if _revisar <= 0.0:
			_revisar = 2.0
			_tocar_fm()


## Online: lo que suena en la sala (del estado del servidor).
func sync_sala(on: bool, p: int, t: float) -> void:
	var antes := str(_sala.on, _sala.pista)
	_sala = {"on": on, "pista": p, "t": t, "ms": Time.get_ticks_msec()}
	if compartida and emisora == "fm":
		_tocar_fm()
		if antes != str(on, p):
			cambio.emit()


func set_compartida(v: bool) -> void:
	if v == compartida:
		return
	compartida = v
	if emisora == "fm":
		_tocar_fm()
	cambio.emit()


## Tocar la radio sin conexión: siguiente pista y, tras la última, apagada.
func tocar_local() -> void:
	if not fm_on:
		fm_on = true
		pista = 0
	elif pista + 1 >= PISTAS:
		fm_on = false
	else:
		pista += 1
	if emisora != "fm":
		emisora = "fm"
	_tocar_fm(true)
	cambio.emit()


## Pone la pista que toca: la de la sala (en su punto) o la tuya.
func _tocar_fm(desde_cero := false) -> void:
	if _fm.is_empty():
		if _hilo == null:
			# se componen en otro hilo (~2 s) para no congelar la pantalla
			_hilo = Thread.new()
			_hilo.start(_componer_todas)
		return
	var on: bool = _sala.on if compartida else fm_on
	var p: int = clampi(int(_sala.pista if compartida else pista), 0, _fm.size() - 1)
	if not on:
		player.stop()
		return
	var w: AudioStreamWAV = _fm[p]
	var largo: float = w.loop_end / float(RATE)
	var pos := 0.0
	if compartida:
		pos = fposmod(float(_sala.t) + (Time.get_ticks_msec() - int(_sala.ms)) / 1000.0, largo)
	if player.stream != w or not player.playing:
		player.stream = w
		player.play(pos)
	elif compartida and absf(player.get_playback_position() - pos) > 0.35:
		player.seek(pos)
	elif desde_cero:
		player.play(0.0)


## Más fuerte cuanto más cerca de la radio del colmado (0..1); solo la FM.
func set_cercania(k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	if absf(k - _cerca) < 0.01:
		return
	_cerca = k
	set_volumen(_vol)


func _exit_tree() -> void:
	if _hilo != null:
		_hilo.wait_to_finish()


func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.bus = "Master"
	add_child(player)
	player.finished.connect(_siguiente_sola)
	DirAccess.make_dir_recursive_absolute(DIR)
	leer_carpeta()


## Volumen de la música de 0 a 1 (ajustes).
func set_volumen(v: float) -> void:
	_vol = v
	var k: float = _cerca if emisora == "fm" else 1.0
	player.volume_db = -8.0 + linear_to_db(max(v * k, 0.0001))


func poner(e: String) -> void:
	emisora = e
	player.stop()
	match e:
		"fm":
			_tocar_fm()
		"mia":
			leer_carpeta()
			_tocar(actual)
	cambio.emit()


func sonando() -> bool:
	return player.playing


func pausa() -> void:
	if player.playing:
		player.stream_paused = not player.stream_paused
	elif emisora != "off":
		poner(emisora)
	cambio.emit()


func siguiente(d := 1) -> void:
	if emisora != "mia" or canciones.is_empty():
		return
	actual = (actual + d + canciones.size()) % canciones.size()
	_tocar(actual)
	cambio.emit()


## Nombre de lo que suena, para la pantalla de la radio.
func titulo() -> String:
	match emisora:
		"fm":
			var on: bool = _sala.on if compartida else fm_on
			if not on:
				return tr("Colmadón FM apagada · toca la radio del colmado")
			return tr("Colmadón FM · pista %d de %d") % [int(_sala.pista if compartida else pista) + 1, PISTAS]
		"mia":
			if canciones.is_empty():
				return tr("Tu carpeta de música está vacía")
			return canciones[actual].get_basename()
	return tr("Radio apagada")


func leer_carpeta() -> void:
	var out: Array = []
	var d := DirAccess.open(DIR)
	if d:
		for f in d.get_files():
			if f.get_extension().to_lower() in EXTS:
				out.append(f)
	out.sort()
	canciones = PackedStringArray(out)
	actual = clampi(actual, 0, max(canciones.size() - 1, 0))


## Copia canciones elegidas con el selector del sistema a la carpeta del juego.
## Devuelve cuántas se copiaron.
func importar(rutas: PackedStringArray) -> int:
	var n := 0
	for r in rutas:
		var ext := r.get_extension().to_lower()
		if not ext in EXTS:
			continue
		var data := FileAccess.get_file_as_bytes(r)
		if data.is_empty():
			continue
		var f := FileAccess.open(DIR.path_join(r.get_file()), FileAccess.WRITE)
		if f:
			f.store_buffer(data)
			f.close()
			n += 1
	leer_carpeta()
	return n


func ruta_carpeta() -> String:
	return ProjectSettings.globalize_path(DIR)


func _tocar(i: int) -> void:
	if canciones.is_empty():
		player.stop()
		return
	var path := DIR.path_join(canciones[i])
	var st: AudioStream = null
	match path.get_extension().to_lower():
		"mp3":
			st = AudioStreamMP3.load_from_file(path)
		"ogg":
			st = AudioStreamOggVorbis.load_from_file(path)
		"wav":
			st = AudioStreamWAV.load_from_file(path)
	if st == null:
		return
	player.stream = st
	player.stream_paused = false
	player.play()


func _siguiente_sola() -> void:
	if emisora == "mia" and canciones.size() > 0:
		siguiente(1)


# ---------------------------------------------------------------- Colmadón FM

## Un bucle suave de bachata: güira, bongó, bajo y requinto con acordes
## Am–F–C–G (8 compases a 128 pulsos). Provisional hasta la música final.
## Devuelve las muestras en 16 bits (corre en un hilo: no toca la escena).
func _componer_todas() -> Array:
	return [
		_componer_fm_datos(128.0, [57, 53, 60, 55], 7),   # merengue: la, fa, do, sol
		_componer_fm_datos(112.0, [55, 60, 62, 55], 11),  # bachata tranquila: sol, do, re, sol
		_componer_fm_datos(140.0, [62, 57, 59, 55], 23),  # rápida: re, la, si, sol
	]


func _componer_fm_datos(bpm := 128.0, roots: Array = [57, 53, 60, 55], semilla := 7) -> PackedByteArray:
	var beat := 60.0 / bpm
	var bars := 8
	var total := beat * 4.0 * bars
	var n := int(total * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var chords := [[0, 3, 7], [0, 4, 7], [0, 4, 7], [0, 4, 7]]
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	for bar in bars:
		var root: int = roots[bar % 4]
		var ch: Array = chords[bar % 4]
		var t0 := bar * 4.0 * beat
		for k in 8:
			var t := t0 + k * beat / 2.0
			# requinto: arpegio en corcheas, una octava arriba
			var note: int = root + 12 + ch[[0, 1, 2, 1, 0, 2, 1, 2][k]] + (12 if k == 6 else 0)
			_pluck(b, t, _hz(note), 0.32, 0.16, rng)
			# güira: raspado en cada corchea, más fuerte a contratiempo
			_noise(b, t, 0.05, 0.05 if k % 2 == 0 else 0.08, rng)
		for k in 4:
			var t := t0 + k * beat
			# bajo: tónica y quinta sincopada
			_pluck(b, t + (beat * 0.5 if k == 3 else 0.0), _hz(root - 12 + (7 if k == 2 else 0)), 0.6, 0.32, rng)
			# bongó: dos golpes por pulso
			_drum(b, t + beat * 0.5, 320.0 if k % 2 == 0 else 260.0, 0.18)
			if k == 3:
				_drum(b, t + beat * 0.75, 380.0, 0.12)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clamp(b[i] * 0.8, -1.0, 1.0) * 32000.0))
	return data


func _hz(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


## Cuerda punteada (Karplus-Strong sencillo).
func _pluck(b: PackedFloat32Array, t: float, f: float, len: float, vol: float, rng: RandomNumberGenerator) -> void:
	var start := int(t * RATE)
	var period := int(RATE / f)
	if period < 2:
		return
	var ring := PackedFloat32Array()
	ring.resize(period)
	for i in period:
		ring[i] = rng.randf_range(-1, 1)
	var count := int(len * RATE)
	for i in count:
		var idx := start + i
		if idx >= b.size():
			break
		var j := i % period
		var nxt := (j + 1) % period
		var v := (ring[j] + ring[nxt]) * 0.497
		ring[j] = v
		b[idx] += v * vol * (1.0 - float(i) / count)


func _noise(b: PackedFloat32Array, t: float, len: float, vol: float, rng: RandomNumberGenerator) -> void:
	var start := int(t * RATE)
	var prev := 0.0
	for i in int(len * RATE):
		var idx := start + i
		if idx >= b.size():
			break
		var x := rng.randf_range(-1, 1)
		var hp := x - prev
		prev = x
		b[idx] += hp * vol * exp(-float(i) / RATE * 60.0)


func _drum(b: PackedFloat32Array, t: float, f: float, vol: float) -> void:
	var start := int(t * RATE)
	for i in int(0.15 * RATE):
		var idx := start + i
		if idx >= b.size():
			break
		var u := float(i) / RATE
		b[idx] += sin(TAU * f * u * (1.0 - u * 1.5)) * exp(-u * 28.0) * vol
