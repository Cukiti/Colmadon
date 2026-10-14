#!/usr/bin/env bash
# Sube a la máquina de Oracle Cloud el módulo del juego recién compilado y
# reinstala/reinicia el servidor (las partidas en curso se cortan).
# Uso: bash servidor/nube/actualizar-oracle.sh
set -e
cd "$(dirname "$0")/.."
IP=${COLMADON_ORACLE_IP:-129.80.114.69}
CLAVE=${COLMADON_ORACLE_CLAVE:-$HOME/.ssh/colmadon_oci}
SSH="ssh -i $CLAVE -o StrictHostKeyChecking=accept-new ubuntu@$IP"
(cd modulo && npx tsc && npm test)
$SSH 'mkdir -p ~/colmadon && chmod 700 ~/colmadon'
scp -i "$CLAVE" -o StrictHostKeyChecking=accept-new datos/nube.env "ubuntu@$IP:colmadon/nakama.env"
scp -i "$CLAVE" modulo/build/index.js nube/instalar-oracle.sh "ubuntu@$IP:colmadon/"
$SSH 'sudo bash ~/colmadon/instalar-oracle.sh && rm -f ~/colmadon/nakama.env'
echo "Actualizado en Oracle ($IP)."
