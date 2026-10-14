# Bot de recorrido y auditoría visual — entrega del 7 de octubre

**Estado vigente al 7 de octubre de 2026:** código integrado en principal y publicado en GitHub en esta entrega autorizada. Nube y Windows publicados anteriormente; esta entrega integra herramientas del bot y documentación, sin nuevo despliegue ni exportación. APK/Para-amigos pendientes. Véanse [traspaso](TRASPASO_CLAUDE.md) y [tablero](TABLERO_COLMADON.html). Las secciones anteriores conservan resultados históricos.

Cambios desarrollados en la copia `.trabajo-codex/bot-auditoria-completa`, rama `codex/bot-auditoria-completa`. **Código del bot integrado en principal en esta entrega; sin despliegue ni exportación nuevos.**

- [Informe de implementación, bugs confirmados y recomendaciones](mejora_bot_20261007.md).
- [Guía y comandos actualizados](recorrido.md).
- [Informe navegable de nueve grabaciones](../.trabajo-codex/bot-auditoria-completa/capturas/revision_bot_20261007/informe.html).
- Se aplicó únicamente el parche de cambios propios, conservando las modificaciones de principal. El informe completo de vídeo permanece local en la copia; las capturas confirmadas se incluyen en `docs/evidencias/bot_20261007/`.

Resultado: 28884 frames de vídeo analizados, 28281 auditados y trazas continuas; siete escenas dirigidas completadas, menús con un clic fallido y grabación del explorador parcial por límite de 600 s. Repetición del explorador sin vídeo: 15/15 objetivos OK, 93 acciones, 0 fallos y 10167 frames auditados. Cuatro clientes gráficos de nube: partida 112–60, tres manos, 0 fallos del supervisor y 39514 frames auditados; esa ejecución no grabó vídeo.

Confirmados visualmente: tabla invade cabeza del colmadero desde compra; varios avisos de No llevaba/falsa alarma/+30 se solapan y una frase se corta. Recomendaciones de Pizarra: distinguir partida directa de abrir/buscar sala, explicar salas públicas y separar meta/navegación/estadísticas. Clic del espejo queda candidato.

Pruebas: auditor visual, auditor espacial, supervisor gráfico y cinco pruebas Python del analizador sin fallos. El análisis automático procesa cada frame del vídeo; esto no es inspección humana semántica de cada imagen ni cobertura de todas las combinaciones/Android. Las alertas de parpadeo/cajas/anchos siguen siendo candidatos. Fuentes e intentos fallidos conservados en la copia; bugs del fixture separados de los del producto.
