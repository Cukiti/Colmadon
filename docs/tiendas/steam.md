# Colmadón — ficha de la tienda de Steam

Borrador de la página de Steam (español e inglés). Todo lo que se promete aquí existe ya
en el juego, salvo lo marcado como **[PENDIENTE]**, que no debe publicarse hasta que esté
hecho. Revisado: 2026-10-03.

## Fuentes oficiales consultadas

- Descripción de la página (reglas de la frase corta y de «Acerca de este juego»):
  https://partner.steamgames.com/doc/store/page/description
- Etiquetas (hasta 20; las 5 primeras pesan más; algunos filtros usan las 15 primeras):
  https://partner.steamgames.com/doc/store/tags
- Recursos gráficos y capturas: ver `capturas.md`.

**Límite de la frase corta:** la documentación pública de Valve solo dice «unos cientos de
caracteres»; el contador del editor de Steamworks la corta en **300 caracteres**
(**sin comprobar en la documentación oficial**: es lo que muestra el editor según guías
de terceros, p. ej. https://www.steampageanalyzer.com/blog/steam-short-description-guide).
Compruébalo en el propio editor al pegarla. Las dos frases de abajo miden menos de 300.

**Reglas de Valve que afectan al texto:** la frase corta es texto plano (sin formato ni
saltos de línea); nada de frases con fecha («ya disponible», «próximamente»); no se
puede enlazar a otras webs ni imitar botones de Steam; las imágenes o GIF de la
descripción, menos de 5 MB cada uno y menos de 15 MB en total.

---

## 1. Nombre

- **Colmadón** (con tilde en todas las tiendas; el paquete Android sigue siendo
  `com.cukiti.colmadon`).
- Búsqueda rápida en la web (2026-10-03): no aparece ningún juego llamado «Colmadón» en
  Steam ni en Google Play. **Sigue pendiente** comprobarlo dentro de Steamworks al dar de
  alta la app y en Google Play Console al reservar el nombre.

---

## 2. Frase corta

### Español (236 caracteres)

```text
Dominó dominicano por parejas en un colmado de noche. Elige un aumento cada mano, mete chivo sin que te cacen y gasta lo que ganas en bebidas que rompen las reglas. Juega con amigos por código de sala o contra bots, en PC y en el móvil.
```

### English (248 caracteres)

```text
Dominican partner dominoes in a late-night corner store. Pick a stacking boost every hand, sneak a cheat tile past your rivals and spend your winnings on drinks that bend the rules. Play with friends via room code or against bots, on PC and mobile.
```

---

## 3. Descripción larga («Acerca de este juego»)

Formato de Steam: `[h2]` para títulos y `[list][*]` para listas. Se puede pegar tal cual.

### Español

```text
[h2]¡Dale agua al dominó!... y luego ron, y café.[/h2]
Cuatro sillas, una bombilla que se balancea y una mesa de madera en un colmado de barrio a medianoche. Colmadón es dominó dominicano por parejas de verdad (doble seis, 7 fichas, 2 contra 2), pero cada mano eliges una carta de aumento que se queda contigo toda la partida, y con lo que ganas compras bebidas que rompen las reglas.

[h2]Cómo se juega[/h2]
[list]
[*]Las 28 fichas se barajan boca abajo sobre la mesa y cada uno roba sus 7.
[*]Juegas en pareja con quien tienes enfrente: si no llevas, pasas; tu compañero cuenta contigo.
[*]Arrastra la ficha hasta la punta de la línea (o tócala) y estámpala en la mesa.
[*]La mano se gana dominando (quedarte sin fichas) o en el tranque (nadie puede jugar). Capicúa, dobles y cierres dan puntos extra.
[*]La primera pareja que llega a 100 puntos se lleva la partida (la meta se puede cambiar en la sala).
[/list]

[h2]El chivo: hacer trampa forma parte del juego[/h2]
Puedes meter una ficha que no casa o pasar teniendo ficha. Si el jugador que sigue lo ve y canta «¡CHIVO!» en su turno, la mano se acaba y su pareja se lleva los puntos de las fichas de los tramposos. Si se le pasa, el chivo se queda. Y si cantas sin haber chivo, te cuesta monedas. Los dobles no se pueden meter de chivo.

[h2]Aumentos que se acumulan y bebidas que rompen las reglas[/h2]
Al empezar cada mano eliges 1 de 3 cartas: «Doble fuerte» (+30 si dominas con un doble), «Capicúa» (+25), «Mano ligera» (si perdéis, tus fichas cuentan menos), «Ojo pícaro» (ves una ficha de cada rival)... Las cartas se suman mano tras mano y cada partida acaba con una combinación distinta.
Entre manos pasas por el mostrador del colmado. Con las monedas de la partida compras hasta 2 bebidas de un solo uso:
[list]
[*]Café: juegas dos fichas seguidas una vez.
[*]Agua fría: anulas un aumento de un rival durante una mano.
[*]Morir soñando: ves la mano de tu compañero.
[*]Ron: mano caliente, +50 % de puntos si tu pareja gana esa mano... pero cazas peor los chivos.
[/list]
Nada de esto se compra con dinero real: las cartas y las bebidas solo se consiguen jugando.

[h2]Con amigos, contra bots o las dos cosas[/h2]
[list]
[*]Sala con amigos: crea una sala y comparte el código de 6 letras. El primer amigo que entra es tu compañero y los siguientes, los rivales.
[*]Bots que juegan en pareja: tapan a los rivales, no le cierran el juego al compañero y a veces meten chivo. Rellenan las sillas vacías para que siempre haya partida.
[*]Si alguien se desconecta, un bot juega su silla hasta que vuelva.
[*]Juego cruzado entre PC y móvil.
[*]Partida rápida en solitario contra bots, sin conexión.
[/list]

[h2]El colmado[/h2]
Una escena 3D con aspecto pixel art y fichas nítidas en alta definición. El colmadero limpia el mostrador, la gata duerme moviendo la cola, el abanico gira y la bombilla tiembla con cada golpe. Los personajes miran a quien juega, se ríen cuando te tapan, se levantan con la capicúa y se tapan la cara al perder. Tus manos están en la mesa: arrastran la ficha, tocan dos veces la madera para pasar y levantan el vaso al beber.
Crea hasta 3 personajes en el espejo (piel, pelo, ropa, barba, gafas, aros, cadena...) y estrena fichas, mesas y vasos en el armario con los pesos que ganas jugando. Son solo estéticos: nunca dan ventaja.
```

### English

```text
[h2]Dominoes, the Dominican way, with a twist.[/h2]
Four chairs, a swinging light bulb and a wooden table in a neighbourhood corner store at midnight. Colmadón is real Dominican partner dominoes (double-six, 7 tiles each, 2 vs 2), but every hand you pick a boost card that stays with you all match long, and you spend your winnings on drinks that bend the rules.

[h2]How to play[/h2]
[list]
[*]All 28 tiles are shuffled face down on the table and everyone draws their 7.
[*]You team up with the player across from you: if you can't play, you pass, and your partner is counting on you.
[*]Drag a tile to an open end of the line (or tap it) and slam it down.
[*]Win the hand by going out (playing all your tiles) or in a block (nobody can play). Capicúa, doubles and big finishes score bonus points.
[*]The first team to 100 points wins the match (the target can be changed in the room).
[/list]

[h2]The Chivo: cheating is part of the game[/h2]
You can sneak in a tile that doesn't match, or pass while holding a playable tile. If the next player spots it and calls "CHIVO!" on their turn, the hand ends and their team takes every point on the table. If they miss it, the cheat stands. Call it when there's nothing there and it costs you coins. Doubles can't be sneaked in.

[h2]Stacking boosts and rule-bending drinks[/h2]
At the start of every hand you pick 1 of 3 cards: "Strong Double" (+30 if you go out on a double), "Capicúa" (+25), "Light Hand" (if your team loses, your tiles count for less), "Sharp Eye" (see one tile from each rival)... Cards stack hand after hand, so every match ends with a different build.
Between hands you stop at the store counter. With the coins you win during the match you can buy up to 2 single-use drinks:
[list]
[*]Coffee: play two tiles in a row, once.
[*]Ice Water: cancel a rival's boost for one hand.
[*]Morir Soñando: see your partner's hand.
[*]Rum: hot hand, +50% points if your team wins that hand... but you get worse at catching cheats.
[/list]
None of this can be bought with real money: cards and drinks are only earned by playing.

[h2]With friends, against bots, or both[/h2]
[list]
[*]Friends room: create a room and share the 6-letter code. The first friend to join is your partner, the next ones are your rivals.
[*]Bots that play as a team: they block rivals, don't shut out their partner and sometimes cheat. They fill empty chairs so there's always a game.
[*]If someone disconnects, a bot plays their seat until they come back.
[*]Cross-play between PC and mobile.
[*]Offline quick match against bots.
[/list]

[h2]The corner store[/h2]
A 3D scene with a pixel art look and crisp, high-definition tiles. The shopkeeper wipes the counter, the cat sleeps with its tail swaying, the fan turns and the light bulb shakes with every slam. Characters watch whoever is playing, laugh when you get blocked, jump up for a capicúa and cover their faces when they lose. Your hands are on the table: they drag the tile, knock twice on the wood to pass and raise the glass when you drink.
Create up to 3 characters in the mirror (skin, hair, clothes, beard, glasses, earrings, chain...) and show off new tiles, tables and glasses from the wardrobe, bought with the pesos you earn by playing. They are purely cosmetic: they never give an advantage.
```

**Notas de traducción:** «chivo» se deja en español (es el nombre del juego dentro del
juego y suena bien como grito); «capicúa» también. Si se prefiere, en inglés se puede
añadir la primera vez «the Chivo (a sneaky cheat)». Los nombres de cartas en inglés
(«Strong Double», «Light Hand», «Sharp Eye») son propuestas: el juego todavía no tiene
inglés y habrá que usar los mismos al traducirlo.

---

## 4. Lista de características (para la sección de características o una imagen)

| Español | English |
|---|---|
| Dominó dominicano por parejas: doble seis, 7 fichas, 2 contra 2, meta de 100 puntos | Dominican partner dominoes: double-six, 7 tiles, 2 vs 2, race to 100 |
| Robas tus 7 fichas de la mesa, boca abajo | Draw your 7 tiles face down from the table |
| El chivo: mete trampa o cázala cantando «¡CHIVO!» | The Chivo: sneak a cheat or catch one by calling "CHIVO!" |
| 8 cartas de aumento que se acumulan durante toda la partida | 8 boost cards that stack for the whole match |
| 4 bebidas que rompen las reglas, compradas con lo que ganas | 4 rule-bending drinks bought with your winnings |
| Salas con amigos por código de 6 letras | Friends rooms with a 6-letter code |
| Bots que juegan en pareja y rellenan sillas vacías | Team-playing bots that fill empty chairs |
| Juego cruzado PC ↔ móvil | PC ↔ mobile cross-play |
| Partida en solitario sin conexión | Offline solo matches |
| Colmado 3D con aspecto pixel art y fichas en alta definición | Pixel art look 3D corner store with HD tiles |
| Hasta 3 personajes personalizables | Up to 3 custom characters |
| Fichas, mesas y vasos solo estéticos, ganados jugando | Cosmetic-only tiles, tables and glasses, earned by playing |
| Libreta del colmadero con las estadísticas de la partida | Shopkeeper's notebook with match stats |

**[PENDIENTE] no anunciar todavía:** inglés (el juego aún está solo en español; ver
«Riesgos»), Reto del día, chat rápido, música, mando completo, Steam Deck verificado,
logros y Steam Cloud.

---

## 5. Etiquetas de Steam recomendadas

Steam deja poner hasta 20; las 5 primeras son las que más pesan. Elegirlas en el
asistente de etiquetas de Steamworks; los nombres de abajo son los de la interfaz en
inglés. **Sin comprobar una a una:** confirmar que cada etiqueta existe en el asistente
(sobre todo las marcadas con *).

| # | Etiqueta | Por qué |
|---|---|---|
| 1 | Board Game | El núcleo es un juego de mesa (dominó). Es lo primero que debe entender quien ve la página. |
| 2 | Roguelite | Aumentos acumulables y bebidas: cada partida es una build distinta. Es el giro que lo separa de los dominós clásicos. |
| 3 | Multiplayer | Pensado para 4 personas en parejas. |
| 4 | Card Game | Las cartas de aumento son una decisión central en cada mano. |
| 5 | Pixel Graphics | Estilo visual; atrae a público que filtra por pixel art. |
| 6 | Tabletop | Refuerza «juego de mesa» para quien busca dominó, cartas o parchís. |
| 7 | Online Co-Op | Juegas en pareja con un amigo contra otra pareja. |
| 8 | PvP | Dos parejas se enfrentan. |
| 9 | Turn-Based | Dominó por turnos (con 30 s por turno online). |
| 10 | Strategy | Tapar, contar fichas y elegir cartas. |
| 11 | Casual | Reglas que se entienden en un minuto. |
| 12 | 3D | La escena es 3D (con aspecto pixel art); evita quejas de quien espera 2D puro. |
| 13 | Cozy* | Ambiente de colmado de noche, sin violencia. |
| 14 | Funny | Reacciones de los personajes, chivos, ron. |
| 15 | Cross-Platform Multiplayer* | Juego cruzado PC ↔ móvil (si existe como etiqueta; si no, solo como función en la ficha). |
| 16 | Singleplayer | Se puede jugar entero contra bots. |
| 17 | Local Multiplayer — **no ponerla** | El juego no tiene multijugador en el mismo equipo. |
| 18 | Bluffing* / Social Deduction — **dudosa** | El chivo es un farol, pero no es un juego de deducción social; mejor no para no atraer al público equivocado. |

Orden recomendado de las 5 primeras: Board Game, Roguelite, Multiplayer, Card Game,
Pixel Graphics.

---

## 6. Requisitos mínimos orientativos

**Orientativos, sin medir.** El juego usa el renderizador «GL Compatibility» de Godot 4.7
(OpenGL 3.3), dibuja la escena a 640×360 y ocupa unos pocos MB de código y arte. Hay que
medir la versión exportada en un PC modesto antes de publicarlos.

| | Español | English |
|---|---|---|
| Sistema | Windows 10 de 64 bits | Windows 10 64-bit |
| Procesador | Doble núcleo a 2 GHz | Dual core 2 GHz |
| Memoria | 4 GB de RAM | 4 GB RAM |
| Gráficos | Compatible con OpenGL 3.3 (Intel HD Graphics 4000 o superior) | OpenGL 3.3 compatible (Intel HD Graphics 4000 or better) |
| Almacenamiento | 300 MB disponibles | 300 MB available space |
| Red | Conexión a Internet de banda ancha para jugar online | Broadband Internet connection for online play |
| Notas | Partida en solitario sin conexión | Solo play works offline |

Recomendados: no hacen falta para un juego de este tamaño; si Steam los pide, repetir los
mínimos con 8 GB de RAM.

**Steam Deck:** no se debe marcar nada todavía. Falta probar 1280×800, control solo con
mando y textos legibles (ver `ESTADO.md`).

---

## 7. Riesgos (Steam)

1. **Juego de azar.** Colmadón no permite apostar dinero real ni nada con valor real.
   Las «monedas» de la partida solo compran bebidas dentro de esa partida y se pierden al
   acabar; los «pesos» del armario se ganan jugando y solo compran cosméticos. No hay
   cajas de botín. Presentarlo siempre así: «sin dinero real, sin apuestas». En la
   encuesta de contenido de Steam no hay nada que marcar por apuestas; no usar las
   palabras «bet», «wager», «casino» ni «gamble» en la página.
2. **Alcohol.** El Ron es una bebida alcohólica que los personajes se beben (con mejillas
   coloradas y mareo de cámara). Steam no lo prohíbe y no hace falta marcarlo como
   contenido para adultos, pero afecta a las clasificaciones por edad (ver
   `google_play.md`, apartado de clasificación). En la página, describirlo como mecánica
   («mano caliente») y no como premio por beber; no poner bebidas alcohólicas en las
   cápsulas.
3. **Idioma inglés.** Si la página sale en inglés pero el juego solo está en español, las
   reseñas lo castigarán. Marcar en Steamworks **solo español** hasta que esté la
   traducción, o terminar el inglés antes de abrir la página «Próximamente» en inglés.
4. **«Chivo» = trampa.** Es una regla del juego, no una trampa contra el sistema. Dejar
   claro en la descripción que «hacer trampa forma parte del juego» para que nadie piense
   que hay tramposos online.
5. **Nombres de jugador libres.** Los jugadores escriben su nombre (16 caracteres) y lo
   ven los demás de la sala. Steam no exige moderación para salas privadas, pero conviene
   un filtro de palabrotas antes del lanzamiento.
6. **Conexión sin cifrar.** Hoy el juego habla con el servidor por `http` (sin TLS).
   Antes de publicar, pasar a `https`/`wss` (ver `google_play.md`).
