Colmadón · dominó por parejas · estado al 7 oct 2026

# Lo que falta en el colmado.

Todo lo pendiente después de la ronda de pruebas del 5 de octubre, agrupado por urgencia y con quién lo hace: yo (Claude), Codex o tú.

Servidor: **Oracle Cloud · 129.80.114.69:7350** (Google Cloud detenido el 2026-10-11; disco e IP conservados). Principal: **cambios integrados; publicación en GitHub realizada en esta entrega autorizada**. EXE actual: **export/Colmadon-Windows/Colmadon.exe**. APK/Para-amigos: **versiones anteriores**. Traspaso vigente: [docs/TRASPASO_CLAUDE.md](docs/TRASPASO_CLAUDE.md).

## 0 · Observaciones del día de pruebas (9 oct) — bugs y mejoras

Fuente: `Observaciones.docx` (18 puntos y 3 capturas). Columna **Bot**: ✅ el bot lo detecta solo en cada fotograma (`scripts/auditoria_observaciones.gd`, resultado en `observaciones.jsonl` y `cobertura_observaciones.json` de cada recorrido); ✅🔁 además ya lo reprodujo en el recorrido online de 4 clientes contra Oracle (9 oct); ✋ hay que mirarlo a mano. Prioridad: P1 rompe la partida o la privacidad, P2 se nota mucho, P3 pulido.

**2026-10-10 tarde:** sala con amigos nueva (cambio de silla con permiso, nombre de equipo acordado, LISTO antes de ¡A JUGAR!), reloj en las esperas y cuenta del tranque sincronizada. Probado con servidor local; falta desplegar en Oracle y probarlo con personas (y ver un tranque real online).

Lista para probar a mano lo hecho en el PR `nube/observaciones-1`: [docs/prueba_4_ventanas_observaciones.md](docs/prueba_4_ventanas_observaciones.md).

**2026-10-10 (Claude en Windows):** servidor de la rama desplegado en Oracle (salud 200). Recorrido 4 clientes contra Oracle: 4/4 completo y **0 hallazgos «obs_»** en ~84.000 fotogramas (ayer reproducía O02, O06, O07, O11 y O16). Arreglado además: panel de la sala que cortaba «¡A JUGAR!» con la fila nueva del equipo (O11), avisos «se sentó» sobre tu pareja, subtítulo de «Dominó con bots» recortado (O05), «Volver a la pizarra» con letra de tiza y botones de la libreta final. Sigue faltando la prueba a mano con personas.

| # | Tipo | Prio | Bot | Qué pasa / qué queremos |
|---|---|---|---|---|
| O01 | Bug | P3 | ✋ | **Hecho 2026-10-10:** el juego no bloquea el Snap (sin tamaño mínimo ni ventana fija); para no arrastrarlas, `--cuadrante=0..3` coloca cada ventana en un cuarto de pantalla y «Abrir 4 ventanas.bat» las abre ya en mosaico. |
| O02 | Bug · privacidad | P1 | ✅🔁 | «Volver a la sala» aparece aunque la partida ya terminó; y el aviso «Volviendo a la sala KTJ123» y el código grande de la sala siguen visibles al empezar (malo para streamers). Comprobar en el servidor que la sala vive antes de mostrar el botón, hacerlo más inmersivo y ocultar el código (o modo streamer). **Hecha en PR (rama `nube/observaciones-1`), falta prueba con 4 ventanas y desplegar (falta lo de «más inmersivo»).** |
| O03 | Mejora · arte | P3 | ✋ | **Hecho 2026-10-10:** iconos pixel art (Aseprite) en JUGAR, VOLVER A LA SALA, PERSONAJE, ARMARIO y SALIR, como el de Ajustes (`arte/interfaz/inicio_*.aseprite`, `tools/crear_inicio_aseprite.lua`). |
| O04 | Bug visual | P3 | ✋ | En la pizarra, la vitrina del mostrador está pegada y tapa parte de la pizarra. **Hecha en PR (rama `nube/observaciones-1`): era el abanico; falta mirarlo a mano.** |
| O05 | Mejora · diseño | P2 | ✋ | Fusionar «Partida rápida» y «Dominó clásico» en **«Dominó con bots»**: al entrar, dos folletos grandes a pantalla completa (izquierda clásico, derecha con aumentos y bebidas), cada uno con su arte. Pendiente: proponer ideas antes de hacerlo. **Hecha en PR (rama `nube/observaciones-1`) con la idea de los dos folletos en la pizarra; falta arte propio en Aseprite si se quiere.** |
| O06 | Bug online | P1 | ✅🔁 | En la sala de espera todos ven la mesa desde la silla del anfitrión; solo se corrige al pulsar ¡A JUGAR!. Debe verse desde tu silla nada más entrar. (Bot: 3 de 4 clientes con cámara en silla 0.) **Hecha en PR (rama `nube/observaciones-1`), falta prueba con 4 ventanas.** |
| O07 | Bug | P2 | ✅🔁 | Si nadie recoge sus fichas y se acaba el tiempo, aparecen de golpe en la bandeja: debe verse la animación de recogida. **Hecha en PR (rama `nube/observaciones-1`), falta prueba con 4 ventanas.** |
| O08 | Bug visual | P2 | ✅ | De pie, unos ven su personaje en el espejo y otros no; el recuadro del espejo está descentrado (en partida y en la pantalla de personaje). **Hecha en PR (rama `nube/observaciones-1`), falta prueba con 4 ventanas.** |
| O09 | Mejora servidor | P2 | ✋ | Cuando no queda ningún jugador real, la sala debe dejar de existir (no seguir solo con bots). **Hecha en PR (rama `nube/observaciones-1`), falta prueba con 4 ventanas.** |
| O10 | Mejora | P2 | ✅ | Al elegir aumento, «Esperando a que los demás elijan» debe decir cuántos están listos (p. ej. «2 de 4 listos»), no solo en la primera mano. **Hecha en PR (rama `nube/observaciones-1`), falta prueba con 4 ventanas.** |
| O11 | Mejora | P2 | ✅🔁 | En la sala online, cada pareja pone nombre a su equipo (máx. 8 letras) y sale en el marcador en lugar de NOSOTROS/ELLOS. Las dos placas deben medir lo mismo siempre (hoy 72 px contra 62 px). **Hecha en PR (rama `nube/observaciones-1`), falta prueba con 4 ventanas (placas iguales y nombres de equipo; los nombres necesitan desplegar el servidor).** |
| O12 | Bug visual | P2 | ✅ | Con «ESTÁS AUSENTE» activo se solapan textos («no llevas», «tira un chivo»…); arreglar simetría y tamaños. **Hecha en PR (rama `nube/observaciones-1`), falta prueba con 4 ventanas.** |
| O13 | Bug visual | P2 | ✅ | Con la skin de fichas negras, la ficha de la animación de «pensar» sale blanca. Causa: color fijo en `character.gd:944`. Todas las animaciones y efectos deben usar la skin puesta. **Hecha en PR (rama `nube/observaciones-1`), falta prueba con 4 ventanas.** |
| O14 | Bug visual | P2 | ✅ | El cartel «ESTÁS AUSENTE» no se quita y sigue mientras se elige aumento; solo debe verse en la mano en juego. (El texto del documento quedó cortado: confirmar el resto.) **Hecha en PR (rama `nube/observaciones-1`), falta prueba con 4 ventanas.** |
| O15 | Mejora online | P1 | ✅ | Cuando gana alguien, los demás ven contar las fichas antes de que esa persona cuente: todo debe seguir el ritmo real de quien actúa. Y en la cuenta, las fichas jugadas deben quedar más apartadas de las que se cuentan para no confundirse ni solaparse. **Hecha en PR (rama `nube/observaciones-1`), falta prueba con 4 ventanas.** |
| O16 | Mejora visual | P1 | ✅🔁 | Tras contar, las fichas de los jugadores de izquierda y derecha se quedan en sus bandejas y no se ven; deben quedar sobre la mesa (captura 1). **Hecha en PR (rama `nube/observaciones-1`), falta prueba con 4 ventanas.** |
| O17 | Bug | P2 | ✅ | «Tu pareja ganó por chivo cantado» no desaparece al empezar otra mano si no se pulsa Volver (capturas 1 y 2). Además, al pasar a elegir aumento desaparecen las fichas de las manos y solo quedan las jugadas. **Hecha en PR (rama `nube/observaciones-1`), falta prueba con 4 ventanas (aviso y fichas de las manos al elegir aumento).** |
| O18 | Bug + idea | P2 | ✅ | Ficha (doble 1) mal colocada al final de la partida (captura 3). Idea a futuro: lanzar la ficha y que el jugador más cercano la coloque bien, para dar vida a la mesa. **Hecha en PR (rama `nube/observaciones-1`): el doble ya no gira la esquina (24 → 6 en 3000 manos). Queda la idea a futuro: aparcada el 2026-10-11 hasta tener mejores colisiones, físicas e interacciones (propuesta: lanzar si la punta queda lejos y que el más cercano la endereza, cosmético y sin servidor).** |

## 1 · Probar ahora con las 4 ventanas

Ya está desplegado y exportado. Hace falta tu prueba para dar estos puntos por buenos o reabrirlos.

- Tú

  De pie en tu turno, el reloj se para

  Los demás ven «X está de pie: espera o siéntalo de un manotazo · reloj parado». Tope de congelación de 60 s; después continúa el reloj y, al vencer el turno, entra el bot. Verificado automáticamente contra nube; falta revisión manual.
- Tú

  Sillas que no se pegan ni se empujan

  Ya son objetos de la mesa. Probar online levantándose, haciendo emotes y con avisos.
- Tú

  Fichas boca abajo en la mesa al pararte

  Las tuyas y las de los demás; nadie se las lleva en la mano.
- Tú

  Emotes y movimientos visibles para los demás

  El código los envía y los recibe; falta confirmarlo entre varias personas (la queja de «no parece online»).
- Tú

  Brazos de pie como Steve y mirada a la cara

  Brazos abajo con vaivén; los de pie miran justo donde apunta su cámara.
- Tú

  Zoom con la rueda y mirar sentado con clic derecho

  Clic derecho arrastrado gira la vista; un clic derecho suelto la centra. Las fichas se siguen colocando con el puntero.
- Tú

  Tranque desde arriba

  Manos boca arriba en verde (gana) y rojo (pierde), 30 s o hasta que todos pulsen «VISTO».
- Tú

  Circulito rojo de la revancha y el Espejo centrado

  El circulito cuenta cuántas personas pidieron revancha.
- Tú

  Snap de Windows con las 4 ventanas

  Codex no encontró la causa en el código. Si sigue fallando, lo investigo yo con la ventana real.

## 2 · Bugs confirmados por el bot de recorrido

B01 y B02 corregidos, integrados y publicados en servidor/EXE. Se conserva debajo la descripción original para reconocer una regresión. Evidencia: `docs/pruebas_bugs_recorrido.md`. Tranque/VISTO entre cuatro humanos sigue pendiente.

- Codex

  B01 · El cierre del tranque se pisa con la siguiente mano P2

  El aviso con «VISTO» sigue abierto cuando ya salen «Ver la mesa», el mostrador y «SIGUIENTE MANO»: los paneles se tapan y se puede comprar y seguir sin reconocer el tranque.
- Codex

  B02 · «PARARSE» no cambia de idioma P3

  Al pasar a inglés sin reiniciar, todo se traduce menos ese botón (debería decir «STAND UP»). Causa probable en `_symbol_button` de `main.gd`.

## 3 · En marcha

Lo que queda de la ronda del 5 de octubre.

- Claude

  Radio compartida: Colmadón FM para todos

  **Hecho 2026-10-09 (falta desplegar el servidor):** tres pistas, misma pista y momento para toda la sala, más fuerte cerca de la radio; tocarla pasa de pista o la apaga. «Tu música» sigue siendo solo tuya.
- Claude

  Sala de espera: que se miren entre ellos

  **Hecho 2026-10-09:** se miran entre ellos y a ti, cambiando cada pocos segundos.
- Claude

  Animación rara al recoger las fichas

  **Arreglado 2026-10-09:** la cuenta cortada seguía moviendo las fichas durante la recogida. Falta confirmarlo a ojo con personas.
- Codex

  Buscador de salas públicas completado

  Integrado y publicado. Dos clientes gráficos contra nube verificaron filtros, refresco, entrada, salas en curso, reconexión y privacidad. Detalle en `docs/salas_publicas.md`; no queda pendiente la implementación del buscador.

## 4 · Problemas abiertos de antes

Arrastrados de rondas anteriores (sección «Pendiente» de `ESTADO.md`).

- Tú

  Repartir el APK y el EXE nuevos a los amigos

  El Windows actualizado está en `export/Colmadon-Windows/Colmadon.exe`. Falta renovar APK y paquetes de `export/Para-amigos/`; esos paquetes no se actualizaron en esta entrega.
- Tú

  Registros del cierre de la app de los amigos

  No se pudo reproducir. PC: `%APPDATA%\Godot\app_userdata\Colmadón (prototipo 0.1)\logs\`; Android: con `adb`.
- Tú

  Probar en el Galaxy A15

  Tacto, zona segura, rendimiento y conexión al servidor (aún sin https). El APK nuevo no se ha instalado en ningún móvil todavía.
- Tú

  Revisar la factura de Google Cloud

  Por la IP fija, a los 2–3 días.
- Claude

  Fichas por encima de cabezas y brazos

  **Arreglado 2026-10-09:** oclusión real en la capa nítida (copias de los personajes que escriben profundidad). Falta verlo de pie con personas y en móvil.
- Codex

  Fichas que se tocan en manos muy largas

  Última comparación de 2400 manos/seis semillas: contactos 10 → 9, escalones reales 2 → 1, dobles esquina 13 → 12; 0 fuera/montadas/movidas. Quedan casos extremos: `docs/colocacion_fichas_largas.md`.
- Codex

  Fuentes libres propias

  La tiza (Segoe Print) y la interfaz usan fuentes de Windows; en Android se verán distintas. Descargarlas necesita tu permiso.
- Codex

  Accesibilidad

  Controles PC, símbolos/paleta, movimiento reducido y tamaño del texto implementados e incluidos en Windows. Pendiente probar con personas con daltonismo y en Android: `docs/accesibilidad.md`.
- Claude

  Online que falta

  Servidor con https (necesita dominio), vincular cuenta de Steam o Google y el reto del día (decidido: modo clasificatorio solo/dúo con ELO, para el futuro). **Reloj del turno: comprobado 2026-10-10, ya se ve en todas las fases** (aumento, robar, turno, tienda y tranque).
- Claude

  Nivel visual de la pizarra en el resto de pantallas

  **Descartado 2026-10-11:** el usuario prefiere el espejo y la radio como están; se vio una maqueta (cartón y frontal de radio) y no se hace.
- Claude

  Tutorial de la primera partida

  **Hecho 2026-10-10 (rama `nube/observaciones-1`):** «Consejos del colmadero», carteles que salen una sola vez, sin conexión, la primera vez que pasa cada cosa: aumentos, robar, tu turno, no llevas (PASO o chivo), cantar ¡CHIVO!/¡UTE VA!, tienda y beber. Se guardan en el perfil (`consejos`). Probado con el bot (`--con-consejos`). Falta verlo con una persona nueva.
- Claude

  Audio final y música

  El sonido actual está sintetizado en código y es provisional.

## 5 · Antes de publicar

- Tú

  Comprobar que «Colmadón» está libre en Steam y Google Play

  Antes de pagar la ficha de Steam.
- Claude

  Compras de cosméticos en Google Play

  Google Play Billing, con dinero real.
- Claude

  Capturas y cápsulas para las tiendas

  Se pueden hacer píxel a píxel con Aseprite.

## 6 · Ideas propuestas, sin aprobar

Necesitan tu sí antes de empezar.

- Idea

  Modos Pintintín y Con pila
- Idea

  Chat de voz de proximidad

  La boca ya se mueve con el volumen de la voz.
- Idea

  Inmersión

  Cabeza libre sentado, beber tocando el vaso, contar las fichas a la vista de todos, «escribiendo…» en el chat y «zzz» sobre el ausente.
- Idea

  Animaciones

  Curvas de entrada y salida en todas las acciones y más expresiones (ver `docs/animaciones.md`).
- Idea

  Móvil

  Recorrido por el colmado en pantallas 20:9, giroscopio y pixel art que tiembla al caminar.

## Hecho en la ronda del 5 de octubre

- Arte Aseprite aprobado e integrado: caras 64×64 (Fello, Tito, colmadero…), radio e interfaz
- GitHub, nube y exportes publicados (commit `98acb56`)
- Bot de recorrido con supervisor y auditoría espacial
- Trabajo con Codex montado (AGENTS.md, bitácora, `tools/codex.sh`)
- Sin subtítulos en el inicio
- Sin «Píxeles del 3D»; 3 fallos de Ajustes arreglados
- «Desde arriba» / «Desde abajo»
- Espejo centrado
- Sin destello de la skin del bot en la sala
- Sillas de la mesa, sin empujones
- Fichas boca abajo al pararse
- Brazos de pie y acciones sin abrir brazos
- Mirada a la cara
- Zoom y mirada libre sentado
- Reloj parado de pie
- Tranque desde arriba con «VISTO»
- Contador de revancha
- Textos en inglés completados
- Servidor desplegado; seguimos con Google (Oracle descartado)

Detalle de cada punto en `docs/ronda_2026-10-05.md`, `docs/bugs_recorrido_2026-10-05.md`, `docs/BITACORA.md` y `ESTADO.md` del proyecto.
## Hecho el 6–7 de octubre

- Seis tareas integradas: recorrido B01/B02, buscador, inglés, registros, blindaje y accesibilidad.
- Estabilidad online corregida: avatar, animaciones, reloj, ausencia, avisos y postura en tienda.
- Servidor Google Cloud y EXE Windows publicados; cuatro clientes A–D abiertos para probar.
- Prueba real de estabilidad en nube: cuatro cuentas nuevas, 13 comprobaciones sin fallos. No sustituye la partida manual completa.
- Herramientas del bot integradas y código/documentos publicados en GitHub; sin exportación nueva de APK. Detalles y límites en `docs/TRASPASO_CLAUDE.md`.

## Bot y revisión visual integrados — entrega GitHub del 7 de octubre

El bot de pruebas (no la estrategia de los rivales) incorpora auditoría por frame, navegación AStar al mostrador, trazas, capturas con geometría de UI, análisis completo de vídeo y lanzador de cuatro clientes online. Informe: [mejora del bot](docs/mejora_bot_20261007.md). Vídeo local: 28884 frames analizados, 28281 auditados; siete escenas completas, un clic de menús fallido y explorador grabado parcial. Explorador repetido sin vídeo: 15/15 objetivos. Online: cuatro clientes, tres manos, 112–60, 39514 frames auditados, sin vídeo. La libreta asentada añadida después aún no se ha repetido.

Pendientes prioritarios: tabla atravesando cabeza del colmadero; mensajes de falsa alarma/No llevaba/+30 superpuestos y recortados; distinguir acciones y acceso al buscador en Pizarra. Clic del espejo: candidato pendiente de reproducción. No confundir alertas automáticas con bugs confirmados ni afirmar inspección humana de cada frame.

[Tablero interactivo](docs/TABLERO_COLMADON.html) · [Inventario exportable](docs/tareas_colmadon.json) · [Mensaje para Claude](docs/PROMPT_PARA_CLAUDE.md). El tablero conserva marcas en el navegador y permite exportarlas; sus cambios no modifican automáticamente GitHub ni certifican pruebas. El inventario inicial y los documentos describen el estado de esta entrega.
