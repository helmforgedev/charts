<!-- SPDX-License-Identifier: Apache-2.0 -->
# Castopod — Chart Design

Design notes for the HelmForge `castopod` chart. Castopod is an open-source
**podcast hosting** platform (publishing, episodes, web player, ActivityPub).

## Application shape

Castopod is a CodeIgniter (PHP) application served via the Service on port 80
(app on 8080). It is backed by **MariaDB** and serves uploaded media (audio,
artwork) from a persistent volume.

## Datastores

- **MariaDB** (bundled subchart or external) — episodes, podcasts, users,
  settings. The source of truth.
- **Redis** (optional, `redis.enabled`) — cache to speed up the app; without it
  Castopod runs file/DB-backed caching.

## Persistence

Uploaded media (audio files and images) live on a `ReadWriteOnce` PVC. Because
media is local and the volume is RWO, the app tier runs a **single replica** by
design. The database holds metadata; the PVC holds the (large) media payloads —
back up both.

## Startup ordering

An init/readiness gate keeps Castopod from serving before MariaDB is reachable; a
scheduled task runner may log a transient error on its first iteration before the
schema/setup is complete (benign during boot).

## Configuration & secrets

Database/Redis passwords and the app key come from secrets (existing-secret
first), never templated into a ConfigMap.

## What this chart deliberately does NOT do

- No app-tier HA (RWO media volume — single replica by design).
- Redis is opt-in (off by default).

## References

- Project: https://castopod.org · https://code.castopod.org/adaures/castopod
- See [`docs/`](docs/) and [`examples/`](examples/).
