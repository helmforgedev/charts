# Production

Use `sonarqube.databaseMode=external` for production.

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

Keep the data and extensions volumes persistent:

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
