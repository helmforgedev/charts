# Apache

Apache HTTP Server is a widely used open source web server.

This HelmForge chart deploys the official `httpd` image with a non-root, read-only root filesystem runtime on port 8080.
It supports custom static content, generated hardening config, extra virtual hosts, optional Basic Auth through an existing Secret,
Gateway API, Ingress, dual-stack Service fields, NetworkPolicy, ExternalSecret, optional Apache exporter metrics, ServiceMonitor,
PodDisruptionBudget, HPA, and Helm tests.

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install apache helmforge/apache
```

## Custom Content

```yaml
content:
  files:
    index.html: |
      <h1>Hello from Apache</h1>
```

Use `content.existingConfigMap` when content is managed outside the chart.

## Extra Apache Config

```yaml
httpd:
  extraConfig: |
    Header always set X-Content-Type-Options "nosniff"
```

## Metrics

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
serverStatus:
  require: "all granted"
```

Metrics use the Apache exporter sidecar and `mod_status` endpoint.
