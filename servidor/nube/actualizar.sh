#!/usr/bin/env bash
# Sube a la máquina de Google Cloud el módulo del juego recién compilado y
# reinicia el servidor (las partidas en curso se cortan).
# Uso: bash servidor/nube/actualizar.sh
set -e
cd "$(dirname "$0")/.."
(cd modulo && npx tsc && npm test)
# la cuenta dueña del proyecto (en este PC la cuenta activa de gcloud puede ser otra)
CUENTA=${COLMADON_GCLOUD_CUENTA:-tu-cuenta@example.com}
gcloud compute instances add-metadata colmadon --zone us-central1-a --project colmadon-servidor --account "$CUENTA" \
	--metadata-from-file colmadon-modulo=modulo/build/index.js,startup-script=nube/instalar.sh
# reinicio de la máquina: vuelve a ejecutar instalar.sh, que copia el módulo nuevo
gcloud compute instances reset colmadon --zone us-central1-a --project colmadon-servidor --account "$CUENTA"
echo "Actualizado. El servidor tarda ~1 minuto en volver."
