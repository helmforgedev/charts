<!-- SPDX-License-Identifier: Apache-2.0 -->

# Apache Tomcat

Production-oriented Apache Tomcat chart for Kubernetes using the official
`docker.io/library/tomcat` image.

## Features

- Official Tomcat image pinned to `11.0.27-jdk17-temurin-noble` by default.
- Deterministic default ROOT application for probes and Helm tests.
- Preservation of WARs and exploded applications baked into immutable images.
- Non-root execution with a read-only root filesystem and explicit writable
  runtime volumes.
- Ingress and Gateway API `HTTPRoute` exposure.
- Optional JMX registry and RMI endpoints.
- Dual-stack Services, NetworkPolicy, HPA, PDB, persistent webapps and logs,
  scheduling controls, and extension hooks.

## Architecture

The chart runs one Tomcat Deployment behind a named-port Service. The official
image listens on HTTP port `8080`; `service.ports.http` is the independent
client-facing Service port. Ingress and HTTPRoute resources route to that
Service. Optional JMX registry and RMI ports are exposed only when JMX is
enabled.

Tomcat needs writable `webapps`, `logs`, `temp`, `work`, and
`conf/Catalina/localhost` paths. The chart mounts those paths explicitly while
keeping the image root filesystem read-only. Webapps and logs can use generated
or existing PVCs; the remaining runtime paths use `emptyDir`.

See [DESIGN.md](DESIGN.md) for the complete topology, trust boundaries, and
design decisions.

## Security

The default pod runs as UID/GID `1001`, drops all Linux capabilities, disables
privilege escalation, uses RuntimeDefault seccomp, and does not mount a
Kubernetes API token. The root filesystem is read-only except for explicit
runtime volumes.

NetworkPolicy is opt-in because application egress and ingress-controller
selectors are environment-specific. Enable it only after declaring every
required application, DNS, ingress, and JMX path. JMX is also opt-in; restrict
it to trusted peers and configure authentication and TLS before production use.

### Security Scan: `tomcat`

| Framework | Score |
| --- | ---: |
| MITRE + NSA + SOC2 | **95%** |

The remaining findings are documented product exceptions for opt-in
NetworkPolicy boundaries.

## Installation

```bash
helm install tomcat oci://repo.helmforge.dev/charts/tomcat \
  --namespace tomcat \
  --create-namespace
```

Verify the release:

```bash
helm test tomcat -n tomcat
kubectl get pods -n tomcat -l app.kubernetes.io/instance=tomcat
```

## Configuration

### Deploying applications

The official image starts without a production application. This chart seeds a
small ROOT application so `/health.jsp` works immediately. For production,
deploy a versioned WAR or exploded application with an immutable image or an
init container.

When an immutable image contains applications under
`/usr/local/tomcat/webapps`, keep `webapps.copyImageContent.enabled=true`. The
chart copies image content only when the mounted webapps volume is empty. Set
`webapps.defaultRoot.enabled=false` when your image owns the ROOT application.

Applications without `/health.jsp` must use an application-specific probe path
or TCP probes:

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

### HTTP listener and Service ports

The official image's primary HTTP Connector remains on port `8080`.
`containerPorts.http` is retained as a compatibility value and is constrained
to `8080`; it is not a client-facing port. Change `service.ports.http` to
expose the application on a different Service port.

Custom `tomcat.serverXml` or `tomcat.existingServerXmlConfigMap` values may
set proxy attributes such as `proxyName`, `proxyPort`, and `scheme`, but the
primary HTTP Connector must continue to listen on `8080` so it matches the
named Service target and probes.

### Exposure

Ingress and Gateway API are both optional. Gateway API requires the CRDs and a
parent Gateway managed by the platform team.

```yaml
gatewayAPI:
  enabled: true
  parentRefs:
    - name: public-gateway
      namespace: gateway-system
  hostnames:
    - tomcat.example.com
```

### JMX

JMX is disabled by default because an unsecured remote management interface is
unsafe. `jmx.port` configures the JVM registry port, and `jmx.rmiPort`
configures the RMI endpoint. The chart advertises the Pod IP unless
`jmx.hostname` is set.

```yaml
jmx:
  enabled: true
  hostname: tomcat.example.local
```

For authentication or TLS, mount the required files with `extraVolumes` and
`extraVolumeMounts`, then add the corresponding JVM flags through
`jmx.extraOpts`.

## Examples

- [Production baseline](examples/production.yaml)
- [Persistent webapps](examples/persistent-webapps.yaml)
- [JMX](examples/jmx.yaml)
- [Production operations guide](docs/production.md)

## Upgrading

Tomcat `11.0.27` contains bug fixes, dependency updates, and stability
improvements without a chart values migration. Review the
[official Tomcat 11 changelog](https://tomcat.apache.org/tomcat-11.0-doc/changelog.html)
and application compatibility before rollout.

For mutable webapps, back up the PVC before an upgrade. For immutable images,
test the new image with the same probes and route configuration in a staging
namespace. Custom clustering or `server.xml` configurations remain the
operator's responsibility.

## Key values

| Key | Default | Description |
| --- | --- | --- |
| `replicaCount` | `1` | Pod count when HPA is disabled |
| `image.repository` | `docker.io/library/tomcat` | Official image repository |
| `image.tag` | `11.0.27-jdk17-temurin-noble` | Pinned image tag |
| `containerPorts.http` | `8080` | Fixed official HTTP Connector port |
| `service.ports.http` | `80` | Client-facing Service port |
| `webapps.defaultRoot.enabled` | `true` | Seed deterministic ROOT health app |
| `webapps.copyImageContent.enabled` | `true` | Preserve image-baked webapps on an empty volume |
| `webapps.persistence.enabled` | `false` | Persist the webapps directory |
| `logs.persistence.enabled` | `false` | Persist Tomcat logs |
| `tomcat.serverXml` | `""` | Inline `server.xml` override |
| `tomcat.existingServerXmlConfigMap` | `""` | Existing ConfigMap with `server.xml` |
| `startupProbe.mode` | `http` | Startup check mode: `http` or `tcp` |
| `jmx.enabled` | `false` | Enable JMX registry and RMI ports |
| `ingress.enabled` | `false` | Render an Ingress |
| `gatewayAPI.enabled` | `false` | Render an HTTPRoute |
| `networkPolicy.enabled` | `false` | Render a NetworkPolicy |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount Kubernetes API credentials |
| `securityContext.readOnlyRootFilesystem` | `true` | Keep the image filesystem read-only |
| `autoscaling.enabled` | `false` | Render an HPA |
| `pdb.enabled` | `false` | Render a PodDisruptionBudget |

Every supported value and its default is documented in
[values.yaml](values.yaml) and validated by
[values.schema.json](values.schema.json).

## Validation

CI renders standalone, Ingress, Gateway API, dual-stack, JMX, and hardening
scenarios. Unit tests cover workload security, writable paths, image webapp
copying, probes, routing, JMX, NetworkPolicy, HPA, PDB, Services, and Helm test
behavior. The release gate also runs strict lint, kubeconform, Artifact Hub
lint, and behavioral k3d validation.

## Troubleshooting

- If the Pod is not Ready, verify that the selected probe path exists in the
  deployed application or switch the probes to `tcp`.
- If an image-baked application is missing, confirm that
  `webapps.copyImageContent.enabled=true` and that a reused PVC was empty on its
  first deployment. The chart does not overwrite an initialized PVC.
- If requests contain the wrong external scheme or hostname, configure proxy
  attributes in `tomcat.serverXml` while keeping the HTTP Connector on `8080`.
- If JMX connects to the registry but not RMI, verify `jmx.hostname`,
  `jmx.rmiPort`, `service.ports.jmxRmi`, and NetworkPolicy peers together.
- If NetworkPolicy blocks the application, declare the ingress controller and
  all required egress destinations before enabling enforcement.

## Links

- [Apache Tomcat](https://tomcat.apache.org/)
- [Official image](https://hub.docker.com/_/tomcat)
- [Chart source](https://github.com/helmforgedev/charts/tree/main/charts/tomcat)

## Artifact Hub

```yaml
artifacthub.io/category: integration-delivery
keywords: tomcat, apache, java, jakarta-ee, servlet, jsp, gateway-api
```
