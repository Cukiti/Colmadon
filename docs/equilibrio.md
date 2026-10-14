# Equilibrio de cartas y bebidas (2026-10-03)

Informe de las simulaciones con bots de `tests/simulacion_equilibrio.gd` y de los
ajustes de números aplicados en `scripts/game.gd`. No se ha cambiado ninguna regla
ni nada visual.

## Cómo se mide

```
godot --headless --path . --script res://tests/simulacion_equilibrio.gd -- n=3000 seed=1
```

Opciones: `n=` partidas por experimento, `seed=` semilla, `rapido` (solo
secciones 1, 2 y 4), `secciones=1,2,4,5` (elige experimentos). Con `n=3000` juega
unas 66.000 partidas en ~4 minutos.

Solo carga `scripts/game.gd`; los cuatro asientos juegan con `bot_turn()`. La pareja
«de prueba» cambia de asiento en cada partida para anular la ventaja de salida.
Con 3.000 partidas, el margen de error de cada tasa es de ±0,9 puntos (una
desviación típica); las diferencias de menos de 2 puntos son ruido.

| Experimento | Qué hace |
|---|---|
| 1. Línea base | Cartas al azar y compras como los bots (70 % de compras entre café, ron y agua) para los 4 asientos. Mide finales de mano y duración. |
| 2. Carta sola | La pareja de prueba solo tiene la carta X; la otra ninguna. Es el valor puro de la carta. |
| 3. Preferir carta | La pareja de prueba coge X siempre que se la ofrecen; la otra no la coge nunca. Es la decisión real del jugador: si una carta fuese «siempre la mejor», aquí se vería lejos del 50 %. |
| 4. Bebida sola | La pareja de prueba compra solo X (todo lo que puede, máximo 2); la otra no compra. Rendimiento = puntos de victoria ganados por cada 10 monedas gastadas. |
| 5. Bebida contra bebida | Una pareja compra solo X y la otra solo Y. |

**Limitación importante:** «Ojo pícaro» y «Morir soñando» dan información solo al
asiento 0 (`revealed` y `reveal_partner`), y los bots no la usan. Con bots su efecto
es cero por diseño, así que la simulación no puede medirlas; sus números no se han
tocado. Su valor real depende de cómo juegue la persona.

## Resumen

| Medida | Antes | Después | Objetivo |
|---|---|---|---|
| Manos que acaban en dominó | 67,0 % | 66,8 % | — |
| Manos que acaban en tranque | 25,3 % | 26,1 % | — |
| Manos que acaban en chivo cantado | **7,7 %** | **7,1 %** | < 10 % ✔ |
| Duración media de una partida | 4,14 manos | 4,28 manos | — |
| Mejor carta (preferir frente a evitar) | Mano ligera **62,0 %** | Cierre ruidoso 52,6 % | ninguna dominante ✔ |
| Diferencia entre la mejor y la peor carta (preferir) | 16,4 puntos | 4,3 puntos | ✔ |
| Mejor bebida cara a cara | Café: 70,6 % contra el Ron y 59,3 % contra el Agua | Café y Agua 47/53 entre sí | ninguna dominante ✔ |
| Rendimiento por 10 monedas (café / ron / agua) | +5,4 / +1,6 / +3,9 | +3,9 / +2,9 / +3,5 | parecido ✔ |

Duración de la partida (línea base, % de partidas):

| Manos | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9+ |
|---|---|---|---|---|---|---|---|---|---|
| Antes | 3,6 | 10,7 | 21,3 | 24,2 | 21,0 | 12,7 | 5,1 | 1,3 | 0,2 |
| Después | 3,0 | 8,9 | 19,8 | 25,0 | 21,8 | 13,6 | 6,0 | 1,6 | 0,2 |

## Cartas de aumento

### Carta sola frente a ninguna carta (tasa de victoria de la pareja que la tiene)

| Carta | Antes | Después | Margen pts/mano antes → después |
|---|---|---|---|
| (control: nadie tiene cartas) | 50,4 % | 50,1 % | −0,7 → +0,9 |
| Doble fuerte | 51,4 % | 52,9 % | +0,5 → +2,1 |
| Capicúa | 53,5 % | 53,5 % | +2,3 → +2,5 |
| Cierre ruidoso | 56,4 % | 53,7 % | +5,4 → +2,5 |
| Pasador | 51,5 % | 53,7 % | +1,7 → +1,2 |
| Bolsillo | 50,3 % | 52,3 % | −0,5 → +0,7 |
| Ojo pícaro *(no medible con bots)* | 49,3 % | 49,6 % | −1,0 → −0,3 |
| **Mano ligera** | **67,2 %** | 51,7 % | **+9,7** → +0,4 |
| Fiado | 50,9 % | 53,4 % | −0,3 → +2,1 |

### Preferir la carta frente a evitarla (partida normal)

| Carta | Antes | Después |
|---|---|---|
| Doble fuerte | 47,9 % | 50,0 % |
| Capicúa | 49,0 % | 50,8 % |
| Cierre ruidoso | 52,4 % | 52,6 % |
| Pasador | 47,6 % | 50,2 % |
| Bolsillo | 47,1 % | 49,3 % |
| Ojo pícaro *(no medible con bots)* | 45,6 % | 48,3 % |
| **Mano ligera** | **62,0 %** | 49,6 % |
| Fiado | 48,9 % | 48,8 % |

Antes, casi todas las cartas salían por debajo del 50 % en esta prueba porque quien
«prefería» otra carta dejaba pasar «Mano ligera», que era la estrategia dominante.
Ahora todas quedan entre 48 % y 53 %: elegir una u otra depende de la partida.

### Observacional (línea base): manos que gana la pareja que tiene la carta cuando la otra no

| Carta | Antes | Después |
|---|---|---|
| Doble fuerte | 48,8 % | 49,5 % |
| Capicúa | 48,7 % | 50,0 % |
| Cierre ruidoso | 48,4 % | 49,0 % |
| Pasador | 49,3 % | 50,6 % |
| Bolsillo | 49,8 % | 49,3 % |
| Ojo pícaro | 49,3 % | 49,8 % |
| Mano ligera | **57,7 %** | 51,1 % |
| Fiado | 49,6 % | 50,8 % |

(Esta tabla mide cada mano por separado, con unas 10.000 manos por carta. Las
cartas de puntos y de monedas apenas mueven quién gana la mano, pero sí cuántos
puntos o monedas se llevan; por eso el valor de verdad está en las tablas
anteriores.)

## Bebidas

### Bebida sola frente a no comprar

| Bebida | Precio antes → después | Victoria antes → después | Monedas gastadas/partida | Usos/partida | Puntos de victoria por 10 monedas antes → después |
|---|---|---|---|---|---|
| (mezcla de los bots) | — | 62,0 % → 60,1 % | 27,2 → 28,8 | 3,2 → 3,7 | +4,4 → +3,5 |
| Café | 8 → **14** | 72,6 % → 68,6 % | 41,7 → 47,7 | 4,4 → 3,0 | **+5,4** → +3,9 |
| Ron | 6 → **4** | 55,2 % → 56,7 % | 33,5 → 23,2 | 4,3 → 5,1 | **+1,6** → +2,9 |
| Morir soñando *(no medible con bots)* | 5 → 5 | 49,3 % → 50,1 % | 16,7 → 15,9 | 0 | — |
| Agua fría | 10 → **11** | 68,2 % → 68,6 % | 46,9 → 53,4 | 4,5 → 4,9 | +3,9 → +3,5 |

### Bebida contra bebida (victoria de la fila frente a la columna)

Antes:

| | Café | Ron | Agua fría |
|---|---|---|---|
| Café | — | 70,6 % | 59,3 % |
| Ron | 29,4 % | — | 36,9 % |
| Agua fría | 40,7 % | 63,1 % | — |

Después:

| | Café | Ron | Agua fría |
|---|---|---|---|
| Café | — | 63,9 % | 47,3 % |
| Ron | 36,1 % | — | 37,7 % |
| Agua fría | 52,7 % | 62,3 % | — |

Antes el Café ganaba a todas: era la bebida dominante. Ahora Café y Agua fría están
igualados y cada uno tiene su momento (el café para cerrar una mano corta, el agua
para frenar a un rival con pocas fichas).

El Ron sigue perdiendo cara a cara porque solo caben 2 bebidas: aunque sea barato, su
efecto por uso es pequeño (cambia una ficha alta por una al azar y además el que lo
bebe caza menos chivos). Por moneda ya rinde casi como las demás (+2,9 frente a +3,5
y +3,9), así que es la opción buena cuando hay pocas monedas. Bajarlo más no ayuda:
el límite son los huecos, no el precio. Para que compita cara a cara haría falta
cambiar su efecto, y eso es una regla (fuera de esta tarea).

## Cambios aplicados en `scripts/game.gd` y por qué

| Qué | Antes | Después | Por qué |
|---|---|---|---|
| Mano ligera (puntos que se restan en tranque) | 6 | **1** | Era la estrategia dominante (+17 puntos de victoria sola, 62 % al preferirla). Un 26 % de las manos acaba en tranque y lo gana el jugador con menos puntos; en un tranque las diferencias entre jugadores son pequeñas, así que restar 6 le daba la mano casi siempre. Con 2 seguía en +8; con 1 desempata a su favor y queda en línea con las demás. |
| Cierre ruidoso (puntos al dominar) | 10 | **6** | Fue la carta más fuerte en todas las rondas (+6 puntos de victoria) porque se activa en dos de cada tres manos. |
| Doble fuerte (puntos al dominar con doble) | 15 | **30** | Casi no se notaba (+1): dominar con un doble es poco frecuente, así que el premio tiene que ser grande. |
| Pasador (monedas al pasar) | 2 | **4** | Por debajo de la media; las monedas solo valen si compran bebidas y el café subió de precio. |
| Bolsillo (monedas extra al ganar) | 4 | **8** | No se notaba (+0): 4 monedas eran menos de media bebida. |
| Fiado (descuento en bebidas) | 2 | **3** | Con los nuevos precios, 2 monedas eran poco. Con 3 el Ron le sale a 1 moneda (nunca a 0 o menos). |
| Café (precio) | 8 | **14** | Bebida dominante: ganaba a todas cara a cara y rendía más por moneda (+5,4). A 11 seguía rindiendo más que el resto (+4,8 por 10 monedas); a 14 rinde como las demás. |
| Ron (precio) | 6 | **4** | Era la que menos rendía por moneda (+1,6). No se baja más para que con Fiado no salga gratis. |
| Agua fría (precio) | 10 | **11** | Al encarecer el café, a 9-10 el agua pasaba a ganarle (55 %). A 11 quedan igualados (53/47). |

Los textos de las cartas (`desc`) y de los bonus (`bonus.append`) se han actualizado
con los nuevos números para que la interfaz muestre lo correcto.

**No se ha cambiado:** las probabilidades del chivo (los bots meten chivo el 4 % de
las veces que no llevan, pasan con ficha el 0,4 % y cazan el 60 % o el 20 % con
ron), porque el chivo ya acaba solo el 7,1 % de las manos (objetivo: menos de 10 %).
Tampoco las monedas por mano (10 / 4), la meta de 100 puntos, la multa de falsa
alarma, «Capicúa» (+25, ya en la media), «Ojo pícaro» ni «Morir soñando».

## Pendiente y riesgos

- **Bots, no personas.** Los bots eligen cartas al azar, compran al azar y no usan la
  información de «Ojo pícaro» ni «Morir soñando». Una persona sacará más partido de
  estas dos; conviene repetir el estudio cuando haya datos de partidas reales.
- **El Ron sigue siendo la bebida más floja cara a cara** (ver arriba).
- El ritmo de la partida apenas cambia (4,1 → 4,3 manos de media): los bonus de puntos
  bajaron en unas cartas y subieron en otras.

## Efectos nuevos de Mano ligera y Ron (2026-10-03, segunda ronda)

Con −1 punto en el tranque, «Mano ligera» solo desempataba, y el Ron (cambiar tu
ficha más alta por una al azar) era la bebida más floja. El usuario eligió efectos
nuevos y se midieron con `n=1500 seed=2 secciones=1,2,4,5`:

| Variante | Mano ligera sola | Ron solo | Ron: pp por 10 monedas | Manos por partida |
|---|---|---|---|---|
| Ligera ½ · Ron +50 % para quien gane | 59,4 % (dominante) | 53,2 % | +2,1 | 3,89 |
| Ligera ⅓ · Ron +50 % para quien gane | 56,7 % | 50,7 % | +0,5 | 3,75 |
| Ligera ¼ · Ron +100 % para quien gane | 53,4 % | 53,9 % | +2,6 | 3,34 (demasiado cortas) |
| **Ligera ¼ · Ron +50 % solo si gana su pareja** (elegida) | **53,9 %** | **55,9 %** | **+3,8** | 3,85 |

Referencia, misma tanda: Café 68,5 % (+3,5), Agua fría 69,2 % (+3,3); el resto de
cartas entre 52 % y 56 %.

- **Mano ligera:** si tu pareja pierde la mano, tus fichas cuentan un 25 % menos
  para los rivales (redondeado). No cambia quién gana el tranque.
- **Ron (mano caliente):** si la pareja que lo bebió gana esa mano, +50 % de los
  puntos (después de restar Mano ligera). Varios rones en la misma mano no se suman.
  Los bots lo beben cuando su pareja lleva menos fichas que los rivales.
- El Ron sigue perdiendo cara a cara (36 % contra Café, 34 % contra Agua) porque solo
  caben 2 bebidas, pero es la que más rinde por moneda: la buena cuando vas justo.
- Las partidas se acortan un poco (4,3 → 3,9 manos de media).

## Cartas nuevas: Ficha marcada, Doble suerte y Tranque seguro (2026-10-04)

Tres cartas nuevas en `scripts/game.gd` (`CARDS`) con el mismo comportamiento en
`servidor/modulo/src/reglas.ts`. Partió de la rama `wip-cartas-nuevas`, que se
revisó y se rehízo en parte (ver «Qué se cambió del borrador»). Medido con
`n=1500 seed=2 secciones=1,2,3` (antes = master, después = esta rama) y confirmado
con `n=3000 seed=1 secciones=2,3 cartas=marcada,suerte,tranque`. La opción nueva
`cartas=` limita los experimentos 2 y 3 a esas cartas.

| Carta | Entrada | Acción | Resultado | Número |
|---|---|---|---|---|
| Ficha marcada | Un rival pasa y la última ficha de la mesa es tuya | Se apunta el pase; además ves todos los números a los que ha pasado cada rival | Si gana tu pareja, se suman los puntos al final de la mano | +3 por pase (`MARK_PTS`) |
| Doble suerte | Juegas un doble y llevas el doble de la otra punta | Ese segundo doble se juega solo, en el mismo turno | Sueltas una ficha más | +1 ficha (como mucho una: después ya no casa ninguno) |
| Tranque seguro | La mano acaba en tranque y lo gana la otra pareja | Se comparan las dos manos de cada pareja juntas | Si la tuya suma menos, ganáis vosotros (lo cobra tu jugador con menos puntos) | Desempate: no cambia nada si las parejas suman igual |

**Ficha marcada y los bots.** Los bots ya usaban `lacks` (todos los pases) para
tapar a los rivales, así que la información no les cambiaba nada. Ahora cada bot
recuerda de un rival solo su **último pase** (`last_pass`); con la carta, todos
(`seen_lacks(viewer, target)` en game.gd, `rPasesVistos` en reglas.ts). Del
compañero lo recuerdan todo, como antes. Medido, la información sola vale poco con
estos bots (51,1 % sola y 48,6 % al preferirla incluso si sin la carta no
recordaran ningún pase), por eso la carta suma además puntos por cada pase que
provoca.

### Variantes probadas (n=1500, seed=2)

| Variante | Sola | Preferir | |
|---|---|---|---|
| Ficha marcada: solo información (sin carta, recuerdas el último pase) | 50,1 % | 47,8 % | floja |
| Ficha marcada: solo información (sin carta, no recuerdas nada) | 51,1 % | 48,6 % | floja y empeora a todos los bots |
| Ficha marcada: información + 2 por pase | 51,5 % | 50,3 % | |
| **Ficha marcada: información + 3 por pase** (elegida) | **52,5 %** | **51,6 %** | |
| Ficha marcada: información + 5 por pase | 59,0 % | 53,7 % | demasiado |
| Doble suerte: 1 vez por mano, al jugar un doble vuelves a jugar | 74,6 % | 64,5 % | dominante |
| Doble suerte: 1 vez por partida, al jugar un doble vuelves a jugar | 58,5 % | 56,5 % | dominante |
| **Doble suerte: el doble de la otra punta se juega solo** (elegida) | **54,1 %** | **50,4 %** | |
| **Tranque seguro: gana la pareja que suma menos** (elegida) | **54,7 %** | **51,2 %** | |

Jugar una ficha de más es lo que más vale en este dominó (el Café cuesta 14
monedas por hacerlo una vez): por eso «vuelves a jugar» era dominante incluso una
sola vez por partida. Con la condición del doble de la otra punta pasa en pocas
manos y es un momento de suerte, no una estrategia.

### Resultado final: preferir la carta frente a evitarla (las 11 cartas)

| Carta | Antes (8 cartas) | Después (11 cartas) | Confirmación n=3000 |
|---|---|---|---|
| Doble fuerte | 50,5 % | 49,4 % | |
| Capicúa | 48,6 % | 49,2 % | |
| Cierre ruidoso | 50,7 % | 49,4 % | |
| Pasador | 50,5 % | 51,4 % | |
| Bolsillo | 50,0 % | 50,6 % | |
| Ojo pícaro *(no medible con bots)* | 49,0 % | 48,0 % | |
| Mano ligera | 53,7 % | 51,6 % | |
| Fiado | 48,9 % | 51,3 % | |
| **Ficha marcada** | — | 50,7 % | **49,8 % ± 0,9** |
| **Doble suerte** | — | 50,9 % | **51,1 % ± 0,9** |
| **Tranque seguro** | — | 52,0 % | **53,4 % ± 0,9** |

### Carta sola frente a ninguna carta

| Carta | Antes | Después | Margen pts/mano antes → después | Confirmación n=3000 |
|---|---|---|---|---|
| (control: nadie tiene cartas) | 48,7 % | 48,3 % | −0,5 → −0,3 | 51,1 % |
| Doble fuerte | 51,5 % | 52,3 % | +2,4 → +1,7 | |
| Capicúa | 52,4 % | 52,0 % | +2,4 → +2,6 | |
| Cierre ruidoso | 53,9 % | 54,6 % | +3,3 → +4,2 | |
| Pasador | 52,5 % | 52,1 % | +0,8 → +0,8 | |
| Bolsillo | 53,6 % | 54,3 % | +1,9 → +2,5 | |
| Ojo pícaro *(no medible con bots)* | 54,6 % | 49,2 % | +3,0 → −1,7 | |
| Mano ligera | 53,9 % | 53,5 % | +3,9 → +5,0 | |
| Fiado | 51,5 % | 50,4 % | 0,0 → −0,4 | |
| **Ficha marcada** | — | 55,0 % | → +5,2 | 53,9 % |
| **Doble suerte** | — | 54,7 % | → +2,6 | 52,8 % |
| **Tranque seguro** | — | 52,9 % | → +2,7 | 53,7 % |

Con 1.500 partidas el margen de error es ±1,3 puntos (Ojo pícaro, que no hace
nada con bots, sale entre 49 % y 55 % según la tanda): solo cuentan diferencias de
más de 3 puntos.

### Línea base (cartas al azar)

| Medida | Antes | Después |
|---|---|---|
| Manos que acaban en dominó | 66,2 % | 66,2 % |
| Manos que acaban en tranque | 25,8 % | 25,6 % |
| Manos que acaban en chivo cantado | 7,9 % | 8,2 % |
| Duración media | 3,85 manos | 3,77 manos |
| Observacional: manos que gana la pareja con la carta | — | Ficha marcada 49,6 %, Doble suerte 50,9 %, Tranque seguro 53,2 % |

Tranque seguro es la que más cambia quién gana la mano (53,2 %), porque da la mano
entera; queda cerca del tope (53,4 % al preferirla), así que si con personas se ve
fuerte, el primer ajuste sería exigir que la pareja sume al menos 5 puntos menos.

### Qué se cambió del borrador (`wip-cartas-nuevas`)

- **Ficha marcada:** el borrador daba +4 por pase y un peso extra al bot, pero los
  bots ya veían todos los pases, así que la parte de «ver» no medía nada. Ahora sin
  la carta se recuerda solo el último pase de cada rival, el peso extra del bot se
  quitó y el premio bajó a +3.
- **Doble suerte:** el borrador mezclaba dos efectos (jugar otra vez una vez por
  partida y, si perdías, dobles que contaban el doble). El primero era dominante
  (58,5 %) y el segundo un castigo. Se rehízo con un solo efecto.
- **Tranque seguro:** se mantuvo; el texto se acortó.
- Las pruebas de `prueba_logica.gd` y `reglas.test.ts` se rehicieron con los
  mismos casos en los dos lados (también el pase recordado con y sin la carta).

## Bots más listos (2026-10-04)

Partió de la rama `wip-bots-listos` (sin verificar), fusionada encima de las
cartas nuevas. Misma lógica en `scripts/game.gd` (`bot_turn`, `_move_score`,
`_bot_view`, `_bot_drink`, `bot_buy`, `bot_pick_card`) y en
`servidor/modulo/src/reglas.ts` (`rTurnoBot`, `rNotaJugada`, `rVistaBot`,
`rBotBebe`, `rTiendaBots`, `rBotEligeCarta`).

### Qué hace distinto el bot

| | Bot viejo | Bot nuevo |
|---|---|---|
| Qué sabe | Números a los que pasó cada uno | Además: fichas jugadas por número, sus fichas, las que vio con **Ojo pícaro** (`seen[silla]`) y la mano del compañero con **Morir soñando** (`sees_partner[silla]`). Con eso calcula, para cada jugador y número, la probabilidad de que pueda jugarlo (`_bot_view`: un número del que no queda ninguna ficha oculta está muerto) |
| Tapar | +8 / +5 si el rival ya pasó a esa punta | Probabilidad de que el rival siguiente (×16) y el otro (×6) no puedan jugar, el doble si les quedan 2 fichas o menos |
| Compañero | −7 si ya pasó a esa punta | −6 × probabilidad de dejarlo sin jugada (el doble si va a dominar) |
| Dobles | +6 siempre | +6, más 0,75 por cada ficha de su número que ya salió (el doble se suelta antes de que se quede sin salida) |
| Trancar | No lo mira | Si la ficha tranca, suma o resta 4 por punto de ventaja estimada en el tranque (máx. ±40); con **Tranque seguro** cuenta la suma de la pareja |
| Bebidas | Compra al azar entre café, ron y agua; nunca usa Morir soñando | Compra entre las 4 con pesos (café 3, agua 3, ron 2, morir 1,5; ron si va perdiendo por más de 20, agua si va ganando por más de 20; menos peso a la que ya lleva). Bebe Morir soñando al empezar, y el Agua también para que juegue antes un compañero con 1 ficha |
| Cartas | Al azar | Al azar con pesos: +0,5 a cartas de puntos si va perdiendo, a Mano ligera si va ganando, a las de monedas si tiene menos de 11; +0,3 a Ojo pícaro; la mitad si ya la tiene |
| Chivo | Mete el 4 % de las veces que no lleva, pasa con ficha el 0,4 %, caza el 60 % (20 % con ron) | **Igual** |

En `game.gd`, `revealed` y `reveal_partner` siguen siendo solo lo que ve la persona
de la silla 0; los bots usan `seen` y `sees_partner`, por silla, como el servidor.
La memoria de pases de «Ficha marcada» se respeta: sin la carta, de un rival solo
se recuerda su último pase.

**Paridad game.gd ↔ reglas.ts:** `tests/paridad_bots.gd` guarda 400 estados de
partidas reales (1.214 jugadas, con todas las cartas) en
`servidor/modulo/tests/paridad_bots.json`, con la nota de cada jugada sin azar
(`bot_noise = 0`). `npm test` comprueba que `rNotaJugada` da la misma nota
(diferencia < 10⁻⁶): **0 fallos**. Si se toca la lógica de los bots, hay que
volver a generar el archivo.

### Bot nuevo contra bot viejo (cambiando de asiento, `secciones=6`)

| Prueba | n=1500, seed=2 | n=3000, seed=1 |
|---|---|---|
| Completo (juego, cartas y compras nuevos) | 59,1 % | **60,6 % ± 0,9** |
| Solo la forma de jugar (mismas cartas y compras) | 60,3 % | 59,9 % |
| Sin cartas ni bebidas | 60,1 % | 60,0 % |
| Las dos parejas con Ojo pícaro, sin bebidas | 57,7 % | 59,2 % |
| Las dos parejas solo con Morir soñando | 68,9 % | 67,1 % |

Dentro del objetivo (55–65 %): mejor, pero no imbatible. Con Morir soñando la
diferencia es mayor porque el bot viejo nunca la bebía.

### Línea base (secciones 1, 2 y 3: n=1500, seed=2)

Antes = bot viejo con las cartas nuevas; después = bot nuevo. La línea base de
después usa la elección de cartas del bot (`cards: "bot"`); la de antes, al azar.

| Medida | Antes | Después |
|---|---|---|
| Manos que acaban en dominó | 66,2 % | 56,8 % |
| Manos que acaban en tranque | 25,6 % | **33,7 %** |
| Manos que acaban en chivo cantado | 8,2 % | 9,5 % |
| Duración media | 3,77 manos | 3,51 manos |

- **Más tranques:** el bot tapa mucho mejor y los rivales se quedan sin jugada más
  a menudo. No es por buscar el tranque: con el peso de trancar a la mitad
  (`BOT_LOCK` 4 → 2) los tranques siguen en 34,6 %.
- **Chivo:** las probabilidades son las mismas (mete chivo en el 2,6 % → 2,8 % de
  los turnos sin jugada, 800 partidas). Sube porque hay más turnos sin jugada por
  mano (3,07 → 3,68). Sigue por debajo del 10 %.

### Preferir la carta frente a evitarla

| Carta | Antes | Después |
|---|---|---|
| Doble fuerte | 49,4 % | 50,7 % |
| Capicúa | 49,2 % | 48,1 % |
| Cierre ruidoso | 49,4 % | 49,2 % |
| Pasador | 51,4 % | 48,7 % |
| Bolsillo | 50,6 % | 51,6 % |
| Ojo pícaro *(ahora sí la usan los bots)* | 48,0 % | 49,7 % |
| Mano ligera | 51,6 % | 48,8 % |
| Fiado | 51,3 % | 52,1 % |
| Ficha marcada | 50,7 % | 49,9 % |
| Doble suerte | 50,9 % | 48,3 % |
| Tranque seguro | 52,0 % | 50,2 % |

### Carta sola frente a ninguna carta

| Carta | Antes | Después |
|---|---|---|
| (control) | 48,3 % | 48,9 % |
| Doble fuerte | 52,3 % | 50,0 % |
| Capicúa | 52,0 % | 50,3 % |
| Cierre ruidoso | 54,6 % | 51,7 % |
| Pasador | 52,1 % | 51,6 % |
| Bolsillo | 54,3 % | 51,3 % |
| Ojo pícaro | 49,2 % | 48,1 % |
| Mano ligera | 53,5 % | 53,6 % |
| Fiado | 50,4 % | 50,0 % |
| Ficha marcada | 55,0 % | 55,0 % |
| Doble suerte | 54,7 % | 52,2 % |
| Tranque seguro | 52,9 % | 54,1 % |

### Bebidas (secciones 4 y 5: n=1500, seed=2)

| Bebida | Victoria sola antes → después | pp por 10 monedas antes → después | Usos por partida antes → después |
|---|---|---|---|
| (mezcla de bot) | 61,7 % → 57,7 % | +5,1 → +3,5 | 2,15 → 2,48 |
| Café | 64,8 % → 61,7 % | +3,2 → +2,9 | 2,87 → 2,30 |
| Ron | 53,9 % → 53,7 % | +2,5 → +2,3 | 1,15 → 1,07 |
| **Morir soñando** | 49,5 % → **58,1 %** | −0,3 → **+2,9** | 0 → 4,80 |
| Agua fría | 66,7 % → 64,5 % | +3,2 → +3,6 | 4,68 → 3,61 |

Bebida contra bebida, después (antes no se medía Morir soñando):

| | Café | Ron | Agua fría | Morir soñando |
|---|---|---|---|---|
| Café | — | 57,1 % | 46,3 % | 53,1 % |
| Ron | 42,9 % | — | 40,5 % | 47,3 % |
| Agua fría | 53,7 % | 59,5 % | — | 55,5 % |
| Morir soñando | 46,9 % | 52,7 % | 44,5 % | — |

Antes: Café–Ron 59,4 %, Café–Agua 49,3 %, Agua–Ron 61,9 %.

Ninguna carta ni bebida queda dominante: las cartas entre 48 % y 52 % al
preferirlas, y Agua fría y Café siguen igualados (54/46).

### Ajustes propuestos (no aplicados)

| Qué | Ahora | Propuesta | Por qué |
|---|---|---|---|
| Ojo pícaro | 1 ficha de cada rival | **2 fichas** de cada rival | Aunque los bots ya la usan, sigue sin notarse (48,1 % sola, 49,7 % al preferirla): una ficha vista dice poco de una mano de 7. |
| Ron | 4 monedas | Sin cambio de precio; si se quiere que compita, **+75 %** en vez de +50 % | Sigue siendo la que pierde cara a cara (40–47 %); por moneda rinde como las demás (+2,3). |
| Morir soñando | 5 monedas | **6 monedas** solo si con personas se nota más | Rinde +2,9 por cada 10 monedas, como el Café, pero las personas leen la mano del compañero mejor que los bots. |
| Tranque seguro | Gana la pareja que suma menos | Exigir **5 puntos menos** si los tranques siguen en un tercio de las manos | Con más tranques, la carta se activa más (54,1 % sola; 55,3 % de manos ganadas en el observacional, la más alta). |
| Tranques en general | 33,7 % de las manos | Si se hacen pesados, bajar `BOT_W_NEXT` (16 → 12) en vez de `BOT_LOCK` | El peso de trancar no cambia nada; lo que tranca es tapar. |
