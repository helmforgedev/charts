# Agent Instructions

Instructions for AI coding agents working on this repository.

## Repository Overview

This repository contains reusable Helm charts published as OCI artifacts to `ghcr.io/mberlofa/helm`. Each chart lives under `charts/<name>/` with its own `Chart.yaml`, `values.yaml`, `templates/`, `ci/`, `examples/`, `docs/`, and `README.md`.

## Repository Layout

```text
charts/<chart-name>/
  Chart.yaml
  values.yaml
  templates/
  ci/
  examples/
  docs/
  README.md
.github/workflows/
  ci.yml
  publish.yml
```

## Workflow Rules

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | Pull requests | `helm lint --strict`, `helm template`, `kubeconform` |
| `publish.yml` | Push to `main`, `workflow_dispatch` | detect changed charts, bump semver, package, push to GHCR, create tag |

Changes to `charts/**/templates/`, `charts/**/values.yaml`, `charts/**/Chart.yaml`, and `charts/**/ci/` trigger CI and publish logic.

Changes to `README.md`, `examples/`, `docs/`, `AGENTS.md`, `.claude/CLAUDE.md`, and `.gitignore` do not trigger publish.

`Chart.yaml` version is managed by CI. Never edit chart version manually.

## Commit and PR Standard

Use Conventional Commits for commit messages and PR titles.

Chart-scoped changes:

```text
feat(chart-name): description
fix(chart-name): description
docs(chart-name): description
refactor(chart-name): description
feat(chart-name)!: description
```

Repository-wide changes:

```text
ci: description
docs(repo): description
refactor(repo): description
```

Rules:

- always use lowercase `type(scope): description`
- always scope chart changes to the exact chart directory name
- use the same convention for the PR title
- keep chart work and repository-instruction work in separate commits when practical
- do not mix unrelated charts in the same commit unless the change is truly shared

Examples:

```text
feat(redis): add dedicated redis chart
docs(redis): expand architecture usage guides
fix(mongodb): correct arbiter selectors
ci: tighten changed-chart detection
docs(repo): refine commit and agent standards
```

## Git Author

Always commit with the repository owner's configured git identity. Never change `user.name` or `user.email`.

When the agent materially contributed to the change, add this trailer:

```text
Co-Authored-By: OpenAI Codex <codex@openai.com>
```

## Branch Naming

Use branches that reflect the main scope:

```text
feat/<chart>-<description>
fix/<chart>-<description>
refactor/<chart>-<description>
docs/<scope>-<description>
ci/<description>
```

Examples:

```text
feat/redis-chart
fix/mongodb-readiness-probe
docs/repo-commit-standards
ci/publish-retry-loop
```

## Helm Chart Authoring Rules

- design each chart around the application, not around the `generic` chart
- use upstream product docs and mature public charts as references, not as copy sources
- keep `values.yaml` small, explicit, and product-oriented
- use `_helpers.tpl` to remove duplication inside one chart
- avoid cross-chart abstraction unless it is clearly stable and justified
- document supported architectures and explicit non-goals before expanding template surface
- if a chart supports materially different architectures, document each architecture in `docs/`

## Validation Commands

```bash
helm lint charts/<chart-name> --strict
helm template test-release charts/<chart-name>
helm template test-release charts/<chart-name> -f charts/<chart-name>/ci/<test-file>.yaml
helm template test-release charts/<chart-name> | kubeconform -strict -summary
for f in charts/<chart-name>/ci/*.yaml; do helm template test-release charts/<chart-name> -f "$f"; done
```

## Adding a New Chart

1. Research the official product documentation and mature public charts.
2. Define the product proposal, supported topologies, and non-goals.
3. Create `Chart.yaml`, `values.yaml`, `templates/`, `ci/`, `examples/`, `docs/`, and `README.md`.
4. Build templates that match the real product contract, not a generic abstraction.
5. Add CI scenarios for each supported topology.
6. Add examples that reflect realistic usage.
7. Update the root `README.md` charts table.
8. Run validation locally before pushing.

## Modifying an Existing Chart

1. Render before and after the change when behavior could regress.
2. Ensure all `ci/*.yaml` files still render correctly.
3. Run `helm lint --strict`.
4. Update chart docs when behavior, defaults, or supported topologies changed.
5. Use a conventional commit with the correct scope.

## Documentation Rules

- root `README.md`: contributor-facing repository behavior, generic commands, no hardcoded chart versions
- `charts/<name>/README.md`: install, features, values, examples, operational usage
- `charts/<name>/docs/*.md`: architecture-specific operational guidance
- do not add design-history documents for users
- when a new stable rule is discovered during real work, update the smallest relevant standard document in the same branch

## Repository Learning Loop

Agents must improve repository guidance when a real task exposes a reusable correction.

Update standards when all of these are true:

- the issue was corrected in actual work
- the correction is likely to recur
- the rule can be explained clearly and briefly

Preferred targets:

- `README.md` for contributor-visible repository rules
- `AGENTS.md` for repository-wide agent rules
- `.claude/CLAUDE.md` for tool-specific agent guidance
- chart docs for product-specific operational guidance
