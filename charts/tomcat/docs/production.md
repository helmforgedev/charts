# Production Guidance

Use a pinned application artifact, explicit resources, NetworkPolicy, and either Ingress or Gateway API.

```yaml
replicaCount: 2

webapps:
  defaultRoot:
    enabled: false

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
