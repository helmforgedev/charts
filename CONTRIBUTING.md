# Contributing

Thanks for contributing to HelmForge Charts.

This repository has a few workflow rules that are stricter than a typical Helm charts repo because chart publishing, versioning, and release notes are automated.

## Before You Start

- write all repository documentation in English
- use `main` as the only PR target
- never edit `version` in `Chart.yaml` manually
- use [Conventional Commits](https://www.conventionalcommits.org/) for commits and PR titles
- for chart changes, use the exact chart directory name as the scope, for example:
  - `feat(redis): add replication topology`
  - `fix(mongodb): correct readiness probe`
  - `docs(repo): refine contribution guidance`

## Branch And PR Flow

Always follow this sequence:

1. `git checkout main`
2. `git pull --ff-only origin main`
3. create a new branch from the updated `main`
4. make the change
5. validate locally
6. commit with a Conventional Commit
7. push the branch
8. open a PR to `main`

Rules:

- never open branch-to-branch PRs
- do not continue new work from an old merged feature branch
- after a PR is merged, return to `main` and start a fresh branch

Recommended branch names:

- `feat/<chart>-<description>`
- `fix/<chart>-<description>`
- `refactor/<chart>-<description>`
- `docs/<scope>-<description>`
- `ci/<description>`

## Adding A New Chart

When adding a new chart:

1. research official product docs and mature public charts
2. confirm the latest release in both official GitHub Releases and official Docker Hub tags
3. only pin a version when both sources match
4. create:
   - `Chart.yaml`
   - `values.yaml`
   - `values.schema.json`
   - `templates/`
   - `tests/`
   - `ci/`
   - `examples/`
   - `docs/`
   - `README.md`
5. update the root [README.md](README.md) charts table
6. update the `site/` repository in the same workstream
7. validate locally on `k3d` before pushing the PR

## Modifying An Existing Chart

When changing an existing chart:

- run `helm lint --strict`
- run `helm unittest`
- render all `ci/*.yaml` scenarios
- update tests when template behavior changes
- update `values.schema.json` when values change
- update chart docs when behavior or defaults change
- update the `site/` repository when the change affects public docs, chart listing, or maturity

## Required Local Validation

Before any local runtime validation:

- run `kubectl config current-context`
- confirm the active context is the intended local `k3d` cluster
- never install, upgrade, or uninstall against a non-local or unclear context

Required commands for chart work:

```bash
helm lint charts/<chart-name> --strict
helm template test-release charts/<chart-name>
helm unittest charts/<chart-name>
for f in charts/<chart-name>/ci/*.yaml; do helm template test-release charts/<chart-name> -f "$f"; done
```

Shortcut script (runs the same checks and prints a PR checklist snippet):

```bash
./test.sh <chart-name>
./test.sh --all
```

For every new chart and every release update:

- local `k3d` validation is mandatory before pushing the PR
- validate the default install
- validate at least one main non-default supported scenario
- if the chart includes backup behavior, validate it end-to-end against local MinIO

## Chart Standards

Every chart must:

- include Artifact Hub annotations in `Chart.yaml`
- include `helmforge.dev/maturity` in `Chart.yaml`
- include `values.schema.json` using JSON Schema draft-07
- document `values.yaml` keys using `# --` comments
- use product-oriented values and templates rather than generic abstraction

## Site Sync

If you add a new chart, you must also update the `site/` repository.

If you change public chart metadata or user-visible behavior, update the `site/` repository when the website should reflect that change, including:

- new chart pages
- chart cards / listings
- sidebar entries
- maturity changes

## Releases

Releases are automated by GitHub Actions.

Do not:

- create git tags manually
- create GitHub Releases manually
- edit `version` in `Chart.yaml`

Conventional Commits drive semantic versioning and release notes.

## Related Docs

- [README.md](README.md)
- [SECURITY.md](SECURITY.md)
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- [GOVERNANCE.md](GOVERNANCE.md)
- [MAINTAINERS.md](MAINTAINERS.md)
- [ADOPTERS.md](ADOPTERS.md)

<!-- @AI-METADATA
type: guide
title: Contributing
description: Contribution guide for HelmForge Charts covering git flow, validation, and chart-specific standards

keywords: contributing, pull requests, git flow, helm, charts, validation

purpose: Explain how humans should contribute to the HelmForge Charts repository
scope: Repository

relations:
  - README.md
  - .claude/AGENTS.md
  - SECURITY.md
  - CODE_OF_CONDUCT.md
  - GOVERNANCE.md
  - MAINTAINERS.md
  - ADOPTERS.md
path: CONTRIBUTING.md
version: 1.2
date: 2026-04-27
-->
