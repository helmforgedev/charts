<!-- SPDX-License-Identifier: Apache-2.0 -->

# Karakeep Architecture

Karakeep is a bookmark and read-later application with optional full-text search,
screenshots, archive capture, and AI tagging. The HelmForge chart deploys it as a
single-writer workload with colocated search and browser sidecars.

## Components

| Component | Kubernetes resource | Purpose |
| --- | --- | --- |
| Karakeep | Deployment container | Runs the web UI, API, auth flow, and bookmark processing. |
| Meilisearch | Deployment sidecar | Provides local full-text search when enabled. |
| Chromium | Deployment sidecar | Provides screenshot and archive capture when enabled. |
| Service | Service | Exposes the Karakeep HTTP port inside the cluster. |
| Credentials | Secret or ExternalSecret | Provides `NEXTAUTH_SECRET` and `MEILI_MASTER_KEY`. |
| Data store | PersistentVolumeClaim | Stores SQLite, uploads, queue data, and optional search index. |
| Edge routing | Ingress or HTTPRoute | Optional public or private HTTP entrypoint. |

## Request Flow

```text
User
   |
   | browser request
   v
Ingress, HTTPRoute, or port-forward
   |
   v
Service port 80
   |
   v
karakeep container port 3000
```

If Meilisearch is enabled, Karakeep uses `http://localhost:7700` inside the pod.
If Chromium is enabled, Karakeep uses `http://localhost:<chromium.port>` inside
the pod and can defer browser connection until a crawl needs it.

## Data Layout

All durable state is rooted at `/data`:

- SQLite application database;
- uploaded or archived bookmark content;
- Meilisearch index data under `/data/meilisearch`;
- operational state created by Karakeep at runtime.

Backups should snapshot the PVC consistently. Because SQLite and Meilisearch live
on the same volume by default, restore testing should include search reindexing
and bookmark access checks.

## Credential Flow

The main container reads `NEXTAUTH_SECRET` from the configured Secret. When
Meilisearch is enabled, both the main container and the Meilisearch sidecar read
the same `MEILI_MASTER_KEY` key.

With chart-managed credentials, Helm `lookup` preserves existing Secret data
during upgrades. With External Secrets Operator, the chart renders only the
ExternalSecret path and expects the operator to own the target Secret.

## Public URL Contract

`karakeep.nextAuthUrl` renders `NEXTAUTH_URL`. It must match the actual external
URL used by clients. For example, an HTTPS ingress should use:

```yaml
karakeep:
  nextAuthUrl: "https://karakeep.example.com"
```

For local port-forward tests, use the URL users open locally:

```yaml
karakeep:
  nextAuthUrl: "http://localhost:3000"
```

## Scaling Boundary

The chart is intentionally single-replica. SQLite and the default shared PVC are
not a horizontal application architecture. Resource tuning should happen within
the pod first; independent scaling of search or browser services requires moving
those services outside this chart's default topology.
