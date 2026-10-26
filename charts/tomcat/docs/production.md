<!-- SPDX-License-Identifier: Apache-2.0 -->

# Production Guidance

Use a pinned application artifact, explicit resources, NetworkPolicy, and
either Ingress or Gateway API.

```yaml
replicaCount: 2

webapps:
  defaultRoot:
    enabled: false
  copyImageContent:
    enabled: true

startupProbe:
  mode: tcp
livenessProbe:
  mode: tcp
readinessProbe:
  mode: tcp

networkPolicy:
  enabled: true
  ingress:
    extraFrom:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: gateway-system

pdb:
  enabled: true
```

## Application delivery

Prefer an immutable image containing a versioned WAR or exploded application.
Keep `webapps.copyImageContent.enabled=true`; the chart copies applications
from `/usr/local/tomcat/webapps` into the writable volume only when that volume
is empty. Disable `webapps.defaultRoot` when the image owns the ROOT context.

An init container may instead download an artifact into the shared webapps
volume. Pin the artifact version, verify its checksum or signature before
installation, use a read-only credential mount, and set explicit resources.
Do not download an unversioned artifact from a mutable URL during every start.

PVC-backed webapps support intentionally mutable deployments, but a reused PVC
is not refreshed when the Tomcat image changes. Record the application version
outside the Pod and define a migration and rollback procedure for that volume.

## Reverse proxy contract

When Tomcat is behind a reverse proxy, use `tomcat.serverXml` or an existing
ConfigMap to configure connector proxy attributes so applications see the
correct external scheme, host, and port.

Keep the primary HTTP Connector on port `8080`. The chart exposes it through a
named target port, while `service.ports.http` controls the client-facing Service
port.

Configure `proxyName`, `proxyPort`, `scheme`, and `secure` according to the
external TLS endpoint. Preserve the primary Connector on `8080`; changing only
container metadata does not reconfigure Tomcat.

## Availability and scaling

Use at least two replicas and a PDB only after the application is safe for
concurrent replicas. The chart does not provide shared HTTP sessions,
application caches, or coordinated background jobs. Configure application
session replication or external state before enabling HPA.

Choose probe endpoints that reflect application health without depending on
slow or optional downstream systems. TCP probes are useful during initial
artifact deployment but prove only that the Connector accepts connections.

## Network and JMX security

Enable NetworkPolicy after identifying the ingress controller and every
application egress dependency. The baseline can allow DNS, HTTP, and HTTPS;
use `networkPolicy.egress.extraTo` for additional peers and
`networkPolicy.egress.extraEgress` for complete custom rules.

JMX must remain disabled unless an operations workflow requires it. When
enabled, restrict registry and RMI ports to a trusted monitoring namespace,
configure a reachable `jmx.hostname`, and mount authentication and TLS files.
Unauthenticated JMX must never be exposed through a public Service or route.

## Storage, backup, and restore

Back up PVC-backed webapps before application or Tomcat upgrades. Persist logs
only when the cluster logging pipeline cannot satisfy retention requirements;
otherwise keep logs ephemeral and collect them centrally. Test restore into a
separate namespace with the same security context and storage class before
depending on the backup procedure.

## Upgrade and rollback

Review the upstream Tomcat changelog, Jakarta API compatibility, custom valves,
realms, native libraries, and `server.xml` before changing the image tag. Test
the exact application image and values in a staging namespace, run Helm tests,
and inspect restarts, logs, and warning events. Rollback restores the prior
chart revision and image, but persistent application mutations require their
own backward-compatible migration or restored PVC snapshot.
