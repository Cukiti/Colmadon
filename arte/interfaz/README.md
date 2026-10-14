# Iconos editables de interfaz

`moneda.aseprite`: 16×16, un frame, capas de relieve y sello C. Se usa en marcador, tienda y aumentos que representan monedas. No lleva animación ni destellos.

Después de editar, reexportar con Aseprite en modo batch y `tools/crear_moneda_aseprite.lua`, pasando `--script-param root=<ruta del proyecto>`. El script conserva el editable existente y exporta `moneda.png`; solo crea el dibujo inicial cuando no existe el archivo.

Comparación reproducible: Godot `--headless --path . --script res://tests/comparar_moneda_aseprite.gd`. Anterior a la izquierda, actual a la derecha; ampliación nearest y tamaño nativo debajo.

## Bebidas

`cafe`, `ron`, `morir` y `agua`: editables .aseprite de 16×16 con capas Recipiente, Bebida y Detalles y reflejos. Los PNG se usan en tienda, mostrador, inventario de bebidas e ir al mostrador. Las bebidas 3D permanecen como estaban.

Reexportar mediante `tools/crear_bebidas_aseprite.lua` en Aseprite batch con `--script-param root=<ruta del proyecto>`; conserva los editables existentes. Comparativa real de tienda: Godot `--path . --script res://tests/comparar_bebidas_aseprite.gd -- --prueba-arte`, usando perfiles de prueba. Guarda `capturas/tienda_bebidas_aseprite.png` y comparativa anterior arriba / actual abajo.
## Aumentos

`aumento_puntos.aseprite` y `aumento_info.aseprite`: iconos de categoría 16×16, dos capas. La ficha representa puntos y el ojo información; monedas conserva moneda.aseprite. Se usan en las cartas de selección y las insignias pequeñas del marcador. No cambian los iconos de los botones generales de mirar la mesa ni las fichas HD.

Reexportar con `tools/crear_aumentos_aseprite.lua` en Aseprite batch y `--script-param root=<ruta del proyecto>`; conserva fuentes existentes. Captura reproducible: Godot `--path . --script res://tests/comparar_aumentos_aseprite.gd -- --prueba-arte`. Usa perfiles de prueba y guarda `capturas/aumentos_aseprite.png`.
## Catálogo y controles

Ver `CATALOGO.md` para el inventario completo por familias, usos y pendientes. Pausa de partida, engranaje de inicio/pausa/Ajustes y controles anterior/pausa-seguir/siguiente de radio usan editables de 16×16. Reexportar con tools/crear_controles_aseprite.lua; conserva editables. Catálogo visual: tests/catalogo_iconos.gd (perfiles de prueba --prueba-arte); también captura inicio y pausa y comprueba que el botón abre/cierra el panel.
## Acciones y navegación principal

`music`, `arrow_left`, `arrow_right`, `arrow_up`, `arrow_down` y `home`: editables 16×16, exportados por tools/crear_navegacion_aseprite.lua. Ver mesa/recoger fichas reutilizan aumento_info/aumento_puntos mediante alias de carga; editar una fuente actualiza ambos usos. Flechas de recorrido y opciones de personaje son imágenes; los símbolos insertados en textos de otros botones quedan pendientes. La prueba de recorrido reconoce la flecha del editor por metadata option_next.
## Gestos y posturas

Nueve editables 16×16: dance, clap, point, wave, stretch, choca, brindis, sit y shove. Dos capas (contorno y pose/colores). Usados por botones de gestos sentado/de pie, sentarse y empujar. Las animaciones del personaje no cambian. Reexportar con tools/crear_gestos_aseprite.lua en Aseprite batch y --script-param root=<ruta>; conserva editables. tests/catalogo_iconos.gd captura también el panel real y ejecuta Saludar, comprobando cierre.
## Pizarra

Cuatro editables 32×32: tiza_domino, tiza_clasico, tiza_amigos y tiza_reto. Capas Trazo de tiza y Polvo y desgaste. PNG con transparencia y filtro nearest; dibujo fijo y cacheado, ya no generado al azar al abrir. Conserva revelado del menú, atenuación de modo deshabilitado, textos y callbacks. Reexportar con tools/crear_tiza_aseprite.lua en Aseprite batch y --script-param root=<ruta>; preserva fuentes existentes. tests/catalogo_iconos.gd también renderiza la pizarra completa en capturas/pizarra_aseprite.png.
## Símbolos finales de botones

chat, pass_hand, stand y add: cuatro editables 16×16 de dos capas, exportados por tools/crear_simbolos_aseprite.lua. Flechas de siguiente mano, volver, crear/entrar/cambiar y selector de meta reutilizan navegación. `_symbol_button` traduce la clave original y separa la imagen; conserva traducciones existentes y evita traducir nuevamente el texto ya procesado. La flecha JUGAR de pizarra es una textura en el contenedor Action; mantiene la animación de aparición. El botón de ir al mostrador conserva su icono de bebida y elimina la flecha de fuente redundante.## Pantalla de inicio (O03)

`inicio_jugar` (ficha), `inicio_sala` (puerta con flecha hacia dentro), `inicio_personaje` (busto), `inicio_armario` (percha con camisa) e `inicio_salir` (puerta con flecha hacia fuera): editables 16×16 de dos capas (Contorno y Color), con el estilo del engranaje de Ajustes. Colores elegidos para destacar sobre el botón de cada uno. Reexportar con `tools/crear_inicio_aseprite.lua` en Aseprite batch y `--script-param root=<ruta>`; conserva los editables existentes (borra el .aseprite para volver a dibujarlo desde el script).
