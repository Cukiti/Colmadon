# Bot de recorrido y revisión visual — 7 de octubre de 2026

**Estado vigente al 7 de octubre de 2026:** código integrado en principal y publicado en GitHub en esta entrega autorizada. Nube y Windows publicados anteriormente; esta entrega integra herramientas del bot y documentación, sin nuevo despliegue ni exportación. APK/Para-amigos pendientes. Véanse [traspaso](TRASPASO_CLAUDE.md) y [tablero](TABLERO_COLMADON.html). Las secciones anteriores conservan resultados históricos.

Trabajo en `.trabajo-codex/bot-auditoria-completa`, rama `codex/bot-auditoria-completa`, basado en principal más sus cambios locales. Se mejora el bot de pruebas, no la estrategia de los rivales de dominó. No se cambia diseño/reglas del producto ni se publica otra versión.

## Cambios

- Auditoría opcional en cada frame, traza continua con fase/pantalla/mano/postura/pausa; registro de acciones y confirmación de pressed. Coordenadas de viewport corrigen clics al cambiar resolución. Objetivos que fallan abortan la escena; búsqueda tolera nodos liberados.
- Auditor visual: ancho, margen y solapes de tinta aproximada con alineación; excluye escritura parcial y exige persistencia. Auditor espacial: cabeza del colmadero contra cajas del entorno y soporte declarado para objetos. La cobertura de objetos sin soporte declarado sigue limitada.
- Navegación AStar al mostrador mediante movimiento y obstáculos, con fallo si no llega. El resto de preparaciones artificiales se reconoce como fixture, no recorrido humano.
- Nueve escenas locales por defecto, incluye explorador. Escena nueva y lanzador de cuatro clientes gráficos online con cuentas QA distintas, entrada por código, gestos/postura y partida completa.
- Análisis de todos los fotogramas del vídeo para parpadeos; FPS y cantidad medidos, continuidad de trazas, AVI conservado, MP4/hojas/informe/bugs.md. Navegación de frames y extracción exacta por índice. Snapshot JSON acompaña nuevas fotos con posiciones, estilos, fuentes, alineación y estado de botones.
- Documentación de bugs incluye diseño/usabilidad, recomendaciones y pruebas de aceptación. Diferencia candidato, confirmado y propuesta de mejora.

## Evidencia y validación

Cuatro clientes gráficos contra nube terminaron partida completa, todos COMPLETADO/0 fallos del supervisor: 9789, 9865, 9836 y 10024 frames auditados (39514 en total). Cada uno hizo gesto/pararse/sentarse; tres resolvieron UTE. Esa ejecución no grabó vídeo: cuenta como prueba de interacción, trazas y capturas, no revisión de vídeo online. Evidencia: `capturas/online_cuatro_20261007_144442_011/`.

Auditor visual, auditor espacial, supervisor gráfico y cinco pruebas Python del analizador pasan. La prueba Python genera un vídeo real de 30 frames, comprueba su cobertura y extrae el frame 17. Prueba inicial del supervisor sin gráficos no servía para su recorrido de clics/capturas; se repitió gráficamente. Los intentos iniciales de menús y UTE se conservan como fallos del fixture, no se borran ni se presentan como bugs del producto.

Grabación local consolidada en `capturas/revision_bot_20261007/`, con `fuentes.json` para saber de qué intento procede cada escena. Menús recorrió todas sus pantallas pero conserva un clic fallido; UTE final completó su revisión tras aislar el fixture y dejar terminar el layout; mostrador final completó una ruta de 20 puntos, compra y siguiente mano sin fallo. Las primeras rutas fallaron por no incluir personas/sillas en el mapa y fueron corregidas. Cada intento anterior queda separado. No confundir el análisis automático de cada frame con inspección humana semántica de cada imagen ni afirmar cobertura de todas las combinaciones posibles.

## Revisión visual y recomendaciones concretas

### UX01 · Pizarra: la acción online se llama JUGAR — mejora de usabilidad P2

Captura revisada: `capturas/recorrido_20261007_144738_197/menus/pizarra.png`. Las tres filas activas usan JUGAR aunque «Sala con amigos» abre configuración/entrada y no empieza una partida directamente. El subtítulo solo describe código y amigos, sin indicar que también existe buscador público. Puede dificultar encontrarlo.

Recomendación: distinguir «Jugar ahora» de «Crear / entrar a sala» y hacer visible «Buscar salas»; describir modos con frases breves y agrupar navegación/metas aparte. Mantener texto/iconos además de color. Aceptación: jugador nuevo identifica partida local, sala pública/privada y volver sin abrir opciones por ensayo.

### UX02 · Meta y navegación de Pizarra — propuesta P3

La meta se sitúa junto a las marcas de victorias y al límite inferior; la animación de la mano invade esa zona mientras escribe. Captura anterior demuestra ese instante, no una obstrucción permanente.

Recomendación: alinear meta en una fila clara «Puntos para ganar», separar navegación y estadísticas, y retirar la mano antes de habilitar interacción. Aceptación: meta/volver permanecen legibles durante toda la transición y en ES/EN.

### V01 · Cabeza del colmadero y tabla — confirmado visualmente P2

El auditor detectó intersecciones de cajas y se revisó la captura real de compra `capturas/recorrido_20261007_150134_309/mostrador/m_mostrador.png`: la tabla entra en la zona lateral/posterior de la cabeza. Coincide con la queja del usuario. El panel tapa además parte de la cara; recomendar anclarlo más abajo o reservar el área del colmadero, con prueba en pantalla pequeña. La confirmación procede de la imagen, no solo de la AABB. Recomendación: separar profundidad de cabeza y tabla, mantener apoyo de objetos y comprobar cámara del mostrador y las cuatro sillas. Aceptación: ninguna pieza atraviesa visualmente cabeza/cabello en reposo o limpieza.

### V02 · Avisos de la mano — candidatos P2/P3

Aparecieron alertas durante cuenta/tranque por cajas anchas y solapes. Se afinó el auditor para medir tinta y excluir escritura parcial: una caja de aviso que sobrepasa el viewport no prueba por sí sola texto recortado. Revisar el frame/captura y mantener aviso de turno, marcador, nombres y acciones en zonas coherentes. Aceptación: no se tapa información necesaria para jugar y no cambia el diseño al actualizar reloj.

### V03 · Avisos simultáneos ilegibles — confirmado visualmente P2

Las cuatro capturas `cliente_0..3/online_final.png` muestran «No iba: ¡de verdad no llevaba!», «Falsa alarma · -10 monedas», «+30» y «¡NO LLEVA!» superpuestos. En el cliente 3 la frase además llega al borde derecho y se corta. Estado: transición del final de la tercera mano (resultado 112–60 según pareja), no pantalla final asentada. Es un problema visual real aunque el supervisor complete la partida.

Recomendación: cola o agrupación de avisos por evento, una zona reservada para el mensaje principal y puntuación debajo; límite de ancho, ajuste multilínea y márgenes. Aceptación: reproducir dos falsas acusaciones/pases seguidos y comprobar en las cuatro vistas que cada mensaje se puede leer sin tapar otro ni salir del viewport.

### B01 del fixture · UTE usaba un panel liberado

Un intento quedó en error de script al buscar ficha en `revision_ui` liberado. Se protegió la búsqueda, se abortan objetivos no alcanzados y se separó el pase forzado de un posible tranque por cuatro pases. La preparación de UTE ahora desactiva temporalmente la lógica automática, deja dos frames de layout y construye la revisión mediante su interfaz; restaura el procesamiento al finalizar. Es un fixture controlado, no validación de timing natural. Las revisiones de la partida online sí ocurrieron durante la partida normal. Guardar el intento como fallo del bot; no atribuirlo automáticamente a un fallo del juego.

### B02 candidato · Flecha del espejo no reconoció un clic

La repetición de menús con confirmación de pressed detectó un clic sin señal durante las opciones del cuerpo. Evidencia `clic_no_recibido_570.png` en la sesión de menús. El resto del recorrido avanzó; revisar cambio de geometría al seleccionar y si la referencia queda válida antes del segundo clic. No ocultar el fallo ni considerarlo resuelto por terminar la escena.

## Resultado del recorrido local

Ocho escenas dirigidas: partida, clásico, de pie, pausas/cambio de idioma, final, UTE y mostrador completados; menús recorrió las pantallas pero conserva un clic no recibido. Esas grabaciones suman 17350 frames de vídeo y 16810 frames auditados por el bot, con trazas continuas. Carga/cierre explican frames fuera de la vida del bot.

El informe final de las nueve grabaciones procesó **28884 frames de vídeo**, con **28281 frames auditados**, todas las trazas continuas y **0 errores del motor**. Estados: siete escenas COMPLETADO, menús FALLO por el clic y explorador TIEMPO_PROCESO_AGOTADO. Las alertas automáticas (incluidas las de parpadeo) requieren revisar evidencia y no son una lista de bugs confirmados.

El explorador grabado agotó el límite externo de 600 s durante la segunda partida; el vídeo y la traza se conservan como cobertura parcial. Repetición gráfica sin vídeo, una partida libre: COMPLETADO/0 fallos, **15/15 pendientes OK, 93 acciones libres y 10167 frames auditados**, dos chivos revisados. Evidencia en `capturas/explorador_final/`.

El detector de parpadeo agrupa intervalos durante la lectura; se retiró la comparación cuadrática de todos los eventos, que frenaba el vídeo largo. Una prueba con parpadeo sintético persistente valida detección e intervalos. Sus alertas siguen siendo candidatos (movimientos de manos, gestos, vuelos y compresión pueden producir señales); no se declara cada alerta un fallo real.

El caso adicional de libreta online asentada se añadió después de la partida y no se da por validado por esa ejecución. La comprobación de partida completa descrita arriba corresponde a fase over con conteo terminado.

## Límites pendientes

Android físico, todas las resoluciones/idiomas/combinaciones, desconexión/reconexión inducida y todas las interacciones sociales no están cubiertos por una sola partida de cuatro bots. No existe detector infalible de composición, confusión de botones ni soporte correcto de cada objeto. El informe conserva lo no revisado y los falsos positivos identificados.
