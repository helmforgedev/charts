# Mosquitto

A Helm chart for deploying [Eclipse Mosquitto](https://mosquitto.org/) on Kubernetes
with standalone or federated broker topologies, WebSocket support,
and an optional [MQTTX Web](https://hub.docker.com/r/emqx/mqttx-web) companion UI.

## Installation

### HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install mosquitto helmforge/mosquitto
```

### OCI Registry

```bash
helm install mosquitto oci://ghcr.io/helmforgedev/helm/mosquitto
```

## Features

- **Official Mosquitto Image** — the default uses the verified multi-architecture
  `eclipse-mosquitto:2.1.2-alpine` image.
- **Standalone or Federated Topology** — run a single broker or a bridged `StatefulSet` of brokers
- **Kubernetes Placement Defaults** — optional anti-affinity and topology spread defaults for multi-replica broker pods
- **WebSocket Listener** — browser-ready MQTT access through a dedicated listener
- **Authentication and ACL** — optional password file and ACL file generation
- **Native MQTT TLS Listener** — optional TLS/mTLS listener using an existing Kubernetes Secret
- **Broker Pressure Limits** — optional connection and queue/message size limits to reduce abuse impact
- **MQTTX Web Companion** — optional browser client deployment for quick testing
- **Secure Runtime Defaults** — non-root containers, read-only root filesystems,
  dropped capabilities, RuntimeDefault seccomp, and disabled API token mounts
- **Ingress NetworkPolicies** — listener-specific policies for broker and MQTTX pods
- **Service exposure** — optional `externalIPs` and static Kubernetes `nodePort` values per listener (MQTT, WebSocket, MQTTS)
- **Values Schema** — `values.schema.json` validates user-supplied values and improves ArtifactHub rendering

## Security Scan

### Security Scan: `mosquitto`

| Framework | Score |
| --- | --- |
| MITRE + NSA + SOC2 | **93.93939%** |

> Security posture acceptable.

## Important Notes

- `architecture.mode=standalone` is the default and requires exactly one broker replica
- `architecture.mode=federated` creates 2+ Mosquitto brokers bridged together through the StatefulSet headless DNS names
- federated mode is based on Mosquitto bridges, not on native shared-state clustering
- federated brokers still do **not** share sessions or retained state like a true clustered MQTT platform
- the default Service routing uses `sessionAffinity=None` for broader compatibility; enable `ClientIP` only when sticky routing is explicitly needed
- set `service.mqttNodePort`, `service.websocketNodePort`, and `service.mqttsNodePort` to a non-zero port
  (typically `30000`–`32767`) to pin static NodePorts; keep them at `0` to let the cluster assign ports automatically
- `service.externalIPs` maps to `spec.externalIPs` on the broker Service for clusters that route traffic to those addresses
- federated multi-replica installs automatically prefer spreading broker pods across nodes unless you provide custom `affinity` or `topologySpreadConstraints`
- when `broker.tls.enabled=true`, set `broker.tls.certSecretName` to an existing Secret containing `tls.crt` and `tls.key` (and optionally `ca.crt` for mTLS)
- when `broker.tls.enabled=true`, the chart disables the plain MQTT `1883` listener and Service port, serving MQTT only on `broker.tls.port` (default `8883`)
- MQTTX Web is pinned to `emqx/mqttx-web:v1.13.1`, and its process listener is
  controlled by `mqttxWeb.containerPort` independently from `mqttxWeb.service.port`
- the official Mosquitto image tag validated for this chart is `eclipse-mosquitto:2.1.2-alpine`
- Mosquitto 2.1 defaults `max_packet_size` to 2,000,000 bytes; set
  `broker.limits.maxPacketSize` explicitly when clients require larger packets

## Architecture

Standalone mode runs one broker with one persistent data boundary. Federated
mode runs two or more StatefulSet replicas and generates Mosquitto bridges
between their stable headless-Service names. Federation relays matching topic
traffic, but sessions, persistence, and retained state remain broker-local.
MQTTX Web is an independent Deployment that reaches the broker through its
WebSocket listener.

## Quick Start

```bash
helm install mosquitto oci://ghcr.io/helmforgedev/helm/mosquitto \
  --set auth.enabled=true \
  --set auth.password=change-me
```

## Example Configurations

### Basic Broker

```yaml
architecture:
  mode: standalone

broker:
  replicaCount: 1
```

### Federated Brokers

```yaml
architecture:
  mode: federated

broker:
  replicaCount: 3

service:
  sessionAffinity: None

pdb:
  enabled: true
  minAvailable: 2
```

### Broker with MQTTX Web

```yaml
websocketIngress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: mqtt.example.com
      paths:
        - path: /mqtt
          pathType: Prefix

mqttxWeb:
  enabled: true
  ingress:
    enabled: true
    ingressClassName: traefik
    hosts:
      - host: mqttx.example.com
        paths:
          - path: /
            pathType: Prefix
```

### NodePort with static NodePorts and external IPs

```yaml
service:
  type: NodePort
  mqttNodePort: 31883
  websocketNodePort: 31901
  externalIPs:
    - 203.0.113.10
```

When `broker.tls.enabled=true`, use `service.mqttsNodePort` instead of `mqttNodePort` for the TLS listener.

### Public Broker with MQTT TLS

```yaml
service:
  type: LoadBalancer

auth:
  enabled: true

acl:
  enabled: true

broker:
  tls:
    enabled: true
    certSecretName: mosquitto-tls
    port: 8883
  limits:
    maxConnections: 10000
    maxInflightMessages: 100
    maxQueuedMessages: 1000
    maxQueuedBytes: 1048576
    maxPacketSize: 262144
```

### Eliminating TLS health check log spam (OpenSSL EOF)

When `broker.tls.enabled` is true and `broker.listeners.websocketEnabled` is false, Kubernetes TCP socket health probes and/or a Cloud Load Balancer health checks (e.g., AWS NLB) will ping the
`mqtts` port. Because the probes immediately close the connection without completing a TLS handshake, Mosquitto will constantly log OpenSSL errors
(e.g., `error:0A000126:SSL routines::unexpected eof while reading`).

To eliminate this log spam, you can use `broker.extraConfig` to create a dedicated, plaintext health check listener, and use `broker.probePortOverride` to point the Kubernetes probes to it.

```yaml
broker:
  # Point health probes/checks to the custom plaintext port
  probePortOverride: 9000

  extraConfig: |
    # Create a dedicated plaintext listener for health checks
    listener 9000
    protocol mqtt

    # Silence the TCP connection logs
    connection_messages false
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `architecture.mode` | `standalone` | Broker topology: standalone or federated |
| `broker.replicaCount` | `1` | Number of broker replicas |
| `broker.listeners.mqtt` | `1883` | MQTT TCP listener port |
| `broker.listeners.websocketEnabled` | `true` | Enable MQTT over WebSocket listener |
| `broker.listeners.websocket` | `9001` | MQTT over WebSocket listener port |
| `broker.tls.enabled` | `false` | Enable broker MQTT TLS listener and disable plain MQTT `1883` |
| `broker.tls.certSecretName` | `""` | Secret containing `tls.crt` and `tls.key` |
| `broker.limits.maxConnections` | `0` | Maximum simultaneously connected clients (`0` keeps broker default) |
| `broker.limits.maxPacketSize` | `0` | Maximum accepted MQTT packet size in bytes (`0` keeps broker default) |
| `broker.federation.topicPattern` | `#` | Topic pattern bridged between federated brokers |
| `auth.enabled` | `false` | Enable username/password authentication |
| `acl.enabled` | `false` | Enable ACL file generation |
| `service.type` | `ClusterIP` | Service type: `ClusterIP`, `NodePort`, or `LoadBalancer` |
| `service.sessionAffinity` | `None` | Service routing policy for client traffic |
| `service.mqttPort` | `1883` | Service port for plain MQTT (when TLS is disabled) |
| `service.websocketPort` | `9001` | Service port for WebSocket |
| `service.mqttsPort` | `8883` | Service port for MQTT TLS (when TLS is enabled) |
| `service.mqttNodePort` | `0` | Static NodePort for MQTT; `0` omits the field (auto-assigned when using NodePort/LoadBalancer) |
| `service.websocketNodePort` | `0` | Static NodePort for WebSocket |
| `service.mqttsNodePort` | `0` | Static NodePort for MQTTS (TLS) |
| `service.externalIPs` | `[]` | Optional `spec.externalIPs` entries for the broker Service |
| `service.externalTrafficPolicy` | `Cluster` | Used when `service.type` is `NodePort` or `LoadBalancer` |
| `websocketIngress.enabled` | `false` | Expose broker WebSocket through ingress |
| `mqttxWeb.enabled` | `false` | Deploy MQTTX Web companion UI |
| `mqttxWeb.containerPort` | `8080` | Listener passed to the MQTTX Web `http-server` process |
| `mqttxWeb.service.port` | `80` | Independent Kubernetes Service port for MQTTX Web |
| `networkPolicy.enabled` | `true` | Restrict ingress to declared broker and MQTTX listeners |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount the Kubernetes API token into pods |

## Security

The chart applies a restricted container baseline by default, but the default
broker permits anonymous clients for evaluation. Before public exposure, enable
authentication, least-privilege ACL rules, TLS or mTLS, and explicit resource
and broker pressure limits. See [Security](docs/security.md) for the trust
boundaries and a production checklist.

## Troubleshooting

Use the commands printed by `helm get notes` to inspect pods, generated broker
configuration, and logs. Listener failures usually indicate a port collision or
TLS Secret mismatch. Authentication failures should be checked against the
effective Secret keys and ACL rules. Federation problems should be diagnosed
per broker because bridge connectivity and retained state are broker-local.
See [Operations](docs/operations.md) for upgrade, backup, and recovery guidance.

## More Information

- [Architecture Notes](docs/architecture.md)
- [Security](docs/security.md)
- [Operations](docs/operations.md)
- [Examples](examples/federated.yaml)
- [Source code and full values reference](https://github.com/helmforgedev/charts/tree/main/charts/mosquitto)
