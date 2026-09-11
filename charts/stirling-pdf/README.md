# Stirling PDF

Authenticated document processing using the official full image
`docker.stirlingpdf.com/stirlingtools/stirling-pdf:2.14.3`. Verified Linux amd64 and arm64 manifests. This chart targets
the Community edition's embedded H2 deployment.

## Features

- Native administrator login from first start, retained generated password, existing Secret and ESO.
- One retained PVC containing H2 authentication state, configuration, custom files and pipelines.
- Non-root, read-only filesystem, dropped capabilities, seccomp and no Kubernetes API token.
- Preserved full OCR and office toolchain with seeded writable tool links and bounded temporary volumes.
- Authenticated native Prometheus on a separate Service, with a Secret-backed additional scrape job.
- Ingress class, Gateway API, dual-stack Service and explicit network isolation.
- Single-writer guards and Recreate upgrades; no unsupported shared-H2 replicas.

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install stirling-pdf helmforge/stirling-pdf --namespace documents --create-namespace
kubectl -n documents port-forward service/stirling-pdf-stirling-pdf 8080:8080
```

Open `http://localhost:8080`. The initial administrator is `admin`; Helm NOTES identifies its credential Secret. For
production, supply `auth.existingSecret`, use a dedicated HTTPS hostname and restrict ingress to your edge controller.
Bootstrap credentials initialize a new database; rotate existing passwords through native account administration.

See [production values](examples/production.yaml), [operations](docs/operations.md), [monitoring](docs/monitoring.md),
[recovery](docs/recovery.md) and [design](DESIGN.md).

## Capacity and availability

Defaults request 500m CPU and 1Gi memory, with limits of 2 CPU and 4Gi. The JVM heap ceiling is 60% of the container
memory limit; OCR, LibreOffice and native processes share the remaining budget. Load-test concurrent conversions and
monitor memory, temporary storage and PVC capacity. Upload limits are 100MB per file and 200MB per request; align proxy
limits.

One Deployment uses Recreate and a 10Gi RWO claim. Restart and upgrade operations interrupt processing; drain traffic
and finish active jobs before maintenance. Shared RWX storage does not make H2 a supported distributed database.
Fresh-install native OAuth SSO and external SQL have upstream license constraints. This chart does not claim paid
clustering or successful licensed SSO validation.

## Validation

From the charts repository, install the pinned PDF fixture dependency:

```bash
npm ci --prefix charts/stirling-pdf/scripts
```

Then run the canonical gate from helmforge-ops:

```bash
make validate-chart CHART=stirling-pdf
```

Runtime checks exercise native login, anonymous conversion rejection, a real two-document merge with independent
page-text extraction, API-key persistence and Secret retention. Dedicated profiles cover OCR, recovery and authenticated
Prometheus.

## Security Scan

Security Scan: stirling-pdf

| Framework          | Score |
| ------------------ | ----- |
| MITRE + NSA + SOC2 | 100%  |

Security posture acceptable. Local Kubescape 4.0.13 scanned the default rendered resources. This is a Kubernetes
configuration assessment, not an image vulnerability or document-processing security audit.

## Gateway API contract

Use `gatewayAPI.enabled` and `gatewayAPI.httpRoutes[]`. Set each route's `parentRefs` to a shared Gateway that allows
this namespace, and configure its HTTPS listener and public hostname. Routes accept labels, annotations and rules
with matches, filters and optional backend references; omitted backends target this chart's application Service.
Ingress and HTTPRoute resources can coexist. Verify controller conditions and public traffic before production use.
See the [Gateway API documentation](https://gateway-api.sigs.k8s.io/).
