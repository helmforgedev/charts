# changedetection.io Production Guide

Use this guide as a starting point for production deployments of the HelmForge
changedetection.io chart.

## Persistence

Keep `persistence.enabled=true` and size the PVC for snapshots and historical
diffs. Storage usage depends on the number of watches, check frequency, and
whether pages include large rendered screenshots.

```yaml
persistence:
  enabled: true
  size: 20Gi
  storageClass: fast-retain
```

Back up the PVC before upgrades. The application stores its SQLite database and
snapshot data under `/datastore`.

## Routing

Ingress remains the most common path:

```yaml
changedetection:
  baseUrl: "https://cd.example.com"

ingress:
  enabled: true
  ingressClassName: traefik
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

Gateway API is available for clusters that standardize on Gateway resources:

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: shared-gateway
      namespace: ingress
  hostnames:
    - cd.example.com
```

Do not enable both paths for the same hostname unless the platform routing
policy explicitly expects it.

## External Secrets

The chart can render ExternalSecret resources and consume the produced Secret
automatically:

```yaml
externalSecrets:
  enabled: true
  secretStoreRef:
    name: vault
    kind: ClusterSecretStore
  target:
    name: changedetection-env
    creationPolicy: Owner
  data:
    - secretKey: LOGGER_LEVEL
      remoteRef:
        key: changedetection/app
        property: loggerLevel
```

Use this pattern for notification provider secrets or other upstream-supported
environment variables.

## Browser Rendering

Enable the browser sidecar only when watches need JavaScript rendering:

```yaml
browser:
  enabled: true
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
```

Browser rendering materially increases CPU and memory usage. Tune pod resources
from observed workload behavior.

## Operations

Useful checks after deployment:

```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=changedetection --timeout=300s
kubectl logs -l app.kubernetes.io/name=changedetection --all-containers --tail=100
kubectl get events --sort-by=.lastTimestamp
```

The default Service can also opt into dual-stack networking:

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

---

keywords: changedetection, production, gateway-api, external-secrets
path: charts/changedetection/docs/production.md
