<!-- SPDX-License-Identifier: Apache-2.0 -->

# Cronicle Chart Design

This chart packages Cronicle as a single writable scheduler node with a web UI,
filesystem-backed job state, and optional Kubernetes ingress. Cronicle can
coordinate multiple servers upstream, but the default chart intentionally keeps a
single Deployment replica because the storage model in this chart is a single PVC
mounted at `/opt/cronicle/data`.

## Goals

- Provide a low-friction Cronicle install that works with a single PVC and no
  external database.
- Keep the default access path private through port-forwarding.
- Expose the operational settings Cronicle needs for a production scheduler:
  public URL, SMTP identity, job memory ceiling, concurrency ceiling, persistent
  data, and optional ingress.
- Preserve sessions and scheduler state across pod restarts by keeping the
  data PVC stable and by documenting when operators should provide a stable
  `secret.existingSecret`.
- Document the storage and single-writer boundaries clearly so operators do not
  scale the chart into a split-brain scheduler.

## Non-Goals

- The chart does not install an external database because this Cronicle topology
  uses the upstream filesystem storage engine.
- The chart does not enable horizontal scaling by default.
- The chart does not install cert-manager, an Ingress controller, SMTP service,
  or shared RWX storage.
- The chart does not manage individual Cronicle jobs or plugins. Those are
  application-level objects configured in the Cronicle UI or API.

## Default Architecture

```text
Operator workstation
   |
   | kubectl port-forward
   v
ClusterIP Service
   |
   v
Cronicle Deployment (1 replica)
   |
   +--> ConfigMap mounted as /opt/cronicle/conf/config.json
   +--> Secret provides CRONICLE_secret_key
   +--> PVC mounted at /opt/cronicle/data
```

Default characteristics:

- one pod and one writable PVC;
- no public ingress;
- generated session secret for simple installs;
- Cronicle data, queue, job definitions, and job logs stored on the PVC;
- readiness, liveness, and startup probes use
  `/api/app/get_master_state/v1`.

## Public Access Architecture

```text
User or trusted network
   |
   v
Ingress Controller + TLS
   |
   v
Cronicle Service
   |
   v
Cronicle Pod
```

When `ingress.enabled=true`, `cronicle.baseUrl` must be set to the same public
URL. Cronicle uses this value for notification links and UI references. TLS,
authentication before Cronicle, IP allowlists, and controller-specific policy are
owned by the platform layer.

## Storage Model

Cronicle stores state as files under `/opt/cronicle/data`. This includes:

- scheduled event definitions;
- server and plugin metadata;
- queue state;
- run history and job logs;
- internal state used by the scheduler.

The chart uses a Deployment with `strategy.type=Recreate` to avoid two pods
mounting the same ReadWriteOnce volume during an update. This matches the
single-writer default and prevents overlapping scheduler instances during a
rolling rollout.

## Secret Strategy

`secret.create=true` renders an Opaque Secret containing `secret_key` for simple
installs. Because the value is generated at render time, production
installations that need stable sessions across upgrades should set
`secret.create=false` and `secret.existingSecret` to reference an
operator-managed Secret with the `secret_key` key. The Deployment exposes that
key as `CRONICLE_secret_key`, matching Cronicle's case-sensitive environment
override for the top-level `secret_key` configuration path.

## Multi-Server Boundary

Cronicle has upstream concepts for multi-server coordination and UDP discovery.
This chart exposes `cronicle.discoveryEnabled` and `cronicle.discoveryPort` so
advanced operators can experiment with that path, but the chart does not claim a
safe HA preset. A production multi-server topology requires shared storage or a
carefully validated upstream-compatible state layout.

## Validation Focus

From `helmforge-ops`, use `make validate-chart CHART=cronicle` as the required
gate. It runs dependency checks, strict Helm lint, template rendering, unit
tests, kubeconform with real schemas, Artifact Hub lint, and k3d behavioral
validation for the chart scenarios. Example files are rendered with Helm before
they are documented as copy-paste ready.
