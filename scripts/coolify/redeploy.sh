#!/usr/bin/env bash
# Redeploy the openGym service so the host pulls the images CI just built.
# Requires COOLIFY_API_TOKEN in the environment.
set -euo pipefail

COOLIFY_URL="${COOLIFY_URL:-https://coolify.fnsalinas.io}"
SERVICE_UUID="${SERVICE_UUID:-tqqxrzyxz9gfxaktkyocsvvv}"

: "${COOLIFY_API_TOKEN:?set COOLIFY_API_TOKEN}"

echo "Redeploying service ${SERVICE_UUID}…"
curl -fsS -X POST "${COOLIFY_URL}/api/v1/deploy?uuid=${SERVICE_UUID}&force=true" \
  -H "Authorization: Bearer ${COOLIFY_API_TOKEN}" | jq -r '.deployments[].message'

echo "Waiting for the app to answer…"
for _ in $(seq 1 30); do
  if curl -fsS --max-time 5 https://gym.fnsalinas.io/api/health >/dev/null 2>&1; then
    curl -s https://gym.fnsalinas.io/api/health
    echo
    echo "OK"
    exit 0
  fi
  sleep 5
done

echo "Still not answering after 150s — check: ssh coolify-supabase 'docker ps | grep tqqx'" >&2
exit 1
