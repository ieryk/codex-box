#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

if [[ ${EUID} -ne 0 ]]; then
  echo "Uruchom jako root: sudo env TARGET_USER=ubuntu $0" >&2
  exit 1
fi

TARGET_USER=${TARGET_USER:-ubuntu}
INSTALL_DOCKER=${INSTALL_DOCKER:-0}
BOX_REPO_REF=${BOX_REPO_REF:-main}
REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

[[ "$INSTALL_DOCKER" == 0 || "$INSTALL_DOCKER" == 1 ]] || {
  echo "INSTALL_DOCKER musi mieć wartość 0 albo 1." >&2
  exit 1
}

if ! id "$TARGET_USER" >/dev/null 2>&1; then
  echo "Nie istnieje użytkownik TARGET_USER=$TARGET_USER" >&2
  exit 1
fi

TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
TARGET_GROUP=$(id -gn "$TARGET_USER")

log() { printf '\n==> %s\n' "$*"; }
as_user() {
  sudo -u "$TARGET_USER" env \
    HOME="$TARGET_HOME" \
    USER="$TARGET_USER" \
    LOGNAME="$TARGET_USER" \
    MISE_CACHE_DIR="$TARGET_HOME/.cache/mise" \
    MISE_CONFIG_DIR="$TARGET_HOME/.config/mise" \
    MISE_DATA_DIR="$TARGET_HOME/.local/share/mise" \
    MISE_STATE_DIR="$TARGET_HOME/.local/state/mise" \
    PATH="$TARGET_HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    bash -c "$1"
}

log "Pakiety systemowe"
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl gnupg software-properties-common
add-apt-repository -y universe
apt-get update
apt-get install -y --no-install-recommends \
  age build-essential ca-certificates curl direnv fd-find file fzf gh git git-lfs \
  gnupg jq locales lsb-release pkg-config ripgrep rsync shellcheck sudo tmux \
  unattended-upgrades unzip xz-utils zip

git lfs install --system

if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  ln -sfn "$(command -v fdfind)" /usr/local/bin/fd
fi

log "Swap 4 GB"
if ! swapon --show=NAME --noheadings | grep -qx '/swapfile'; then
  if [[ ! -f /swapfile ]]; then
    fallocate -l 4G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096 status=progress
  fi
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
fi
grep -qE '^/swapfile\s' /etc/fstab || printf '/swapfile none swap sw 0 0\n' >>/etc/fstab
printf 'vm.swappiness=10\n' >/etc/sysctl.d/60-codex-box.conf
sysctl --system >/dev/null

log "Automatyczne aktualizacje bezpieczeństwa"
cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

log "Konfiguracja powłoki, Codexa i tmux"
install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" \
  "$TARGET_HOME/.cache/mise" \
  "$TARGET_HOME/.codex" \
  "$TARGET_HOME/.config" \
  "$TARGET_HOME/.config/mise" \
  "$TARGET_HOME/.local" \
  "$TARGET_HOME/.local/bin" \
  "$TARGET_HOME/.local/share" \
  "$TARGET_HOME/.local/share/mise" \
  "$TARGET_HOME/.local/state/mise" \
  "$TARGET_HOME/src"
install -d -m 0700 -o "$TARGET_USER" -g "$TARGET_GROUP" \
  "$TARGET_HOME/.config/codex-box"
chown "$TARGET_USER:$TARGET_GROUP" "$TARGET_HOME/.local" "$TARGET_HOME/.local/share"
chown -R "$TARGET_USER:$TARGET_GROUP" \
  "$TARGET_HOME/.cache/mise" \
  "$TARGET_HOME/.config/mise" \
  "$TARGET_HOME/.local/bin" \
  "$TARGET_HOME/.local/share/mise" \
  "$TARGET_HOME/.local/state/mise"
install -m 0644 -o "$TARGET_USER" -g "$TARGET_GROUP" "$REPO_DIR/config/tmux.conf" "$TARGET_HOME/.tmux.conf"
install -m 0644 -o "$TARGET_USER" -g "$TARGET_GROUP" \
  "$REPO_DIR/config/deepseek-flash.config.toml" "$TARGET_HOME/.codex/deepseek-flash.config.toml"
touch "$TARGET_HOME/.bashrc"
chown "$TARGET_USER:$TARGET_GROUP" "$TARGET_HOME/.bashrc"

PROFILE_BEGIN='# >>> codex-box >>>'
if ! grep -Fq "$PROFILE_BEGIN" "$TARGET_HOME/.bashrc"; then
  cat >>"$TARGET_HOME/.bashrc" <<'EOF'

# >>> codex-box >>>
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
[[ -f "$HOME/.config/codex-box/secrets.env" ]] && source "$HOME/.config/codex-box/secrets.env"
eval "$(mise activate bash)"
eval "$(direnv hook bash)"
# <<< codex-box <<<
EOF
fi
chown "$TARGET_USER:$TARGET_GROUP" "$TARGET_HOME/.bashrc"

log "mise i Node.js LTS"
if [[ ! -x "$TARGET_HOME/.local/bin/mise" ]]; then
  as_user 'curl -fsSL https://mise.run | sh'
fi
as_user 'export PATH="$HOME/.local/bin:$PATH"; mise use --global node@lts'

log "Codex CLI"
# Oficjalny instalator jest również mechanizmem aktualizacji Codex CLI.
as_user 'curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh'

log "Tailscale"
if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
systemctl enable --now tailscaled

log "Narzędzia Codex Box"
for tool in box-login box-clone box-update box-doctor codex-deepseek; do
  install -m 0755 "$REPO_DIR/bin/$tool" "/usr/local/bin/$tool"
done

cat >/etc/default/codex-box <<EOF
BOX_REPO_URL="$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null || true)"
BOX_REPO_REF="$BOX_REPO_REF"
TARGET_USER="$TARGET_USER"
INSTALL_DOCKER="$INSTALL_DOCKER"
EOF

if [[ "$INSTALL_DOCKER" == 1 ]]; then
  "$REPO_DIR/scripts/install-docker.sh" "$TARGET_USER"
fi

log "Gotowe. Uruchom jako $TARGET_USER: box-doctor, a potem box-login"
