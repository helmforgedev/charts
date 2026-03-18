# Helm Charts

Reusable Helm charts for Kubernetes workloads. Published as OCI artifacts to GitHub Container Registry.

## Charts

| Chart | Description | Version |
|-------|-------------|---------|
| [generic](charts/generic/) | General-purpose chart for any Kubernetes workload | `1.0.0` |

## Usage

### Install from OCI registry

```bash
helm install my-release oci://ghcr.io/mberlofa/helm/generic --version 1.0.0 -f values.yaml
```

### Pull and inspect

```bash
helm pull oci://ghcr.io/mberlofa/helm/generic --version 1.0.0
helm show values oci://ghcr.io/mberlofa/helm/generic --version 1.0.0
```

---

## Generic Chart

A single chart that handles **Deployments**, **StatefulSets**, **DaemonSets**, **Jobs**, and **CronJobs** with a unified values interface. Designed for teams that deploy many services and want one chart to rule them all.

### Workload Types

Only one workload type is active at a time, controlled by `workload.type`:

```yaml
workload:
  enabled: true          # false for Jobs/CronJobs-only releases
  type: Deployment       # Deployment | StatefulSet | DaemonSet
```

<details>
<summary><b>Deployment</b> (default)</summary>

```yaml
workload:
  enabled: true
  type: Deployment

image:
  repository: myapp
  tag: "1.0.0"

imageTagFormat: simple   # image = myapp:1.0.0

containers:
  - name: app
    ports:
      - containerPort: 3000

service:
  port: 3000
  targetPort: 3000

ingress:
  enabled: true
  hosts:
    - host: app.example.com
      paths: [/]
  tls:
    - hosts: [app.example.com]
      secretName: app-tls
```
</details>

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

### Key Features

#### Multi-container pods

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

#### Global and per-container environment

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

#### Init containers

```yaml
initContainers:
  - name: wait-for-db
    image:
      repository: busybox
      tag: "1.36"
    command: ["sh", "-c", "until nc -z db 5432; do sleep 1; done"]
```

#### Image tag format

Two modes for composing the image tag:

| Format | Result | Use case |
|--------|--------|----------|
| `named` (default) | `repo:containerName-tag` | Multi-stage Dockerfiles with named targets |
| `simple` | `repo:tag` | Standard single-image builds |

```yaml
imageTagFormat: simple   # myapp:1.0.0
imageTagFormat: named    # myapp:app-1.0.0
```

#### Probes

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

#### Extra manifests

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

### All Values Reference

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
| `image.repository` | Container image repository | `container.registry.io/project/image` |
| `image.tag` | Image tag | `latest` |
| `image.pullPolicy` | Pull policy | `Always` |
| `imageTagFormat` | `named` or `simple` | `named` |
| `imagePullSecrets` | Registry pull secrets | `[]` |
| **Containers** | | |
| `containers` | List of container specs | 1 container on port 8080 |
| `initContainers` | Init container specs | `[]` |
| **Environment** | | |
| `env` | Global env vars for all containers | `[]` |
| `envFrom` | Global envFrom for all containers | `[]` |
| **Service Account** | | |
| `serviceAccount.create` | Create a ServiceAccount | `false` |
| `serviceAccount.name` | ServiceAccount name | `""` |
| `serviceAccount.annotations` | ServiceAccount annotations | `{}` |
| **Resources & Probes** | | |
| `resources` | Default resource limits/requests | `{}` |
| `livenessProbe` | Global liveness probe (first container) | `{}` |
| `readinessProbe` | Global readiness probe (first container) | `{}` |
| `startupProbe` | Global startup probe (first container) | `{}` |
| **Security** | | |
| `podSecurityContext` | Pod-level security context | `{}` |
| `securityContext` | Container-level security context | `{}` |
| **Networking** | | |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `8080` |
| `service.targetPort` | Target port | `8080` |
| `service.extraPorts` | Additional service ports | `[]` |
| `ingress.enabled` | Enable Ingress | `false` |
| `ingress.ingressClassName` | Ingress class | `nginx` |
| `ingress.hosts` | Ingress host rules | `[]` |
| `ingress.tls` | TLS configuration | `[]` |
| **Scheduling** | | |
| `updateStrategy` | Deployment rollout strategy | `RollingUpdate 25%/25%` |
| `nodeSelector` | Node selector | `{}` |
| `tolerations` | Tolerations | `[]` |
| `affinity` | Affinity rules | `{}` |
| `topologySpreadConstraints` | Topology spread | `[]` |
| `priorityClassName` | Priority class | `""` |
| `terminationGracePeriodSeconds` | Graceful shutdown timeout | `30` |
| **Autoscaling** | | |
| `hpa.enabled` | Enable HPA (not for DaemonSet) | `false` |
| `hpa.minReplicas` | Minimum replicas | `1` |
| `hpa.maxReplicas` | Maximum replicas | — |
| `hpa.metrics` | Scaling metrics | `[]` |
| `vpa.enabled` | Enable VPA | `false` |
| `vpa.updateMode` | VPA update mode | `Off` |
| `pdb.enabled` | Enable PodDisruptionBudget | `false` |
| `pdb.minAvailable` | Minimum available pods | — |
| `pdb.maxUnavailable` | Maximum unavailable pods | — |
| **Storage** | | |
| `persistence.volumes` | Extra volumes | `[]` |
| `persistence.mounts` | Volume mounts for all containers | `[]` |
| `persistence.storage` | PV/PVC definitions | `[]` |
| **Observability** | | |
| `serviceMonitor.enabled` | Enable Prometheus ServiceMonitor | `false` |
| `serviceMonitor.endpoints` | Scrape endpoints | `[]` |
| **ConfigMaps** | | |
| `configMaps` | Declarative ConfigMap resources | `[]` |
| **Batch** | | |
| `jobs` | One-time Job definitions | `[]` |
| `cronjobs` | CronJob definitions | `[]` |
| **Extensibility** | | |
| `extraManifests` | Arbitrary K8s manifests (supports tpl) | `[]` |
| **Metadata** | | |
| `podLabels` | Extra pod labels | `{}` |
| `podAnnotations` | Extra pod annotations | `{}` |
| `annotations` | Workload resource annotations | `{}` |

---

## CI/CD

Charts are automatically tested and published via GitHub Actions.

### Pipeline

```
PR        --> [Lint] [Template] [Kubeconform]  (parallel)
Push main --> [Lint] [Template] [Kubeconform]  --> Semver --> Publish to GHCR --> Git tag
```

### Versioning

Versions are calculated automatically from **conventional commits** affecting each chart:

| Commit prefix | Bump | Example |
|---------------|------|---------|
| `fix:`, `docs:`, `refactor:` | PATCH | `fix(generic): correct HPA indentation` |
| `feat:` | MINOR | `feat(generic): add DaemonSet support` |
| `feat!:` or `BREAKING CHANGE` | MAJOR | `feat(generic)!: restructure workload config` |

Tags follow the format `{chart}-v{version}` (e.g., `generic-v1.2.3`).

### Testing

Each chart can include a `ci/` directory with test values files. The pipeline runs `helm template` against every `ci/*.yaml` file automatically:

```
charts/
  generic/
    ci/
      deployment-values.yaml
      statefulset-values.yaml
      daemonset-values.yaml
      jobs-only-values.yaml
      multi-container-values.yaml
```

---

## Contributing

### Adding a new chart

1. Create `charts/<chart-name>/` with `Chart.yaml`, `values.yaml`, and `templates/`
2. Add test values in `charts/<chart-name>/ci/*.yaml`
3. Open a PR -- lint, template, and schema validation run automatically
4. Merge to main -- the chart is versioned and published to GHCR

### Commit conventions

Use [Conventional Commits](https://www.conventionalcommits.org/) to drive automatic versioning:

```bash
git commit -m "feat(generic): add topology spread constraints support"
git commit -m "fix(generic): correct service targetPort default"
git commit -m "feat(redis-ha)!: redesign sentinel configuration"
```

## License

MIT
