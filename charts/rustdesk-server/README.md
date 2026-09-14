# RustDesk Server

[RustDesk Server OSS](https://github.com/rustdesk/rustdesk-server) provides the
rendezvous and relay infrastructure for self-hosted RustDesk remote desktop
clients. This chart runs one coordinated hbbs/hbbr pair with persistent identity,
restricted container privileges and real native protocol acceptance tests.

## Requirements

- Kubernetes >=1.29 with native SidecarContainers enabled; Helm 3.
- Storage supporting the configured UID/GID and volume ownership (1000 by default).
- A reachable TCP/UDP endpoint, DNS/firewall rules and compatible RustDesk clients
  for access outside the cluster. The default Service is private ClusterIP.
- External Secrets Operator or an HTTP/Gateway controller only if their optional
  integrations are enabled.

The official image is `docker.io/rustdesk/rustdesk-server:1.1.16`, verified for
amd64, arm64 and arm/v7. RustDesk Server is AGPL-3.0; this chart is Apache-2.0.
There is no Pro console, external SQL database, multi-replica mode or Prometheus
endpoint in this OSS chart.

## Install and connect

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install rustdesk helmforge/rustdesk-server \
  --namespace rustdesk --create-namespace -f production-values.yaml
kubectl -n rustdesk logs deployment/rustdesk-rustdesk-server -c hbbs
```

Start `production-values.yaml` from an [example](examples/production.yaml), then
replace its hostnames, Secret reference and CIDRs. For a private initial trial,
omit `-f production-values.yaml`. Read the printed Helm NOTES for current resource
names and listener ports. This image contains no shell or file utilities.

Configure each client's ID server, relay server and the public `Key:` from hbbs
logs. Never distribute the private key. `server.relayServers` accepts reachable
`host:port` entries that hbbs advertises. Empty means clients must configure their
relay endpoint explicitly. A matching public key is not per-user authorization;
configure endpoint access controls and network admission separately.

## Ports and exposure

| Listener | Default | Purpose |
| --- | --- | --- |
| TCP | 21115 | NAT test; rendezvous base minus one |
| TCP and UDP | 21116 | Native rendezvous |
| TCP | 21117 | Native relay |
| TCP, optional Service mapping | 21118 | Rendezvous WebSocket |
| TCP, optional Service mapping | 21119 | Relay WebSocket |

LoadBalancer requires provider support for mixed TCP/UDP. NodePort mappings must
match the public endpoint clients use. `externalTrafficPolicy: Local` preserves
source addresses at the Service boundary where possible; external SNAT can still
impair hole punching. The default NetworkPolicy permits same-namespace Pods only.
Set explicit `ingressFrom` peers for offices, VPNs and HTTP controllers.
See the [networking guide](docs/networking.md) for external mapping and client setup.

`websocket.enabled` adds the two WebSocket Service ports. Optional Ingress uses
distinct rendezvous and relay hostnames. `gatewayAPI.httpRoutes[]` selects `hbbs`
or `hbbr` through `component` and defaults to that component's WebSocket backend.
These HTTP routes do not expose native TCP/UDP or install a web client. Configure
TLS and long-lived connection support in the chosen controller.

## Identity, storage and availability

hbbs starts first as a native restartable init container and passes its startup
probe before hbbr launches. This prevents competing first-start key generation.
Both binaries explicitly require the same native server key using `-k _`.
Generated identity and SQLite peer associations persist together in a 1Gi RWO
PVC. Recreate updates deliberately interrupt sessions to avoid concurrent writers.
Exactly one pair is supported, including when the storage supports RWX.

Use `auth.existingSecret` for an existing matching native keypair. The Secret must
contain native base64 private/public file contents, not PEM, under the configurable
key names. The chart mounts both files read-only and keeps their contents out of
Helm values. See [identity and security](docs/security.md).

External Secrets Operator integration uses `externalSecrets.enabled`,
`refreshInterval` and `items[]` with complete per-item specs. Install the operator
and store independently, and point `auth.existingSecret` to the synchronized target.
An [ESO example](examples/external-secrets.yaml) is included. Secret changes require
Pod replacement and identity rotation requires updating clients.

The chart retains its generated PVC on uninstall by default. Existing claims are
never created or deleted by the chart. Namespace deletion can still remove data.
Use `persistence.existingClaim` to reuse a retained or restored claim. Disabling
persistence is only for disposable trials. Back up the complete stopped data
directory and any separately managed identity source; a retained PVC is not a
backup. See [backup, restore and upgrades](docs/backup-restore.md).

## Resources and operations

Each binary requests 100m CPU and 64Mi memory and has a 1 CPU/256Mi ceiling.
Size relay resources for concurrent sessions and measured network throughput.
`hbbr.totalBandwidth`, `singleBandwidth` and `limitSpeed` map to upstream limits
using units of 1024*1024 bits per second. Defaults are 1024, 128 and 32.
`server.alwaysUseRelay` forces relay use but still needs a reachable relay address.

Both containers run non-root with dropped capabilities, no privilege escalation,
read-only image filesystems and RuntimeDefault seccomp. No Kubernetes API token is
mounted. Standard scheduling, annotations, ServiceAccount and security context
overrides are available; storage permissions must match the selected identity.

TCP probes check listener health. The mandatory rendezvous startup probe also
enforces identity initialization order. Listener readiness does not prove internet
NAT, client permission or desktop consent; verify those with real endpoints.

## Validation

The chart includes template contract tests and CI profiles for defaults, custom
ports/forced relay, dual-stack Services, disposable storage, existing identity,
ESO and WebSocket routes. Its runtime client checks UDP registration and heartbeat,
TCP NAT responses, wrong-key rejection and 64KiB payloads in both relay directions.
Persistent profiles repeat checks after Pod replacement and quiesced recovery to
a fresh PVC. WebSocket profiles exercise key enforcement and binary relay traffic.

```bash
make validate-chart CHART=rustdesk-server CONTEXT=k3d-helmforge-tests-wsl
```

Run that command from the HelmForge ops repository. The full gate includes Helm
lint, all rendered CI profiles, helm-unittest, real CRD schemas, Artifact Hub lint
and behavioral k3d validation. Cloud load balancer and external TLS acceptance
remain deployment-specific. See [design decisions](DESIGN.md).

## Security Scan: `rustdesk-server`

| Framework | Score |
| --- | --- |
| MITRE + NSA + SOC2 | **100%** |

> Security posture acceptable.

Measured locally on 2026-09-14 with Kubescape 4.0.14 against the default rendered
chart: 33 controls passed, zero failed. This is a Kubernetes configuration scan,
not an application vulnerability audit or proof of internet NAT behavior.

## Values reference

<!-- VALUES_REFERENCE -->

| Parameter | Default | Description |
| --- | --- | --- |
| `nameOverride` | `""` | Override the chart name in resource names. |
| `fullnameOverride` | `""` | Override the complete resource name. |
| `replicaCount` | `1` | Exactly one coordinated rendezvous/relay pair; horizontal scaling is unsupported. |
| `commonLabels` | `{}` | Additional resource labels; selector labels cannot be overridden. |
| `podLabels` | `{}` | Additional Pod labels; selector labels cannot be overridden. |
| `podAnnotations` | `{}` | Additional Pod annotations. |
| `imagePullSecrets` | `[]` | Registry credentials for the official image. |
| `image` | `{}` | Official upstream image shared by hbbs and hbbr. |
| `image.repository` | `"docker.io/rustdesk/rustdesk-server"` | Official RustDesk Server OSS repository. |
| `image.tag` | `"1.1.16"` | Pinned stable upstream version, independent of the chart version. |
| `image.pullPolicy` | `"IfNotPresent"` | Image pull policy. |
| `server` | `{}` | Native rendezvous and relay configuration. |
| `server.relayServers` | `[]` | Client-reachable relay endpoints, including port, for example relay.example.com:21117. Empty requires clients to configure their relay explicitly. |
| `server.alwaysUseRelay` | `false` | Force relay instead of attempting peer-to-peer hole punching. |
| `server.rendezvousPort` | `21116` | Rendezvous TCP/UDP base port; NAT is base-1 and WebSocket is base+2. |
| `server.relayPort` | `21117` | Relay TCP base port; relay WebSocket is base+2. |
| `auth` | `{}` | Native server identity supplied independently of Helm release history. |
| `auth.existingSecret` | `""` | Secret containing a matching native base64 Ed25519 private/public pair. Empty generates the pair on the data volume. |
| `auth.privateKeyKey` | `"id_ed25519"` | Secret key containing the native base64 64-byte private key. |
| `auth.publicKeyKey` | `"id_ed25519.pub"` | Secret key containing the native base64 32-byte public key. |
| `externalSecrets` | `{}` | Optional External Secrets Operator integration; install the operator separately. |
| `externalSecrets.enabled` | `false` | Render ExternalSecret resources. |
| `externalSecrets.refreshInterval` | `"1h"` | Default synchronization interval. |
| `externalSecrets.items` | `[]` | Complete ExternalSecret definitions with optional name/fullnameOverride/labels/annotations and spec. |
| `websocket` | `{}` | Optional WebSocket listeners for compatible clients; no web console is included. |
| `websocket.enabled` | `false` | Expose the derived hbbs and hbbr WebSocket ports through the Service and NetworkPolicy. |
| `ingress` | `{}` | HTTP Ingress for WebSocket endpoints only. |
| `ingress.enabled` | `false` | Render one Ingress with separate rendezvous and relay hostnames. |
| `ingress.ingressClassName` | `""` | Ingress controller class; empty omits ingressClassName. |
| `ingress.annotations` | `{}` | Controller annotations, including controller-specific WebSocket timeouts. |
| `ingress.rendezvousHost` | `""` | Hostname for the hbbs WebSocket endpoint. |
| `ingress.relayHost` | `""` | Distinct hostname for the hbbr WebSocket endpoint. |
| `ingress.tls` | `[]` | Standard Ingress TLS entries. |
| `gatewayAPI` | `{}` | Gateway API HTTPRoutes for WebSocket endpoints only. |
| `gatewayAPI.enabled` | `false` | Render HTTPRoutes; requires websocket.enabled and an existing Gateway controller. |
| `gatewayAPI.httpRoutes` | `[]` | Route definitions; component is hbbs (default) or hbbr. Supports name, parentRefs, hostnames, rules, labels and annotations. |
| `hbbs` | `{}` | Rendezvous process settings. Starts before hbbr as a native sidecar. |
| `hbbs.resources` | `{}` | Resource requests and limits for rendezvous and its SQLite database. |
| `hbbs.resources.requests` | `{}` | Guaranteed scheduling resources. |
| `hbbs.resources.requests.cpu` | `"100m"` | Requested CPU. |
| `hbbs.resources.requests.memory` | `"64Mi"` | Requested memory. |
| `hbbs.resources.limits` | `{}` | Resource ceilings. |
| `hbbs.resources.limits.cpu` | `"1"` | CPU limit. |
| `hbbs.resources.limits.memory` | `"256Mi"` | Memory limit. |
| `hbbr` | `{}` | Relay process settings; bandwidth and session count drive sizing. |
| `hbbr.totalBandwidth` | `1024` | Aggregate relay bandwidth limit in upstream units of 1024*1024 bits per second. |
| `hbbr.singleBandwidth` | `128` | Per-session relay bandwidth limit in upstream Mb/s units. |
| `hbbr.limitSpeed` | `32` | Throttled/blacklisted session bandwidth in upstream Mb/s units. |
| `hbbr.resources` | `{}` | Resource requests and limits for relay traffic. |
| `hbbr.resources.requests` | `{}` | Guaranteed scheduling resources. |
| `hbbr.resources.requests.cpu` | `"100m"` | Requested CPU. |
| `hbbr.resources.requests.memory` | `"64Mi"` | Requested memory. |
| `hbbr.resources.limits` | `{}` | Resource ceilings. |
| `hbbr.resources.limits.cpu` | `"1"` | CPU limit. |
| `hbbr.resources.limits.memory` | `"256Mi"` | Memory limit. |
| `serviceAccount` | `{}` | Dedicated account; RustDesk does not call the Kubernetes API. |
| `serviceAccount.create` | `true` | Create a ServiceAccount. |
| `serviceAccount.name` | `""` | Existing account name or custom created name. |
| `serviceAccount.annotations` | `{}` | Account annotations. |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount a Kubernetes API token; unnecessary for both servers. |
| `podSecurityContext` | `{}` | Pod identity and volume ownership. |
| `podSecurityContext.runAsNonRoot` | `true` | Require non-root execution. |
| `podSecurityContext.runAsUser` | `1000` | Numeric runtime user. |
| `podSecurityContext.runAsGroup` | `1000` | Numeric primary group. |
| `podSecurityContext.fsGroup` | `1000` | Group ownership for the shared data volume. |
| `podSecurityContext.fsGroupChangePolicy` | `"OnRootMismatch"` | Avoid recursive ownership walks when the volume root already matches. |
| `podSecurityContext.seccompProfile` | `{}` | Kernel syscall filtering. |
| `podSecurityContext.seccompProfile.type` | `"RuntimeDefault"` | Use the runtime default profile. |
| `securityContext` | `{}` | Applied to both native server containers. |
| `securityContext.allowPrivilegeEscalation` | `false` | Prevent privilege escalation. |
| `securityContext.readOnlyRootFilesystem` | `true` | Application writes only into its data volume. |
| `securityContext.capabilities` | `{}` | Linux capability configuration. |
| `securityContext.capabilities.drop` | `["ALL"]` | Drop all capabilities; native ports are unprivileged. |
| `service` | `{}` | Native TCP/UDP Service. Internet access requires an appropriate external endpoint. |
| `service.type` | `"ClusterIP"` | ClusterIP, NodePort or LoadBalancer. |
| `service.annotations` | `{}` | Provider-specific annotations. |
| `service.externalTrafficPolicy` | `"Local"` | Preserve source IP for external Services; provider SNAT remains outside this setting. |
| `service.ipFamilyPolicy` | `""` | Optional IP policy: SingleStack, PreferDualStack or RequireDualStack. |
| `service.ipFamilies` | `[]` | Optional ordered IP families, for example [IPv4, IPv6]. |
| `service.loadBalancerClass` | `""` | Optional LoadBalancer implementation class, immutable once allocated. |
| `service.loadBalancerSourceRanges` | `[]` | Optional CIDRs accepted by a compatible LoadBalancer implementation. |
| `service.nodePorts` | `{}` | Explicit external node ports; zero delegates allocation to Kubernetes. |
| `service.nodePorts.nat` | `0` | NAT test TCP port. |
| `service.nodePorts.rendezvous` | `0` | Rendezvous TCP port. |
| `service.nodePorts.rendezvousUdp` | `0` | Rendezvous UDP port; normally use the same public number as TCP. |
| `service.nodePorts.relay` | `0` | Relay TCP port. |
| `service.nodePorts.rendezvousWs` | `0` | Rendezvous WebSocket TCP port when enabled. |
| `service.nodePorts.relayWs` | `0` | Relay WebSocket TCP port when enabled. |
| `persistence` | `{}` | Retain SQLite peer identities and the native Ed25519 keypair together. |
| `persistence.enabled` | `true` | Use persistent storage. Disable only for disposable trials with disposable keys. |
| `persistence.existingClaim` | `""` | Existing PVC; never created or deleted by this chart. |
| `persistence.storageClass` | `""` | StorageClass; empty uses the cluster default, '-' disables dynamic provisioning. |
| `persistence.size` | `"1Gi"` | Requested data-volume capacity. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | Volume access modes; RWX does not permit concurrent server replicas. |
| `persistence.retain` | `true` | Retain a generated PVC after Helm uninstall; namespace deletion is not protected. |
| `persistence.annotations` | `{}` | Additional PVC annotations. |
| `networkPolicy` | `{}` | Protect native listener ports with explicit client peers. |
| `networkPolicy.enabled` | `true` | Render a NetworkPolicy; enforcement requires a compatible CNI. |
| `networkPolicy.ingressFrom` | `[]` | Allowed native clients. Empty restricts to Pods in the release namespace. |
| `networkPolicy.egressIsolation` | `true` | Restrict outbound connections to DNS and explicitly configured rules. |
| `networkPolicy.dnsEgress` | `[{"namespaceSelector":{}}]` | DNS destinations on TCP/UDP 53. |
| `networkPolicy.extraEgress` | `[]` | Additional complete egress rules. |
| `probes` | `{}` | TCP probe timing. The mandatory hbbs startup probe serializes key initialization. |
| `probes.startup` | `{}` | Startup probe budget. |
| `probes.startup.periodSeconds` | `5` | Interval between attempts. |
| `probes.startup.timeoutSeconds` | `2` | Per-attempt timeout. |
| `probes.startup.failureThreshold` | `60` | Consecutive failures before restart. |
| `probes.readiness` | `{}` | Readiness probe timing for both components. |
| `probes.readiness.periodSeconds` | `5` | Interval between attempts. |
| `probes.readiness.timeoutSeconds` | `2` | Per-attempt timeout. |
| `probes.readiness.failureThreshold` | `3` | Failures before marking unready. |
| `probes.liveness` | `{}` | Liveness probes detect a stopped native listener. |
| `probes.liveness.periodSeconds` | `20` | Interval between attempts. |
| `probes.liveness.timeoutSeconds` | `2` | Per-attempt timeout. |
| `probes.liveness.failureThreshold` | `3` | Failures before restart. |
| `terminationGracePeriodSeconds` | `30` | Shutdown grace period; active remote desktop sessions are interrupted on replacement. |
| `nodeSelector` | `{}` | Node selection labels. |
| `tolerations` | `[]` | Pod tolerations. |
| `affinity` | `{}` | Pod affinity and anti-affinity. |
| `priorityClassName` | `""` | Optional workload priority. |
| `topologySpreadConstraints` | `[]` | Optional topology constraints; this does not increase replicas. |
