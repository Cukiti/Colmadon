# Separación de fichas largas — 2026-10-06

**Estado vigente al 7 de octubre de 2026:** código integrado en principal y publicado en GitHub en esta entrega autorizada. Nube y Windows publicados anteriormente; esta entrega integra herramientas del bot y documentación, sin nuevo despliegue ni exportación. APK/Para-amigos pendientes. Véanse [traspaso](TRASPASO_CLAUDE.md) y [tablero](TABLERO_COLMADON.html). Las secciones anteriores conservan resultados históricos.

**Estado vigente al 2026-10-07:** Mejora integrada e incluida en el EXE Windows publicado el 7; casos extremos siguen pendientes. Consulta [traspaso](TRASPASO_CLAUDE.md); el resto conserva el historial.


Continuación autorizada de `tareas_codex/bugs-recorrido.md`, sobre la carpeta principal/master, conservando B01/B02. Cambios locales pendientes de revisión, sin commit, push, despliegue ni exportes.

## Cambio aceptado

Al salir de un doble, una ficha normal podía girar hacia una esquina sin reservar sitio para el doble del nuevo número abierto: la comprobación solo se hacía cuando también había una alternativa recta. Ahora también se hace al salir del doble cuando la recta ya no cabe, siempre que ese próximo doble no se haya jugado. Se mantienen las dimensiones, el hueco nominal y las posiciones/orientaciones de las fichas anteriores.

La mejora es pequeña y medible. Quedan contactos ocasionales y dobles que giran en otras manos extremas; las cifras siguientes son una muestra reproducible, sin garantía sobre todas las partidas posibles.

## Comparación controlada

400 manos completas por semilla, mismas reglas, decisiones de bots y umbrales geométricos antes/después. El test continúa tras un contacto, verifica por separado salidas/solapamientos/contactos y también detecta cambios de orientación. Cuenta una mano con contactos una sola vez. El límite de 300 turnos causa fallo si la mano sigue jugando.

| Semilla | Manos con contacto antes → después | Escalones reales antes → después | Dobles de esquina antes → después |
|---|---:|---:|---:|
| 20261003 | 3 → 3 | 0 → 0 | 3 → 3 |
| 20261004 | 0 → 0 | 0 → 0 | 4 → 4 |
| 20261005 | 4 → 4 | 1 → 0 | 3 → 2 |
| 20261006 | 1 → 0 | 1 → 1 | 2 → 2 |
| 20261007 | 2 → 2 | 0 → 0 | 0 → 0 |
| 20261008 | 0 → 0 | 0 → 0 | 1 → 1 |
| **Total, 2400 manos por versión** | **10 → 9** | **2 → 1** | **13 → 12** |

En todas las filas y ambas versiones: **0 fuera de mesa, 0 montadas y 0 movidas**. La línea más larga fue de 25 fichas.

También se corrigió la medición de escalones: las sondas que buscan dónde dibujar las puntas ejecutaban `_spot_robust()` e incrementaban el contador sin colocar una ficha. Ahora solo lo incrementa `_place_robust()`. La tabla usa esta medición corregida en las dos versiones. La cifra histórica 3 de la semilla 20261006 incluía sondas; su corrección a 1 no se atribuye a una mejora de geometría.

El test de geometría crea la vista sin añadirla al árbol y la libera al acabar. Ya no construye una escena 3D innecesaria ni emite los avisos de recursos Dummy/RID que aparecían al terminar este test. Esto se refiere a esta prueba; no certifica la limpieza de todas las escenas del juego.

Variantes exploradas y retiradas: reserva de salida después del doble (sin mejora), giro anticipado (empeoró contactos y solapamientos), mayor penalización por invadir la otra mitad (sin mejora), preferencia por dobles sin giro y desplazamientos cortos (empeoraron otros indicadores). La reserva en todos los giros provocó un contacto nuevo en la semilla 20261004; se limitó al caso geométrico al salir de un doble y esa regresión desapareció.

## Regresión y vista real

`tests/fixtures/colocacion_esquina.json` conserva los estados reales, en orden, de la mano 315 de la semilla 20261006 hasta el contacto de las 22 fichas. `tests/prueba_colocacion_esquina.gd` los reproduce y comprueba posiciones, orientaciones, bordes, solapamientos, contactos y que volver a consultar las puntas no altere el contador. Con la vista anterior: **1 fallo / salida 1**; con la actual: **0 fallos / salida 0**.

El modo visual dibuja esa secuencia en la mesa real del juego. Capturas inspeccionadas: `capturas/colocacion_esquina.png` y `capturas/colocacion_esquina_arriba.png`, más las dos variantes `_anterior` para comparar. Usa `--prueba-arte` para cargar los perfiles de prueba.

| Antes | Después |
|---|---|
| [Vista desde arriba](../capturas/colocacion_esquina_anterior_arriba.png) | [Vista desde arriba](../capturas/colocacion_esquina_arriba.png) |

```powershell
$godotPruebas = '%USERPROFILE%/AndroidStudioProjects/Godot_4.7.2/Godot_v4.7.2-stable_win64_console.exe'
& $godotPruebas --headless --path . --script res://tests/prueba_colocacion_esquina.gd
& $godotPruebas --path . --resolution 1280x720 --script res://tests/prueba_colocacion_esquina.gd -- --prueba-arte --visual
& $godotPruebas --headless --path . --script res://tests/prueba_colocacion.gd -- --semilla=20261006
# Reproducción rápida de la mano real completa (23 fichas al acabar):
& $godotPruebas --headless --path . --script res://tests/prueba_colocacion.gd -- --semilla=20261006 --mano=315 --diagnostico
```

Para repetir la muestra completa, ejecutar `prueba_colocacion.gd` con las seis semillas de la tabla. `--manos=N` amplía la muestra. `--vista=res://...` permite cargar una implementación anterior para comparar; no cambia la vista del producto. `--guardar-caso=res://...` guarda la secuencia del primer problema para convertirla en una regresión.

Manual: jugar hasta una mano larga, revisar desde arriba el giro después de un doble y comprobar que las fichas ya puestas conservan su posición. Repetir el caso de 22 fichas con el comando visual anterior.

## Alcance de cierre

Verificación final: importación Godot correcta; lógica 300 partidas/989 manos SIN FALLOS; chivo 0 fallos; traducción 494 claves SIN FALLOS; servidor 3000 partidas/10114 manos, sala 142 comprobaciones, paridad 400 estados/1236 jugadas y cuenta SIN FALLOS. Tranque forzado clásico/tienda con estado local/online, vencimiento real de 30 s y salir/reiniciar SIN FALLOS. Autotests gráficos ES [12,113] (3 manos), EN [115,73] (5) y clásico [188,62] (3): PARTIDA TERMINADA, salida 0 y sin SCRIPT ERROR. Regresión de esquina y vista gráfica actual: 0 fallos. `git diff --check` correcto.

B01 y B02 conservan sus correcciones y pruebas documentadas en `pruebas_bugs_recorrido.md`; esta continuación completa la mejora medible pedida para las fichas largas. La publicación, los EXE/APK y una prueba online con humanos reales siguen pendientes. La nube y el servidor local del buscador no se modificaron.
