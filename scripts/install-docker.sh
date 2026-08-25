#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Uruchom jako root." >&2
  exit 1
fi

TARGET_USER=${1:-ubuntu}
. /etc/os-release
[[ "$ID" == ubuntu ]] || { echo "Skrypt obsługuje Ubuntu." >&2; exit 1; }

apt-get update
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

ARCH=$(dpkg --print-architecture)
CODENAME=${UBUNTU_CODENAME:-$VERSION_CODENAME}
printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu %s stable\n' "$ARCH" "$CODENAME" >/etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
usermod -aG docker "$TARGET_USER"

echo "Docker gotowy. Użytkownik $TARGET_USER musi zalogować się ponownie."

