<!-- SPDX-License-Identifier: Apache-2.0 -->

# Production

Use PostgreSQL for production. For a self-contained release, enable the HelmForge PostgreSQL subchart:

```yaml
sonarqube:
  databaseMode: postgresql
  esBootstrapChecksDisable: false

postgresql:
  enabled: true
  auth:
    database: sonarqube
    username: sonar
    password: change-me
  standalone:
    persistence:
      enabled: true
      size: 50Gi
```

For platform-managed database services, use `sonarqube.databaseMode=external`.

```yaml
sonarqube:
  databaseMode: external
  esBootstrapChecksDisable: false

database:
  external:
    jdbcUrl: jdbc:postgresql://postgresql.database.svc.cluster.local:5432/sonarqube
    username: sonar
    existingSecret: sonarqube-database
    existingSecretPasswordKey: jdbc-password
```

## Host Requirements

SonarQube embeds Elasticsearch. Production nodes must satisfy the SonarQube host requirements before enabling bootstrap checks:

- `vm.max_map_count=524288`
- `fs.file-max=131072`
- file descriptor limit of `131072`
- process limit of `8192`

Keep `sonarqube.esBootstrapChecksDisable=true` only for disposable local environments.

## Persistence

Keep the SonarQube data and extensions volumes persistent:

```yaml
persistence:
  data:
    enabled: true
    size: 50Gi
  extensions:
    enabled: true
    size: 10Gi
```

Use `existingClaim` when PVC lifecycle is managed outside Helm.

If `postgresql.enabled=true`, also size and back up the PostgreSQL PVC according to your retention requirements.

## Backup and Restore Boundary

A recoverable SonarQube backup combines a consistent PostgreSQL backup with the
data and extensions volumes. The logs volume is optional and is not required for
application recovery. Schedule and test backups outside this chart; restoring
only a PVC or only PostgreSQL is not a complete recovery procedure.

## Network

Use Gateway API or Ingress for HTTP exposure. SonarQube should normally be served behind TLS at the edge.

Enable NetworkPolicy when your CNI enforces it:

```yaml
networkPolicy:
  enabled: true
  egress:
    enabled: true
```

## Monitoring Passcode

When using endpoints that require a system passcode, provide it from a Secret:

```yaml
sonarqube:
  existingMonitoringPasscodeSecret: sonarqube-monitoring
  existingMonitoringPasscodeSecretKey: monitoring-passcode
```

## Upgrades

Read SonarSource upgrade notes before changing `image.tag`. Keep plugins compatible with the target SonarQube version, especially when `communityBranchPlugin.enabled=true`.

Validate database migrations and restore readiness in a non-production namespace
before promoting an upgrade.
