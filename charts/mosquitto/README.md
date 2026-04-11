# Mosquitto

A Helm chart for deploying [Eclipse Mosquitto](https://mosquitto.org/) on Kubernetes with standalone or federated broker topologies, WebSocket support, and an optional [MQTTX Web](https://hub.docker.com/r/emqx/mqttx-web) companion UI.

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

- **Official Mosquitto Image** — based on the official `eclipse-mosquitto` image
  The default chart release now uses the official non-Alpine image tag `2.0.22`.
- **Standalone or Federated Topology** — run a single broker or a bridged `StatefulSet` of brokers
- **Kubernetes Placement Defaults** — optional anti-affinity and topology spread defaults for multi-replica broker pods
- **WebSocket Listener** — browser-ready MQTT access through a dedicated listener
- **Authentication and ACL** — optional password file and ACL file generation
- **Native MQTT TLS Listener** — optional TLS/mTLS listener using an existing Kubernetes Secret
- **Broker Pressure Limits** — optional connection and queue/message size limits to reduce abuse impact
- **MQTTX Web Companion** — optional browser client deployment for quick testing
- **Service exposure** — optional `externalIPs` and static Kubernetes `nodePort` values per listener (MQTT, WebSocket, MQTTS)
- **Values Schema** — `values.schema.json` validates user-supplied values and improves ArtifactHub rendering

## Important Notes

- `architecture.mode=standalone` is the default and requires exactly one broker replica
- `architecture.mode=federated` creates 2+ Mosquitto brokers bridged together through the StatefulSet headless DNS names
- federated mode is based on Mosquitto bridges, not on native shared-state clustering
- federated brokers still do **not** share sessions or retained state like a true clustered MQTT platform
- the default Service routing uses `sessionAffinity=None` for broader compatibility; enable `ClientIP` only when sticky routing is explicitly needed
- set `service.mqttNodePort`, `service.websocketNodePort`, and `service.mqttsNodePort` to a non-zero port (typically `30000`–`32767`) to pin static NodePorts; keep them at `0` to let the cluster assign ports automatically
- `service.externalIPs` maps to `spec.externalIPs` on the broker Service for clusters that route traffic to those addresses
- federated multi-replica installs automatically prefer spreading broker pods across nodes unless you provide custom `affinity` or `topologySpreadConstraints`
- when `broker.tls.enabled=true`, set `broker.tls.certSecretName` to an existing Secret containing `tls.crt` and `tls.key` (and optionally `ca.crt` for mTLS)
- when `broker.tls.enabled=true`, the chart disables the plain MQTT `1883` listener and Service port, serving MQTT only on `broker.tls.port` (default `8883`)
- MQTTX Web upstream versioning currently requires verification against both Docker Hub and GitHub releases before pinning a strict default tag
- the official Mosquitto image tag validated for this chart is `eclipse-mosquitto:2.0.22`

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
    messageSizeLimit: 262144
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `architecture.mode` | `standalone` | Broker topology: standalone or federated |
| `broker.replicaCount` | `1` | Number of broker replicas |
| `broker.listeners.mqtt` | `1883` | MQTT TCP listener port |
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

## More Information

- [Architecture Notes](docs/architecture.md)
- [Examples](examples/federated.yaml)
- [Source code and full values reference](https://github.com/helmforgedev/charts/tree/main/charts/mosquitto)

<!-- @AI-METADATA
type: chart-readme
title: Mosquitto
description: Installation guide, values reference, and operational overview for the Mosquitto Helm chart

keywords: mosquitto, mqtt, websocket, mqttx, helm, kubernetes

purpose: User-facing chart documentation with install, examples, and values reference
scope: Chart

relations:
  - charts/mosquitto/docs/architecture.md
path: charts/mosquitto/README.md
version: 1.0
date: 2026-04-01
-->
