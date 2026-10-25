<!-- SPDX-License-Identifier: Apache-2.0 -->

# OpenReplay research

## Upstream baseline

- Stable release: `v1.28.0`, published 2026-09-25.
- Source: <https://github.com/openreplay/openreplay/tree/v1.28.0>.
- Deployment documentation: <https://docs.openreplay.com/en/deployment/deploy-kubernetes/>.
- License: repository content defaults to AGPL-3.0; identified directories use MIT and `ee/` has separate proprietary terms.
- Runtime architecture: linux/amd64 only. The application is a distributed stack, not a single workload.

## Required OSS topology

The upstream deployment contains fifteen application services: alerts, api,
assets, assist, canvases, chalice, db, ender, frontend, http, images, sink,
sourcemapreader, spot, and storage. PostgreSQL, Valkey, ClickHouse, an
S3-compatible object store, a migration job, and RWX scratch storage complete
the data plane. Kafka, Vault, and connector are enterprise-only and are not
part of this chart's default OSS topology.

## Image evidence

Application images come from the official `public.ecr.aws/p1t3u8a3` registry.
Every component is pinned by compatible upstream tag and manifest digest. The
images publish linux/amd64 manifests only, so the chart validates an amd64 node
selector. Component hotfix versions intentionally differ from the product
release; they must not be flattened to one tag.

## Routing findings

Upstream bundles the F5 NGINX controller and depends on mergeable Ingresses,
snippets, regex rewrites, affinity maps, long timeouts, and an external HTTPS
proxy. Portable Ingress and Gateway API resources cannot reproduce every one
of those behaviors. This chart therefore places a pinned Caddy router in front
of the OpenReplay services and exposes only that router. The chart never
installs a controller or GatewayClass.

## Storage, migrations, and operations

- Multi-node deployments need an RWX claim mounted at `/mnt/efs` and writable
  by UID 1001. The unsafe upstream hostPath default is not used.
- The migration job is mandatory for real installs and uses pinned official
  migration tooling. It retains the upstream downgrade guard.
- A complete backup includes PostgreSQL, ClickHouse, object storage, secrets,
  and in-flight RWX/Valkey state. One PVC snapshot is not a complete backup.
- Kubernetes 1.31 or newer, HTTPS, x86/amd64, at least 2 vCPU, 8 GiB memory,
  and 50 GiB storage are upstream prerequisites.
- Backend 1.28 requires tracker 19.x and Assist 11.x.

## Sources and research method

Three independent research tracks covered official runtime behavior,
operations/ecosystem, and supply-chain evidence. Tavily was attempted first
and returned plan-limit HTTP 432; the permitted native-search fallback,
Context7, GitHub APIs, upstream manifests, and registry manifests were used.
