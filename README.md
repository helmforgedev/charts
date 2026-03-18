# Helm Charts

Reusable Helm charts for Kubernetes workloads. Published as OCI artifacts to GitHub Container Registry.

## Charts

| Chart | Description | Version |
|-------|-------------|---------|
| [generic](charts/generic/) | General-purpose chart for any Kubernetes workload | `1.0.0` |

## Quick Start

### Install from OCI registry

```bash
helm install my-release oci://ghcr.io/mberlofa/helm/generic --version 1.0.0 -f values.yaml
```

### Pull and inspect

```bash
helm pull oci://ghcr.io/mberlofa/helm/generic --version 1.0.0
helm show values oci://ghcr.io/mberlofa/helm/generic --version 1.0.0
```

## Repository Structure

```
charts/
  generic/              # General-purpose chart
    Chart.yaml
    values.yaml
    templates/
    ci/                 # Test values for CI pipeline
    examples/           # Usage examples
  <future-chart>/       # Add new charts here
.github/
  workflows/
    ci.yml              # PR validation
    publish.yml         # Release to GHCR
```

## CI/CD

Charts are automatically tested and published via two GitHub Actions workflows.

```
PR        --> ci.yml      --> [Lint] [Template] [Kubeconform]
Push main --> publish.yml --> [Lint] [Template] [Kubeconform] --> Semver --> Publish to GHCR --> Git tag
```

Both workflows dynamically detect which charts changed and run jobs only for those charts using a matrix strategy. Changes to docs (`README.md`, `examples/`, `docs/`) are ignored.

### Versioning

Versions are calculated automatically from **conventional commits** affecting each chart:

| Commit prefix | Bump | Example |
|---------------|------|---------|
| `fix:`, `docs:`, `refactor:` | PATCH | `fix(generic): correct HPA indentation` |
| `feat:` | MINOR | `feat(generic): add DaemonSet support` |
| `feat!:` or `BREAKING CHANGE` | MAJOR | `feat(generic)!: restructure workload config` |

Tags follow the format `{chart}-v{version}` (e.g., `generic-v1.2.3`).

### Testing

Each chart includes a `ci/` directory with test values files. The pipeline runs `helm template` against every `ci/*.yaml` file automatically, in addition to default values, lint, and kubeconform schema validation.

## Contributing

### Adding a new chart

1. Create `charts/<chart-name>/` with `Chart.yaml`, `values.yaml`, and `templates/`
2. Add test values in `charts/<chart-name>/ci/*.yaml`
3. Add usage examples in `charts/<chart-name>/examples/`
4. Create a `README.md` inside the chart directory with documentation
5. Open a PR -- lint, template, and schema validation run automatically
6. Merge to main -- the chart is versioned and published to GHCR

### Commit conventions

Use [Conventional Commits](https://www.conventionalcommits.org/) to drive automatic versioning:

```bash
git commit -m "feat(generic): add topology spread constraints support"
git commit -m "fix(generic): correct service targetPort default"
git commit -m "feat(redis-ha)!: redesign sentinel configuration"
```

## License

MIT
