# Prompts para sesiones de Claude en la nube

Cada sesión gasta tu límite de uso. Lánzalas **de una en una**, en este orden, y fusiona el PR de una antes de lanzar la siguiente (las tareas 1 y 2 tocan los mismos archivos).

Cómo lanzar una: en https://claude.ai/code elige el repositorio **Cukiti/Colmadon**, pega el prompt y envía.

---

## 1. Cartas nuevas (idea 7): continuar la rama `wip-cartas-nuevas`

```
Repositorio Cukiti/Colmadon (dominó dominicano por parejas en Godot 4.7, con cartas de aumento y bebidas; modo online con servidor Nakama en TypeScript). Escribe comentarios, commits y PR en español.

Parte de la rama wip-cartas-nuevas: es trabajo a medias de otra sesión (sin verificar). Revísalo, corrígelo y termínalo; si algo no tiene sentido, rehazlo.

Objetivo: tres cartas de aumento nuevas en scripts/game.gd (CARDS y sus efectos) y, con comportamiento idéntico, en servidor/modulo/src/reglas.ts:
- «Ficha marcada»: ves a qué números ha pasado cada rival. Que también sirva a los bots (usan lacks) para poder medirla.
- «Doble suerte»: un efecto con los dobles (elige el más interesante y equilibrado).
- «Tranque seguro»: un efecto sobre los tranques.
Cada carta con texto (desc) claro y con números. Sin pago para ganar ni estrategia dominante.

Equilibra con tests/simulacion_equilibrio.gd (Godot 4.7.2 headless; descarga el binario Linux de https://github.com/godotengine/godot/releases/tag/4.7.2-stable si hace falta) siguiendo el método de docs/equilibrio.md: «carta sola frente a ninguna» y «preferir frente a evitar». Objetivo: cada carta nueva entre 48 % y 54 % al preferirla y ninguna carta existente rota (vuelve a medir todas). Deben pasar `cd servidor/modulo && npm install && npm test` y tests/prueba_logica.gd.

No toques scripts/main.gd, scripts/view3d.gd ni scripts/menus.gd; si una carta necesita algo visual, descríbelo en el PR. Añade una sección al final de docs/equilibrio.md y una línea en ESTADO.md.
Entrega: PR a master con el diseño de cada carta (entrada → acción → resultado → número) y las tablas antes/después. Sé eficiente: simulaciones de n=1500 salvo para confirmar el resultado final. No despliegues nada.
```

## 2. Bots más listos: continuar la rama `wip-bots-listos`

```
Repositorio Cukiti/Colmadon (dominó dominicano por parejas en Godot 4.7; servidor Nakama en TypeScript). Escribe comentarios, commits y PR en español.

Parte de la rama wip-bots-listos (trabajo a medias de otra sesión: ya tenía paridad exacta entre game.gd y reglas.ts en 1.542 estados). Si master tiene cambios nuevos en scripts/game.gd o servidor/modulo/src/reglas.ts, fusiona master primero y resuelve los conflictos.

Objetivo: bots que jueguen mejor en pareja sin ser imbatibles, con la misma lógica en scripts/game.gd (bot_turn, _move_score, _bot_drink, _bots_shop) y servidor/modulo/src/reglas.ts (rTurnoBot, rNotaJugada, rBotBebe, rTiendaBots, rBotEligeCarta):
1. Que usen «Ojo pícaro» (fichas vistas de los rivales) y «Morir soñando» (mano del compañero). En game.gd esa información debe existir por silla también para los bots, sin cambiar lo que ve la persona en la silla 0.
2. Contar fichas jugadas por número, soltar dobles a tiempo, y elegir cartas y bebidas con criterio pero con variedad.
3. Mantener las tasas de chivo (meter y cazar) como están.
Medir: bot nuevo contra bot viejo (cambiando de asiento), con objetivo 55–65 %; repetir las tablas de docs/equilibrio.md y comprobar que ninguna carta ni bebida queda dominante (ahora sí se pueden medir Ojo pícaro y Morir soñando). Deben pasar npm test y tests/prueba_logica.gd.

No toques scripts/main.gd, scripts/view3d.gd ni scripts/menus.gd. Añade una sección a docs/equilibrio.md y una línea en ESTADO.md.
Entrega: PR a master con qué hace distinto el bot y las tablas antes/después; propone ajustes de números sin aplicarlos. Sé eficiente con las simulaciones. No despliegues nada.
```

## 3. Juego en inglés: aplicar `tr()` y selector de idioma

```
Repositorio Cukiti/Colmadon (Godot 4.7). Escribe comentarios, commits y PR en español.

La traducción ya existe: translations/textos.csv (claves = texto español exacto) y docs/traduccion.md, con la lista exacta de los sitios que necesitan tr(): unos 25 en main.gd, 6 en menus.gd y 5 en red.gd, más la función _tr_bonus para los bonus del servidor. Las líneas pueden haber cambiado: busca cada sitio por su texto.

Tarea:
1. Aplicar todos los tr() de la lista (también tr(text) en los avisos flotantes de main.gd::_draw, y tr() antes de .to_upper()).
2. Quitar la traducción automática de las etiquetas con nombres de jugador (que «Ron» no salga como «Rum»).
3. Selector de idioma en la radio de ajustes (menus.gd): Automático / Español / English, guardado en ajustes.cfg y aplicado al arrancar (TranslationServer.set_locale).
4. Añadir al CSV las claves que falten (p. ej. las 8 frases del chat rápido FRASES de main.gd, si no están).
Comprueba con Godot 4.7.2 headless (binario Linux de https://github.com/godotengine/godot/releases/tag/4.7.2-stable): `--import` sin errores y `--path . -- --autotest` termina con «PARTIDA TERMINADA» y sin SCRIPT ERROR, en español y forzando inglés. Si puedes, guarda capturas en inglés de la pizarra, la tienda y la mesa (ventana virtual con xvfb) para revisar longitudes.
Entrega: PR a master con la lista de cambios y lo que no pudiste comprobar.
```

## 4. Botón «Borrar mis datos online» (lo pide la política de privacidad)

```
Repositorio Cukiti/Colmadon (Godot 4.7, servidor Nakama en TypeScript en servidor/modulo). Escribe comentarios, commits y PR en español.

Contexto: docs/tiendas/privacidad.md y docs/tiendas/google_play.md (apartado Riesgos) piden poder borrar la cuenta online. La cuenta se crea sola con el id del dispositivo (scripts/red.gd, Nakama.authenticate_device_async).

Tarea:
1. Servidor: RPC «borrar_cuenta» que borre la cuenta del usuario que llama (nk.accountDeleteId, con registro en el log sin datos personales). Pruebas en servidor/modulo/tests con un nk simulado; `npm install && npm test` debe pasar.
2. Cliente: en scripts/red.gd, una función borrar_cuenta() que llame al RPC, cierre el socket y genere un id de dispositivo nuevo la próxima vez (borra user://nakama_device_id). En scripts/menus.gd, en la radio de ajustes, el botón «Borrar mis datos online» con confirmación («¿Seguro? Se borra tu cuenta online; tus personajes y pesos de este dispositivo se quedan»).
3. Actualiza docs/tiendas/privacidad.md para explicar el botón.
Comprueba que el juego arranca sin errores con Godot 4.7.2 headless (`--path . -- --autotest`).
Entrega: PR a master. No despliegues el servidor (eso se hace desde el PC con servidor/nube/actualizar.sh).
```
