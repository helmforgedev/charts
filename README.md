# Helm Charts

Reusable Helm charts for Kubernetes workloads. Published as OCI artifacts to GitHub Container Registry.

## Charts

| Chart | Description |
|-------|-------------|
| [generic](charts/generic/) | General-purpose chart for any Kubernetes workload |

## Quick Start

```bash
# List available chart versions
helm search repo oci://ghcr.io/mberlofa/helm --versions

# Show default values for a chart
helm show values oci://ghcr.io/mberlofa/helm/<chart-name> --version <version>

# Install a chart
helm install <release-name> oci://ghcr.io/mberlofa/helm/<chart-name> --version <version> -f values.yaml

# Pull chart locally
helm pull oci://ghcr.io/mberlofa/helm/<chart-name> --version <version>
```

See each chart's README for specific install commands and configuration.

## CI/CD

Charts are automatically tested and published via two GitHub Actions workflows.

```
PR        --> ci.yml      --> [Lint] [Template] [Kubeconform]
Push main --> publish.yml --> Detect --> Semver --> Package --> Publish to GHCR --> Git tag
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
