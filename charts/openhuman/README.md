# OpenHuman Helm chart

<!-- markdownlint-disable MD013 -->

Deploy the official OpenHuman Core as a persistent, authenticated singleton with an immutable image, hardened runtime, retained state and private networking defaults.

## Features

- Immutable official OpenHuman Core image with a non-root, read-only runtime.
- Separate retained volumes for the workspace and project data.
- Generated, existing or External Secrets-managed RPC authentication.
- Optional encrypted-keyring Secret mounted through an in-memory staging volume.
- NetworkPolicy enabled by default, plus opt-in TLS Ingress and Gateway API routes.
- Configurable application listener, probes, scheduling controls and disruption budget.

## Install

```bash
helm install openhuman oci://ghcr.io/helmforgedev/helm/openhuman --version 1.1.0
kubectl port-forward service/openhuman 7788:7788
```

Retrieve the generated token from Secret `openhuman`, then configure OpenHuman Desktop with `http://127.0.0.1:7788/rpc`. Use HTTPS for any non-loopback connection.

## Architecture

OpenHuman Core runs as an intentionally single-replica Deployment behind a
ClusterIP Service. Separate retained PVCs hold the workspace and projects
directory. A generated or existing Secret supplies the RPC bearer, while an
optional Secret file unlocks the encrypted keyring. Ingress and Gateway API are
opt-in TLS entry points; NetworkPolicy restricts ingress and provider egress.
See [DESIGN.md](DESIGN.md) for the topology and operational boundaries.

## Configuration

The Service port and application listener are separate contracts.
`containerPorts.http` changes the real Core process through
`OPENHUMAN_CORE_PORT`; `service.port` is the client-facing Kubernetes port:

```yaml
containerPorts:
  http: 7799

service:
  port: 7788
```

The Service, probes, and NetworkPolicy use the named application port, so this
override does not require replacing the container command or arguments.

Key production values include:

| Key | Default | Purpose |
| --- | --- | --- |
| `containerPorts.http` | `7788` | Actual OpenHuman Core listener. |
| `service.port` | `7788` | Client-facing Service port. |
| `auth.existingSecret` | `""` | Existing Secret containing the RPC bearer. |
| `keyring.existingSecret` | `""` | Existing Secret containing the keyring master key. |
| `persistence.size` | `10Gi` | Workspace volume capacity. |
| `projectsPersistence.size` | `10Gi` | Projects and action-tool volume capacity. |
| `networkPolicy.enabled` | `true` | Restrict ingress and egress by default. |
| `openhuman.allowedOrigins` | `""` | Explicit browser origins allowed to call RPC. |

## Examples

Start with [examples/simple.yaml](examples/simple.yaml) for private access through
port-forwarding. Use [examples/production.yaml](examples/production.yaml) for a
TLS endpoint and production scheduling controls, or
[examples/external-secrets.yaml](examples/external-secrets.yaml) when the RPC
token is managed by External Secrets Operator. Review each example before use;
hostnames, Secret references and allowed peers are environment-specific.

## Production secrets

Set `auth.existingSecret` to a Secret containing `core-token`, or create that Secret through `externalSecrets.items`. Optionally select `keyring.existingSecret` containing a 64-character hexadecimal `master-key`. Losing the keyring key makes encrypted provider credentials unrecoverable.

## State and upgrades

Workspace and projects claims are both enabled and retained by default. Back them up before image upgrades because application migrations are not documented as downgrade-safe. The official container is currently `linux/amd64` only.

## Exposure

The bearer grants full agent RPC control. Keep the default ClusterIP whenever possible. Ingress requires an explicit class and TLS configuration. Gateway API parent Gateways must terminate TLS. Set `openhuman.allowedOrigins` to exact browser origins and restrict `networkPolicy.ingressFrom`.

## Troubleshooting

Check rollout health, application logs, and the configured listener:

```bash
kubectl rollout status deployment/<release>-openhuman
kubectl logs deployment/<release>-openhuman -c openhuman --tail=100
kubectl exec deployment/<release>-openhuman -c openhuman -- \
  sh -c 'curl --fail --silent http://127.0.0.1:7788/health'
```

If the Pod cannot start after restoring a backup, verify that both volumes are
writable by UID/GID 10001. If clients cannot connect, inspect the Service
endpoints and NetworkPolicy peers, then confirm that the external TLS endpoint
preserves the bearer header and uses an allowed browser origin.

## Security scan

Security scan results use the same Kubescape policy set as HelmForge CI.

Security Scan: openhuman

| Framework                |       Score |
| ------------------------ | ----------: |
| MITRE                    | **100.00%** |
| NSA                      | **100.00%** |
| SOC 2                    | **100.00%** |
| Aggregate resource score | **100.00%** |

Kubescape reported zero failed resources at critical, high, medium or low severity for the default rendered workload.

## Documentation

- [Configuration](docs/configuration.md)
- [Security](docs/security.md)
- [Operations](docs/operations.md)
- [Upstream research](RESEARCH.md)
- [Design](DESIGN.md)
