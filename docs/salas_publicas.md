# Buscador de salas públicas — 2026-10-06

**Estado vigente al 7 de octubre de 2026:** código integrado en principal y publicado en GitHub en esta entrega autorizada. Nube y Windows publicados anteriormente; esta entrega integra herramientas del bot y documentación, sin nuevo despliegue ni exportación. APK/Para-amigos pendientes. Véanse [traspaso](TRASPASO_CLAUDE.md) y [tablero](TABLERO_COLMADON.html). Las secciones anteriores conservan resultados históricos.

**Estado vigente al 2026-10-07:** Buscador integrado y publicado en nube y Windows; verificado con dos clientes gráficos contra Google Cloud (filtros, refresco, entrada, curso, reconexión, privadas por código). Evidencia: `capturas/recorrido/buscador_nube_20261007/`. Consulta [traspaso](TRASPASO_CLAUDE.md); el resto conserva el historial.


Continuación del commit `d4325d8` en `codex/salas-publicas`, sin commit nuevo, push, fusión, exportación ni despliegue. Carpeta de trabajo: `.trabajo-codex/salas-publicas`.

## Resultado

- Crear sala permite Pública/Privada; privada sigue siendo el valor inicial.
- Buscar salas muestra públicas esperando y en curso. Filtros de modo, meta 100/200, sitio libre y estado; actualización manual y cada cinco segundos. Mantiene los controles cuando la respuesta no cambia.
- En curso aparece deshabilitada: no hay espectadores implementados. El servidor rechaza cuentas nuevas después de empezar, conservando la reconexión de cuentas ya sentadas. No sustituye una silla reservada a alguien desconectado.
- Etiquetas con privacidad, estado, modo, meta, humanos conectados, anfitrión y mano; se actualizan al cambiar esos datos. La RPC comprueba de nuevo privacidad/filtros después del listado y limita a 50 resultados.
- Consultas booleanas de Nakama usan `T`, conforme a [su sintaxis oficial](https://heroiclabs.com/docs/nakama/concepts/multiplayer/query-syntax/). El trabajo pendiente usaba `true` y devolvía una lista vacía pese a tener salas públicas.
- Traducciones españolas/inglesas añadidas al CSV y binarios regenerados. `--local` tiene prioridad sobre servidor.cfg para que una prueba local no termine conectándose a otra dirección.

## Prueba con dos ventanas locales

El servidor local se deja ejecutando con el módulo de esta rama. `arrancar.sh` permite usar los binarios/base local existentes y el módulo de un worktree mediante dos variables opcionales; sin ellas mantiene sus rutas habituales. No editar claves ni archivos de servidor/datos.

```powershell
$env:COLMADON_SERVIDOR_BASE='%USERPROFILE%/AndroidStudioProjects/GodotGames/Colmadon/servidor'
$env:COLMADON_MODULOS='%USERPROFILE%/AndroidStudioProjects/GodotGames/Colmadon/.trabajo-codex/salas-publicas/servidor/modulo/build'
# Desde este worktree; antes compilar: cd servidor/modulo; npm run build
& 'C:/Program Files/Git/bin/bash.exe' servidor/arrancar.sh
```

Abrir dos terminales desde este worktree con una `--sesion` nueva y cuentas de prueba:

```powershell
$godotPruebas='%USERPROFILE%/AndroidStudioProjects/Godot_4.7.2/Godot_v4.7.2-stable_win64_console.exe'
& $godotPruebas --path . --resolution 960x540 --position 0,31 res://tests/prueba_buscador_local.tscn -- --prueba-buscador --local --cuenta=buscador_host7 --rol=host --sesion=salas_nueva
& $godotPruebas --path . --resolution 960x540 --position 960,31 res://tests/prueba_buscador_local.tscn -- --prueba-buscador --local --cuenta=buscador_amigo7 --rol=amigo --sesion=salas_nueva
```

Usar la escena `.tscn`, que carga después del autoload Nakama; no ejecutar su script como SceneTree. Los procesos finalizan solos, tienen límite global de 240 s y esperas de 90 s. La prueba confirma el host local, usa perfiles de cuentas de prueba y sustituye el guardado de última sala para no modificar `ultima_sala.cfg` real. La señal de sala creada espera a que su código se pueda resolver en el índice eventual de Nakama.

Recorrido final `salas_20261006_validado`: ambos procesos código 0, **BUSCADOR LOCAL ... SIN FALLOS**, sin SCRIPT ERROR. Creación pública desde el botón del producto; lista y filtros combinados reales; clic en Entrar; refresco que conserva el botón; pública en curso con entrada deshabilitada; reconexión de cuenta existente; privada ausente del listado y unión por código. Capturas inspeccionadas en `capturas/recorrido/salas_20261006_validado/`: `amigo_lista_publica.png`, `amigo_jugando.png`, `amigo_privada_oculta.png`, `amigo_privada_codigo.png`, `host_publica.png`, `host_privada.png`. Son evidencia local, fuera de git.

Pruebas adicionales: `npm test` (3000 partidas; sala 122 comprobaciones con privacidad, filtros, sintaxis booleana, etiquetas antiguas y entrada; paridad 400 estados/1236 jugadas; cuenta), `npm run build`, importación Godot, traducción 510 claves, lógica 300 partidas/1016 manos y chivo 0 fallos correctos. Autotest gráfico terminó **[102,43], tres manos**, sin SCRIPT ERROR. Healthcheck local HTTP 200. Ninguna prueba ni solicitud del buscador se hizo contra la nube.

Comprobación adicional de colocación sobre esta rama antigua: 400 manos, cero fichas fuera de mesa, montadas o desplazadas; tres contactos, cero escalones y dos dobles en esquina. Código de salida 0, pero emite avisos/errores de recursos del renderizador Dummy al terminar. No se presenta como una prueba limpia ni se corrigió la colocación en esta tarea.

Durante el desarrollo se corrigieron errores del helper: autoload al usar `--script`, búsqueda accidental de botones de una página anterior pendiente de borrado y publicación de códigos antes de indexarse. Se cerraron solo los dos primeros procesos fallidos con autorización explícita; se reinició únicamente el Nakama local con autorización. Los demás tests finalizaron por su propio flujo/límite.

## Integración pendiente

La rama parte de master antiguo: carece, entre otros cambios posteriores, del arte Aseprite aprobado, `OP_TRANQUE_OK` en red.gd y ajustes posteriores de menús/servidor. No se fusionó ni se alteraron B01/B02, colocación, radio, miradas, animación de recoger o las capas de fichas. Al integrar se deben reconciliar `menus.gd`, `red.gd`, `sala.ts` y las traducciones, preservando las correcciones nuevas de master, y repetir las pruebas. La prueba local pasa sobre esta rama; no garantiza una fusión automática sin conflictos ni una prueba móvil.

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
