# Deployment runbook

openGym runs on the Coolify-managed host as a Docker Compose service. Images are built
by GitHub Actions and pulled from GHCR; nothing is built on the host.

| | |
|---|---|
| URL | https://gym.fnsalinas.io |
| Coolify project | `openGym` — `b9l3sovpoyv46f593slpspwy` |
| Coolify service | `opengym` — `tqqxrzyxz9gfxaktkyocsvvv` |
| Host path | `/data/coolify/services/tqqxrzyxz9gfxaktkyocsvvv` |
| Containers | `api-tqqxrzyxz9gfxaktkyocsvvv`, `web-tqqxrzyxz9gfxaktkyocsvvv` |
| Images | `ghcr.io/fnsalinas/opengym-api`, `ghcr.io/fnsalinas/opengym-web` (public) |
| SSH | `ssh coolify-supabase` |

The API token for the Coolify API lives in the shell environment as `COOLIFY_API_TOKEN`.

## Deploy a change

Push to `main`. Actions rebuilds both images and tags them `latest` plus the commit SHA.
Then redeploy so the host pulls them:

```bash
scripts/coolify/redeploy.sh
```

## Environment

Set as service environment variables in Coolify, not in this repo — see `env.example`
for the full list. `RP_ID` and `ORIGIN` are the hostname openGym binds passkeys to;
changing either invalidates every passkey already registered.

Read or change one:

```bash
curl -s -H "Authorization: Bearer $COOLIFY_API_TOKEN" \
  https://coolify.fnsalinas.io/api/v1/services/tqqxrzyxz9gfxaktkyocsvvv/envs | jq -r '.[] | "\(.key)=\(.value)"'

curl -s -X PATCH -H "Authorization: Bearer $COOLIFY_API_TOKEN" -H "Content-Type: application/json" \
  https://coolify.fnsalinas.io/api/v1/services/tqqxrzyxz9gfxaktkyocsvvv/envs \
  -d '{"key":"INVITE_ONLY","value":"1"}'
```

Environment changes need a redeploy to take effect.

## Closing signup

The instance ships with `INVITE_ONLY=0` so the first profile can be created. After
registering, read the user id and lock it down:

```bash
ssh coolify-supabase 'cat /data/coolify/services/tqqxrzyxz9gfxaktkyocsvvv/data/db.json' | jq -r '.users[] | "\(.id) \(.name)"'
```

Set `ADMIN_UIDS` to that id, set `INVITE_ONLY=1`, redeploy. Existing accounts keep
working; new ones then need an invite code, generated from the admin dashboard.

## Backups

`data/` is the entire backup surface — users, passkeys, workout history, the session
secret and the VAPID keys. There is no database. Losing it means every passkey has to
be re-registered.

```bash
scripts/coolify/backup-data.sh            # writes to ./backups/
scripts/coolify/backup-data.sh /mnt/nas   # or somewhere durable
```

Restore: stop the service, unpack the archive over `data/`, start it again.

## Health

```bash
curl -s https://gym.fnsalinas.io/api/health              # {"ok":true,"users":N}
ssh coolify-supabase 'docker ps --format "{{.Names}} {{.Status}}" | grep tqqx'
```

Logs:

```bash
ssh coolify-supabase 'docker logs --tail 100 api-tqqxrzyxz9gfxaktkyocsvvv'
```

## Notes on this host

The host also runs Supabase, two n8n instances and Chatwoot, all behind the same
Traefik. Two consequences shaped this setup:

- **Never publish host ports.** Upstream's compose maps `8080:80`, which is already
  taken by `coolify-proxy`. Traefik reaches the containers over the Docker network.
- **Never build here.** Memory is tight. Images are built in CI.

The service is capped at 384 MB (api) and 128 MB (web); actual use is ~26 MB combined.
