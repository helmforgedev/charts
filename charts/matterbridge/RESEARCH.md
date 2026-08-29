# Matterbridge Chart Research

**Chart request:** helmforgedev/charts#1077
**Requester:** drieks
**Upstream:** [Matterbridge on GitHub](https://github.com/Luligu/matterbridge)
**Research date:** 2026-08-29

## Product and Runtime

Matterbridge is an Apache-2.0 Matter plugin manager. It exposes devices from
platforms such as Zigbee2MQTT, MQTT, Home Assistant, Homebridge and Shelly to
Matter controllers including Apple Home, Google Home and Amazon Alexa.

The stable upstream release selected for this chart is `3.10.7`, published on
2026-08-28. The official pinned image is
`docker.io/luligu/matterbridge:3.10.7`. HelmForge manifest verification
confirmed `linux/amd64` and `linux/arm64` support. The manifest digest observed
during implementation was
`sha256:568d9fae6342aadbd62aa72560b6e6c070c33b1c0c5224fe2925a28c1cb4ebc6`.

The image is based on `node:24-trixie-slim`, runs as root, starts
`matterbridge --docker`, and includes the `mb_health` binary. Its Docker
healthcheck calls the HTTP health endpoint at `http://localhost:8283/health`.

## Network Model

Matterbridge uses three different network surfaces:

1. The management frontend listens on TCP port `8283` by default.
2. Matter nodes use UDP starting at port `5540`; child bridges can consume a
   range such as `5540-5559`.
3. Discovery relies on multicast DNS and routable LAN IPv6.

The official Docker instructions require host networking on Linux because
ordinary bridge/NAT networking does not reliably transport multicast or
advertise addresses reachable by Matter controllers. Kubernetes Pod Security
baseline forbids host namespaces, so the chart keeps pod networking as its
installable default and exposes `network.hostNetwork: true` as the documented
production/LAN setting. A pod-network deployment requires a suitable multicast
CNI, reflector or L2 integration. Ingress and Gateway API expose only the web
UI; they cannot carry Matter UDP or mDNS traffic.

## Persistent State

Upstream persists three coupled state domains:

- `/root/Matterbridge`: installed plugins and plugin assets;
- `/root/.matterbridge`: application configuration and operational state;
- `/root/.mattercert`: Matter fabrics, certificates and commissioning data.

Loss of the certificate or fabric state can require devices to be paired
again. The chart therefore enables persistence by default and uses the
official `--homedir /data` option to place all three directories on one PVC.
This produces one atomic storage boundary, avoids three-claim coordination,
and makes snapshot/restore procedures less error-prone. The PVC is retained on
uninstall by default.

## Existing Deployment Options

### Official Docker and Compose

Strengths:

- canonical image and lifecycle;
- host networking and 60-second stop grace period;
- explicit mounts for all durable state;
- built-in health command.

Limitations:

- floating `latest` tag in examples;
- no Kubernetes scheduling, probes, Service, TLS ingress or schema validation;
- operators must coordinate the three mounts and backups themselves.

### Official Home Assistant Application

Strengths:

- convenient installation for Home Assistant OS users;
- supervised lifecycle and persistent add-on storage.

Limitations:

- coupled to the Home Assistant Supervisor;
- not a general-purpose Kubernetes deployment;
- uses a specialized s6-rc image rather than the standard runtime.

### Community Kubernetes and Helm Options

No maintained Matterbridge-specific Helm chart or upstream Kubernetes
manifest was identified. Generic application charts can run the image but do
not model Matter networking, the coupled storage domains, singleton upgrades,
or commissioning data safety.

## Production Requirements

### Singleton Lifecycle

Matterbridge is stateful and binds node-local frontend/Matter ports when host
networking is enabled. Multiple replicas would compete for ports, storage
locks and Matter identity. The chart must render exactly one StatefulSet
replica. Ordered singleton replacement prevents an upgrade from overlapping
old and new pods.

### Shutdown and Probes

Upstream uses a 60-second Docker stop timeout. Kubernetes must provide at least
the same termination grace period. Startup can be slow while plugins are
restored or installed, so the startup probe must be substantially more
tolerant than readiness and liveness probes. All probes should use the
official `/health` endpoint.

### Security

The image entrypoint runs as root and stores data below `/root` by default.
Matterbridge also officially supports `--homedir`, and the image contains the
`node` user at UID/GID 1000. A direct runtime test proved that overriding the
entrypoint with `matterbridge`, setting `--homedir /data`, and using UID/GID
1000 works with a read-only root filesystem, all capabilities dropped and
`/tmp` on an `emptyDir`. The chart uses that hardened path and stores the
private npm prefix/cache on the persistent volume for non-root plugin installs.

The frontend should normally remain on a private network or behind an
authenticated proxy. Ingress/Gateway TLS protects transport but does not turn
the Matterbridge frontend into a hardened internet-facing control plane.

### Observability

Matterbridge exposes health and structured application logs but no native
Prometheus metrics endpoint. A ServiceMonitor would be misleading, so the
chart intentionally provides probes and pod annotations without inventing
metrics. Users can integrate log collectors through standard pod annotations
or extra containers.

### Backup and Restore

Upstream provides logical backup through its UI. Kubernetes operators can also
snapshot the single PVC. Crash-consistent storage snapshots are possible, but
the safest backup and restore occurs while Matterbridge is stopped. The chart
does not invent an unsupported scheduled backup format.

## HelmForge Differentiation

| Capability | Docker/Compose | Generic chart | HelmForge chart |
|---|---:|---:|---:|
| Stable pinned official image | No | Optional | Yes |
| Explicit mDNS-ready LAN mode | Yes | No | Yes, opt-in host networking |
| Portable pod-network mode | Manual | Generic | Documented and tested |
| Atomic three-directory persistence | Manual | No | Yes |
| PVC retained on uninstall | N/A | Optional | Default |
| Singleton-safe upgrade | Restart | Usually rolling | Ordered singleton |
| Official health probes | Docker only | Generic | Startup/readiness/liveness |
| Ingress and Gateway API for UI | No | Generic | Yes, with scope clarified |
| Dual-stack Service controls | No | Optional | Yes |
| ExternalSecret adapter | No | Optional | Canonical items contract |
| Schema and fail-fast validation | No | Limited | Complete |
| Operational docs and examples | Basic | Varies | Product-specific |

## High-Impact Differentiators

1. **Matter-correct networking:** one explicit switch enables the upstream
   host-network topology, while the baseline-compatible default explains the
   multicast and IPv6 responsibilities.
2. **Atomic durable state:** one retained PVC protects plugins, configuration,
   fabrics and certificates together.
3. **Safe lifecycle:** singleton validation, ordered upgrades, official health
   probes and the upstream 60-second shutdown window prevent common failures.
4. **Honest exposure model:** Service, Ingress and HTTPRoute simplify UI access
   without implying they transport Matter or mDNS.
5. **Escape hatches without clutter:** extra environment sources, volumes,
   mounts, containers and manifests support plugin-specific integrations while
   keeping the default contract small.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| CNI does not carry mDNS | Pairing/discovery fails | Opt-in host-network mode and dedicated networking guide |
| Host ports collide | Pod cannot start | Singleton validation and scheduling docs |
| PVC lost | Re-pairing may be required | Retain policy, atomic PVC and backup guide |
| Plugin first boot is slow | False liveness failures | Generous startup probe |
| Root runtime | Reduced hardening | Drop capabilities, no privilege escalation, no API token |
| UI exposed publicly | Control-plane risk | Private-access guidance and proxy/TLS documentation |

## Recommendation

Implement the chart as a stable `1.0.0` release. Matterbridge is already a
stable production application, the official image is multi-architecture, and
the Kubernetes limitations are understood and can be made explicit. Do not
represent horizontal scaling, Prometheus metrics or automatic multicast
reflection as supported features.

## Primary Sources

- [Matterbridge repository](https://github.com/Luligu/matterbridge)
- [Matterbridge 3.10.7 release](https://github.com/Luligu/matterbridge/releases/tag/3.10.7)
- [Official Docker documentation](https://github.com/Luligu/matterbridge/blob/main/README-DOCKER.md)
- [Official Docker Compose file](https://github.com/Luligu/matterbridge/blob/main/docker/docker-compose.yml)
- [Official health check source](https://github.com/Luligu/matterbridge/blob/main/packages/core/src/mb_health.ts)
- [Matterbridge website](https://matterbridge.io)
