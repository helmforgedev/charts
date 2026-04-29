# Security and Trust

## When to use this guide

Read this guide when:

- the external database uses TLS
- Keycloak must trust internal or self-signed certificate authorities
- secret rotation is managed outside Helm
- the environment has stricter outbound TLS requirements

## Trust model in this chart

The chart separates two concerns:

- `database.tls` for database-specific TLS material and JDBC URL wiring
- `truststore` for additional trusted certificates used by Keycloak in outbound TLS connections

This keeps database CA handling explicit without pretending every outbound TLS integration is the same as database connectivity.

## Database TLS

The current automatic TLS wiring is production-ready for PostgreSQL.

Example:

```yaml
database:
  external:
    vendor: postgres
    host: postgresql-rw.default.svc
    name: keycloak
    username: keycloak
    existingSecret: keycloak-db
  tls:
    enabled: true
    sslMode: verify-full
    existingConfigMap: keycloak-db-ca
    rootCertFilename: ca.crt
    mode: verify-server
    trustStoreFile: /opt/keycloak/conf/db-truststore.p12
    trustStorePasswordSecret: keycloak-db-truststore
    trustStoreType: PKCS12
```

What the chart does in this case:

- mounts the CA material under `database.tls.mountPath`
- appends PostgreSQL TLS parameters to the generated JDBC URL
- keeps database credentials in the existing database secret flow

If the environment uses MySQL or MariaDB, keep TLS expectations explicit and prefer additional JDBC parameters only after validating the exact driver behavior used in the target environment.

## Additional truststore material

Use `truststore` when Keycloak must trust internal or private certificate authorities for outbound TLS connections.

Example:

```yaml
truststore:
  enabled: true
  existingSecret: keycloak-extra-cas
  tlsHostnameVerifier: DEFAULT
```

This chart mounts the referenced files and exposes them through `KC_TRUSTSTORE_PATHS`.

Keycloak 26.6.x includes upstream improvements around automatic truststore initialization on Kubernetes and OpenShift. Keep chart-managed `truststore` values explicit when the deployment needs deterministic private CA material, database CA bundles, or provider/theme integration trust paths.

The upstream Kubernetes/OpenShift CA auto-discovery is controlled by:

```yaml
truststore:
  kubernetes:
    enabled: true
```

This renders `KC_TRUSTSTORE_KUBERNETES_ENABLED`. If `serviceAccount.automountServiceAccountToken=false`, Kubernetes service account CA files are not mounted, so Keycloak cannot discover them even if the truststore option remains enabled.

Disable service account token automount only after confirming the deployment does not need the implicit Kubernetes CA files, Kubernetes service account identity provider behavior, external Infinispan integrations, or custom provider code that talks to the Kubernetes API.

Accepted formats follow the official Keycloak guidance:

- PEM certificates
- unencrypted PKCS12 files

## Hostname verification

The chart exposes `truststore.tlsHostnameVerifier`, which maps to Keycloak hostname verification for outbound TLS connections.

Recommended production behavior:

- keep `DEFAULT`
- do not use `ANY` in production

## Secret rotation guidance

Generated admin and database secrets are part of the Helm release and trigger a rollout through the deployment checksum when they change during an upgrade.

Externally managed secrets or ConfigMaps do not trigger an automatic rollout just because their content changed. When those inputs rotate, plan an explicit rollout or restart of the Keycloak deployment.

Examples:

- external secret controller rotates the database password
- the database CA bundle is replaced
- internal CA certificates are updated in the truststore

## External Secrets Operator

The chart can render `ExternalSecret` resources for clusters that already run External Secrets Operator. This is optional and does not install the operator or create a `SecretStore`.

```yaml
externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  admin:
    enabled: true
    usernameRemoteRef:
      key: keycloak/admin
      property: username
    passwordRemoteRef:
      key: keycloak/admin
      property: password
  database:
    enabled: true
    passwordRemoteRef:
      key: keycloak/database
      property: password
```

Use this only when the platform team already operates https://github.com/external-secrets/external-secrets and the referenced store exists before the Helm release is installed.

## Rollout checklist for trust changes

- confirm the new certificate chain is present in the referenced Secret or ConfigMap
- confirm the mounted filenames match the configured values
- trigger a controlled rollout after secret or truststore rotation
- validate database connectivity after rollout
- validate admin login and public login flows after rollout

## Official product references

- Keycloak trusted certificates: https://www.keycloak.org/server/keycloak-truststore
- Keycloak production configuration: https://www.keycloak.org/server/configuration-production
- Keycloak release notes: https://www.keycloak.org/docs/latest/release_notes/index.html
- External Secrets Operator: https://external-secrets.io/latest/

<!-- @AI-METADATA
type: chart-docs
title: Keycloak - Security
description: TLS, truststore, database security

keywords: keycloak, security, tls, truststore

purpose: TLS, truststore, and database security configuration for Keycloak
scope: Chart Architecture

relations:
  - charts/keycloak/README.md
  - charts/keycloak/docs/reverse-proxy.md
path: charts/keycloak/docs/security-and-trust.md
version: 1.0
date: 2026-03-20
-->
