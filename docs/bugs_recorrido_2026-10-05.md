# Bugs del recorrido — 2026-10-05

**Estado vigente al 7 de octubre de 2026:** código integrado en principal y publicado en GitHub en esta entrega autorizada. Nube y Windows publicados anteriormente; esta entrega integra herramientas del bot y documentación, sin nuevo despliegue ni exportación. APK/Para-amigos pendientes. Véanse [traspaso](TRASPASO_CLAUDE.md) y [tablero](TABLERO_COLMADON.html). Las secciones anteriores conservan resultados históricos.

**Estado vigente al 2026-10-07:** B01/B02 corregidos e integrados; servidor y EXE Windows publicados el 7. Este documento conserva el diagnóstico original; evidencia actual en `pruebas_bugs_recorrido.md`. Consulta [traspaso](TRASPASO_CLAUDE.md); el resto conserva el historial.


Estado al 2026-10-06: **B01 y B02 corregidos en código local, sin commit/despliegue/exportes**. Reproducciones originales conservadas debajo. Pruebas y límites: [instrucciones de validación](pruebas_bugs_recorrido.md). La continuación de fichas largas logró una mejora medible en 2400 manos: contactos 10 → 9, escalones reales 2 → 1, dobles de esquina 13 → 12; fuera/montadas/movidas siempre 0. Quedan casos extremos: [comparación y reproducción](colocacion_fichas_largas.md).

Se ejecutaron siete escenas locales con los cambios actuales en la copia de trabajo `codex/fello-alta-resolucion`. Las siete terminaron con código 0 y marca FIN. Grabación a 1280×720, 30 fps fijos: **19.370 fotogramas, 10 min 45,66 s**. Se analizaron todos los fotogramas mediante el detector de oscilaciones a 320×180; se inspeccionaron capturas de eventos y las ventanas señaladas. Esto no equivale a una revisión humana individual de cada fotograma ni garantiza encontrar todos los bugs.

## B01 · P2 · La transición entre manos se adelanta al cierre del tranque

**Corregido el 2026-10-06:** la transición espera el cierre de VISTO (o los 30 s) y después la cuenta. Compra, mostrador, revisión y siguiente mano bloqueados mientras está pendiente. Invalidación de callbacks al salir/reiniciar. VISTO del servidor admite también el tranque final en `over`. Prueba forzada local/estado online y vencimiento, más recorridos clásico/mostrador completados; capturas revisadas. Pendiente: prueba online real con varios humanos y despliegue de la corrección del servidor.

**Confirmado visualmente en clásico y partida con mostrador.** El aviso de tranque con «VISTO» sigue abierto cuando ya aparecen las opciones entre manos. Los paneles se superponen y permiten continuar antes de reconocer el resultado.

Reproducción con el recorrido, semilla predeterminada 20261004:

1. Ejecutar `-- --recorrido --escena=clasico` y llegar al tranque de la primera mano.
2. Antes de pulsar «VISTO», intentar «Ver la mesa».
3. Repetir con `--escena=mostrador`: al terminar la mano, ir al mostrador, comprar café y pulsar «SIGUIENTE MANO» mientras el aviso del tranque sigue pendiente.

Resultado observado:

- Clásico, vídeo alrededor de **00:47,83**: «VISTO» ocupa el espacio de «Ver la mesa». El bot no llega a la revisión de mesa y después no encuentra «Desde abajo» ni «Volver». Estas dos alertas son consecuencias del mismo fallo, no bugs independientes.
- Mostrador, alrededor de **00:59,47**: el panel de compra se dibuja sobre parte del aviso del tranque. Se compra café (30 → 16 monedas) y se entra en la selección de aumentos de la mano 2 sin pulsar «VISTO». Las capturas `m_comprado` y `m_siguiente` y las marcas del log respaldan esta secuencia.

Esperado: reconocer/cerrar el tranque antes de habilitar la transición entre manos, o presentar una convivencia explícita de paneles sin tapar controles ni texto. Impacto: revisión de mesa bloqueada en esa transición, resultado tapado y confirmación saltable. No se ha demostrado corrupción de puntuaciones ni desincronización online.

Evidencia:

- [Clásico: paneles superpuestos](../capturas/auditoria_2026-10-05/clasico/mesa_arriba_m1.png), [vídeo](../capturas/auditoria_2026-10-05/clasico/video.mp4), [auditoría original](../capturas/auditoria_2026-10-05/clasico/originales/auditoria.jsonl).
- [Mostrador y tranque](../capturas/auditoria_2026-10-05/mostrador/m_mostrador.png), [café comprado con aviso pendiente](../capturas/auditoria_2026-10-05/mostrador/m_comprado.png), [siguiente mano](../capturas/auditoria_2026-10-05/mostrador/m_siguiente.png), [log](../capturas/auditoria_2026-10-05/mostrador/log.txt), [vídeo](../capturas/auditoria_2026-10-05/mostrador/video.mp4).

## B02 · P3 · «PARARSE» conserva el idioma anterior

**Corregido el 2026-10-06:** los botones con iconos conservan clave y argumentos y responden al cambio de idioma. Incluye Meta 100/200. Traducción 494 claves, cambio del botón real ES/EN y recorrido raros correctos; autotests en ambos idiomas sin SCRIPT ERROR. Lista de controles y reproducción manual en [pruebas](pruebas_bugs_recorrido.md).

**Confirmado visualmente tras cambiar a inglés durante la misma ejecución.** El bot cambia el ajuste de idioma mediante `apply_settings()` y comienza otra partida. Marcador, instrucciones y «PASS» aparecen en inglés, pero el botón persistente «PARARSE» sigue en español.

Reproducción observada: recorrido `--escena=raros`, sección «otra partida en inglés». Para reproducir desde la interfaz: iniciar en español, cambiar a English en Ajustes y comenzar otra partida sin reiniciar el proceso. Esa ruta manual exacta queda pendiente de repetición; el fallo está confirmado en el cambio de idioma aplicado por el recorrido.

Esperado: «STAND UP», traducción ya existente en `translations/textos.csv`. Observado alrededor de **00:56,23**, y también en la captura final de la sección inglesa: «PASS» y «PARARSE» juntos. Impacto: interfaz con idiomas mezclados; el botón sigue visible.

Indicio de causa, sin modificar código: `scripts/main.gd` traduce el texto una vez en `_symbol_button` y desactiva su traducción automática. `stand_btn` se reutiliza; `apply_settings()` cambia el locale. Debe verificarse el alcance en otros controles persistentes antes de arreglarlo; esta revisión solo confirma «PARARSE».

Evidencia: [captura inglesa](../capturas/auditoria_2026-10-05/raros/ingles.png), [fotograma 00:56,23](../capturas/auditoria_2026-10-05/raros/hallazgo_00.jpg), [vídeo](../capturas/auditoria_2026-10-05/raros/video.mp4).

## Alertas separadas de los bugs confirmados

- **Bot de pruebas, idioma:** busca «PASO» aunque el botón real ya dice «PASS». Su alerta `boton_no_aparece` en `raros` es una incompatibilidad del recorrido con el texto traducido, no evidencia de que falte el botón. No se corrigió el bot. El tramo inglés no valida correctamente el pase y su cobertura queda limitada.
- **Auditoría de solapamientos del mostrador:** registra siete cruces entre gestos y «VISTO» en el mismo instante. No se cuentan como siete fallos visuales independientes: la captura no muestra esos siete botones dibujados. El detector geométrico necesita comprobar oclusión/estado visual. La superposición real entre mostrador y aviso sí está confirmada en B01.
- **15 alertas de oscilaciones:** las evidencias revisadas corresponden al reparto, gestos/baile, cuenta de puntos, cambio de avatar y escritura animada de pizarra. No se confirmó un destello de luz independiente. El detector no distingue por sí solo animación intencionada de parpadeo defectuoso.
- **Avisos al cerrar Godot:** las siete escenas muestran `ObjectDB instances were leaked at exit`: menús 2, partida 8, clásico 6, de pie 2, raros 2, final 2, mostrador 2. Se conserva el aviso como pendiente técnico, sin afirmar una fuga acumulativa durante partidas. Hace falta identificar instancias con `--verbose` y comprobar crecimiento entre partidas; no se investigó ni corrigió en este recorrido.

## Cobertura y límites

| Escena | Fotogramas | Resultado |
|---|---:|---|
| menus | 1.940 | Navegación, espejo/gestos, armario y ajustes; sin alertas de auditoría |
| partida | 2.740 | Aumentos, dos manos, cuenta y revisión de mesa; sin alertas de auditoría |
| clasico | 3.023 | Dos manos; B01 y dos alertas derivadas |
| de_pie | 2.943 | Levantarse, caminar, colisiones, gestos, empujar, volver/sentarse; sin alertas de auditoría |
| raros | 5.788 | Pausas, ajustes, cámara, salida e inglés; B02 y limitación del bot al pasar |
| final | 961 | Final preparado, libreta, revisión de mesa y revancha; sin alertas de auditoría |
| mostrador | 1.975 | Baile/brindis, compra y siguiente mano; B01 |

No aparecieron errores de ejecución en los logs, aparte de los avisos de cierre descritos. «Sin alertas» no significa ausencia garantizada de bugs. El recorrido prepara ciertos estados: final parte de puntos ajustados y mostrador asigna 30 monedas y coloca al jugador frente al dependiente; no valida obtener esas monedas ni caminar toda esa ruta. No cubre Android, mandos, otras resoluciones, online, servidores ni sesiones largas. El tiempo de Movie Maker no sirve como medición de rendimiento real.

Grabaciones anteriores conservadas. Artefactos de esta sesión: [informe automático](../capturas/auditoria_2026-10-05/informe.html), [resumen JSON](../capturas/auditoria_2026-10-05/resumen.json). El HTML contiene alertas brutas; este documento es la clasificación revisada. Las marcas originales del bot empiezan después de cargar: los tiempos de vídeo del informe se ajustaron por un desplazamiento estimado, conservando originales en cada carpeta `originales`.

Comando usado para cada escena (en PowerShell, rutas absolutas de la copia):

```powershell
& '%USERPROFILE%/AndroidStudioProjects/Godot_4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path '<copia>' --resolution 1280x720 --write-movie '<copia>/capturas/recorrido/<escena>/video.avi' --fixed-fps 30 -- --recorrido --escena=<escena>
```

No se cambiaron scripts del juego, reglas ni arte durante esta auditoría. No se aplicaron arreglos ni se creó un commit.
