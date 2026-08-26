#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

scripts=(
  bootstrap.sh
  bin/box-login
  bin/box-clone
  bin/box-update
  bin/box-doctor
  bin/box-playbook-sync
  bin/codex-deepseek
  scripts/install-docker.sh
  tests/smoke.sh
)

for script in "${scripts[@]}"; do
  bash -n "$ROOT/$script"
done

grep -q '^#cloud-config$' "$ROOT/cloud-init.yaml"
grep -q 'BOX_REPO_URL=' "$ROOT/cloud-init.yaml"
grep -q 'INSTALL_DOCKER=' "$ROOT/cloud-init.yaml"
grep -q 'AGENT_PLAYBOOK_REPO_URL=' "$ROOT/cloud-init.yaml"
grep -Fq 'HOME="$TARGET_HOME"' "$ROOT/bootstrap.sh"
grep -Fq 'MISE_DATA_DIR="$TARGET_HOME/.local/share/mise"' "$ROOT/bootstrap.sh"
grep -Fq '"$TARGET_HOME/.local/share/mise"' "$ROOT/bootstrap.sh"
grep -Fq 'CODEX_NON_INTERACTIVE=1 sh' "$ROOT/bootstrap.sh"
grep -Fq 'box-playbook-sync' "$ROOT/bootstrap.sh"
grep -Fq 'box-playbook-sync' "$ROOT/bin/box-login"
grep -q 'model = "deepseek-v4-flash"' "$ROOT/config/deepseek-flash.config.toml"
grep -q 'env_key = "DEEPSEEK_API_KEY"' "$ROOT/config/deepseek-flash.config.toml"
if rg -n 'experimental_bearer_token|sk-[A-Za-z0-9]' "$ROOT/config"; then
  echo "Konfiguracja nie może zawierać jawnego klucza API." >&2
  exit 1
fi

if command -v ruby >/dev/null 2>&1; then
  ruby -e 'require "yaml"; YAML.load_file(ARGV.fetch(0))' "$ROOT/cloud-init.yaml"
else
  echo "Ruby niedostępny — pomijam pełne parsowanie YAML"
fi

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x "${scripts[@]/#/$ROOT/}"
else
  echo "shellcheck niedostępny — pomijam lint"
fi

echo "Smoke tests: OK"
