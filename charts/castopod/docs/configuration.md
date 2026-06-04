<!-- SPDX-License-Identifier: Apache-2.0 -->
# Castopod — Configuration

Castopod is an open-source podcast hosting platform (publishing, episodes, web
player, ActivityPub federation). This chart runs the Castopod (CodeIgniter/PHP)
app on port 80, backed by MariaDB, serving uploaded media from a persistent
volume.

## Key values

| Value | Default | Purpose |
|---|---|---|
| `mariadb.enabled` | `true` | Bundle the HelmForge MariaDB subchart. |
| `database.external.*` | — | Managed MariaDB (when `mariadb.enabled=false`). |
| `redis.enabled` | `false` | Optional cache to speed up the app. |
| `persistence.*` | `true` | PVC for uploaded media (audio, artwork). |
| `ingress.*` | disabled | Expose the site (a public hostname is required for podcasts/feeds). |

## Datastores and media

- **MariaDB** — podcasts, episodes, users, settings (source of truth). Use the
  bundled subchart or point at managed MariaDB via `database.external.*`.
- **Redis** (optional) — cache; without it Castopod uses file/DB caching.
- **Media PVC** — uploaded audio files and artwork. This is a large, `ReadWriteOnce`
  volume, so the app runs a single replica.

## Access and hostname

Castopod builds absolute URLs for feeds and the player, so a stable hostname
matters. With ingress disabled, port-forward for local testing:

```bash
kubectl port-forward svc/<release>-castopod 8080:80
# open http://localhost:8080/cp-install to complete setup
```

For real use, enable `ingress.*` with your domain.

## Backup

Back up both MariaDB (metadata) and the media PVC (the audio payloads). The
database alone is not sufficient — episodes' media live on the PVC.

## Configuration & secrets

Database/Redis passwords and the app key come from secrets (existing-secret
first), never templated into a ConfigMap.
