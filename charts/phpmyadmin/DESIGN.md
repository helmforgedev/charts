<!-- SPDX-License-Identifier: Apache-2.0 -->

# phpMyAdmin Chart Design

This document describes the architecture and operational model for the HelmForge phpMyAdmin chart.

## Goals

- Keep the default deployment simple for development and troubleshooting.
- Provide opt-in production controls without forcing every install to be production-shaped.
- Expose official phpMyAdmin Docker image capabilities through structured values.
- Support current Kubernetes patterns: Gateway API, External Secrets Operator v1, NetworkPolicy, HPA,
  PDB, Service dual-stack, and ServiceAccount token control.

## Non-Goals

- The chart does not install MySQL, MariaDB, External Secrets Operator, Gateway API CRDs, or a Gateway controller.
- The chart does not make phpMyAdmin safe to expose publicly by itself.
- The chart does not manage database users or privileges.

## Default Development Architecture

```text
Developer
   |
   | kubectl port-forward
   v
Service ClusterIP
   |
   v
phpMyAdmin Deployment
   |
   | PMA_HOST or login-entered host
   v
MySQL/MariaDB
```

Default characteristics:

- one replica;
- no Ingress or Gateway;
- no NetworkPolicy;
- no ExternalSecret;
- ServiceAccount token not mounted;
- access through port-forward.

## Internal Production Architecture With Ingress

```text
User/VPN/SSO
   |
   v
Ingress Controller + TLS
   |
   v
Service
   |
   v
phpMyAdmin replicas
   |
   | restricted egress
   v
MySQL/MariaDB

External Secrets Operator
   |
   v
Kubernetes Secret -> phpMyAdmin env
```

Recommended controls:

- TLS at the Ingress layer.
- SSO, VPN, or reverse proxy authentication before phpMyAdmin.
- Existing Secret or ExternalSecret for credentials.
- NetworkPolicy with only required ingress and database egress.
- Least-privilege database accounts.
- PDB and optional HPA.
- Shared `/sessions` storage or sticky sessions when using multiple replicas.

## Gateway API Architecture

```text
Client
   |
   v
Gateway listener
   |
   v
HTTPRoute
   |
   v
phpMyAdmin Service
   |
   v
phpMyAdmin Pod
```

The chart renders only `HTTPRoute`. Platform teams remain responsible for GatewayClass, Gateway
listeners, TLS certificates, cross-namespace route attachment policy, and controller operations.

## External Secrets Architecture

```text
External secret backend
   |
   v
SecretStore or ClusterSecretStore
   |
   v
ExternalSecret external-secrets.io/v1
   |
   v
Kubernetes Secret
   |
   v
phpMyAdmin environment variables
   |
   v
Generated config.user.inc.php when needed
```

The chart supports External Secrets for:

- auto-login username;
- auto-login password;
- cookie blowfish secret;
- configuration-storage control password.

Inline values are acceptable for local development only. Production should use `auth.existingSecret` or `externalSecrets.auth`.
The phpMyAdmin Docker image does not consume every phpMyAdmin setting as an environment variable. For auth modes other than `cookie` and for
a stable cookie blowfish secret, the chart writes a generated `config.user.inc.php` and reads secret material from a pod environment variable
populated by Kubernetes Secret references.

## Multi-Server Architecture

```text
phpMyAdmin
   |
   +-- PMA_HOSTS[0] -> MySQL primary
   +-- PMA_HOSTS[1] -> MySQL replica
   +-- PMA_HOSTS[2] -> MariaDB analytics
```

Use `phpmyadmin.hosts`, `phpmyadmin.ports`, and `phpmyadmin.verboses` to provide a curated server list.
Use `phpmyadmin.arbitrary=true` only when the user population is trusted to choose valid database
endpoints.
When database TLS is enabled with `phpmyadmin.hosts`, the chart renders the multi-host variables
`PMA_SSLS`, `PMA_SSL_VERIFIES`, `PMA_SSL_CAS`, `PMA_SSL_CERTS`, and `PMA_SSL_KEYS` so TLS settings line up with the `PMA_HOSTS` order.

## Session Strategy

phpMyAdmin is mostly stateless, but web sessions can matter for multi-replica deployments.

```text
Replica A ----+
              +--> /sessions shared volume
Replica B ----+
```

Recommended choices:

- single replica for simple admin use;
- multiple replicas with shared `/sessions` storage when session continuity is required;
- ingress stickiness as an alternative when storage is not available.

## Service Dual Stack

The chart leaves `service.ipFamilyPolicy` and `service.ipFamilies` empty by default so the cluster default applies. On IPv4/IPv6 clusters, use:

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

Use `RequireDualStack` only when the cluster is known to support dual-stack Services.

## Security Model

phpMyAdmin is a powerful database administration UI. The chart provides controls, but production safety depends on the platform configuration.

Production baseline:

- do not expose directly to the public internet;
- require TLS;
- put phpMyAdmin behind VPN, SSO, reverse proxy auth, or IP allowlists;
- use least-privilege database users;
- avoid auto-login unless the surrounding access controls are strong;
- mount ServiceAccount tokens only when needed;
- restrict ingress and egress with NetworkPolicy;
- prefer External Secrets or existing Kubernetes Secrets.

## Validation Matrix

Each change should be validated with:

- `helm lint`;
- `helm unittest`;
- `helm template` for default and example values;
- local HelmForge validations for ExternalSecrets, Gateway API, values quality, and CI evidence;
- K3D install for default, production, ExternalSecret, Gateway API, NetworkPolicy, and dual-stack scenarios where the local cluster supports them.
