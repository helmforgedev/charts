# BentoPDF

BentoPDF provides PDF tools that run in the user's browser. The official image contains a static application and NGINX.
This chart deploys a restricted, stateless service with native runtime tool controls and optional NGINX monitoring.

## Features

- Non-root UID/GID 101, read-only root, RuntimeDefault seccomp, no capabilities or Kubernetes API token.
- Tagged upstream routes, MIME types, compression and browser isolation headers preserved.
- Public runtime configuration with rollout checksums.
- Rolling updates, topology spreading, optional disruption budget and CPU autoscaling.
- Ingress, Gateway API HTTPRoute, dual-stack Services and default-deny pod egress.
- Official NGINX exporter, metrics Service, ServiceMonitor and PrometheusRule as opt-in features.
- Real browser validation merges distinct PDFs and parses the downloaded document.

## Installation

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install bentopdf helmforge/bentopdf --namespace bentopdf --create-namespace
kubectl -n bentopdf port-forward service/bentopdf-bentopdf 8080:8080
```

Open <http://localhost:8080>. Use a dedicated HTTPS hostname in production. SharedArrayBuffer needs a secure context;
localhost is an exception for testing.

## Deployment contract

The official image is `ghcr.io/alam00000/bentopdf:2.8.8`, verified for Linux amd64 and arm64. Deploy at the domain root.
BASE_URL, branding and CSP build arguments cannot be changed through runtime environment variables.

NGINX starts directly with configuration derived from the tagged upstream nginx.conf. Image-owned security-header
includes and assets remain immutable. Only `/etc/nginx/tmp` and `/tmp` are writable. ConfigMap changes trigger a rollout
because individual files use subPath mounts.

No database, Secret, ExternalSecret or PVC is required. There is no native login. Protect private installations through
edge authentication. Disabling tools is presentation control, not an authorization boundary.

## Privacy and network boundary

PDF operations execute on client devices. The browser test checks for document POST/PUT/PATCH requests to the
application server during the tested merge workflow. It does not audit every upstream tool or browser extension.

Access logs contain HTTP metadata such as paths and client addresses. Treat logs accordingly. There is no server-side
document backup dataset.

Some tools download WASM, OCR or font assets from CDNs in the browser. Denying pod egress does not block those requests.
The default image is not an offline guarantee. Air-gapped use requires hosting relevant assets and building an image
with matching URLs and CSP.

## Runtime configuration

```yaml
config:
  disabledTools:
    - compress-pdf
  editorDisabledCategories:
    - annotation-shape
    - redaction
```

Use exact upstream tool/category identifiers. Disabling a parent category disables its children. Unknown identifiers may
have no effect upstream. These controls do not enforce permissions.

## Availability

```yaml
replicaCount: 2
podDisruptionBudget:
  enabled: true
  maxUnavailable: 1
```

PDF processing does not occupy pod CPU. Replicas serve static content; spread them across failure domains. PDBs cover
voluntary disruption, not node failures. The chart rejects singleton PDBs to avoid blocking maintenance.

Optional HPA targets the bentopdf container CPU, requires metrics-server and CPU requests, and defaults to two minimum
replicas. HPA owns replica count when enabled. Scale-down stabilization is 300 seconds. Browser workload may not
increase serving CPU.

## Networking

The default Service is ClusterIP on 8080. Ingress and HTTPRoute reference existing controllers/Gateways. Terminate TLS
at the edge and preserve CSP, Cross-Origin-Opener-Policy and Cross-Origin-Embedder-Policy. Replacing these headers may
break workers and office conversions.

NetworkPolicy allows HTTP from the release namespace and denies outbound pod traffic by default. Configure
`networkPolicy.ingressFrom` for the edge namespace. `metrics.ingressFrom` separately grants exporter access.
`extraEgress` allows explicit rules. Enforcement requires a NetworkPolicy-capable CNI.

Service `ipFamilyPolicy`/`ipFamilies` support dual stack. PreferDualStack can fall back; RequireDualStack needs cluster
support. `server.ipv6` independently controls the NGINX listener.

## Observability

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    labels:
      release: prometheus
  prometheusRule:
    enabled: true
    labels:
      release: prometheus
```

Install Prometheus Operator CRDs and match monitor/rule labels to Prometheus selectors. The official exporter scrapes
loopback-only stub_status on 8081. The public application port does not expose that endpoint. Metrics default to
port 9113.

`nginx_up` reports exporter-to-NGINX connectivity. `nginx_http_requests_total` and connection gauges describe static
serving, not PDF operations or 5xx counts. The built-in alert detects nginx_up zero for five minutes. Configure
target-down alerts for missing exporters; use browser/blackbox checks for broader coverage.

## Upgrade and restore

```bash
helm upgrade bentopdf helmforge/bentopdf -n bentopdf -f production.yaml
kubectl -n bentopdf rollout status deployment/bentopdf-bentopdf
helm rollback bentopdf -n bentopdf
```

Review release notes and browser-cache compatibility. Existing tabs may need reloading after upgrades. Rolling updates
use maxUnavailable zero and maxSurge one; reserve extra pod capacity.

Keep values, edge configuration and image pins in version control. Reinstall the same chart/image/configuration to
recover server state. Client documents require client backups; Kubernetes snapshots cannot recover them.

## Validation

Install dependencies with `npm ci --prefix charts/bentopdf/scripts` and Chromium with
`npx --prefix charts/bentopdf/scripts playwright install chromium`. Run `make validate-chart CHART=bentopdf` from
helmforge-ops. The real browser test is not skipped when Chromium is unavailable.

## Security Scan

### Security Scan: `bentopdf`

| Framework          | Score    |
| ------------------ | -------- |
| MITRE + NSA + SOC2 | **100%** |

> Security posture acceptable.

Measured with Kubescape 4.0.13 against default manifests. This is a configuration assessment, not an application
security guarantee.

## Parameters

See [values.yaml](values.yaml) and [values.schema.json](values.schema.json) for the complete contract.

<!-- @AI-METADATA
 type: guide
 title: BentoPDF chart
 description: Production deployment of browser-local PDF tools
 keywords: bentopdf, pdf, nginx, privacy
 purpose: Explain deployment and operational boundaries
 scope: chart
 path: charts/bentopdf/README.md
 version: 1.0
 date: 2026-09-10
-->
