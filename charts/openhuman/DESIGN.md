# OpenHuman chart design

<!-- markdownlint-disable MD013 -->

## Architecture

One Deployment runs the headless Core and one Service exposes its authenticated JSON-RPC endpoint. Two retained PVCs preserve the application workspace and projects/action directory. The chart does not deploy the desktop UI or optional external model and search services.

## Singleton and lifecycle

OpenHuman stores local SQLite and workspace state without a documented coordination protocol. The chart fixes the workload at one replica and uses Recreate so two writers never overlap. Application-managed self-update is disabled; image rollout belongs to Kubernetes.

## Identity and storage

The container runs as the upstream UID/GID 10001. `fsGroup` makes newly provisioned volumes writable while avoiding the upstream Docker entrypoint's root path and CHOWN, SETUID and SETGID capabilities. A read-only root filesystem is paired with writable workspace, projects and `/tmp` mounts.

## Authentication boundary

The RPC token is generated into a retained Secret unless an existing Secret is selected. The optional keyring master key is projected as a read-only file. ExternalSecret items use the HelmForge canonical free-form contract. The health endpoint is intentionally unauthenticated upstream; every other client connection must protect the bearer in transit.

## Networking

ClusterIP, default-deny ingress and same-namespace callers are the defaults. Public HTTPS egress remains available because providers are operator-selected and dynamic; private endpoints are declared with extra egress rules. Ingress requires both a class and TLS. Gateway API parents are operator-managed and must terminate TLS.

## Deliberate omissions

There is no HPA, multi-replica mode, ServiceMonitor, bundled database, bundled inference service, arm64 scheduling or in-container updater. Upstream does not provide contracts that would make those features truthful and safe.
