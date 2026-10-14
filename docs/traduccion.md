# Traducción al inglés

Colmadón sale en español y en inglés. Este documento recoge cómo está montada la
traducción, el glosario, el estilo y **la lista exacta de sitios del código que
faltan por envolver en `tr()`**. La lista está tomada de `master` en el commit
`65fb76d`. Si los scripts cambian antes de aplicarla, busca cada línea por su
texto y no por su número.

## Estado (2026-10-04): aplicado

- Revisión Codex (2026-10-05): 14 claves añadidas y 6 `tr()` nuevos; ayudas de renuncio/chivo, chat rápido, manotazo, cadenas, selector de música y mostrador. Importación, prueba de traducción (491 claves), lógica (300 partidas) y comprobación directa de las 14 claves nuevas aprobadas. Las tres filas antiguas mal delimitadas quedan intactas; se añadieron sus claves completas correctamente entrecomilladas. Regenerar los `.translation` con `--import` al integrar (no se modifican en esta tarea).
- Todos los `tr()` de la lista de abajo están puestos (36 sitios y `_tr_bonus`),
  más 5 sitios que llegaron después con el cliente online: los avisos «¡%s se
  sentó!», «%s se fue · juega un bot», «%s volvió», el «Tú» de esos avisos y el
  sufijo «%s (ausente)». Sus 4 claves nuevas están en el CSV.
- `_float` traduce el texto al guardarlo, así que `_draw` ya pinta el aviso en el
  idioma elegido. `red.gd::_corto` también traduce los errores del servidor.
- Los nombres de jugador no se traducen: placas de `main.gd`, «Juegas como:» y
  pestañas del espejo en `menus.gd` (`AUTO_TRANSLATE_MODE_DISABLED`).
- Selector en la radio de ajustes: Automático / Español / English, guardado como
  `idioma` en `ajustes.cfg` ("" = el del sistema) y aplicado en
  `main.gd::apply_settings()` al arrancar y al cambiarlo.
- Prueba: `godot --headless --path . res://tests/prueba_traduccion.tscn` (claves
  en inglés, bonus con número, idioma de respaldo y los mismos `%s`/`%d` en las
  tres columnas).
- Capturas en inglés (1280×720, xvfb): `capturas/ingles/` (pizarra, ajustes,
  armario, cartas, mesa, tienda y libreta).
- «Ver mesa» (mesa desde arriba, en juego) y «Ver la mesa» (cómo quedó, en la
  tienda y la libreta) salen los dos como «View table»; el primero se esconde
  mientras la tienda o la libreta están abiertas, así nunca hay dos iguales.
- «(+1 ficha)» / «(+1 tile)» llevan un espacio duro (U+00A0) en las columnas `es` y
  `en` para que no se partan; la clave sigue siendo el texto de `game.gd`.


- **Archivo:** `translations/textos.csv` con las columnas `keys,es,en`. La clave es
  el **texto español exacto** del código, con sus `…`, `·`, `−`, `¡` y saltos de
  línea. Por eso la columna `es` repite la clave.
- **Registro:** `project.godot` → `[internationalization] locale/translations`
  apunta a `textos.en.translation` y `textos.es.translation`. Godot los genera al
  importar el CSV. Se suben a git: el importador da siempre el mismo resultado, y
  sin ellos un clon nuevo muestra errores de «Cannot open file» en la primera
  importación. Si editas el CSV, el editor los regenera solo; sin editor, usa
  `godot --headless --path . --import`.
- **Idioma:** Godot elige el del sistema. Un sistema en español (`es_DO`, `es_ES`…)
  usa `es`; uno en inglés usa `en`; cualquier otro idioma usa el de respaldo, que
  por defecto es `en`.
- **Lo que ya se traduce solo** (no hay que tocarlo): todo `Label`, `Button`,
  `CheckButton`, `Label3D`, `placeholder_text` y `tooltip_text` cuyo texto sea
  **igual** a una clave, aunque el texto se asigne desde código. Por ejemplo
  `pb.text = "Pasar"` ya sale como «Pass».
- **Lo que no se traduce solo:**
  1. Los textos montados con `%` o con `+`. El resultado ya no coincide con
     ninguna clave.
  2. Los **avisos flotantes** (`_float`). Se pintan con `draw_string` en
     `main.gd::_draw()`, y eso no pasa por la traducción.
  3. `.to_upper()` sobre un texto. «DOBLE FUERTE» no es una clave.
  4. Los textos que llegan del servidor con números pegados («Mano ligera −3»).

### Añadir un texto nuevo

1. Escribe el texto en español en el código, como siempre.
2. Si se forma con `%`, usa `tr("formato %d") % valor`. Nunca uses `tr(texto_ya_formateado)`.
3. Añade una fila al CSV: `clave,clave,english`. Con comas, comillas o saltos
   de línea, va entre comillas dobles. Los `%s` y `%d` tienen que estar en el
   mismo orden en las tres columnas.

## Glosario

| Español | Inglés en el juego | Cómo se presenta |
|---|---|---|
| colmado | **colmado** | Se queda en español: es el escenario y el sabor del juego. La primera vez que el jugador lo ve en la página de la tienda, se explica como «colmado (Dominican corner store)». En el juego basta el contexto («Opening the colmado…», «Back to the colmado»). |
| colmadero | shopkeeper | «The shopkeeper's tally» (la libreta). |
| chivo | **chivo** | Término propio de la trampa. Se presenta como «Chivo (cheat tile)» la primera vez, en la ficha de tienda y en el futuro tutorial o ayuda. En el juego: «CHIVO!», «slip in a chivo», «call a chivo», «CHIVO CALLED!». Verbos: *meter chivo* → *slip in a chivo*; *cantar chivo* → *call a chivo*. |
| capicúa | **capicúa** | Se presenta como «Capicúa (go out on a tile that fits both ends)» la primera vez, igual que el chivo. En el juego: «CAPICÚA!», la carta «Capicúa». |
| tranque | **tranque** | Se presenta como «Tranque (blocked game)» la primera vez. En el juego: «TRANQUE!», «by tranque», «Tranques» en la libreta. El verbo *trancar* se traduce por *block / lock up* («Who blocks the game, takes the pot»). |
| dominó (ganar la mano) | domino | «DOMINO!», «by domino». El verbo *dominar* se traduce por *go out* («Go out on a double: +30 points»). |
| ficha | tile | Nunca *piece* ni *domino* para una ficha suelta. |
| doble | double | «double six», «Heavy Double». |
| punta | end | «Tap the end where it goes». |
| pasar | pass | «Pass!», «Passed with a playable tile». |
| mano (ronda) | hand | «HAND %d», «Hands won». |
| pareja / compañero | team / partner | *Tu pareja* → *your team*; *tu compañero* → *your partner*. |
| rivales | rivals | «The rivals win». |
| aumento (carta) | boost | «PICK A BOOST», «Boosts stack…». |
| monedas | coins | Moneda de la partida. |
| pesos | **pesos** | Moneda del armario. Se queda: es dominicana y se entiende. |
| armario | wardrobe | |
| pizarra | chalkboard | |
| sala con amigos | Friends' table | En el colmado no hay «salas»: hay mesas. «Room» sonaba a menú de juego online. |
| compai | **compai** | Se queda (chat rápido, rama del servidor). Equivale a *buddy*. |
| Morir soñando | **Morir Soñando** | Bebida dominicana real (jugo de naranja con leche). Se queda con su nombre; si hace falta, en la ficha de tienda: «Morir Soñando (orange cream drink)». |
| Fiado / fiao | On the Tab / Tabs | «Fiar» es vender a crédito. La carta se llama «On the Tab» y el letrero de la calle dice «Drinks · Dominoes · Tabs». |
| Don Fello, Yeya, Chichí, Tato, Nena, Tito, Rafa | sin cambios | Nombres propios: no se traducen. |
| Colmadón | Colmadón | Marca: no se traduce y no está en el CSV. |

## Decisiones de estilo

- **Tono:** inglés natural y cercano, con sabor caribeño en los nombres propios y en
  los cuatro términos del dominó dominicano (chivo, capicúa, tranque, colmado). No
  es una traducción literal: por ejemplo, «Hoy se juega» es «Tonight we play» y
  «Cierre ruidoso» es «Table Slam».
- **Dichos de la pantalla de carga:** escritos como refranes, cortos y con ritmo,
  por ejemplo «Who blocks the game, takes the pot.» o «Rum warms the heart… and
  fogs the head.».
- **Mayúsculas:** se respetan las del original (letreros y botones grandes en
  mayúsculas). Los nombres de cartas y bebidas van en *Title Case* («Heavy
  Double», «Cold Water»).
- **Exclamaciones:** el inglés no lleva `¡`. Por eso existe la clave `¡%s!` →
  `%s!` para el aviso de beber.
- **Porcentajes:** el inglés va sin espacio: «+50%».
- **Longitud:** se buscó que el inglés no fuera más largo que el español en los
  botones y las cartas de tamaño fijo (cartas de 138 px, columna de la libreta de
  130 px). Hay que revisarlo a ojo cuando esté el `tr()`.
- **Nombres de jugadores:** nunca se traducen (ver «Etiquetas con nombres» más abajo).

## Lista exacta de sitios que necesitan `tr()`

Son 36 líneas en 3 archivos (25 en `main.gd`, 6 en `menus.gd` y 5 en `red.gd`)
más una función nueva en `main.gd`. Además hay 3 etiquetas de nombres que
desactivar y 2 cambios opcionales. `game.gd`, `view3d.gd` y el servidor **no
necesitan cambios**. La columna «Línea actual» es la línea tal cual, sin la
sangría.

### scripts/main.gd

| Sitio | Línea actual | Cambio |
|---|---|---|
| `main.gd:1123` | `floats.append({"text": text, "pos": pos + Vector2(0, -12), "t": 0.0, "col": col})` | `"text": tr(text)`. **Este cambio basta para todos los avisos literales**: main.gd:958, 961, 967, 971, 973, 977, 1007, 1009, 1012, 1014, 1181, 1183, 1185, 1246, 1349 y 2105; menus.gd:1089; y los avisos del servidor que llegan por main.gd:145 (`red.aviso`). |
| `main.gd:969` | `_float("Falsa alarma · -%d monedas" % ColmadoGame.CHIVO_FALSE_FINE, p, C_CREAM)` | `_float(tr("Falsa alarma · -%d monedas") % ColmadoGame.CHIVO_FALSE_FINE, p, C_CREAM)` |
| `main.gd:975` | `_float("¡" + ColmadoGame.DRINKS[e.id].name + "!", p, DRINK_COLOR[e.id].lightened(0.3))` | `_float(tr("¡%s!") % tr(ColmadoGame.DRINKS[e.id].name), p, DRINK_COLOR[e.id].lightened(0.3))` |
| `main.gd:933` | `txt += " · %d bebida%s" % [g.drinks[s].size(), "s" if g.drinks[s].size() > 1 else ""]` | `txt += " · " + (tr("%d bebida") if g.drinks[s].size() == 1 else tr("%d bebidas")) % g.drinks[s].size()` (el CSV no admite plurales: son dos claves). |
| `main.gd:1276` | `meta_lbl.text = "META %d · MANO %d" % [ColmadoGame.TARGET, g.hand_no]` | `tr("META %d · MANO %d") % [...]` |
| `main.gd:1283` | `chip.tooltip_text = "%s: %s" % [ColmadoGame.CARDS[id].name, ColmadoGame.CARDS[id].desc]` | `"%s: %s" % [tr(ColmadoGame.CARDS[id].name), tr(ColmadoGame.CARDS[id].desc)]` |
| `main.gd:1291` | `turn_lbl.text = "Elige tus fichas · %d/7" % my_picks.size()` | `tr("Elige tus fichas · %d/7") % my_picks.size()` |
| `main.gd:1298` | `var txt := "TU TURNO" if mine else "Juega %s…" % seat_names[g.turn]` | `var txt: String = tr("TU TURNO") if mine else tr("Juega %s…") % seat_names[g.turn]` |
| `main.gd:1300` | `txt = "TU TURNO · sale el doble seis"` | `txt = tr("TU TURNO · sale el doble seis")`. Los literales de esta línea y de las dos siguientes se traducirían solos en la etiqueta, pero `_turn_base` (L1306) se reutiliza formateado en L2042. |
| `main.gd:1302` | `txt = "Toca la punta donde la pones"` | `txt = tr("Toca la punta donde la pones")` |
| `main.gd:1304` | `txt = "No llevas · pasas solo (o mete un chivo…)"` | `txt = tr("No llevas · pasas solo (o mete un chivo…)")` |
| `main.gd:1328` | `cb.tooltip_text = "Canta si el jugador anterior\nmetió una ficha que no casa\no pasó teniendo ficha.\nSi fallas, pagas %d monedas." % ColmadoGame.CHIVO_FALSE_FINE` | `tr("Canta si el jugador anterior\nmetió una ficha que no casa\no pasó teniendo ficha.\nSi fallas, pagas %d monedas.") % ColmadoGame.CHIVO_FALSE_FINE` |
| `main.gd:1445` | `_sign("MANO %d · ELIGE UN AUMENTO" % g.hand_no)` | `_sign(tr("MANO %d · ELIGE UN AUMENTO") % g.hand_no)` |
| `main.gd:1515` | `var dicho := _lbl("«%s»" % DICHOS.pick_random(), 12, C_CREAM)` | `_lbl(tr("«%s»") % tr(DICHOS.pick_random()), 12, C_CREAM)` |
| `main.gd:1612` | `var pe := _lbl("+%d pesos para el armario  (tienes %d)" % [earned, int(menus.profile.pesos)], 11, Color(0.6, 0.4, 0.05))` | `tr("+%d pesos para el armario  (tienes %d)") % [...]` |
| `main.gd:1771` | `var l := _lbl("Así quedó la mesa · %s por %s" % [who, how], 11)` | `_lbl(tr("Así quedó la mesa · %s por %s") % [tr(who), tr(how)], 11)` (`who` y `how` son literales de L1769–1770 que ya son claves). |
| `main.gd:1901` | `var name_l := _lbl(c.name.to_upper(), 11, C_INK)` | `_lbl(tr(c.name).to_upper(), 11, C_INK)` |
| `main.gd:1923` | `var lines: Array = ["%s la mano por %s · +%d pts" % [who, r.reason, r.pts]]` | `[tr("%s la mano por %s · +%d pts") % [tr(who), tr(r.reason), r.pts]]` (`r.reason` es `dominó`/`tranque`/`chivo`, también en local y online). |
| `main.gd:1925` | `lines.append(" · ".join(r.bonus))` | `lines.append(" · ".join(r.bonus.map(_tr_bonus)))`, con la función nueva de abajo. |
| `main.gd:1926` | `var others: Array = g.bot_purchases.map(func(bp): return "%s compró %s" % [seat_names[bp[0]], ColmadoGame.DRINKS[bp[1]].name])` | `... return tr("%s compró %s") % [seat_names[bp[0]], tr(ColmadoGame.DRINKS[bp[1]].name)])` |
| `main.gd:1941` | `wallet.add_child(_lbl("%d  (+%d)   ·   Bebidas %d/%d" % [g.coins[0], gain, g.drinks[0].size(), ColmadoGame.MAX_DRINKS], 12, C_GOLD))` | `tr("%d  (+%d)   ·   Bebidas %d/%d") % [...]` |
| `main.gd:1974` | `var n := _lbl(d.name.to_upper(), 10, C_INK)` | `_lbl(tr(d.name).to_upper(), 10, C_INK)` |
| `main.gd:2042` | `turn_lbl.text = "%s · %d s" % [_turn_base, left]` | `"%s · %d s" % [tr(_turn_base), left]` (por si `_turn_base` aún está en español; no hace daño si ya está traducido). |
| `main.gd:2133` | `nombre += " (bot)"` | `nombre = tr("%s (bot)") % nombre` |
| `main.gd:2234` | `var info := _lbl("Esperando jugadores · %d de 4 · si faltan, los bots juegan las sillas libres" % humanos, 9, C_INK)` | `_lbl(tr("Esperando jugadores · %d de 4 · si faltan, los bots juegan las sillas libres") % humanos, 9, C_INK)` |
| *(nueva)* | — | Función para los bonus, que el servidor manda ya montados («Mano ligera −3»). Los literales («Cierre ruidoso +6») son claves; los que llevan número se traducen por su formato («Mano ligera −%d»): |

```gdscript
## Bonus de fin de mano. "Cierre ruidoso +6" es clave tal cual; "Mano ligera −3"
## (local o del servidor) se traduce por su formato "Mano ligera −%d".
func _tr_bonus(b: String) -> String:
	var t := tr(b)
	if t != b:
		return t
	var m := RegEx.create_from_string("^(.*[+−])(\\d+)$").search(b)
	return tr(m.get_string(1) + "%d") % int(m.get_string(2)) if m else b
```

`main.gd:1106` (la etiqueta `FOTO …` del modo `--demo`) y los `print()` de las
pruebas no se traducen: no los ve el jugador.

### scripts/menus.gd

| Sitio | Línea actual | Cambio |
|---|---|---|
| `menus.gd:610` | `var wins := _chalk_label("Ganadas  %s     Meta 100" % _tally(int(profile.get("ganadas", 0))), 11, Color(C_CHALK, 0.8))` | `tr("Ganadas  %s     Meta 100") % _tally(...)` |
| `menus.gd:873` | `_row(v, "Piel", func(): return "Tono %d" % (_idx(SKINS, profile.skin) + 1), func(d): _cycle("skin", SKINS, d))` | `func(): return tr("Tono %d") % (_idx(SKINS, profile.skin) + 1)` |
| `menus.gd:1019` | `var pesos_l := _label("%d pesos" % int(profile.pesos), 12, C_GOLD)` | `_label(tr("%d pesos") % int(profile.pesos), 12, C_GOLD)` |
| `menus.gd:1043` | `var state := "✓ Puesto" if equipped else ("Tuyo" if owned else "%d pesos" % price)` | `var state: String = tr("✓ Puesto") if equipped else (tr("Tuyo") if owned else tr("%d pesos") % price)` |
| `menus.gd:1044` | `b.text = "%s   ·   %s" % [item[1], state]` | `"%s   ·   %s" % [tr(item[1]), state]` |
| `menus.gd:1084` | `m._float("Te faltan %d pesos" % (price - int(profile.pesos)), Vector2(200, 160), C_RED.lightened(0.3))` | `m._float(tr("Te faltan %d pesos") % (price - int(profile.pesos)), ...)` |
| `menus.gd:1119` | `var lang := _label("Idioma: Español · English pronto", 10, Color(C_CREAM, 0.7))` | Cambiarla por un selector (ver «Selector de idioma»). Mientras tanto se traduce sola («Language: English · Español»). |
| `menus.gd:269` | `b.text = text + ("   · " + note if note != "" else "")` | Hoy nadie pasa `note`, así que el texto queda igual a la clave y se traduce solo. Si alguien la usa: `tr(text) + ("   · " + tr(note) if note != "" else "")`. |

### scripts/red.gd

`red.gd` es un `Node`, así que `tr()` funciona directamente. Los errores llegan a
la pizarra por `menus.gd:665` (`estado.text = err`).

| Sitio | Línea actual | Cambio |
|---|---|---|
| `red.gd:73` | `return "No se pudo conectar con el colmado (%s)" % _corto(session.get_exception())` | `return tr("No se pudo conectar con el colmado (%s)") % _corto(...)` |
| `red.gd:77` | `return "No se pudo abrir la conexión (%s)" % _corto(r.get_exception())` | `tr("No se pudo abrir la conexión (%s)") % ...` |
| `red.gd:89` | `return "No se pudo crear la sala (%s)" % _corto(r.get_exception())` | `tr("No se pudo crear la sala (%s)") % ...` |
| `red.gd:100` | `return "No se pudo buscar la sala (%s)" % _corto(r.get_exception())` | `tr("No se pudo buscar la sala (%s)") % ...` |
| `red.gd:111` | `return "La sala está llena" if txt.contains("llena") or txt.contains("full") else "No se pudo entrar en la sala (%s)" % txt` | `... else tr("No se pudo entrar en la sala (%s)") % txt` (el literal de la izquierda se traduce solo en la etiqueta). |
| `red.gd:165` | `return t.substr(0, 60)` | Opcional: `return tr(t.substr(0, 60))`, para que los errores del servidor que van entre paréntesis («código no válido», «el código tiene 6 letras», que ya están en el CSV) también salgan en inglés. |

### Textos del servidor (servidor/modulo/src) — sin cambios en el servidor

El servidor manda los textos en español y el cliente los traduce al mostrarlos:

- `sala.ts:99` «No hay ninguna sala con ese código» → llega como `d.error` (red.gd:103) a una etiqueta: se traduce sola.
- `sala.ts:126` «La sala está llena» → el cliente la convierte en su propio literal (red.gd:111).
- `sala.ts:257` «No se puede hacer eso ahora» → `OP_AVISO` → `_float` (se traduce con el cambio de main.gd:1123).
- `sala.ts:95` y `sala.ts:97` (errores del RPC) → llegan dentro de `(%s)`; ver red.gd:165.
- `reglas.ts:447`, `451` y `455` (bonus literales) → claves tal cual.
- `reglas.ts:463` `bonus.push("Mano ligera −" + off);` y `reglas.ts:469` `bonus.push("Mano caliente +" + extra);` → los resuelve `_tr_bonus` en el cliente. Usan el mismo signo `−` (U+2212) que `game.gd:349`.
- Rama `servidor-avisos-reloj-chat` (sin fusionar): las frases del chat rápido, «Jugador» y «Esa frase no existe» ya están en el CSV. Cuando el cliente pinte las frases con `_float` o con etiquetas, se traducirán solas.

A largo plazo, conviene que el servidor mande identificadores y números
(`{"id": "ligera", "n": 3}`) en vez de frases. Así el cliente no depende de que
el texto coincida letra por letra.

### Etiquetas con nombres de jugador

Un nombre que coincida con una clave se traduciría: un jugador llamado «Ron»
saldría como «Rum». Para evitarlo, en las etiquetas que muestran nombres hay que
poner `auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED`:

- `main.gd:805` `var l := _lbl(seat_names[s], 9)` (placas con nombre sobre cada silla).
- `menus.gd:644` `nrow.add_child(_chalk_label(nombre_personaje() if not sin_nombre else "(sin nombre)", 15, C_PINK if sin_nombre else C_GOLD))`. Solo cuando `not sin_nombre`, porque «(sin nombre)» sí se traduce.
- `menus.gd:840` `tb.text = n if n != "" else "Sin nombre"`. Solo cuando `n != ""`.

En `main.gd:1298` («Juega %s…») el nombre entra por `%s` después de `tr()`, así
que no hay problema.

### Selector de idioma (menus.gd, radio de ajustes)

Propuesta para sustituir `menus.gd:1119`. Las claves «Idioma» y «Automático» ya
están en el CSV; «Español» y «English» se quedan sin traducir, porque cada idioma
se muestra con su propio nombre:

```gdscript
_choice(v, "Idioma", "idioma", ["", "es", "en"], ["Automático", "Español", "English"])
```

Añade `"idioma": ""` a `settings` y, en `main.gd::apply_settings()`:

```gdscript
var loc: String = str(st.get("idioma", ""))
TranslationServer.set_locale(loc if loc != "" else OS.get_locale())
```

Al cambiar de idioma, las etiquetas con texto literal se actualizan solas. Las
que se montaron con `tr() % …` (cartel de turno, tienda, libreta) se rehacen en
el siguiente `_refresh()` o al reabrir la pantalla.

## Comprobaciones hechas

- Godot 4.7.2 estable (Windows, consola) con `--headless --path . --import`, con
  la carpeta `.godot` borrada antes: **0 errores y 0 avisos**. El importador
  genera `textos.en.translation` y `textos.es.translation`, siempre idénticos.
- Script de prueba en modo headless:
  - Se cargan los idiomas `en` y `es`.
  - Las claves con salto de línea, `…`, `−`, `·`, `«»`, `%s` y `%d` devuelven el
    inglés esperado, y `tr("Juega %s…") % "Yeya"` da «Yeya is playing…».
  - Con `es_DO` sale el español.
  - Con `fr` sale el inglés de respaldo.
  - Un `Label` con texto «Pasar» se traduce solo a «Pass».
- Cada clave del CSV aparece **literal** en `scripts/*.gd` o en
  `servidor/modulo/src/*.ts`. Las excepciones son 6 claves nuevas que existen
  para el `tr()` pendiente (`%d bebida`, `%d bebidas`, `¡%s!`, `%s (bot)`,
  `Idioma`, `Automático`) y las 9 de la rama del chat.
- Al revés, se revisó cada literal del código que no está en el CSV. Solo quedan
  textos de depuración, nombres propios, nombres de nodos o de fuentes, y
  separadores sin palabras.
- **No verificado:** cómo se ve en pantalla en inglés (longitud en botones y
  cartas). Muchos textos dependen del `tr()` pendiente, así que conviene revisarlo
  con capturas cuando esté aplicado.
