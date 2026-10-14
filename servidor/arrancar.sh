#!/usr/bin/env bash
# Arranca el servidor local de Colmadón: PostgreSQL (puerto 5432) y Nakama
# (7350 juego, 7351 consola). Uso: bash servidor/arrancar.sh  [parar]
set -e
cd "${COLMADON_SERVIDOR_BASE:-$(dirname "$0")}"
PG=./pgsql/bin
DB=./datos/pg
mkdir -p datos
if [ "$1" = "parar" ]; then
	taskkill //IM nakama.exe //F >/dev/null 2>&1 || true
	$PG/pg_ctl -D $DB stop -m fast || true
	exit 0
fi
if [ ! -f $DB/PG_VERSION ]; then
	$PG/initdb -D $DB -U postgres -A trust -E UTF8 --locale=C >/dev/null
fi
$PG/pg_ctl -D $DB status >/dev/null 2>&1 || $PG/pg_ctl -D $DB -l datos/pg.log -o "-p 5432 -h 127.0.0.1" start -w >/dev/null
$PG/psql -h 127.0.0.1 -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='nakama'" | grep -q 1 || $PG/createdb -h 127.0.0.1 -U postgres nakama
[ -f datos/consola.txt ] || head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' > datos/consola.txt
DBADDR="postgres@127.0.0.1:5432/nakama"
./bin/nakama.exe migrate up --database.address "$DBADDR" >datos/migrate.log 2>&1
exec ./bin/nakama.exe --config config.yml --database.address "$DBADDR" --console.password "$(cat datos/consola.txt)" --runtime.path "${COLMADON_MODULOS:-./modulo/build}"
