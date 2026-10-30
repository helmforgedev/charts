<!-- SPDX-License-Identifier: Apache-2.0 -->

# ntfy Configuration

ntfy needs a stable public URL when clients connect through Ingress or Gateway API.

## Public URL

```yaml
ntfy:
  baseUrl: "https://ntfy.example.com"
```

This value should match the URL used by browsers, mobile apps, and scripts.

## Listener and Service Ports

`containerPorts.http` controls the port on which the ntfy process listens.
`service.port` is the stable client-facing Service port and targets the named
`http` container port.

```yaml
containerPorts:
  http: 8080

service:
  port: 80
```

Do not set `listen-http` through `ntfy.extraConfig` or
`NTFY_LISTEN_HTTP` through `ntfy.extraEnv`; the chart rejects both so probes,
Services, and the actual process listener cannot drift.

## Authentication

For private deployments, deny unauthenticated access and create users with the ntfy CLI:

```yaml
ntfy:
  authDefaultAccess: "deny-all"
```

After deployment:

```bash
kubectl exec -it deploy/<release>-ntfy -- ntfy user add --role=admin admin
```

## Metrics

```yaml
ntfy:
  enableMetrics: true

metrics:
  serviceMonitor:
    enabled: true
```

`ServiceMonitor` requires Prometheus Operator CRDs to exist in the cluster.

## PostgreSQL

ntfy can use PostgreSQL for its message cache, access control, and web push
subscriptions. The connection URL is read from an existing Kubernetes Secret
and is never stored in the ConfigMap:

```yaml
ntfy:
  database:
    enabled: true
    existingSecret: ntfy-database
    existingSecretKey: database-url

persistence:
  enabled: false
```

The Secret must contain a `database-url` key with a PostgreSQL connection URL.
When PostgreSQL is enabled, the chart omits `cache-file`, `auth-file`, and
`web-push-file`, as required by ntfy.

Disabling persistence is appropriate only when no local file-backed features
need durable storage. Keep it enabled for filesystem attachments, the ban-feed,
or custom configuration that writes beneath `/var/cache/ntfy`.

PostgreSQL does not by itself make the chart highly available. The chart keeps
one replica, and local filesystem attachments are not shared.

## External Secrets

Use External Secrets Operator to reconcile the database Secret from a provider:

```yaml
ntfy:
  database:
    enabled: true
    existingSecret: ntfy-database

externalSecrets:
  enabled: true
  refreshInterval: 1h
  items:
    - fullnameOverride: ntfy-database
      spec:
        secretStoreRef:
          name: production-secrets
          kind: ClusterSecretStore
        target:
          name: ntfy-database
        data:
          - secretKey: database-url
            remoteRef:
              key: ntfy/database
              property: url
```

See the [External Secrets Operator documentation](https://external-secrets.io/latest/)
for provider setup.

Secret rotation does not update `NTFY_DATABASE_URL` inside a running pod because
Kubernetes injects environment variables only when containers start. Trigger a
Deployment rollout after rotation, or use a compatible restart controller that
restarts the workload when the target Secret changes.

## Abuse Ban-Feed

ntfy 2.26.3 can emit confirmed abusive visitors to a file consumed by fail2ban
or equivalent enforcement:

```yaml
ntfy:
  banFeed:
    enabled: true
    file: /var/cache/ntfy/ban.log
    window: 10m
    threshold: 100
    weights:
      - "42909:10"
```

The default path is on the chart's writable data volume. Configure an external
consumer and rotate the file with copy-truncate semantics. The chart does not
install fail2ban or modify node firewall rules.

## Gateway API

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: public
      namespace: gateway-system
  hostnames:
    - ntfy.example.com
```

## Dual Stack Service

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

## Availability and Network Policy

The singleton Deployment can be protected from voluntary eviction:

```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

Ingress isolation can be enabled independently. Egress isolation should list
every external dependency. For external PostgreSQL, a database CIDR is
required:

```yaml
networkPolicy:
  enabled: true
  ingressFrom:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-system
  egress:
    enabled: true
    dnsPeers:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: kube-system
    externalDatabaseCIDR: 10.30.0.0/24
    extraEgress:
      - to:
          - ipBlock:
              cidr: 198.51.100.10/32
        ports:
          - protocol: TCP
            port: 587
```

## Security and Temporary Storage

The secure defaults require the upstream image and mounted storage to be
writable by UID/GID 1000. `/tmp` and non-persistent data use bounded
`emptyDir` volumes:

```yaml
runtimeStorage:
  tmpSizeLimit: 128Mi

persistence:
  enabled: false
  emptyDirSizeLimit: 1Gi
```

Keep `serviceAccount.automountServiceAccountToken: false` unless ntfy or a
custom sidecar explicitly needs Kubernetes API access.
