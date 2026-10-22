# Transmute

Production-ready Helm chart for [Transmute](https://transmute.sh/), a self-hosted
file conversion platform. The chart deploys the official pinned image with durable
SQLite storage, a stable JWT signing key, optional OIDC, Ingress, Gateway API,
External Secrets Operator integration and hardened Kubernetes defaults.

## Installation

From the Helm repository:

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install transmute helmforge/transmute --namespace transmute --create-namespace
```

From OCI:

```bash
helm install transmute oci://ghcr.io/helmforgedev/helm/transmute \
  --namespace transmute --create-namespace
```

The first account created through the Transmute UI becomes the administrator.
Transmute has no supported environment variables for pre-creating that account.
Keep a fresh installation private until the first administrator is registered.

## Architecture and invariants

Transmute stores users, jobs, uploads and outputs under `/app/data` and uses a
local SQLite database. The chart therefore enforces these safety invariants:

- exactly one replica;
- a persistent volume is mandatory;
- `config.dataDir` must equal `persistence.mountPath`, keeping all state on the PVC;
- Deployment updates use `Recreate` so old and new pods never write together;
- `AUTH_SECRET_KEY` is generated once and preserved across Helm upgrades, or read
  from an existing Secret;
- `/tmp` is writable through an `emptyDir` while the container root filesystem
  remains read-only.

See [DESIGN.md](DESIGN.md) for the design boundaries.

## OIDC

Register this callback URI with the provider:

```text
https://transmute.example.com/api/oidc/callback
```

Then configure the public application URL and the exact upstream OIDC settings:

```yaml
config:
  appUrl: https://transmute.example.com

oidc:
  enabled: true
  issuerUrl: https://id.example.com/realms/main
  internalUrl: http://keycloak.identity.svc/realms/main
  clientId: transmute
  clientSecret: replace-me
  displayName: Company SSO
  autoCreateUsers: true
```

`internalUrl` is optional. Use it when the public issuer is not reachable from
the cluster. Transmute requests the fixed upstream scopes `openid email profile`.
Password login remains available unless `autoLaunch` redirects the UI directly.

For production, store both `AUTH_SECRET_KEY` and `OIDC_CLIENT_SECRET` in an
existing Secret and set `auth.existingSecret`.

## External Secrets Operator

The chart accepts canonical full `ExternalSecret` specs and can render multiple
items. The application Secret must contain `AUTH_SECRET_KEY` and, with OIDC,
`OIDC_CLIENT_SECRET`:

```yaml
auth:
  existingSecret: transmute-auth

externalSecrets:
  enabled: true
  items:
    - fullnameOverride: transmute-auth
      spec:
        secretStoreRef:
          name: platform-secrets
          kind: ClusterSecretStore
        target:
          name: transmute-auth
          creationPolicy: Owner
        data:
          - secretKey: AUTH_SECRET_KEY
            remoteRef:
              key: applications/transmute
              property: auth-secret-key
```

See [examples/external-secrets.yaml](examples/external-secrets.yaml) for OIDC too.

## Exposure

Ingress uses `ingress.ingressClassName`. Gateway API can render one or more
`HTTPRoute` resources and defaults each rule to the chart Service when no
`backendRefs` are supplied. Both APIs can coexist.

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - name: public
      parentRefs:
        - name: shared-gateway
          namespace: gateway-system
      hostnames:
        - transmute.example.com
```

The Service also supports `SingleStack`, `PreferDualStack` and
`RequireDualStack` through `service.ipFamilyPolicy` and `service.ipFamilies`.

## Backup and restore

All durable state is under `config.dataDir` on one PVC. Use a CSI snapshot or a
file-level volume backup while application writes are quiesced. Restore the PVC,
the JWT signing Secret and the same chart configuration together. This chart does
not claim an application-aware online backup mechanism.

## Breaking changes in chart v2

Chart v2 replaces the non-functional v1 configuration surface with upstream
Transmute variables. Migrate before upgrading:

| Removed v1 value | v2 replacement |
| --- | --- |
| `config.storageDir` | Removed; all state uses `config.dataDir` |
| `config.queueConcurrency` | `config.conversionWorkerConcurrency` and `config.compressionWorkerConcurrency` |
| `config.jobTimeout` | `config.conversionJobStaleAfterMinutes` |
| `auth.enabled` | `config.allowUnauthenticated` |
| `auth.allowRegistration` | Removed; unsupported upstream |
| `auth.initialAdmin.*` | Removed; the first registered user becomes admin |
| `oidc.providerUrl` | `oidc.issuerUrl` |
| `oidc.redirectUri` | `config.appUrl`; callback is derived as `/api/oidc/callback` |
| `oidc.scopes` | Removed; upstream scopes are fixed |
| `oidc.autoRegister` | `oidc.autoCreateUsers` |
| `oidc.disableLocalAuth` | `oidc.autoLaunch` has different redirect behavior |
| `externalSecrets.secretStoreRef/data/dataFrom` | `externalSecrets.items[].spec` |

Also note that `replicaCount` now must be `1`, `persistence.enabled` must be
`true`, and the signing Secret key is named `AUTH_SECRET_KEY` instead of
`TRANSMUTE_SECRET_KEY`.

## Configuration reference

| Parameter | Description | Default |
| --- | --- | --- |
| `replicaCount` | Supported pod count; fixed to one | `1` |
| `image.repository` | Official Transmute image | `ghcr.io/transmute-app/transmute` |
| `image.tag` | Pinned image tag | `v2.1.1` |
| `image.pullPolicy` | Pull policy | `IfNotPresent` |
| `imagePullSecrets` | Registry pull Secrets | `[]` |
| `nameOverride` / `fullnameOverride` | Resource name overrides | `""` |
| `commonLabels` | Labels added to chart resources | `{}` |
| `serviceAccount.*` | ServiceAccount creation, name, annotations and token mounting | see values |
| `podAnnotations` / `podLabels` | Additional pod metadata | `{}` |
| `podSecurityContext` | Pod-level security settings | non-root UID/GID 1000 |
| `securityContext` | Container security settings | read-only root, all capabilities dropped |
| `containerPorts.http` | Transmute process HTTP port | `8080` |
| `service.type` / `service.port` | Service type and public port | `ClusterIP` / `8080` |
| `service.annotations` | Service annotations | `{}` |
| `service.ipFamilyPolicy` | Kubernetes Service IP family policy | omitted |
| `service.ipFamilies` | Ordered Service IP families | omitted |
| `config.appUrl` | Public base URL; required for OIDC | `""` |
| `config.dataDir` | Persistent application data directory; must equal the PVC mount path | `/app/data` |
| `config.conversionWorkerConcurrency` | Conversion workers | `5` |
| `config.conversionJobStaleAfterMinutes` | Stale conversion threshold | `60` |
| `config.compressionWorkerConcurrency` | Compression workers | `5` |
| `config.invalidatePdfDigitalSignatures` | Permit signature-invalidating PDF changes | `false` |
| `config.maxChunkSize` | Upload chunk limit; zero uses upstream behavior | `0` |
| `config.allowUnauthenticated` | Permit unauthenticated requests | `false` |
| `config.domainAuthConfigPath` | Optional domain-auth config path | `""` |
| `auth.secretKey` | Inline JWT key, minimum 32 characters | generated |
| `auth.existingSecret` | Existing Secret for JWT and OIDC keys | `""` |
| `auth.secretKeyKey` | JWT key field | `AUTH_SECRET_KEY` |
| `auth.algorithm` | JWT algorithm | `HS256` |
| `auth.accessTokenExpireMinutes` | Token lifetime | `60` |
| `oidc.*` | Issuer, internal URL, client and login behavior | disabled |
| `ingress.*` | Ingress class, hosts, TLS and annotations | disabled |
| `gatewayAPI.*` | Canonical HTTPRoute definitions | disabled |
| `resources` | Container requests and limits | CPU 200m, memory 256Mi/2Gi |
| `livenessProbe` / `readinessProbe` / `startupProbe` | Health probes | upstream endpoints |
| `persistence.*` | PVC size, class, modes, mount and existing claim | enabled, `20Gi` |
| `externalSecrets.*` | API version, refresh interval and full items | disabled |
| `env` / `envFrom` | Additional environment sources | `[]` |
| `volumeMounts` / `volumes` | Additional storage mounts | `[]` |
| `networkPolicy.*` | Ingress policy and optional explicit egress isolation | disabled |
| `nodeSelector` / `tolerations` / `affinity` | Pod scheduling | empty |
| `topologySpreadConstraints` | Topology spread configuration | `[]` |
| `priorityClassName` | Pod priority class | `""` |
| `terminationGracePeriodSeconds` | Graceful shutdown window | `30` |

## Security Scan: `transmute`

| Framework | Score |
| --- | --- |
| MITRE + NSA + SOC2 | **87.878784%** |

> Security posture acceptable.

Measured with Kubescape v4.0.9 against the default rendered manifests on
2026-10-22. This assesses Kubernetes configuration; it is not an application
vulnerability scan.

## Operations

See [docs/operations.md](docs/operations.md) for first access, OIDC verification,
backup, restore, upgrades and troubleshooting.
