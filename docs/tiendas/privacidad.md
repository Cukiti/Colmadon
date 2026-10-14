# Colmadón — política de privacidad / privacy policy

Borrador para publicar en una URL pública (Google Play la exige para el formulario de
seguridad de datos: https://support.google.com/googleplay/android-developer/answer/10787469).
Coincide con `google_play.md` (apartado 6) y con lo que hace el juego el 2026-10-04.

**Huecos que debe completar el usuario:** `[NOMBRE LEGAL]`, `[PAÍS DE RESIDENCIA]`,
`[CORREO DE CONTACTO]`, `[URL DE ESTA PÁGINA]`, `[FECHA DE PUBLICACIÓN]`, `[DÍAS DE REGISTROS]`.

**Antes de publicarla, comprobar:**
- Que la conexión con el servidor ya va cifrada (TLS). Si no, quitar la frase que lo
  afirma en el apartado 5 (la política no puede prometer algo que no se hace).
- Cuántos días guarda el registro técnico la máquina de Google Cloud (journald) y
  ponerlo en `[DÍAS DE REGISTROS]` (recomendado: limitarlo a 30).
- Que existe de verdad la forma de borrar los datos que se describe: por correo y con el
  botón «Borrar mis datos online» de Ajustes (hecho el 2026-10-04; funciona cuando el
  servidor de la nube tenga el RPC `borrar_cuenta`, es decir, tras
  `servidor/nube/actualizar.sh`).
- Esta política no es asesoramiento legal. Si el juego se dirige a la UE, conviene que la
  revise alguien que conozca el RGPD.

---

## Español

**Política de privacidad de Colmadón**
Última actualización: [FECHA DE PUBLICACIÓN]

Colmadón («el juego») es un juego de dominó desarrollado por [NOMBRE LEGAL], con
residencia en [PAÍS DE RESIDENCIA] («nosotros»). Esta política explica qué datos trata el
juego en Steam (PC) y en Google Play (Android), para qué y cómo puedes pedir que se
borren. Contacto: [CORREO DE CONTACTO].

### 1. Jugar sin conexión

Si juegas solo contra los bots, el juego **no envía ningún dato**. Tus personajes, tus
pesos, tus cosméticos y tus ajustes se guardan únicamente en tu dispositivo. Si
desinstalas el juego, se borran.

### 2. Qué datos tratamos cuando juegas online

Solo cuando entras en «Sala con amigos»:

| Dato | Para qué | Cuánto tiempo |
|---|---|---|
| **Identificador del dispositivo** (el que da el sistema a esta app) | Crear tu cuenta de juego automáticamente, sin correo ni contraseña, y reconocerte la próxima vez | Mientras exista tu cuenta |
| **ID de usuario** y un nombre de usuario aleatorio que crea el servidor | Identificar tu cuenta de juego | Mientras exista tu cuenta |
| **Nombre de jugador** que eliges (máx. 16 caracteres) | Mostrarlo en la mesa a los demás jugadores de tu sala | Solo durante la partida (no se guarda) |
| **Aspecto de tu personaje** (piel, pelo, ropa, accesorios) | Que los demás vean tu personaje | Solo durante la partida (no se guarda) |
| **Jugadas y estadísticas de la partida** (fichas, pases, cartas, bebidas, puntos) | Que el servidor aplique las reglas y muestre el resultado | Solo durante la partida (no se guardan) |
| **Dirección IP y datos técnicos de conexión** | Hacer funcionar la conexión y resolver errores | En el registro técnico del servidor: [DÍAS DE REGISTROS] días |

No pedimos tu nombre real, correo, teléfono, ubicación, contactos, fotos ni micrófono.
El juego no tiene anuncios, no tiene compras con dinero real y no usa herramientas de
analítica ni de publicidad.

### 3. Con quién se comparten

- **Otros jugadores de tu sala** ven tu nombre de jugador y el aspecto de tu personaje.
- **Google Cloud** aloja nuestro servidor en **Estados Unidos** (región us-central1).
  Actúa como proveedor de servicios: guarda y procesa los datos solo por cuenta nuestra.
- **Valve (Steam)** y **Google (Google Play)** tratan los datos de tu compra y de tu
  cuenta en sus tiendas según sus propias políticas de privacidad; nosotros no recibimos
  esos datos.

No vendemos tus datos ni los compartimos con nadie más, salvo que lo exija la ley.

### 4. Transferencias internacionales

El servidor está en Estados Unidos. Si juegas desde otro país (por ejemplo, de la Unión
Europea), tus datos online viajan a EE. UU. para que el juego funcione (ejecución del
servicio que pides al entrar en una sala).

### 5. Seguridad

La conexión entre el juego y el servidor va cifrada. El servidor solo abre el puerto del
juego y la base de datos no es accesible desde Internet. Ningún sistema es 100 % seguro,
pero tratamos el mínimo de datos posible.

### 6. Tus derechos y cómo borrar tus datos

Puedes pedir en cualquier momento ver, corregir o **borrar** tu cuenta de juego online y
sus datos:
- **desde el juego**, en Ajustes > «Borrar mis datos online». Tras confirmar, el servidor
  borra al momento tu cuenta, su identificador del dispositivo y todo lo que cuelga de
  ella, sin guardar ningún registro de la cuenta borrada. El juego olvida también el
  identificador: si vuelves a jugar online, se crea una cuenta nueva sin relación con la
  anterior. Tus personajes, pesos y ajustes siguen en tu dispositivo (se borran al
  desinstalar el juego);
- escribiendo a [CORREO DE CONTACTO] con el asunto «Borrar mis datos de Colmadón» e
  indicando, si puedes, el nombre de jugador que usas y la plataforma (Steam o Android).

Si lo pides por correo, borraremos la cuenta y su identificador en un plazo máximo de 30
días. Los registros
técnicos se borran solos al cumplir [DÍAS DE REGISTROS] días. Si vives en la UE o en otro
lugar con leyes de protección de datos, también puedes reclamar ante tu autoridad de
protección de datos.

Base legal (para usuarios de la UE): ejecución del servicio que pides (jugar online) e
interés legítimo en mantener el servidor funcionando y seguro.

### 7. Menores

Colmadón no está dirigido a menores de 13 años y no recogemos a sabiendas datos de
menores de esa edad. Si crees que un menor nos ha dado datos, escríbenos y los borraremos.

### 8. Cambios

Si cambiamos lo que hace el juego con tus datos (por ejemplo, al añadir compras,
clasificaciones o estadísticas), actualizaremos esta página y la fecha de arriba antes de
que el cambio llegue al juego.

Esta política está publicada en [URL DE ESTA PÁGINA].

---

## English

**Colmadón Privacy Policy**
Last updated: [FECHA DE PUBLICACIÓN]

Colmadón ("the game") is a dominoes game developed by [NOMBRE LEGAL], based in
[PAÍS DE RESIDENCIA] ("we", "us"). This policy explains what data the game processes on
Steam (PC) and Google Play (Android), why, and how you can ask us to delete it.
Contact: [CORREO DE CONTACTO].

### 1. Playing offline

If you play solo against bots, the game **sends no data at all**. Your characters,
pesos, cosmetics and settings are stored only on your device. Uninstalling the game
deletes them.

### 2. What data we process when you play online

Only when you enter "Friends room":

| Data | Purpose | How long |
|---|---|---|
| **Device identifier** (the one the system gives this app) | Create your game account automatically, with no email or password, and recognise you next time | While your account exists |
| **User ID** and a random username created by the server | Identify your game account | While your account exists |
| **Player name** you choose (max. 16 characters) | Show it at the table to the other players in your room | Only during the match (not stored) |
| **Character appearance** (skin, hair, clothes, accessories) | Let the others see your character | Only during the match (not stored) |
| **Moves and match statistics** (tiles, passes, cards, drinks, points) | Let the server apply the rules and show the result | Only during the match (not stored) |
| **IP address and technical connection data** | Run the connection and fix errors | In the server's technical log: [DÍAS DE REGISTROS] days |

We do not ask for your real name, email, phone number, location, contacts, photos or
microphone. The game has no ads, no real-money purchases and uses no analytics or
advertising tools.

### 3. Who we share it with

- **Other players in your room** see your player name and your character's appearance.
- **Google Cloud** hosts our server in the **United States** (us-central1 region). It
  acts as a service provider: it stores and processes data only on our behalf.
- **Valve (Steam)** and **Google (Google Play)** process your purchase and store-account
  data under their own privacy policies; we do not receive that data.

We do not sell your data or share it with anyone else, unless required by law.

### 4. International transfers

The server is in the United States. If you play from another country (for example, the
European Union), your online data travels to the US so the game can work (performance of
the service you request when you join a room).

### 5. Security

The connection between the game and the server is encrypted. The server only opens the
game port and the database cannot be reached from the Internet. No system is 100% secure,
but we process as little data as possible.

### 6. Your rights and how to delete your data

You can ask at any time to access, correct or **delete** your online game account and its
data:
- **in the game**, under Settings > "Delete my online data". Once you confirm, the server
  immediately deletes your account, its device identifier and everything linked to it,
  keeping no record of the deleted account. The game also forgets the identifier: if you
  play online again, a new account is created with no link to the old one. Your
  characters, pesos and settings stay on your device (uninstalling the game deletes them);
- by emailing [CORREO DE CONTACTO] with the subject "Delete my Colmadón data", including,
  if you can, the player name you use and your platform (Steam or Android).

If you ask by email, we will delete the account and its identifier within 30 days at
most. Technical logs are
deleted automatically after [DÍAS DE REGISTROS] days. If you live in the EU or another
place with data protection laws, you can also complain to your data protection authority.

Legal basis (for EU users): performance of the service you request (online play) and
legitimate interest in keeping the server running and secure.

### 7. Children

Colmadón is not directed at children under 13 and we do not knowingly collect data from
children under that age. If you believe a child has given us data, contact us and we will
delete it.

### 8. Changes

If we change what the game does with your data (for example, by adding purchases,
leaderboards or statistics), we will update this page and the date above before the
change reaches the game.

This policy is published at [URL DE ESTA PÁGINA].
