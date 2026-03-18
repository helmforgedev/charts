# Claude Code — Helm Charts Repository

## Repository

OCI Helm chart registry at `ghcr.io/mberlofa/helm`. Charts live under `charts/<name>/`.

## Skills to Use

When working on this repository, use these skills:

- **helm-chart-scaffolding** — designing, organizing, and managing Helm charts
- **kubernetes-specialist** — K8s workloads, RBAC, networking, storage, troubleshooting
- **coding-standards** — code quality and best practices
- **context7-docs-lookup** — fetch up-to-date Helm/K8s documentation when needed

## Conventions

### Commits

Use [Conventional Commits](https://www.conventionalcommits.org/) scoped to the chart name. This drives automatic semver:

- `feat(generic): ...` → MINOR
- `fix(generic): ...` → PATCH
- `feat(generic)!: ...` → MAJOR

### Git Author

Always commit as the repository owner's git identity. Never change git config user.name or user.email. Add co-authorship trailer:

```
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

### Branches

`feat/`, `fix/`, `refactor/`, `docs/` prefixes. The commit message determines the version bump, not the branch name.

## Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | PR | lint, template, kubeconform |
| `publish.yml` | Push main / dispatch | detect → semver → package → push GHCR → git tag |

### What triggers workflows

Only changes to `templates/`, `values.yaml`, `Chart.yaml`, `ci/` trigger workflows. Changes to `README.md`, `examples/`, `docs/`, `AGENTS.md` are **ignored**.

`Chart.yaml` version is managed by the publish workflow — never edit it manually.

## Helm Development

### Template patterns

- `_helpers.tpl` contains shared helpers (`chart.containerSpec`, `chart.podSpec`) — always reuse them
- Go template booleans: empty string = falsy. Use `{{- if .Values.x -}}true{{- end -}}` not `{{- .Values.x -}}`
- Global probes apply to first container only; Jobs/CronJobs skip them via `skipGlobalProbes`
- Image formats: `named` = `repo:containerName-tag`, `simple` = `repo:tag`

### Validate before pushing

```bash
helm lint charts/<name> --strict
helm template test charts/<name>
for f in charts/<name>/ci/*.yaml; do helm template test charts/<name> -f "$f"; done
```

## Documentation Rules

- **Root README**: generic commands with `<placeholders>`, no chart-specific details, no versions
- **Chart README** (`charts/<name>/README.md`): specific install commands, features, values reference
- Adding a chart → add row to root README charts table + create chart README
- Never hardcode versions in READMEs — they become stale
