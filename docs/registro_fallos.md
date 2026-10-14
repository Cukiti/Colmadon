# Registros de fallos — 2026-10-06

**Estado vigente al 7 de octubre de 2026:** código integrado en principal y publicado en GitHub en esta entrega autorizada. Nube y Windows publicados anteriormente; esta entrega integra herramientas del bot y documentación, sin nuevo despliegue ni exportación. APK/Para-amigos pendientes. Véanse [traspaso](TRASPASO_CLAUDE.md) y [tablero](TABLERO_COLMADON.html). Las secciones anteriores conservan resultados históricos.

**Estado vigente al 2026-10-07:** El EXE Windows publicado el 7 incluye los registros y su interfaz; APK y paquetes Para-amigos siguen anteriores. Falta un registro de cierre real en el equipo de los amigos y validación Android. Consulta [traspaso](TRASPASO_CLAUDE.md); el resto conserva el historial.


Implementado en principal/master, sin commit, publicación, despliegue ni exportación. Los EXE/APK existentes todavía no incluyen este cambio.

## Uso

Después de un cierre inesperado, vuelve a abrir el juego y entra en la radio → Ajustes → **Copiar registro de fallos**. Aparece **Copiado**. Pega el texto para comunicar el problema. Si existe una sesión interrumpida conservada, se copia la más reciente; de lo contrario se copia la sesión actual. El juego no envía registros automáticamente.

En Android se intenta abrir el selector de compartir texto mediante el puente Java integrado de Godot; el contenido también queda en el portapapeles. Sin puente o aplicación receptora, queda la copia. No se añadieron permisos ni plugins. El selector todavía necesita comprobación en un dispositivo Android: no había ninguno conectado.

## Contenido y almacenamiento

- Cabecera: versión de juego/Godot, sistema y versión, modelo, GPU, renderizador, resolución inicial e idioma. Cambios de idioma/resolución se registran como contexto. En headless no hay GPU ni resolución de ventana; el modelo depende de lo que informa el sistema.
- Conexión, desconexión, reconexión, entrada/salida de sala y errores de red; categoría y código numérico, sin cuenta, nombre, código de sala, IP, identificadores ni payload.
- Errores del motor: tipo, categoría, archivo del proyecto, función, línea y hasta doce marcos por pila. No se guardan variables, stdout ni mensajes libres de excepciones. El Logger funciona también desde hilos y vacía el archivo después de cada evento.
- Registro compartible separado del `godot.log` bruto existente: **el botón solo copia el registro saneado**. No copia el log bruto ni volcados nativos.
- Carpeta normal `user://logs/fallos`; en PC está bajo `%APPDATA%\Godot\app_userdata\Colmadón (prototipo 0.1)\logs\fallos`. Archivos `sesion_*.jsonl`, marcas `.jsonl.pendiente` y copias `fallo_*.jsonl`.
- Máximo 256 KiB por registro y 32 KiB por copia. Al recortar conserva cabecera y eventos recientes completos. Retiene cinco sesiones cerradas y cinco copias de interrupciones; conserva sesiones activas. La limpieza solo afecta nombres propios de este registro.

## Recuperación

Cada ventana tiene su propia marca y un puerto reservado en la interfaz local como candado de vida. No acepta conexiones ni transmite contenido. Una nueva ventana conserva las marcas de procesos aún vivos. Cuando el proceso anterior desaparece, copia exactamente su archivo y retira la marca; al salir normalmente se retira la marca propia.

Una interrupción también puede ser un cierre del sistema operativo o una terminación forzada: la marca no demuestra por sí sola un bug. Un fallo previo a arrancar el autoload no queda capturado por este mecanismo. Esta tarea permite obtener evidencia; no identifica todavía la causa del cierre comunicado por los amigos.

## Validación realizada

| Prueba | Resultado |
| --- | --- |
| Importación Godot | Código 0, sin SCRIPT ERROR |
| Registro unitario e integración del adaptador | SIN FALLOS: privacidad, aviso real del motor, señales de socket sin conexión, hilo, límites, retención, sesiones simultáneas y recuperación |
| Cierre brusco real | Solo PID 32552, autorizado por el usuario; reinicio detectó la interrupción y conservó exactamente el log; CIERRE BRUSCO SIN FALLOS |
| Botón y portapapeles | ES/EN, radio apagada/tu música, 640×360 y 1280×720, confirmación de borrar abierta sin ejecutar borrado; REGISTRO UI SIN FALLOS; capturas revisadas |
| Traducciones | 500 claves SIN FALLOS |
| Lógica | 300 partidas, 1028 manos SIN FALLOS |
| Chivo | 0 fallos |
| Colocación | 400 manos, semilla 20261006: fuera/montadas/pegadas/movidas 0; un escalón y dos dobles de esquina del sistema de colocación existente |
| npm test | 3000 partidas/10092 manos; sala 142; paridad 400 estados/1236 jugadas; cuenta SIN FALLOS |
| Autotest gráfico con aumentos | PARTIDA TERMINADA [171,39], cuatro manos; código 0, sin SCRIPT ERROR |
| Autotest gráfico clásico | PARTIDA TERMINADA [63,104], cuatro manos; código 0, sin SCRIPT ERROR |

El test del Logger produce un WARNING controlado con un texto ficticio y comprueba que ese texto no se copia. Las primeras pruebas tuvieron errores del harness corregidos; las ejecuciones fallidas no se cuentan como válidas. La prueba de registro ya puede repetirse en la misma carpeta: comprueba primero la sesión actual y al final la prioridad del fallo simulado anterior.

Evidencia local: `capturas/recorrido/registro_fallos/`, con ocho capturas finales, `cierre_recuperado.jsonl` y `validacion.json`. Los perfiles/ajustes utilizados fueron los de prueba. No se conectó a la nube, no se cambió código del servidor ni se cerró ningún EXE o servicio local.

## Cómo repetir

Usa el ejecutable de Godot indicado en AGENTS.md, desde la raíz:

```powershell
& $godot --headless --path . --import
& $godot --headless --path . res://tests/prueba_registro_fallos.tscn -- --registro-prueba=unidad
& $godot --path . --resolution 640x360 --script res://tests/prueba_registro_ui.gd -- --autotest --registro-prueba=ui640
& $godot --path . --resolution 1280x720 --script res://tests/prueba_registro_ui.gd -- --autotest --registro-prueba=ui1280
& $godot --headless --path . --script res://tests/prueba_traduccion.gd
& $godot --headless --path . --script res://tests/prueba_logica.gd
& $godot --headless --path . --script res://tests/prueba_chivo.gd
& $godot --headless --path . --script res://tests/prueba_colocacion.gd -- --semilla=20261006
& $godot --path . --resolution 1280x720 --fixed-fps 30 --quit-after 36000 -- --autotest
& $godot --path . --resolution 1280x720 --fixed-fps 30 --quit-after 36000 -- --autotest --clasico
```

`npm test` se ejecuta en `servidor/modulo`, conforme a AGENTS.md; solo genera sus salidas de compilación ignoradas.

Para repetir la interrupción, inicia una instancia aislada con `--headless --path . --script res://tests/sesion_registro_fallos.gd -- --registro-prueba=cierre-nuevo`. Anota el PID que imprime y verifica su comando. Con permiso del usuario, termina **solo ese PID**; después arranca el mismo comando añadiendo `--verificar-recuperacion`. Debe imprimir `CIERRE BRUSCO SIN FALLOS`. La fixture tiene salida normal de seguridad a los cinco minutos y no carga perfiles, ajustes ni cuentas. No terminar otras ventanas del juego.

APIs: [Logger de Godot](https://docs.godotengine.org/en/stable/classes/class_logger.html) y [JavaClassWrapper/AndroidRuntime](https://docs.godotengine.org/en/stable/tutorials/platform/android/javaclasswrapper_and_androidruntimeplugin.html).

Commit propuesto: `[Codex] Añade registros de fallos recuperables y copia desde Ajustes`.
