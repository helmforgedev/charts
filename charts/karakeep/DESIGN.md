<!-- SPDX-License-Identifier: Apache-2.0 -->

# Karakeep Design

## Purpose

The Karakeep chart packages the official Karakeep application with the two
sidecars that complete the default product experience: Meilisearch for full-text
search and browserless Chromium for screenshots and archived page capture. The
chart keeps the runtime simple and explicit: one application pod, one writable
PVC, one Service, and optional edge routing.

## Default Architecture

```text
Browser or API client
   |
   | port-forward, Ingress, or HTTPRoute
   v
ClusterIP Service
   |
   v
Karakeep Deployment (1 replica, Recreate)
   |
   +--> karakeep container on port 3000
   +--> optional Meilisearch sidecar on localhost:7700
   +--> optional Chromium sidecar on localhost:9222
   +--> Secret for NEXTAUTH_SECRET and MEILI_MASTER_KEY
   +--> PVC mounted at /data
```

Default characteristics:

- one pod and one writable PVC;
- Meilisearch and Chromium enabled for the full bookmark/search/archive
  experience;
- generated credentials reused through Helm `lookup` during upgrades;
- no public ingress by default;
- TCP probes on the Karakeep HTTP port.

## Storage Model

Karakeep stores SQLite data, uploaded content, and application state under
`/data`. The Meilisearch sidecar stores its index under `/data/meilisearch`
through a subPath mount. This keeps backup and restore centered on a single PVC.

The Deployment uses `strategy.type=Recreate` because the default storage model is
single-writer. Running multiple replicas against the same SQLite database and PVC
is outside this chart's supported contract.

## Secret Strategy

When `karakeep.existingSecret` is empty, the chart creates an Opaque Secret with
the keys configured by `karakeep.existingSecretNextAuthKey` and
`karakeep.existingSecretMeiliMasterKey`. The helper templates use `lookup` to
reuse existing Secret data during Helm upgrades.

Production operators can set `karakeep.existingSecret` to use a platform-managed
Secret. External Secrets Operator support intentionally requires that existing
Secret path so the chart-managed Secret and ExternalSecret do not compete as
credential writers.

## Sidecar Boundary

Meilisearch and Chromium are sidecars rather than external dependencies by
default. This makes the chart self-contained and easy to validate, but it also
means one pod carries application, search, and browser resource pressure.

Operators that need independent scaling, stricter isolation, or separate backup
policies should disable the sidecars and point Karakeep at externally managed
services through `karakeep.extraEnv` only after validating the upstream
configuration variables for their target version.

## Routing Model

The chart supports three access paths:

- no edge resource, using `kubectl port-forward` for local or private testing;
- Kubernetes Ingress for controller-managed HTTP/TLS routing;
- Gateway API HTTPRoute for clusters standardized on Gateway API.

`karakeep.nextAuthUrl` must match the user-facing URL. Authentication callback
URLs are sensitive to scheme, host, and trailing slash differences.

## Security Posture

The chart exposes `resources`, `securityContext`, `podSecurityContext`,
`serviceAccount`, and scheduling controls without forcing a single cluster
baseline. This keeps the default portable across local clusters and managed
platforms, while production values should set:

- resource requests and limits for all three containers;
- non-root and privilege escalation restrictions where supported by the images;
- service account and token mounting policy appropriate for the namespace;
- NetworkPolicies or equivalent platform policy for ingress and egress.

## Validation

The HelmForge gate for this chart is:

```bash
make validate-chart CHART=karakeep
```

This runs dependency, lint, template, unittest, kubeconform, Artifact Hub lint,
and k3d behavioral validation. Site documentation must also remain synchronized
with chart-facing examples and value contracts.
