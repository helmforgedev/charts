<!-- SPDX-License-Identifier: Apache-2.0 -->

# FastMCP Server Architecture

## Runtime Topology

`fastmcp-server` runs as a single Kubernetes Deployment that exposes one HTTP
port. The default Service listens on port `8000` and forwards traffic to the
container port configured by `server.port`.

The main container receives runtime configuration through environment
variables:

- `MCP_SERVER_NAME` from `server.name`;
- `MCP_PORT` from `server.port`;
- `MCP_PATH` from `server.path`;
- `LOG_LEVEL` and `LOG_FORMAT` from `server`;
- source, auth, rate-limit, cache, sandboxing, and package settings when those
  features are enabled.

The chart intentionally keeps the default deployment small: one replica,
ClusterIP service, no ingress, no Gateway API, no persistence, no auth, and no
external sources.

## Workspace

All pods mount `/app/workspace`.

| Mode | Volume | Use case |
| --- | --- | --- |
| Default | `emptyDir` | Stateless lab and CI deployments. |
| `persistence.enabled=true` | PVC | Larger knowledge bases or source sync data that should survive pod restarts. |
| `persistence.existingClaim` | Existing PVC | Platform-managed storage lifecycle. |

The Deployment strategy is `Recreate`. That avoids overlapping pods writing to
the same workspace when a ReadWriteOnce PVC is used.

## Source Mounts

Inline sources are split by MCP content type and mounted read-only:

| Values key | Rendered object | Mount path |
| --- | --- | --- |
| `sources.inline.tools` | `<fullname>-tools` ConfigMap | `/app/inline/tools` |
| `sources.inline.resources` | `<fullname>-resources` ConfigMap | `/app/inline/resources` |
| `sources.inline.prompts` | `<fullname>-prompts` ConfigMap | `/app/inline/prompts` |
| `sources.inline.knowledge` | `<fullname>-knowledge` ConfigMap | `/app/inline/knowledge` |

The pod template includes checksum annotations for each inline map. Updating
inline content changes the pod template hash and triggers a rollout.

## Source Synchronization

External sources are passed to the application as environment variables. S3 and
Git are independent and can be enabled together. The application merges sources
with this documented precedence:

1. Inline content
2. S3-compatible object storage
3. Git repository

Set `initSync.enabled=true` when the source tree must be synchronized before
the server starts. This adds an init container that runs `python
/app/sync_only.py` with the same source mounts and credentials.

## Scaling

`replicaCount` controls pods when `autoscaling.enabled=false`. When autoscaling
is enabled, the Deployment omits `spec.replicas` and the HPA controls replica
count.

Use multiple replicas only when the configured sources and workspace mode are
safe for concurrent pods. For a shared ReadWriteOnce PVC, keep one replica.

## Exposure

The chart supports three exposure layers:

- Service for in-cluster traffic and port-forwarding;
- Ingress for classic Kubernetes ingress controllers;
- Gateway API `HTTPRoute` for clusters with a shared Gateway.

Gateway API does not create a Gateway. The platform team owns the Gateway and
the chart references it through `gatewayAPI.parentRefs`.
