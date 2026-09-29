# Attic

Production-ready Helm chart for the [Attic](https://github.com/zhaofengli/attic)
Nix binary cache server.

## Why this chart

Attic provides content-addressed global deduplication, multi-tenant caches,
managed cache signing and token-scoped access. This chart turns the upstream
runtime modes into two explicit Kubernetes topologies and prevents unsafe
combinations at render time.

The upstream project is still an early prototype and does not publish semantic
releases. HelmForge therefore marks this chart beta and pins an official image
by immutable commit SHA.

## Installation

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install attic helmforge/attic --namespace attic --create-namespace
```

OCI installation:

```bash
helm install attic oci://ghcr.io/helmforgedev/helm/attic \
  --namespace attic --create-namespace --version 1.0.0
```

## Topologies

### Standalone

The default runs `atticd --mode monolithic` with SQLite and local object
storage on one PVC. It uses one replica and a Recreate deployment strategy.
This topology is appropriate for personal caches, build labs and small teams.

```yaml
mode: standalone
persistence:
  size: 50Gi
config:
  apiEndpoint: https://cache.example.com/
  allowedHosts: [cache.example.com]
```

### Distributed

Distributed mode runs a replicated stateless API, a singleton garbage
collector and a pre-install/pre-upgrade database migration Job. It requires
external PostgreSQL, S3-compatible storage and a pre-existing Secret.

```yaml
mode: distributed
replicaCount: 3
database:
  type: postgresql
storage:
  type: s3
  s3:
    region: us-east-1
    bucket: company-attic-cache
auth:
  generate: false
  existingSecret: attic-production
pdb:
  enabled: true
```

The Secret must provide `database-url` and one JWT signing key. S3 credential
keys are optional when workload identity is used.

## Secret contract

| Key | Environment variable | Purpose |
| --- | --- | --- |
| `token-hs256-secret-base64` | `ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64` | HMAC signing and verification |
| `token-rs256-secret-base64` | `ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64` | RSA private signing key |
| `token-rs256-pubkey-base64` | `ATTIC_SERVER_TOKEN_RS256_PUBKEY_BASE64` | RSA verification key |
| `database-url` | `ATTIC_SERVER_DATABASE_URL` | PostgreSQL connection URL |
| `aws-access-key-id` | `AWS_ACCESS_KEY_ID` | Optional S3 access key |
| `aws-secret-access-key` | `AWS_SECRET_ACCESS_KEY` | Optional S3 secret key |

Standalone mode generates and reuses an HS256 Secret when no existing Secret
is selected. Production installations should manage stable signing material
outside the chart. Changing JWT keys, issuer or audience invalidates tokens.

## Exposure

Ingress and Gateway API are opt-in. Set `config.apiEndpoint` to the externally
visible HTTPS URL, including the trailing slash, and put every accepted host in
`config.allowedHosts`.

Nix uploads can be large and long-running. Configure the proxy or Gateway for
unlimited/appropriate body size and generous read/write timeouts. Subpath
routing is not a default because canonical Attic endpoints must stay aligned.

See [docs/exposure.md](docs/exposure.md).

## Storage and backup

Standalone backup must preserve both the SQLite database and local object
directory. Quiesce uploads and garbage collection before taking a consistent
PVC snapshot.

Distributed backup must coordinate PostgreSQL backup/PITR with S3 object
versioning and retention. Restoring only one side can leave metadata pointing
to missing objects. Attic has no native backup command.

Custom S3 endpoints may be embedded in presigned client URLs. The endpoint
must be reachable by Nix clients, not only from the Attic pod.

See [docs/storage-and-backup.md](docs/storage-and-backup.md).

## Security

Defaults run the root-default upstream image as UID/GID 10001, drop all Linux
capabilities, use RuntimeDefault seccomp, disable privilege escalation and
mount the root filesystem read-only. The data PVC and `/tmp` remain writable.
The ServiceAccount token is not mounted.

`requireProofOfPossession` defaults to true. Keep it enabled unless you have a
well-understood compatibility reason. Distribute cache public keys through a
trusted channel because they participate in Nix supply-chain trust.

See [docs/security.md](docs/security.md).

## Observability and health

Attic writes structured Rust tracing logs to stdout/stderr. Set
`config.logLevel` to change `RUST_LOG`. The pinned upstream version has no
Prometheus endpoint, so this chart intentionally does not render a
ServiceMonitor.

Startup, liveness and readiness probes use TCP 8080. They verify the process
listener only and do not prove PostgreSQL or S3 health. Validate production
readiness with a real cache create/push/pull workflow and monitor proxy, DB,
bucket and Kubernetes metrics externally.

## Garbage collection

Standalone monolithic mode owns garbage collection. Distributed mode creates
exactly one `garbage-collector` process because upstream states it cannot be
replicated. Time-based deletion is disabled when the default retention is
`"0"`; set retention deliberately after confirming backup policy.

Changing chunking parameters does not corrupt data, but reduces deduplication
for newly uploaded NARs because chunk boundaries change.

## Configuration reference

The complete default contract is documented in [values.yaml](values.yaml) and
validated by [values.schema.json](values.schema.json). Major groups are:

| Group | Purpose |
| --- | --- |
| `mode`, `replicaCount` | Standalone or distributed lifecycle |
| `config` | Endpoints, hosts, chunking, compression, GC and JWT claims |
| `database` | SQLite path or PostgreSQL Secret mapping |
| `storage` | Local path or S3 bucket/endpoint mapping |
| `auth` | Generated or existing signing/database credential Secret |
| `persistence` | Standalone PVC lifecycle |
| `ingress`, `gatewayAPI` | Optional external HTTP routing |
| `externalSecrets` | Canonical External Secrets resources |
| `networkPolicy`, `pdb` | Availability and traffic policy |
| `podSecurityContext`, `securityContext` | Pod hardening |

## Examples

- [Standalone cache](examples/simple.yaml)
- [Distributed production](examples/production.yaml)
- [Ingress](examples/ingress.yaml)
- [Gateway API](examples/gateway-api.yaml)
- [External Secrets](examples/external-secrets.yaml)

## Upgrade policy

The image tag is an upstream commit, not a semver release. Before changing it:

1. read upstream commits and database migrations;
2. back up metadata and objects together;
3. validate both config and migration modes;
4. exercise a real cache push and pull;
5. retain a rollback image and compatible backup.

Do not roll back the container after a database migration unless upstream
confirms backward compatibility.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| HTTP 400 | Add the request hostname to `config.allowedHosts` |
| Push timeout | Increase proxy body-size and timeouts |
| Database error | Verify `database-url` and network egress |
| S3 download fails | Ensure the configured endpoint is client-reachable |
| Permission denied | Verify PVC `fsGroup` behavior and UID 10001 ownership |
| Tokens stop working | Check signing key, issuer and audience changes |
| Pod Ready but operations fail | TCP probes do not validate DB or S3 |
| Migration hook fails | Inspect the hook Job and PostgreSQL permissions |
| GC does not free space | Check cache retention and GC logs |
| Deduplication drops | Check whether chunking values changed |

## Security Scan

Security scan results use the same Kubescape policy set as HelmForge CI.

```text
Security Scan: attic
Framework                  Score
MITRE + NSA + SOC2         95.454544%
Security posture acceptable.
```

## Non-goals

- Installing PostgreSQL or an S3 service inside this chart.
- Generating or rotating production RSA keys.
- Inventing metrics or deep readiness endpoints absent upstream.
- Hiding the upstream early-prototype and compatibility risks.

## References

- [Attic source](https://github.com/zhaofengli/attic)
- [Attic documentation](https://docs.attic.rs)
- [Configuration guide](docs/configuration.md)
- [Operations guide](docs/operations.md)
- [Security guide](docs/security.md)
- [Storage and backup guide](docs/storage-and-backup.md)
