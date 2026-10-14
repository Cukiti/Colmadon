# Reglamento de interacción de Colmadón

Qué tiene que pasar en cada momento del juego. Lo decide el usuario (Claude pregunta, el usuario elige) y el bot lo comprueba: cada regla con **Contrato** está vigilada en cada fotograma por `scripts/auditoria_reglas.gd`. Si se rompe durante unos segundos seguidos, el bot deja un hallazgo `regla_Rxx`, una captura y una línea en `reglas.jsonl`.

Estado de cada regla: **Cumple** (probado), **Por probar** (escrito, sin prueba propia) o **Pendiente** (aún no está así en el juego).

## Fichas

| # | Regla (elegida el 2026-10-13) | Estado | Prueba |
|---|---|---|---|
| F1 | **Modo cámara: mantener y soltar.** Coges la ficha con el clic y, manteniéndolo, apuntas a una punta; al soltar el botón se coloca. Si sueltas fuera de una punta, vuelve a tu mano. Con la tecla E sigue siendo E para coger y E para soltar. Clic derecho la devuelve. | Cumple | `-- --prueba-camara` (jugadas impares con el ratón) |
| F2 | Sin modo cámara: arrastrar y soltar en la punta, o clic en la ficha y clic en la punta. | Cumple | recorrido `partida` |

## Interfaz

| # | Regla (13 oct) | Estado | Contrato / prueba |
|---|---|---|---|
| I1 | **Un panel o botón no cambia de tamaño mientras se ve**: si su texto cambia, el recuadro ya tenía sitio para el más largo; si no cabe, se achica la letra. Pulsar un botón no lo encoge. | Cumple en lo detectado (ver lista en la bitácora) | **R06** (lista en `tamanos.json`) |
| I2 | **Toda espera con segundos enseña la cuenta atrás**: turno, aumentos, tienda, silla, siguiente mano, tranque (girar y entregar) y cuenta de fin de mano. | Cumple | **R07** (tranque); `prueba_accesibilidad` |
| I3 | **Al recoger fichas, la que señalas se levanta, crece y lleva un marco dorado; las que ya cogiste se ven de cara en tu bandeja.** | Cumple | `tests/foto_robar.gd` |

## Tienda, mostrador y aumentos

| # | Regla | Estado | Contrato / prueba |
|---|---|---|---|
| T1 | **Al acabar la tienda, la ventana de aumentos te sale donde estés** (sentado, de pie o en el mostrador). Al elegir sigues donde estabas y vuelves a la silla cuando empieza la mano. | Cumple (arreglado el 13 oct: quedaba escondida al seguir de pie) | **R01**, **R05**; escenas `mostrador_tiempo` y `online_cuatro` (cliente 1 se queda en el mostrador) |
| T2 | **Si se acaba la tienda estando en el mostrador, se cierra sin comprar lo que no confirmaste** y vuelves a tu silla. | Cumple | **R04** |
| T3 | Cualquier ventana con botones deja el ratón libre para pulsarlos. | Cumple | **R02** |

## Turno y mesa

| # | Regla | Estado | Contrato / prueba |
|---|---|---|---|
| J1 | **Chivo: solo lo puede cantar el siguiente jugador, y solo antes de jugar o pasar él.** Después el chivo queda «viejo» y no se canta. | Cumple | `tests/prueba_chivo.gd` (chivo viejo no se canta) |
| J2 | **Si te toca mientras miras la mesa desde arriba, la vista no cambia sola**: sale «¡TE TOCA!» y puedes jugar desde arriba. | Por probar | — |
| J3 | **Pausa (Esc) online solo abre el menú**: la partida sigue para todos y tu reloj corre. | Por probar | — |
| J4 | **El chat no para el reloj**: puedes escribir en tu turno, pero el turno no espera. | Por probar | — |

## Fin de mano y de partida

| # | Regla | Estado | Contrato / prueba |
|---|---|---|---|
| C1 | **Cuenta de fin de mano: el ganador toca las fichas para contarlas; si no las toca, se cuentan solas a los 30 s.** (Los 6 s del tranque son otra cosa: el plazo para entregar las fichas.) | Cumple | recorrido `partida` (cuenta) |
| C4 | **Al empezar la cuenta, todos miran la mesa, pero pueden girar** (clic derecho arrastrado o el ratón en modo cámara). | Cumple (13 oct) | — |
| C5 | **Tranque con tiempo para todo**: 2,5 s entre el turno de revelar de uno y otro, VISTO de los cuatro (o 30 s), 10 s para entregar fichas, el total se ve 3 s antes de la tienda; «Ver la mesa» respeta la línea en bloque y los montones. | Cumple (13 oct) | escena `tranque` |
| C3 | **«Ver la mesa» al acabar la mano enseña la mesa como la dejó lo último que pasó (la cuenta)**: las fichas contadas se quedan en su sitio, sin volver giradas a las bandejas. | Cumple (13 oct) | foto `ver_mesa_tras_cuenta` (recorrido `partida`) |
| C2 | **Fin de partida: la libreta final te sale donde estés** (de pie o en el mostrador), sin volver a la silla. | Por probar | — |

## Bebidas y empujones

| # | Regla | Estado | Contrato / prueba |
|---|---|---|---|
| B1 | **Las bebidas solo se toman en tu turno, antes de jugar**, tocando el vaso; el efecto se aplica a esa jugada. | Cumple | recorrido `mostrador` (beber tocando el vaso) |
| E1 | **Empujones y manotazos solo a quien está de pie**: a los sentados no se les empuja ni se les tumba; el manotazo sienta al que está de pie. | Por probar | — |

## Tiempo

| # | Regla | Estado | Contrato / prueba |
|---|---|---|---|
| H1 | **Si se acaba el tiempo de una elección (aumento, tienda, VISTO), el juego elige lo más sensato** (en la tienda, nada) **y te avisa** de lo que eligió. | Por probar | — |
| H2 | **Si se acaban los 30 s de tu turno, juega tu bot** (la mejor ficha, o pasa si no llevas) con aviso «Jugó por ti». Tras 2 seguidos quedas «ausente» (turnos de 5 s) hasta que tocas la pantalla o mueves el mouse. | Por probar | — |

## De pie

| # | Regla | Estado | Contrato / prueba |
|---|---|---|---|
| P1 | **Te puedes parar en tu turno**: las fichas van escondidas, tu reloj sigue corriendo y tienes que sentarte para jugar. | Cumple | recorrido `de_pie` |
| P3 | **Lejos de tu silla, Espacio/E no te sienta: sale el aviso «Vuelve a tu silla para sentarte»** (también con la pistola en la mano). | Cumple (13 oct) | explorador (`armado_no_se_sienta` pasa a ser esperado) |
| P2 | **En el tranque nadie se queda de pie**: el colmadero te sienta y ves la revelación como todos. | Por probar | **R03** |

## Sala de espera

| # | Regla | Estado | Contrato / prueba |
|---|---|---|---|
| S4 | **Cambiar de silla no quita el LISTO; el nombre es del equipo**: quien llega a un equipo toma su nombre (no se borra). Solo se reinicia una propuesta a medias si quien la hizo se fue. | Cumple (13 oct, servidor) | `npm test` (sala) |
| S5 | **Los dos equipos no pueden llamarse igual**: el ✓ no envía y sale «Ese nombre ya lo tienen los rivales» (el servidor también lo rechaza). | Cumple (13 oct) | — |
| S1 | **Si el anfitrión se va antes de empezar, pasa a ser anfitrión el siguiente que llegó**, con aviso a todos. | Por probar | — |
| S2 | **Si pides una silla y no responden en 15 s, se rechaza sola** («No respondió a tiempo») y sigues en tu silla. | Cumple | `online_cuatro` (cambio de silla) |
| S3 | **La partida la empieza el anfitrión con ¡A JUGAR!**, que se habilita cuando todos están LISTO. | Cumple | `online_cuatro` |

## Red

| # | Regla | Estado | Contrato / prueba |
|---|---|---|---|
| N1 | **Si alguien se desconecta, un bot juega por él** con su nombre «(ausente)» y le guarda la silla; si vuelve, recupera su silla y sus fichas en el punto en que va la partida. | Por probar | — |
| N2 | Los 4 clientes están en la misma fase que el servidor (como mucho 2 s de diferencia). | Pendiente | contrato entre clientes (siguiente paso) |

## Mesa y fichas como objetos (elegido 2026-10-13)

| # | Regla | Estado | Contrato / prueba |
|---|---|---|---|
| F10 | **Reacomodar tu mano arrastrando**: mantienes el clic en tu ficha, se levanta, la mueves entre las otras (se apartan) y al soltar baja a su hueco. Online y sin conexión; los demás ven tu mano moverse, nunca las caras. | Cumple (13 oct; servidor reenvía el gesto fuera de turno) | `tests/foto_verificar.gd`, `npm test` (sala) |
| F11 | **Las fichas tienen peso al soltarlas**: caen, rebotan un poco y suenan; al final quedan alineadas exactas en la línea. | Cumple (13 oct) | autotest |
| F12 | **La mesa reacciona**: golpes, empujones y el chivo la hacen temblar y mueven un poco las fichas sueltas (no las de la línea). | Cumple (13 oct; golpe, chivo cantado y dominó) | autotest |
| F13 | **Contar a mano**: en la cuenta puedes coger y voltear fichas para contarlas tú. | Cumple (13 oct): llegan boca abajo y quien cuenta las coge y voltea; los demás pueden coger una para mirarla (solo en su pantalla) | `tests/foto_verificar.gd` |
| V1 | **Verificar tranque, capicúa y dominada**: al cerrarse la mano se para todo, se resalta lo que la cierra (puntas, fichas que trancan) y cada jugador pulsa VISTO ✓ o RECLAMAR, con reloj visible y tiempo máximo. | Cumple en dominó y capicúa (13 oct, servidor `OP_VERIFICAR` 43, 20 s; RECLAMAR: el colmadero repite la prueba); el tranque ya tenía su VISTO | `npm test` (sala), `tests/foto_verificar.gd` |
| T6 | **El marcador no suma el tranque hasta que se cierra su pantalla** (revelar, VISTO, entregar y el total): ahí se suman los puntos. Elegido el 13 oct. | Cumple (13 oct) | escena `tranque` (`tranque_marcador_hasta_el_final`, `tranque_marcador_suma_al_cerrar`) |
| I9 | **Ningún texto ni objeto se monta sobre otro en la sala con amigos** (barrido completo antes de lo demás). | Cumple en lo que ve el bot (13 oct): detector `texto_tapa_cara` y foto de cada solape (`auditoria_visual.gd`); quedan avisos de libreta inclinada y de transiciones, revisados a mano y aceptados | auditoría espacial online |

## Cómo seguir

- **Bug que no está en el reglamento** (elegido el 2026-10-13): Claude enseña la captura, propone opciones y pregunta; lo elegido se añade aquí y al bot antes de arreglarlo.

- Cada bug nuevo que encuentres jugando: primero se decide la regla aquí (si no estaba), después se convierte en contrato y por último se arregla. Así el bot no vuelve a dejarlo pasar.
- Siguiente paso del bot: comparar las fases de los 4 clientes (N2) y un explorador que provoque a propósito las combinaciones raras (estar de pie o en el mostrador justo cuando cambia la fase, perder la conexión en cada fase).
