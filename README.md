---
title: HelmForge Charts
description: Helm chart repository overview, installation, charts list, and CI/CD
keywords: [helm, charts, oci, ghcr, repository, install]
scope: repository
audience: users, contributors
---

# Helm Charts

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
| [answer](charts/answer/) | Apache Answer — Q&A platform with SQLite, PostgreSQL, or MySQL, auto-install, and S3 backup |
| [n8n](charts/n8n/) | n8n — workflow automation with SQLite, PostgreSQL, or MySQL, Redis queue mode, and S3 backup |
| [komga](charts/komga/) | Komga — media server for comics and manga with OPDS, SQLite persistence, and S3 backup |
| [guacamole](charts/guacamole/) | Apache Guacamole — remote desktop gateway with guacd, PostgreSQL or MySQL, OIDC/SAML SSO, and S3 backup |
| [cloudflared](charts/cloudflared/) | Cloudflare Tunnel — secure outbound-only connections with HA, PDB, and Prometheus metrics |

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

## Contributing

### Adding a new chart

1. Research official docs and mature public charts first.
2. Define the chart proposal, supported architectures, and explicit non-goals.
3. Create `charts/<chart-name>/` with `Chart.yaml`, `values.yaml`, and `templates/`.
4. Add test values in `charts/<chart-name>/ci/*.yaml` for the real scenarios supported by that product.
5. Add usage examples in `charts/<chart-name>/examples/`.
6. Create a `README.md` inside the chart directory.
7. Add architecture-specific docs in `charts/<chart-name>/docs/` when the chart supports materially different topologies.
8. Add the chart to the `## Charts` table in this file.
9. Open a PR. Lint, template rendering, and schema validation run automatically.

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
