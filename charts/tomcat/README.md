# Apache Tomcat

Apache Tomcat chart for Kubernetes using the official `docker.io/library/tomcat` image.

## Highlights

- Official Tomcat image, pinned by default to `11.0.22-jdk17-temurin-noble`.
- Stable default install with an optional ROOT health webapp for deterministic probes and Helm tests.
- Non-root runtime with writable `webapps`, `logs`, `temp`, and `work` volumes.
- Ingress and Gateway API `HTTPRoute` exposure.
- Optional JMX remote port for platform monitoring integrations.
- Dual-stack Service fields, NetworkPolicy, HPA, PDB, persistent webapps/logs, and extra init/sidecar hooks.

## Install

```bash
helm install tomcat oci://repo.helmforge.dev/charts/tomcat
```

## Deploying Applications

The official Tomcat image starts without a production application. This chart enables a small default ROOT app so `/health.jsp` works immediately.
For real workloads, mount WAR files or exploded applications through `extraInitContainers`, `extraVolumes`, and `extraVolumeMounts`, or enable `webapps.persistence`.

For production applications that do not expose `/health.jsp`, switch probes to TCP or set probe paths to an application endpoint:

```yaml
webapps:
  defaultRoot:
    enabled: false

startupProbe:
  mode: tcp
livenessProbe:
  mode: tcp
readinessProbe:
  mode: tcp
```

## Gateway API

```yaml
gatewayAPI:
  enabled: true
  parentRefs:
    - name: public-gateway
      namespace: gateway-system
  hostnames:
    - tomcat.example.com
```

## JMX

JMX is opt-in because remote JMX should normally be restricted to trusted networks.

```yaml
jmx:
  enabled: true
  hostname: tomcat.example.local
```

For authenticated or TLS-secured JMX, mount the required files with `extraVolumes`/`extraVolumeMounts` and append JVM flags through `jmx.extraOpts`.

## Production Notes

- Keep `serviceAccount.automountServiceAccountToken=false` unless your app needs Kubernetes API access.
- Enable `networkPolicy.enabled` and explicitly allow ingress from your gateway or ingress controller namespace.
- Use persistent `webapps` storage only when applications are installed or mutated at runtime.
- Prefer immutable app images or init containers that fetch versioned WAR artifacts.
- Configure `tomcat.serverXml` or `tomcat.existingServerXmlConfigMap` when you need proxy connector attributes such as `proxyName`, `proxyPort`, or `scheme`.

## Values

| Key | Default | Description |
| --- | --- | --- |
| `replicaCount` | `1` | Number of Tomcat pods when HPA is disabled. |
| `image.repository` | `docker.io/library/tomcat` | Tomcat image repository. |
| `image.tag` | `11.0.22-jdk17-temurin-noble` | Tomcat image tag. |
| `service.type` | `ClusterIP` | Kubernetes Service type. |
| `service.ipFamilyPolicy` | `null` | Optional Service dual-stack policy. |
| `service.ipFamilies` | `[]` | Optional Service IP family ordering. |
| `webapps.defaultRoot.enabled` | `true` | Render a minimal ROOT app for health checks. |
| `webapps.persistence.enabled` | `false` | Persist `/usr/local/tomcat/webapps`. |
| `logs.persistence.enabled` | `false` | Persist `/usr/local/tomcat/logs`. |
| `tomcat.serverXml` | `""` | Inline `server.xml` override. |
| `tomcat.existingServerXmlConfigMap` | `""` | Existing ConfigMap containing `server.xml`. |
| `jmx.enabled` | `false` | Expose JMX remote options and service port. |
| `ingress.enabled` | `false` | Render Ingress. |
| `gatewayAPI.enabled` | `false` | Render Gateway API HTTPRoute. |
| `networkPolicy.enabled` | `false` | Render NetworkPolicy. |
| `autoscaling.enabled` | `false` | Render HPA. |
| `pdb.enabled` | `false` | Render PodDisruptionBudget. |

## CI Scenarios

- `ci/standalone.yaml`
- `ci/ingress.yaml`
- `ci/gateway-api.yaml`
- `ci/dual-stack.yaml`
- `ci/jmx.yaml`
- `ci/hardening.yaml`

## Artifact Hub

```yaml
artifacthub.io/category: integration-delivery
keywords: tomcat, apache, java, jakarta-ee, servlet, jsp, gateway-api
```
