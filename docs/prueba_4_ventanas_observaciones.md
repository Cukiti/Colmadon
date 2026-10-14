# Prueba con 4 ventanas · observaciones del PR `nube/observaciones-1`

Para comprobar a mano lo que el bot no puede ver sin servidor. Marca cada casilla
y apunta al lado lo que veas mal (con captura si puedes).

## Antes de empezar

- [ ] **Servidor desplegado** con este PR (`servidor/modulo`). Sin desplegar,
      O02 (`sala_viva`), O09 y los nombres de equipo de O11 no funcionan: el
      cliente nuevo sigue jugando, pero eso no se puede comprobar.
- [ ] Abrir el proyecto una vez en Godot (regenera las traducciones).
- [ ] Abrir las 4 ventanas A–D con el código de la rama («Abrir 4 ventanas.bat»).
- [ ] En una ventana, poner las **fichas negras** en el armario (para O13).

## 1 · Sala de espera

- [ ] **O06** Al entrar, cada ventana ve la mesa **desde su propia silla** (no
      todas desde la del anfitrión), antes de pulsar ¡A JUGAR!
- [ ] **O02** El código sale tapado («• • • • • •»). «Ver código» lo enseña y
      «Ocultar código» lo vuelve a tapar. «Copiar código» copia el código bueno.
- [ ] **O11** A escribe un nombre en «Tu equipo» (pulsa Enter). Su pareja lo ve
      en su campo y los rivales lo ven en «Rivales: …». Más de 8 letras o
      símbolos raros no entran.

## 2 · Primera mano

- [ ] **O11** En el marcador sale el nombre del equipo en lugar de NOSOTROS/ELLOS.
      Las dos placas miden lo mismo.
- [ ] **O10** Al elegir aumento, quien elige primero ve «Esperando a que los
      demás elijan…» y debajo «1 de 4 listos», «2 de 4 listos»… y sube solo.
- [ ] **O07** En una ventana, **no recojas fichas** y deja que se acabe el
      tiempo: tus fichas deben volar de la mesa a la bandeja, no aparecer de golpe.
- [ ] **O13** Con fichas negras, cuando un bot «piensa» con una ficha en la mano,
      esa ficha es negra (no blanca). De pie con fichas en la mano, también.

## 3 · Durante la mano

- [ ] **O08** Desde cada silla, ponerse de pie e ir al espejo: todos se ven
      reflejados y el reflejo queda dentro del marco.
- [ ] **O14 / O12** En una ventana, deja que se acabe tu turno para quedar
      **ausente**. El cartel «ESTÁS AUSENTE» sale pequeño, debajo del cartel de
      turno, y no tapa «No llevas…», «tira un chivo» ni las placas de nombre.
- [ ] **O14** Ese cartel desaparece al pasar a la tienda y al elegir aumento.
- [ ] **O04** Volver a la pizarra: el abanico ya no tapa la esquina («Meta 100»).
      De pie, caminar cerca del abanico: chocas con él (no lo atraviesas ni hay
      una pared invisible donde estaba antes).

## 4 · Fin de la mano

- [ ] **O15** Que gane una persona y tarde **más de 15 s** en contar. Los demás
      ven cada ficha contarse cuando ella la toca, no antes. Las fichas jugadas
      quedan apartadas de las que se cuentan.
- [ ] **O16** Tras contar, las fichas de los jugadores de izquierda y derecha
      quedan **sobre la mesa**, no en sus bandejas.
- [ ] **O17** Ganar por chivo cantado, pulsar «Ver la mesa» y **no** pulsar
      Volver: al empezar la mano siguiente el aviso desaparece solo.
- [ ] **O17** Al pasar a elegir aumento, la mesa se queda como acabó la mano
      (siguen las fichas de las manos, no solo las jugadas) hasta barajar.

## 5 · Salir y volver

- [ ] **O02** Una ventana sale al inicio con la partida en marcha: aparece
      «VOLVER A LA SALA» y la devuelve a su silla. El aviso dice «Volviendo a tu
      sala…», sin código.
- [ ] **O09** Cerrar **las 4** ventanas en plena partida y esperar 1 minuto:
      la sala desaparece (en el inicio ya no sale «VOLVER A LA SALA»).
- [ ] **O09** Repetir, pero volver antes de 1 minuto: la partida sigue donde
      estaba (los bots no jugaron mientras no había nadie).

## Sin conexión (una ventana basta)

- [ ] **O05** Pizarra → «Dominó con bots» → dos folletos. «Clásico» empieza
      sin aumentos; «Con aumentos» empieza eligiendo aumento. La meta 100/200
      se cambia abajo y vale para los dos.
