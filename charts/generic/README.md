# Generic Helm Chart

A single chart that handles **Deployments**, **StatefulSets**, **DaemonSets**, **Jobs**, and **CronJobs** with a unified values interface. Designed for teams that deploy many services and want one chart to rule them all.

## Install

### HTTPS repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install my-release helmforge/generic -f values.yaml
```

### OCI registry

```bash
helm install my-release oci://ghcr.io/helmforgedev/helm/generic -f values.yaml
```

## Workload Types

Only one workload type is active at a time, controlled by `workload.type`:

```yaml
workload:
  enabled: true          # false for Jobs/CronJobs-only releases
  type: Deployment       # Deployment | StatefulSet | DaemonSet
```

Read before choosing a mode:

- [Deployment](docs/deployment.md)
- [StatefulSet](docs/statefulset.md)
- [DaemonSet](docs/daemonset.md)
- [Batch Jobs and CronJobs](docs/batch.md)

<details>
<summary><b>Deployment</b> (default)</summary>

```yaml
workload:
  enabled: true
  type: Deployment

image:
  repository: myapp
  tag: "1.0.0"

containers:
  - name: app
    ports:
      - containerPort: 3000

service:
  port: 3000
  targetPort: 3000

ingress:
  enabled: true
  ingressClassName: traefik
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  hosts:
    - host: app.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - app.example.com
      secretName: app-tls
```
</details>

## How to choose the right mode

- use `Deployment` for stateless APIs, web apps, workers behind a service, and most standard applications
- use `StatefulSet` when pod identity, ordered rollout, or persistent storage per replica matters
- use `DaemonSet` when exactly one pod per node is the intended operating model
- use Jobs or CronJobs when the release is batch-oriented and should not keep a long-running workload alive

The generic chart is most useful when your team wants one operational contract for many internal services. It is not the right choice when a product has its own topology, bootstrap flow, or domain-specific configuration model that deserves a dedicated chart.

<details>
<summary><b>StatefulSet</b></summary>

```yaml
workload:
  enabled: true
  type: StatefulSet
  podManagementPolicy: Parallel
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: standard
        resources:
          requests:
            storage: 10Gi
```
</details>

<details>
<summary><b>DaemonSet</b></summary>

```yaml
workload:
  enabled: true
  type: DaemonSet
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1

tolerations:
  - operator: Exists
```
</details>

<details>
<summary><b>Jobs / CronJobs only</b> (no long-running workload)</summary>

```yaml
workload:
  enabled: false

jobs:
  - name: db-migrate
    command: ["npm", "run", "migrate"]
    backoffLimit: 3

cronjobs:
  - name: cleanup
    schedule: "0 2 * * *"
    command: ["npm", "run", "cleanup"]
```
</details>

## Key Features

### Multi-container pods

```yaml
containers:
  - name: api
    ports:
      - containerPort: 3000
  - name: sidecar
    image:
      repository: envoyproxy/envoy
      tag: "v1.31"
    ports:
      - containerPort: 9901
```

### Global and per-container environment

```yaml
# Applied to ALL containers
env:
  - name: NODE_ENV
    value: "production"

envFrom:
  - secretRef:
      name: app-secrets

# Per-container override
containers:
  - name: app
    env:
      - name: PORT
        value: "3000"
    envFrom:
      - configMapRef:
          name: app-config
```

### Init containers

```yaml
initContainers:
  - name: wait-for-db
    image:
      repository: busybox
      tag: "1.36"
    command: ["sh", "-c", "until nc -z db 5432; do sleep 1; done"]
```

### Probes

Global probes apply to the **first container** only. Each container can override with its own:

```yaml
# Global (first container)
livenessProbe:
  httpGet:
    path: /health
    port: 3000

# Per-container override
containers:
  - name: app
    readinessProbe:
      httpGet:
        path: /ready
        port: 3000
```

Jobs and CronJobs never inherit global probes.

### Extra manifests

Inject any Kubernetes resource via values, with full Helm templating support:

```yaml
extraManifests:
  - apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: '{{ include "chart.fullname" . }}-deny-all'
    spec:
      podSelector:
        matchLabels:
          app.kubernetes.io/name: '{{ include "chart.name" . }}'
      policyTypes: [Ingress, Egress]
```

### Explicit rollouts

The chart does not add time-based pod annotations during normal renders. To intentionally roll long-running workloads, set:

```yaml
rollout:
  restartAt: "2026-04-27T00:00:00Z"
  podAnnotations:
    app.example.com/restarted-by: platform
  checksum:
    enabled: true
    configMaps: true
    secrets: true
```

### Platform integrations

The chart now includes opt-in primitives for common platform needs:

- `secrets[]`, `externalSecrets`, and `sealedSecrets` for secret integration. ExternalSecret, SealedSecret, ServiceMonitor, PodMonitor, PrometheusRule, KEDA, VPA, and Gateway API resources require their CRDs to exist before enabling them.
- `rbac.create` and `networkPolicy.enabled` for least-privilege identity and traffic policy.
- `securityPreset: baseline` or `restricted` for opt-in security contexts when explicit contexts are not set.
- `services[]`, `service.headless`, `service.nameOverride`, per-port `appProtocol`, and custom Ingress backends for richer networking.
- `podMonitor`, `prometheusRule`, advanced HPA metrics, and optional KEDA ScaledObject/ScaledJob support.
- `persistence.persistentVolumeClaims[]` and explicit opt-in `persistence.persistentVolumes[]` for clearer storage ownership.

### Breaking-change migration notes

- The default image is now pinned to `docker.io/library/nginx:1.27.5` with `IfNotPresent` instead of relying on `latest`.
- Pod templates are deterministic; use `rollout.restartAt` or checksum-enabled ConfigMaps/Secrets for intentional rollouts.
- HPA now fails validation when used with `DaemonSet` or when `hpa.maxReplicas` is missing.
- `pdb.enabled` requires exactly one of `pdb.minAvailable` or `pdb.maxUnavailable`.
- Optional CRD-backed resources are disabled by default and must only be enabled in clusters where the corresponding operator/API is installed.

## Operational guidance

### When this chart fits well

- internal platforms that deploy many services with the same operational contract
- teams that want a single chart for stateless services, workers, scheduled tasks, and simple stateful apps
- cases where the application contract is generic enough to be described by workload, containers, service, ingress, scaling, and persistence primitives

### When this chart is the wrong tool

- databases and middleware with their own topology and bootstrap semantics
- applications that require custom initialization controllers, cluster formation, or product-specific CRDs
- products whose values contract should reflect domain concepts instead of generic Kubernetes objects

### Recommended practices

- keep `containers` explicit and small; avoid turning one release into a large bundle of unrelated sidecars
- define probes per container when more than one container is user-facing
- enable `pdb`, `hpa`, and `topologySpreadConstraints` for production deployments that need resilience
- prefer chart examples and `ci/` scenarios as the starting point for new workloads

## Examples

See the [examples/](examples/) directory for complete, ready-to-use values files:

| Example | Description |
|---------|-------------|
| [web-app.yaml](examples/web-app.yaml) | Node.js/Python web app with Ingress, HPA, probes |
| [api-with-sidecar.yaml](examples/api-with-sidecar.yaml) | API server with Envoy sidecar proxy |
| [worker.yaml](examples/worker.yaml) | Background worker without Service/Ingress |
| [statefulset-database.yaml](examples/statefulset-database.yaml) | StatefulSet with persistent storage |
| [cronjob-batch.yaml](examples/cronjob-batch.yaml) | Batch processing with CronJobs |

## Usage Guides

- [`docs/deployment.md`](docs/deployment.md) — stateless services, APIs, ingress, and autoscaling
- [`docs/statefulset.md`](docs/statefulset.md) — stable identity, persistent storage, and rollout expectations
- [`docs/daemonset.md`](docs/daemonset.md) — node-level agents and one-pod-per-node behavior
- [`docs/batch.md`](docs/batch.md) — one-off jobs and scheduled workloads
- [`docs/security.md`](docs/security.md) — ServiceAccount, Secrets, RBAC, and NetworkPolicy
- [`docs/observability.md`](docs/observability.md) — ServiceMonitor, PodMonitor, PrometheusRule, VPA, HPA, and KEDA
- [`docs/gateway.md`](docs/gateway.md) — Gateway API HTTPRoute patterns
- [`docs/storage.md`](docs/storage.md) — PVC/PV ownership and StatefulSet storage patterns

## Values Reference

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Pod replicas (ignored with HPA/DaemonSet) | `1` |
| `nameOverride` | Override release name | `""` |
| `fullnameOverride` | Override fully qualified name | `""` |
| `commonLabels` | Labels added to all resources | `{}` |
| **Workload** | | |
| `workload.enabled` | Enable long-running workload | `true` |
| `workload.type` | `Deployment` / `StatefulSet` / `DaemonSet` | `Deployment` |
| `workload.podManagementPolicy` | StatefulSet pod management | — |
| `workload.volumeClaimTemplates` | StatefulSet PVC templates | `[]` |
| `workload.updateStrategy` | StatefulSet/DaemonSet update strategy | — |
| **Image** | | |
| `global.imageRegistry` | Optional registry prefix for unqualified repositories | `""` |
| `image.repository` | Container image repository | `docker.io/library/nginx` |
| `image.tag` | Image tag | `1.27.5` |
| `image.digest` | Image digest, takes precedence over tag | `""` |
| `image.pullPolicy` | Pull policy | `IfNotPresent` |
| `imagePullSecrets` | Registry pull secrets | `[]` |
| **Containers** | | |
| `containers` | List of container specs | 1 container on port 80 |
| `initContainers` | Init container specs | `[]` |
| **Environment** | | |
| `env` | Global env vars for all containers | `[]` |
| `envFrom` | Global envFrom for all containers | `[]` |
| **Service Account** | | |
| `serviceAccount.create` | Create a ServiceAccount | `false` |
| `serviceAccount.name` | ServiceAccount name | `""` |
| `serviceAccount.annotations` | ServiceAccount annotations | `{}` |
| `serviceAccount.automountServiceAccountToken` | Mount API token into pods | `false` |
| **Resources & Probes** | | |
| `resources` | Default resource limits/requests | `{}` |
| `livenessProbe` | Global liveness probe (first container) | `{}` |
| `readinessProbe` | Global readiness probe (first container) | `{}` |
| `startupProbe` | Global startup probe (first container) | `{}` |
| **Security** | | |
| `podSecurityContext` | Pod-level security context | `{}` |
| `securityContext` | Container-level security context | `{}` |
| `securityPreset` | Optional `baseline` or `restricted` preset when explicit contexts are absent | `""` |
| **Networking** | | |
| `service.enabled` | Create the default Service for long-running workloads | `true` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `80` |
| `service.targetPort` | Target port | `80` |
| `service.nameOverride` | Override primary Service name | `""` |
| `service.headless.enabled` | Render primary Service as headless | `false` |
| `service.extraPorts` | Additional service ports | `[]` |
| `services` | Additional Service resources | `[]` |
| `ingress.enabled` | Enable Ingress | `false` |
| `ingress.ingressClassName` | Ingress class | `traefik` |
| `ingress.hosts` | Ingress host rules | `[]` |
| `ingress.defaultBackend` | Ingress default backend | `{}` |
| `ingress.tls` | TLS configuration | `[]` |
| `gatewayApi.enabled` | Enable Gateway API HTTPRoutes | `false` |
| `gatewayApi.httpRoutes` | HTTPRoute definitions | `[]` |
| **Scheduling** | | |
| `updateStrategy` | Deployment rollout strategy | `RollingUpdate 25%/25%` |
| `nodeSelector` | Node selector | `{}` |
| `tolerations` | Tolerations | `[]` |
| `affinity` | Affinity rules | `{}` |
| `topologySpreadConstraints` | Topology spread | `[]` |
| `priorityClassName` | Priority class | `""` |
| `terminationGracePeriodSeconds` | Graceful shutdown timeout | `30` |
| `runtimeClassName` | RuntimeClass name | `""` |
| `schedulerName` | Custom scheduler | `""` |
| `hostAliases` | Pod host aliases | `[]` |
| `dnsPolicy` | Pod DNS policy | `""` |
| `dnsConfig` | Pod DNS config | `{}` |
| `hostNetwork` | Use node network namespace | `false` |
| `hostPID` | Use node PID namespace | `false` |
| `hostIPC` | Use node IPC namespace | `false` |
| `shareProcessNamespace` | Share process namespace between containers | `false` |
| `enableServiceLinks` | Inject Service env vars into pods | `true` |
| `rollout.restartAt` | Explicit restart marker for pod template annotations | `""` |
| `rollout.podAnnotations` | Rollout-specific pod annotations | `{}` |
| `rollout.checksum` | ConfigMap/Secret checksum rollout controls | enabled |
| **Autoscaling** | | |
| `hpa.enabled` | Enable HPA (not for DaemonSet) | `false` |
| `hpa.minReplicas` | Minimum replicas | `1` |
| `hpa.maxReplicas` | Maximum replicas | — |
| `hpa.metrics` | Scaling metrics | `[]` |
| `keda.enabled` | Enable KEDA custom resources | `false` |
| `keda.scaledObject` | KEDA ScaledObject configuration | disabled |
| `keda.scaledJobs` | KEDA ScaledJob definitions | `[]` |
| `vpa.enabled` | Enable VPA | `false` |
| `vpa.updateMode` | VPA update mode | `Off` |
| `pdb.enabled` | Enable PodDisruptionBudget | `false` |
| `pdb.minAvailable` | Minimum available pods | — |
| `pdb.maxUnavailable` | Maximum unavailable pods | — |
| **Storage** | | |
| `persistence.volumes` | Extra volumes | `[]` |
| `persistence.mounts` | Volume mounts for all containers | `[]` |
| `persistence.storage` | Legacy PV/PVC definitions | `[]` |
| `persistence.persistentVolumeClaims` | Declarative PVCs | `[]` |
| `persistence.persistentVolumes` | Explicit opt-in PVs | `[]` |
| **Observability** | | |
| `serviceMonitor.enabled` | Enable Prometheus ServiceMonitor | `false` |
| `serviceMonitor.endpoints` | Scrape endpoints | `[]` |
| `podMonitor.enabled` | Enable Prometheus PodMonitor | `false` |
| `podMonitor.podMetricsEndpoints` | Pod scrape endpoints | `[]` |
| `prometheusRule.enabled` | Enable PrometheusRule | `false` |
| `prometheusRule.groups` | Prometheus alert/recording rule groups | `[]` |
| **ConfigMaps** | | |
| `configMaps` | Declarative ConfigMap resources | `[]` |
| **Security** | | |
| `secrets` | Declarative Secret resources | `[]` |
| `externalSecrets.enabled` | Enable ExternalSecret resources | `false` |
| `sealedSecrets.enabled` | Enable SealedSecret resources | `false` |
| `rbac.create` | Create Role and RoleBinding | `false` |
| `rbac.clusterRole.create` | Create ClusterRole and ClusterRoleBinding | `false` |
| `networkPolicy.enabled` | Create NetworkPolicy | `false` |
| `networkPolicy.defaultDeny` | Render default-deny policy shape | `false` |
| **Batch** | | |
| `jobs` | One-time Job definitions | `[]` |
| `cronjobs` | CronJob definitions | `[]` |
| **Extensibility** | | |
| `extraManifests` | Arbitrary K8s manifests (supports tpl) | `[]` |
| **Metadata** | | |
| `podLabels` | Extra pod labels | `{}` |
| `podAnnotations` | Extra pod annotations | `{}` |
| `annotations` | Workload resource annotations | `{}` |

<!-- @AI-METADATA
type: chart-readme
title: Generic Helm Chart
description: Multi-purpose Helm chart for Deployments, StatefulSets, DaemonSets, Jobs, CronJobs

keywords: generic, deployment, statefulset, daemonset, job, cronjob

purpose: Usage guide for the generic multi-purpose Helm chart
scope: Chart

relations:
  - charts/generic/docs/deployment.md
  - charts/generic/docs/statefulset.md
  - charts/generic/docs/daemonset.md
  - charts/generic/docs/batch.md
path: charts/generic/README.md
version: 1.0
date: 2026-03-20
-->
