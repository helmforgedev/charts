# Apache Guacamole Helm Chart

Deploy [Apache Guacamole](https://guacamole.apache.org) on Kubernetes — a clientless remote desktop gateway supporting RDP, VNC, SSH, telnet, and Kubernetes.

## Features

- **guacd Sidecar** — protocol daemon runs as a sidecar container
- **PostgreSQL Subchart** — bundled via HelmForge dependency (default)
- **MySQL Subchart** — bundled via HelmForge dependency
- **External Database** — connect to existing PostgreSQL or MySQL
- **Database Init Job** — automatic schema initialization via post-install hook
- **OpenID Connect** — SSO with Keycloak, Okta, Azure AD, and others
- **SAML** — SSO with any SAML 2.0 identity provider
- **TOTP** — two-factor authentication
- **Reverse Proxy** — Tomcat RemoteIpValve for proper client IP detection
- **Ingress** — TLS with cert-manager
- **S3 Backup** — scheduled CronJob with pg_dump or mysqldump

## Installation

### HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install guacamole helmforge/guacamole -f values.yaml
```

### OCI Registry

```bash
helm install guacamole oci://ghcr.io/helmforgedev/helm/guacamole -f values.yaml
```

## Quick Start

```yaml
postgresql:
  auth:
    password: "change-me"
```

After deploying, access the web interface and log in with `guacadmin` / `guacadmin`. Change the default password immediately.

```bash
kubectl port-forward svc/<release>-guacamole 8080:80
```

## OIDC with Keycloak

```yaml
oidc:
  enabled: true
  authorizationEndpoint: https://keycloak.example.com/realms/master/protocol/openid-connect/auth
  jwksEndpoint: https://keycloak.example.com/realms/master/protocol/openid-connect/certs
  issuer: https://keycloak.example.com/realms/master
  clientId: guacamole

ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: guacamole.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - guacamole.example.com
      secretName: guacamole-tls
```

See [OIDC with Keycloak guide](docs/oidc-keycloak.md) for detailed setup instructions.

## Values

### Images

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `guacamole/guacamole` | Web app image |
| `image.tag` | `""` (appVersion) | Web app tag |
| `guacd.image.repository` | `guacamole/guacd` | guacd daemon image |
| `guacd.image.tag` | `""` (appVersion) | guacd daemon tag |
| `guacd.port` | `4822` | guacd port |
| `guacd.logLevel` | `info` | guacd log level |

### Guacamole

| Key | Default | Description |
|-----|---------|-------------|
| `guacamole.contextPath` | `ROOT` | Web context path (`ROOT` = `/`) |

### Database

| Key | Default | Description |
|-----|---------|-------------|
| `database.type` | `postgresql` | Database type (postgresql, mysql) |
| `database.external.host` | `""` | External database host |
| `database.external.name` | `guacamole_db` | Database name |
| `database.external.username` | `guacamole_user` | Database username |
| `postgresql.enabled` | `true` | Deploy PostgreSQL subchart |
| `mysql.enabled` | `false` | Deploy MySQL subchart |
| `initDb.enabled` | `true` | Run schema init Job on install |

### OIDC (OpenID Connect)

| Key | Default | Description |
|-----|---------|-------------|
| `oidc.enabled` | `false` | Enable OIDC authentication |
| `oidc.authorizationEndpoint` | `""` | Authorization endpoint URI |
| `oidc.jwksEndpoint` | `""` | JWKS endpoint URI |
| `oidc.issuer` | `""` | Token issuer |
| `oidc.clientId` | `""` | Client ID |
| `oidc.redirectUri` | `""` | Redirect URI (auto-detected from ingress) |
| `oidc.usernameClaim` | `preferred_username` | JWT username claim |
| `oidc.groupsClaim` | `groups` | JWT groups claim |

### SAML

| Key | Default | Description |
|-----|---------|-------------|
| `saml.enabled` | `false` | Enable SAML authentication |
| `saml.idpMetadataUrl` | `""` | IdP metadata URL |
| `saml.entityId` | `""` | SP entity ID (auto-detected from ingress) |
| `saml.callbackUrl` | `""` | Callback URL (auto-detected from ingress) |
| `saml.groupAttribute` | `groups` | Group attribute name |

### Service & Ingress

| Key | Default | Description |
|-----|---------|-------------|
| `service.type` | `ClusterIP` | Service type |
| `service.port` | `80` | Service port |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `traefik` | Ingress class |

### Backup

| Key | Default | Description |
|-----|---------|-------------|
| `backup.enabled` | `false` | Enable S3 backup CronJob |
| `backup.schedule` | `0 2 * * *` | Cron schedule |
| `backup.s3.endpoint` | `""` | S3 endpoint URL |
| `backup.s3.bucket` | `""` | S3 bucket |

## Architecture

Guacamole runs as a single Deployment with two containers:

- **guacamole** — Java/Tomcat web application on port 8080
- **guacd** — protocol daemon on port 4822 (sidecar, communicates via localhost)

A post-install Job initializes the database schema. The init job is idempotent and skips schema creation if tables already exist.

## Documentation

- [Database Configuration](docs/database.md)
- [OIDC with Keycloak](docs/oidc-keycloak.md)
- [Backup Guide](docs/backup.md)
- [Guacamole Official Docs](https://guacamole.apache.org/doc/gug/)

<!-- @AI-METADATA
type: chart-readme
title: Apache Guacamole Helm Chart
description: Guacamole remote desktop gateway with guacd sidecar, PostgreSQL/MySQL, OIDC/SAML SSO, and S3 backup
keywords: guacamole, remote-desktop, rdp, vnc, ssh, oidc, saml, keycloak, helm
purpose: Installation guide, values reference, and architecture overview
scope: Chart
relations:
  - charts/guacamole/values.yaml
  - charts/guacamole/docs/database.md
  - charts/guacamole/docs/oidc-keycloak.md
  - charts/guacamole/docs/backup.md
path: charts/guacamole/README.md
version: 1.0
date: 2026-03-23
-->
