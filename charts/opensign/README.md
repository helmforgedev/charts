# OpenSign Helm chart

Deploy [OpenSign](https://www.opensignlabs.com), an open-source electronic
signature platform, with separate frontend and API workloads, HelmForge
MongoDB, durable document storage, External Secrets, and hardened Kubernetes
networking.

## Install

```bash
helm install opensign oci://ghcr.io/helmforgedev/helm/opensign \
  --version 1.0.0 \
  --namespace opensign \
  --create-namespace
```

The first user is created through the application. Configure HTTPS, a stable
master key, a signing certificate, SMTP, and tested backups before accepting
production documents.

## Runtime model

OpenSign consists of a React frontend on port 3000 and a Parse Server backend
on port 8080. The chart exposes them through separate Services and public
hostnames because the backend owns root-level Parse routes in addition to
`/app`.

The frontend defaults to two replicas and supports HPA. The backend remains a
single `Recreate` replica because upstream runs migrations during startup and
local document storage uses one writable volume. MongoDB is supplied by the
HelmForge subchart or by an external URI.

## Image provenance

Upstream publishes its deployment images through the mutable `main` channel.
This chart never renders that floating tag. It pins the official manifests
resolved for upstream v2.41.3 at commit
`e5f2c5c0a9f65ec01d8a53e4bf3a390c7ade7bcd` on 2026-10-21:

- Frontend: `docker.io/opensign/opensign@sha256:0ebc230eed21ced0d321a0df887c1a48e9f4bd423c2454fe865a262aec49f99a`
- Backend: `docker.io/opensign/opensignserver@sha256:cadfcaaa20bf40272aed43c91314362c1dac034b2a4651f50e5288d01c2b434d`

Review the [upstream release](https://github.com/OpenSignLabs/OpenSign/releases/tag/v2.41.3)
and re-verify both manifests before changing either digest.

## Secrets and signing

When `secrets.existingSecret` is empty, the chart creates and retains a random
Parse master key. Production GitOps installations should provide an existing
Secret or use the canonical `externalSecrets.items` mapping so the identity can
be restored independently of the Helm release.

OpenSign signs documents with a base64-encoded PKCS#12 certificate. Configure
`pfx-base64` and `pfx-passphrase` together. SMTP and S3 credentials are also
read from the same Secret; plain values exist only for bootstrap convenience.

## Storage and recovery

`storage.type=local` mounts a retained PVC at `/usr/src/app/files`.
`storage.type=s3` configures an S3-compatible bucket and uses an ephemeral
local work directory. Back up MongoDB, documents, the master key, certificate,
and integration credentials as one recovery set.

Restore the same OpenSign image digests into an isolated namespace, verify
login, template access, upload, signing, download, and email delivery, and only
then upgrade.

## Public exposure and networking

Ingress and Gateway API are opt-in. Use distinct frontend and API hostnames,
terminate TLS at the controller, set `config.publicUrl` to the frontend origin,
and keep `config.apiUrl` ending in `/app`.

NetworkPolicy is enabled by default. It allows frontend-to-backend traffic,
DNS, MongoDB, public HTTP/HTTPS, and the configured SMTP port. Private database,
SMTP, S3, webhook, or proxy destinations require explicit
`networkPolicy.extraEgress` rules.

Both application containers run as UID/GID 1000 with read-only root
filesystems. Bounded writable volumes hold the frontend build, backend copy-up,
exports, signing work files, and `/tmp` without weakening the container root.

## Availability

The default frontend has two replicas and an enabled PodDisruptionBudget.
Enable `frontend.autoscaling` only when resource metrics are available. The
backend intentionally remains a singleton; use resilient MongoDB and object
storage to protect state, and schedule upgrades with a brief API interruption.

## Key values

| Value | Default | Purpose |
|---|---:|---|
| `frontend.replicaCount` | `2` | Stateless web replicas |
| `frontend.autoscaling.enabled` | `false` | CPU or memory based frontend HPA |
| `frontend.podDisruptionBudget.enabled` | `true` | Protect frontend availability |
| `mongodb.enabled` | `true` | Bundled HelmForge MongoDB |
| `mongodb.auth.rootPassword` | `""` | Optional URI-safe password; empty lets the subchart generate one |
| `storage.type` | `local` | Local PVC or S3-compatible documents |
| `storage.persistence.size` | `10Gi` | Local document capacity |
| `secrets.existingSecret` | `""` | Stable master key and integration credentials |
| `networkPolicy.enabled` | `true` | Component-aware traffic isolation |
| `ingress.enabled` | `false` | Kubernetes Ingress exposure |
| `gateway.enabled` | `false` | Gateway API exposure |

Every value is documented in [values.yaml](values.yaml) and constrained by
[values.schema.json](values.schema.json).

## Validation scenarios

The chart validates the default topology, immutable images, generated and
external Secrets, local and S3 storage contracts, external MongoDB, Ingress,
Gateway API, dual-stack Services, HPA, disruption protection, and invalid
configuration fail-fast behavior. The k3d smoke verifies both HTTP workloads,
runtime UID 1000, stable master-key retention, clean logs/events, and MongoDB
connectivity.

## Security scan

Security Scan: opensign

| Framework | Score |
|---|---:|
| MITRE | **100.00%** |
| NSA | **91.08%** |
| SOC 2 | **96.00%** |
| Aggregate resource score | **93.99%** |

Kubescape reported no critical or high-severity failures. The remaining medium
and low findings are limited to the maintained MongoDB dependency, whose
writable data filesystem and bootstrap context are required by the upstream
database image.

## Limitations

- Upstream does not publish immutable version tags for both deployment images;
  this chart therefore records verified release-associated digests.
- The backend is deliberately singleton because migrations run at startup.
- Local `ReadWriteOnce` storage cannot support multiple backend replicas.
- OpenSign does not expose a documented Prometheus endpoint, so the chart does
  not create a misleading ServiceMonitor.

## Additional documentation

- [Design](DESIGN.md)
- [Research](RESEARCH.md)
- [Implementation plan](PLAN.md)
- [External services](docs/external-services.md)
- [Operations and recovery](docs/operations.md)
- [Production example](examples/production.yaml)
