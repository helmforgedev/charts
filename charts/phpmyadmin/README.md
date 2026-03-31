# phpMyAdmin

A Helm chart for deploying [phpMyAdmin](https://www.phpmyadmin.net/) on Kubernetes using the official [`phpmyadmin/phpmyadmin`](https://hub.docker.com/r/phpmyadmin/phpmyadmin) Docker image.

## Installation

### HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install phpmyadmin helmforge/phpmyadmin
```

### OCI Registry

```bash
helm install phpmyadmin oci://ghcr.io/helmforgedev/helm/phpmyadmin
```

## Quick Start

```bash
helm install phpmyadmin oci://ghcr.io/helmforgedev/helm/phpmyadmin \
  --set phpmyadmin.host=mysql.default.svc.cluster.local
```

## Features

- **Official phpMyAdmin Image** — based on the official `phpmyadmin/phpmyadmin` container
- **Single or Multi-Server** — connect to one MySQL host or multiple servers
- **Auto-Login** — optional automatic authentication via PMA_USER/PMA_PASSWORD
- **Custom Configuration** — mount custom `config.user.inc.php` via ConfigMap
- **Upload Limit** — configurable max upload size for SQL imports
- **Ingress Support** — configurable ingress with TLS for HTTPS access
- **Stateless** — no persistent storage needed, scales horizontally

## Configuration

### Connect to a MySQL Server

```yaml
phpmyadmin:
  host: mysql.default.svc.cluster.local
  port: 3306
```

### Multi-Server Mode

```yaml
phpmyadmin:
  hosts: "mysql-primary.svc,mysql-replica.svc,mysql-analytics.svc"
```

### Production with Ingress

```yaml
phpmyadmin:
  host: mysql.default.svc.cluster.local
  absoluteUri: "https://pma.example.com/"
  uploadLimit: "128M"

ingress:
  enabled: true
  ingressClassName: traefik
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: pma.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: phpmyadmin-tls
      hosts:
        - pma.example.com
```

### Auto-Login with Existing Secret

```yaml
phpmyadmin:
  host: mysql.default.svc.cluster.local

auth:
  existingSecret: mysql-credentials
  existingSecretUsernameKey: username
  existingSecretPasswordKey: password
```

### Custom PHP Configuration

```yaml
phpmyadmin:
  host: mysql.default.svc.cluster.local

config:
  customConfig: |
    <?php
    $cfg['ShowPhpInfo'] = true;
    $cfg['MaxRows'] = 100;
    $cfg['DefaultLang'] = 'en';
```

## Parameters

### phpMyAdmin

| Key | Default | Description |
|-----|---------|-------------|
| `phpmyadmin.host` | `""` | MySQL/MariaDB host to connect to |
| `phpmyadmin.hosts` | `""` | Comma-separated list of MySQL hosts (multi-server mode) |
| `phpmyadmin.port` | `3306` | MySQL port |
| `phpmyadmin.uploadLimit` | `"64M"` | Max upload size for SQL imports |
| `phpmyadmin.absoluteUri` | `""` | Absolute URI when behind a reverse proxy |

### Authentication

| Key | Default | Description |
|-----|---------|-------------|
| `auth.username` | `""` | MySQL username for auto-login (leave empty for login form) |
| `auth.password` | `""` | MySQL password for auto-login |
| `auth.existingSecret` | `""` | Existing secret with auto-login credentials |

### Custom Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `config.customConfig` | `""` | Raw content for config.user.inc.php |
| `config.existingConfigMap` | `""` | Existing ConfigMap with config.user.inc.php |

### Service

| Key | Default | Description |
|-----|---------|-------------|
| `service.type` | `ClusterIP` | Service type |
| `service.port` | `80` | Service port |

### Ingress

| Key | Default | Description |
|-----|---------|-------------|
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `""` | Ingress class (`traefik`, `nginx`, etc.) |
| `ingress.hosts` | `[]` | Ingress hosts and paths |
| `ingress.tls` | `[]` | TLS configuration |

### Deployment

| Key | Default | Description |
|-----|---------|-------------|
| `replicaCount` | `1` | Number of replicas |
| `image.repository` | `phpmyadmin/phpmyadmin` | Container image |
| `image.tag` | `""` | Image tag (defaults to appVersion) |
| `resources` | `{}` | Resource requests and limits |

## Notes

- phpMyAdmin is **stateless** — no persistent volume is required
- set `phpmyadmin.host` or `phpmyadmin.hosts` to point at your MySQL/MariaDB server
- use `phpmyadmin.hosts` for the server selector dropdown in the login page
- when using `phpmyadmin.absoluteUri`, ensure the value matches the external URL including the trailing slash
- auto-login (`auth.username` + `auth.password`) skips the login form — use only in trusted networks
- for large database imports, increase `phpmyadmin.uploadLimit` (e.g., `"256M"`)

## More Information

- [Source code and full values reference](https://github.com/helmforgedev/charts/tree/main/charts/phpmyadmin)

<!-- @AI-METADATA
type: chart-readme
title: phpMyAdmin
description: Installation guide, values reference, and operational overview for the phpMyAdmin Helm chart

keywords: phpmyadmin, mysql, mariadb, database, admin, web-ui, helm, kubernetes

purpose: User-facing chart documentation with install, examples, and values reference
scope: Chart

relations: []
path: charts/phpmyadmin/README.md
version: 1.0
date: 2026-03-31
-->
