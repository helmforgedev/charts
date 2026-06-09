# SonarQube

SonarQube Community Build for Kubernetes using the official Docker image.
It supports embedded evaluation mode, HelmForge PostgreSQL, external PostgreSQL, plugin automation, and the community branch plugin.

## Install

### HTTPS repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install sonarqube helmforge/sonarqube -f values.yaml
```

### OCI registry

```bash
helm install sonarqube oci://ghcr.io/helmforgedev/helm/sonarqube -f values.yaml
```

## What this chart covers

- official `docker.io/library/sonarqube` image
- `embedded` mode for disposable local validation
- `postgresql` mode backed by the HelmForge PostgreSQL subchart
- `external` mode for PostgreSQL-backed production deployments
- generated, existing, or External Secrets Operator-backed database password handling
- optional monitoring passcode secret handling
- plugin download init container with persistent extensions volume
- bundled PostgreSQL wait init container to avoid first-start connection races
- first-class community branch plugin wiring, including Java agents and webapp replacement
- Gateway API `HTTPRoute`, Ingress, and dual-stack Service fields
- default non-root pod security context, dropped Linux capabilities, and read-only root filesystem
- optional NetworkPolicy, PodDisruptionBudget, persistence, extra containers, and extra volumes
- Helm test pod that validates the SonarQube system status endpoint

## Database Modes

The default `auto` mode uses external settings when provided, then `postgresql.enabled`, and otherwise falls back to embedded evaluation mode. The embedded mode is intentionally scoped to disposable evaluation.

Bundled HelmForge PostgreSQL:

```yaml
sonarqube:
  databaseMode: postgresql

postgresql:
  enabled: true
  auth:
    database: sonarqube
    username: sonar
    password: change-me
```

External PostgreSQL:

```yaml
sonarqube:
  databaseMode: external

database:
  external:
    jdbcUrl: jdbc:postgresql://postgresql.database.svc.cluster.local:5432/sonarqube
    username: sonar
    existingSecret: sonarqube-database
    existingSecretPasswordKey: jdbc-password
```

## External Secrets

```yaml
sonarqube:
  databaseMode: external

database:
  external:
    jdbcUrl: jdbc:postgresql://postgresql.database.svc.cluster.local:5432/sonarqube
    username: sonar

externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  database:
    enabled: true
    passwordRemoteRef:
      key: sonarqube/database
      property: password
```

## Community Branch Plugin

The chart can install the community branch plugin and patch the SonarQube web application during startup.

```yaml
communityBranchPlugin:
  enabled: true
  version: "26.4.0"
```

Keep the plugin major and minor version aligned with the SonarQube version. The default chart image is pinned to `26.4.0.121862-community` to match the default plugin line.

See [Community Branch Plugin](docs/community-branch-plugin.md).

## Exposure

Ingress:

```yaml
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: sonarqube.example.com
      paths:
        - path: /
          pathType: Prefix
```

Gateway API:

```yaml
gatewayAPI:
  enabled: true
  parentRefs:
    - name: public-gateway
      namespace: gateway-system
  hostnames:
    - sonarqube.example.com
```

Dual-stack Service:

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

## Main Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `docker.io/library/sonarqube` | Official SonarQube image repository |
| `image.tag` | `26.4.0.121862-community` | SonarQube Community Build image tag |
| `sonarqube.databaseMode` | `auto` | `auto`, `embedded`, `postgresql`, or `external` |
| `postgresql.enabled` | `false` | Deploy HelmForge PostgreSQL as a subchart |
| `waitForDatabase.enabled` | `true` | Wait for bundled PostgreSQL before starting SonarQube |
| `database.external.jdbcUrl` | `""` | JDBC URL when using external mode |
| `database.external.existingSecret` | `""` | Existing database password Secret |
| `externalSecrets.enabled` | `false` | Render ExternalSecret resources |
| `plugins.enabled` | `false` | Enable plugin download init container |
| `communityBranchPlugin.enabled` | `false` | Install and wire the branch plugin |
| `persistence.data.enabled` | `true` | Persist SonarQube data |
| `persistence.extensions.enabled` | `true` | Persist installed plugins |
| `service.ipFamilyPolicy` | `~` | Optional Kubernetes Service IP family policy |
| `ingress.enabled` | `false` | Render Ingress |
| `gatewayAPI.enabled` | `false` | Render Gateway API HTTPRoute |
| `networkPolicy.enabled` | `false` | Render NetworkPolicy |
| `pdb.enabled` | `false` | Render PodDisruptionBudget |

## Production Notes

Before production use, read [Production](docs/production.md).
SonarQube embeds Elasticsearch and requires host kernel settings for production bootstrap checks.
The chart defaults to disabled bootstrap checks for k3d and evaluation; production clusters should set the host requirements and use bundled or external PostgreSQL.

## References

- [SonarQube Community Build](https://docs.sonarsource.com/sonarqube-community-build/)
- [Official SonarQube Docker image](https://hub.docker.com/_/sonarqube)
- [SonarQube Docker source](https://github.com/SonarSource/docker-sonarqube)
- [Community branch plugin](https://github.com/mc1arke/sonarqube-community-branch-plugin)

### 🟢 Security Scan: `sonarqube`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **92.42425%** |

> ✅ Security posture acceptable.
