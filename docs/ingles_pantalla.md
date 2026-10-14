# Inglés en pantalla — revisión 2026-10-06

**Estado vigente al 7 de octubre de 2026:** código integrado en principal y publicado en GitHub en esta entrega autorizada. Nube y Windows publicados anteriormente; esta entrega integra herramientas del bot y documentación, sin nuevo despliegue ni exportación. APK/Para-amigos pendientes. Véanse [traspaso](TRASPASO_CLAUDE.md) y [tablero](TABLERO_COLMADON.html). Las secciones anteriores conservan resultados históricos.

**Estado vigente al 2026-10-07:** Revisión y correcciones incluidas en el EXE Windows publicado el 7. APK todavía anterior. Consulta [traspaso](TRASPASO_CLAUDE.md); el resto conserva el historial.


Tarea `docs/tareas_codex/ingles-en-pantalla.md`, realizada en la carpeta principal/master por continuidad de la instrucción del usuario. Cambios sin commit ni push. Se conserva el trabajo previo de B01/B02 y colocación. No se cambian reglas, arte, servidor, exportes ni datos reales del jugador.

## Hallazgos y arreglos

Las rutas siguientes son relativas a la raíz del proyecto. Las capturas permanecen localmente en `capturas/recorrido/`, excluida de git. No son imágenes de una exportación nueva.

| Texto / lugar | Problema | Arreglo / evidencia |
|---|---|---|
| `Street`, `Wardrobe`, `Radio off` en Ajustes | Cambiar EN → ES dejaba esos textos en inglés aunque el resto de la página cambiaba. | La navegación conserva las claves españolas; la radio recalcula su título al cambiar de idioma. La página de Ajustes vuelve a abrirse de forma diferida al pulsar el selector. Antes: [captura](../capturas/recorrido/ingles_antes/estaticas_640/idioma_caliente.png). Después, usando el botón real Español: [captura](../capturas/recorrido/ingles_final/en_640x360/idioma_caliente.png). También probado ES → EN. |
| Nombres de aumentos y bebidas en mayúsculas | `tr(nombre).to_upper()` almacenaba el resultado; la clave original se perdía para cambios posteriores. | `texto_vivo.gd` recalcula el texto del mismo control. Las descripciones vuelven a ajustar la fuente para el idioma elegido. [Aumentos cambiados en caliente](../capturas/recorrido/ingles_final/en_640x360/aumento_idioma_caliente.png), [bebidas](../capturas/recorrido/ingles_final/en_640x360/tienda_idioma_caliente.png). |
| `HAND 1`, resultado, monedero, recompensa de libreta y revisión UTE VA | Los textos con cifras o fragmentos traducidos ya formateados tampoco coincidían con claves al cambiar de idioma. | Se recalculan mediante funciones conservadas por un nodo hijo del control. No se reconstruye la pantalla ni se repiten premios/compras. [Tienda](../capturas/recorrido/ingles_final/en_1280x720/tienda_idioma_caliente.png), [libreta](../capturas/recorrido/ingles_final/en_640x360/libreta_idioma_caliente.png). Prueba gráfica comprueba que pesos y victorias permanecen iguales al cambiar idioma sobre la libreta. |
| `TARGET 100 · HAND 1`, turno y ayudas almacenadas del HUD | La meta podía quedarse en el idioma anterior hasta el siguiente refresco del juego. | `apply_settings()` refresca el HUD cuando cambia el idioma durante una partida, conservando `ui_phase`. Invalida las firmas de controles con ayudas traducidas. No ejecuta ese refresco al arrancar en la calle. [Meta en español tras cambio](../capturas/recorrido/ingles_final/en_640x360/tienda_idioma_caliente.png). |
| `Colmadón FM · colmado tunes` | La frase inglesa excedía los 164 píxeles del título de radio y activaba la elipsis. | Acortada a `Colmadón FM · music`; conserva el sentido y cabe. Español intacto. [Antes](../capturas/recorrido/ingles_despues/audit_640x360/menus/observacion_00.png), [después](../capturas/recorrido/ingles_final/en_640x360/radio_fm.png). |
| `1 songs added` / `1 canciones añadidas` | El aviso usaba siempre plural. | Singular `1 song added` / `1 canción añadida`, plural para 0 y 2. Este cambio español corrige un error claro. Prueba del mismo método que llama el selector, sin importar archivos reales. [Texto preparado EN](../capturas/recorrido/ingles_final/en_640x360/importacion_1.png), [ES](../capturas/recorrido/ingles_final/es_640x360/importacion_1.png). Las capturas presentan el resultado en un panel de QA; no simulan una importación real. |

No se ha cambiado la corrección de PARARSE/B02 ni su mecanismo `_symbol_button` / `_translate_symbol_buttons`.

## Alertas revisadas que no son bugs de traducción

| Alerta | Revisión visual / decisión |
|---|---|
| Nombre largo de una canción importada | Elipsis prevista; el nombre original no se traduce. Se conserva el recorte, sin renombrar ni copiar canciones. [Captura](../capturas/recorrido/ingles_final/en_640x360/musica_propia.png). |
| Título español de Colmadón FM | Ya tenía elipsis prevista; la tarea pide conservar el español salvo errores claros. Se mantiene. |
| `Yeya counts: ...` / `... POINTS!` con rectángulo fuera de pantalla | La animación agranda un control de ancho completo; el texto visible permanece centrado y legible. El detector mide el rectángulo escalado, no solo los glifos. No se cambia el efecto. |
| `THE PASSER`, `TABLE SLAM`, `HEAVY DOUBLE` en rectángulos diminutos | Carta capturada durante su contracción al salir hacia el HUD. Los títulos de las cartas en reposo caben. |
| Placas de bebidas al pasar ES ↔ EN | Avisos de ancho durante el ajuste del contenedor; las capturas estables muestran el texto entero y el plural correcto. |

La revisión de Ajustes mantiene los nombres Español, English y Colmadón FM, nombres de jugador y títulos importados sin traducción. Morir Soñando, chivo, tranque, capicúa y colmado respetan el glosario.

## Cobertura y resultados

Revisión con ventana real, base lógica 640×360 y salida física tanto **640×360** como **1280×720**. Cada tamaño tiene sus propias capturas.

| Recorrido local | 640×360 | 1280×720 |
|---|---|---|
| menus | COMPLETADO, 0 fallos | COMPLETADO, 0 fallos |
| partida | COMPLETADO, 0 fallos | COMPLETADO, 0 fallos |
| clasico | COMPLETADO, 0 fallos | COMPLETADO, 0 fallos |
| de_pie | COMPLETADO, 0 fallos | COMPLETADO, 0 fallos |
| raros | COMPLETADO, 0 fallos | COMPLETADO, 0 fallos en repetición |
| final | COMPLETADO, 0 fallos | COMPLETADO, 0 fallos |
| ute | COMPLETADO, 0 fallos | COMPLETADO, 0 fallos |
| mostrador | COMPLETADO, 0 fallos | COMPLETADO, 0 fallos |

Primera pasada de `raros` a 1280×720: 23 fallos del supervisor, empezando por no activar JUGAR y no encontrar Partida rápida; no fue un SCRIPT ERROR. Se conserva esa evidencia en `ingles_despues/bot_1280x720/raros`. Repetición separada completa con 0 fallos. No se atribuye automáticamente el fallo a un bug del producto ni se oculta como éxito.

Carpetas de evidencia:

- `capturas/recorrido/ingles_antes/`: primera pasada y captura del fallo de idioma.
- `capturas/recorrido/ingles_despues/bot_640x360/<escena>/`: ocho recorridos, marcas, auditorías y JSON del supervisor.
- `capturas/recorrido/ingles_despues/bot_1280x720/<escena>/`: menús, partida, clásico y de pie; primera corrida fallida de raros.
- `capturas/recorrido/ingles_repeticion/bot_1280x720/<escena>/`: raros, final, ute y mostrador completos.
- `capturas/recorrido/ingles_despues/prueba_<menus|cartas|revision>_<resolucion>/`: pruebas integradas y copias de sus PNG de user://.
- `capturas/recorrido/ingles_final/<en|es>_<resolucion>/`: calle, pizarra completamente dibujada, amigos, personaje y pestañas, armario y pestañas, ajustes, confirmación de borrado (solo abierta), radio, textos de importación, aumentos, tienda, entre manos, libreta y cambios de idioma.

`--prueba-menus`, `--prueba-cartas` y `--prueba-revision`: las seis ejecuciones finalizaron con código 0 y sin SCRIPT ERROR. Revisadas visualmente pizarra, ajustes, cartas de texto largo, barra de revisión, UTE VA, mostrador, tienda y libreta en ambos tamaños, además de las pantallas estáticas y cambio de idioma ES/EN.

Sala/chat anfitrión e invitado, cartel de ausencia y espera de elección: estados preparados en el harness, sin iniciar sesión ni conectar a ningún servidor. [Chat](../capturas/recorrido/ingles_final/en_640x360/sala_chat_preparada.png), [invitado](../capturas/recorrido/ingles_final/en_1280x720/sala_invitado_preparada.png). No certifica sincronización online, reconexión real ni mensajes arbitrarios del servidor. Buscador público de la rama separada no integrado/revisado aquí. Android y selector nativo de música no ejecutados.

Pruebas finales:

- Importación Godot: completada sin errores de script.
- `tests/prueba_traduccion.tscn`: **495 claves SIN FALLOS**; incluye plurales ES/EN 0/1/2 y el mismo Label formateado cambiando ES → EN → ES.
- `tests/prueba_revancha.tscn`: **REVANCHA UI SIN FALLOS**.
- Autotest con ventana ES: **PARTIDA TERMINADA [138, 59], 2 manos**.
- Autotest con ventana EN: **PARTIDA TERMINADA [113, 82], 3 manos**.
- Autotests: código 0 y ningún SCRIPT ERROR. Los archivos `.translation` regenerados se conservan porque cambió el CSV.
- Cuatro pasadas gráficas estáticas ES/EN × ambas resoluciones: completadas; pesos/victorias no se duplican por cambiar de idioma.

## Reproducir

Desde la raíz, sustituyendo `<godot>` por la ruta de AGENTS.md:

```powershell
& '<godot>' --headless --path . --import
& '<godot>' --headless --path . res://tests/prueba_traduccion.tscn
& '<godot>' --path . --resolution 640x360 --fixed-fps 30 --script res://tests/revisar_ingles.gd -- --autotest --qa-estaticas --qa-idioma=en --qa-resolucion=640x360 --qa-salida=res://capturas/recorrido/mi_revision/en_640
& '<godot>' --path . --resolution 1280x720 --fixed-fps 30 --script res://tests/revisar_ingles.gd -- --recorrido --escena=ute --qa-idioma=en --qa-resolucion=1280x720 --qa-salida=res://capturas/recorrido/mi_revision/audit --salida-recorrido=res://capturas/recorrido/mi_revision/bot
& '<godot>' --path . --resolution 1280x720 --fixed-fps 30 --script res://tests/revisar_ingles.gd -- --prueba-cartas --qa-resolucion=1280x720 --qa-salida=res://capturas/recorrido/mi_revision/cartas
```

Cambiar el tamaño y `--qa-idioma=es` para comparar. Sustituir la escena por las ocho locales y la prueba por menus/revision. Las pruebas integradas guardan sus PNG en user://; copiar esos PNG antes de ejecutar el siguiente tamaño. Ejecutar recorridos con clics sin lanzar nuevas ventanas durante su ejecución para una repetición más estable.

Prueba manual del cambio: abrir Ajustes, pulsar English/Español y comprobar navegación y radio; repetir desde la pausa en elección de aumentos y tienda. En libreta, comprobar texto y que la cantidad de pesos no aumenta otra vez.

Commit propuesto: `[Codex] Revisa el inglés en pantalla y actualiza textos al cambiar de idioma`.
