---
title: Agent Instructions
description: AI agent rules for Helm chart development, git workflow, and testing
keywords: [agents, ai, rules, conventions, git, helm, testing]
scope: repository
audience: ai-agents
---

# Agent Instructions

Instructions for AI coding agents working on this repository.

## Repository Overview

This repository contains reusable Helm charts published as OCI artifacts to `ghcr.io/helmforgedev/helm` and as a traditional Helm repository at `https://repo.helmforge.dev`. The public project website is `https://helmforge.dev`, and contributor/user documentation lives at `https://helmforge.dev/doc`. Each chart lives under `charts/<name>/` with its own `Chart.yaml`, `values.yaml`, `templates/`, `tests/`, `ci/`, `examples/`, `docs/`, and `README.md`.

## Repository Layout

```text
charts/<chart-name>/
  Chart.yaml
  values.yaml
  templates/
  tests/          # helm-unittest test suites
  ci/
  examples/
  docs/
  README.md
docs/
  testing-strategy.md
.github/workflows/
  ci.yml
  publish.yml
```

## Workflow Rules

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | Pull requests | `helm lint --strict`, `helm template`, `helm unittest`, `kubeconform` |
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
- always open pull requests from the working branch to `main`
- never open pull requests from one feature branch to another branch

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

Required git flow for agents:

1. create a branch from `main`
2. if the previous branch for the same work was merged, stop using that feature branch and return to `main`
3. run `git checkout main` and `git pull --ff-only origin main` immediately before creating the next branch
4. create the new branch from the updated local `main`, never from an older feature branch even if it looks equivalent
5. make the change
6. commit all intended files with the correct conventional commit
7. if the current branch already has an open PR, check the PR status before pushing
8. push the branch to origin
9. if no PR exists yet, open the PR targeting `main`

Do not use stacked PRs or branch-to-branch PRs in this repository.

Important:

- after a PR is merged, do not continue the next phase from that old feature branch
- always start the next phase from the current `main`
- branching from a previously merged feature branch is a common source of unnecessary README and values conflicts in this repository
- before starting the next phase for the same chart or workstream, verify that the previous PR was merged and that local `main` was refreshed from `origin/main`
- in this repository, `main` may advance again immediately after merge because the publish workflow creates release commits; a stale local `main` can conflict even if you think you branched from `main`
- when a chart PR was merged recently, assume both the merge commit and an automated release commit may exist on `main` until verified otherwise

## Helm Chart Authoring Rules

- design each chart around the application, not around the `generic` chart
- use upstream product docs and mature public charts as references, not as copy sources
- keep `values.yaml` small, explicit, and product-oriented
- document default `values.yaml` keys with inline comments following the repository pattern used by the existing charts
- use `_helpers.tpl` to remove duplication inside one chart
- avoid cross-chart abstraction unless it is clearly stable and justified
- document supported architectures and explicit non-goals before expanding template surface
- if a chart supports materially different architectures, document each architecture in `docs/`
- if a solution has a UI or web entrypoint, the chart must expose configurable ingress support with `ingressClassName`
- for UI/web solutions, default `ingressClassName` can be `traefik`, but docs must state that operators may use `traefik`, `nginx`, or another cluster-supported ingress class
- before pushing changes on a branch that already has an open PR, always validate whether that PR is still open, merged, closed, or obsolete

## Validation Commands

```bash
helm lint charts/<chart-name> --strict
helm template test-release charts/<chart-name>
helm unittest charts/<chart-name>
helm template test-release charts/<chart-name> -f charts/<chart-name>/ci/<test-file>.yaml
helm template test-release charts/<chart-name> | kubeconform -strict -summary
for f in charts/<chart-name>/ci/*.yaml; do helm template test-release charts/<chart-name> -f "$f"; done
```

## Unit Testing with helm-unittest

Tests live under `charts/<chart-name>/tests/` with naming `<template>_test.yaml`. See `docs/testing-strategy.md` for the full guide.

Critical rules:

- when a template uses `include` to reference another template, add the dependency to the suite `templates` list and use `template:` at each test level
- `documentIndex` is per-template, not global across all rendered templates
- Kubernetes adds `protocol: TCP` by default; `contains` assertions must match it
- check whether secrets use `data` (base64) or `stringData` (plain text)
- test conditional resources in both enabled and disabled states
- some PDBs require multiple conditions (e.g., `pdb.enabled` AND `replicaCount > 1`)
- always run `helm unittest charts/<chart-name>` before pushing

## Adding a New Chart

1. Research the official product documentation and mature public charts.
2. Define the product proposal, supported topologies, and non-goals.
3. Create `Chart.yaml`, `values.yaml`, `templates/`, `tests/`, `ci/`, `examples/`, `docs/`, and `README.md`.
4. Build templates that match the real product contract, not a generic abstraction.
5. Add helm-unittest test suites for all key templates (workload, service, secret, optional resources).
6. Add CI scenarios for each supported topology.
7. Add examples that reflect realistic usage.
8. Update the root `README.md` charts table.
9. Run validation locally before pushing.
10. Push and open a PR, wait for CI to pass.
11. Deploy and validate the chart on a local k3d cluster **before merging the PR**. Install the chart with default values and at least one non-default CI scenario, verify pods are running and the application is reachable. Fix any issues found before merging.
12. Merge the PR only after k3d validation succeeds.

## Modifying an Existing Chart

1. Render before and after the change when behavior could regress.
2. Ensure all `ci/*.yaml` files still render correctly.
3. Run `helm lint --strict` and `helm unittest charts/<name>`.
4. Update or add unit tests when template behavior changes.
5. Update chart docs when behavior, defaults, or supported topologies changed.
6. Use a conventional commit with the correct scope.

## Documentation Rules

- all repository documentation must be written in English
- root `README.md`: contributor-facing repository behavior, generic commands, no hardcoded chart versions
- `charts/<name>/README.md`: install, features, values, examples, operational usage
- `charts/<name>/docs/*.md`: architecture-specific operational guidance
- chart README files must document the main default values, not only the feature overview
- chart docs are exclusive to the chart itself; do not reference local filesystem paths, personal machine paths, or unrelated repository paths
- use relative links for files inside the same chart, such as `docs/*.md` and `examples/*`
- when external references are needed in chart docs, use only official product or official project documentation
- always document ingress examples in `values.yaml` using `hosts`, `ingressClassName`, and `tls[].secretName` in the Kubernetes-native shape
- always use `ingressClassName` as the values key for ingress class selection in Helm charts
- whenever a chart documents ingress in `values.yaml`, add a commented annotation example using `cert-manager.io/cluster-issuer`
- do not add design-history documents for users
- when a new stable rule is discovered during real work, update the smallest relevant standard document in the same branch

## AI Metadata Standard

Every markdown documentation file must include an `<!-- @AI-METADATA -->` HTML comment block at the very end. See `docs/ai-metadata-standard.md` for the full specification.

Required actions:

- when creating a new markdown file, always append an `@AI-METADATA` block with the correct `type`, `title`, `description`, `keywords`, `purpose`, `scope`, `relations`, `path`, `version`, and `date`
- when editing an existing file, never remove the `@AI-METADATA` block; update `date` on significant changes
- use the correct type: `overview`, `chart-readme`, `chart-docs`, `design`, `guide`, `agent-instructions`, `skill-definition`, `issue-template`
- use relative paths from repo root for `path` and `relations`

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

<!-- @AI-METADATA
type: agent-instructions
title: Agent Instructions
description: AI agent rules for Helm chart development, git workflow, and testing

keywords: agents, ai, rules, conventions, git, helm, testing

purpose: AI agent rules for Helm chart development, git workflow, testing, and validation
scope: Repository

relations:
  - .claude/CLAUDE.md
  - docs/testing-strategy.md
path: AGENTS.md
version: 1.0
date: 2026-03-20
-->
