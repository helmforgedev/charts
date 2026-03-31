---
title: HelmForge Charts
description: Helm chart repository overview, installation, charts list, and CI/CD
keywords: [helm, charts, oci, ghcr, repository, install]
scope: repository
audience: users, contributors
---

# Helm Charts

[![CI](https://github.com/helmforgedev/charts/actions/workflows/ci.yml/badge.svg)](https://github.com/helmforgedev/charts/actions/workflows/ci.yml)
[![Publish](https://github.com/helmforgedev/charts/actions/workflows/publish.yml/badge.svg)](https://github.com/helmforgedev/charts/actions/workflows/publish.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/helmforge)](https://artifacthub.io/packages/search?repo=helmforge)

Reusable open source Helm charts for Kubernetes workloads. Published to a traditional Helm repository at `https://repo.helmforge.dev` and as OCI artifacts on GitHub Container Registry.

Project links:

- Website: `https://helmforge.dev`
- Documentation: `https://helmforge.dev/doc`
- Helm repository: `https://repo.helmforge.dev`

## Charts

| Chart | Description |
|-------|-------------|
| [generic](charts/generic/) | General-purpose chart for any Kubernetes workload |
| [mongodb](charts/mongodb/) | MongoDB — standalone, replica set, or sharded cluster |
| [redis](charts/redis/) | Redis — standalone, replication, sentinel, or cluster |
| [rabbitmq](charts/rabbitmq/) | RabbitMQ — single-node or cluster with management UI and optional TLS |
| [postgresql](charts/postgresql/) | PostgreSQL — standalone or fixed-primary replication with optional metrics |
| [mysql](charts/mysql/) | MySQL — standalone or fixed-source replication with optional metrics |
| [keycloak](charts/keycloak/) | Keycloak — dev or production mode with external DB and separated management service |
| [vaultwarden](charts/vaultwarden/) | Vaultwarden — single-instance with persistent SQLite, ingress, and optional SMTP |
| [minecraft](charts/minecraft/) | Minecraft — Java Edition server with Vanilla, Paper, Forge, Fabric, GeyserMC cross-play, S3 backup, and monitoring |
| [pihole](charts/pihole/) | Pi-hole — DNS sinkhole with custom records, Unbound recursive DNS, and Prometheus metrics |
| [wordpress](charts/wordpress/) | WordPress — CMS with MySQL subchart or external database, S3 backup, and Prometheus metrics |
| [strapi](charts/strapi/) | Strapi — headless CMS with SQLite, PostgreSQL, or MySQL, uploads persistence, and S3 backup |
| [answer](charts/answer/) | Apache Answer — Q&A platform with SQLite, PostgreSQL, or MySQL, auto-install, and S3 backup |
| [n8n](charts/n8n/) | n8n — workflow automation with SQLite, PostgreSQL, or MySQL, Redis queue mode, and S3 backup |
| [komga](charts/komga/) | Komga — media server for comics and manga with OPDS, SQLite persistence, and S3 backup |
| [guacamole](charts/guacamole/) | Apache Guacamole — remote desktop gateway with guacd, PostgreSQL or MySQL, OIDC/SAML SSO, and S3 backup |
| [cloudflared](charts/cloudflared/) | Cloudflare Tunnel — secure outbound-only connections with HA, PDB, and Prometheus metrics |
| [ddns-updater](charts/ddns-updater/) | DDNS Updater — dynamic DNS for 50+ providers with web UI and persistent history |
| [uptime-kuma](charts/uptime-kuma/) | Uptime Kuma — self-hosted monitoring with SQLite or MariaDB, status pages, and S3 backup |
| [authelia](charts/authelia/) | Authelia — SSO, MFA, and OpenID Connect authentication server with forward auth for reverse proxies |
| [adguard-home](charts/adguard-home/) | AdGuard Home — network-wide DNS ad/tracker blocker with sync and S3 backup |
| [velero](charts/velero/) | Velero — Kubernetes backup, restore, migration, schedules, and S3-compatible object storage |
| [kafka](charts/kafka/) | Kafka — KRaft single-broker and production-oriented cluster modes with persistent storage and optional metrics |

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

### Adding a new chart

1. Research official docs, official releases, and mature public charts first.
2. Confirm the latest stable application version from the official project repository before choosing `appVersion`, defaults, or examples.
3. Prefer official container images when they exist. If the product does not publish a maintained official runtime image, document that clearly and build examples around an image created from the official source or package.
4. Define the chart proposal, supported architectures, and explicit non-goals.
5. Create `charts/<chart-name>/` with `Chart.yaml`, `values.yaml`, and `templates/`.
6. Add test values in `charts/<chart-name>/ci/*.yaml` for the real scenarios supported by that product.
7. Add usage examples in `charts/<chart-name>/examples/`.
8. Create a `README.md` inside the chart directory.
9. Add architecture-specific docs in `charts/<chart-name>/docs/` when the chart supports materially different topologies.
10. Add the chart to the `## Charts` table in this file.
11. Validate locally, including a real install on a local cluster when the chart is new or materially changed.
12. Open a PR. Lint, template rendering, and schema validation run automatically.

Local validation safety:

- always check `kubectl config current-context` before any install or uninstall used for local chart validation
- only run validation installs when the active context is the intended local `k3d` cluster
- treat that context check as a mandatory gate before every validation install, upgrade, or uninstall
- never assume a fresh local cluster became the active context automatically
- never continue if the active context is wrong or unclear, because that can affect shared or production-like clusters

### Commit and PR conventions

Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages and PR titles.

Repository standard:

- always use lowercase `type(scope): description`
- always scope chart changes to the chart directory name
- use `ci` for workflow-only changes
- use `repo` for repository-wide docs and instruction changes
- keep each commit and each PR focused on one logical change
- always open PRs from a branch to `main`
- never open branch-to-branch PRs
- always follow this sequence: create branch, commit, push, open PR to `main`

Examples:

```text
feat(redis): add dedicated redis chart
docs(redis): expand architecture usage guides
fix(mongodb): correct service selectors
ci: harden publish workflow retry logic
docs(repo): refine commit and agent standards
```

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
  - AGENTS.md
  - docs/testing-strategy.md
path: README.md
version: 1.0
date: 2026-03-20
-->
