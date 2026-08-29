# Matterbridge

A production-ready Helm chart for [Matterbridge](https://matterbridge.io), the
official Matter plugin manager that bridges existing home-automation platforms
and devices into Matter ecosystems.

This chart uses the official `luligu/matterbridge` image, preserves the complete
Matter identity on one PVC and runs the application as a hardened non-root
singleton. It supports a portable pod-network default and an explicit LAN mode
for reliable mDNS, IPv6 and Matter commissioning.

## Installation

### OCI registry

```bash
helm install matterbridge oci://ghcr.io/helmforgedev/helm/matterbridge
```

### HTTPS repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install matterbridge helmforge/matterbridge
```

The default installation is deliberately private and uses pod networking. Open
the frontend for evaluation:

```bash
kubectl port-forward svc/matterbridge 8283:8283
```

Then visit `http://localhost:8283`.

## Production quick start

Normal Matter commissioning on a home or building LAN needs mDNS multicast,
IPv6 reachability and direct Matter ports. Most Kubernetes CNIs do not transport
those protocols between the pod network and the physical LAN. For that common
case, label one trusted LAN-connected node and enable host networking:

```bash
kubectl label node my-lan-node matterbridge.helmforge.dev/lan-node=true
helm upgrade --install matterbridge \
  oci://ghcr.io/helmforgedev/helm/matterbridge \
  --set network.hostNetwork=true \
  --set nodeSelector.matterbridge\.helmforge\.dev/lan-node=true
```

Host networking is opt-in because Kubernetes Pod Security baseline rejects it.
Only use it on a trusted node and protect the administrative frontend.

## Features

- Official, pinned multi-architecture Matterbridge image
- Stable chart version `1.0.0` with upstream Matterbridge `3.10.7`
- StatefulSet singleton with explicit validation against unsafe scaling
- One retained PVC for plugins, fabrics, certificates and configuration
- Non-root UID/GID 1000, read-only root filesystem and all capabilities dropped
- RuntimeDefault seccomp and no mounted Kubernetes API token
- Official `/health` startup, readiness and liveness probes
- Portable pod-network default compatible with Pod Security baseline
- Opt-in host networking for practical LAN mDNS, IPv6 and Matter support
- Optional TCP/UDP Matter port-range Service for multicast-aware CNIs
- Dual-stack Service configuration
- Ingress and Gateway API frontend exposure
- Generic External Secrets Operator resources for TLS and plugin credentials
- Optional NetworkPolicy for pod-network deployments
- Existing PVC, extra volumes, sidecars, init containers and manifests
- Graceful 60-second shutdown for storage and Matter session cleanup

### 🟢 Security Scan: `matterbridge`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **93.93939%** |

> ✅ Security posture acceptable.

The two medium findings are the intentionally optional NetworkPolicy controls.
The default workload passes non-root, immutable filesystem, capability,
privilege-escalation, seccomp, service-account and resource-limit controls. The
production host-network option remains a documented networking exception
required by common Matter LAN deployments.

## Architecture

Matterbridge is stateful and has no active-active clustering or leader election.
Multiple replicas would contend for the same fabric identity, plugin files,
mDNS identity and Matter ports. The chart always renders one StatefulSet replica
and rejects any `replicaCount` other than `1`.

The chart bypasses the root-oriented image entrypoint and starts the official
`matterbridge` binary directly with `--homedir /data`. This keeps all mutable
state below the PVC while the image filesystem remains read-only.

## Network modes

### Portable pod network

This is the default:

```yaml
network:
  hostNetwork: false
```

It is the safest and most portable Kubernetes configuration. The frontend,
health checks and plugin management work. Matter commissioning works only when
the CNI and LAN design provide multicast DNS and IPv6 reachability.

### Typical LAN production mode

```yaml
network:
  hostNetwork: true

nodeSelector:
  matterbridge.helmforge.dev/lan-node: "true"
```

Matterbridge uses the node interfaces directly. The chart selects
`ClusterFirstWithHostNet` DNS unless `network.dnsPolicy` is explicitly set.

### Advanced Service mode

For a CNI that already transports mDNS and IPv6 correctly:

```yaml
matterService:
  enabled: true
  type: LoadBalancer
  externalTrafficPolicy: Local
```

This publishes TCP and UDP for every port from `matterbridge.matterPort` through
the configured `matterPortRangeSize`. It does not relay UDP 5353 multicast and
cannot make a multicast-incapable CNI work.

See [docs/networking.md](docs/networking.md) for topology and troubleshooting.

## Persistence

The PVC is mounted at `/data`. Upstream then stores:

- plugins under `/data/Matterbridge`;
- configuration, logs and Matter storage under `/data/.matterbridge`;
- Matter certificates under `/data/.mattercert`;
- the private npm prefix and cache below `/data`.

The chart creates a 2 GiB ReadWriteOnce PVC and annotates it with
`helm.sh/resource-policy: keep` by default. To reuse an existing claim:

```yaml
persistence:
  enabled: true
  existingClaim: matterbridge-data
```

Back up the whole volume consistently while the StatefulSet is stopped. Partial
restores can invalidate the Matter fabric identity. See
[docs/persistence-backup.md](docs/persistence-backup.md).

## Plugins and credentials

Install and manage Matterbridge plugins through the upstream frontend. Installed
packages survive restarts on the PVC. Plugins can require LAN, MQTT or cloud
connections; size resources and NetworkPolicy egress for the selected plugins.

Pass credentials from Kubernetes Secrets without writing them into values:

```yaml
extraEnvFrom:
  - secretRef:
      name: matterbridge-plugin
```

The chart can create generic `external-secrets.io/v1` ExternalSecrets:

```yaml
externalSecrets:
  enabled: true
  items:
    - name: plugin
      spec:
        secretStoreRef:
          name: production-secrets
          kind: ClusterSecretStore
        target:
          name: matterbridge-plugin
        data:
          - secretKey: token
            remoteRef:
              key: matterbridge/plugin
              property: token
```

No credential environment variable is invented by the chart; map Secrets using
the contract documented by each plugin.

## Frontend exposure

The default ClusterIP is private. Matterbridge does not expose a stable
chart-managed authentication contract, so an exposed frontend should use TLS,
authentication and client restrictions at a trusted proxy.

Ingress example:

```yaml
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: matterbridge.example.com
      paths:
        - path: /
          pathType: Prefix
```

Gateway API example:

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - name: frontend
      parentRefs:
        - name: shared-gateway
          namespace: gateway-system
          sectionName: https
      hostnames:
        - matterbridge.example.com
```

These HTTP resources expose only the frontend. Matter and mDNS traffic never
traverse an Ingress or HTTPRoute.

## Native frontend TLS

Matterbridge can serve HTTPS from an existing Secret:

```yaml
frontend:
  tls:
    enabled: true
    existingSecret: matterbridge-frontend-tls
```

The Secret must contain `cert.pem` and `key.pem`; `ca.pem` is optional. It is
mounted read-only into `/data/.matterbridge/certs`. Prefer proxy TLS when your
Ingress or Gateway already manages certificates.

## NetworkPolicy

NetworkPolicy is optional and only valid with `network.hostNetwork=false`.
Host-network policy behavior varies by CNI, so the chart rejects that ambiguous
combination.

By default the policy permits frontend ingress from all namespaces. Egress is
not restricted unless enabled because plugin destinations are deployment
specific. A restrictive example:

```yaml
networkPolicy:
  enabled: true
  ingressFrom:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-system
  egress:
    enabled: true
    allowDNS: true
    extraEgress:
      - to:
          - ipBlock:
              cidr: 192.0.2.10/32
        ports:
          - protocol: TCP
            port: 1883
```

## Health and operations

The official `/health` endpoint drives all three HTTP probes. Startup allows up
to five minutes for first boot, storage restoration and plugin initialization.
Liveness follows the conservative upstream health-check cadence.

```bash
kubectl get pod matterbridge-0
kubectl logs matterbridge-0 --follow
kubectl get events --sort-by=.lastTimestamp
```

Do not publish commissioning codes from logs. They grant access to an
uncommissioned Matter bridge.

## Upgrades

Before upgrading:

1. Read upstream Matterbridge release notes.
2. Take and verify a consistent PVC backup.
3. Confirm installed plugin compatibility.
4. Keep the singleton on the same LAN topology.

After upgrading, wait for readiness, inspect startup logs and test a bridged
device. Application migrations may make a chart-only rollback insufficient, so
restore chart and volume state together when necessary.

## Uninstall

```bash
helm uninstall matterbridge
```

The chart-created PVC remains by default. Delete it only after verifying a
backup and accepting that Matter commissioning and plugin state will be lost.

## Examples

- [Simple portable installation](examples/simple.yaml)
- [Typical production LAN installation](examples/production.yaml)
- [Advanced portable networking](examples/portable-networking.yaml)
- [Ingress](examples/ingress.yaml)
- [Gateway API](examples/gateway-api.yaml)
- [External Secret](examples/external-secret.yaml)

## Values

See [values.yaml](values.yaml) for the complete documented contract and
[values.schema.json](values.schema.json) for validation. Important groups are:

| Group | Purpose |
|---|---|
| `matterbridge` | Runtime mode, ports, interface selection and logging |
| `frontend` | HTTP port, bind address and native TLS |
| `network` | Pod or host network behavior |
| `service` | Frontend Service and dual-stack policy |
| `matterService` | Optional TCP/UDP Matter range publishing |
| `persistence` | PVC creation, retention and existing claims |
| `ingress` | Frontend Ingress |
| `gatewayAPI` | Frontend HTTPRoutes |
| `externalSecrets` | Generic ExternalSecret resources |
| `networkPolicy` | Pod-network ingress and optional egress controls |

## Support

Chart issues belong in the
[HelmForge charts repository](https://github.com/helmforgedev/charts/issues).
Application and plugin behavior belongs in the
[Matterbridge repository](https://github.com/Luligu/matterbridge/issues).

Matterbridge is a trademark and project of its upstream maintainers. HelmForge
is not affiliated with or endorsed by Matterbridge.
