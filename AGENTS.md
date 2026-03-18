# Agent Instructions

Instructions for AI coding agents (Claude Code, Codex, etc.) working on this repository.

## Repository Overview

This repository contains reusable Helm charts published as OCI artifacts to `ghcr.io/mberlofa/helm`. Each chart lives under `charts/<name>/` with its own `Chart.yaml`, `values.yaml`, `templates/`, `ci/`, and `examples/`.

## Architecture

```
charts/<chart-name>/
  Chart.yaml          # Chart metadata and version (managed by CI, do not edit version manually)
  values.yaml         # Default values with documentation comments
  templates/          # Helm templates (Go templates)
    _helpers.tpl      # Reusable template helpers (DRY pattern)
    deployment.yaml
    ...
  ci/                 # Test values consumed by CI pipeline (helm template -f ci/*.yaml)
  examples/           # Real-world usage examples for users
  README.md           # Chart-specific documentation
.github/workflows/
  ci.yml              # PR validation: lint, template, kubeconform
  publish.yml         # Release: detect → semver → package → push GHCR → git tag
```

## Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | Pull requests | Validates charts: helm lint (strict), helm template (default + ci/*.yaml), kubeconform |
| `publish.yml` | Push to main, workflow_dispatch | Publishes charts: semver from conventional commits, OCI push to GHCR, git tag |

### What triggers workflows

- Changes to `charts/**/templates/`, `charts/**/values.yaml`, `charts/**/Chart.yaml`, `charts/**/ci/` trigger both CI and Publish.
- Changes to `charts/**/README.md`, `charts/**/examples/`, `charts/**/docs/` are **ignored** by both workflows.
- `Chart.yaml` version is managed by the publish workflow. Never edit it manually.

## Conventions

### Commit messages

This repo uses [Conventional Commits](https://www.conventionalcommits.org/) for automatic semantic versioning:

```
feat(chart-name): description     → MINOR bump
fix(chart-name): description      → PATCH bump
refactor(chart-name): description → PATCH bump
docs(chart-name): description     → PATCH bump
feat(chart-name)!: description    → MAJOR bump
```

Always scope commits to the chart name (e.g., `generic`, `redis-ha`).

### Branch naming

```
feat/<description>       # New features
fix/<description>        # Bug fixes
refactor/<description>   # Refactoring
docs/<description>       # Documentation only
```

## Helm Chart Development

### Key principles

- **DRY templates**: Use `_helpers.tpl` for shared logic. The `generic` chart uses `chart.containerSpec` and `chart.podSpec` helpers to avoid duplication across Deployment, StatefulSet, DaemonSet, Job, and CronJob.
- **Go template booleans**: Empty string is falsy, any non-empty string is truthy. Use `{{- if .Values.x -}}true{{- end -}}` pattern, never `{{- .Values.x -}}` which returns `"false"` (truthy).
- **Probes**: Global probes apply to the first container only. Jobs/CronJobs skip global probes via `skipGlobalProbes` flag.
- **Image tag formats**: `named` produces `repo:containerName-tag`, `simple` produces `repo:tag`.

### Validation commands

```bash
# Lint a chart
helm lint charts/<chart-name>
helm lint charts/<chart-name> --strict

# Template with default values
helm template test-release charts/<chart-name>

# Template with test values
helm template test-release charts/<chart-name> -f charts/<chart-name>/ci/<test-file>.yaml

# Validate against K8s schemas
helm template test-release charts/<chart-name> | kubeconform -strict -summary

# Test all ci/ values files
for f in charts/<chart-name>/ci/*.yaml; do
  echo "--- $f ---"
  helm template test-release charts/<chart-name> -f "$f"
done
```

### Adding a new chart

1. Create `charts/<name>/` with `Chart.yaml` (set version to `1.0.0`), `values.yaml`, `templates/`
2. Add CI test values in `ci/*.yaml` covering all workload types
3. Add usage examples in `examples/`
4. Create `README.md` with install command, features, and values reference
5. Run validation commands locally before pushing

### Modifying an existing chart

1. Run `helm template` before and after changes to compare output
2. Ensure all `ci/*.yaml` files still render correctly
3. Run `helm lint --strict` to catch warnings
4. Use conventional commit with chart scope: `fix(generic): description`

## Documentation Rules

### Root README (`README.md`)

- Lists all charts in a table (name + description, no version — versions change frequently)
- Contains generic commands with `<chart-name>` and `<version>` placeholders
- Documents CI/CD, versioning, and contributing guidelines
- **No chart-specific commands or configuration details**

### Chart README (`charts/<name>/README.md`)

- Chart-specific install command with exact OCI path
- Feature documentation, workload types, usage examples
- Complete values reference table
- Links to `examples/` directory

### When to update docs

- Adding a new chart → add row to root README charts table + create chart README
- Changing chart features → update chart README
- Changing CI/CD workflows → update root README CI/CD section
- **Never hardcode versions in READMEs** — they become stale immediately

## File Ignore Patterns

These files/directories do NOT trigger CI or publish workflows:

- `README.md` (any level)
- `examples/` directory
- `docs/` directory
- `AGENTS.md`, `CLAUDE.md`, `.gitignore`

Only changes to chart source files (`templates/`, `values.yaml`, `Chart.yaml`, `ci/`) trigger workflows.
