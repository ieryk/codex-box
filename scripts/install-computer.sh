#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Uruchom jako root: sudo $0 ubuntu" >&2
  exit 1
fi

TARGET_USER=${1:-ubuntu}
CPTR_VERSION=${CPTR_VERSION:-0.9.21}
CPTR_PORT=${CPTR_PORT:-8000}

if ! id "$TARGET_USER" >/dev/null 2>&1; then
  echo "Nie istnieje użytkownik: $TARGET_USER" >&2
  exit 1
fi

[[ "$CPTR_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "Nieprawidłowa wersja CPTR_VERSION=$CPTR_VERSION" >&2
  exit 1
}
if [[ ! "$CPTR_PORT" =~ ^[0-9]+$ ]] || (( CPTR_PORT < 1024 || CPTR_PORT > 65535 )); then
  echo "CPTR_PORT musi być liczbą od 1024 do 65535." >&2
  exit 1
fi

TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
TARGET_GROUP=$(id -gn "$TARGET_USER")
VENV_DIR="$TARGET_HOME/.local/share/codex-box/computer-venv"
DATA_DIR="$TARGET_HOME/.cptr"
SERVICE_FILE=/etc/systemd/system/codex-box-computer.service

apt-get update
apt-get install -y --no-install-recommends python3 python3-pip python3-venv

install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" \
  "$TARGET_HOME/.local/share/codex-box"
install -d -m 0700 -o "$TARGET_USER" -g "$TARGET_GROUP" "$DATA_DIR"

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  sudo -u "$TARGET_USER" env HOME="$TARGET_HOME" python3 -m venv "$VENV_DIR"
fi

sudo -u "$TARGET_USER" env HOME="$TARGET_HOME" \
  "$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel
sudo -u "$TARGET_USER" env HOME="$TARGET_HOME" \
  "$VENV_DIR/bin/python" -m pip install --upgrade \
  "cptr[agents,docs,mcp]==$CPTR_VERSION"

cat >"$SERVICE_FILE" <<EOF
[Unit]
Description=Open WebUI Computer for Codex Box
Documentation=https://docs.openwebui.com/ecosystem/computer/
After=network-online.target tailscaled.service
Wants=network-online.target tailscaled.service

[Service]
Type=simple
User=$TARGET_USER
Group=$TARGET_GROUP
WorkingDirectory=$TARGET_HOME
Environment=HOME=$TARGET_HOME
Environment=USER=$TARGET_USER
Environment=LOGNAME=$TARGET_USER
Environment=SHELL=/bin/bash
Environment=PATH=$TARGET_HOME/.local/bin:$TARGET_HOME/.local/share/mise/shims:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=CPTR_DATA_DIR=$DATA_DIR
Environment=CPTR_AUDIT_LOG_LEVEL=METADATA
Environment=CPTR_LOG_UPSTREAM_REQUESTS=false
ExecStart=$VENV_DIR/bin/cptr run --headless --host 127.0.0.1 --port $CPTR_PORT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
UMask=0077

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable codex-box-computer.service
systemctl restart codex-box-computer.service

healthy=0
for _ in {1..30}; do
  if curl -fsS "http://127.0.0.1:$CPTR_PORT/api/health" >/dev/null; then
    healthy=1
    break
  fi
  sleep 1
done

if [[ "$healthy" != 1 ]]; then
  systemctl --no-pager --full status codex-box-computer.service || true
  echo "Open WebUI Computer nie odpowiedział na health check." >&2
  exit 1
fi

echo "Open WebUI Computer $CPTR_VERSION działa lokalnie na 127.0.0.1:$CPTR_PORT."
echo "Uruchom jako $TARGET_USER: box-computer setup"
