# Generic Chart Design

## Scope

This chart provides a reusable Kubernetes workload wrapper for teams that need one operational values contract across many simple services.

Supported workload modes:

- `Deployment` for stateless services, APIs, workers, and web applications
- `StatefulSet` for workloads that need stable pod identity or per-replica claim templates
- `DaemonSet` for node-level agents
- `Job` and `CronJob` for batch-oriented releases

The chart intentionally models Kubernetes primitives directly. It is a platform building block, not an application-specific chart.

## Architecture

```mermaid
flowchart TB
  values[values.yaml] --> workload[Workload template]
  workload --> deploy[Deployment]
  workload --> stateful[StatefulSet]
  workload --> daemon[DaemonSet]
  workload --> batch[Job or CronJob]
  svc[Service templates] --> ingress[Ingress]
  svc --> route[Gateway API HTTPRoute]
  secrets[Secrets and ExternalSecret] --> pods[Pods]
  observability[ServiceMonitor, PodMonitor, PrometheusRule] --> prometheus[Prometheus stack]
  scaling[HPA, VPA, KEDA] --> workload
```

## Main Design Choices

- Keep the default path small: one `Deployment`, one `Service`, and a pinned nginx image.
- Treat the first container as the default probe target while allowing per-container overrides.
- Render one primary Service by default and support additional Services through `services[]`.
- Keep CRD-backed integrations opt-in. ExternalSecret, SealedSecret, ServiceMonitor, PodMonitor, PrometheusRule, KEDA,
  VPA, and Gateway API resources require their operators or CRDs to exist before users enable them.
- Render ExternalSecret resources with `external-secrets.io/v1`, matching the current External Secrets Operator API.
- Keep ExternalSecret naming backward compatible with suffix-based `name`, while allowing literal resource names through
  `fullnameOverride`. When `spec.target.name` is omitted, default it to the rendered ExternalSecret name.
- Validate unsafe combinations at render time, including HPA with DaemonSet, incomplete PDB configuration, and routes that would point to a disabled primary Service.
- Avoid time-based pod annotations. Intentional rollouts use `rollout.restartAt` or checksum-driven ConfigMap and Secret changes.

## Production Boundary

Production users should set explicit values for:

- `image.repository`, `image.tag`, and `image.pullPolicy`
- container ports, probes, env, envFrom, and resource requests/limits
- `service`, Ingress, or Gateway API exposure
- `securityPreset`, `podSecurityContext`, and `securityContext`
- `pdb`, `hpa`, `topologySpreadConstraints`, and scheduling controls where appropriate
- Secret source through `secrets[]`, `externalSecrets.items[]`, or existing Kubernetes Secrets
- observability resources only when the corresponding CRDs are installed

## Security Boundary

- Security contexts are empty by default because the chart cannot know the
  user, filesystem, and port needs of an arbitrary image. `securityPreset:
  baseline` sets non-root, `RuntimeDefault` seccomp, and drops capabilities;
  `restricted` also sets a read-only root filesystem and default IDs.
- The ServiceAccount token is not mounted unless
  `serviceAccount.automountServiceAccountToken` is enabled, and RBAC objects
  are rendered only when requested.
- Secrets come from `secrets[]`, ExternalSecret, SealedSecret, or existing
  Kubernetes Secrets; the chart never generates credentials.
- NetworkPolicy is opt-in and must be written for the workload.

## Observability Boundary

- Probes are empty by default; set `livenessProbe`, `readinessProbe`, and
  `startupProbe` (or per-container probes) for the real application.
- ServiceMonitor, PodMonitor, and PrometheusRule resources are rendered only
  when enabled and require the Prometheus Operator CRDs.
- Logs and metrics semantics belong to the deployed image.

## Current Gaps and Improvement Candidates

- No automatic probe or security defaults per image; users must supply them.
- Optional CRD-backed resources (KEDA, VPA, ExternalSecret, SealedSecret,
  monitoring) are validated by schema and render tests only when their CRDs
  are installed in the validation cluster.

## Non-Goals

- Modeling application-specific domain concepts
- Installing platform operators such as External Secrets Operator, Prometheus Operator, KEDA, or Gateway API controllers
- Replacing purpose-built charts for databases, brokers, or applications with complex bootstrap logic
- Managing cloud resources, DNS providers, certificate issuers, or provider-side secret stores
- Providing universal production defaults for every workload type

<!-- @AI-METADATA
type: design
title: Generic Chart Design
description: Design document for the generic multi-workload Helm chart

keywords: generic, design, deployment, statefulset, daemonset, batch, external-secrets

purpose: Document architecture, chart boundaries, and production choices for the generic Helm chart
scope: Chart Design

relations:
  - charts/generic/README.md
  - charts/generic/docs/deployment.md
  - charts/generic/docs/security.md
  - charts/generic/docs/observability.md
path: charts/generic/DESIGN.md
version: 1.0
date: 2026-06-09
-->
