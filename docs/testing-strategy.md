# Testing Strategy

HelmForge uses layered validation for Helm charts.
Static checks catch template, schema, metadata, and security regressions before review.
Runtime checks on the local k3d cluster prove that workloads start, become ready, and do not produce bad events or logs.

For runtime testing details, see [Local Testing with k3d](local-testing-k3d.md).

## Testing Layers

| Layer | Tool | Purpose | Required |
|-------|------|---------|----------|
| Dependency build | `helm dependency build` | Resolve HelmForge subcharts and upstream dependencies | Every chart PR |
| Strict lint | `helm lint --strict` | Catch chart metadata, values, and template issues | Every chart PR |
| Default rendering | `helm template` | Verify default values render cleanly | Every chart PR |
| Scenario rendering | `helm template -f ci/*.yaml` | Verify supported modes and feature combinations | Every chart PR |
| Unit tests | `helm unittest --with-subchart=false` | Assert expected rendered resources and values | Charts with `tests/` |
| Schema validation | `kubeconform -strict` | Validate rendered manifests against Kubernetes and CRD schemas | Every chart PR |
| Artifact Hub lint | `ah lint -p` | Validate package metadata consumed by Artifact Hub | Every chart PR |
| Values quality | Custom CI checks | Detect floating image tags, missing schemas, and weak values contracts | Every PR |
| License headers | Custom CI checks | Enforce SPDX headers on changed YAML, template, and shell files | Every PR |
| Security scan | `kubescape` | Scan rendered chart output against MITRE, NSA, and SOC2 frameworks | Every chart PR |
| Runtime validation | `k3d`, `helm`, `kubectl` | Prove install, readiness, events, logs, and cleanup | New charts and risky fixes |

## Local Helper

Use the repository helper for normal local chart validation:

```bash
./test.sh <chart-name>
```

The helper mirrors the active PR gates:

- Builds dependencies.
- Runs `helm lint --strict`.
- Renders default values.
- Renders every `charts/<chart>/ci/*.yaml` scenario.
- Runs kubeconform on default and CI scenario renders.
- Runs helm-unittest when `tests/` exists.
- Runs Artifact Hub lint.
- Runs Kubescape and applies the minimum score gate.
- Prints a PR checklist snippet with the evidence expected in review.

Before running those gates, the helper verifies the tools required by the
selected options. Missing `helm`, `kubectl`, `kubeconform`, `ah`, and
`kubescape` binaries are installed into `~/.local/bin` by default, or into
`HELMFORGE_TOOLS_DIR` when set. If selected charts include `tests/`, the helper
also verifies and installs the `helm-unittest` plugin. Use `--no-install` to
disable this bootstrap and fail fast on missing tools.

To validate all charts without runtime installs:

```bash
./test.sh --all --skip-runtime
```

To validate a runtime scenario:

```bash
kubectl config current-context
./test.sh <chart-name> --runtime -f charts/<chart-name>/ci/<scenario>.yaml
```

Runtime mode must run against a local `k3d-` context.
The default expected cluster is `k3d-helmforge-tests-wsl`.

## kubeconform Policy

Never use `kubeconform --ignore-missing-schema`.

The repository validates rendered manifests with:

```bash
kubeconform -strict -summary \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  -exit-on-error
```

If a chart renders a CRD-backed resource, make schema validation work.
For runtime tests, install the CRD in the local cluster before installing the chart.

Common CRD-backed features include:

- Gateway API HTTPRoutes
- External Secrets
- ServiceMonitor, PodMonitor, and PrometheusRule
- KEDA ScaledObjects
- VerticalPodAutoscalers

## helm-unittest

[helm-unittest](https://github.com/helm-unittest/helm-unittest) is a BDD-style unit test framework for Helm charts.
It is installed as a Helm plugin.

### Installation

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest
```

### Running Tests

```bash
helm unittest --with-subchart=false charts/<chart-name>
```

Test files live under `charts/<chart-name>/tests/` with the naming convention `<template-name>_test.yaml`.

```text
charts/<chart-name>/
  templates/
    deployment.yaml
    service.yaml
  tests/
    deployment_test.yaml
    service_test.yaml
```

### Test Structure

```yaml
suite: <Suite Name>
templates:
  - <primary-template>.yaml
  - <dependency-template>.yaml
release:
  name: test
  namespace: default
tests:
  - it: should <expected behavior>
    template: <primary-template>.yaml
    set:
      key: value
    asserts:
      - <assertion-type>:
          <assertion-params>
```

## Unit Test Patterns

Multi-template dependencies:

Templates that use `include` for checksums or helper-rendered manifests need the referenced templates listed in the suite.
Use `template` at the test level to target assertions at the correct resource.

Multi-document templates:

Use `documentSelector` when one template emits more than one resource.
It is more stable than relying on document order.

Conditional resources:

Test both enabled and disabled states for optional resources such as NetworkPolicy, Ingress, HTTPRoute, ServiceMonitor, ExternalSecret, and PodDisruptionBudget.

Edge conditions:

PDBs, autoscalers, clustering, and backup resources often require multiple enabling conditions.
Test the negative edge case where only one condition is true.

## Common Assertion Types

| Assertion | Purpose |
|-----------|---------|
| `isKind` | Verify resource kind |
| `equal` | Exact value match at path |
| `contains` | Array contains an element |
| `notContains` | Array does not contain an element |
| `isNotNull` | Path exists and is not null |
| `isNull` | Path is null or missing |
| `hasDocuments` | Assert document count |
| `lengthEqual` | Assert array length |
| `matchRegex` | Value matches a regex pattern |

## CI Pipeline

The CI workflow (`.github/workflows/ci.yml`) runs these jobs for every relevant PR:

```text
detect
  -> lint
  -> template
  -> unittest
  -> artifacthub-lint
  -> kubeconform
  -> ci gate
```

Other required PR workflows include:

- `code-quality.yml` for Markdown lint, values quality, and SPDX license headers.
- `security-scan.yml` for Kubescape MITRE, NSA, and SOC2 scanning.
- `pr-governance.yml` for semantic PR title checks and labels.

Documentation-only changes are intentionally excluded from chart rendering jobs when they do not affect chart behavior.

## Runtime Evidence

For new charts, release updates, and fixes that affect startup or configuration, collect runtime evidence from the local k3d cluster:

```bash
kubectl config current-context
./test.sh <chart-name> --runtime -f charts/<chart-name>/ci/<scenario>.yaml
```

The install must use `--wait --timeout 120s`.
Do not wait for long-running failed installs without checking resource status.
Inspect pods, events, and logs after roughly 60 seconds if rollout is not progressing.

Runtime evidence must confirm:

- Workloads are Ready or Complete as expected.
- Services and endpoints exist when the chart exposes traffic.
- PVCs are Bound when persistence is enabled.
- Namespace events do not contain warnings or failures.
- Pod logs do not contain startup errors, permission errors, crash loops, or probe failures.
- The test namespace was removed after validation.

## Pitfalls

- Kubernetes defaults `protocol: TCP` when a Service port omits it.
  Include `protocol: TCP` in `contains` assertions when the rendered output includes it.
- `documentIndex` is scoped per template.
  Prefer `documentSelector` when order is not important.
- Templates that reference other templates through `include (print $.Template.BasePath "/secret.yaml")` must list those files in the test suite.
- Some Secrets use `stringData` instead of base64 encoded `data`.
  Render the chart before writing assertions.
- Charts with dependencies should not commit `Chart.lock`.
  Dependency build is part of validation and release.

<!-- @AI-METADATA
type: guide
title: Testing Strategy
description: Helm chart testing strategy using test.sh, helm-unittest, helm lint, kubeconform, Artifact Hub lint, Kubescape, and k3d validation

keywords: helm-unittest, testing, unit-test, ci, kubeconform, lint, validation, kubescape, artifacthub, k3d

purpose: Testing strategy documentation covering local and CI validation for HelmForge charts
scope: Testing

relations:
  - ../CONTRIBUTING.md
  - local-testing-k3d.md
  - ../test.sh
  - ../.github/workflows/ci.yml
  - ../.github/workflows/code-quality.yml
  - ../.github/workflows/security-scan.yml
path: docs/testing-strategy.md
version: 1.1
date: 2026-06-02
-->
