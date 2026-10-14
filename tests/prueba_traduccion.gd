extends Node
## Prueba de la traducción sin gráficos: claves sueltas en inglés, bonus del
## servidor con número (_tr_bonus de main.gd) y que los %s / %d del CSV
## coincidan en las tres columnas. Uso:
## godot --headless --path . res://tests/prueba_traduccion.tscn
## (escena y no --script: main.gd necesita el autoload de Nakama)

var fallos := 0


func check(got: String, want: String) -> void:
	if got != want:
		fallos += 1
		print("FALLO «%s» en vez de «%s»" % [got, want])


func _ready() -> void:
	var main = load("res://scripts/main.gd").new()
	var stand := Button.new()
	var meta := Button.new()
	main.add_child(stand)
	main.add_child(meta)
	TranslationServer.set_locale("es")
	main._symbol_button(stand, "PARARSE  ⇧")
	main._symbol_button(meta, "Meta %d ▾", [200])
	check(stand.text, "PARARSE")
	TranslationServer.set_locale("en")
	main._translate_symbol_buttons(main)
	check(stand.text, "STAND UP")
	check(meta.text, "Goal 200")
	assert(stand.icon != null)
	check(tr("Pasar"), "Pass")
	check(tr("Juega %s…") % "Yeya", "Yeya is playing…")
	check(tr("%s (bot)") % "Ron", "Ron (bot)")
	check(main._tr_bonus("Cierre ruidoso +6"), "Table Slam +6")
	check(main._tr_bonus("Mano ligera −3"), "Light Hand −3")
	check(main._tr_bonus("Ficha marcada +9"), "Marked Tile +9")
	check(main._tr_bonus("Tranque seguro"), "Safe Block")
	check(main._tr_bonus("algo raro"), "algo raro")
	check(tr("Morir soñando").to_upper(), "MORIR SOÑANDO")
	TranslationServer.set_locale("es_DO")
	main._translate_symbol_buttons(main)
	check(stand.text, "PARARSE")
	check(meta.text, "Meta 200")
	check(tr("Pasar"), "Pasar")
	check(main._tr_bonus("Mano ligera −3"), "Mano ligera −3")
	TranslationServer.set_locale("fr")
	check(tr("Pasar"), "Pass")
	# Plurales de importación sin abrir el selector ni copiar música real.
	var menus = load("res://scripts/menus.gd").new(main)
	for locale in ["es", "en"]:
		TranslationServer.set_locale(locale)
		var expected := ["0 canciones añadidas", "1 canción añadida", "2 canciones añadidas"] if locale == "es" else ["0 songs added", "1 song added", "2 songs added"]
		for n in 3:
			check(menus._import_notice(n), expected[n])
	menus.free()
	# El mismo control y sus cifras sobreviven al cambio; no se reconstruye
	# la pantalla ni se repiten los efectos de la libreta.
	TranslationServer.set_locale("es")
	var wallet: Label = main._lbl(func(): return tr("%d  (+%d)   ·   Bebidas %d/%d") % [50, 12, 1, 3])
	add_child(wallet)
	check(wallet.text, "50  (+12)   ·   Bebidas 1/3")
	TranslationServer.set_locale("en")
	await get_tree().process_frame
	check(wallet.text, "50  (+12)   ·   Drinks 1/3")
	TranslationServer.set_locale("es")
	await get_tree().process_frame
	check(wallet.text, "50  (+12)   ·   Bebidas 1/3")
	wallet.free()
	main.free()
	# mismos marcadores de formato en las tres columnas
	var f := FileAccess.open("res://translations/textos.csv", FileAccess.READ)
	f.get_csv_line()
	var re := RegEx.create_from_string("%[sd]")
	var filas := 0
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 3:
			continue
		filas += 1
		var marcas: Array = Array(row).map(func(x): return re.search_all(x).map(func(m): return m.get_string()))
		if marcas[0] != marcas[1] or marcas[0] != marcas[2]:
			fallos += 1
			print("FALLO marcadores distintos en «%s»" % row[0])
	print("TRADUCCIÓN %d claves · %s" % [filas, "SIN FALLOS" if fallos == 0 else "%d FALLOS" % fallos])
	get_tree().quit(1 if fallos > 0 else 0)
