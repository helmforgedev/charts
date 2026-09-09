# Moodle production topology

## Capacity planning

The default topology is one web pod, a cron sidecar and persistent PostgreSQL.
It is suitable for evaluating the complete application and as a starting point
for a small site. Production sizing depends on concurrent students, course
content, quizzes, scheduled reports, plugins and backup tasks.

Apache defaults to eight prefork workers. PHP defaults to 256 MiB per process;
the web container has a 2 GiB limit. These limits are ceilings, not reserved
capacity. Load test peak quizzes and uploads before accepting an SLO.

Increase `apache.maxRequestWorkers` only with enough memory and database
connections. The cron/worker containers have independent memory limits. Large
course backups often need more memory and disk than ordinary web requests.

## Public URL and TLS

Configure one canonical root URL without a trailing slash. DNS and certificates
are managed by your infrastructure. Route requests to the chart Service on port
80; Apache runs on unprivileged port 8080 inside the pod.

```yaml
moodle:
  wwwroot: https://learn.example.com
  sslProxy: true
  reverseProxy: false
ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: 64m
  hosts:
    - host: learn.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: learning-tls
      hosts: [learn.example.com]
```

`sslProxy` tells Moodle that TLS terminates at a trusted proxy. Secure cookies
follow the HTTPS public URL. `reverseProxy` remains false for ordinary Ingress
controllers that preserve the public Host header. Enabling it blindly can
trigger Moodle's reverse-proxy-abuse protection.

Set ingress upload limits consistently with PHP POST and upload limits. Configure
timeouts for long requests at your controller or gateway. Do not expose the
backend directly to untrusted clients when relying on proxy TLS settings.

This chart serves Moodle at the host root; use a dedicated hostname.

## Gateway API

Gateway API is optional and requires an existing Gateway controller and CRDs.
HTTPRoutes attach to a Gateway; the chart does not create or operate that Gateway.

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - name: learning
      parentRefs:
        - name: public-gateway
          namespace: gateway-system
          sectionName: https
      hostnames: [learn.example.com]
```

The default route backend is the Moodle Service and port. Explicit route rules
can add matches, filters and backendRefs. Give every route a unique name when
rendering more than one route. Ingress and HTTPRoute may coexist for migration.

See [Gateway API](https://gateway-api.sigs.k8s.io/) for namespace attachment,
TLS listener configuration and controller support.

## External PostgreSQL

The chart supports PostgreSQL 16 or newer. Its optional PostgreSQL dependency
is the HelmForge chart, not a vendor-specific database container wrapper.

```yaml
postgresql:
  enabled: false
database:
  host: postgres.learning.svc.cluster.local
  port: 5432
  name: moodle
  username: moodle
  existingSecret: learning-db
  existingSecretPasswordKey: password
  sslMode: verify-full
  tlsSecret: learning-db-ca
  tlsCAKey: ca.crt
```

Provision an empty UTF-8 database and a user that owns the Moodle schema.
The schema owner needs DDL permissions for installation and upgrades. Use a
dedicated database; the upstream installer refuses unrelated existing tables.

Verified TLS uses the mounted CA and libpq's hostname verification. Do not use
an IP address if the server certificate is issued only for a DNS hostname.
The chart does not provision an external database or rotate its passwords.

Bundled PostgreSQL accepts the full subchart contract, including its persistence,
resources and replication settings. For production, prefer a managed database
or a database topology whose failover and backups you operate and test.

## Redis sessions and MUC

Enable explicit session storage with either bundled Redis:

```yaml
sessions:
  enabled: true
redis:
  enabled: true
```

Or an external service:

```yaml
sessions:
  enabled: true
  host: redis.learning.svc.cluster.local
  port: 6379
  existingSecret: learning-redis
  existingSecretPasswordKey: redis-password
  database: 0
  prefix: school_a_session_
```

Use a dedicated prefix and an appropriate Redis eviction policy. Losing session
keys signs users out. Redis availability is part of the login availability
budget; a standalone Redis deployment is not an HA service.

For Redis TLS, set `sessions.tlsSecret` and `tlsCAKey`. Certificate validation
remains enabled. Use a stable service endpoint supplied by your Redis platform.
The bundled topology supported by this chart is standalone Redis.

Redis sessions do not configure Moodle Universal Cache mappings. Configure and
test MUC stores in Moodle's cache administration or through reviewed application
configuration. The chart deliberately does not claim that enabling sessions
automatically moves every Moodle cache into Redis.

## Safe horizontal scaling

Multiple web pods and HPA require both:

1. `persistence.enabled=true` with real `ReadWriteMany` storage.
2. `sessions.enabled=true` with a reachable Redis endpoint.

The chart fails rendering when these prerequisites are absent. `existingClaim`
does not prove that a volume supports concurrent writers: its declared access
modes must describe the actual provisioned storage.

Moodledata, shared cache, temporary and backup temporary directories remain on
the shared volume. Only local cache/request directories use per-container
emptyDir. Redis or an object-storage plugin does not remove this filesystem
requirement.

Moodle uses PostgreSQL task locks. The chart does not configure a nonexistent
core Redis lock factory. Shared sessions, task locks and identical read-only code
allow requests and cron execution across replicas.

Use node anti-affinity/topology spread with enough cluster capacity. Enable PDB
only with multiple replicas. Ensure the minimum HPA replica count can satisfy
your PDB during node maintenance.

The local lab tests concurrent web replicas against a shared volume on one node.
That proves application concurrency and shared writes, not cross-node CSI
failover. Test the chosen production RWX storage and database/Redis failover in
your own multi-node environment.

## NetworkPolicy

NetworkPolicy is opt-in. Its default policy permits web ingress to port 8080,
DNS egress, the bundled PostgreSQL/Redis endpoints and HTTPS egress in archive
mode. Configure `ingressFrom` to restrict traffic to your gateway/controller.

Add explicit `extraEgress` rules for external databases, Redis, SMTP, identity
providers, object stores and other application integrations. Kubernetes network
policies do not provide portable FQDN filtering; unrestricted port 443 egress in
archive mode is a documented compromise. Use an immutable image and explicit
egress destinations where tighter policy is required.

## SMTP and email safety

```yaml
smtp:
  hosts: smtp.example.com:587
  security: tls
  username: moodle
  existingSecret: learning-smtp
  existingSecretPasswordKey: smtp-password
  noReplyAddress: noreply@example.com
```

SMTP passwords stay in Secret references. Send a test message through Moodle,
then exercise a cron-driven notification. Check sender authorization, SPF, DKIM
and your provider's quotas outside the chart.

Set `moodle.noEmailEver=true` on staging and restored test sites to prevent
accidental notifications to real students. Explicitly reverse that setting only
when the intended environment should send mail.

## External Secrets

The chart uses `externalSecrets.enabled`, `refreshInterval` and `items[]`.
Each item carries a complete ExternalSecret spec. The operator must already be
installed; the chart renders the stable `external-secrets.io/v1` API.

```yaml
moodle:
  existingSecret: learning-admin
externalSecrets:
  enabled: true
  items:
    - fullnameOverride: learning-admin
      spec:
        secretStoreRef:
          name: production-secrets
          kind: ClusterSecretStore
        target:
          name: learning-admin
        data:
          - secretKey: admin-password
            remoteRef:
              key: learning/moodle
              property: bootstrapPassword
```

Wait for `Ready=True` and `SecretSynced`, then verify the workload consumes the
target. Database/Redis/SMTP secrets may be synchronized by additional items.
Secret rotation does not itself change existing database or Moodle passwords.
Coordinate credential changes with the corresponding service and restart
consuming pods after environment-based secrets change.

## Dual-stack networking

The Service inherits cluster defaults when IP family fields are omitted.
Set `service.ipFamilyPolicy=PreferDualStack` for portable dual-stack preference.
Explicit `ipFamilies` values require a cluster advertising those families.

```yaml
service:
  ipFamilyPolicy: PreferDualStack
```

See [Kubernetes dual-stack](https://kubernetes.io/docs/concepts/services-networking/dual-stack/).
Upstream gateways, DNS and external databases must also support the selected
families; a dual-stack Service alone does not make all integrations dual-stack.
