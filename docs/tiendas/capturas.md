# Colmadón — capturas, tráiler, cápsulas y prompts de concepto

Plan de imágenes y vídeo para Steam y Google Play. Revisado: 2026-10-03.

## Fuentes oficiales consultadas

- Steam, recursos gráficos de la tienda (cápsulas y capturas):
  https://partner.steamgames.com/doc/store/assets/standard
- Steam, recursos de la biblioteca:
  https://partner.steamgames.com/doc/store/assets/libraryassets
- Steam, tráiler: https://partner.steamgames.com/doc/store/trailer
- Steam, descripción (límite de imágenes y GIF dentro de la descripción):
  https://partner.steamgames.com/doc/store/page/description
- Google Play, recursos de la ficha (icono, gráfico de funciones, capturas, vídeo):
  https://support.google.com/googleplay/android-developer/answer/9866151

---

## 1. Cómo sacar las capturas

- El juego dibuja la mesa a 640×360. Capturar a **1920×1080** (escala entera ×3): cumple
  el mínimo de Steam (1920×1080, 16:9) y el recomendado de Google Play para horizontal
  (16:9, mínimo 1920×1080).
- Steam pide **mínimo 5 capturas de juego real**, sin arte de concepto, sin fotogramas de
  cinemáticas, sin premios ni textos de marketing encima. Google Play pide mínimo 2 (se
  recomiendan 4 o más para optar a promoción), JPEG o PNG de 24 bits **sin transparencia**.
- Usar la interfaz real (marcador, cartas, cartel de turno). Nada de textos añadidos en
  Steam. En Google Play se toleran títulos cortos, pero mejor sin texto para reutilizar las
  mismas imágenes.
- Herramientas que ya tiene el juego: `-- --demo` (fotos automáticas de cada mano),
  `-- --prueba-beber`, `-- --prueba-revision`, `-- --prueba-menus`. Algunas capturas
  (cantar chivo, capicúa) se preparan mejor con una partida guiada; si hace falta, añadir
  un modo de captura (fuera de esta entrega).

---

## 2. Las 8 capturas, por orden

| # | Momento | Qué tiene que verse | Por qué |
|---|---|---|---|
| 1 | **¡CHIVO! cazado** (momento para clips) | Letrero grande «¡CHIVO!», la ficha que no casa marcada en rojo en la línea, el rival tapándose la cara y tu compañero celebrando; monedas volando al marcador. | Es lo que nadie más tiene: el dominó donde hacer trampa es una regla. Va primero. |
| 2 | **Capicúa y golpe final** | Tu mano estampando la última ficha que casa por los dos lados, polvo, anillo de impacto, bombilla balanceándose, letrero «¡CAPICÚA!» y los cuatro de pie. | Game feel y celebración: se entiende sin leer. |
| 3 | **Elegir aumento** | Las 3 cartas de aumento sobre la mesa con iconos, y en una esquina las cartas ya acumuladas. | Enseña la capa roguelite (la build). |
| 4 | **El mostrador del colmado** | Tienda con los 4 vasos (café, agua fría, morir soñando, ron), precios en monedas y el colmadero detrás. | Enseña las bebidas que rompen las reglas. Ver «Riesgos»: si el Ron se quita o se suaviza, que no salga en primer plano. |
| 5 | **Partida en curso desde tu silla** | Vista normal: compañero enfrente, rivales a los lados, tu bandeja con fichas, la línea en S por la mesa, la punta brillando al arrastrar una ficha. | Es lo que el jugador verá el 90 % del tiempo. |
| 6 | **Sala con amigos** | La mesa como sala de espera con el código grande de 6 letras, dos amigos sentados con sus personajes y dos sillas con bots. | Enseña el multijugador sin explicar nada. |
| 7 | **El espejo** | Editor de personaje con varias opciones visibles (pelo, gafas, cadena) y los 3 personajes guardados. | Personalización. |
| 8 | **La calle de noche** | Fachada con el neón «COLMADÓN», farola y motor. | Ambiente y marca; buena como última (Steam usa la última captura para el fondo si no se sube uno). |

Para Google Play, las 4 primeras deben ser 1, 2, 5 y 3 (las que más se ven en el móvil).

---

## 3. Tráiler de 30 s

Especificación de Steam: hasta 1920×1080, 30 o 60 fps, 16:9, H.264 + AAC, más de
5.000 kbps, .mp4/.mov/.wmv, audio a 44 o 48 kHz. Empezar con juego real y la interfaz
visible. En Google Play el vídeo es solo un enlace de YouTube.

| Segundos | Plano | Sonido |
|---|---|---|
| 0–4 | **Momento para clips:** alguien mete un chivo, el siguiente canta «¡CHIVO!», letrero, la ficha se marca en rojo, el rival se tapa la cara. | Golpe de ficha + grito «¡Chivo!» |
| 4–7 | Corte a negro con el logo «COLMADÓN» en neón que se enciende. | Zumbido del neón |
| 7–11 | Barajar: las 28 fichas giran boca abajo; tu mano roba sus 7. | Barajado |
| 11–15 | Elegir carta de aumento; se suma a las anteriores. | Cartas |
| 15–19 | Mostrador: compras un café y juegas dos fichas seguidas (o agua fría que anula una carta rival). | Monedas, vaso, trago |
| 19–23 | Sala con código: dos amigos entran, uno en PC y otro en móvil (pantalla partida o dos planos rápidos). | Ambiente de colmado |
| 23–27 | Capicúa: golpe final, polvo, bombilla, todos de pie. | Golpe fuerte + celebración |
| 27–30 | Logo, «Dominó por parejas · Con amigos o contra bots» y botón de la tienda (solo en el vídeo, no en las cápsulas). | Cierre musical |

Si el juego todavía no tiene música, usar el ambiente del colmado y los efectos; no
meter música con derechos de terceros.

---

## 4. Cápsulas y recursos de Steam

Tamaños comprobados en la documentación oficial (2026-10-03). Regla general de Valve:
en las cápsulas y cabeceras, **el logo legible y ningún texto aparte del título** (ni
citas, ni premios, ni «ya disponible»).

### Tienda (obligatorios)

| Recurso | Tamaño | Dónde sale | Contenido propuesto |
|---|---|---|---|
| Cápsula de cabecera (header) | **920×430** | Arriba de la página, recomendaciones, Big Picture | Mesa vista en diagonal con las fichas en S, cuatro manos alrededor, logo neón a la izquierda. |
| Cápsula pequeña (small) | **462×174** (Steam genera 120×45 y 184×69) | Búsquedas y listas | El logo casi llenando la cápsula; solo una ficha doble al lado. Tiene que leerse en 120×45. |
| Cápsula principal (main) | **1232×706** | Carrusel de la portada | Escena del chivo cazado desde arriba con el logo; la más vistosa. |
| Cápsula vertical | **748×896** | Rebajas de temporada | Fachada del colmado de noche con el neón, la mesa vista por la puerta. |
| Capturas | **1920×1080 mínimo, 16:9**, al menos 5 | Página | Las 8 del apartado 2. |

### Opcionales

| Recurso | Tamaño | Nota |
|---|---|---|
| Fondo de la página | **1438×810** | Si no se sube, Steam lo genera con la última captura. Propuesto: estantes del colmado desenfocados y oscuros. |

### Biblioteca (obligatorios para publicar)

| Recurso | Tamaño | Regla de Valve | Contenido propuesto |
|---|---|---|---|
| Cápsula de biblioteca | **600×900** (Steam genera 300×450) | Muy gráfica, que transmita la experiencia | Vertical: bombilla arriba, mesa abajo, logo en medio. |
| Cabecera de biblioteca | **920×430** | Centrada en la marca | Puede ser la misma que la cabecera de la tienda. |
| Héroe de biblioteca | **3840×1240** (Steam genera 1920×620); zona segura central **860×380** | Imagen rica y reconocible, **sin texto** | Panorámica del colmado: mostrador, gata, abanico, mesa en el centro. |
| Logo de biblioteca | **1280 de ancho y/o 720 de alto**, PNG con transparencia | Solo el logotipo, ninguna otra palabra | El neón «COLMADÓN». |

**Sin comprobar en esta revisión:** tamaño del icono de la comunidad y de las portadas de
eventos/anuncios (no aparecen en las páginas consultadas); mirarlos en Steamworks al
subir los recursos.

### Google Play (para la misma tanda)

| Recurso | Tamaño | Nota |
|---|---|---|
| Icono | **512×512**, PNG de 32 bits con alfa, máx. 1.024 KB | Ficha doble 6 sobre madera con un toque de neón; nada de texto. |
| Gráfico de funciones | **1024×500**, JPEG o PNG de 24 bits sin alfa | Versión apaisada de la cabecera de Steam. |
| Capturas | Lado mínimo 320 px, máximo 3.840 px; el lado largo no más del doble del corto; recomendado 1920×1080 para horizontal | Las mismas de Steam. |
| Vídeo | Enlace de YouTube | El tráiler de 30 s. |

---

## 5. Prompts de concepto (Flow, en inglés)

Para imágenes de concepto y referencia de cápsulas, **no** para subirlas como capturas
(Steam prohíbe arte de concepto en las capturas). Todos en 16:9 horizontal.

**Estilo común (añadir al final de cada prompt):**
`Low-resolution 3D scene rendered at 640x360 and upscaled with nearest-neighbour, chunky pixel art look, warm tungsten light bulb as the key light, deep blue night shadows, Caribbean corner-store palette of painted-wood yellow, turquoise and red with golden coins; the domino tiles themselves are crisp and high-definition with round pips, contrasting with the pixelated scene. Real in-game screenshot with a small HUD, not a poster, not a collage, no phone frame, 16:9.`

1. **The Chivo caught (clip moment)**
   `First-person view from a player's chair at a light wooden domino table with raised edges in a late-night Dominican corner store. The player on the right has just slid a domino that doesn't match onto the end of the line; the tile now glows red. The player on the left stands up pointing at it, a big painted-wood sign reading "¡CHIVO!" pops over the table, the cheater covers his face with both hands, and the partner across the table laughs with arms raised. Gold coins fly toward a small score board in the top corner.`

2. **Capicúa slam**
   `Over-the-shoulder view of the player's own hand slamming the last domino onto a line that snakes around the table edges in an S shape. Dust puffs and a white impact ring burst from the tile, the hanging light bulb swings, glasses on the corner coasters shake, all four characters jump up from their chairs, and a sign reads "¡CAPICÚA!". Score board top left, team coins top right.`

3. **Choosing a boost**
   `Close view of the domino table between hands: three illustrated boost cards rise from the table in front of the player, each with a pixel icon (a double domino, a coin pouch, an eye). On the side, small stacked cards show the boosts already collected this match. The partner across the table leans in to look. The store counter with jars and an old radio is blurred in the background.`

4. **The counter**
   `View of the corner-store counter between hands: a shopkeeper in an apron wipes the counter; four drinks are lined up on it — a steaming coffee cup, a sweating glass of ice water, an orange-and-milk drink, and a small glass of dark rum — each with a coin price tag. A ginger cat sleeps at the end of the counter with its tail curled, a standing fan turns, shelves of colourful bottles behind.`

5. **Friends room**
   `Top-down-ish view of the domino table used as a waiting room: a big chalk-style room code "K7M2QX" hovers over the table with a copy icon, two custom characters are seated (one with a straw hat, one with a turquoise headscarf), the two empty chairs show friendly bot characters with small robot badges, and a large "¡A JUGAR!" painted-wood button sits at the bottom.`

6. **Street at night (vertical capsule reference, crop later)**
   `Exterior of a small Caribbean corner store at night: a glowing red-and-yellow neon sign on the façade, a street lamp, a parked motorbike, the open door showing four people around a domino table under a hanging light bulb, warm light spilling onto the wet street.`

**No** pedir «al estilo de» ningún juego existente; no nombrar marcas reales de ron ni de
cerveza en los prompts.

---

## 6. Riesgos de las imágenes

1. **Alcohol en primer plano.** Ninguna cápsula debe mostrar el Ron ni botellas como
   protagonistas: las cápsulas se ven en la portada para todas las edades y en Google
   Play condicionan la clasificación percibida. El Ron solo aparece en la captura 4 junto
   a las otras tres bebidas. Si el usuario decide quitarlo (ver `google_play.md`),
   rehacer esa captura.
2. **Que no parezca un casino.** Nada de montones de monedas como premio, fichas de
   póquer, ruletas ni la palabra «win» grande. Las monedas del marcador, pequeñas.
3. **Juego real.** Las capturas tienen que salir del juego tal como está; si se
   retocan (luz, encuadre), que no enseñen cosas que el juego no hace.
4. **Inglés.** Las capturas muestran la interfaz en español; vale para las dos fichas,
   pero si se lanza en inglés, rehacerlas con la interfaz traducida.
