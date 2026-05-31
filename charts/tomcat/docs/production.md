# Production Guidance

Use a pinned application artifact, explicit resources, NetworkPolicy, and either Ingress or Gateway API.

```yaml
replicaCount: 2

webapps:
  defaultRoot:
    enabled: false
  copyImageContent:
    enabled: true

startupProbe:
  mode: tcp
livenessProbe:
  mode: tcp
readinessProbe:
  mode: tcp

networkPolicy:
  enabled: true
  ingress:
    extraFrom:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: gateway-system

pdb:
  enabled: true
```

When Tomcat is behind a reverse proxy, use `tomcat.serverXml` or an existing ConfigMap to configure connector proxy attributes so applications see the correct external scheme, host, and port.

For immutable Tomcat application images, keep `webapps.copyImageContent.enabled=true`.
The chart copies applications already present under `/usr/local/tomcat/webapps` into the writable webapps volume only when that volume is empty.
This preserves image-baked WARs while still supporting PVC-backed mutable deployments.
