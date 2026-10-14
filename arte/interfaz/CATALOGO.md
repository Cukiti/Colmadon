# Catálogo de iconos de Colmadón

Fuente: llamadas a `_icon`, `_card_icon`, `_drink_icon`, `_chalk_icon` y símbolos usados en botones de `scripts/main.gd` y `scripts/menus.gd`. Se agrupan dibujos únicos; sus usos repetidos comparten el mismo editable. Los textos de botones permanecen traducibles.

| Familia | Iconos actuales | Dónde se usan | Estado |
|---|---|---|---|
| Pausa y ajustes | pause, gear | Pausa de partida; Ajustes de inicio, menú de pausa, navegación y título de Ajustes | Aseprite 16×16 |
| Reproductor | previous, play_pause, next | Anterior, pausa/seguir y siguiente en radio | Aseprite 16×16 |
| Economía | moneda | Marcador, tienda, armario, precios y aumentos de monedas | Aseprite 16×16 |
| Bebidas | cafe, ron, morir, agua | Tienda, mostrador y botones para beber | Aseprite 16×16 |
| Categorías de aumentos | aumento_puntos, aumento_info | Selección de cartas e insignias pequeñas | Aseprite 16×16 |
| Acciones generales | tile, eye, music | Recoger fichas, ver/revisar mesa y título de radio | Aseprite 16×16; tile/eye comparten fuentes con aumentos |
| Gestos | dance, clap, point, wave, stretch, choca, brindis | Menú de gestos sentado y de pie | Aseprite 16×16 |
| Postura e interacción | sit, shove | Sentarse y empujar | Aseprite 16×16 |
| Modos en pizarra | domino, clasico, amigos, reto | Partida rápida, clásico, sala con amigos y reto diario | Aseprite 32×32; trazo y desgaste de tiza en dos capas |
| Navegación horizontal | ◀, ▶, ▸, ‹ | Recorrido por el colmado, opciones del personaje, jugar/entrar/cambiar, siguiente mano y volver | Aseprite 16×16; arrow_left/arrow_right compartidos |
| Navegación vertical | ▲, ▼, ▾ | Ir a Ajustes, volver al armario y selector de meta | Aseprite 16×16; arrow_up/arrow_down compartidos |
| Casa | ⌂ | Volver a la calle | Aseprite 16×16 |
| Chat | 💬 | Frases rápidas online | Aseprite 16×16 |
| Mano | ✋ | Botón PASO | Aseprite 16×16 |
| Levantarse | ⇧ | Botón PARARSE | Aseprite 16×16 |
| Añadir | + | Añadir canciones | Aseprite 16×16; add compartido por Nuevo y Añadir canciones |

## Pausa en inicio

El inicio no tiene una partida que pausar: tiene AJUSTES (engranaje). Comparte el nuevo `gear.aseprite` con los Ajustes del menú de pausa. La radio tiene su propio botón pausa/seguir, ahora `play_pause.aseprite`. El botón de partida utiliza `pause.aseprite`.

## Familias integradas

1. Controles comunes de pausa, Ajustes y radio: integrados.
2. Acciones generales y navegación principal: integradas. Flechas antes incrustadas dentro de textos también integradas.
3. Gestos y postura: integrados a 16×16, dos capas por dibujo.
4. Modos: integrados a 32×32 con estética de tiza diferenciada de los iconos dorados.

No se consideran iconos las caras/personajes, fichas jugables HD, vasos/modelos 3D, textura de radio, partículas, puntos de dominó o textos decorativos. Esos elementos tienen procesos de arte distintos.

## Fuentes y exportación

Todos los editables de iconos se agrupan en `arte/interfaz/`. Los nuevos controles están en `pause`, `gear`, `play_pause`, `previous` y `next`, cada uno con `.aseprite` y `.png`. Reexportar mediante Aseprite batch y `tools/crear_controles_aseprite.lua` con `--script-param root=<ruta del proyecto>`; conserva los archivos editados. Nunca volver a generar un editable retocado para actualizar un PNG.

Vista agrupada de dibujos actuales: Godot `--path . --script res://tests/catalogo_iconos.gd -- --prueba-arte`; guarda `capturas/catalogo_iconos.png`. El catálogo muestra las familias integradas. Hay 35 editables: 31 de 16×16 y cuatro de tiza de 32×32; los alias tile/eye reutilizan fuentes de aumentos.

5. Símbolos de chat, Paso, levantarse, añadir y flechas junto al texto: integrados. Se traduce la clave original antes de separar el símbolo para conservar español e inglés.
