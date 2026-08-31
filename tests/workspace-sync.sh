#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT

REMOTE="$FIXTURE/remote.git"
SEED="$FIXTURE/seed"
WORKSPACE="$FIXTURE/home/personal-workspace"
export HOME="$FIXTURE/home"
export CODEX_BOX_CONFIG_FILE=/dev/null
export PERSONAL_WORKSPACE_REPO_URL="$REMOTE"
export PERSONAL_WORKSPACE_REPO_REF=master
export PERSONAL_WORKSPACE_DIR="$WORKSPACE"

git init --bare "$REMOTE" >/dev/null
git init --initial-branch=master "$SEED" >/dev/null
git -C "$SEED" config user.name Test
git -C "$SEED" config user.email test@example.invalid
printf '# Test workspace\n' >"$SEED/README.md"
git -C "$SEED" add README.md
git -C "$SEED" commit -m init >/dev/null
git -C "$SEED" remote add origin "$REMOTE"
git -C "$SEED" push -u origin master >/dev/null

"$ROOT/bin/box-workspace-sync" setup >/dev/null
mkdir -p "$WORKSPACE/notes"
printf 'ordinary note\n' >"$WORKSPACE/notes/test.md"
"$ROOT/bin/box-workspace-sync" snapshot >/dev/null
git -C "$WORKSPACE" show HEAD:notes/test.md | grep -Fq 'ordinary note'
if git --git-dir="$REMOTE" show master:notes/test.md >/dev/null 2>&1; then
  echo "Automatyczny snapshot nie może sam wysyłać danych." >&2
  exit 1
fi
"$ROOT/bin/box-workspace-sync" push >/dev/null
git --git-dir="$REMOTE" show master:notes/test.md | grep -Fq 'ordinary note'

printf 'OPENAI_API_KEY=sk-abcdefghijklmnopqrstuvwxyz123456\n' >"$WORKSPACE/notes/unsafe.txt"
if "$ROOT/bin/box-workspace-sync" snapshot >"$FIXTURE/guard.out" 2>&1; then
  echo "Snapshot zaakceptował przykładowy sekret." >&2
  exit 1
fi
grep -Fq 'prawdopodobny sekret' "$FIXTURE/guard.out"
if grep -Fq 'sk-abcdefghijklmnopqrstuvwxyz123456' "$FIXTURE/guard.out"; then
  echo "Komunikat diagnostyczny ujawnił sekret." >&2
  exit 1
fi
rm "$WORKSPACE/notes/unsafe.txt"
git -C "$WORKSPACE" reset >/dev/null
printf 'outside allowlist\n' >"$WORKSPACE/unexpected.txt"
if "$ROOT/bin/box-workspace-sync" snapshot >"$FIXTURE/allowlist.out" 2>&1; then
  echo "Snapshot zaakceptował plik poza dozwoloną strukturą." >&2
  exit 1
fi
grep -Fq 'poza dozwoloną strukturą' "$FIXTURE/allowlist.out"

echo "Workspace sync tests: OK"
