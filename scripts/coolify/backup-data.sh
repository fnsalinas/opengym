#!/usr/bin/env bash
# Pull openGym's data directory off the deployment host into a local archive.
#
# data/ holds every user, passkey, workout, the session secret and the VAPID keys.
# There is no database — this archive is the whole backup.
set -euo pipefail

SSH_HOST="${SSH_HOST:-coolify-supabase}"
SERVICE_UUID="${SERVICE_UUID:-tqqxrzyxz9gfxaktkyocsvvv}"
REMOTE_DIR="/data/coolify/services/${SERVICE_UUID}"
DEST="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/backups}"
KEEP="${KEEP:-14}"

mkdir -p "$DEST"
stamp=$(date +%F-%H%M)
archive="${DEST}/opengym-data-${stamp}.tar.gz"

# Archive on the host and stream it back; never mutates anything remote.
ssh "$SSH_HOST" "tar czf - -C '${REMOTE_DIR}' data" > "$archive"

if ! tar tzf "$archive" >/dev/null 2>&1; then
  echo "Archive is corrupt, removing: $archive" >&2
  rm -f "$archive"
  exit 1
fi

echo "$archive  ($(du -h "$archive" | cut -f1), $(tar tzf "$archive" | wc -l) entries)"

# Retention: keep the newest $KEEP archives.
ls -1t "${DEST}"/opengym-data-*.tar.gz 2>/dev/null | tail -n "+$((KEEP + 1))" | while read -r old; do
  echo "pruning $old"
  rm -f "$old"
done
