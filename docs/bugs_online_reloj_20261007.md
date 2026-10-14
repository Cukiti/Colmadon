# Estabilidad online, personajes y avisos — 7 de octubre de 2026

**Estado vigente al 7 de octubre de 2026:** código integrado en principal y publicado en GitHub en esta entrega autorizada. Nube y Windows publicados anteriormente; esta entrega integra herramientas del bot y documentación, sin nuevo despliegue ni exportación. APK/Para-amigos pendientes. Véanse [traspaso](TRASPASO_CLAUDE.md) y [tablero](TABLERO_COLMADON.html). Las secciones anteriores conservan resultados históricos.

La idea central sigue siendo dominó por parejas entre amigos dentro de un colmado compartido: movimientos y gestos visibles en directo, con las reglas de la mesa funcionando de manera coherente. No se ha cambiado el diseño ni las reglas de dominó.

## Fallos confirmados y corregidos (ya integrados y publicados)

| Fallo | Causa y corrección | Evidencia |
|---|---|---|
| Personajes que parpadean, vuelven a su silla o pierden el gesto | `str(cara)` depende del orden de las claves. Nakama entrega diccionarios con órdenes diferentes: `set_seat_look()` destruye y reconstruye al personaje, sus vasos y la asociación con la silla. Se compara JSON con claves ordenadas, conservando el mismo personaje cuando no cambia su aspecto. | Prueba gráfica con diccionarios equivalentes y conservación de identidad/gesto. Tráfico real de cuatro clientes de nube confirma miles de cambios de orden sin cambios cosméticos. |
| «Reloj parado» que desaparece entre actualizaciones | `_refresh()` sustituía el texto completo por su base; `_tick_reloj()` lo completaba después, al procesar otro fotograma. Se compone el aviso completo dentro del refresco y se restaura su color cuando se congela. | Estado repetido deja el mismo texto completo inmediatamente. |
| Ausente que vuelve solo y reinicia su tiempo | El servidor contaba `OP_POSE` y `OP_MANO` como actividad humana. Estando de pie se envían poses incluso quieto. Se excluyen estas operaciones automáticas de la reactivación; `OP_AQUI` y las acciones explícitas siguen devolviendo al jugador. | Regresión de timeout con pose por tick y mano neutra; el bot progresa y no se reinician sus 30 s. |
| Tienda/mostrador: de pie para uno, sentado para los demás | `salaPose()` permitía la tienda, pero `salaLoop()` obligaba a sentarse fuera de play en la misma vuelta. Se conserva la postura también en shop. | Levantarse y caminar en tienda conserva st=1/st=2 en el servidor. |
| Persona de pie tamborileando una mesa que ya no tiene delante | La pensada online se aplicaba por el turno sin comprobar la postura remota. Ahora solo se aplica sentado. | Prueba gráfica: no se inicia tap al estar de pie. |
| «De vuelta» duplicado y cartel de ausente pulsando | `queue_free()` libera al final del fotograma: otra llamada veía el banner válido y repetía el aviso. Se retira la referencia inmediatamente. El aviso de ausencia permanece con opacidad estable. | Dos llamadas antes de liberar generan un solo aviso; opacidad 1. |
| Pide PASO mientras estás de pie | «No llevas» sobrescribía «Siéntate» cuando no había jugada legal. La instrucción de pasar se limita a quien está sentado. | Prueba gráfica con mano sin jugada y jugador de pie conserva «Siéntate». |

## Validación

- Cliente, escena real: versión anterior **7 fallos / salida 1**; corregida **0 fallos / salida 0**. Incluye identidad, gesto, reloj, postura, pensada y ausencia.
- Servidor: antes de corregir **5 fallos nuevos**; corregido npm test: 3000 partidas, sala 850 comprobaciones, paridad 400 estados/1236 jugadas y cuenta sin fallos. Ampliación posterior: **853 comprobaciones de sala sin fallos**, incluidas cuatro personas de pie, 60 s máximos de congelación, vencimiento y juego del bot pese a poses periódicas.
- Lógica Godot y chivo sin fallos. Partida gráfica local terminada **[123, 38], cuatro manos**, salida 0 y sin errores de script.
- Importación y build correctos. Los cambios específicos de producto respecto al principal son `scripts/main.gd` y `servidor/modulo/src/sala.ts`; pruebas añadidas en `tests/prueba_estabilidad_online.gd/.tscn` y `servidor/modulo/tests/sala.test.ts`.

## Observación real y límites

Se inspeccionaron dos capturas de las cuatro ventanas ya abiertas: personajes de pie, estado de la misma mesa desde sus cuatro sillas y avisos de turno/reloj. Se preservaron los cuatro EXE y sus perfiles. Esta sesión no dispone del runtime `node_repl` requerido por Computer Use para enviar entradas nativas; la inspección fue visual y las reproducciones se hicieron con escenas y clientes de prueba. No se presenta como un recorrido manual completo de esas ventanas.

Clientes SDK adicionales recorrieron lobby, reparto, juego, tienda y final contra la nube. Los intentos iniciales generaron acciones duplicadas, avisos de rechazo o agotaron su límite por un error de deduplicación del propio fixture; se conservan como intentos fallidos, separados de las pruebas limpias del producto. No se atribuyen esos rechazos automáticamente a bugs del juego. Confirmaron el problema real del orden de claves en los avatares.

Repetición final del recorrido SDK: **salida 0, PARTIDA TERMINADA [143, 56], tres manos, cero avisos**, fases lobby/draw/play/shop/over. **1198 cambios solo de orden de avatar** durante esa partida. El fixture se corrigió para contar fichas tomadas del pozo y evitar reenviar la misma selección mientras llegaba su confirmación; se retiró el script temporal al terminar.

Las correcciones se desarrollaron en `.trabajo-codex/bugs-online-reloj`, rama `codex/bugs-online-reloj`, a partir del principal más sus cambios locales. El usuario autorizó integrar y publicar con «Esta bien procede». Ya están integradas en principal y desplegadas en Google Cloud; el EXE se exportó y se abrieron cuatro ventanas actualizadas. La copia se conserva como evidencia del desarrollo.

El intento de levantar una instancia adicional local de Nakama salió solo porque PostgreSQL local no estaba disponible. No se arrancó ni modificó `servidor/datos/`; las correcciones del servidor se verificaron con la suite determinista. La repetición contra Google Cloud actualizado se ejecuta con `tests/prueba_estabilidad_nube.tscn`: cuatro cuentas nuevas, congelación real, vencimiento, ausencia, retorno y postura en tienda. Resultado real: **salida 0, 13 comprobaciones, 0 fallos**, sin SCRIPT ERROR/ERROR. Se verificaron los 60 s máximos de congelación, timeout, juego del bot, ausencia persistente pese a pose/mano, OP_AQUI y postura de pie durante tienda.

Pendientes de revisión manual con la versión corregida: levantarse/sentarse simultáneamente desde cuatro ventanas; caminar con colisiones, caídas/manotazos y gestos; mostrador; tranque y VISTO; desconexión/reconexión; partida completa manual y Android físico. No se afirma haber encontrado todos los bugs posibles.

Evidencia de desarrollo en `capturas/recorrido/estabilidad_online_20261007` dentro de `.trabajo-codex/bugs-online-reloj`; capturas de las ventanas existentes en `capturas/recorrido/bugs_online_20261007` del principal. No hay commit ni push.
