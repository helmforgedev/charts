# Security

## Workload identity

Grafana runs as UID/GID 472 without root, privilege escalation, Linux
capabilities, or a Kubernetes API token. RuntimeDefault seccomp is enabled and
the image filesystem is read-only. Writable mounts are restricted to data,
logs, and temporary files.

No Kubernetes RBAC is created. This is intentional: declarative ConfigMaps
replace dashboard sidecars that would otherwise watch the Kubernetes API.

## Administrator credentials

For production, reference a Secret created by a secret manager or External
Secrets Operator.

```yaml
admin:
  existingSecret: grafana-admin
  userKey: admin-user
  passwordKey: admin-password
```

The administrator environment variables initialize a new Grafana database.
Changing the Secret later does not necessarily rotate an existing database
user. Use Grafana's administration flow for credential rotation, then keep the
Secret synchronized with the active credential.

## External Secrets Operator

```yaml
admin:
  existingSecret: grafana-admin
externalSecrets:
  enabled: true
  refreshInterval: 1h
  items:
    - name: admin
      fullnameOverride: grafana-admin
      spec:
        secretStoreRef:
          name: production
          kind: ClusterSecretStore
        target:
          name: grafana-admin
          creationPolicy: Owner
        data:
          - secretKey: admin-user
            remoteRef:
              key: grafana/admin
              property: username
          - secretKey: admin-password
            remoteRef:
              key: grafana/admin
              property: password
```

The ExternalSecret and `admin.existingSecret` must converge on the same Secret
name. Use separate items for administrator and database credentials when they
have different ownership or refresh policies.

## Database transport

Use TLS for external PostgreSQL/MySQL. `database.sslMode` is passed directly to
Grafana and therefore follows Grafana's database driver semantics. Prefer
certificate and hostname verification. If a private CA is required, mount it
with `extraVolumes` and `extraVolumeMounts`, then reference it through supported
Grafana database configuration in `grafana.ini`.

Do not store database passwords inline in a production values file. Use
`database.existingSecret`.

## NetworkPolicy

The default policy admits the HTTP port from same-namespace pods. Add ingress
controller and Prometheus namespaces explicitly when they run elsewhere.

```yaml
networkPolicy:
  ingress:
    allowSameNamespace: false
    extraFrom:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: ingress-nginx
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: monitoring
```

Egress isolation is disabled by default because datasources and integrations
are deployment-specific. Enabling it without complete rules can break logins,
alerts, dashboards, plugins, email, webhooks, or database connectivity.

## Plugins

Install only trusted plugins with exact versions. Grafana blocks unsigned
plugins by default; keep that behavior. Treat plugins as code running inside
Grafana's trust boundary and review their permissions and update history.

## Anonymous access and authentication

Anonymous access, OAuth, OIDC, LDAP, and auth proxy settings can be expressed in
`grafana.ini`. Keep authentication secrets in environment-backed Secret
references rather than values.

```yaml
grafana:
  ini:
    auth.anonymous:
      enabled: false
    users:
      allow_sign_up: false
```

## Exposure

Use TLS at the Ingress or Gateway. Set `grafana.rootUrl` exactly, restrict the
edge to approved networks or identity-aware proxies where appropriate, and
avoid exposing the initial administrator credential retrieval workflow.

## Audit checklist

- administrator and database credentials are externally owned;
- TLS is enforced at the browser edge and external database;
- root URL and OAuth callback URLs are exact;
- unsigned plugins remain disabled;
- NetworkPolicy peers match actual controllers and monitoring namespaces;
- egress rules include every required integration before isolation is enabled;
- backups are encrypted, access-controlled, and restore-tested;
- Grafana, plugins, and base image are updated under a tested process.

<!-- @AI-METADATA
type: chart-docs
title: Grafana Security
description: Identity, credentials, network, plugin, and transport security
keywords: grafana, security, external-secrets, networkpolicy, tls
purpose: Secure a HelmForge Grafana deployment
scope: Chart
relations:
  - charts/grafana/README.md
  - charts/grafana/values.yaml
path: charts/grafana/docs/security.md
version: 1.0
date: 2026-11-25
-->
