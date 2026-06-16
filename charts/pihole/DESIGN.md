# Pi-hole Chart Design

## Purpose

The `pihole` chart deploys the official Pi-hole DNS sinkhole as a single
Kubernetes workload with persistent configuration, Helm-managed DNS lists,
optional Unbound recursive DNS, optional Prometheus metrics, and optional
S3-compatible backups.

Pi-hole is stateful and authoritative for client DNS configuration. The chart
therefore treats one pod as the supported topology and uses `Recreate` rollout
semantics so one instance owns `/etc/pihole` and `/etc/dnsmasq.d` at a time.

## Workload Model

The chart renders a Deployment with one replica. The main container exposes DNS
over TCP and UDP port 53 plus the web admin interface on port 80. DHCP can be
enabled for advanced home-network deployments, but it requires host networking
because DHCP broadcasts do not cross Kubernetes service boundaries.

The DNS service defaults to `LoadBalancer` because Pi-hole is normally consumed
by devices outside the cluster. The documentation calls out that
`serviceDns.loadBalancerIP` should be reserved before the first production
install; changing this address breaks every client configured to use Pi-hole.

## Storage Design

Pi-hole persists its application state under `/etc/pihole`. The chart creates a
single PVC for that path by default and allows operators to attach an existing
claim for migration or disaster recovery.

`/etc/dnsmasq.d` is modeled as a writable `emptyDir`. Helm-managed dnsmasq
fragments are mounted into that directory only when the corresponding features
are enabled. This keeps Pi-hole compatible with its own runtime writes while
still allowing GitOps-managed DNS records and conditional forwarding rules.

## Gravity Design

When `gravity.enabled` is true, the chart runs `gravity-init` before the main
container starts. That init container reconciles Pi-hole v6 gravity schema rows
for Helm-managed adlists, whitelist entries, blacklist entries, and regex
filters.

When `gravity.updateOnInit` is true, a second init container runs `pihole -g`
with the same official Pi-hole image as the main workload. This makes first
startup deterministic: blocklists are downloaded before the pod is marked ready,
rather than relying on an operator to run gravity manually after install.

## Security Model

The official Pi-hole image must start with elevated permissions because it binds
DNS ports, adjusts ownership of `/etc/pihole`, and runs FTL with DNS-specific
capabilities. The chart therefore does not force `runAsNonRoot`,
`runAsUser`, `capabilities.drop: ALL`, or `readOnlyRootFilesystem: true` by
default.

The compatible default hardening set is:

- `serviceAccount.automountServiceAccountToken: false`
- `podSecurityContext.seccompProfile.type: RuntimeDefault`
- `securityContext.allowPrivilegeEscalation: false`
- explicit CPU and memory requests/limits for Pi-hole, gravity init, gravity
  update, backup, metrics, and Unbound containers

The remaining Kubescape findings are documented product exceptions for DNS
capabilities, root bootstrap behavior, writable runtime configuration, and
NetworkPolicy delegation. The chart does not generate NetworkPolicy because
home DNS, DHCP, recursive DNS, conditional forwarding, S3 backup endpoints, and
monitoring stacks vary by deployment.

## Networking

Pi-hole's upstream DNS is configured through Pi-hole v6 `FTLCONF_` environment
variables. The chart default uses `pihole.listeningMode: ALL` because the
upstream Pi-hole default only accepts local queries, which does not work for
Kubernetes pod and service networking.

When `unbound.enabled` is true, the chart automatically overrides Pi-hole's
upstream DNS to `127.0.0.1#5335`. Unbound runs in the same pod network namespace
and receives only local queries from Pi-hole.

The DNS and web services both expose `ipFamilyPolicy` and `ipFamilies` so
operators can render dual-stack manifests. The CI scenario uses explicit IPv4
settings because the HelmForge k3d validation lab is IPv4-only.

## Observability

The chart uses HTTP probes against `/admin/` so readiness follows the web admin
surface that operators use for status checks. Startup has a longer failure
threshold to allow gravity downloads and first-boot initialization.

Prometheus metrics are optional through the `pihole-exporter` sidecar. When
enabled, the chart exposes a metrics port on the web service and can render a
ServiceMonitor for Prometheus Operator.

## Backup Design

Backups are optional and rendered as a CronJob. The job creates an archive from
selected Pi-hole state and uploads it to S3-compatible storage with the
HelmForge MinIO client image. Credentials can come from a chart-managed Secret
or an existing Secret.

The backup containers use explicit resource requests and limits by default so
enabling backups does not introduce unconstrained workloads.

## Validation Expectations

The chart must pass:

- `make standards-check CHART=pihole`
- `helm lint --strict charts/pihole`
- `helm unittest charts/pihole`
- `make validate-chart CHART=pihole`

Runtime validation must cover default install plus CI scenarios for custom DNS,
dual-stack rendering, External Secrets, full values, Gateway API, host network,
Ingress, metrics, namespace override, no persistence, and Unbound. The External
Secrets scenario must use the HelmForge fake store in the k3d lab.
