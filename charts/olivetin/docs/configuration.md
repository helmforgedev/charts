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
