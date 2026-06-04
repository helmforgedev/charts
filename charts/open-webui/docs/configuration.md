<!-- SPDX-License-Identifier: Apache-2.0 -->
# Open WebUI — Configuration

Open WebUI is a self-hosted AI chat platform (Ollama and OpenAI-compatible
backends, RAG, multi-model chats, plugins). This chart runs the web app (Service
on port 80, app on 8080); it talks to external model backends — it is not a model
server itself.

## Key values

| Value | Default | Purpose |
|---|---|---|
| `postgresql.enabled` | `false`→subchart when set | Use PostgreSQL instead of the default SQLite (recommended for multi-user). |
| `externalDatabase.*` | — | Managed PostgreSQL. |
| `redis.enabled` | optional | Websocket/state coordination across replicas. |
| `persistence.*` | `true` | PVC for `/app/backend/data` (SQLite, uploads, cached embedding model). |
| `probes.startup.*` | generous | Tolerates the first-boot model download (see below). |
| Model backends | env/values | Ollama base URL and/or OpenAI-compatible API base + key. |

## First-boot model download

On first boot Open WebUI downloads its RAG embedding model from the HuggingFace
Hub, which can take several minutes (longer on slow links / arm64). The startup
probe budget is intentionally generous (~10 min) so the container is not killed
mid-download; the model is then cached on the data PVC. Do not shrink the startup
probe — a fresh install would crash-loop.

## Datastore

- **SQLite (default)** on the data PVC — works out of the box for a single
  user / small install.
- **PostgreSQL** — set the subchart or `externalDatabase.*` for multi-user and
  to scale beyond a single pod. Pair with Redis for multi-replica coordination.

## Model backends

Point Open WebUI at one or more backends:

- **Ollama** — set the Ollama base URL (in-cluster or external).
- **OpenAI-compatible** — set the API base URL + key (from a secret).

## Persistence and scaling

`/app/backend/data` is `ReadWriteOnce`. With SQLite this means a single replica;
with PostgreSQL + Redis the app can scale, though the model cache is per-pod
(re-downloaded on each replica's first start). Secrets (API keys, app secret, DB
password) come from secrets, never templated into a ConfigMap.
