# Arreglos y pruebas del recorrido — 2026-10-06

**Estado vigente al 7 de octubre de 2026:** código integrado en principal y publicado en GitHub en esta entrega autorizada. Nube y Windows publicados anteriormente; esta entrega integra herramientas del bot y documentación, sin nuevo despliegue ni exportación. APK/Para-amigos pendientes. Véanse [traspaso](TRASPASO_CLAUDE.md) y [tablero](TABLERO_COLMADON.html). Las secciones anteriores conservan resultados históricos.

**Estado vigente al 2026-10-07:** B01/B02 integrados y publicados en servidor/EXE Windows el 7. Pendiente validación manual de tranque/VISTO entre cuatro personas. Consulta [traspaso](TRASPASO_CLAUDE.md); el resto conserva el historial.


Cambios locales sin commit, publicación, despliegue ni exportación. Los ejecutables existentes conservan su versión anterior: estos cambios se prueban con Godot desde el proyecto. Nunca se cierran procesos del usuario ni se borran perfiles.

En PowerShell, desde la carpeta principal:

```powershell
$godotPruebas = '%USERPROFILE%/AndroidStudioProjects/Godot_4.7.2/Godot_v4.7.2-stable_win64_console.exe'
```

## B01 — cierre del tranque

Causa: `_wait_count()` empezaba a esperar la cuenta cuando el aviso de tranque todavía la tenía suspendida. Ahora espera el estado pendiente de tranque antes de iniciar su espera de cuenta. Mostrador, compra, revisión y siguiente mano quedan bloqueados; se libera después de VISTO o de 30 s y del regreso de cámara. Los callbacks se invalidan al abandonar una partida para evitar que aparezcan en la nueva.

Online, VISTO también se acepta en `over` cuando el último resultado es tranque; se reinician las confirmaciones al entrar en ese final. No cambian reglas ni puntos. Esta corrección del servidor aún requiere despliegue autorizado.

```powershell
& $godotPruebas --path . --resolution 1280x720 --script res://tests/prueba_tranque_transicion.gd -- --autotest
& $godotPruebas --path . --resolution 1280x720 --fixed-fps 30 -- --recorrido --escena=clasico --salida-recorrido=res://capturas/auditoria_b01_clasico
& $godotPruebas --path . --resolution 1280x720 --fixed-fps 30 -- --recorrido --escena=mostrador --salida-recorrido=res://capturas/auditoria_b01_mostrador
```

La prueba forzada comprueba clásico/tienda, estado local/online, ausencia de controles de transición durante VISTO, acciones rechazadas, confirmación, vencimiento real de 30 s y salida/reinicio. Las capturas `capturas/tranque_*.png` muestran el panel aislado; son estados preparados. Los dos recorridos terminaron COMPLETADO sin fallos del bot y se inspeccionaron las capturas de transición y mostrador. **En esta ejecución no reprodujeron un tranque**; el caso forzado aporta esa cobertura. El cliente online usa estado preparado; falta una partida real con varios clientes y servidor actualizado.

Manual: provocar un tranque en clásico y con aumentos. Antes de VISTO no deben aparecer Ver la mesa, tienda, mostrador ni SIGUIENTE MANO. Confirmar y comprobar su aparición tras la cuenta; repetir sin pulsar nada durante 30 s, y saliendo al colmado durante el aviso. Online, repetir con dos humanos que confirmen por separado, también cuando el tranque termine la partida.

## B02 — idioma de los botones con iconos

Cada botón conserva su clave española y sus argumentos; la notificación de cambio de idioma vuelve a traducirla y retira los símbolos del texto conservando el icono. Meta conserva 100/200 al cambiar de idioma.

Controles revisados: PARARSE; chat (solo icono); PASO; SIGUIENTE MANO de tienda, clásico y mostrador; botones de tiza creados con `_chalk_button`; Volver a la calle/pizarra; Meta; Nuevo personaje; Añadir canciones. SENTARSE, EMPUJAR, TAPAR/DESTAPAR, RECOGER MIS FICHAS, Ver mesa/Volver y pausa conservan claves originales y traducción automática de Godot. No se traducen nombres de jugadores ni canciones.

```powershell
& $godotPruebas --headless --path . res://tests/prueba_traduccion.tscn
& $godotPruebas --path . --resolution 1280x720 --fixed-fps 30 -- --recorrido --escena=raros --salida-recorrido=res://capturas/auditoria_b02_raros
& $godotPruebas --path . --resolution 1280x720 --script res://tests/autotest_idioma.gd -- --autotest --idioma=es
& $godotPruebas --path . --resolution 1280x720 --script res://tests/autotest_idioma.gd -- --autotest --idioma=en
```

Traducción: 494 claves SIN FALLOS, incluye ida/vuelta ES/EN y Meta 200. La prueba del tranque verifica el botón real PARARSE/STAND UP por notificación. Raros COMPLETADO sin fallos del bot. Los autotests deben imprimir AUTOTEST IDIOMA con el idioma solicitado y PARTIDA TERMINADA sin SCRIPT ERROR. El argumento `--idioma` es del helper, no del juego normal.

Manual: empezar en español, Ajustes → English → volver sin reiniciar, comprobar STAND UP y PASS; regresar a Español y comprobar PARARSE/PASO. Repetir con pizarra Meta 100 y 200.

## Fichas largas — mejora completada en la continuación

La continuación del 2026-10-06 consiguió una reducción medible sin alterar tamaño ni posiciones anteriores: en 2400 manos por versión, contactos 10 → 9, escalones reales 2 → 1 y dobles de esquina 13 → 12; fuera/montadas/movidas 0. Caso real de 22 fichas: vista anterior falla y vista actual pasa. Comandos, capturas y límites actuales en [colocacion_fichas_largas.md](colocacion_fichas_largas.md). Los datos siguientes conservan el primer ensayo, antes de esta continuación.

```powershell
& $godotPruebas --headless --path . --script res://tests/prueba_colocacion.gd -- --semilla=20261006
& $godotPruebas --headless --path . --script res://tests/prueba_colocacion.gd -- --semilla=20261004
```

Ahora la prueba tiene semilla reproducible y devuelve fallo si hay fichas fuera, montadas o movidas. Cuenta avisos de separación aparte.

| Variante, semilla 20261006 (400 manos) | Pegadas | Escalón | Dobles esquina | Fuera / montadas / movidas |
|---|---:|---:|---:|---|
| Original y resultado final | 1 | 3 | 2 | 0 / 0 / 0 |
| Hueco 0,024 y relajación intermedia 0,014 | 1 | 3 | 2 | 0 / 0 / 0 |
| Desplazamientos pequeños antes de relajar; reserva doble con 2 GAP | 1 | 16 | 2 | 0 / 0 / 0 |
| Mayor peso del espacio alcanzable (0,5) | 1 | 3 | 2 | 0 / 0 / 0 |

Se retiraron todas las variantes: no demostraron una mejora. Segunda semilla original 20261004: 0 pegadas, 0 escalones, 4 dobles esquina; 0 fuera/montadas/movidas. Las cifras históricas aproximadas de la tarea (5/13/2) procedían de partidas aleatorias; no sirven como comparación directa. Queda pendiente una búsqueda de colocación que reserve espacio futuro sin mover fichas asentadas ni reducir su tamaño aprobado.

La prueba headless de colocación conserva avisos de liberación del renderizador Dummy/RID al salir, también presentes antes de los cambios; no son fallos geométricos ni SCRIPT ERROR. No se ha corregido esa limpieza.
