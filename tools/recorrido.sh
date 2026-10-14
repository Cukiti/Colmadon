#!/usr/bin/env bash
# Graba el recorrido de pruebas de Colmadón: un vídeo por escena (Movie Maker
# de Godot, 30 fps fijos: no se pierde ningún fotograma), lo analiza y hace
# el informe capturas/recorrido/informe.html.
#
# Uso:  bash tools/recorrido.sh                 # todas las escenas
#       bash tools/recorrido.sh de_pie final    # solo esas
# Escenas: menus partida clasico de_pie raros final online
#          explorar (bot explorador con pendientes; no va en «todas»: bash tools/recorrido.sh explorar)
# (online enciende el servidor local y graba las dos ventanas: anfitrión y amigo)
set -u
cd "$(dirname "$0")/.."
G=${GODOT:-$HOME/AndroidStudioProjects/Godot_4.7.2/Godot_v4.7.2-stable_win64_console.exe}
OUT=capturas/recorrido
ESC=("$@")
[ ${#ESC[@]} -eq 0 ] && ESC=(menus partida clasico de_pie raros final online)
mkdir -p "$OUT"

grabar() {  # grabar <escena> [args extra...]
	local e=$1; shift
	rm -rf "$OUT/$e"; mkdir -p "$OUT/$e"
	local avi; avi=$(cygpath -w "$PWD/$OUT/$e/video.avi")
	echo "== grabando $e"
	timeout 1200 "$G" --path . --resolution 1280x720 --write-movie "$avi" --fixed-fps 30 -- --recorrido --escena="$e" "$@" > "$OUT/$e/log.txt" 2>&1
	echo "   salida $? · $(grep -c '^MARCA' "$OUT/$e/log.txt") marcas · $(grep -c '^HALLAZGO' "$OUT/$e/log.txt") hallazgos"
}

for e in "${ESC[@]}"; do
	if [ "$e" = "online" ]; then
		bash servidor/arrancar.sh parar >/dev/null 2>&1
		(bash servidor/arrancar.sh > servidor/datos/nakama_run.log 2>&1 &)
		for i in $(seq 1 60); do curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:7350/healthcheck 2>/dev/null | grep -q 200 && break; sleep 2; done
		grabar online_anfitrion --local --cuenta=A &
		sleep 4
		grabar online_amigo --local --cuenta=B
		wait
		bash servidor/arrancar.sh parar >/dev/null 2>&1
	else
		grabar "$e"
	fi
done

python tools/analizar_recorrido.py "$OUT"
