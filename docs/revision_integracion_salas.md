# Revisión de integración del buscador — 2026-10-06

**Estado vigente al 7 de octubre de 2026:** código integrado en principal y publicado en GitHub en esta entrega autorizada. Nube y Windows publicados anteriormente; esta entrega integra herramientas del bot y documentación, sin nuevo despliegue ni exportación. APK/Para-amigos pendientes. Véanse [traspaso](TRASPASO_CLAUDE.md) y [tablero](TABLERO_COLMADON.html). Las secciones anteriores conservan resultados históricos.

**Estado vigente al 2026-10-07:** Integración y publicación completadas; buscador verificado con dos clientes gráficos contra Google Cloud. Las referencias siguientes a integración/despliegue pendientes describen etapas anteriores. Consulta [traspaso](TRASPASO_CLAUDE.md); el resto conserva el historial.


Las seis tareas de `docs/tareas_codex` tienen implementación terminada. El buscador está completado y probado en `.trabajo-codex/salas-publicas`, rama `codex/salas-publicas`; su bitácora y `docs/salas_publicas.md` ya documentaban el resultado. Faltaba reflejar ese estado en la carpeta principal. La integración sigue pendiente.

## Comparación realizada

Se compararon los archivos actuales, incluidos los cambios **sin commit** de ambas carpetas, contra el ancestro común `4b9f04981a85410eed6223e8e534b55ad56ad7ab`. Se usó `git merge-file -p` sobre copias de texto en QA, normalizando finales de línea. Esto genera una vista previa y no cambia ninguna rama ni archivo del juego. No se ejecutó `git merge`, no se fusionó ni se publicó.

| Archivo | Resultado textual de la vista previa |
|---|---|
| scripts/menus.gd | Sin conflictos |
| scripts/red.gd | Sin conflictos |
| servidor/modulo/src/sala.ts | Sin conflictos |
| servidor/modulo/src/main.ts | Sin conflictos |
| servidor/modulo/tests/sala.test.ts | Un bloque de conflicto al añadir pruebas al final |
| translations/textos.csv | Un bloque de conflicto al añadir traducciones al final |
| servidor/arrancar.sh | Sin conflictos |

La normalización es necesaria: una primera comparación con finales de línea distintos marcaba archivos completos como conflictos. Esos falsos conflictos se descartaron. Evidencia final en `capturas/recorrido/integracion_salas/comparacion.json` y vistas previas.

## Resolución concreta para la integración

- Conservar las pruebas nuevas de ambas versiones: B01/VISTO, validación y límites del servidor, privacidad, filtros y entrada en salas. No sustituir la suite actual por la de la rama antigua.
- Conservar las traducciones actuales y añadir las **20 claves exclusivas** del buscador. Hay **11 claves compartidas con traducciones diferentes** en la rama antigua; mantener las revisadas de principal. La comparación de claves también normaliza saltos de línea. Regenerar ambos `.translation` después de resolver el CSV; no copiar los binarios antiguos.
- La vista previa conserva `OP_TRANQUE_OK`, los registros de fallos, el panel de accesibilidad y la validación/límites del servidor junto con `rpcListarSalas`. Esto es una comprobación textual, no prueba de ejecución.
- Incorporar también `tests/prueba_buscador_local.gd`, su escena y el informe del buscador, que siguen sin commit en su carpeta. No copiar `.npm-cache`, builds ni archivos completos de la rama antigua sobre principal: faltan arte Aseprite y cambios recientes.
- Probar el buscador con los tres tamaños de texto, especialmente los filtros y las filas de salas, porque sus pantallas se construyeron antes de la accesibilidad.
- El servidor local documentado en la tarea carga el módulo de la rama antigua. Verificar qué proceso/módulo está activo antes de cualquier recarga; pedir permiso para reiniciarlo si hace falta. Nunca usar la nube para estas pruebas ni cerrar ventanas del usuario.

## Validación que falta tras integrar

Importación; lógica, chivo, colocación y traducción; `npm test` con las dos familias de pruebas; autotest gráfico en ambos modos; dos clientes contra Nakama local para pública visible/entrada, privada oculta/entrada por código, filtros, refresco, partida empezada y reconexión. Repetir capturas del buscador ES/EN con Normal/Grande/Muy grande y comprobar B01/VISTO y registros sin regresiones.

En esta revisión no se repitieron pruebas de ejecución: no hubo cambios de código ni una versión integrada. Las pruebas anteriores del buscador siguen siendo evidencia de su rama, no de principal.

La tarea original indica: **«Si al probar choca con lo que ya hay en master, avísalo en el resumen; no fusiones tú»**. La integración requiere autorización expresa para sustituir esa restricción. No se cambiaron ESTADO.md, código, perfiles, servidor, nube ni exportes.

Commit propuesto para esta documentación: `[Codex] Documenta el estado del buscador y su revisión de integración`.

## Integración en principal/master — 2026-10-06

El usuario autorizó expresamente integrar con «Procede». Se incorporó el código actual (incluidos cambios sin commit) de codex/salas-publicas mediante comparación a tres bandas normalizada. Se conservaron accesibilidad, registros, OP_TRANQUE_OK, validación y límites del servidor, arte y cambios previos. Los dos conflictos de pruebas y traducciones se resolvieron conservando ambas suites y todas las traducciones de principal; se añadieron 20 claves y se regeneraron los binarios. No hubo commit, push, nube ni exportes.

Validación de la versión integrada:
- Importación correcta; traducción 538 claves SIN FALLOS.
- Lógica: 300 partidas/1015 manos SIN FALLOS; chivo: 0 fallos.
- Colocación: 400 manos/semilla 20261006; fuera, montadas, pegadas y movidas: 0. Se conservan un escalón y dos dobles de esquina previamente documentados.
- npm test: 3000 partidas/10080 manos; sala 838 comprobaciones; paridad 400 estados/1236 jugadas; cuenta SIN FALLOS. npm run build correcto.
- Autotest gráfico aumentos [0,198], tres manos; clásico [120,0], dos manos. Ambos código 0, PARTIDA TERMINADA y sin SCRIPT ERROR.
- B01/VISTO: transición correcta en clásico/colmado, local/estado online simulado. Registros SIN FALLOS en carpeta exclusiva --registro-prueba=integracion_salas_0610_registro (el WARNING controlado es parte del test).
- Nueva escena tests/prueba_buscador_ui.tscn: datos simulados sin red, 12 salas, nombres largos, espera/en curso; ES/EN, los tres tamaños, 640x360 y 1280x720: 0 fallos de geometría. Capturas de principal revisadas; los controles fijos y las filas caben horizontalmente, con desplazamiento vertical y nombres elididos. Esta auditoría no prueba conexión ni detecta todo posible solapamiento.

Pendiente imprescindible: repetir la escena de dos clientes tests/prueba_buscador_local.tscn contra el módulo integrado. Nakama PID 12792 sigue cargando .trabajo-codex/salas-publicas/servidor/modulo/build; healthcheck local HTTP 200. El usuario autorizó reiniciar únicamente ese proceso, pero la revisión automática rechazó el comando antes de ejecutarlo con «blocked by policy», sin más explicación. No se reintentó ni se cerró el servidor. Ninguna petición de esta validación se hizo a la nube; el healthcheck 200 corresponde al módulo anterior y no valida la integración online.

Errores de preparación separados: primer fixture UI se lanzó como --script y falló por autoload; traducir también requiere escena. Se corrigieron los comandos y el fixture UI. Solo los procesos de prueba 21952/15576 y 24224/42116 se cerraron, con permiso específico. Una primera prueba de registros usó carpeta general compartida y falló la retención; repetida aislada pasó. Evidencia y logs de intentos fallidos y finales en capturas/recorrido/integracion_salas, ignorados por git.

Para la UI aislada:
```powershell
& '%USERPROFILE%/AndroidStudioProjects/Godot_4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path . --resolution 1280x720 res://tests/prueba_buscador_ui.tscn -- --autotest
```
Para el recorrido local real, tras recargar de forma autorizada el servidor con servidor/modulo/build, utilizar los dos comandos del informe con una sesión y cuentas nuevas. No ejecutar arrancar.sh parar: termina instancias por nombre y excedería el permiso específico. No se presenta la tarea como completamente validada en principal hasta esa repetición.

Commit propuesto: `[Codex] Integra el buscador de salas públicas conservando las mejoras actuales`.
## Validación local integrada completada — 2026-10-06

Se completó el recorrido pendiente en principal/master con dos clientes gráficos reales. Para conservar el servidor anterior y evitar el reinicio bloqueado se creó otra instancia local: Nakama PID 30300, HTTP/WebSocket 127.0.0.1:7460, consola 127.0.0.1:7461, módulo servidor/modulo/build de principal. Archivos de esta instancia en capturas/recorrido/integracion_salas_local_20261006; PostgreSQL local existente, cuentas nuevas de prueba. No se leyeron/modificaron claves de servidor/datos/, no se cambió servidor.cfg ni el código de conexión de producción.

El fixture tests/prueba_buscador_local.gd admite --puerto-local-prueba=7460 únicamente en su subclase de pruebas, con loopback y clave local fijos. Conserva --local, perfiles de prueba y desactiva persistencia de última sala. La instancia inicial salió sola por nombre mayor de 16 caracteres; se corrigió. Un comando conjunto de consulta/lanzamiento fue bloqueado automáticamente antes de ejecutarse; tras confirmar HTTP 200 se ejecutaron los dos comandos individuales de prueba, con límite global de 240 s. Ningún proceso del servidor anterior fue cerrado.

Resultados: ambos procesos código 0, BUSCADOR LOCAL host/amigo SIN FALLOS, sin SCRIPT ERROR. Pública creada desde interfaz, visible y accesible por clic; filtros combinados/excluyentes; refresco conserva el mismo botón; sala en curso deshabilitada; reconexión de cuenta previamente sentada; privada ausente del listado y accesible por código. Capturas de pública, en curso y privada revisadas visualmente. Healthcheck de la instancia integrada HTTP 200. Evidencia en capturas/recorrido/integracion_salas_local_20261006 y validacion.json.

La implementación e integración quedan completadas y validadas localmente; este resultado sustituye el pendiente de recorrido anotado anteriormente. Permanecen los límites de alcance: sin nube, publicación, exportación, móvil físico ni prueba de carga de más de 50 salas. Los EXE/APK y servidor habitual continúan con su versión anterior. Cambios sin commit, sin push.

Reproducción: utilizar los dos comandos de tests/prueba_buscador_local.tscn del informe, añadir --puerto-local-prueba=7460 y usar cuentas/sesión nuevas, con un servidor local cargando el módulo integrado en ese puerto. No usar señales de una sesión anterior. La primera validación automática de interfaz/reglas/B01/registros y las partidas completas siguen documentadas arriba.
