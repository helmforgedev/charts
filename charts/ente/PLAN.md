# Ente - Implementation Plan

**Chart:** `ente`
**Issue:** [#980](https://github.com/helmforgedev/charts/issues/980)
**Target chart version:** `1.0.0`
**Target maturity:** `stable`
**Complexity:** High

## Executive Summary

Create a production-ready Ente Photos chart around the official Museum and web
images. The chart will provide a secure single-instance default, an explicit HA
topology, HelmForge PostgreSQL, external PostgreSQL support, mandatory external
S3 configuration, stable cryptographic secrets, modern Kubernetes exposure,
observability, backup automation, and complete operational documentation.

## Scope

The chart deploys:

- Museum API and its optional singleton background worker.
- One web Deployment serving the selected Ente Photos applications.
- A HelmForge PostgreSQL dependency by default or an external PostgreSQL service.
- Services, Ingress, Gateway API routes, policy, observability, and backup jobs.

The chart does not deploy an S3 server, SMTP server, or Ente's Paste and Locker
products. These are separate operational domains and should not be hidden inside
an Ente Photos release.

## Priority 1: Functional MVP

### P1-1: Museum API

- Render a complete upstream `museum.yaml`.
- Source credentials from a stable generated Secret or an existing Secret.
- Configure `/ping` startup/readiness and TCP liveness probes.
- Apply non-root, read-only runtime security.

### P1-2: PostgreSQL

- Depend on HelmForge PostgreSQL `2.0.4` by default.
- Support external PostgreSQL with TLS mode and Secret key mapping.
- Wait for the database before Museum starts.

### P1-3: External S3

- Require endpoint, region, bucket, access key, and secret key.
- Support path-style addressing for compatible providers.
- Keep MinIO outside the chart and use it only as a k3d fixture.

### P1-4: Web applications

- Run one official web image with Photos, Accounts, and Albums enabled.
- Expose selected application ports through Kubernetes Services.
- Configure `ENTE_API_ORIGIN` consistently.

### P1 validation gate

Before production templates are added:

1. Resolve dependencies and run strict lint/schema rendering.
2. Install the chart in k3d with an external MinIO fixture.
3. Confirm PostgreSQL, Museum `/ping`, and each default web app are ready.
4. Confirm secrets remain unchanged after `helm upgrade`.
5. Exercise an S3 write/read operation using chart credentials.

## Priority 2: Production Features

### P2-1: Safe high availability

- Provide API replicas with cron disabled.
- Provide exactly one cron-enabled worker Deployment with `Recreate` strategy.
- Add API PDB, HPA, topology spread, affinity, and anti-affinity controls.
- Fail rendering for unsafe combinations.

### P2-2: Exposure

- Support per-application Ingress hosts with TLS.
- Support Gateway API HTTPRoutes and reusable parent references.
- Support dual-stack Service settings.

### P2-3: Secret management

- Support one existing Secret contract for all Museum credentials.
- Support External Secrets Operator `items[]` with complete specs.
- Detect duplicate generated ExternalSecret names.

### P2-4: Network security

- Add NetworkPolicy for Museum and web workloads.
- Model DNS, PostgreSQL, S3, SMTP, ingress-controller, monitoring, and custom
  egress without making public-network assumptions.

### P2-5: Observability

- Expose Museum metrics through a separate Service.
- Add opt-in ServiceMonitor and PrometheusRule.
- Document logs and actionable alerts.

### P2-6: Backup

- Add an opt-in PostgreSQL dump-to-S3 CronJob.
- Reuse external backup credentials without conflating them with Ente storage.
- Document S3 object backup and complete restore ordering.

## Priority 3: Quality And Operations

- Full `values.schema.json` coverage.
- At least 40 focused helm-unittest cases.
- Eight to ten CI values scenarios.
- Five or more complete examples.
- Dedicated guides for architecture, S3, HA, security, backup, and operations.
- A 150-200 line `NOTES.txt` with eight operational sections.
- A comprehensive chart README.
- Stable site catalog entry, official icon, playground scenarios, and an
  800-line minimum documentation page with all required sections.

## Planned Chart Structure

```text
charts/ente/
|-- Chart.yaml
|-- Chart.lock
|-- values.yaml
|-- values.schema.json
|-- README.md
|-- RESEARCH.md
|-- PLAN.md
|-- ci/
|-- docs/
|-- examples/
|-- tests/
`-- templates/
    |-- _helpers.tpl
    |-- validate.yaml
    |-- configmap.yaml
    |-- secret.yaml
    |-- externalsecret.yaml
    |-- museum-api-deployment.yaml
    |-- museum-worker-deployment.yaml
    |-- web-deployment.yaml
    |-- services.yaml
    |-- ingress.yaml
    |-- gateway-httproute.yaml
    |-- networkpolicy.yaml
    |-- pdb.yaml
    |-- hpa.yaml
    |-- servicemonitor.yaml
    |-- prometheusrule.yaml
    |-- backup-cronjob.yaml
    |-- serviceaccount.yaml
    |-- extra-manifests.yaml
    `-- NOTES.txt
```

## Validation Strategy

### Static gates

- `helm dependency build`
- `helm lint --strict` for defaults and every `ci/*.yaml`
- `helm template` and JSON schema validation
- `helm unittest`
- `kubeconform` against installed CRD schemas
- Artifact Hub lint
- SPDX and HelmForge standards checks

### Behavioral gates

- Default single-instance install.
- External PostgreSQL render and connection contract.
- ESO render against the installed fake ClusterSecretStore.
- Ingress and Gateway API routes.
- HA API plus singleton worker rollout.
- Metrics discovery.
- NetworkPolicy-enabled startup and S3 access.
- Backup CronJob execution against the fixture.
- Secret preservation across upgrade.
- API and web smoke checks.

The final mandatory gate is:

```shell
make validate-chart CHART=ente
```

## Documentation Plan

Chart documentation will cover:

1. Architecture.
2. Installation.
3. Initial secret preparation.
4. PostgreSQL modes.
5. S3 providers and CORS.
6. SMTP and one-time codes.
7. Web application hosts.
8. Ingress.
9. Gateway API.
10. High availability.
11. Security and NetworkPolicy.
12. Observability.
13. Backup and restore.
14. Upgrade procedures.
15. Troubleshooting with at least ten cases.

## Acceptance Criteria

- The chart is marked `helmforge.dev/maturity: stable`.
- All images are official, pinned, and verified multi-architecture images.
- No critical credential changes during an ordinary upgrade.
- Default and production examples pass the full local validation gate.
- HA never runs more than one cron-enabled worker.
- S3 is clearly external and validated as a production dependency.
- Chart and site documentation satisfy the new-chart requirements.
- No unresolved validation warnings remain.
