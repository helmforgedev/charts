<p align="center">
  <img src="docs/images/helmforge_banner.svg" alt="HelmForge" width="960" />
</p>

<h1 align="center">HelmForge Charts</h1>

<p align="center">
  Production-ready Helm charts for self-hosted and platform workloads.
</p>

<p align="center">
  <a href="https://github.com/helmforgedev/charts/actions/workflows/ci.yml"><img src="https://github.com/helmforgedev/charts/actions/workflows/ci.yml/badge.svg" alt="Tests" /></a>
  <a href="https://github.com/helmforgedev/charts/actions/workflows/publish.yml"><img src="https://github.com/helmforgedev/charts/actions/workflows/publish.yml/badge.svg" alt="Publish" /></a>
  <a href="https://www.apache.org/licenses/LICENSE-2.0"><img src="https://img.shields.io/badge/License-Apache--2.0-blue.svg" alt="License: Apache-2.0" /></a>
  <a href="https://artifacthub.io/packages/search?repo=helmforge"><img src="https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/helmforge" alt="Artifact Hub" /></a>
  <img src="https://img.shields.io/endpoint?url=https://repo.helmforge.dev/badges/charts-count.json" alt="Charts count" />
  <img src="https://img.shields.io/badge/Signed-GPG%20%2B%20Cosign-brightgreen" alt="GPG and Cosign signed" />
</p>

<p align="center">
  <a href="https://helmforge.dev">Website</a> |
  <a href="https://helmforge.dev/docs">Documentation</a> |
  <a href="https://repo.helmforge.dev">Helm Repository</a> |
  <a href="https://github.com/orgs/helmforgedev/packages?repo_name=charts">OCI Registry</a> |
  <a href="CONTRIBUTING.md">Contributing</a> |
  <a href="https://buymeacoffee.com/mberlofa">Support</a>
</p>

## What HelmForge Provides

HelmForge is a catalog of 89 Helm charts built around a consistent operating contract:
official upstream images, pinned versions, explicit values, reproducible validation, and signed releases.

Use HelmForge when you want charts that stay close to upstream applications while still behaving like a
maintained Kubernetes platform catalog.

- **Official upstream images**: charts prefer images published by the application maintainers.
- **Pinned image tags**: no `:latest`, floating tags, or surprise upgrades after a pull.
- **Explicit values contracts**: `values.yaml` and schema validation document what operators can configure.
- **Consistent dependencies**: databases, caches, queues, and platform services use HelmForge subcharts where available.
- **Signed releases**: packages include GPG provenance, and OCI artifacts are signed with Sigstore Cosign.
- **Apache-2.0 chart code**: charts, tests, examples, and docs use a permissive open-source license.

## Install

HelmForge publishes charts through both a standard HTTPS Helm repository and an OCI registry on GHCR.

### HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm search repo helmforge/
helm install <release-name> helmforge/<chart-name> --version <version> -f values.yaml
```

### OCI Registry

```bash
helm install <release-name> oci://ghcr.io/helmforgedev/helm/<chart-name> --version <version> -f values.yaml
helm show values oci://ghcr.io/helmforgedev/helm/<chart-name> --version <version>
```

Check each chart README, [the documentation site](https://helmforge.dev/docs/charts), and
[GitHub releases](https://github.com/helmforgedev/charts/releases) for available versions and upgrade notes.

## Chart Catalog

Browse the full catalog with descriptions, install commands, values guidance, and playground configs at
[helmforge.dev/docs/charts](https://helmforge.dev/docs/charts).

Common categories include:

- **Data services**: PostgreSQL, MySQL, MariaDB, MongoDB, Redis, Valkey, Kafka, ZooKeeper, RabbitMQ, Elasticsearch, and Druid.
- **Identity and access**: Keycloak, Authelia, OAuth2 Proxy, and application charts with ingress/auth patterns.
- **Operations and automation**: n8n, Cronicle, FastMCP Server, Cloudflared, Velero, DDNS Updater, and Envoy Gateway.
- **Content and collaboration**: WordPress, Ghost, Drupal, Gitea, Wallabag, Castopod, Komga, and Open WebUI.
- **Reusable platform workloads**: the [`generic`](charts/generic) chart for internal services, workers, jobs, and sidecars.

## Validation

Pull requests run the same chart quality gates used for release readiness:

- Dependency build for HelmForge OCI subcharts.
- `helm lint --strict`.
- Default and `ci/*.yaml` render checks.
- Helm unit tests when a chart includes tests.
- `kubeconform` with Kubernetes and CRD schemas.
- Artifact Hub lint.
- Kubescape security scanning.
- Markdown, values quality, and SPDX checks for changed files.

For local work, use the repository helper:

```bash
# Static validation matching the current PR gates
./test.sh <chart-name>

# Runtime validation on the local k3d lab cluster
./test.sh <chart-name> --runtime --values charts/<chart-name>/ci/<scenario>.yaml

# Validate every chart without runtime installs
./test.sh --all --skip-runtime
```

Runtime validation must use the local `k3d-helmforge-tests-wsl` lab context, not a production cluster.
The helper intentionally does not use `kubeconform --ignore-missing-schema`; CRD-backed resources must have
real schemas available during validation.

## Release Model

Chart versions are calculated automatically from Conventional Commits affecting each chart.
Do not edit chart versions manually.

| Commit prefix | Bump | Example |
| ------------- | ---- | ------- |
| `fix:`, `docs:`, `refactor:` | PATCH | `fix(generic): correct hpa indentation` |
| `feat:` | MINOR | `feat(generic): add daemonset support` |
| `feat!:` or `BREAKING CHANGE` | MAJOR | `feat(generic)!: restructure workload config` |

Tags follow the format `{chart}-v{version}`, for example `generic-v1.2.3`.
Each release includes install instructions for both OCI and the HTTPS Helm repository.

## Requirements

- Helm 4.
- Kubernetes 1.26 or newer.
- Standard stable Kubernetes APIs where possible.
- No alpha or beta APIs unless a chart explicitly documents the exception.

## Contributing

Contributions are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md) for branch flow,
validation requirements, commit conventions, and chart standards.

Project references:

- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Governance](GOVERNANCE.md)
- [Maintainers](MAINTAINERS.md)
- [Adopters](ADOPTERS.md)
- [Security Policy](SECURITY.md)

## Support

<p align="center">
  <a href="https://buymeacoffee.com/mberlofa">
    <img src="docs/images/buymeacoffee-qr.png" alt="Buy Me a Coffee QR code for HelmForge support" width="180" />
  </a>
</p>

## Contributors

<p align="center">
  <a href="https://github.com/helmforgedev/charts/graphs/contributors">
    <img src="docs/images/contributors.svg" alt="HelmForge contributors" />
  </a>
</p>

## License

Apache License 2.0

<!-- @AI-METADATA
type: overview
title: HelmForge Charts
description: Repository overview, installation, validation, release model, support, and contributors guide

keywords: helm, charts, oci, ghcr, repository, install

purpose: Repository overview with installation, validation, release model, support, and contributors guide
scope: Repository

relations:
  - CONTRIBUTING.md
  - CODE_OF_CONDUCT.md
  - GOVERNANCE.md
  - MAINTAINERS.md
  - ADOPTERS.md
  - SECURITY.md
path: README.md
version: 1.5
date: 2026-04-01
updated: 2026-07-09
-->
