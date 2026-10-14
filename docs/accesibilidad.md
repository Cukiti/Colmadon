# Accesibilidad — 2026-10-06

**Estado vigente al 7 de octubre de 2026:** código integrado en principal y publicado en GitHub en esta entrega autorizada. Nube y Windows publicados anteriormente; esta entrega integra herramientas del bot y documentación, sin nuevo despliegue ni exportación. APK/Para-amigos pendientes. Véanse [traspaso](TRASPASO_CLAUDE.md) y [tablero](TABLERO_COLMADON.html). Las secciones anteriores conservan resultados históricos.

**Estado vigente al 2026-10-07:** Implementación incluida en el EXE Windows publicado el 7. Pendientes Android físico y validación con personas con daltonismo; APK todavía anterior. Consulta [traspaso](TRASPASO_CLAUDE.md); el resto conserva el historial.


Implementada en principal/master, sin commit ni push. Se entra desde **Ajustes → Accesibilidad** y se vuelve a la misma pantalla de Ajustes. Mantiene el panel de madera y la radio; las opciones nuevas tienen su propio panel desplazable para no apretar los controles actuales.

## Opciones y cómo probarlas

- **Texto Normal / Grande / Muy grande:** factores 1 / 1,15 / 1,30 sobre las fuentes originales. Incluye botones, etiquetas, marcador, chat y avisos flotantes. No cambia la resolución del SubViewport, las fichas, la mesa ni las reglas. Cambiar tamaño y recorrer Ajustes, pizarra, espejo, armario, chat, tienda y libreta; volver a Normal comprueba que no se acumula la escala. Ajustes y modos pasan a tener desplazamiento cuando hace falta; los textos de los modos se envuelven y los pies permanecen accesibles. El armario se mantiene dentro de pantalla y el cartel de turno evita el marcador, el monedero y los nombres.
- **Modo daltónico:** azul `#56B4E9` y naranja `#E69F00`, evitando la distinción rojo/verde para los estados cubiertos. El marcador distingue parejas con ◆/●; el turno con ▶/●; el tranque y la libreta con ✓/× y palabras explícitas; las puntas con 1/2. Las puntas accesibles no pulsan su opacidad. En un tranque, comprobar ambas manos, la cuenta y el ganador; al elegir ficha, comprobar las dos puntas. La libreta usa variantes oscuras sobre papel para mantener legibilidad. No se añadieron destellos.
- **Teclas de PC:** siete gestos, pararse/sentarse, mirar y chat. Pulsar la tecla mostrada, elegir una nueva y comprobarla en partida. Las teclas anteriores dejan de activar la acción; se rechazan duplicadas y teclas de movimiento/modificadores/pausa. Escape cancela la captura. «Restablecer controles» recupera 1–7, E, Tab y C. Las ayudas de gestos y de pie reflejan las teclas asignadas. La sección se oculta con la característica `mobile`; el chat se abre en los estados donde está disponible y pararse respeta las restricciones existentes de la partida.
- **Menos movimiento:** anula la sacudida y el balanceo de cámara por mareo del ron, conservando el ajuste previo de sacudida al desactivarlo. No suprime las animaciones del personaje. Probar activado/desactivado mientras se bebe ron o se golpea la mesa.

Todo se guarda en `ajustes.cfg` como las demás opciones. Los ajustes anteriores reciben los valores predeterminados y los mapas de teclas inválidos vuelven al mapa seguro. Se añadieron 18 claves ES/EN y se regeneraron las traducciones.

## Validación

Las pruebas usan `--autotest` y archivos exclusivos de prueba; no leen ni sobrescriben el perfil o los ajustes reales del jugador. Las pruebas de interfaz crean estados preparados, sin conectar al servidor local ni a la nube. Los fallos iniciales del harness al preparar una mesa durante su barajado se corrigieron en el fixture, sin modificar la animación del juego.

```powershell
$g = '%USERPROFILE%/AndroidStudioProjects/Godot_4.7.2/Godot_v4.7.2-stable_win64_console.exe'
& $g --headless --path . --import
& $g --path . --resolution 640x360 --script res://tests/prueba_accesibilidad.gd -- --autotest
& $g --path . --resolution 1280x720 --script res://tests/prueba_accesibilidad.gd -- --autotest
& $g --path . --resolution 1280x720 --script res://tests/auditoria_accesibilidad.gd -- --autotest --qa-estaticas --qa-idioma=es --qa-salida=res://capturas/recorrido/accesibilidad/final_es
& $g --path . --resolution 1280x720 --script res://tests/auditoria_accesibilidad.gd -- --autotest --qa-estaticas --qa-idioma=en --qa-salida=res://capturas/recorrido/accesibilidad/final_en
& $g --path . --resolution 1280x720 --script res://tests/autotest_accesibilidad.gd -- --autotest
& $g --path . --resolution 1280x720 --script res://tests/autotest_accesibilidad.gd -- --autotest --clasico
```

Resultados: 478 comprobaciones sin fallos en cada resolución; guardado/carga de las seis combinaciones tamaño/paleta/movimiento y de las diez teclas; migración, duplicados, reservas, cancelación, restablecimiento y ejecución de gestos/pararse/mirar/chat correctos. Capturas ES/EN de los tres tamaños en 640×360 y 1280×720, chat, mesa/puntas y tranque. Auditoría de los estados preparados completos ES/EN con Muy grande: cero incidencias en zonas fijas, con revisión visual de las zonas desplazables. La auditoría distingue el recorte deliberado por desplazamiento o elipsis de un control fuera de pantalla; no pretende detectar cualquier solapamiento posible.

Pruebas de AGENTS: lógica 300 partidas/1021 manos sin fallos; chivo 0 fallos; colocación 400 manos/semilla 20261006, fuera/montadas/pegadas/movidas 0, conservando un escalón y dos dobles de esquina anteriores. `npm test`: 3000 partidas/9928 manos, sala 818 comprobaciones, paridad 400 estados/1236 jugadas y cuenta sin fallos. Traducción 518 claves sin fallos e importación correcta. Partidas gráficas con accesibilidad: aumentos `[108,78]`, cuatro manos; clásico `[0,115]`, tres manos. Autotest gráfico habitual: `[125,0]`, tres manos. La repetición final de clásico con el código terminado dio `[101,17]`, tres manos. Todos imprimieron `PARTIDA TERMINADA`, código 0 y sin `SCRIPT ERROR`.

Evidencia local: `capturas/recorrido/accesibilidad/`, con subcarpetas por resolución y `final_es`/`final_en`; resumen de validación en `validacion.json`. Las capturas y logs de QA permanecen fuera del código publicable.

No se probaron dispositivos Android físicos ni se realizó una evaluación con usuarios con daltonismo; la paleta no sustituye las formas y textos. No se cambiaron reglas, servidor, buscador, radio compartida, arte, claves ni exportes, ni se cerraron procesos del usuario.

Commit propuesto: `[Codex] Añade accesibilidad y controles reasignables en Ajustes`.
