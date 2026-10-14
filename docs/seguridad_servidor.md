# Revisión de mensajes del servidor — 2026-10-06

**Estado vigente al 7 de octubre de 2026:** código integrado en principal y publicado en GitHub en esta entrega autorizada. Nube y Windows publicados anteriormente; esta entrega integra herramientas del bot y documentación, sin nuevo despliegue ni exportación. APK/Para-amigos pendientes. Véanse [traspaso](TRASPASO_CLAUDE.md) y [tablero](TABLERO_COLMADON.html). Las secciones anteriores conservan resultados históricos.

**Estado vigente al 2026-10-07:** Blindaje incluido en el servidor publicado el 7. Suite actual: 853 comprobaciones de sala; estabilidad real de nube 13/13. Las 18 comprobaciones de blindaje anteriores fueron locales y no se presentan como repetidas en nube. Carga sostenida y física autoritativa completa siguen pendientes. Consulta [traspaso](TRASPASO_CLAUDE.md); el resto conserva el historial.


Tarea `servidor-blindaje.md`, en la carpeta principal/master autorizada por el usuario. Cambios exclusivamente de esta tarea en `servidor/modulo/src/sala.ts`, `servidor/modulo/tests/sala.test.ts` y documentación. Los cambios anteriores de B01/B02 quedan conservados. Sin commit, push, despliegue, reinicio del servidor local ni cambios de claves, exportes, menús o buscador de salas.

## Fallos reproducidos y correcciones

La primera ejecución de las pruebas nuevas produjo **11 comprobaciones fallidas**. No son once causas independientes: incluyen dos variantes de índice de robo y dos variantes de pose. Después se añadieron y reprodujeron **dos fallos adicionales** del emote `shove`.

### Graves: caída, corrupción, suplantación o ventaja indebida

- `OP_PERFIL` con JSON `null` accedía a `d.name` y lanzaba una excepción fuera del manejador: Nakama podía cerrar la sala. Ahora todo mensaje requiere un objeto JSON y campos válidos antes de ejecutarse. JSON roto se descarta; antes se convertía en `{}` y podía ejecutar `OP_EMPEZAR`.
- Se identificaba al actor solo por `userId`. Una presencia anterior de la misma cuenta podía seguir actuando después de reconectar. Ahora también debe coincidir el `sessionId` de la presencia actual; un usuario ajeno o desconectado tampoco actúa. La silla siempre sale de esa presencia; cualquier campo `seat` enviado por el cliente se ignora.
- `OP_ROBAR` aceptaba `0.5` y lo guardaba en `pool_taken`, causando un reparto incoherente; también convertía texto a índice. Ahora solo admite números enteros 0–27. Fichas son arrays exactos de dos enteros 0–6 y lados son enteros -1/0/1: sin conversión de texto, null, booleanos, fracciones, NaN o Infinity.
- Una pose incompleta `st:2` modificaba la postura antes de validar coordenadas. Además, se podía saltar directamente de sentado a de pie, con `desde:0`, evitando el tiempo mínimo para ver fichas ajenas. Ahora se valida el paquete entero y se exige pasar primero por levantarse; el inicio de esa transición lo fija el servidor.
- El emote antiguo `shove` con objetivo aplicaba empuje en el cliente aunque el objetivo estuviera sentado o lejos. Ahora pasa por `salaGolpe`: valida fase, distancia, objetivo humano de pie, cooldown, caída y abuso, y emite el evento autoritativo `golpe`. Sin objetivo sigue siendo una animación cosmética.
- Las acciones del turno enviadas mientras el actor está levantado o caído se rechazan. Esto refuerza en el servidor la decisión ya vigente del diseño y del cliente: para jugar hay que estar sentado. No cambian reglas de dominó, puntos, bebidas ni bots; no fue necesario modificar `reglas.ts` o `game.gd`.

### Abuso de tráfico y problemas menores

- Cientos de `OP_MANO` generaban cientos de retransmisiones. Se añaden contadores por silla y tick **antes de decodificar/parsear**; también consumen cupo los mensajes inválidos o desconocidos. Máximo total 12 por tick (60/s a cinco ticks/s); pose y mano dos por tick (10/s), perfil y tapar uno por tick (5/s), otras operaciones ocho por tick. Emotes conservan un máximo de uno/s, frases válidas una/3 s y golpes uno/2 s. Los excesos se ignoran sin expulsar ni responder, y no consumen el cupo de otra silla.
- Mensajes de más de 2048 bytes binarios se descartan antes de convertir a texto, y también hay un límite de 2048 unidades de texto antes del JSON. Los strings de la simulación no representan un paquete binario: en Nakama real la comprobación de bytes precede a la de texto.
- Perfil reenviaba cualquier objeto como avatar, incluida información ajena al aspecto del personaje. Ahora solo conserva los campos que entiende `look_de_json`: cuatro colores hexadecimales, textos cosméticos cortos/booleanos y barba/bigote booleanos. Campos desconocidos o anidados se omiten; nombre sigue limitado a 16 caracteres y se rechazan entradas de nombre excesivas.
- Operaciones desconocidas o de salida no reactivan al ausente. Mensajes con forma válida siguen demostrando actividad, conforme al comportamiento existente, aunque una acción no proceda por turno/fase.
- Errores inesperados del manejador se contienen con un aviso fijo sin copiar el payload. La prueba inyecta un fallo de decodificación y otro de envío durante un manejador y confirma que `matchLoop` retorna. Esto no garantiza recuperación de fallos internos de Nakama, falta de memoria o un estado almacenado ya corrupto.

## Operaciones revisadas

Todos los mensajes entrantes requieren presencia actual, cupo, tamaño y objeto JSON válido. Los campos adicionales no eligen actor ni se mezclan con el estado del servidor.

| Operación | Contrato y comprobación |
| --- | --- |
| 1 PERFIL | Nombre de texto acotado; avatar null/objeto saneado; únicamente silla propia |
| 2 EMPEZAR | Solo anfitrión, antes de tener partida; JSON roto nunca equivale a petición vacía |
| 10 CARTA | ID de texto corto; fase pick, oferta de la silla y elección única en reglas |
| 11 ROBAR | Entero 0–27, fase draw, ficha libre y máximo siete por silla |
| 12 JUGAR | Ficha válida que pertenece a su mano, lado válido, turno/fase/revisión y actor sentado; chivo intencional conserva sus reglas |
| 13 PASAR | Actor sentado, fase/turno y legalidad del pase en reglas |
| 14 PASAR_CON_FICHA | Actor sentado, jugadas disponibles y reglas de renuncio; no se elimina el renuncio deliberado |
| 15 CANTAR | Actor sentado, turno play y sin revisión abierta; reglas del chivo/UTE VA |
| 16 BEBER | Bebida conocida y pose válida; reglas exigen propiedad, turno, play y ausencia de revisión |
| 17 COMPRAR | Bebida de catálogo propio, fase shop, monedas y límite de inventario; IDs heredados como constructor/__proto__ rechazados |
| 18 LISTO | Solo shop y voto de la silla autenticada |
| 19 REVANCHA | Solo over y voto de la silla autenticada; repetición no duplica votos |
| 20 FRASE | Texto corto que identifica frase cerrada; no texto libre; ID inexistente conserva aviso limitado al emisor |
| 21 POSE | Estado entero 0/1/2; números reales finitos y acotados; transformación por silla y recorte a paredes; no salto directo sentado→de pie |
| 22 EMOTE | Lista cerrada; objetivo entero 1–3 o sentinel -1/0; punto con dos coordenadas finitas acotadas; shove con objetivo usa golpe |
| 23 TAPAR | on booleano real, solo su propia mano |
| 24 MANO | Estado entero 0–3, lado entero -1/0/1; fuera de turno/fase envía estado neutral; solo animación, ninguna ficha |
| 25 AQUI | Petición de actividad de la presencia actual; limitada igual que el resto |
| 26 REVISAR | none:true sin tile, o ficha válida; reglas validan acusador, mano acusada y resolución verdadera; actor sentado |
| 27 GOLPE | Objetivo entero 1–3, run booleano opcional; play/shop, distancia ≤1 m, ambos de pie, objetivo humano conectado, cooldown y caída; abuso sienta al atacante |
| 28 TRANQUE_OK | Solo shop/over tras tranque real, voto propio; arreglo B01 anterior conservado |
| 100–104 SALA/ESTADO/AVISO/POSES/MANOS | Son de salida; un cliente no puede ejecutar ninguno de ellos |

## Información oculta

Se revisaron `salaVista`, `salaEventosGirados` y `salaMano`. `OP_ESTADO` se emite por destinatario: mano propia visible, otras fichas null. No contiene `pool`. Las ofertas son únicamente las propias; el dueño de cada índice tomado es público, pero no su ficha.

Las excepciones previstas por el juego se mantienen: fichas ya reveladas, bebida que permite ver al compañero, revisión solo para su acusador, mirar desde detrás de alguien que no tapó y revelación al finalizar la mano. El evento `chivo_false.hand` se elimina para quien no acusó. `OP_MANOS` lleva solo seat/st/side y se gira para cada receptor; no contiene manos reales. Las pruebas comprueban las cuatro rotaciones y las excepciones de revisión/bebida/fin de mano.

`reglas.ts` conserva las comprobaciones de propiedad, turno, fase, ofertas, dinero y revisión. `cuenta.ts` borra exclusivamente el `ctx.userId` de la sesión, ignora el ID del payload y rechaza llamadas sin sesión; su suite existente continúa pasando. Los RPC de creación/búsqueda y la protección de transporte de Nakama no se modifican en esta tarea.

## Validación y reproducción

- `npm test`: **818 comprobaciones de sala SIN FALLOS**, 3000 partidas/10030 manos de reglas, paridad 400 estados/1236 jugadas y cuenta SIN FALLOS. Incluye matriz de raíces inválidas para todas las operaciones, campos faltantes/tipos/rangos, inundaciones de 500 mensajes, independencia de jugadores, presencia vieja, silla ajena, posición, golpe y ocultación. Fallos de pruebas anteriores al arreglo conservados como evidencia; no se contaron como correctos.
- `npm run build`: código 0.
- `prueba_logica.gd`: 300 partidas/1012 manos SIN FALLOS.
- `prueba_chivo.gd`: 0 fallos.
- `prueba_colocacion.gd`, semilla 20261006: 400 manos, fuera/montadas/pegadas/movidas 0; un escalón/dos dobles de esquina existentes, sin cambios de geometría.
- Autotest con ventana, aumentos: `PARTIDA TERMINADA [105,0]`, dos manos, código 0/sin SCRIPT ERROR. El autotest local verifica regresión del cliente; no sustituye una partida online con servidor real.
- Autotest con ventana, clásico: `PARTIDA TERMINADA [112,0]`, dos manos, código 0/sin SCRIPT ERROR.

Repetir en `servidor/modulo`: `npm test` y `npm run build`. Desde la raíz, usar los comandos de lógica, chivo y colocación de AGENTS.md y ejecutar Godot **con ventana** con `--path . --resolution 1280x720 --fixed-fps 30 --quit-after 36000 -- --autotest` (también `--clasico`). Se usan perfiles/ajustes de prueba. Evidencia local consolidada en `capturas/recorrido/blindaje_servidor/validacion.json`; logs temporales propios se retiran al terminar.

## Límites

La simulación cubre el módulo autoritativo, sin desplegar ni recargar el servicio local en uso. Falta validación online con clientes reales después de que se autorice integrar y desplegar. La posición dentro de las paredes sigue siendo comunicada por el cliente: no se añadió física autoritativa completa, comprobación de velocidad ni colisiones de todos los muebles; distancia y miradas se calculan sobre las poses aceptadas. El flag run continúa siendo comunicado por el cliente y determina el tipo de caída de un golpe que ya superó las comprobaciones. Los límites del módulo reducen el trabajo de decodificación y la amplificación, pero no son un filtro de tráfico en la red ni una cuota de RPC de Nakama.

Commit propuesto: `[Codex] Blinda los mensajes de sala y limita el abuso de clientes`.

## Integración con Nakama real — 2026-10-06

Pendiente de integración del blindaje comprobado en principal/master mediante tests/prueba_blindaje_local.gd y su escena. Instancia propia 127.0.0.1:7460, módulo integrado; servidor habitual conservado. Dos clientes SDK reales, cuentas efímeras nuevas, sin Main, perfiles, ultima_sala ni datos del jugador. Límite global 75 s. No se modificó código de producción ni servidor/modulo/build durante esta prueba.

Resultado final: **18 comprobaciones SIN FALLOS**, código 0 y sin SCRIPT ERROR/ERROR. Matriz de 162 entradas (27 operaciones × seis raíces inválidas), payload de 10 KB y ráfaga acotada de 200 poses inválidas/operaciones desconocidas; la sala sobrevive. El transporte desconecta el cliente que manda el payload enorme; reconexión correcta, compañero continúa, anfitrión activo conserva capacidad de iniciar. Perfil válido funciona tras la basura y elimina campos de avatar arbitrarios. Partida iniciada y reparto completado realmente; ambos clientes ven su mano no vacía, las manos restantes ocultas y ninguna propiedad pool. Healthcheck posterior HTTP 200.

Intentos iniciales fallidos conservados separadamente: fixture enviaba por socket ya cerrado, esperaba un nombre mayor del máximo de 16 caracteres, iniciaba con el antiguo host y auditaba manos antes de terminar el reparto. Se corrigieron esas expectativas; no se cambiaron reglas ni servidor. Todos los procesos de este fixture terminaron solos (flujo, límite de frames/tiempo); no se cerraron procesos ajenos. Evidencia final: capturas/recorrido/integracion_salas_local_20261006/blindaje_real_completo.log y blindaje_validacion.json. Los intentos anteriores no cuentan como pruebas aprobadas.

```powershell
& '%USERPROFILE%/AndroidStudioProjects/Godot_4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path . res://tests/prueba_blindaje_local.tscn -- --prueba-blindaje --local --registro-prueba=blindaje_nueva_sesion
```

Requiere una instancia local propia en 7460 con el módulo integrado. La cuota exacta por silla/tick, sesiones viejas, reglas y todos los casos de golpe/posición siguen cubiertos por la suite determinista de sala; este recorrido real complementa esa evidencia, no prueba todas las condiciones bajo carga. Sin nube, prueba de carga sostenida, protección absoluta de infraestructura ni física autoritativa completa. Sin commit/push, despliegue o exportes; instancia temporal PID 30300 sigue abierta hasta permiso específico de cierre.
