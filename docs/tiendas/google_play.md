# Colmadón — ficha de Google Play

Borrador de la ficha de Google Play (español e inglés), clasificación de contenido y
formulario de seguridad de datos. Basado en lo que el juego hace de verdad el
2026-10-03 (`scripts/red.gd`, `servidor/`). **Si cambia el juego (compras, anuncios,
Firebase, chat, Google Play Games), hay que rehacer los apartados 5 y 6.**

## Fuentes oficiales consultadas

- Límites de la ficha (nombre 30, descripción breve 80, descripción completa 4.000):
  https://support.google.com/googleplay/android-developer/answer/9859152
- Recursos gráficos (icono 512×512, gráfico de funciones 1024×500, capturas):
  https://support.google.com/googleplay/android-developer/answer/9866151
- Clasificación de contenido (cuestionario IARC):
  https://support.google.com/googleplay/android-developer/answer/188189
- Etiquetas de PEGI (qué edad pone el alcohol y el juego de azar):
  https://pegi.info/what-do-the-labels-mean
- Formulario de seguridad de datos:
  https://support.google.com/googleplay/android-developer/answer/10787469
- Eliminación de cuentas:
  https://support.google.com/googleplay/android-developer/answer/13327111
- Juegos de azar con dinero real, juegos y concursos:
  https://support.google.com/googleplay/android-developer/answer/9877032

Recuentos de caracteres comprobados con un script (Python `len`) el 2026-10-03.

---

## 1. Título (máx. 30)

| Idioma | Título | Caracteres |
|---|---|---|
| Español | `Colmadón: Dominó en Pareja` | 26 |
| English | `Colmadón: Partner Dominoes` | 26 |

Alternativa corta si Google pide quitar descriptores: `Colmadón` (8).

---

## 2. Descripción breve (máx. 80)

| Idioma | Texto | Caracteres |
|---|---|---|
| Español | `Dominó dominicano por parejas con chivos, aumentos y bebidas que rompen reglas.` | 79 |
| English | `Dominican partner dominoes with cheats, stacking boosts and rule-bending drinks.` | 80 |

---

## 3. Descripción completa (máx. 4.000)

### Español (2.585 caracteres de 4.000)

```text
Cuatro sillas, una bombilla y una mesa de madera en un colmado de barrio a medianoche. Colmadón es dominó dominicano por parejas de verdad, con un giro: cada mano eliges un aumento que se queda contigo toda la partida y, con lo que ganas, compras bebidas que rompen las reglas.

CÓMO SE JUEGA
• Doble seis, 7 fichas cada uno, 2 contra 2: juegas en pareja con quien tienes enfrente.
• Las 28 fichas se barajan boca abajo y cada uno roba las suyas de la mesa.
• Arrastra la ficha a la punta de la línea (o tócala) y estámpala.
• Gana la mano dominando o en el tranque. Capicúa, dobles y cierres dan puntos extra.
• La primera pareja que llega a 100 puntos se lleva la partida.

EL CHIVO
Mete una ficha que no casa o pasa teniendo ficha... si te atreves. Si el siguiente jugador canta «¡CHIVO!», la mano se acaba y su pareja se lleva los puntos de los tramposos. Si no lo ve, el chivo se queda. Cantar sin haber chivo cuesta monedas.

AUMENTOS QUE SE ACUMULAN
Al empezar cada mano eliges 1 de 3 cartas: Doble fuerte, Capicúa, Cierre ruidoso, Mano ligera, Ojo pícaro, Pasador, Bolsillo o Fiado. Se suman mano tras mano: cada partida termina con una combinación distinta.

BEBIDAS QUE ROMPEN LAS REGLAS
Entre manos pasas por el mostrador y gastas las monedas de la partida en hasta 2 bebidas:
• Café: juegas dos fichas seguidas.
• Agua fría: anulas un aumento rival durante una mano.
• Morir soñando: ves la mano de tu compañero.
• Ron: mano caliente, +50 % de puntos si tu pareja gana la mano... pero cazas peor los chivos.
Las monedas no tienen valor real y no se pueden comprar: solo se ganan jugando.

CON AMIGOS O CONTRA BOTS
• Crea una sala y comparte el código de 6 letras. El primer amigo es tu compañero; los siguientes, los rivales.
• Los bots juegan en pareja de verdad: tapan, guardan el juego al compañero y a veces meten chivo. Rellenan las sillas vacías.
• Si alguien se desconecta, un bot juega su silla hasta que vuelva.
• Juego cruzado entre móvil y PC.
• Partida rápida contra bots sin conexión.

UN COLMADO VIVO
Escena 3D con aspecto pixel art y fichas nítidas. El colmadero limpia el mostrador, la gata duerme, el abanico gira y la bombilla tiembla con cada golpe. Los personajes miran a quien juega, se ríen cuando te tapan y se levantan con la capicúa. Tus manos están en la mesa: arrastran la ficha, tocan la madera para pasar y levantan el vaso.

TU PERSONAJE, TU MESA
Crea hasta 3 personajes en el espejo y estrena fichas, mesas y vasos en el armario con los pesos que ganas jugando. Son solo estéticos: nunca dan ventaja.

Sin anuncios. Sin apuestas ni dinero real en juego.
```

### English (2.619 caracteres de 4.000)

```text
Four chairs, a light bulb and a wooden table in a neighbourhood corner store at midnight. Colmadón is real Dominican partner dominoes with a twist: every hand you pick a boost that stays with you all match long, and you spend your winnings on drinks that bend the rules.

HOW TO PLAY
• Double-six, 7 tiles each, 2 vs 2: you team up with the player across from you.
• All 28 tiles are shuffled face down and everyone draws their own from the table.
• Drag a tile to an open end of the line (or tap it) and slam it down.
• Win the hand by going out or in a block. Capicúa, doubles and big finishes score bonus points.
• The first team to 100 points wins the match.

THE CHIVO
Sneak in a tile that doesn't match, or pass while holding a playable one... if you dare. If the next player calls "CHIVO!", the hand ends and their team takes every point. If they miss it, the cheat stands. Calling it when there's nothing there costs you coins.

STACKING BOOSTS
At the start of every hand you pick 1 of 3 cards: Strong Double, Capicúa, Loud Finish, Light Hand, Sharp Eye, Passer, Pocket or Store Credit. They stack hand after hand: every match ends with a different build.

RULE-BENDING DRINKS
Between hands you stop at the counter and spend the match coins on up to 2 drinks:
• Coffee: play two tiles in a row.
• Ice Water: cancel a rival's boost for one hand.
• Morir Soñando: see your partner's hand.
• Rum: hot hand, +50% points if your team wins the hand... but you get worse at catching cheats.
Coins have no real value and can't be bought: they are only earned by playing.

WITH FRIENDS OR AGAINST BOTS
• Create a room and share the 6-letter code. The first friend is your partner; the next ones are your rivals.
• Bots play as a real team: they block, keep the game open for their partner and sometimes cheat. They fill empty chairs.
• If someone disconnects, a bot plays their seat until they come back.
• Cross-play between mobile and PC.
• Offline quick match against bots.

A LIVING CORNER STORE
A 3D scene with a pixel art look and crisp tiles. The shopkeeper wipes the counter, the cat sleeps, the fan turns and the light bulb shakes with every slam. Characters watch whoever is playing, laugh when you get blocked and jump up for a capicúa. Your hands are on the table: they drag the tile, knock on the wood to pass and raise the glass.

YOUR CHARACTER, YOUR TABLE
Create up to 3 characters in the mirror and show off new tiles, tables and glasses from the wardrobe, bought with the pesos you earn by playing. They are purely cosmetic: they never give an advantage.

No ads. No betting and no real money at stake.
```

**Ojo al publicar:** «Sin anuncios» y «sin dinero real» solo valen mientras no haya
anuncios ni compras. Cuando se añadan las compras de cosméticos, cambiar la última línea
por «Compras opcionales solo estéticas. Sin apuestas.» y marcar «Contiene compras en
la aplicación» en Play Console. La ficha en inglés no debe publicarse hasta que el
juego esté traducido (ver «Riesgos»).

---

## 4. Categoría y etiquetas

- **Tipo:** Juego. **Categoría:** Juegos de mesa (Board).
  Alternativa: Cartas (Card); se descarta porque el núcleo es el dominó.
- **Etiquetas** (Play Console deja elegir hasta 5 de una lista cerrada; **sin comprobar
  cuáles ofrece hoy para «Juegos de mesa»**: elegirlas en Play Console > Presencia en
  Google Play > Etiquetas de la tienda). Por orden de preferencia:
  1. Dominoes / Dominó (si existe): es lo que busca la gente.
  2. Multiplayer / Multijugador: salas con amigos.
  3. Casual: reglas que se aprenden en un minuto.
  4. Pixelated / Pixel art: estilo visual.
  5. Offline / Sin conexión: se puede jugar contra bots sin Internet.
- **Público objetivo (sección «Público objetivo y contenido»):** mayores de 13 años
  (13–15, 16–17 y 18+). **No** marcar menores de 13: el juego tiene alcohol, juego
  online con nombres libres y el chivo como trampa; marcar menores obligaría a cumplir
  la política de Familias.

---

## 5. Clasificación de contenido orientativa (cuestionario IARC)

El cuestionario lo responde el usuario en Play Console > Clasificación de contenido. IARC
genera a la vez las edades de cada región (PEGI, ESRB, USK, ClassInd...). Las preguntas
exactas cambian; abajo va **qué responder y por qué** en cada bloque. Responder siempre
la verdad: una respuesta falsa puede retirar la app.

**Categoría del cuestionario:** «Juego» (Game).

| Bloque | Respuesta | Por qué |
|---|---|---|
| Violencia | **No** | No hay peleas ni daño. Los golpes son fichas contra la mesa. |
| Miedo / terror | **No** | Ambiente nocturno pero tranquilo. |
| Sexualidad / desnudez | **No** | Personajes vestidos; sin contenido sexual. |
| Lenguaje soez | **No** | Los textos del juego no tienen palabrotas. (Los nombres los escriben los jugadores: eso va en «interacción entre usuarios».) |
| Humor grosero / escatológico | **No** | — |
| Sustancias controladas (drogas) | **No** | — |
| **Alcohol** | **Sí: se muestra el consumo de alcohol** | El **Ron** es una bebida alcohólica que el jugador compra con monedas del juego y que los personajes (y tú en primera persona) se beben, con mejillas coloradas, tambaleo y mareo de cámara. Hay estanterías con botellas al fondo. Responder que el alcohol **se consume** (no solo «referencias»). Si pregunta si se incentiva o recompensa: la bebida da una ventaja de juego (+50 % de puntos), así que lo honesto es responder que **sí aporta un beneficio en el juego**. Esto probablemente dará **PEGI 16** (según PEGI, en el 16 «puede aparecer el uso de tabaco, alcohol o drogas») y una edad parecida en otras regiones. |
| Tabaco | **No** | Nadie fuma. |
| **Juego de azar simulado** | **No** | Es dominó, un juego de habilidad por parejas. No hay apuestas, ni casino, ni tragaperras, ni ruleta. Las «monedas» no se apuestan: se ganan al cerrar cada mano (10 la pareja ganadora, 4 la perdedora) y solo compran bebidas dentro de esa partida. Los «pesos» del armario se ganan jugando y solo compran cosméticos. No se puede comprar moneda con dinero real ni cambiarla por nada con valor real. |
| Juego de azar con dinero real | **No** | — |
| **Interacción entre usuarios** | **Sí** | Salas online con código: los jugadores ven el nombre (texto libre de hasta 16 caracteres) y el aspecto del personaje de los demás. **No** hay chat de texto ni de voz. |
| Comparte la ubicación del usuario | **No** | El juego no usa la ubicación. |
| **Compras digitales** | **No (por ahora)** | No hay compras en la app. **Cambiar a Sí** cuando se añadan las compras de cosméticos. |
| Comparte información personal con otros usuarios | **No** | Solo el nombre de jugador que tú eliges; ni correo, ni teléfono, ni datos reales. |
| Navegador web / contenido sin restringir | **No** | — |

**El «chivo».** En el juego «chivo» es una ficha metida con trampa (una regla del
dominó dominicano), no una sustancia ni una bebida. No corresponde a ninguna pregunta del
cuestionario. «Morir soñando» (leche con jugo de naranja), el Café y el Agua fría no
tienen alcohol.

**Resultado esperado (orientativo, no garantizado):** PEGI 16 / ESRB Teen por el
consumo de alcohol, con aviso de «interacción entre usuarios». **Sin el Ron**, lo
esperable sería PEGI 3–7 / ESRB Everyone. Ver «Riesgos» para elegir.

---

## 6. Borrador del formulario de seguridad de datos

### Qué recoge el juego de verdad (revisado en el código)

- **Partida en solitario:** no envía nada. El perfil (personajes, pesos, cosméticos) y
  los ajustes se guardan solo en el móvil (`user://perfil.cfg`, `user://ajustes.cfg`).
  Lo que no sale del dispositivo no cuenta como «recogido» para Google.
- **Sala con amigos (online):** al entrar por primera vez, `scripts/red.gd` llama a
  `authenticate_device_async` con `Nakama.get_device_id()` (en Android, el identificador
  del dispositivo que da Godot con `OS.get_unique_id()`). Nakama crea una cuenta con un
  **ID de usuario** interno y un nombre de usuario aleatorio, y la guarda en su base de
  datos PostgreSQL. Además se envían:
  - el **nombre** que eliges (máx. 16 caracteres, se ve en la mesa de los demás);
  - el **aspecto del personaje** (piel, pelo, ropa, gafas...);
  - las **jugadas** (robar, jugar, pasar, cantar chivo, comprar y beber).
  El nombre, el aspecto, las jugadas y las **estadísticas de la partida** (puntos, manos,
  chivos...) viven solo en la memoria de la sala mientras dura la partida
  (`servidor/modulo/src/sala.ts`); no se escriben en la base de datos.
- El servidor anota en su registro técnico «Sala XXXXXX creada por <ID de usuario>»
  (`sala.ts`) y, como cualquier servidor, recibe la **dirección IP** de la conexión.
- **No hay:** anuncios, compras, Firebase, analítica, Google Play Games, ubicación,
  contactos, correo, micrófono ni chat. El único permiso Android es `INTERNET`.
- **Servidor:** Google Cloud, máquina en `us-central1` (EE. UU.). Google Cloud actúa como
  proveedor de servicios: transferirle datos **no** cuenta como «compartir».

### Respuestas propuestas

**¿Tu app recoge o comparte alguno de los tipos de datos de usuario obligatorios?** Sí.

**¿Todos los datos de usuario recogidos se cifran en tránsito?** **No, hoy no.** El
cliente se conecta por `http` y WebSocket sin TLS (`Nakama.create_client(..., "http", ...)`
en `red.gd`, puerto 7350 abierto en la nube). **Antes de publicar** hay que poner TLS
(certificado y `https`/`wss`) y entonces responder **Sí**. Publicar respondiendo «Sí» sin
haberlo hecho sería falso.

**¿Ofreces una forma de que los usuarios pidan que se eliminen sus datos?** Sí:
desde el juego, con el botón «Borrar mis datos online» de Ajustes, y por correo a
[CORREO DE CONTACTO] (ver `privacidad.md`).

**¿Compartes datos con terceros?** No.

| Tipo de dato (Play Console) | ¿Recogido? | ¿Compartido? | ¿Efímero? | ¿Obligatorio u opcional? | Finalidad |
|---|---|---|---|---|---|
| Información personal > **Nombre** | Sí (el nombre de jugador; Google incluye los apodos) | No | **Sí** (solo en memoria durante la partida) | Obligatorio para jugar online | Funciones de la app (mostrar tu nombre en la mesa) |
| Información personal > **ID de usuario** | Sí (ID de cuenta de Nakama) | No | No (se guarda) | Obligatorio para jugar online | Funciones de la app; gestión de la cuenta |
| Actividad en la app > **Interacciones con la app** | Sí (jugadas de la partida) | No | **Sí** | Obligatorio para jugar online | Funciones de la app (el servidor decide las jugadas) |
| Actividad en la app > **Otro contenido generado por el usuario** | Sí (aspecto del personaje) | No | **Sí** | Obligatorio para jugar online | Funciones de la app (que los demás vean tu personaje) |
| Actividad en la app > **Otras acciones** | Sí (estadísticas de la partida) | No | **Sí** | Obligatorio para jugar online | Funciones de la app (libreta del final) |
| **ID de dispositivo u otros ID** | Sí (identificador del dispositivo usado para crear la cuenta) | No | No (Nakama lo guarda para volver a reconocerte) | Obligatorio para jugar online | Funciones de la app; gestión de la cuenta |
| Ubicación, información financiera, salud, mensajes, fotos, audio, archivos, calendario, contactos, historial web, apps instaladas | No | — | — | — | — |
| Información de la app y rendimiento (fallos, diagnósticos) | No (no hay Crashlytics) | — | — | — | — |

Sobre «obligatorio u opcional»: Google considera opcional lo que el usuario puede negarse
a dar y seguir usando la app. Como el juego en solitario funciona sin enviar nada, se
podría defender «opcional»; se propone **obligatorio** (más prudente), porque sin esos
datos no hay modo online.

Sobre la IP: Google no la pide como tipo de dato si no se usa para sacar la ubicación (no
se hace). Se menciona igualmente en la política de privacidad.

**Cuándo hay que actualizar el formulario:** al añadir Firebase (Analytics/Crashlytics),
compras (Google Play Billing), anuncios, chat rápido, vinculación con Google Play Games o
Steam, clasificaciones o guardado en la nube.

---

## 7. Riesgos (Google Play)

1. **Alcohol y edad.** Con el Ron tal como está (se bebe, da ventaja y emborracha al
   personaje), la clasificación esperable es PEGI 16. Eso no impide publicar, pero quita
   público joven y bloquea la promoción a menores. Opciones para el usuario:
   - **Mantener el Ron** (es parte del colmado dominicano) y aceptar 16+. Público objetivo
     13+ no encaja con PEGI 16: marcar 16+ o 18+ en «Público objetivo».
   - **Cambiar el Ron por una bebida sin alcohol** con el mismo efecto (p. ej. «Malta» o
     «Mabí») y quitar el tambaleo: probablemente PEGI 3–7. Las botellas del fondo
     seguirían siendo una «referencia» leve.
   Decisión de producto: preguntarla al usuario antes de rellenar el cuestionario.
2. **Juego de azar.** El dominó con puntos no es juego de azar, pero los revisores ven
   «monedas», «pesos» y «colmado». Presentarlo así: «Sin apuestas. Las monedas no tienen
   valor real y no se pueden comprar». Cuando haya compras: **vender cosméticos
   directamente, nunca pesos ni monedas**; si se vendieran pesos y los pesos se ganan
   ganando partidas, se parecería a apostar. No usar «bet», «apuesta», «casino»,
   «premio» en la ficha ni en las imágenes.
3. **Conexión sin cifrar.** Hoy no hay TLS: la respuesta honesta en el formulario es
   «no se cifran en tránsito», lo que se ve mal en la ficha pública. Además Android, desde
   la API 28, bloquea el tráfico `http` en claro si no se permite expresamente. Poner
   TLS antes de la prueba cerrada.
4. **Eliminación de cuenta.** La política de Google obliga a ofrecer borrado dentro de la
   app **y** un enlace web si la app «permite crear una cuenta». Aquí la cuenta se crea
   sola al entrar en una sala; la política solo excluye las cuentas creadas sin conexión.
   Es dudoso que aplique, así que lo prudente es: botón «Borrar mis datos online» en
   Ajustes + página web (la propia política de privacidad publicada) con el correo para
   pedir el borrado. El botón ya está (2026-10-04, RPC `borrar_cuenta`); falta desplegar
   el servidor con `servidor/nube/actualizar.sh` para que funcione en la nube.
5. **Nombres libres.** Otros jugadores ven el nombre que escribes. Con «interacción entre
   usuarios», conviene filtro de palabras y forma de reportar antes de abrir salas
   públicas. Con salas privadas por código el riesgo es bajo.
6. **Idioma.** El juego solo está en español. Publicar la ficha en inglés antes de
   traducirlo genera reseñas malas; o se traduce antes, o se publica solo la ficha en
   español.
7. **Política de privacidad.** Es obligatoria para el formulario: publicar
   `privacidad.md` en una URL pública (p. ej. GitHub Pages) y enlazarla en Play Console y
   dentro del juego.
