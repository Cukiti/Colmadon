# Recorrido de pruebas grabado

Cómo se graba y se revisa el juego entero, y qué salió en la primera revisión (2026-10-04).

## Auditoría completa de fotogramas y diseño — 2026-10-07

```powershell
./tools/recorrido.ps1 -Grabar -AuditarCadaFrame
./tools/recorrido.ps1 -Escenas menus,mostrador -Grabar -AuditarCadaFrame -Semilla 20261007
./tools/recorrido_online.ps1 -Grabar
python tools/analizar_recorrido.py capturas/<sesion>
python tools/analizar_recorrido.py --video capturas/<sesion>/<escena>/video.mp4 --fotograma 150 --salida capturas/fotograma_150.png
```

El recorrido local incluye nueve escenas, ahora también exploración. Online tiene un lanzador independiente para cuatro clientes gráficos, perfiles/cuentas QA distintos y sala coordinada por un archivo exclusivo de sesión. Usa el servidor configurado por Red; registra el host. No arranca ni reinicia servidores. Sin `-Grabar` los cuatro clientes también generan trazas y capturas, pero esa prueba no tiene vídeo que analizar.

`-AuditarCadaFrame` registra `frames.jsonl` por cada frame procesado y ejecuta auditoría de interfaz/textos/espacio en cada uno. `acciones.jsonl` registra botones pulsados; se verifica su señal pressed para reconocer clics ignorados. Los clics usan coordenadas del viewport; las teclas conservan Input para que caminar funcione. El mostrador tiene navegación AStar por obstáculos, movimiento con W y fallo explícito si no llega, sin colocar al jugador allí directamente. Los escenarios antiguos que preparan una mano o una posición siguen siendo fixtures y no prueban esa preparación mediante el jugador.

El auditor visual revisa textos fuera del margen, ancho disponible y solapes de la tinta aproximada, respetando alineación y excluyendo escritura parcial. Mantiene persistencia para evitar avisar por un único frame. El espacial compara la cabeza del colmadero con cajas del entorno, y ofrece soportes declarados mediante grupo `audit_soporte` y meta `audit_soporte_y`. **No conoce automáticamente el soporte correcto de todos los objetos**: un adorno colgado o una ficha volando no es flotación defectuosa. Las cajas que se cruzan generan candidatos para revisar la malla y perspectiva, no confirmación automática.

El analizador decodifica todos los frames del vídeo para parpadeos, mide FPS/cantidad de frames reales y comprueba continuidad de la traza del bot. Conserva AVI original, produce MP4, hojas, `resumen.json`, `bugs.md` e informe navegable con anterior/siguiente e índice de frame. La extracción por CLI usa el índice exacto del vídeo; el paso del navegador depende de su decodificador. Las marcas nuevas de grabación usan frames dibujados del motor para incluir carga anterior al bot; ejecuciones antiguas mantienen el reloj anterior y deben correlacionarse con sus capturas.

Esto no equivale a una revisión humana semántica de cada imagen. La cobertura del informe dice qué se ejecutó y qué quedó sin revisar; COMPLETADO no declara ausencia de bugs.

## Criterio para documentar bugs y mejoras visuales

Documentar también usabilidad/diseño, aunque el juego no lance errores: jerarquía de botones en Pizarra, posición/alineación de avisos durante una mano, profundidad y apoyo de objetos, cabeza/tabla del colmadero, sombras y capas que ocultan personajes.

Cada hallazgo debe incluir categoría, estado (confirmado/candidato/mejora propuesta/no revisado), impacto y prioridad, escena/resolución/idioma, pasos, frame/intervalo y captura, comportamiento actual y esperado, recomendación concreta y prueba de aceptación. Nunca presentar como confirmado un problema únicamente porque intersectan AABB. La estética y claridad de las acciones se revisan visualmente.

Ejemplo: **Pizarra, mejora de usabilidad**: diferenciar jugar, crear/entrar a sala y volver con jerarquía, agrupación, textos y márgenes; no depender solo de color. Aceptación: un jugador nuevo identifica modo, acción principal y volver sin confundir controles. **Mostrador, candidato geométrico**: cabeza intersecta tabla del fondo; confirmar captura desde compra, separar profundidad y comprobar otras sillas.

## Cómo se usa

    bash tools/recorrido.sh                 # todas las escenas (unos 7 minutos)
    bash tools/recorrido.sh de_pie final    # solo esas

- **Bot director** (`scripts/recorrido.gd`, se activa con `-- --recorrido --escena=X`): juega como una persona con ratón y teclado reales, usa el perfil de pruebas (nunca toca el tuyo) y una semilla fija (misma partida cada vez).
- **Escenas:**
  - `menus`: calle, pizarra, sala, espejo, armario, ajustes, recorrido circular.
  - `partida`: 2 manos con aumentos.
  - `clasico`: 2 manos en modo clásico.
  - `de_pie`: levantarse, ratón, caminar, chocar, gestos, empujar, lejos de la silla, Tab, sentarse.
  - `raros`: pausas en cada fase, ajustes desde la pausa, vista de arriba, pausar de pie, salir a mitad, partida en inglés.
  - `final`: última mano, chivo, cuenta, libreta, revancha.
  - `online`: anfitrión y amigo, con servidor local; uno se para y el otro tapa.
- **Grabación:** Movie Maker de Godot a 30 fps fijos; no se pierde ningún fotograma.
- **Auditoría dentro del juego (`auditoria.jsonl`):**
  - botones que se pisan (dos revisiones seguidas);
  - botones fuera de pantalla;
  - textos más anchos que su botón;
  - tus fichas invisibles en tu turno;
  - fichas de la línea montadas (sin contar las que vuelan);
  - botones que el bot no encuentra.
- **Análisis del vídeo (`tools/analizar_recorrido.py`):**
  - MP4 para el navegador;
  - hojas de miniaturas (4 por segundo) con la marca de cada momento;
  - parpadeos: zonas que van y vuelven casi en cada fotograma (8 o más en 1 s) con la cámara quieta;
  - errores del motor;
  - nodos y memoria, para detectar fugas.
- **Informe:** `capturas/recorrido/informe.html`, con los vídeos y las capturas en `capturas/recorrido/<escena>/`, fuera de git.

## Bot explorador ampliado (2026-10-11)

Orden: barrido de botones de 7 pantallas de menús → pendientes guiados → barrido de la pausa y sus ajustes → modo cámara y arma guiados → juego libre (una partida de cada dos con mira y teclas, con tiroteos al azar). Pendientes nuevos: `botones_menus`, `botones_pausa`, `camara_*`, `arma_*`, `sin_errores_motor`, `sin_fugas`. Los errores del motor se capturan con un `Logger` y se atribuyen a la última acción. `--sin-barrido` se salta el barrido de menús. Conviene `--limite-recorrido=3000` (unos 12 min simulados).

## Bot explorador (2026-10-04)

    bash tools/recorrido.sh explorar
    # o sin vídeo, más rápido y con otra partida:
    godot --path . -- --recorrido --escena=explorar --semilla=7 --partidas=2

- **Qué hace:** primero repasa una **lista de pendientes** guiados y luego juega partidas rápidas **con libertad**, eligiendo al azar (según la semilla) lo que haría una persona curiosa: repasar fichas con el ratón, clic o arrastre, chivos, «¡Ute va!», beber, mirar desde arriba, pausar, pararse y pasear con gestos, volver tocando la silla, contar a mano o todas de golpe, comprar, «Ver la mesa» (también con pausa encima), revancha o volver al colmado.
- **Pendientes** (cada uno acaba en OK o FALLO con su nota, en `capturas/recorrido/explorar/pendientes.md`): pausa que no tapa carteles, mesa limpia al empezar, «Ver la mesa» con botones enteros, pausar de pie y ajustes de pie, silla resaltada cerca y no lejos, clic en la silla, gestos sentado, bots que juguetean, salir y empezar otra, sin atascos e invariantes.
- **Vigilancia continua:** atascos (40 s sin que cambie nada), marcador que baja, fichas que no suman 28, monedas negativas, placas de nombre montadas, pausa que pisa textos y que pausar de pie te siente. Además, toda la auditoría del recorrido.
- Código: `scripts/explorador.gd` (hereda las herramientas de `scripts/recorrido.gd`).

## Supervisor del bot (2026-10-05)

En Windows, el lanzador local conserva cada sesión en una carpeta nueva:

```powershell
./tools/recorrido.ps1                       # ocho escenas locales, incluye ute y mostrador
./tools/recorrido.ps1 -Escenas ute,raros     # solo casos seleccionados
./tools/recorrido.ps1 -Escenas clasico -Grabar
./tools/recorrido.ps1 -Escenas explorar      # explorador libre
```

No arranca servidores. El lanzador de Bash anterior sigue disponible. El PS1 aplica un límite de proceso de 1800 s reales y continúa con la siguiente escena si vence, registrando `TIEMPO_PROCESO_AGOTADO`. Solo termina el proceso que él creó. El vídeo AVI se genera con `-Grabar`; después se puede analizar con `python tools/analizar_recorrido.py <carpeta de sesión>`.

El bot ahora atiende la revisión UTE VA y el aviso de tranque antes de seguir jugando o dar por alcanzado el destino de fase. En la revisión pulsa una ficha que casa con las puntas o NO LLEVABA, usando controles reales. La escena `ute` conserva además la prueba de elegir una ficha incorrecta. La cuenta espera a que aparezca su interfaz y continúa contando si pasa a manual. El bot no modifica las reglas para resolver esos paneles.

Las consultas de botones usan las claves originales y las variantes de `translations/textos.csv`, retirando los símbolos que ahora son iconos. Esto cubre PASO/PASS y SIGUIENTE MANO/NEXT HAND sin corregir la traducción persistente del producto. No convierte todos los controles del juego en identificadores estables; los controles dinámicos de revisión se localizan dentro de su panel por el tooltip de ficha.

Si el estado de juego no avanza en 40 s simulados, guarda captura y estado JSON y admite dos recuperaciones mediante la interfaz (panel conocido, pausa, cuenta, vista de mesa o sentarse). Si persiste, abandona el objetivo con fallo. Una recuperación no borra el fallo. El explorador comparte el manejo prioritario y vigila también su bucle libre. Las ventanas desconocidas no se aceptan a ciegas: quedan limitadas por los plazos.

`resultado_bot.json` distingue COMPLETADO y FALLO, enumera casos ejecutados y conserva fallos/esperas agotadas. COMPLETADO significa que terminó el recorrido, no ausencia de bugs: las alertas visuales siguen en `auditoria.jsonl` para revisión. Los casos del explorador que no se dieron se marcan NO_REVISADO. Los sondeos opcionales pueden usar `hasta(cond, segundos, false)` para no confundir una ausencia esperada con un fallo.

Límite global: 1200 s simulados por defecto, configurable con `--limite-recorrido=N`. Carpeta configurable con `--salida-recorrido=res://capturas/<sesion>`. El límite externo del PS1 protege también contra bloqueos donde Godot deja de procesar frames.

Validación: ambas ramas de revisión por clic real, búsquedas ES/EN, captura/JSON al vencer una espera, dos recuperaciones y abandono; límites simulado y externo con continuación del lanzador. Escena ute completada; raros completada sin espera de PASO/PASS; clásico reconoció dos tranques y siguió revisando la mesa. Explorador final: 15/15 pendientes, 88 acciones, cero fallos del supervisor. No se aplicaron las correcciones del juego B01/B02 documentadas en docs/bugs_recorrido_2026-10-05.md. No probado online ni Android.

Prueba de integración gráfica (perfil de pruebas):

```powershell
& '<godot>' --path . --resolution 1280x720 --fixed-fps 30 --script res://tests/prueba_supervisor_recorrido.gd -- --autotest
```

Esta prueba provoca fallos de espera deliberadamente y verifica que se registren. Su JSON FALLO es esperado; la prueba termina con `SUPERVISOR ... SIN FALLOS` si sus aserciones pasan.

## Auditoría espacial (2026-10-05)

Durante el recorrido se inspecciona el mundo una vez por 30 frames, y una alerta debe repetirse en tres muestras consecutivas. Se guarda como candidato pendiente de revisión visual en `espacial.jsonl`, con coordenadas, distancias, rutas de objetos y captura (máximo 12 por escenario). `cobertura_espacial.json` y `resultado_bot.json` indican el alcance. No cambia posiciones, reglas ni física del juego.

Comprobaciones incorporadas:

- Penetración del cuerpo del jugador en los cuatro obstáculos de caminar, fuera de sala, contra personas o contra sillas vacías, según las formas reales de `pie.gd`. Tolerancia de 2–3 cm; solo estando de pie, excluyendo las transiciones intencionadas de silla.
- Desfase entre centro visual de mesa y caja de colisión de caminar (>4 cm).
- Posición/orientación de las tres sillas ajenas en reposo, según distribución de asientos; movimientos de silla/personas de pie quedan excluidos.
- Los doce bordes/bandejas: posición cardinal, altura y orientación declaradas (>2 cm o 2°). La base completa de mesa no se confunde con un borde.
- Esquinas de fichas asentadas fuera del tablero, complementando la prueba existente de fichas montadas. Se excluyen vuelo y cuenta.

La simetría se compara en coordenadas 3D contra la disposición prevista, no contra píxeles de cámara: una silla más grande por perspectiva no es un error. No se exige que personajes, gestos o decoración sean simétricos. No comprueba automáticamente si el estilo artístico es agradable.

Extensión a otros objetos: añadir raíces de objetos independientes al grupo `audit_solido` desde una escena de pruebas. Se comparan sus cajas envolventes visibles, hasta 64 raíces por muestra, omitiendo ancestro/descendiente. Objetos ensamblados pueden compartir metadato `audit_union` para permitir ese cruce. Sus intersecciones son aproximaciones y requieren revisión de mallas; no equivalen a contacto físico exacto. Ningún objeto decorativo se registró automáticamente en esta primera versión: aparecen como NO_REVISADO en cobertura. No se certifica todo el mobiliario ni todas las formas de PhysicsServer.

Pruebas: `tests/prueba_auditoria_espacial.gd` verifica contacto permitido, penetración, separación, ensambles y alineación. `tests/prueba_espacial_escena.gd` introduce defectos controlados en escena real, comprueba exclusión de transición, persistencia, deduplicación y foto/JSON. Recorrido final de pie: 67 muestras, ninguna alerta espacial persistente en el ámbito revisado. Los defectos artificiales de pruebas no son bugs del juego. No probado Android/online.

## Primera revisión (2026-10-04)

### Fallos encontrados y arreglados
- **Parpadeos de píxeles al mover la cámara:**
  - **Rayas de la madera:** las texturas de madera no tenían mipmaps; ahora sí.
  - **Barrotes de las ventanas:** eran demasiado finos para dibujarse a 640×360; ahora son más gruesos.
  - **Rejilla de la radio:** igual de fina; ahora tiene tres listones gruesos.
- **Abanico con efecto rueda de carro:** las aspas giraban a 18 rad/s y a 30 fps parecían temblar. Ahora giran despacio, con un disco translúcido de «borrón».
- **Botones de tu turno y de bebidas que parpadeaban:** se borraban y se volvían a crear en cada refresco, y durante un fotograma no se veían. Ahora solo se rehacen si cambia lo que muestran.
- **«Ver la mesa» pisaba los botones de bebida:** las bebidas se esconden mientras el cartel está abierto.
- **Las frases del chat tapaban «Copiar código»:** en la sala de espera, el panel de frases sale arriba a la derecha.
- **Placas de nombre pegadas al borde de pie:** cuando la persona no está en la vista, su placa ya no se queda en el borde de la pantalla.
- **Texto antiguo:** «No llevas · pasas solo» pasa a ser «No llevas: toca PASO».
- **Cartel «¡CHIVO!» huérfano:** se quedaba flotando en la mesa cuando empezaba la cuenta; ahora se desvanece.

### Revisado y correcto (no son fallos)
Lo que el detector aún marca son animaciones que se quieren así:
- el contador de la cuenta que salta con cada ficha;
- los «+N»;
- el botón «¡UTE VA!» que late;
- la boca al hablar en el espejo;
- tus fichas que se mecen;
- las manos de los personajes.

### Para decidir (equilibrio)
- **Los +30 de pase acaban partidas muy rápido:** en la escena `partida`, los rivales ganaron 0-102 en 2 manos (pase de salida, pase corrido y una acusación falsa).
- **Un chivo cantado gana la partida de golpe:** se lleva los puntos de las 4 manos (unos 120 al principio de la mano). En la primera mano eso es la partida entera (127-0).
