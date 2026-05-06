<!-- SPDX-License-Identifier: Apache-2.0 -->

# phpMyAdmin

A Helm chart for deploying [phpMyAdmin](https://www.phpmyadmin.net/) on Kubernetes with the official `phpmyadmin/phpmyadmin` image.

phpMyAdmin is a web UI for administering MySQL and MariaDB. This chart supports development installs,
internal administration portals, and hardened production-style deployments with External Secrets,
Gateway API, NetworkPolicy, dual-stack Services, optional shared sessions, and Kubernetes-native
availability controls.

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install phpmyadmin helmforge/phpmyadmin
```

OCI:

```bash
helm install phpmyadmin oci://ghcr.io/helmforgedev/helm/phpmyadmin
```

## Quick Start

```bash
helm install phpmyadmin oci://ghcr.io/helmforgedev/helm/phpmyadmin \
  --set phpmyadmin.host=mysql.default.svc.cluster.local
```

Local access:

```bash
kubectl port-forward svc/phpmyadmin 8080:80
```

Open `http://localhost:8080/`.

## Feature Summary

- Official `phpmyadmin/phpmyadmin` container image.
- Single-server, multi-server, and arbitrary-server login modes.
- Cookie, config, HTTP, and signon auth mode selection.
- Optional auto-login with inline Secret, existing Secret, or External Secrets Operator.
- External Secrets Operator support with `external-secrets.io/v1`.
- Ingress and Kubernetes Gateway API `HTTPRoute`.
- Service dual-stack options through `ipFamilyPolicy` and `ipFamilies`.
- Optional NetworkPolicy for ingress and database egress.
- Optional ServiceAccount token automount control.
- Optional HPA and PodDisruptionBudget.
- Optional `/sessions` mount for multi-replica session stability.
- Optional custom phpMyAdmin config through ConfigMap or `PMA_CONFIG_BASE64`.
- Optional configuration storage/control user variables.
- Optional custom themes mounted at `/www/themes`.

## Development vs Production

The default values are intentionally simple for development: one replica, no Ingress/Gateway, no NetworkPolicy, no ExternalSecret, and access through port-forward. This keeps a local install easy.

Production deployments should opt into the controls they need:

- Use `auth.existingSecret` or `externalSecrets.auth` instead of inline passwords.
- Prefer `phpmyadmin.authType: cookie` unless a controlled `config`, `http`, or `signon` workflow is required.
- Expose phpMyAdmin through private networking, VPN, SSO/reverse proxy auth, or IP allowlists.
- Enable TLS at the Ingress or Gateway layer.
- Enable NetworkPolicy and restrict egress to DNS and the target database.
- Use least-privilege database accounts.
- Enable `sessions.enabled` for multi-replica deployments that rely on cookie/session state.
- Add requests, limits, PDB, HPA, topology spread, and anti-affinity where appropriate.

## Database Connectivity

Single MySQL/MariaDB server:

```yaml
phpmyadmin:
  host: mysql.default.svc.cluster.local
  port: 3306
```

Multi-server dropdown:

```yaml
phpmyadmin:
  hosts: "mysql-primary.default.svc,mysql-replica.default.svc,mariadb.default.svc"
  ports: "3306,3306,3306"
  verboses: "Primary,Replica,MariaDB"
```

Arbitrary server mode:

```yaml
phpmyadmin:
  arbitrary: true
```

## Authentication

Default cookie login:

```yaml
phpmyadmin:
  authType: cookie
auth:
  blowfishSecret: "use-a-32-byte-random-secret-here"
```

Non-cookie auth modes are rendered into `config.user.inc.php` because the official phpMyAdmin image does not consume an auth-type environment variable:

```yaml
phpmyadmin:
  authType: http
```

When `authType: http` is used, the chart automatically switches the default probes to TCP checks because the application root returns `401`
until HTTP authentication succeeds.

Auto-login with an existing Secret:

```yaml
auth:
  existingSecret: phpmyadmin-auth
  existingSecretUsernameKey: username
  existingSecretPasswordKey: password
  existingSecretBlowfishKey: blowfish-secret
```

The Secret should contain:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: phpmyadmin-auth
type: Opaque
stringData:
  username: admin
  password: change-me
  blowfish-secret: use-a-32-byte-random-secret-here
```

Auto-login skips the login form and should only be used behind strong network and identity controls.
When a blowfish secret is provided inline, by existing Secret, or by External Secrets Operator, the chart exposes it to the pod as
`HELMFORGE_BLOWFISH_SECRET` and writes `$cfg['blowfish_secret']` through `config.user.inc.php`.

## External Secrets Operator

The chart can render an `ExternalSecret` using `external-secrets.io/v1`. The External Secrets Operator
and the referenced SecretStore or ClusterSecretStore must already exist.

```yaml
externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  auth:
    enabled: true
    usernameRemoteRef:
      key: prod/phpmyadmin
      property: username
    passwordRemoteRef:
      key: prod/phpmyadmin
      property: password
    blowfishSecretRemoteRef:
      key: prod/phpmyadmin
      property: blowfish-secret
```

## Ingress

```yaml
phpmyadmin:
  host: mysql.default.svc.cluster.local
  absoluteUri: "https://pma.example.com/"

ingress:
  enabled: true
  ingressClassName: nginx
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

## Gateway API

Gateway API support is opt-in and creates an `HTTPRoute` attached to an existing Gateway.

```yaml
gatewayAPI:
  enabled: true
  parentRefs:
    - name: public
      namespace: gateway-system
      sectionName: https
  hostnames:
    - pma.example.com
```

## Service Dual Stack

Dual-stack is disabled by default and inherits the cluster default. Enable it only on clusters configured
for IPv4/IPv6 Services.

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

## NetworkPolicy

```yaml
networkPolicy:
  enabled: true
  ingress:
    allowSameNamespace: true
  egress:
    enabled: true
    allowDNS: true
    allowSameNamespaceDatabase: true
    databasePort: 3306
```

Use `extraFrom` and `extraTo` to restrict traffic to Gateway/Ingress controller namespaces and database CIDRs or pod selectors.

## Sessions And Replicas

phpMyAdmin is mostly stateless, but cookie/session flows benefit from a shared `/sessions` mount when running multiple replicas.

```yaml
replicaCount: 2
sessions:
  enabled: true
  type: persistentVolumeClaim
  accessModes:
    - ReadWriteMany
  size: 1Gi
```

For clusters without shared storage, keep `replicaCount: 1` or use ingress stickiness.

## Custom Configuration

Mount `config.user.inc.php`:

```yaml
config:
  customConfig: |
    <?php
    $cfg['ShowPhpInfo'] = false;
    $cfg['MaxRows'] = 100;
```

The chart also generates `config.user.inc.php` when it needs to apply `phpmyadmin.authType` values other than `cookie` or a configured
blowfish secret. If `config.customConfig` is set, the custom block is appended after the generated block so advanced users can still override
phpMyAdmin settings deliberately.

Or pass base64 configuration through the official image variable:

```yaml
phpmyadmin:
  configBase64: "PD9waHAKJGNmZ1snU2hvd1BocEluZm8nXSA9IGZhbHNlOwo="
```

## Production Example

See [examples/production.yaml](examples/production.yaml).

## Main Parameters

| Key | Default | Description |
| --- | --- | --- |
| `phpmyadmin.host` | `""` | Single MySQL/MariaDB host |
| `phpmyadmin.hosts` | `""` | Comma-separated multi-server hosts |
| `phpmyadmin.ports` | `""` | Comma-separated multi-server ports |
| `phpmyadmin.verboses` | `""` | Comma-separated server display names |
| `phpmyadmin.arbitrary` | `false` | Let users enter a host at login |
| `phpmyadmin.authType` | `cookie` | phpMyAdmin auth mode |
| `phpmyadmin.uploadLimit` | `64M` | SQL import upload limit |
| `phpmyadmin.absoluteUri` | `""` | External URL when behind a proxy |
| `auth.existingSecret` | `""` | Existing auth Secret |
| `externalSecrets.enabled` | `false` | Render ExternalSecret resources |
| `gatewayAPI.enabled` | `false` | Render HTTPRoute |
| `service.ipFamilyPolicy` | `""` | Service IP family policy |
| `service.ipFamilies` | `[]` | Service IP families |
| `networkPolicy.enabled` | `false` | Render NetworkPolicy |
| `sessions.enabled` | `false` | Mount `/sessions` |
| `autoscaling.enabled` | `false` | Render HPA |
| `pdb.enabled` | `false` | Render PDB |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount SA token into pods |

## Validation

Recommended checks before promotion:

```bash
helm lint charts/phpmyadmin
helm unittest charts/phpmyadmin
helm template phpmyadmin charts/phpmyadmin -f charts/phpmyadmin/examples/production.yaml
```

For cluster validation, install into K3D/K3S with a test MySQL/MariaDB target and check pods, logs,
events, Service endpoints, Ingress or Gateway route, and ExternalSecret reconciliation when ESO is
enabled.

## References

- [phpMyAdmin](https://www.phpmyadmin.net)
- [Official Docker image](https://hub.docker.com/_/phpmyadmin)
- [phpMyAdmin Docker setup](https://docs.phpmyadmin.net/en/latest/setup.html#installing-using-docker)
- [External Secrets Operator](https://external-secrets.io/latest/api/externalsecret/)
- [Kubernetes Gateway API HTTPRoute](https://gateway-api.sigs.k8s.io/api-types/httproute/)

<!-- @AI-METADATA
type: chart-readme
title: phpMyAdmin
description: Installation guide, values reference, and operational overview for the phpMyAdmin Helm chart
keywords: phpmyadmin, mysql, mariadb, database, admin, web-ui, helm, kubernetes, gateway-api, external-secrets, dual-stack
purpose: User-facing chart documentation with install, examples, security posture, and values reference
scope: Chart
relations: []
path: charts/phpmyadmin/README.md
version: 2.0
date: 2026-05-06
-->
