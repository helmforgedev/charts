# OliveTin Configuration

OliveTin reads its application configuration from `/config/config.yaml`. This chart renders that file from `.Values.config`.

## Minimal Command Panel

```yaml
config: |
  actions:
    - title: Show uptime
      shell: uptime
```

When `config` is empty, the chart renders a safe default action so the application can start and expose the UI.

## Application Port

`olivetin.port` configures the container port, probes, Service target, and the
upstream `PORT` environment variable. `PORT` is reserved by the chart; do not
repeat it in `olivetin.extraEnv`.

OliveTin 3000.18 also supports the `dnsname` argument type:

```yaml
config: |
  actions:
    - title: Resolve host
      shell: "getent hosts {{ hostname }}"
      arguments:
        - name: hostname
          type: dnsname
          default: example.com
```

## Runtime Template Handling

OliveTin supports its own runtime template syntax. For that reason, Helm `tpl` rendering is disabled by default.

Enable `configTpl.enabled=true` only when the file intentionally contains Helm template expressions:

```yaml
configTpl:
  enabled: true
config: |
  actions:
    - title: Namespace
      shell: echo "{{ .Release.Namespace }}"
```

## Secrets

Use External Secrets Operator or an existing Kubernetes Secret when commands need credentials. The chart intentionally does not put credentials in `config` by default.

```yaml
externalSecrets:
  enabled: true
  items:
    - name: command-credentials
      spec:
        secretStoreRef:
          name: platform-secrets
          kind: ClusterSecretStore
        target:
          name: olivetin-command-credentials
          creationPolicy: Owner
        data:
          - secretKey: API_TOKEN
            remoteRef:
              key: olivetin/command-api-token

olivetin:
  extraEnv:
    - name: API_TOKEN
      valueFrom:
        secretKeyRef:
          name: olivetin-command-credentials
          key: API_TOKEN
```

## Exposure

Use `ingress` for classic ingress controllers and `gatewayAPI.httpRoutes` for Gateway API.

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - name: web
      parentRefs:
        - name: public
          namespace: gateway-system
      hostnames:
        - olivetin.example.com
```

## Dual Stack Service

Dual-stack clusters can opt in through Service fields:

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

Leave these values unset on clusters that do not support dual-stack Services.

## Prometheus Metrics

OliveTin uses a separate Prometheus listener rather than the frontend
`olivetin.port`. Enable the listener and optional ServiceMonitor together:

```yaml
metrics:
  enabled: true
  port: 1341
  defaultGoMetrics: false
  serviceMonitor:
    enabled: true
    namespace: monitoring
    labels:
      release: kube-prometheus-stack
```

The chart sets `listenAddressPrometheus` to
`0.0.0.0:<metrics.port>`, exposes a named `metrics` Service port, and
configures ServiceMonitor to scrape `/metrics`. The chart-managed metrics
settings override `prometheus` and `listenAddressPrometheus` entries in a
custom `config` so the rendered configuration and Kubernetes ports cannot
drift.

## Persistence

The ConfigMap remains the source of `/config/config.yaml`. OliveTin also needs
writable session and theme paths under `/config`; the chart provides those
through an `emptyDir`, so they are ephemeral.

Enabling `persistence` mounts a PVC at `/data`. Only actions that explicitly
write files there use that storage:

```yaml
persistence:
  enabled: true
  size: 5Gi
  storageClass: fast
```

The chart does not back up `/data` or restore it.

## Security

OliveTin executes the shell commands defined in `config`. Configure upstream
authentication and ACLs or an authenticated reverse proxy before broad
exposure. Do not allow clients to bypass a proxy that supplies trusted identity
headers.

The pod runs non-root without Linux capabilities or an automatic
ServiceAccount token. When actions need the Kubernetes API, deliberately enable
token mounting and grant only the minimum RBAC. Credentials belong in Secrets
or External Secrets, not in `config`, because the latter is stored in a
ConfigMap.
