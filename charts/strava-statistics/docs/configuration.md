<!-- SPDX-License-Identifier: Apache-2.0 -->

# Dreeve Configuration and Operations

Dreeve v5 stores application settings in SQLite and exposes them through the admin panel. Helm values configure the
container runtime, bootstrap credentials, exposure, persistence, and Kubernetes controls.

## Runtime Secrets

For development, values can generate the runtime Secret:

```yaml
dreeve:
  appUrl: http://localhost:8080
  appSecret: replace-with-a-long-random-value
  adminUsername: admin
  adminPasswordHash: '$2y$13$replace-with-a-bcrypt-hash'
```

For production, prefer an existing Secret:

```yaml
dreeve:
  existingSecret: dreeve-runtime
  existingSecretAppSecretKey: app-secret
  existingSecretAdminPasswordHashKey: admin-password-hash
  existingSecretApiKeyKey: api-key
```

`api-key` is optional. Omitting it keeps the upload API disabled. `admin-password-hash` must be a bcrypt hash generated
by `bin/console security:hash-password`; do not store a plaintext password.

## Import Modes

### Strava API

The default preserves the behavior of earlier chart releases:

```yaml
dreeve:
  importMode: stravaApi

strava:
  existingSecret: strava-credentials
  existingSecretClientIdKey: client-id
  existingSecretClientSecretKey: client-secret
  existingSecretRefreshTokenKey: refresh-token
```

The chart fails rendering when `stravaApi` is selected without inline credentials or an existing Secret.

### Activity Files

File mode does not require Strava credentials:

```yaml
dreeve:
  importMode: files

strava:
  clientId: ""
  clientSecret: ""
  refreshToken: ""
```

Place FIT, TCX, or GPX files in the persistent `/var/www/watch` directory through an operator-controlled workflow.

## External Secrets

External Secrets can materialize the referenced runtime and Strava Secrets:

```yaml
externalSecrets:
  enabled: true
  items:
    - name: runtime
      storeRef:
        name: platform-secrets
        kind: ClusterSecretStore
      targetName: dreeve-runtime
      data:
        - secretKey: app-secret
          remoteRef:
            key: dreeve/runtime
            property: app-secret
        - secretKey: admin-password-hash
          remoteRef:
            key: dreeve/runtime
            property: admin-password-hash
    - name: strava
      storeRef:
        name: platform-secrets
        kind: ClusterSecretStore
      targetName: strava-credentials
      data:
        - secretKey: client-id
          remoteRef:
            key: dreeve/strava
            property: client-id
        - secretKey: client-secret
          remoteRef:
            key: dreeve/strava
            property: client-secret
        - secretKey: refresh-token
          remoteRef:
            key: dreeve/strava
            property: refresh-token

dreeve:
  existingSecret: dreeve-runtime

strava:
  existingSecret: strava-credentials
```

The chart does not install External Secrets Operator or a SecretStore.

## Persistence Layout

One RWO PVC is mounted by both containers at these paths:

| Path | Purpose |
| --- | --- |
| `/var/www/storage/database` | SQLite database |
| `/var/www/storage/files` | Uploaded activity and application files |
| `/var/www/storage/gear-maintenance` | Gear-maintenance assets |
| `/var/www/build` | Shared rendered dashboard cache |
| `/var/www/watch` | File-import watch directory |

The bootstrap init container creates every directory before the web and daemon containers start. It also exposes legacy
root-level `strava.db` or `dreeve.db` files through compatibility links.

Back up the entire PVC, with the database directory as the critical recovery asset. Keep `replicas: 1` and `Recreate`;
SQLite cannot safely support concurrent chart replicas.

## Legacy v4 Migration

`strava.config` is mounted as `/var/www/config/app/config.yaml` so the first v5 startup can migrate supported v4 YAML
settings into SQLite. After verifying them in the admin panel, remove custom YAML content. New v5 settings are managed in
the browser and no longer read from that file.

Images and gear purchase prices are not migrated upstream. Re-enter them after the upgrade. Consult the
[official migration guide](https://docs.dreeve.app/getting-started/migrating-from-v4/).

## Public URL and Exposure

Set the public root URL, including the scheme and non-default port when needed:

```yaml
dreeve:
  appUrl: https://dreeve.example.com
```

Ingress and Gateway API terminate TLS outside the pod. Dreeve listens on `strava.port` (default `8080`), while the
Kubernetes Service exposes `service.port` (default `80`) through the named `http` targetPort.

## Gateway API

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - name: web
      parentRefs:
        - name: public
          namespace: gateway-system
      hostnames:
        - dreeve.example.com
```

## Dual-Stack Service

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

## NetworkPolicy

When enabled, the chart renders exactly the supplied ingress and egress rule lists. Empty lists deny that traffic
direction. Declare DNS and every required external destination before enabling the policy:

```yaml
networkPolicy:
  enabled: true
  ingress:
    - from:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - {}
```

Replace unrestricted egress with cluster-specific DNS, Strava, map tile, notification, or AI-provider rules whenever
your NetworkPolicy implementation supports the necessary destination controls.

## Security Contexts

The defaults run as UID/GID `82`, use `RuntimeDefault` seccomp, disable token automounting and privilege escalation,
and make application root filesystems read-only. Writable PHP, Caddy, cache, and temporary paths are explicit bounded
volumes. The web container adds only `NET_BIND_SERVICE` because the upstream FrankenPHP binary carries that capability;
the daemon drops every capability.

An existing PVC must be writable by the configured `fsGroup`. If the CSI driver does not apply group ownership, repair
the volume out of band before installation rather than relaxing the application security context.

## Resources and PHP Memory

The upstream Kubernetes guidance recommends a `4G` PHP memory limit with `5Gi` container limits for large imports. The
chart applies those limits while using conservative CPU and memory requests. Tune web and daemon resources together;
both containers can process expensive activity data.

## Upgrade Verification

Before an upgrade:

1. Snapshot or back up the PVC.
2. Read the upstream release notes.
3. Confirm the pinned image exists for amd64 and arm64.
4. Upgrade the chart and wait for both containers to become Ready.
5. Check migration, daemon, and restart logs.
6. Verify admin login and run a representative import.

Useful commands:

```bash
kubectl rollout status deploy/<release>-strava-statistics
kubectl logs deploy/<release>-strava-statistics -c strava-statistics
kubectl logs deploy/<release>-strava-statistics -c daemon
kubectl get pod,pvc,svc -l app.kubernetes.io/instance=<release>
```

See the [operations runbook](operations.md) for backup, restore, upgrade, and incident procedures.
