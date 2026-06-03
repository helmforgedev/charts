# Contributing

Thanks for contributing to HelmForge Charts.

This repository has stricter rules than a typical Helm charts repo because chart publishing, semantic versioning, security checks, and release notes are automated.

## Before You Start

- Write all repository documentation in English.
- Use `main` as the only PR target.
- Create or link a GitHub issue for every PR.
- Never edit `version` in `Chart.yaml` manually.
- Use [Conventional Commits](https://www.conventionalcommits.org/) for commits and PR titles.
- For chart changes, use the exact chart directory name as the scope.
  Good examples are `feat(redis): add replication topology`, `fix(mongodb): correct readiness probe`, and `docs(repo): refine contribution guidance`.

## Branch And PR Flow

Always follow this sequence:

1. `git checkout main`
2. `git pull --ff-only origin main`
3. Create a new branch from the updated `main`.
4. Make the change.
5. Validate locally.
6. Commit with a Conventional Commit.
7. Push the branch.
8. Open a PR to `main` and link the required issue.
9. Wait for CI to finish.
10. Resolve or reply to every review comment.
11. Rerun local validation after every correction that changes chart behavior.

Rules:

- Never open branch-to-branch PRs.
- Do not continue new work from an old merged feature branch.
- After a PR is merged, return to `main` and start a fresh branch.
- Do not leave unresolved review comments or unanswered requested changes.
- Do not use `kubeconform --ignore-missing-schema`; install missing CRDs or provide schema coverage instead.

Recommended branch names:

- `feat/<chart>-<description>`
- `fix/<chart>-<description>`
- `refactor/<chart>-<description>`
- `docs/<scope>-<description>`
- `ci/<description>`

## Adding A New Chart

When adding a new chart:

1. Research official product docs and mature public charts.
2. Confirm the latest release in both official GitHub Releases and official image registry tags.
3. Only pin a version when both sources match.
4. Create `Chart.yaml`, `values.yaml`, `values.schema.json`, `templates/`, `tests/`, `ci/`, `examples/`, `docs/`, `README.md`, and `DESIGN.md`.
5. Add official chart icons using the repository icon standard.
6. Update the root [README.md](README.md) when the catalog overview changes.
7. Update the `site/` repository in the same workstream when public docs, listings, icons, or maturity change.
8. Validate locally on `k3d` before pushing the PR.

## Modifying An Existing Chart

When changing an existing chart:

- Run the current local validation helper: `./test.sh <chart-name>`.
- Update tests when template behavior changes.
- Update `values.schema.json` when values change.
- Update chart docs when behavior or defaults change.
- Update the `site/` repository when the change affects public docs, chart listing, icon, or maturity.
- Keep `README.md`, `DESIGN.md`, `docs/`, `examples/`, `ci/`, `tests/`, and `templates/NOTES.txt` aligned with the established chart standard.
- Prefer HelmForge subcharts for databases, caches, queues, and coordination services when the catalog already provides that dependency.
- Use the latest compatible HelmForge dependency versions in `Chart.yaml`.

## Required Local Validation

Before any local runtime validation:

- Run `kubectl config current-context`.
- Confirm the active context is the intended local `k3d-helmforge-tests-wsl` cluster or another clearly local `k3d-` context.
- Never install, upgrade, or uninstall against a non-local or unclear context.

Required command for chart work:

```bash
./test.sh <chart-name>
```

The helper runs the current local equivalent of the PR gates:

- `helm dependency build`
- `helm lint --strict`
- `helm template` with default values
- `helm template` for every `ci/*.yaml` scenario
- `kubeconform -strict` with Kubernetes schemas and CRD schemas from the Datree CRDs catalog
- `helm unittest --with-subchart=false` when `tests/` exists
- `ah lint -p`
- `kubescape scan framework "MITRE,NSA,SOC2"`

Optional runtime validation:

```bash
kubectl config current-context
./test.sh <chart-name> --runtime -f charts/<chart-name>/ci/<scenario>.yaml
```

Runtime validation installs with `helm upgrade --install --wait --timeout 120s`, checks Kubernetes resources, recent events, and pod logs, then removes the namespace unless `--keep-namespace` is used.

For every new chart and every release update:

- Local `k3d` validation is mandatory before pushing the PR.
- Validate the default install.
- Validate at least one main non-default supported scenario.
- Restart relevant Deployments or StatefulSets when the change affects startup behavior, persistence, probes, or application configuration.
- Verify logs and namespace events do not contain warnings, startup failures, permission errors, probe failures, crash loops, or image pull failures.
- If the chart includes backup behavior, validate it end-to-end against local MinIO.

## Chart Standards

Every chart must:

- Include Artifact Hub annotations in `Chart.yaml`.
- Include `helmforge.dev/maturity` in `Chart.yaml`.
- Include `values.schema.json` using JSON Schema draft-07.
- Document `values.yaml` keys using `# --` comments.
- Use product-oriented values and templates rather than generic abstraction.
- Use `ingress.ingressClassName`, Gateway API HTTPRoute values, service dual-stack values, and External Secrets patterns consistently with established charts when those features make sense for the workload.
- Keep `templates/NOTES.txt` useful for operators, including access paths, credentials guidance, health checks, and next steps adapted to the chart.
- Avoid committing `Chart.lock` for charts that use dependencies; dependency resolution is handled during validation and release.

## Site Sync

If you add a new chart, you must also update the `site/` repository.

If you change public chart metadata or user-visible behavior, update the `site/` repository when the website should reflect that change, including:

- New chart pages
- Chart cards or listings
- Sidebar entries
- Maturity changes
- Icons and hosted logo assets
- Documentation examples

## Releases

Releases are automated by GitHub Actions.

Do not:

- Create git tags manually.
- Create GitHub Releases manually.
- Edit `version` in `Chart.yaml`.

Conventional Commits drive semantic versioning and release notes.

## PR Review And CI Completion

Before considering a PR complete:

- The PR title must pass the semantic PR title workflow.
- All CI, code quality, security, and governance checks must be green.
- Every review comment must be fixed or answered.
- Every requested change must be resolved in the PR conversation.
- The linked issue must be referenced in the PR body.
- Local validation evidence must be listed in the PR body or a follow-up comment.
- Runtime namespaces created during validation must be removed from the local cluster.

## Related Docs

- [README.md](README.md)
- [Local Testing with k3d](docs/local-testing-k3d.md)
- [Testing Strategy](docs/testing-strategy.md)
- [SECURITY.md](SECURITY.md)
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- [GOVERNANCE.md](GOVERNANCE.md)
- [MAINTAINERS.md](MAINTAINERS.md)
- [ADOPTERS.md](ADOPTERS.md)

<!-- @AI-METADATA
type: guide
title: Contributing
description: Contribution guide for HelmForge Charts covering git flow, validation, PR review, and chart-specific standards

keywords: contributing, pull requests, git flow, helm, charts, validation, k3d, kubeconform, kubescape

purpose: Explain how humans and agents should contribute to the HelmForge Charts repository
scope: Repository

relations:
  - README.md
  - docs/local-testing-k3d.md
  - docs/testing-strategy.md
  - .claude/AGENTS.md
  - SECURITY.md
  - CODE_OF_CONDUCT.md
  - GOVERNANCE.md
  - MAINTAINERS.md
  - ADOPTERS.md
path: CONTRIBUTING.md
version: 1.3
date: 2026-06-02
-->
