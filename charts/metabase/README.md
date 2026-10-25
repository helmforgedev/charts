<!-- SPDX-License-Identifier: Apache-2.0 -->

# Metabase Helm Chart

Deploy [Metabase](https://www.metabase.com) on Kubernetes using the official
[metabase/metabase](https://hub.docker.com/r/metabase/metabase) Docker image.
Open-source BI platform with visual data exploration, SQL editor, and shareable dashboards connecting to 60+ databases.

## Features

- **Visual data exploration** — point-and-click queries, no SQL required
- **SQL editor** — native SQL with autocomplete and snippets
- **60+ database connectors** — PostgreSQL, MySQL, BigQuery, Redshift, and more
- **PostgreSQL metadata store** — bundled subchart or external database
- **Backups** — optional PostgreSQL dump CronJob for S3-compatible object storage
- **Auto-generated encryption key** — protects saved database credentials
- **JVM tuning** — configurable JAVA_OPTS for memory optimization
- **Ingress support** — TLS with cert-manager
- **Gateway API** — HTTPRoute for clusters running Envoy Gateway or similar
- **Dual-stack networking** — IPv4/IPv6 service support
- **External Secrets Operator** — ExternalSecret for Vault, AWS Secrets Manager, and more
- **Secure runtime defaults** — non-root UID 2000, read-only root filesystem, dropped capabilities, RuntimeDefault seccomp, and no API token mount
- **Optional disruption and traffic controls** — PodDisruptionBudget and NetworkPolicy templates

## Architecture

The release runs one Metabase Deployment behind a named-port Service. Metabase stores application metadata in either
the bundled HelmForge PostgreSQL StatefulSet or an external PostgreSQL service; analytical source databases remain
outside the chart boundary. The application Secret supplies the stable encryption key, while an optional backup
CronJob exports only the PostgreSQL metadata database to S3-compatible storage.

The application container runs directly as UID/GID `2000`, with a read-only root filesystem. Bounded `emptyDir`
volumes provide the only writable paths: `/plugins`, `/tmp`, and `/target`. See [DESIGN.md](DESIGN.md) for trust
boundaries, failure modes, and non-goals.

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install metabase helmforge/metabase -f values.yaml
```

**OCI registry:**

```bash
helm install metabase oci://ghcr.io/helmforgedev/helm/metabase -f values.yaml
```

## Basic Example

```yaml
# values.yaml — default values deploy with bundled PostgreSQL
# No configuration needed for a basic setup
```

After deploying, access Metabase:

```bash
kubectl port-forward svc/<release>-metabase 3000:80
# Open http://localhost:3000 to complete the setup wizard
```

## External Database

```yaml
postgresql:
  enabled: false

database:
  external:
    host: postgres.example.com
    name: metabase
    username: metabase
    existingSecret: metabase-db-credentials
```

## JVM Tuning

```yaml
metabase:
  javaOpts: "-Xmx2g -Xms1g"

resources:
  requests:
    memory: 2Gi
  limits:
    memory: 3Gi
```

## Air-Gapped or Proxied Registries

The `wait-for-db` init container image is configurable separately from the main
Metabase image, so proxy-based environments can mirror both images:

```yaml
image:
  repository: registry.example.com/proxy/metabase/metabase
  tag: v0.64.2

waitForDatabase:
  image:
    repository: registry.example.com/proxy/library/busybox
    tag: "1.37"
```

Use `extraInitContainers` with `extraVolumes` and `extraVolumeMounts` when you
need to prepare files before Metabase starts, for example JDBC drivers mounted
into a shared plugin directory.

User-provided mounts at `/plugins`, `/tmp`, or `/target` replace the corresponding chart-managed `emptyDir`. The
matching `runtimeStorage.*SizeLimit` no longer applies to that path. User-provided volumes named `runtime-plugins`,
`runtime-tmp`, or `runtime-target` also replace the chart-managed volume with that name.

## Dual-Stack Service

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

## Gateway API (HTTPRoute)

Requires Gateway API CRDs and a compatible controller (e.g. Envoy Gateway).

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: envoy-gateway
      namespace: envoy-gateway-system
  hostnames:
    - metabase.example.com
```

> **Note:** `gateway.parentRefs` is required when `gateway.enabled=true`.
> Existing releases that still carry `gatewayAPI.enabled`, `gatewayAPI.gatewayName`,
> and `gatewayAPI.gatewayNamespace` from older chart values remain supported as a
> deprecated upgrade alias. New configuration should use `gateway.parentRefs`.

## External Secrets Operator (ESO)

Requires ESO installed. Set `metabase.existingSecret` so the chart-managed Secret is suppressed and the ExternalSecret is the single source of truth.

```yaml
metabase:
  existingSecret: metabase-eso-secret
  existingSecretKey: encryption-secret-key

externalSecrets:
  enabled: true
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  data:
    - secretKey: encryption-secret-key
      remoteRef:
        key: metabase/credentials
        property: encryption-secret-key
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `docker.io/metabase/metabase` | Metabase container image repository |
| `image.tag` | `v0.64.2` | Metabase container image tag |
| `waitForDatabase.image.repository` | `docker.io/library/busybox` | Wait-for-db init container image repository |
| `waitForDatabase.image.tag` | `1.37` | Wait-for-db init container image tag |
| `waitForDatabase.image.pullPolicy` | `IfNotPresent` | Wait-for-db init container image pull policy |
| `metabase.port` | `3000` | Application port |
| `metabase.encryptionSecretKey` | `""` | Encryption key (auto-generated) |
| `metabase.siteUrl` | `""` | Public site URL |
| `metabase.aiFeaturesEnabled` | `false` | Enable Metabase AI features after configuring a supported provider |
| `metabase.javaTimezone` | `UTC` | Java timezone |
| `metabase.javaOpts` | `""` | JVM memory options |
| `probes.startup.initialDelaySeconds` | `90` | Startup probe delay for first-run migrations and PostgreSQL bootstrap |
| `postgresql.enabled` | `true` | Deploy HelmForge PostgreSQL subchart (`2.1.1`) |
| `postgresql.standalone.persistence.size` | `8Gi` | PostgreSQL standalone PVC size |
| `resources.requests.memory` | `512Mi` | Metabase memory request |
| `resources.limits.memory` | `2Gi` | Metabase memory limit |
| `podSecurityContext.runAsNonRoot` | `true` | Require a non-root runtime identity |
| `podSecurityContext.runAsUser` | `2000` | Run the official image without root privileges |
| `podSecurityContext.runAsGroup` | `2000` | Primary runtime group |
| `podSecurityContext.fsGroup` | `2000` | Writable volume group ownership |
| `podSecurityContext.fsGroupChangePolicy` | `OnRootMismatch` | Avoid unnecessary recursive ownership changes |
| `podSecurityContext.seccompProfile.type` | `RuntimeDefault` | Apply the runtime default seccomp profile |
| `securityContext.allowPrivilegeEscalation` | `false` | Block privilege escalation |
| `securityContext.readOnlyRootFilesystem` | `true` | Make the application root filesystem immutable |
| `securityContext.capabilities.drop` | `[ALL]` | Drop all Linux capabilities |
| `runtimeStorage.pluginsSizeLimit` | `512Mi` | Limit the writable `/plugins` emptyDir |
| `runtimeStorage.tmpSizeLimit` | `512Mi` | Limit the writable `/tmp` emptyDir |
| `runtimeStorage.targetSizeLimit` | `256Mi` | Limit the writable `/target` log emptyDir |
| `serviceAccount.automountServiceAccountToken` | `false` | Keep the Kubernetes API token out of the pod |
| `pdb.enabled` | `false` | Render a PodDisruptionBudget |
| `networkPolicy.enabled` | `false` | Restrict inbound traffic to declared peers |
| `networkPolicy.egress.enabled` | `false` | Restrict outbound traffic to declared rules |
| `networkPolicy.ingress.allowSameNamespace` | `true` | Permit traffic from the release namespace |
| `networkPolicy.ingress.extraFrom` | `[]` | Add ingress peers such as a cross-namespace controller |
| `networkPolicy.egress.allowDNS` | `true` | Permit DNS while egress isolation is enabled |
| `networkPolicy.egress.extraEgress` | `[]` | Add complete rules for analytical databases and integrations |
| `ingress.enabled` | `false` | Enable ingress |
| `service.port` | `80` | Service port |
| `service.ipFamilyPolicy` | `~` | IP family policy (`SingleStack`, `PreferDualStack`, `RequireDualStack`) |
| `service.ipFamilies` | `[]` | IP families override (`IPv4`, `IPv6`) |
| `extraInitContainers` | `[]` | Additional init containers rendered after `wait-for-db` |
| `gateway.enabled` | `false` | Enable Gateway API HTTPRoute |
| `gateway.parentRefs` | `[]` | Gateway parentRefs (required when `gateway.enabled=true`) |
| `gateway.hostnames` | `[]` | HTTPRoute hostnames |
| `gateway.path` | `/` | HTTPRoute path match value |
| `gateway.pathType` | `PathPrefix` | HTTPRoute path match type |
| `externalSecrets.enabled` | `false` | Render ExternalSecret resource |
| `externalSecrets.apiVersion` | `external-secrets.io/v1` | ExternalSecret API version |
| `externalSecrets.refreshInterval` | `"0"` | Refresh interval (`"0"` = one-time sync) |
| `externalSecrets.secretStoreRef.name` | `""` | SecretStore name (required when enabled) |
| `externalSecrets.secretStoreRef.kind` | `SecretStore` | SecretStore kind |
| `externalSecrets.data` | `[]` | Remote key mappings (must include encryption key entry) |

## Upgrade Notes

### Upgrading to v0.64.2

Metabase `v0.64.2` is a patch release fixing analytics regressions and query optimizations.
Review the [official v0.64.2 release notes](https://github.com/metabase/metabase/releases/tag/v0.64.2).

### Upgrading to v0.64.1

Metabase `v0.64.1` is the first public maintenance release in the 0.64 line. Back up the Metabase application
database and review the [official Metabase 64 changelog](https://www.metabase.com/changelog/64#metabase-641)
before upgrading. Keep the encryption key stable and validate the `/api/health`
endpoint after rollout.

The generated application encryption key is reused from the existing Kubernetes
Secret during connected Helm upgrades. For GitOps or offline rendering, set
`metabase.existingSecret` to a stable Secret; `helm template` cannot look up the
cluster's current key. An explicit `metabase.encryptionSecretKey` takes precedence
and must not change after installation.

Metabase 0.64.1 includes the 0.64 feature line and its first maintenance fixes.
The existing startup encryption behavior remains relevant: to refuse automatic cleanup of legacy plaintext fields,
set `MB_DISABLE_LEGACY_STARTUP_ENCRYPTION=true` through `metabase.extraEnv`.
The upstream default is `false`. This option is separate from enabling
encryption on an application database that has never been encrypted.
The patch also validates LDAP server certificates; verify the trust chain of
your LDAP server before upgrading an LDAP-enabled deployment.
See the [0.64.1 changelog](https://www.metabase.com/changelog/64#metabase-641).

Starting with 0.63.16, adding encryption to an existing unencrypted application
database requires an explicit migration. Back up the database and key, stop all
Metabase instances, and run the upstream `enable-encryption` JAR command with the
same database environment and `MB_ENCRYPTION_SECRET_KEY` used by the deployment.
Restart with that same key. Existing encrypted databases do not need this command.
If encryption was already configured and Metabase reports an unencrypted database,
investigate and restore a known-good backup; do not automatically re-encrypt it.
See [Metabase encryption instructions](https://www.metabase.com/docs/latest/databases/encrypting-details-at-rest).

For signed database sessions, inject `MB_SESSION_SECRET_KEY` through
`metabase.extraEnv` using a Kubernetes `secretKeyRef`. Use a separate stable secret
of at least 16 characters. Setting or changing it logs out existing sessions;
coordinate activation with users. See the
[session secret documentation](https://www.metabase.com/docs/latest/configuring-metabase/environment-variables#mb_session_secret_key).

## Troubleshooting

### Pod never becomes ready

Metabase may spend several minutes applying metadata migrations on the first start. Inspect the startup probe and both
application and database logs before changing probe thresholds:

```bash
kubectl describe pod -l app.kubernetes.io/name=metabase
kubectl logs -l app.kubernetes.io/name=metabase -c metabase --tail=300
```

### Plugin or temporary storage is full

The secure defaults bound `/plugins`, `/tmp`, and `/target`. Increase the corresponding `runtimeStorage.*SizeLimit`
value after checking actual usage. Extra init containers can mount the reserved `runtime-plugins` volume to install
JDBC drivers before Metabase starts.

### NetworkPolicy blocks a connection

When `networkPolicy.enabled=true`, ingress defaults to the release namespace. Add the ingress controller to
`networkPolicy.ingress.extraFrom`. When egress isolation is also enabled, add rules for every analytical database,
SMTP server, webhook, and external API through `networkPolicy.egress.extraEgress`; an external metadata database also
requires `database.external.networkPolicyPeers`.

## Security

The application defaults enforce non-root execution, a read-only root filesystem, RuntimeDefault seccomp, dropped
capabilities, bounded writable runtime volumes, and disabled ServiceAccount token mounting. Secrets can be supplied by
existing Kubernetes Secrets or External Secrets. NetworkPolicy remains opt-in because the chart cannot infer the
analytical databases and external integrations each installation must reach.

## Security Scan

Security Scan: Kubescape local scan against `MITRE,NSA,SOC2` reports a 92.42% resource summary score.

## Examples

- [Production](examples/production.yaml)
- [External PostgreSQL](examples/external-db.yaml)
- [S3 backup](examples/backup.yaml)

## More Information

- [Chart design](DESIGN.md)
- [Database and backups](docs/database.md)
- [Production operations](docs/production.md)
- [Metabase documentation](https://www.metabase.com/docs/latest/)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/metabase)

<!-- @AI-METADATA
type: chart-readme
title: Metabase Helm Chart
description: README for the Metabase open-source BI platform Helm chart

keywords: metabase, bi, analytics, dashboard, visualization, postgresql, gateway-api, external-secrets, dual-stack

purpose: Chart installation, configuration, and usage documentation
scope: Chart

relations:
  - charts/metabase/DESIGN.md
  - charts/metabase/docs/database.md
  - charts/metabase/docs/production.md
  - charts/metabase/examples/production.yaml
  - charts/metabase/examples/external-db.yaml
  - charts/metabase/examples/backup.yaml
  - charts/metabase/values.yaml
path: charts/metabase/README.md
version: 1.2
date: 2026-06-02
-->
