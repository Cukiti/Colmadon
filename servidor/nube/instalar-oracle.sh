#!/bin/bash
# Instala y arranca el servidor de Colmadón en la máquina de Oracle Cloud
# (Ubuntu 24.04 ARM, VM.Standard.A1.Flex 4 OCPU / 24 GB). Lo lanza
# actualizar-oracle.sh por SSH con sudo; se puede repetir sin problema.
# Espera junto a este script: nakama.env (claves) e index.js (módulo).
set -euo pipefail
NAKAMA_VER=3.41.0
AQUI=$(cd "$(dirname "$0")" && pwd)

# claves
install -m 600 "$AQUI/nakama.env" /root/nakama.env
chmod 600 /root/nakama.env
set -a; . /root/nakama.env; set +a

# sin intercambio: hay 24 GB de RAM

# PostgreSQL (versión de Ubuntu 24.04), con memoria de sobra
if ! command -v psql >/dev/null; then
	apt-get update -q
	DEBIAN_FRONTEND=noninteractive apt-get install -y -q postgresql
fi
PGCONF=$(ls /etc/postgresql/*/main/postgresql.conf | head -1)
grep -q "colmadon" "$PGCONF" || cat >> "$PGCONF" <<'PGEOF'
# colmadon: máquina A1 de 24 GB
shared_buffers = 4GB
effective_cache_size = 12GB
work_mem = 16MB
max_connections = 200
listen_addresses = 'localhost'
PGEOF
systemctl restart postgresql
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='nakama'" | grep -q 1 \
	|| sudo -u postgres psql -c "CREATE ROLE nakama LOGIN PASSWORD '$DB_PASS'"
sudo -u postgres psql -c "ALTER ROLE nakama PASSWORD '$DB_PASS'" >/dev/null
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='nakama'" | grep -q 1 \
	|| sudo -u postgres createdb -O nakama nakama

# Nakama
mkdir -p /opt/nakama/data/modules
if [ ! -x /opt/nakama/nakama ] || ! /opt/nakama/nakama --version 2>/dev/null | grep -q "$NAKAMA_VER"; then
	curl -sfL -o /tmp/nakama.tar.gz "https://github.com/heroiclabs/nakama/releases/download/v$NAKAMA_VER/nakama-$NAKAMA_VER-linux-arm64.tar.gz"
	tar -xzf /tmp/nakama.tar.gz -C /opt/nakama nakama
fi
cp "$AQUI/index.js" /opt/nakama/data/modules/index.js
id nakama >/dev/null 2>&1 || useradd --system --home /opt/nakama --shell /usr/sbin/nologin nakama
cat > /opt/nakama/config.yml <<CFG
name: colmadon-nube
data_dir: "/opt/nakama/data"
logger:
  level: "INFO"
  stdout: true
session:
  encryption_key: "$SESSION_KEY"
  refresh_encryption_key: "$REFRESH_KEY"
  token_expiry_sec: 604800
  refresh_token_expiry_sec: 2592000
runtime:
  http_key: "$HTTP_KEY"
  js_entrypoint: "index.js"
socket:
  server_key: "$SERVER_KEY"
  port: 7350
console:
  port: 7351
  address: "127.0.0.1"
  username: "admin"
  password: "$CONSOLE_PASS"
CFG
chown -R nakama:nakama /opt/nakama
chmod 600 /opt/nakama/config.yml
DB="nakama:$DB_PASS@127.0.0.1:5432/nakama"
cat > /etc/systemd/system/nakama.service <<UNIT
[Unit]
Description=Servidor de Colmadon (Nakama)
After=postgresql.service network-online.target
Requires=postgresql.service

[Service]
User=nakama
WorkingDirectory=/opt/nakama
ExecStartPre=/opt/nakama/nakama migrate up --database.address $DB
ExecStart=/opt/nakama/nakama --config /opt/nakama/config.yml --database.address $DB
Restart=always
RestartSec=5
MemoryMax=12G

[Install]
WantedBy=multi-user.target
UNIT
chmod 600 /etc/systemd/system/nakama.service
systemctl daemon-reload
systemctl enable nakama >/dev/null
systemctl restart nakama
# cortafuegos de Ubuntu en Oracle (iptables): abre el 7350
if ! iptables -C INPUT -p tcp --dport 7350 -m state --state NEW -j ACCEPT 2>/dev/null; then
	iptables -I INPUT 5 -p tcp --dport 7350 -m state --state NEW -j ACCEPT
	netfilter-persistent save >/dev/null
fi
echo "Colmadón: servidor listo"
