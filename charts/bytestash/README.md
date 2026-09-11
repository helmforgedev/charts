# ByteStash

Private code snippets using the official `ghcr.io/jordan-dalby/bytestash:1.5.12` image. Linux amd64, arm64 and arm image
manifests were verified. The chart preserves SQLite's single-writer contract and closes the upstream first-registration
window with an administrative init container.

## Features

- Transactional initial administrator creation before HTTP starts; existing passwords are never reset on restart.
- Separate retained JWT and bootstrap Secrets, native JWT file loading, existing Secrets and canonical ESO items.
- Durable 5Gi SQLite claim, Recreate upgrades and optional verified online snapshots with retention and fresh-PVC
  recovery.
- Native OIDC with confidential client credentials and optional additional CA trust; provider admission requirements are
  documented against the actual upstream behavior.
- Native authenticated MCP endpoint with API-key revocation validation.
- Non-root UID/GID 1000, read-only image filesystem, dropped capabilities, RuntimeDefault seccomp and no Kubernetes API
  token; bounded resources and database-aware readiness.
- Explicit NetworkPolicy, Ingress class, Gateway API, Service dual stack and native URL subpath support.

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install bytestash helmforge/bytestash --namespace snippets --create-namespace
kubectl -n snippets port-forward service/bytestash-bytestash 5000:5000
```

Open `http://localhost:5000`. Retrieve the initial administrator credential from the Secret named in Helm NOTES. For
production, use a dedicated HTTPS hostname and existing Secrets managed by your credential system. The default
administrator is `admin`; local registration is closed. Use the native application password flow for later password
rotation. Changing the bootstrap Secret never resets an existing account.

## Production values

```yaml
auth:
  existingSecret: snippets-jwt
bootstrap:
  username: snippetsadmin
  existingSecret: snippets-admin
persistence:
  size: 10Gi
backup:
  enabled: true
  size: 80Gi
  retention: 7
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: snippets.example.test
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: snippets-tls
      hosts: [snippets.example.test]
networkPolicy:
  ingressFrom:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
```

Create `snippets-jwt` with a strong `jwt-secret` key and `snippets-admin` with a `password` key before installation. The
main server only receives the JWT credential; the bootstrap password is mounted exclusively in its init container. Never
run two releases against the same writable database claim. Resource defaults are 100m/128Mi requests and 1 CPU/512Mi
limits; size them for your users and snippet volume.

## Configuration contract

| Values                             | Behavior                                                                               |
| ---------------------------------- | -------------------------------------------------------------------------------------- |
| `auth`                             | Retained JWT key, local account enrollment, token lifetime and administrator usernames |
| `bootstrap`                        | Initial local administrator through native database and password APIs                  |
| `oidc`                             | Native HTTPS issuer, client Secret, requested scopes and additional trusted CA         |
| `server.basePath`                  | Safe URL prefix such as `/snippets`, without a trailing slash                          |
| `persistence`                      | Complete SQLite data directory, existing claim, storage class and retention            |
| `backup`                           | Verified online snapshots, UTC schedule, retention and separate destination PVC        |
| `service`, `ingress`, `gatewayAPI` | Native port 5000 behind configurable Service routing                                   |
| `externalSecrets.items`            | External Secrets Operator v1 resources targeting existing Secret references            |
| `networkPolicy`                    | Same-namespace ingress and DNS by default, explicit additional egress                  |
| `probes`, `resources`              | Authentication-config readiness, HTTP liveness and bounded resources                   |
| `extraEnv`, `envFrom`              | Additional upstream settings; chart-managed security variables are protected           |
| `extraContainers`, `extraVolumes`  | Explicit companion workloads and storage with reserved-name guards                     |

See [values.yaml](values.yaml), [values.schema.json](values.schema.json), [design](DESIGN.md) and
[operations](docs/operations.md) for the full contract and recovery procedure.

## Authentication and networking limits

OIDC enrollment must be restricted at the provider. Closing local registration does not close OIDC enrollment in the
pinned upstream. Its browser token storage is not an HttpOnly-cookie session. The chart documents these limitations and
keeps local administrator recovery available. The OIDC runtime fixture verifies S256 PKCE and trusted issuer TLS.

The upstream process always trusts proxy headers. Configure the edge to overwrite forwarded headers, constrain accepted
hostnames and limit pod ingress to that edge. The advertised upstream `ALLOWED_HOSTS` setting is not implemented in the
tagged server, so the chart does not offer it as a security control. Enabling OIDC requires explicit HTTPS egress.

There is no external SQL backend, native Prometheus endpoint, ServiceMonitor, HPA or PDB. Use Kubernetes
workload/PVC/Job and ingress monitoring. The native MCP endpoint is `/mcp` under the chosen subpath and requires an
application API key.

## Backup and upgrade

Backups use SQLite's online backup API, integrity verification and atomic publication on a separate PVC. A storage-check
Job ensures the destination binds during Helm installation with delayed provisioning. The backup CronJob uses Forbid
concurrency and colocates with the writer for RWO access. ReadWriteOncePod is rejected when online backup is enabled.

A same-cluster PVC is not an off-cluster disaster-recovery copy. Budget destination space for retained full snapshots
plus one temporary copy and export backups through your infrastructure backup system. Restore to a fresh claim and set
`persistence.existingClaim`; preserve the JWT Secret if sessions must survive. Helm rollback does not reverse database
migrations. The [operations guide](docs/operations.md) includes the exact recovery sequence.

## Validation

The chart includes Helm feature and rejection tests plus real Kubernetes application validation: protected bootstrap,
anonymous denial, local registration policy, Unicode snippet creation, persistence after pod replacement, retained JWT
sessions, native MCP key use and revocation, OIDC signature/state/TLS checks and online snapshot recovery. CI profiles
cover default, ephemeral, subpath, existing credentials, ESO, OIDC, backup, dual stack, Ingress and Gateway API.

## Security Scan

### Security Scan: `bytestash`

| Framework          | Score         |
| ------------------ | ------------- |
| MITRE + NSA + SOC2 | **98.48485%** |

> Security posture acceptable.

Measured using Kubescape 4.0.13 against default manifests. This assesses Kubernetes deployment configuration, not the
absence of upstream application vulnerabilities.

Control C-0012 flags the non-secret environment settings `TOKEN_EXPIRY=24h` and `ALLOW_PASSWORD_CHANGES=true` by name.
These contain a duration and a boolean, not credentials. JWT and initial password material are mounted from Secrets. The
unmodified scanner result is reported above; no control was suppressed.

<!-- @AI-METADATA
type: chart
title: ByteStash
description: Production code snippets with protected bootstrap, retained authentication and verified SQLite recovery.
keywords: bytestash, snippets, sqlite, oidc, mcp, backup
purpose: Describe the production chart values and operational boundaries.
scope: charts/bytestash
relations: [DESIGN.md, docs/operations.md]
path: charts/bytestash/README.md
version: 1.0
-->

## Gateway API contract

Use `gatewayAPI.enabled` and `gatewayAPI.httpRoutes[]`. Set each route's `parentRefs` to a shared Gateway that allows
this namespace, and configure its HTTPS listener and public hostname. Routes accept labels, annotations and rules
with matches, filters and optional backend references; omitted backends target this chart's application Service.
Ingress and HTTPRoute resources can coexist. Verify controller conditions and public traffic before production use.
See the [Gateway API documentation](https://gateway-api.sigs.k8s.io/).
