# Metrics Server Chart Design

## Scope

This chart installs Metrics Server and the Kubernetes API aggregation resources required for `kubectl top`, HPA, and VPA metrics consumption.

## Decisions

The chart uses Metrics Server `v0.8.1`, the latest upstream application release found during implementation.
The official upstream Helm chart was still published at app version `0.8.0`, so this chart intentionally follows the newer application release while keeping the same upstream operational contract.

Kubelet TLS verification is secure by default.
A dedicated `metricsServer.kubelet.insecureTLS` value exists for local k3d/kind-style clusters where kubelet serving certificates lack usable SANs.

RBAC and APIService resources are enabled by default because Metrics Server is normally installed as a cluster add-on.
Disabling RBAC while managing APIService is rejected because delegated authentication and authorization are part of the aggregation contract.

## Security

The default pod runs as non-root, drops all capabilities, disables privilege escalation, uses RuntimeDefault seccomp, and mounts only `/tmp` as writable storage for generated serving certificates.

## Operations

The chart supports:

- typed kubelet connection options
- high availability through replicas, topology spread, and PDB
- hostNetwork mode
- dual-stack Service fields
- optional NetworkPolicy
- optional ServiceMonitor
- Helm test validation against `/readyz`
