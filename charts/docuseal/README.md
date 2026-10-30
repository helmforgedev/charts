# DocuSeal Helm chart

Deploy [DocuSeal](https://www.docuseal.com), an open-source electronic-signature
platform, with a pinned official image, HelmForge PostgreSQL and Redis subcharts,
durable attachments, External Secrets, and hardened Kubernetes networking.

## Features

- Official DocuSeal image pinned by immutable multi-platform digest.
- Bundled or external PostgreSQL and Redis with Secret-based credentials.
- Retained local attachments or S3-compatible shared storage.
- Configurable Puma listener, named Service target, and `/up` health probes.
- External Secrets, Ingress, Gateway API, dual-stack, and NetworkPolicy support.
- Non-root, read-only runtime with dropped capabilities and seccomp enabled.

## Install

```bash
helm install docuseal oci://ghcr.io/helmforgedev/helm/docuseal \
  --version 1.0.0 \
  --namespace docuseal \
  --create-namespace
```

## Architecture and production topology

The default is a durable single-replica deployment backed by HelmForge
PostgreSQL and Redis. An init container prepares the database before each Pod
can start. Puma listens on `containerPorts.http` through the upstream `PORT`
environment variable, while `service.port` remains the independent
cluster-facing port. The application uses the upstream `/up` health endpoint,
runs as UID/GID 2000, and persists `/data/docuseal`.

For multiple replicas, the chart requires external PostgreSQL, external Redis,
S3-compatible attachment storage, and a pre-provisioned identity Secret. Those
requirements prevent unsafe local-state scale-out.

## Image provenance

The default image is
`docker.io/docuseal/docuseal@sha256:28d0ca583860e2c73e5b068756023a93a325799a22da1f788355d566865dd051`,
the official DocuSeal 3.3.3 image verified on 2026-10-21. The human-readable
`image.tag` is informational; Kubernetes always receives the immutable digest.

## Secrets

By default, the chart creates and retains `SECRET_KEY_BASE` and
`ENCRYPTION_SECRET` with Helm cluster lookup so upgrades preserve identity. For
GitOps and disaster recovery, set `docuseal.existingSecret`. The same Secret can
hold S3 and SMTP credentials, or be materialized by External Secrets Operator.

Never rotate the encryption secret without following upstream recovery
procedures; existing encrypted values may become unreadable.

## Network and exposure

Ingress and Gateway API are opt-in and mutually exclusive. NetworkPolicy allows
namespace-local HTTP, DNS, the selected PostgreSQL and Redis services, and
public HTTP/HTTPS. Private external services require explicit peer selectors or
additional egress rules.

## State and recovery

Back up PostgreSQL, the attachment PVC or S3 bucket, and the application
identity Secret as one recovery set. Redis contains asynchronous job state and
should also be protected where losing queued work is unacceptable. Restore the
same image version in an isolated namespace and verify login, document access,
upload, signing, and email before upgrading.

## Key values

| Value | Default | Purpose |
|---|---:|---|
| `image.tag` | `3.3.3` | Human-readable upstream release |
| `image.digest` | pinned | Immutable official image |
| `replicaCount` | `1` | Application replicas |
| `containerPorts.http` | `3000` | Puma HTTP listener configured through `PORT` |
| `service.port` | `3000` | Independent cluster-facing Service port |
| `docuseal.existingSecret` | `""` | Persistent application identity and credentials |
| `postgresql.enabled` | `true` | Bundled HelmForge PostgreSQL |
| `redis.enabled` | `true` | Bundled HelmForge Redis |
| `storage.type` | `local` | Local PVC or S3 attachment storage |
| `migrations.enabled` | `true` | Database preparation init container |
| `networkPolicy.enabled` | `true` | Product-aware isolation |
| `networkPolicy.allowPublicInternet` | `true` | Public web egress excluding private ranges |

Every value is documented in [values.yaml](values.yaml) and constrained by
[values.schema.json](values.schema.json).

## Configuration example

The process listener and Service port are deliberately independent:

```yaml
containerPorts:
  http: 3100
service:
  port: 8080
docuseal:
  appUrl: https://signatures.example.com
  forceSsl: true
```

Puma receives `PORT=3100`; the Service exposes `8080` and targets the named
`http` port. See the complete [production example](examples/production.yaml)
for external dependencies, S3 storage, and a stable identity Secret.

## Examples

- [Production values](examples/production.yaml)
- [External services](docs/external-services.md)
- [Operations and recovery](docs/operations.md)

## Validation scenarios

The chart tests the default topology, a custom application listener, dual-stack Service, Ingress, Gateway API,
native External Secrets, retained identity, HA prerequisites, and external
service isolation. The k3d smoke verifies `/up`, UID 2000, identity retention,
clean events and logs, successful migrations, and stable workloads.

## Security scan

Security Scan: docuseal

| Framework | Score |
|---|---:|
| MITRE | **100.00%** |
| NSA | **91.25%** |
| SOC 2 | **94.29%** |
| Aggregate resource score | **93.83%** |

Kubescape reported no critical or high-severity failures. The remaining medium
and low findings are limited to the maintained PostgreSQL and Redis subcharts,
whose writable data filesystems and independent network policies are required.

## Troubleshooting

Inspect application and migration output separately because migrations run as
an init container, not a Job:

```bash
kubectl -n docuseal rollout status deployment/docuseal-docuseal
kubectl -n docuseal logs deployment/docuseal-docuseal -c migrate
kubectl -n docuseal logs deployment/docuseal-docuseal -c docuseal
kubectl -n docuseal get events --sort-by=.lastTimestamp
```

If the Pod is not ready, verify PostgreSQL and Redis connectivity, Secret key
names, writable attachment storage, and any private NetworkPolicy peers before
changing the health probe timings.

## Limitations

- Horizontal scaling is intentionally rejected without fully shared state.
- The chart does not create a ServiceMonitor because upstream does not document
  a native Prometheus metrics contract.
- Private SMTP and S3 endpoints may need installation-specific egress rules.

## Additional documentation

- [Design](DESIGN.md)
- [External services](docs/external-services.md)
- [Operations and recovery](docs/operations.md)
- [Production example](examples/production.yaml)
