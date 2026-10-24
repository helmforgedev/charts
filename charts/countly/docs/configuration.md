<!-- SPDX-License-Identifier: Apache-2.0 -->
# Configuration

## Application Listeners

`countly.apiPort` and `countly.dashboardPort` configure the sockets opened by
the Countly API and dashboard processes. `service.apiPort` and `service.port`
configure the Kubernetes-facing ports independently. The Service targets the
named container ports, so overrides remain aligned.

```yaml
countly:
  apiPort: 3101
  dashboardPort: 6101
service:
  apiPort: 3100
  port: 8080
```

Ingress and HTTPRoute expose only the dashboard Service port. Create an explicit
API route or LoadBalancer when SDK clients cannot reach the cluster Service.

## MongoDB Modes

The default deploys the HelmForge MongoDB dependency. Its generated root
password is referenced from the dependency Secret and is not copied into a
ConfigMap.

For a managed service:

```yaml
mongodb:
  enabled: false
externalMongodb:
  enabled: true
  existingSecret: countly-mongodb
  existingSecretUriKey: mongodb-uri
```

The Secret key contains the complete URI. Direct `externalMongodb.uri` values
are supported for non-sensitive development environments but are retained in
Helm release history.

External Secrets renders the Secret named by
`externalMongodb.existingSecret`. Its `externalSecrets.data` list must include
the configured URI key.

## Plugins and Environment

`countly.plugins` replaces the upstream plugin list. Keep it empty to use the
image default. `countly.extraEnv` accepts standard Kubernetes EnvVar objects for
upstream settings not modeled by the chart. Do not override chart-managed
MongoDB or listener variables through `extraEnv`.

## Scheduling and Resources

Set `resources` from measured event volume and dashboard load. Node selection,
tolerations, affinity, topology spread, priority class, and termination grace
are available at the top level. The chart intentionally keeps one application
replica because it does not automate Countly clustering or validate every
plugin's multi-process behavior.

## Related Guides

- [Operations](operations.md)
- [Security](security.md)
- [Backup and restore](backup-and-restore.md)
