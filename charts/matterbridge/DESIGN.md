# Matterbridge chart design

## Goals

This chart packages the official Matterbridge image as a stable, single-node
Kubernetes workload. It prioritizes a safe install, durable Matter identity,
clear LAN networking choices and direct compatibility with upstream behavior.

## Workload model

Matterbridge stores fabric identity, certificates, plugin packages and runtime
configuration on disk. It also owns fixed Matter ports and advertises a single
mDNS identity. The chart therefore uses a StatefulSet with exactly one replica,
`OrderedReady` pod management and one persistent volume. Horizontal scaling and
active-active failover are intentionally rejected.

The official image normally starts through a root-oriented entrypoint. The chart
calls the `matterbridge` executable directly and places its home under `/data`.
This permits UID/GID 1000, a read-only image filesystem and a private writable
npm prefix without modifying or replacing the official image.

## Storage model

One PVC is mounted at `/data`. The upstream `--homedir /data` option consolidates
plugins, Matter state and certificates into `/data/Matterbridge`,
`/data/.matterbridge` and `/data/.mattercert`. A single mount avoids partial
backups and the shared-PVC deadlocks caused by multiple claims waiting for the
same `WaitForFirstConsumer` pod.

The PVC has Helm's `keep` annotation by default. Backups are storage-platform
snapshots or filesystem copies taken while the StatefulSet is stopped. The chart
does not invent an unsafe live-copy sidecar or application API.

## Network model

The portable default uses pod networking so it passes Pod Security baseline and
works in ordinary clusters for frontend evaluation. Matter commissioning on a
physical LAN generally requires multicast DNS, IPv6 link reachability and direct
TCP/UDP Matter ports, which commonly requires `network.hostNetwork=true`.

Host networking is opt-in because Kubernetes Pod Security baseline forbids it.
Operators must schedule the singleton to a trusted LAN-connected node. Advanced
CNIs may instead transport multicast and use the optional Matter Service port
range. A Service never substitutes for mDNS.

Ingress and Gateway API HTTPRoutes target only the management frontend. They do
not proxy Matter or multicast traffic.

## Security model

The default pod is non-root, drops every Linux capability, prevents privilege
escalation, uses RuntimeDefault seccomp, has a read-only root filesystem and does
not mount a Kubernetes API token. Writable paths are limited to `/data` and
`/tmp`.

The frontend is private by default. Authentication is delegated to a trusted
reverse proxy because Matterbridge does not expose a stable chart-manageable
authentication contract. TLS can be terminated at Ingress/Gateway or supplied
to Matterbridge through an existing Secret.

## Deliberate omissions

- No HPA or replica scaling: upstream is a singleton.
- No PodDisruptionBudget: it cannot create availability from one replica and can
  block voluntary maintenance.
- No ServiceMonitor: upstream has no native Prometheus endpoint.
- No automated plugin mutation: plugins are managed through the upstream UI/CLI
  and persisted on the PVC.
- No live backup CronJob: consistent backup requires a stopped application or a
  storage-native snapshot.
