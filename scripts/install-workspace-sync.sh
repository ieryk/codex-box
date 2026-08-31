#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Uruchom jako root: sudo $0 ubuntu" >&2
  exit 1
fi

TARGET_USER=${1:-ubuntu}
WORKSPACE_SNAPSHOT_MINUTES=${WORKSPACE_SNAPSHOT_MINUTES:-15}

id "$TARGET_USER" >/dev/null 2>&1 || {
  echo "Nie istnieje użytkownik $TARGET_USER" >&2
  exit 1
}
if [[ ! "$WORKSPACE_SNAPSHOT_MINUTES" =~ ^[0-9]+$ ]] || (( WORKSPACE_SNAPSHOT_MINUTES < 5 || WORKSPACE_SNAPSHOT_MINUTES > 1440 )); then
  echo "WORKSPACE_SNAPSHOT_MINUTES musi być liczbą od 5 do 1440." >&2
  exit 1
fi

TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

cat >/etc/systemd/system/codex-box-workspace-snapshot.service <<EOF
[Unit]
Description=Local snapshot of Codex Box personal workspace

[Service]
Type=oneshot
User=$TARGET_USER
Group=$(id -gn "$TARGET_USER")
Environment=HOME=$TARGET_HOME
Environment=USER=$TARGET_USER
Environment=LOGNAME=$TARGET_USER
EnvironmentFile=-/etc/default/codex-box
UMask=0077
ExecStart=/usr/local/bin/box-workspace-sync snapshot
EOF

cat >/etc/systemd/system/codex-box-workspace-snapshot.timer <<EOF
[Unit]
Description=Snapshot Codex Box personal workspace every $WORKSPACE_SNAPSHOT_MINUTES minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=${WORKSPACE_SNAPSHOT_MINUTES}min
RandomizedDelaySec=60
Persistent=true
Unit=codex-box-workspace-snapshot.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now codex-box-workspace-snapshot.timer
