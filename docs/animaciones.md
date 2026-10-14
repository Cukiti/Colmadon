# Animaciones y movimiento de personajes (inventario, 2026-10-04)

Todo está hecho en código, sin esqueletos ni clips: cada personaje (`scripts/character.gd`) es un muñeco de bloques (cuerpo, cabeza, dos brazos con pivote en el hombro, piernas de pie con cadera y rodilla) y cada fotograma se calcula la pose sumando capas con `lerp` (interpolación suave).

## Lo que hay hoy

### Personajes (`character.gd`)
| Capa | Qué hay |
|---|---|
| **Cara** | parpadeo al azar, guiño, boca que habla (sílabas al azar o volumen de voz `talk_level`), rubor del ron |
| **Respirar** | el cuerpo sube y baja un poco siempre |
| **Estados** (`state`) | `idle` (quieto), `think` (mano a la barbilla, en su turno), `win` (brazos arriba), `lose` (cabeza gacha) |
| **Acciones** (`act`, duran 0,45–3,2 s) | `play` (poner ficha), `slam` (golpe de dominó), `tap` (tamborilear), `shuffle` (barajar), `drink` (beber con vaso y nivel que baja), `cheer`, `laugh`, `facepalm`, `thumbs` (pulgar al compañero), `standup` (todos de pie, capicúa), `wipe` (el colmadero limpia) |
| **Gestos** | `dance`, `clap`, `point`, `wave`, `stretch`, `shove` (empujar), `stagger` (tambalearse), `choca`, `brindis` |
| **Jugueteo con la ficha** (`fiddle`) | 1 repasa fichas, 2 ficha en la mano dándole vueltas, 3 estira el brazo hacia la punta |
| **Después de beber** | ron: se tambalea; agua: escalofrío; morir soñando: saltitos; café: nervio; con partículas |
| **De pie** | `stand_k` (0 sentado … 1 de pie), piernas que se estiran, caminar (`walk_amt`: piernas y brazos alternos), fichas escondidas en las manos, cabeza que sube y baja con su mirada (`head_pitch`) |
| **Tapar fichas** (`covering`) | manos sobre la bandeja |
| **Mirada** (`look_target`) | la cabeza sigue un punto (quien juega, la última ficha, quien se paró) |
| **Silla** | se queda en su sitio al levantarse y vuelve al sentarse |

### Tú (primera persona, `view3d.gd` y `pie.gd`)
- Brazos en la mesa: siguen la ficha que llevas, `tap` (contar), `drink`, `shuffle`, arrastrar.
- De pie: levantarte apartando la silla (2,4 s), sentarte al revés (1,1 s), caminar con inercia, pasos con sonido, balanceo de cabeza y de lado, inclinación en las curvas, choques con paredes, muebles y gente, empujón que te desplaza, camino automático a tu silla, manos con las fichas al pecho, bote al bailar.
- Sentado: mesa vista desde arriba, temblor de cámara.

### Mesa y colmado
- Fichas: barajar, coger del montón (vuelan a la bandeja), jugar (vuelan y caen con polvo), voltear al final, cuenta ficha a ficha, revelar mano, tapar.
- Aura de pases (fuego, chispas, anillos), bombilla que se mece, colmadero que limpia, gata (cola y cabeza), abanico, vasos en la mesa.

## Hecho (2026-10-04, noche)
- **Sillas:** cada silla nace suelta en su sitio de la mesa; al levantarse se corre 18 cm hacia atrás y al sentarse vuelve. Nunca sigue al cuerpo.
- **Clic izquierdo de pie:** a tu silla resaltada → sentarte; a una persona de pie delante y a menos de 0,95 m → **manotazo**; si no → **señalar** (marca que se abre en el suelo o la mesa y el brazo del personaje apunta allí; «¡X te señala!» si es a ti).
- **Golpe y caída (online, decide el servidor):** un golpe cada 2 s; se tambalea (cara de enfado); si venía corriendo o es el segundo en 3 s, **al suelo 3 s** (tumbado, estrellitas, cara de susto; los demás se ríen; tu cámara cae y mira al techo). Al tercer golpe en 10 s el colmadero grita «¡Respeten mi colmado!» y te manda a tu silla. A los sentados no se les puede golpear.
- **Director de animación:** prioridad por acción (jugar, beber, golpe de dominó y tambalearse no los corta un gesto; el gesto espera y va después); la misma acción a medias no se reinicia; tumbado no hace gestos.
- **Caminar y cuello:** el cuerpo mira hacia donde anda y la cabeza hacia donde mira (cuello ±70°); quieto, el cuerpo solo gira si la mirada se va lejos; marcha atrás de frente; inclinación al andar; **correr con Mayúsculas** (piernas más rápidas, más balanceo, vista más abierta).
- **Física ligera:** chocar fuerte con la mesa la sacude (bombilla y vasos tiemblan; muy fuerte se vuelca un vaso y al rato se levanta; online lo ven todos); las sillas vacías se apartan al chocar.
- **Caras:** enfado (al tambalearse), susto (al caer), risa (al reír).

## Problemas vistos
1. **Sillas que siguen al personaje (online):** en la foto del usuario las sillas acompañan a quien se levanta (en local no pasa; en estudio).
2. **Todo son `lerp` sueltos:** no hay prioridades: una acción pisa a otra (por ejemplo, beber en mitad de un gesto), y sin curvas de entrada y salida algunas se ven «a saltos».
3. **Caminar es pobre:** las piernas balancean, pero el cuerpo no se inclina, no gira antes de andar y no hay frenada.
4. **La cabeza no gira sola:** gira todo el cuerpo hacia donde miras; no hay giro de cuello.
5. **Online, algunas acciones no se ven** (beber de pie, tapar desde lejos) o se ven con retraso, sin suavizar.
6. **Sin reacción física:** chocar o empujar solo tambalea; no hay caídas, objetos que se muevan ni vasos que se vuelquen.

## Propuestas
1. **Director de animación** por personaje: estados de cuerpo (sentado, levantándose, de pie, caminando, sentándose, en el suelo, levantándose del suelo) + capas (piernas, brazos, cabeza, cara) con **prioridades** y **curvas** de entrada y salida (las acciones se encolan o mezclan, no se pisan).
2. **Locomoción mejor:** girar el cuerpo antes de andar, inclinarse al acelerar, frenada, correr (Mayúsculas), brazos opuestos a las piernas, cuello que gira solo (hasta ±70°) y luego el cuerpo.
3. **Clic izquierdo de pie:**
   - **Señalar:** apuntas con la mira y tu personaje señala ese punto (los demás ven hacia dónde); si señalas a alguien, se gira a mirarte.
   - **Golpe cómico (de cerca):** manotazo con empujón; el que lo recibe se tambalea y, según la regla que elijas, **cae al suelo** (se tumba con estrellitas y un «¡Ay!») y se levanta a los pocos segundos. Nunca hace daño de verdad.
   - **Límites:** espera entre golpes; el colmadero regaña («¡Respeten mi colmado!») y, si se abusa, multa en monedas o te manda a tu silla.
4. **Física ligera:** sillas que se apartan al chocar, vasos que se vuelcan si alguien choca fuerte con la mesa, botellas del estante que tiemblan.
5. **Expresiones:** enfado al ser golpeado, susto, risa al ver caer a otro.
6. **Online:** todas las acciones con marca de tiempo y suavizado (interpolación), y el servidor decide golpes y caídas.
