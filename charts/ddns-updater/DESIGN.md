# DDNS Updater Chart Design

This chart packages `ddns-updater` as a single-replica dynamic DNS controller
with a web status UI and optional persistent update history.

## Architecture

```text
Public IP checkers
  |
  v
ddns-updater pod
  |
  +-- reads config.json from a Kubernetes Secret
  +-- writes update history to /updater/data
  +-- calls configured DNS provider APIs
  +-- serves status UI on the ClusterIP Service
```

The application is intentionally deployed with `Recreate` strategy and one
replica. Multiple replicas can race provider API updates and write conflicting
history. Availability comes from quick restarts and persistent state, not
horizontal scaling.

## Design Choices

- DNS provider credentials are rendered into a chart-managed Secret only for
  simple starts. Production deployments should prefer `config.existingSecret`
  with a pre-created `config.json`.
- Persistence is enabled by default because `updates.json` is small and useful
  for debugging provider update history.
- The web UI is private by default. Operators can use port-forwarding or enable
  Ingress explicitly.
- Default resources are intentionally small, matching the lightweight polling
  workload while satisfying resource governance.
- The pod runs as the upstream image user `1000:1000`, disables service account
  token automount, drops Linux capabilities, blocks privilege escalation, uses a
  read-only root filesystem, and relies on `RuntimeDefault` seccomp.

## Security Model

The workload does not need Kubernetes API access after its Secret and PVC are
mounted, so `serviceAccount.automountServiceAccountToken=false` is the default.
Provider API tokens are sensitive credentials. Use `config.existingSecret` for
production so tokens are not exposed in Helm release values.

NetworkPolicy is not rendered by this chart because DNS provider access and
public IP detection endpoints vary by deployment. Platform policy should define
egress boundaries for the namespaces where this chart runs.

## Non-Goals

- The chart does not create DNS provider API tokens.
- The chart does not validate provider-specific `config.settings` schemas.
- The chart does not scale beyond one replica by default.
- The chart does not render NetworkPolicy because required egress differs by
  provider and IP detection strategy.

## Validation Focus

- Default chart-managed empty settings Secret.
- Cloudflare settings rendering.
- Existing Secret consumption for `config.json`.
- Persistence and no-persistence runtime paths.
- Ingress rendering for web UI exposure.
- Restricted pod and ServiceAccount token defaults.

## Related Files

- `charts/ddns-updater/README.md`
- `charts/ddns-updater/docs/providers.md`
- `charts/ddns-updater/examples/simple/values.yaml`
- `charts/ddns-updater/examples/production/values.yaml`
- `charts/ddns-updater/examples/multi-provider/values.yaml`
