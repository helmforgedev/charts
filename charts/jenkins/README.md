# Jenkins

Jenkins is an open source automation server for continuous integration and delivery.

This HelmForge chart deploys the official `jenkins/jenkins` controller image
at the pinned `2.580.1-lts-jdk21` release with production-oriented Kubernetes
defaults. It includes a StatefulSet
controller, persistent Jenkins home, secure initial admin bootstrap, optional
Jenkins Configuration as Code, optional plugin installation with
`jenkins-plugin-cli`, optional RBAC for Kubernetes agents, dual-stack Service
support, Gateway API, Ingress, NetworkPolicy, ExternalSecret, ServiceMonitor,
PodDisruptionBudget, and Helm tests.

Jenkins 2.580.1 is the next LTS line after 2.568.3 and includes the core fixes in
the [September 2 security advisory](https://www.jenkins.io/security/advisory/2026-09-02/).
The chart retains the LTS/JDK 21 distribution and existing plugin configuration.
Before upgrading, back up `JENKINS_HOME`, update installed plugins, and review the
[2.580.x upgrade guide](https://www.jenkins.io/doc/upgrade-guide/2.580/), especially
for offline controllers that may need detached plugins installed explicitly.

NetworkPolicy supports `networkPolicy.egress.extraEgress` for appending custom egress
rules without replacing the chart-generated DNS, cluster, internet, and
`networkPolicy.egress.extraRules` controls.

## Features

- Single-controller StatefulSet with stable `JENKINS_HOME` storage identity.
- Official Jenkins LTS image pinned to a JDK 21 tag.
- Stable chart-generated admin credentials during live Helm operations, or
  operator-managed Secret keys for rendered GitOps workflows.
- Optional Configuration as Code and pinned plugin bootstrap.
- Optional namespaced RBAC for Kubernetes plugin agents.
- Ingress and Gateway API routing with a named HTTP service target port.
- Optional inbound TCP agent listener, NetworkPolicy, ServiceMonitor, PDB, and
  External Secrets integration.
- Dual-stack Service controls and scheduling overrides for production clusters.

## Architecture

The chart runs one Jenkins controller because `JENKINS_HOME` is a single-writer
application data boundary. A StatefulSet preserves controller and PVC identity.
The HTTP Service exposes the web UI, and the same Service can expose the inbound
agent port. Ingress or an HTTPRoute can route HTTP traffic to the named service
port. Optional plugin installation runs before the controller, while JCasC
files and the initial admin script come from the chart ConfigMap.

Kubernetes agents are created by Jenkins and are not chart workloads. Enable
`rbac.create` only when the controller must manage agent Pods in its namespace.
See [DESIGN.md](./DESIGN.md) for trust boundaries and
[docs/production.md](./docs/production.md) for operational guidance.

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install jenkins helmforge/jenkins
```

## Configuration

The defaults install a persistent, single-replica controller with generated
initial admin credentials. The following settings define the primary user
contract; run `helm show values helmforge/jenkins` for the complete annotated
values file.

| Parameter | Default | Description |
|---|---|---|
| `image.repository` | `docker.io/jenkins/jenkins` | Official controller image repository. |
| `image.tag` | `2.580.1-lts-jdk21` | Pinned Jenkins LTS and JDK 21 image tag. |
| `controller.httpPort` | `8080` | Real Jenkins HTTP listener port. |
| `controller.agentPort` | `50000` | Real inbound agent listener port. |
| `service.httpPort` | `8080` | Cluster Service HTTP port. |
| `agent.enabled` | `true` | Expose the inbound agent listener. |
| `agent.servicePort` | `50000` | Cluster Service port for inbound agents. |
| `admin.create` | `true` | Bootstrap the initial admin account. |
| `admin.existingSecret` | `""` | Use an operator-managed admin Secret. |
| `persistence.enabled` | `true` | Persist `JENKINS_HOME`. |
| `persistence.size` | `8Gi` | Default Jenkins home claim size. |
| `plugins.install.enabled` | `false` | Install the pinned plugin list before startup. |
| `plugins.install.initializeOnce` | `true` | Reuse the initialized plugin state on the PVC. |
| `jcasC.enabled` | `false` | Mount and activate JCasC scripts. |
| `ingress.enabled` | `false` | Render an Ingress. |
| `gateway.enabled` | `false` | Render a Gateway API HTTPRoute. |
| `networkPolicy.enabled` | `false` | Render controller network boundaries. |
| `rbac.create` | `false` | Grant namespaced permissions for Kubernetes agents. |
| `metrics.serviceMonitor.enabled` | `false` | Render a Prometheus Operator ServiceMonitor. |
| `externalSecrets.enabled` | `false` | Render an ExternalSecret for admin credentials. |

Listener and Service ports are intentionally separate. Changing
`controller.httpPort` changes the Jenkins process and Pod probe target;
changing only `service.httpPort` changes the Service-facing port. Do not set
`--httpPort` in `controller.jenkinsOpts`; a user-supplied argument takes
precedence over the generated argument while the container port and probes
still use `controller.httpPort`. If an existing deployment already supplies
that argument, its value must exactly match `controller.httpPort`.

## Admin Credentials

By default the chart creates an initial admin user and stores the generated password in a Kubernetes Secret:

```bash
kubectl get secret jenkins-admin -o jsonpath='{.data.jenkins-admin-password}' | base64 -d
```

Use `admin.existingSecret` with `admin.existingSecretUserKey` and
`admin.existingSecretPasswordKey` to manage credentials externally. Generated
credentials remain stable when Helm can look up the live Secret during an
install or upgrade. Offline rendering cannot perform that lookup, so GitOps
workflows that render manifests before applying them must use
`admin.existingSecret` or `externalSecrets` to avoid Secret and Jenkins
credential drift.

## Examples

Production, JCasC, Gateway API, and External Secrets examples are maintained in
the [`examples/`](./examples/) directory. Download the production values file,
review every credential, storage, resource, and network setting, and create the
Secret it references before installation:

```bash
curl -fsSLo jenkins-production-values.yaml \
  https://raw.githubusercontent.com/helmforgedev/charts/main/charts/jenkins/examples/production.yaml
kubectl create namespace jenkins --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic jenkins-admin \
  --namespace jenkins \
  --from-literal=jenkins-admin-user=admin \
  --from-literal=jenkins-admin-password='replace-with-a-strong-password'
helm upgrade --install jenkins helmforge/jenkins \
  --namespace jenkins \
  --values jenkins-production-values.yaml
```

## Plugins and JCasC

The chart can install pinned plugins before Jenkins starts:

```yaml
plugins:
  install:
    enabled: true
    initializeOnce: true
    list:
      - kubernetes:4423.vb_59f230b_ce53
      - workflow-aggregator:608.v67378e9d3db_1
      - git:5.10.1
      - configuration-as-code:2074.va_57f83f7a_10b_
```

JCasC files can be mounted and activated with `jcasC.enabled=true`. The
`configuration-as-code` plugin must be included in the image or installed
through the plugin bootstrap.

## Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: jenkins.example.com
      paths:
        - path: /
          pathType: Prefix
```

## Gateway API

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: public
  hostnames:
    - jenkins.example.com
```

## Validation

This chart is tested with Helm lint, strict lint, Helm unittest, kubeconform,
Artifact Hub lint, markdown lint, security scans, and k3d runtime validation.

## Troubleshooting

- If Jenkins remains unready, inspect the controller logs and confirm the
  configured HTTP listener matches `controller.httpPort`.
- If plugin initialization fails, verify update-center egress and every pinned
  coordinate in `plugins.install.list`. Existing initialized homes skip the
  installer while `initializeOnce=true`.
- If JCasC is ignored, ensure the Configuration as Code plugin is installed and
  that `jcasC.configScripts` contains at least one entry.
- If Kubernetes agents cannot start, verify `rbac.create`, the controller
  ServiceAccount, API-server egress, and any agent-specific Jenkins cloud
  configuration.
- If an upgrade changes credentials unexpectedly, restore the prior Secret or
  configure `admin.existingSecret` before retrying. Back up `JENKINS_HOME`
  before core or plugin changes.

### Security Scan: `jenkins`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **91.41%** |

> Security posture acceptable with controller security contexts, non-root execution, optional NetworkPolicy, and operator-controlled plugin/JCasC inputs.

## Documentation

- [Design](./DESIGN.md)
- [Production guide](./docs/production.md)
- [Networking](./docs/networking.md)
- [External Secrets](./docs/external-secrets.md)
- [JCasC and plugins](./docs/jcasc-and-plugins.md)
