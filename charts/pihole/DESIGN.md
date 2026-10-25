<!-- SPDX-License-Identifier: Apache-2.0 -->

# Pi-hole Chart Design

## Scope

The `pihole` chart deploys the official Pi-hole DNS sinkhole as a single
Kubernetes workload with persistent configuration, Helm-managed DNS lists,
optional Unbound recursive DNS, optional Prometheus metrics, and optional
S3-compatible backups.

Pi-hole is stateful and authoritative for client DNS configuration. The chart
therefore treats one pod as the supported topology and uses `Recreate` rollout
semantics so one instance owns `/etc/pihole` and `/etc/dnsmasq.d` at a time.

## Architecture

The chart renders a Deployment with one replica. The main container exposes DNS
over TCP and UDP through `containerPorts.dns` plus the web admin interface
through `containerPorts.http`. Both values configure Pi-hole FTL itself through
`FTLCONF_dns_port` and `FTLCONF_webserver_port`; Service ports remain separate.
DHCP port 67 is fixed by the protocol and explicitly documented as such. DHCP can be
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

## Security Boundary

The official Pi-hole image must start with elevated permissions because it binds
DNS ports, adjusts ownership of `/etc/pihole`, and runs FTL with DNS-specific
capabilities. The chart therefore does not force `runAsNonRoot`,
`runAsUser`, or `readOnlyRootFilesystem: true` by default. It does drop all
ambient capabilities before adding the minimum set required by the official
entrypoint and FTL. When enabled, the official Unbound sidecar similarly drops
all capabilities and adds only `CHOWN`, `DAC_OVERRIDE`, `MKNOD`, `SETGID`,
`SETUID`, and `SYS_CHROOT`; its entrypoint needs these to prepare the chroot and
DNSSEC trust anchor before dropping to the `_unbound` user.

The compatible default hardening set is:

- `serviceAccount.automountServiceAccountToken: false`
- `podSecurityContext.seccompProfile.type: RuntimeDefault`
- `securityContext.allowPrivilegeEscalation: false`
- `securityContext.capabilities.drop: [ALL]` before adding only Pi-hole's
  required capabilities
- explicit CPU and memory requests/limits for Pi-hole, gravity init, gravity
  update, backup, metrics, and Unbound containers

The remaining Kubescape findings are documented product exceptions for DNS
capabilities, root bootstrap behavior, and writable runtime configuration. A
default ingress NetworkPolicy admits only the declared DNS, web, optional DHCP,
and optional metrics ports. Its source list is open by default because DNS and
DHCP clients commonly live outside Kubernetes; operators can restrict
`networkPolicy.ingressFrom`. Egress remains open for upstream DNS, gravity
lists, recursive DNS, and optional S3 backups.

When DHCP is enabled, the chart configures the Pi-hole FTL DHCP range and
router, requires host networking, exposes fixed UDP port 67, and adds
`NET_ADMIN` only for that configuration. The default DNS-only deployment does
not receive `NET_ADMIN`.

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

## Observability Boundary

The chart uses HTTP probes against `/admin/` so readiness follows the web admin
surface that operators use for status checks. Startup has a longer failure
threshold to allow gravity downloads and first-boot initialization.

Prometheus metrics are optional through the `pihole-exporter` sidecar. When
enabled, the chart exposes a metrics port on the web service and can render a
ServiceMonitor for Prometheus Operator.

Container logs, HTTP probes, the live DNS query runtime smoke, and optional
Prometheus metrics are the supported signals. The chart does not provision a
Prometheus stack, alert rules, log aggregation, or external synthetic DNS
monitoring.

## Backup Design

Backups are optional and rendered as a CronJob. The job creates an archive from
selected Pi-hole state and uploads it to S3-compatible storage with the
HelmForge MinIO client image. Credentials can come from a chart-managed Secret
or an existing Secret.

The backup containers use explicit resource requests and limits by default so
enabling backups does not introduce unconstrained workloads.

## Design Decisions

- `Recreate` preserves single-writer ownership of the Pi-hole data PVC.
- DNS and web process ports are configurable because current Pi-hole FTL exposes
  supported configuration keys for both listeners.
- DHCP port 67 remains fixed because it is part of the DHCP protocol contract.
- Unbound and the exporter remain optional sidecars to keep the default pod
  focused on Pi-hole while supporting privacy and observability profiles.
- Every image is tag-and-digest pinned so tag intent remains readable while the
  runtime artifact is immutable.

## Production Boundary

The chart owns the workload, persistence, credentials, Service objects,
listener wiring, probes, and optional ingress resources. Operators own a stable
external DNS address, router or client DNS configuration, TLS and DNS names,
restricted NetworkPolicy peers, PVC snapshots and restore drills, upstream DNS
policy, and capacity planning.

## Known Gaps

- Pi-hole requires root bootstrap and selected network capabilities; a fully
  non-root, read-only-root-filesystem default is not compatible upstream.
- The default NetworkPolicy intentionally leaves source peers unrestricted to
  support external LAN clients.
- The chart is single-instance and does not implement state replication.
- DHCPv6 and NTP exposure are outside the current chart contract.

## Non-Goals

The chart does not provide Pi-hole clustering, Gravity Sync, router
configuration, a VPN, a Prometheus installation, or an S3 service. External
Unbound, exporters, and backup systems can be used, but their lifecycle is not
managed by this chart.

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
