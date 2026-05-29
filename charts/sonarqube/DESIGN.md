# SonarQube Chart Design

## Scope

This chart packages a single SonarQube Community Build node. It is designed for straightforward Kubernetes operation while keeping production requirements explicit.

## Decisions

The chart uses a Deployment with `Recreate` strategy because a single SonarQube instance owns local data, extensions, logs, and embedded search state.
Production deployments should back the application with PostgreSQL and persistent volumes.

The default image is pinned to `docker.io/library/sonarqube:26.4.0.121862-community`.
This line matches the default `communityBranchPlugin.version` of `26.4.0`, allowing the plugin automation to be enabled without version guesswork.

`sonarqube.databaseMode=embedded` exists for k3d smoke tests and temporary evaluation only.
Production should use `external` mode with a PostgreSQL JDBC URL and a password from an existing Secret or ExternalSecret.

The chart keeps plugin installation in an init container.
This makes the main container use the official image unchanged while still allowing clusters to persist extensions or replace the webapp for the community branch plugin.

## Security

The default runtime drops all Linux capabilities, disallows privilege escalation, runs as UID/GID 1000, and disables service account token mounting.
Writable paths are modeled as explicit volumes so the main container can keep a read-only root filesystem.

NetworkPolicy is optional because clusters differ in CNI behavior.
When enabled, ingress is limited to the SonarQube HTTP port and egress can be restricted to DNS, HTTP, HTTPS, and PostgreSQL.

## Operations

The chart includes:

- startup, readiness, and liveness probes against `/api/system/status`
- optional PodDisruptionBudget
- optional Gateway API and Ingress exposure
- dual-stack Service fields
- Helm test connection pod
- External Secrets Operator integration for database and monitoring passcode material

## Non-goals

This chart does not deploy PostgreSQL as a dependency. Database ownership is intentionally external so teams can use their platform-standard PostgreSQL chart, operator, or managed service.
