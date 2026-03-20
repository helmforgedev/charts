---
title: Testing Strategy
description: Helm chart testing strategy using helm-unittest, helm lint, kubeconform, and CI automation
keywords: [helm-unittest, testing, unit-test, ci, kubeconform, lint, validation, bdd, yaml]
scope: repository
audience: contributors, ai-agents
---

# Testing Strategy

This repository uses a layered testing approach for Helm charts, combining static analysis, unit testing, and schema validation.

## Testing Layers

| Layer | Tool | Purpose | When |
|-------|------|---------|------|
| Lint | `helm lint --strict` | Catch YAML/template syntax errors | Every PR, local dev |
| Template | `helm template` | Verify templates render without errors | Every PR, local dev |
| Unit Test | `helm-unittest` | Assert template output matches expectations | Every PR, local dev |
| Schema Validation | `kubeconform` | Validate rendered manifests against K8s API schemas | Every PR |

## helm-unittest

[helm-unittest](https://github.com/helm-unittest/helm-unittest) is a BDD-style unit test framework for Helm charts, installed as a Helm plugin.

### Installation

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest
```

### Running Tests

```bash
# Single chart
helm unittest charts/<chart-name>

# All charts
helm unittest charts/*
```

### Test File Location

Test files live under `charts/<chart-name>/tests/` with the naming convention `<template-name>_test.yaml`.

```
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
  - <dependency-template>.yaml   # if primary includes other templates
release:
  name: test
  namespace: default
tests:
  - it: should <expected behavior>
    template: <primary-template>.yaml  # required when multiple templates listed
    set:
      key: value
    asserts:
      - <assertion-type>:
          <assertion-params>
```

### Key Patterns

#### Multi-template dependencies

When a template uses `include` to reference another template (e.g., for checksum annotations), both templates must be listed in the suite's `templates` array. Use the `template` field at the test level to target assertions at the correct template:

```yaml
templates:
  - statefulset-primary.yaml
  - configmap.yaml          # needed because statefulset includes configmap checksum
tests:
  - it: should be a StatefulSet
    template: statefulset-primary.yaml   # target only the statefulset
    asserts:
      - isKind:
          of: StatefulSet
```

#### Multi-document templates

When a single template renders multiple YAML documents (separated by `---`), use `documentIndex` or `documentSelector` at the test level:

```yaml
# By index
- it: should have headless service
  documentIndex: 0
  asserts:
    - equal:
        path: metadata.name
        value: test-redis-headless

# By content (preferred when order is not guaranteed)
- it: should target the StatefulSet
  documentSelector:
    path: kind
    value: StatefulSet
  asserts:
    - equal:
        path: spec.replicas
        value: 1
```

#### Conditional resources

Test both the enabled and disabled states of optional resources:

```yaml
- it: should not create NetworkPolicy by default
  asserts:
    - hasDocuments:
        count: 0

- it: should create NetworkPolicy when enabled
  set:
    networkPolicy.enabled: true
  asserts:
    - isKind:
        of: NetworkPolicy
```

#### Complex conditional PDBs

Some PDBs require multiple conditions (e.g., `pdb.enabled` AND `replicaCount > 1`). Always test the edge case where only one condition is met:

```yaml
- it: should not create PDB with single replica even when enabled
  set:
    pdb.enabled: true
  asserts:
    - hasDocuments:
        count: 0

- it: should create PDB with multiple replicas when enabled
  set:
    pdb.enabled: true
    replicaCount: 3
  asserts:
    - isKind:
        of: PodDisruptionBudget
```

### Common Assertion Types

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

### Pitfalls

1. **`protocol: TCP`** — Kubernetes adds `protocol: TCP` by default when the template does not specify it. If the rendered output includes `protocol: TCP`, the `contains` assertion must include it too, or it will fail.

2. **`documentIndex` scope** — `documentIndex` is scoped per-template, not across all rendered templates. When using suite-level `documentIndex`, it only works reliably if the suite targets a single template file.

3. **`template` filter** — When multiple templates are listed in the suite, always use `template: <file>.yaml` at the test level to avoid assertions running against all rendered templates.

4. **`stringData` vs `data`** — Some secrets use `stringData` (plain text) instead of `data` (base64). Check the actual template output before writing assertions.

5. **Include dependencies** — Templates that use `include (print $.Template.BasePath "/secret.yaml")` will fail rendering if `secret.yaml` is not in the `templates` list.

## CI Pipeline

The CI workflow (`.github/workflows/ci.yml`) runs these jobs for every PR:

```
detect → lint (parallel)
       → template (parallel)
       → unittest (parallel)
       → kubeconform (after template)
       → ci (gate)
```

The `unittest` job skips charts without a `tests/` directory, allowing incremental adoption.

## Local Validation Checklist

Before pushing chart changes:

```bash
helm lint charts/<name> --strict
helm template test charts/<name>
helm unittest charts/<name>
for f in charts/<name>/ci/*.yaml; do helm template test charts/<name> -f "$f"; done
```

<!-- @AI-METADATA
type: guide
title: Testing Strategy
description: Helm chart testing strategy using helm-unittest, helm lint, kubeconform, and CI automation

keywords: helm-unittest, testing, unit-test, ci, kubeconform, lint, validation, bdd, yaml

purpose: Testing strategy documentation covering helm-unittest, helm lint, kubeconform, and CI
scope: Testing

relations:
  - AGENTS.md
  - .claude/CLAUDE.md
path: docs/testing-strategy.md
version: 1.0
date: 2026-03-20
-->
