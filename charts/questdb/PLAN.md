# QuestDB implementation plan

## Scope

Deliver a production-oriented chart for one QuestDB OSS instance with immutable
official images, persistent storage, generated or externally managed passwords,
network isolation, optional TLS edge exposure and Prometheus integration.

## Implementation

1. Pin QuestDB 10.0.1 by its multi-architecture OCI index digest.
2. Create a singleton StatefulSet with a retained PVC and stable headless DNS.
3. Run as UID/GID 10001 under the Kubernetes Restricted security profile.
4. Generate stable PostgreSQL and HTTP passwords or consume an existing Secret.
5. Support External Secrets Operator through the HelmForge canonical contract.
6. Expose HTTP and PostgreSQL internally, with legacy ILP TCP opt-in.
7. Add `/status` probes, optional `/metrics` service and ServiceMonitor.
8. Add default NetworkPolicy, TLS-only Ingress and Gateway API integration.
9. Document checkpoint-based backup, upgrades, singleton limits and storage.
10. Validate schema, lint, templates, unit tests, kubeconform, policy checks,
    External Secrets reconciliation and behavioral k3d execution.

## Explicit non-goals

- Pretending multiple OSS replicas form a safe cluster.
- Packaging Enterprise replication, TLS, RBAC or backup features.
- Supporting NFS or distributed database storage.
- Rebuilding or repackaging the official upstream image.
