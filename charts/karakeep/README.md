# Karakeep Helm Chart

Deploy [Karakeep](https://karakeep.app), formerly Hoarder, on Kubernetes using
the official `ghcr.io/karakeep-app/karakeep` container image. Karakeep provides
bookmark management, full-text archive search, web page capture, and optional AI
tagging in a single-writer application pod.

Current application version: `0.32.0`.

## Features

- Official Karakeep image pinned to `0.32.0`
- Optional Meilisearch sidecar for full-text search
- Optional browserless Chromium sidecar for screenshots and page archiving
- SQLite and uploaded content stored on a PersistentVolumeClaim
- Generated `NEXTAUTH_SECRET` and `MEILI_MASTER_KEY` with lookup-based reuse on
  upgrades
- Existing Secret and External Secrets Operator paths for production credentials
- Ingress, Gateway API, dual-stack Service, scheduling, and resource controls

## Installation

HTTPS repository:

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install karakeep helmforge/karakeep -f values.yaml
```

OCI registry:

```bash
helm install karakeep oci://ghcr.io/helmforgedev/helm/karakeep -f values.yaml
```

## Examples

The chart includes example values under `examples/`:

- `examples/simple.yaml` - local or private-network deployment with explicit
  resources.
- `examples/ingress.yaml` - TLS ingress with sidecars enabled.
- `examples/ai-tagging.yaml` - AI tagging through Secret-backed environment
  variables.
- `examples/external-secrets.yaml` - External Secrets Operator projection for
  auth and search credentials.

Render an example before adapting it:

```bash
helm template karakeep charts/karakeep -f charts/karakeep/examples/ingress.yaml
```

## Architecture Guides

- [Design rationale](DESIGN.md)
- [Architecture guide](docs/architecture.md)
- [Operations guide](docs/operations.md)

## Basic Configuration

For local testing through port-forwarding:

```yaml
karakeep:
  nextAuthUrl: "http://localhost:3000"
```

Then access the web UI:

```bash
kubectl port-forward svc/<release>-karakeep 3000:80
```

For production, `karakeep.nextAuthUrl` must match the exact external URL users
open in the browser, including `https://` when TLS is enabled.

## Sidecars

Meilisearch and Chromium are enabled by default because they provide Karakeep's
search and archive capture experience. They also increase pod memory needs. Set
resources for each container in production:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

meilisearch:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

chromium:
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: "1"
      memory: 1Gi
```

Disable sidecars only when the workload can operate without their features:

```yaml
meilisearch:
  enabled: false

chromium:
  enabled: false
```

## Key Values

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `ghcr.io/karakeep-app/karakeep` | Main Karakeep image |
| `image.tag` | `"0.32.0"` | Main Karakeep image tag |
| `karakeep.nextAuthUrl` | `""` | Public URL of the Karakeep instance |
| `karakeep.browserConnectOnDemand` | `true` | Connect to Chromium only when crawling needs it |
| `karakeep.existingSecret` | `""` | Existing secret with auth and Meilisearch keys |
| `karakeep.extraEnv` | `[]` | Extra environment variables for AI and advanced configuration |
| `meilisearch.enabled` | `true` | Enable the Meilisearch sidecar |
| `chromium.enabled` | `true` | Enable the Chromium sidecar |
| `persistence.enabled` | `true` | Enable persistence for SQLite, uploads, and Meilisearch data |
| `persistence.size` | `10Gi` | PVC size |
| `ingress.enabled` | `false` | Enable Ingress |
| `gatewayAPI.enabled` | `false` | Enable Gateway API HTTPRoute |
| `externalSecrets.enabled` | `false` | Render ExternalSecret for app credentials |

## Security Scan

Security Scan: Kubescape on rendered default manifests.

| Framework | Score |
| --- | --- |
| MITRE | 100.00% |
| NSA | 60.00% |
| SOC2 | 80.00% |
| Aggregate | 80.00% |

Default findings are driven by intentionally unset platform-specific controls:
resource limits, container hardening context, service account token mounting, and
NetworkPolicy boundaries. Set `resources`, `securityContext`,
`podSecurityContext`, and platform NetworkPolicies according to your cluster
baseline.

## Quality Gates

Before proposing a merge for this chart, run:

```bash
make validate-chart CHART=karakeep
make standards-check CHART=karakeep
make deps-check CHART=karakeep
make site-sync-check CHART=karakeep
```

## Persistence

Karakeep stores SQLite, uploads, queue state, and optional sidecar data on the
PVC mounted at `/data`. The Deployment uses `strategy.type=Recreate` because the
default storage model is single-writer.

Use an existing PVC when migrating from another release:

```yaml
persistence:
  existingClaim: my-karakeep-pvc
```

## External Secrets

Use `externalSecrets.enabled=true` only with `karakeep.existingSecret`. The
ExternalSecret must populate both `nextauth-secret` and `meili-master-key` when
Meilisearch is enabled.

```yaml
karakeep:
  existingSecret: karakeep-app-secret

externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  data:
    - secretKey: nextauth-secret
      remoteRef:
        key: karakeep/credentials
        property: nextauth-secret
    - secretKey: meili-master-key
      remoteRef:
        key: karakeep/credentials
        property: meili-master-key
```

## Limitations

- Single replica by default; SQLite and the shared PVC are not a concurrent
  writer architecture.
- Ingress and Gateway API expose HTTP routing only; authentication and network
  boundaries outside Karakeep are platform responsibilities.
- AI providers are configured through `karakeep.extraEnv`; this chart does not
  create provider-specific API key Secrets.

## More Information

- [Karakeep documentation](https://docs.karakeep.app)
- [Karakeep source](https://github.com/karakeep-app/karakeep)
- [HelmForge chart source](https://github.com/helmforgedev/charts/tree/main/charts/karakeep)
