# Security and TLS

## Overview

The chart uses X-Pack security to provide authentication and TLS encryption. Security is disabled in `dev` profile by default and auto-enabled in `production-ha`.

## Enable security

```yaml
security:
  enabled: true
```

When enabled:

- `xpack.security.enabled: true` is set in `elasticsearch.yml`
- TLS transport encryption is configured (`xpack.security.transport.ssl.*`)
- TLS HTTP encryption is configured (`xpack.security.http.ssl.*`)
- A random password is generated for the `elastic` built-in user

## Get the elastic user password

```bash
kubectl get secret <release>-elasticsearch-credentials \
  -n <namespace> \
  -o jsonpath='{.data.elastic-password}' | base64 -d
```

## cert-manager integration

The recommended way to manage TLS in production is to let cert-manager issue and rotate the certificate automatically.

### Self-signed (no external CA)

```yaml
security:
  enabled: true
  tls:
    certManager:
      enabled: true
      clusterIssuer: false   # create a self-signed Issuer in the same namespace
```

This creates:
- `Issuer` — self-signed, in the same namespace
- `Certificate` — multi-SAN covering all headless service DNS entries

### External ClusterIssuer (Let's Encrypt or internal CA)

```yaml
security:
  enabled: true
  tls:
    certManager:
      enabled: true
      clusterIssuer: true
      issuerName: letsencrypt-prod   # your ClusterIssuer name
```

Only a `Certificate` resource is created — no `Issuer`.

## Bring your own certificates

If you manage certificates externally (Vault, ACM, manual):

```yaml
security:
  enabled: true
  existingTlsSecret: my-elasticsearch-tls   # keys: ca.crt, tls.crt, tls.key
  tls:
    certManager:
      enabled: false
```

## Bring your own credentials

If you pre-generate passwords (e.g., via Vault or an external operator):

```yaml
security:
  existingCredentialsSecret: my-es-credentials   # keys: elastic-password, kibana-system-password
  generatePasswords: false
```

## Test with TLS enabled

```bash
kubectl port-forward svc/<release>-elasticsearch 9200 -n <namespace>

# No cert verification (self-signed)
curl -k -u elastic:<password> https://localhost:9200/_cluster/health?pretty

# With CA cert
curl --cacert /path/to/ca.crt \
  -u elastic:<password> \
  https://localhost:9200/_cluster/health?pretty
```

## Common risks

- using `security.enabled=false` in non-dev environments
- not rotating the `elastic` password after initial setup
- skipping cert-manager and using a self-signed certificate with a long expiry
- exposing port 9200 externally without network policies

## Internode transport TLS

Transport TLS (port 9300) is always configured when `security.enabled=true`. Nodes authenticate each other using the same certificate that covers all headless service names. This prevents rogue nodes from joining the cluster.

<!-- @AI-METADATA
type: chart-docs
title: Elasticsearch - Security and TLS
description: TLS, cert-manager, authentication and password management

keywords: elasticsearch, tls, cert-manager, security, xpack, authentication

purpose: Security guidance for the Elasticsearch Helm chart
scope: Chart Security

relations:
  - charts/elasticsearch/README.md
  - charts/elasticsearch/docs/profile-production-ha.md
path: charts/elasticsearch/docs/security.md
version: 1.0
date: 2026-04-09
-->
