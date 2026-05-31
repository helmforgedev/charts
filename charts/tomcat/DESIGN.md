# Apache Tomcat Chart Design

## Goals

- Package Apache Tomcat with the official Docker image.
- Keep default installs functional in k3d without requiring a user WAR file.
- Provide production controls that are usually missing from minimal Tomcat charts: Gateway API, dual-stack Service, NetworkPolicy, JMX, HPA, PDB, non-root runtime, and explicit writable runtime volumes.

## Runtime Model

The official image stores Tomcat under `/usr/local/tomcat` and listens on port `8080`.
The chart runs the container as UID/GID `1001`, mounts writable volumes for directories Tomcat mutates, and keeps Kubernetes API token mounting disabled by default.

The default ROOT app exists only to make health checks deterministic.
Operators deploying a real app can disable it and point probes at their own endpoint, or use TCP probes while an application warms up.

## Exposure

The chart supports classic Ingress and Gateway API.
Gateway API requires existing CRDs and an existing parent Gateway.
The chart intentionally renders only `HTTPRoute`, leaving Gateway ownership to platform teams.

## Monitoring

JMX remote flags are opt-in.
Authentication and TLS are intentionally left to mounted files plus `jmx.extraOpts`.
JMX security is environment-specific and unsafe defaults would expose a management interface.

## Persistence

`webapps` persistence is optional for mutable deployments.
Immutable app images or versioned init-container downloads are preferred for production because they make rollback and audit easier.
Logs persistence is optional; clusters with centralized logging should leave it disabled.
