<!-- SPDX-License-Identifier: Apache-2.0 -->
# Open WebUI — Chart Design

Design notes for the HelmForge `open-webui` chart. Open WebUI is a self-hosted AI
chat platform (Ollama and OpenAI-compatible backends, RAG, multi-model chats,
plugins).

## Application shape

A single web application (served via the Service on port 80, app on 8080) that
talks to one or more model backends (Ollama and/or OpenAI-compatible endpoints,
configured via values/env). It is not a model server itself — it orchestrates
chats against external model APIs.

## First-boot model download (startup probe)

On first boot Open WebUI downloads its **RAG embedding model** from the
HuggingFace Hub. This can take several minutes (and longer on slow links / arm64).
The startup probe is therefore generous (`probes.startup.failureThreshold *
periodSeconds` ≈ 10 min) so the container is not killed mid-download; once the
model is cached on the data PVC, subsequent starts are fast. Cutting the startup
budget here causes a crash-loop on a fresh install.

## Datastores

- **SQLite (default)** on the data PVC — works out of the box, single user/small.
- **PostgreSQL** (`postgresql.enabled` or `externalDatabase`) — recommended for
  multi-user / persistence beyond a single pod.
- **Redis** (`redis.enabled`, optional) — websocket/state coordination when
  running multiple replicas.

## Persistence

`/app/backend/data` (the SQLite DB when used, uploaded files, and the cached
embedding model) is backed by a `ReadWriteOnce` PVC. With SQLite this implies a
single replica; with PostgreSQL + Redis the app can scale, but the model cache is
still per-pod (re-downloaded per replica on first start).

## Configuration & secrets

Model backend URLs/keys, the app secret, and datastore passwords come from
secrets/values; never templated into a ConfigMap.

## What this chart deliberately does NOT do

- It does not run Ollama/models in-pod (points at external model backends).
- No HA with SQLite (use PostgreSQL + Redis to scale).

## References

- Project: https://openwebui.com · https://github.com/open-webui/open-webui
- See [`docs/`](docs/) and [`examples/`](examples/).
