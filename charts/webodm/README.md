<!-- SPDX-License-Identifier: Apache-2.0 -->

# WebODM Helm Chart

WebODM provides browser-based aerial imagery processing backed by PostgreSQL
with PostGIS, Redis, Celery, and a private NodeODM processor.

## Features

- Official WebODM and NodeODM images pinned by version and immutable digest.
- Separate web, Celery worker, and authenticated processing workloads.
- Configurable application and processing listeners independent from Services.
- Bundled maintained PostgreSQL/PostGIS and Redis dependencies or external
  service contracts backed by existing Secrets.
- Retained media and processing claims, CPU and NVIDIA GPU modes, OIDC,
  Ingress, Gateway API, External Secrets, PodDisruptionBudget, and scheduling
  controls.
- NetworkPolicy enabled by default, restricted service-account token mounting,
  RuntimeDefault seccomp, probes, Helm tests, and behavioral k3d validation.

## Install

```bash
helm install webodm oci://ghcr.io/helmforgedev/helm/webodm \
  --namespace webodm --create-namespace
```

The default installation is suitable for functional evaluation. Photogrammetry
jobs need substantially more CPU, memory, and storage than the defaults.

## Storage and backup

WebODM web and worker pods share the media claim. Configure `ReadWriteMany`
storage before increasing `worker.replicaCount`. Back up the PostgreSQL database
and the media claim at the same recovery point. NodeODM task storage is retained
by default but is not a substitute for the WebODM media backup.

With the default `ReadWriteOnce` media claim, the worker is scheduled onto the
web pod's node. A user-defined global `affinity` replaces this default, so keep
equivalent co-location rules unless the media claim supports `ReadWriteMany`.

## Security

The official upstream images currently initialize services as root. The chart
drops all capabilities except the small set required by the upstream startup
scripts, disables privilege escalation, and does not mount service account
tokens. NetworkPolicy is enabled by default. Keep the NodeODM Service private,
expose only the WebODM HTTP Service, and add explicit controller or external
service peers when the cluster CNI enforces policy.

## Architecture support

WebODM and the default CPU NodeODM image support amd64 and arm64. The bundled
PostGIS image is amd64-only. Use an external PostGIS database on arm64 clusters.

## GPU processing

Set `processing.gpu.enabled=true` to use the pinned official CUDA-enabled
NodeODM image. GPU mode requests `nvidia.com/gpu`, supports an optional
`runtimeClassName`, and accepts GPU-specific node selectors and tolerations.
It requires amd64 nodes with a working NVIDIA device plugin and driver stack.

## OpenID Connect

WebODM 3.3.0 supports one or more OIDC providers through
`settings_override.py`. This chart renders one provider from the `oidc` block
and reads its client secret exclusively from `oidc.existingSecret`. Configure
the callback URI as `https://YOUR_HOST/oidc/callback/` at the identity provider.
Email allowlists, profile synchronization, custom scopes, and group claims are
supported. See [OIDC configuration](docs/oidc.md).

## External exposure

Ingress and Gateway API HTTPRoute are opt-in. Expose only the WebODM Service;
the authenticated NodeODM Service is intentionally private. Photogrammetry
uploads and downloads are large and long-running, so configure body-size and
timeout settings on the selected proxy. When NetworkPolicy is enabled, add the
Ingress controller or Gateway data-plane namespace to `networkPolicy.ingressFrom`.

## External Secrets

Set `externalSecrets.enabled=true` and define canonical `items` to project the
application, database, Redis, or OIDC Secrets. External Secrets Operator must
already be installed. Point the corresponding `existingSecret` value at each
projected target. See [External Secrets](docs/external-secrets.md).

## Configuration reference

The complete values contract is documented inline in [values.yaml](values.yaml)
and enforced by [values.schema.json](values.schema.json). Production examples
are available under [examples](examples).

| Parameter | Default | Purpose |
| --- | --- | --- |
| `web.containerPort` | `8000` | Configures the actual upstream WebODM NGINX listener through `WO_PORT`. |
| `service.port` | `80` | Exposes WebODM inside the cluster without changing the process listener. |
| `worker.replicaCount` | `1` | Scales Celery workers; values above one require RWX media storage. |
| `processing.enabled` | `true` | Deploys and registers a private NodeODM processor. |
| `processing.containerPort` | `3000` | Configures the actual NodeODM `--port` listener. |
| `processingService.port` | `3000` | Exposes NodeODM privately and independently from its process listener. |
| `processing.gpu.enabled` | `false` | Selects the pinned CUDA image and requests NVIDIA resources. |
| `persistence.size` | `20Gi` | Sizes the shared WebODM media claim. |
| `processing.persistence.size` | `20Gi` | Sizes retained NodeODM task storage. |
| `networkPolicy.enabled` | `true` | Isolates chart workloads while permitting required in-release traffic. |
| `webodm.existingSecret` | `""` | Uses an externally managed Django key and processor token Secret. |
| `oidc.enabled` | `false` | Renders one WebODM OIDC provider from non-secret values and a Secret. |

Application listener ports and Service ports are separate by design. Changing
`web.containerPort` updates `WO_PORT`, the container port, and probes; changing
`processing.containerPort` updates the NodeODM command, container port, and
probes. Services continue to route by the named `http` target port.

## Examples

- [Simple evaluation](examples/simple.yaml)
- [Production-oriented sizing](examples/production.yaml)
- [OIDC login](examples/oidc.yaml)
- [NVIDIA GPU processing](examples/gpu.yaml)
- [Gateway API exposure](examples/gateway-api.yaml)
- [External Secrets Operator](examples/external-secrets.yaml)

Use the examples as starting points and review every resource, persistence, and
network value against the target cluster. They do not contain production
credentials and do not replace a restore or representative processing test.

## Architecture and operations

The detailed guides separate design intent from day-two procedures:

- [Architecture](docs/architecture.md)
- [Security](docs/security.md)
- [Operations](docs/operations.md)
- [OIDC](docs/oidc.md)
- [External Secrets](docs/external-secrets.md)

When an external application, OIDC, database, or Redis Secret is rotated, Helm
cannot checksum the data it does not own. Restart the consuming Deployments and
wait for their rollouts after the secret manager updates the Kubernetes Secret.

## Validation

```bash
helm lint --strict charts/webodm
helm unittest charts/webodm
helm test webodm --namespace webodm --logs
```

The Helm test checks both the WebODM HTTP endpoint and the authenticated
NodeODM `/info` endpoint.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Web pod waits for PostgreSQL | Database host, password Secret and PostGIS initialization |
| Worker stays unready | Redis credentials, Web Service readiness and Celery logs |
| Processor appears offline | Registration Job and processor token consistency |
| Large upload fails | Proxy request body and read/write timeouts |
| Job is evicted | CPU, memory, ephemeral-storage and PVC capacity |
| OIDC button is absent | Provider endpoints, client Secret and mounted settings override |

## Security Scan

Security scan results use the same Kubescape policy set as HelmForge CI.

```text
Security Scan: webodm
Framework                  Score
MITRE + NSA + SOC2         87.9762%
Security posture acceptable.
```

## Uninstall

PersistentVolumeClaims and the generated application Secret use the Helm keep
policy. Delete them explicitly only after confirming that their data is no
longer required.

## References

- [WebODM source](https://github.com/WebODM/WebODM)
- [WebODM documentation](https://docs.webodm.org/)
- [NodeODM source](https://github.com/OpenDroneMap/NodeODM)
- [HelmForge documentation](https://helmforge.dev/docs/charts/webodm)
