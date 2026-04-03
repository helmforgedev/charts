<p align="center">
  <img src="docs/images/helmforge_banner.svg" alt="HelmForge" width="960" />
</p>

<h1 align="center">HelmForge Charts</h1>

<p align="center">
  Open-source Helm charts, forged to last.
</p>

<p align="center">
  <a href="https://github.com/helmforgedev/charts/actions/workflows/ci.yml"><img src="https://github.com/helmforgedev/charts/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
  <a href="https://github.com/helmforgedev/charts/actions/workflows/publish.yml"><img src="https://github.com/helmforgedev/charts/actions/workflows/publish.yml/badge.svg" alt="Publish" /></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT" /></a>
  <a href="https://artifacthub.io/packages/search?repo=helmforge"><img src="https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/helmforge" alt="Artifact Hub" /></a>
  <img src="https://img.shields.io/badge/Helm-3-blue?logo=helm" alt="Helm 3" />
  <img src="https://img.shields.io/badge/Kubernetes-≥1.26-blue?logo=kubernetes" alt="Kubernetes >=1.26" />
  <a href="CONTRIBUTING.md"><img src="https://img.shields.io/badge/PRs-welcome-brightgreen" alt="PRs Welcome" /></a>
</p>

<p align="center">
  <a href="https://helmforge.dev">Website</a> · <a href="https://helmforge.dev/doc">Documentation</a> · <a href="https://repo.helmforge.dev">Helm Repository</a> · <a href="CONTRIBUTING.md">Contributing</a>
</p>

## Quick Start

### HTTPS repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm search repo helmforge/
helm install <release-name> helmforge/<chart-name> --version <version> -f values.yaml
```

### OCI registry

```bash
helm install <release-name> oci://ghcr.io/helmforgedev/helm/<chart-name> --version <version> -f values.yaml

# Show default values
helm show values oci://ghcr.io/helmforgedev/helm/<chart-name> --version <version>
```

Check each chart's README and [git tags](../../tags) for available versions.

## Why HelmForge

HelmForge is built on a simple principle: **use what upstream ships, nothing more**.

- **Official upstream images** — every chart uses the image published by the application maintainers. No custom rebuilds, no proprietary layers, no vendor-specific modifications.
- **Pinned version tags** — charts reference explicit, immutable image tags. No `:latest`, no floating tags, no surprises after a pull.
- **MIT licensed** — the charts, the CI, the docs — everything is MIT. No open-core, no paid tiers, no license changes down the road.
- **Cosign signed** — every OCI artifact is signed with [Sigstore Cosign](https://www.sigstore.dev/) keyless signing via GitHub Actions OIDC. Verify before you deploy.
- **No vendor lock-in** — standard Helm, standard Kubernetes APIs, standard images. If you stop using HelmForge tomorrow, nothing breaks.
- **Simple, explicit values** — product-oriented `values.yaml` files that map directly to the application's configuration. What you see is what you get.

## Charts

50+ production-ready charts covering databases, authentication, CMS, analytics, automation, and more.

Browse the full catalog with descriptions, install commands, and playground configs at **[helmforge.dev/docs/charts](https://helmforge.dev/docs/charts)**.

## CI/CD

Charts are automatically tested and published via two GitHub Actions workflows.

```text
PR        --> ci.yml      --> [Lint] [Template] [Kubeconform]
Push main --> publish.yml --> Detect --> Semver --> Package --> Publish to GHCR + Pages --> Git tag
```

Both workflows dynamically detect which charts changed and run jobs only for those charts using a matrix strategy. Changes to docs (`README.md`, `examples/`, `docs/`) are ignored.

### Versioning

Versions are calculated automatically from Conventional Commits affecting each chart.

| Commit prefix | Bump | Example |
|---------------|------|---------|
| `fix:`, `docs:`, `refactor:` | PATCH | `fix(generic): correct HPA indentation` |
| `feat:` | MINOR | `feat(generic): add DaemonSet support` |
| `feat!:` or `BREAKING CHANGE` | MAJOR | `feat(generic)!: restructure workload config` |

Tags follow the format `{chart}-v{version}` (for example `generic-v1.2.3`).

### Release Notes

Every chart release automatically creates a [GitHub Release](https://github.com/helmforgedev/charts/releases) with categorized notes generated from Conventional Commits:

- **Breaking Changes** — commits with `!:` or `BREAKING CHANGE`
- **Features** — `feat(...):`
- **Bug Fixes** — `fix(...):`
- **Other Changes** — `docs`, `refactor`, `ci`, etc.

Each release includes install instructions for both OCI and Helm repository.

### Testing

Each chart includes a `ci/` directory with test values files. The pipeline runs `helm template` against every `ci/*.yaml` file automatically, in addition to default values, lint, and kubeconform schema validation.

### Kubernetes Compatibility

All charts require **Helm 3** (`apiVersion: v2`) and target **Kubernetes 1.26+**.

| Kubernetes Version | Status |
|--------------------|--------|
| 1.26.x | Supported (minimum) |
| 1.27.x | Supported |
| 1.28.x | Supported |
| 1.29.x | Supported |
| 1.30.x | Supported |
| 1.31.x | Supported |
| 1.32.x | Supported |
| 1.33.x | Supported |
| 1.34.x | Supported |
| 1.35.x | Supported |

CI validates rendered manifests with [kubeconform](https://github.com/yannh/kubeconform) against the default Kubernetes JSON schemas. Local validation uses [k3d](https://k3d.io/) clusters.

Charts use standard stable APIs (`apps/v1`, `batch/v1`, `networking.k8s.io/v1`) and avoid alpha/beta API versions to maximize compatibility.

## Contributing

Contributions are welcome. Please read the [contributing guide](CONTRIBUTING.md) for branch flow, validation requirements, commit conventions, and chart standards.

## License

MIT

<!-- @AI-METADATA
type: overview
title: HelmForge Charts
description: Helm chart repository overview, installation, charts list, and CI/CD

keywords: helm, charts, oci, ghcr, repository, install

purpose: Repository overview with charts list, installation, CI/CD, and contributing guide
scope: Repository

relations:
  - .claude/AGENTS.md
  - docs/testing-strategy.md
path: README.md
version: 1.0
date: 2026-04-01
-->
