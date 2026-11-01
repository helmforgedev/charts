<!-- SPDX-License-Identifier: Apache-2.0 -->

# Stirling PDF

Authenticated document processing with the official full image
`docker.stirlingpdf.com/stirlingtools/stirling-pdf:2.14.3`, verified for Linux amd64 and arm64. The chart targets the
Community edition's embedded H2 deployment and keeps the native OCR, office and PDF toolchain available under a
restricted Kubernetes security context.

## Features

- Native administrator login from first start, with a retained generated password, existing Secret and ESO options.
- One retained PVC containing H2 authentication state, application configuration, custom files and pipelines.
- Non-root, read-only root filesystem, dropped capabilities, RuntimeDefault seccomp and no Kubernetes API token.
- Preserved OCR and office tools with seeded writable links and bounded temporary volumes.
- Startup, readiness and liveness checks against the native application endpoint.
- Authenticated native Prometheus on a separate private Service with a Secret-backed scrape job option.
- Ingress class, Gateway API HTTPRoute, dual-stack Service and explicit NetworkPolicy controls.
- Single-writer enforcement and `Recreate` upgrades; no unsupported shared-H2 replicas.

## Installation

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install stirling-pdf helmforge/stirling-pdf --namespace documents --create-namespace
kubectl -n documents port-forward service/stirling-pdf-stirling-pdf 8080:8080
```

Open `http://localhost:8080`. The initial administrator is `admin`; Helm NOTES identifies the credential Secret. For
production, supply `auth.existingSecret`, use a dedicated HTTPS hostname and restrict ingress to the edge controller.
Bootstrap credentials initialize a new database; rotate existing passwords through native account administration.

To inspect every supported value before installation:

```bash
helm show values helmforge/stirling-pdf
```

## Configuration

The defaults are production-oriented but intentionally single-instance. Do not set more than one replica, even with an
RWX volume: the embedded H2 database and workspace are one writer. Values not listed below remain documented in
`values.yaml` and constrained by `values.schema.json`.

| Parameter | Default | Purpose |
| --- | --- | --- |
| `image.repository` | `docker.stirlingpdf.com/stirlingtools/stirling-pdf` | Official full image repository |
| `image.tag` | `2.14.3` | Verified pinned application version |
| `replicaCount` | `1` | Required single H2 writer |
| `auth.username` | `admin` | Initial administrator for a new database |
| `auth.password` | `""` | Optional bootstrap password; generated when empty |
| `auth.existingSecret` | `""` | Existing Secret containing the bootstrap password |
| `auth.passwordKey` | `password` | Key read from the credential Secret |
| `server.port` | `8080` | Real application listener and container port |
| `server.basePath` | `""` | Optional public root URI prefix |
| `server.maxUploadSize` | `100MB` | Native per-file upload limit |
| `server.maxRequestSize` | `200MB` | Native multipart request limit |
| `service.type` | `ClusterIP` | Kubernetes application Service type |
| `service.port` | `8080` | Service-facing port targeting named port `http` |
| `ingress.enabled` | `false` | Render a Kubernetes Ingress |
| `gatewayAPI.enabled` | `false` | Render configured HTTPRoutes |
| `networkPolicy.enabled` | `true` | Render ingress and egress isolation |
| `networkPolicy.egressIsolation` | `true` | Restrict outbound traffic to declared rules |
| `persistence.enabled` | `true` | Persist H2 and workspace state |
| `persistence.existingClaim` | `""` | Reuse a pre-provisioned workspace claim |
| `persistence.size` | `10Gi` | Generated claim request |
| `persistence.retain` | `true` | Keep generated claim on Helm uninstall |
| `metrics.enabled` | `false` | Enable the private native management listener |
| `metrics.port` | `9090` | Management listener, separate from application HTTP |
| `metrics.scrapeConfig.enabled` | `false` | Generate a Prometheus additional-scrape Secret |
| `runtime.javaCustomOptions` | `-XX:MaxRAMPercentage=60.0` | Leave memory for native conversion tools |
| `runtime.temporarySize` | `4Gi` | Bound temporary document storage |
| `resources.requests.memory` | `1Gi` | Default pod memory request |
| `resources.limits.memory` | `4Gi` | Default pod memory limit |

Credential sources are mutually exclusive. Prefer an externally managed Secret in production:

```yaml
auth:
  existingSecret: documents-admin
persistence:
  size: 20Gi
  retain: true
```

The Secret must contain the configured `auth.passwordKey`. Changing initial credentials does not overwrite an account
already stored in H2. ESO users can declare canonical `externalSecrets.items`; see the CI scenario for a complete
SecretStore reference.

## Examples

Start with [simple values](examples/simple.yaml), [staging values](examples/staging.yaml) or the
[production example](examples/production.yaml). Production operators should also read
[operations](docs/operations.md), [monitoring](docs/monitoring.md) and [backup and recovery](docs/recovery.md).

The production example enables TLS Ingress and narrows ingress traffic by namespace. Application upload settings do not
change ingress-controller body limits or timeouts; configure those independently. Remote URL conversion is denied by
default egress isolation and requires explicit, narrow `networkPolicy.webEgress` rules.

## Architecture

One Deployment uses `Recreate` with one workspace claim. The claim is mounted through `configs`, `customFiles` and
`pipeline` subpaths, while temporary files, home, logs and tools use bounded `emptyDir` volumes. An init container seeds
the official tool directory so the writable mount does not hide Ghostscript, OCR and UNO commands. The application
Service always targets the named `http` listener; the optional metrics Service targets a separate management listener.

See [DESIGN.md](DESIGN.md) for the Mermaid topology, design decisions, production boundaries and non-goals.

## Capacity and availability

Defaults request 500m CPU and 1Gi memory, with limits of 2 CPU and 4Gi. The JVM heap ceiling is 60% of the container
memory limit; OCR, LibreOffice and native processes share the remaining budget. Load-test realistic concurrent
documents and monitor memory, temporary storage and PVC capacity. Upload limits are 100MB per file and 200MB per
request; align every proxy in the request path.

Restart and upgrade operations interrupt processing. Drain traffic and finish active jobs before maintenance. Shared
RWX storage does not make H2 a supported distributed database. Fresh-install native OAuth SSO and external SQL have
upstream license constraints; this chart validates password authentication and Community H2 only.

## Security

Treat uploaded documents as untrusted input to native parsers. Restrict the service to trusted users, terminate TLS at a
controlled edge, rotate native credentials and API keys, and keep document content out of logs. The default workload
runs as UID/GID 1000 with a read-only root filesystem, all capabilities dropped, privilege escalation disabled and no
mounted Kubernetes API token.

Default NetworkPolicy permits same-namespace application ingress and DNS egress. A policy-capable CNI is required.
Cross-namespace edge and Prometheus access must be selected explicitly. Image vulnerability assessment, cluster RBAC,
storage encryption and backup retention remain platform responsibilities; the published Kubescape score evaluates the
rendered Kubernetes configuration, not document-parser safety.

## Upgrade and recovery

Before an application-version upgrade, stop new traffic, finish conversions, scale the Deployment to zero and wait for
the pod to terminate. Then archive the complete workspace claim plus credential Secrets. Upgrade in place with the same
release name; resource names, credential keys and workspace mounts remain stable. Verify native login, a real
conversion, retained API keys and pipeline state after rollout.

For disaster recovery, restore into a fresh PVC with compatible ownership and set `persistence.existingClaim`. Start
with the original application image before moving forward. Helm rollback restores Kubernetes manifests but cannot undo
an H2 migration. The detailed, tested procedure is in [docs/recovery.md](docs/recovery.md).

## Troubleshooting

Check rollout state and application logs first:

```bash
kubectl -n documents get pods,pvc,service
kubectl -n documents logs deployment/stirling-pdf-stirling-pdf -c stirling-pdf
kubectl -n documents describe pod -l app.kubernetes.io/instance=stirling-pdf
```

If probes fail, confirm `server.basePath` matches the externally used prefix and do not disable probes to hide startup
errors. If conversions fail, inspect memory limits, temporary-volume capacity and the seeded `/usr/local/bin` tools.
Authentication failures after restore usually indicate that the credential Secret and H2 workspace came from different
recovery points. For metrics, verify the management Service is private, the API-key file is mounted in Prometheus and
the generated scrape job was merged rather than replacing existing jobs.

## Validation

From the charts repository, install the pinned fixture dependency and run the canonical gate from `helmforge-ops`:

```bash
npm ci --prefix charts/stirling-pdf/scripts
make validate-chart CHART=stirling-pdf
```

Runtime validation exercises native login, anonymous conversion rejection, a real two-document merge with page-text
extraction, API-key persistence and Secret retention. Dedicated profiles cover OCR, office conversion, recovery and
authenticated Prometheus. Release validation also upgrades the published chart with normal value merging and with
`--reuse-values` so existing installations keep working.

## Security Scan

Security Scan: stirling-pdf

| Framework | Score |
| --- | --- |
| MITRE + NSA + SOC2 | 100% |

Local Kubescape 4.0.13 scanned the default rendered resources. This is a Kubernetes configuration assessment, not an
image vulnerability or document-processing security audit.
