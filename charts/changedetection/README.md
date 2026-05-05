# changedetection.io Helm Chart

Deploy [changedetection.io](https://changedetection.io) on Kubernetes using the
official [dgtlmoon/changedetection.io](https://github.com/dgtlmoon/changedetection.io)
container image. Monitor websites for changes, track price or stock updates,
run selective content filters, and send notifications through email, Slack,
Discord, Telegram, webhooks, and 90+ Apprise services.

## Features

- **Website monitoring** — detect content changes on any URL
- **90+ notification channels** — via built-in Apprise library
- **Optional JavaScript rendering** — Playwright browser sidecar for dynamic sites
- **SQLite storage** — zero external database dependencies
- **Persistent storage** — snapshots and history on PVC
- **Ingress support** — TLS with cert-manager
- **Configurable probes** — startup, readiness, and liveness checks
- **Runtime tuning** — fetch workers, recheck interval, timezone, labels, annotations, resources, scheduling, and extra manifests

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install changedetection helmforge/changedetection -f values.yaml
```

**OCI registry:**

```bash
helm install changedetection oci://ghcr.io/helmforgedev/helm/changedetection -f values.yaml
```

## Basic Example

```yaml
# values.yaml — default values are sufficient for basic usage
changedetection:
  baseUrl: "https://cd.example.com"
```

After deploying:

```bash
kubectl port-forward svc/<release>-changedetection 5000:80
# Open http://localhost:5000
```

## JavaScript Rendering

Enable the Playwright browser sidecar for monitoring JavaScript-heavy sites:

```yaml
browser:
  enabled: true
```

The sidecar runs `ghcr.io/browserless/chromium` and the main container receives
`PLAYWRIGHT_DRIVER_URL` automatically. Keep browser resources sized separately
from the application container when JavaScript rendering is used heavily.

## Persistence

changedetection.io stores its SQLite database, snapshots, and watch history in
`/datastore`. Persistence is enabled by default:

```yaml
persistence:
  enabled: true
  size: 10Gi
  storageClass: ""
```

For disposable test environments, disable persistence to use an `emptyDir`:

```yaml
persistence:
  enabled: false
```

Because SQLite is used, this chart intentionally deploys a single replica with
the `Recreate` strategy. Do not scale the workload horizontally unless the
upstream application storage model changes.

## Ingress

```yaml
changedetection:
  baseUrl: "https://cd.example.com"

ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  hosts:
    - host: cd.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - cd.example.com
      secretName: changedetection-tls
```

Set `changedetection.baseUrl` to the public URL used by users and notification
links.

## Runtime Configuration

```yaml
changedetection:
  fetchWorkers: 10
  minimumSecondsRecheckTime: "180"
  timezone: "America/Sao_Paulo"
  extraEnv:
    - name: LOGGER_LEVEL
      value: INFO
```

Use `changedetection.extraEnv` for upstream-supported environment variables that
are not exposed as first-class chart values.

## Security And Scheduling

The chart exposes standard Kubernetes controls for production placement and
hardening:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL

podSecurityContext: {}
nodeSelector: {}
tolerations: []
affinity: {}
topologySpreadConstraints: []
priorityClassName: ""
```

## Probes

Startup, liveness, and readiness probes are enabled by default and use the HTTP
container port through TCP socket checks. Tune probe timings for slow storage or
large existing datastores:

```yaml
probes:
  startup:
    failureThreshold: 30
  liveness:
    periodSeconds: 15
  readiness:
    periodSeconds: 10
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `ghcr.io/dgtlmoon/changedetection.io` | changedetection.io image repository |
| `image.tag` | Chart appVersion | changedetection.io image tag |
| `image.pullPolicy` | `IfNotPresent` | Image pull policy |
| `changedetection.port` | `5000` | Application port |
| `changedetection.baseUrl` | `""` | Public base URL |
| `changedetection.fetchWorkers` | `10` | Concurrent fetch workers |
| `changedetection.minimumSecondsRecheckTime` | `""` | Minimum seconds between checks |
| `changedetection.timezone` | `""` | Container timezone via `TZ` |
| `changedetection.extraEnv` | `[]` | Extra environment variables |
| `browser.enabled` | `false` | Enable Playwright browser sidecar |
| `browser.image.repository` | `ghcr.io/browserless/chromium` | Browser sidecar image repository |
| `browser.image.tag` | `v2.46.0` | Browser sidecar image tag |
| `persistence.enabled` | `true` | Enable persistence for /datastore |
| `persistence.size` | `10Gi` | PVC size |
| `persistence.storageClass` | `""` | PVC storage class |
| `persistence.existingClaim` | `""` | Existing PVC name |
| `service.type` | `ClusterIP` | Kubernetes Service type |
| `service.port` | `80` | HTTP Service port |
| `ingress.enabled` | `false` | Enable ingress |
| `probes.*.enabled` | `true` | Enable startup, readiness, and liveness probes |
| `resources.requests.cpu` | `100m` | Main container CPU request |
| `resources.requests.memory` | `256Mi` | Main container memory request |
| `resources.limits` | unset | Optional main container resource limits |
| `securityContext.allowPrivilegeEscalation` | `false` | Prevent privilege escalation |
| `securityContext.capabilities.drop` | `[ALL]` | Drop Linux capabilities by default |
| `extraManifests` | `[]` | Additional manifests rendered with the release |

## Upgrade Notes

For this release the application image is updated to `0.55.3`. Review the
upstream changelog before production rollout and test restores from the
`/datastore` backup when upgrading long-lived instances.

## Limitations

- **Single instance only** — SQLite does not support concurrent writers
- **Storage grows** — each snapshot consumes disk space; plan PVC size accordingly
- **Browser rendering costs more** — enabling the browser sidecar increases CPU
  and memory consumption

## More Information

- [changedetection.io documentation](https://changedetection.io)
- [changedetection.io releases](https://github.com/dgtlmoon/changedetection.io/releases)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/changedetection)
