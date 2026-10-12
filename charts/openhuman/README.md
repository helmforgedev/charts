# OpenHuman Helm chart

<!-- markdownlint-disable MD013 -->

Deploy the official OpenHuman Core as a persistent, authenticated singleton with an immutable image, hardened runtime, retained state and private networking defaults.

## Install

```bash
helm install openhuman oci://ghcr.io/helmforgedev/helm/openhuman --version 1.0.0
kubectl port-forward service/openhuman 7788:7788
```

Retrieve the generated token from Secret `openhuman`, then configure OpenHuman Desktop with `http://127.0.0.1:7788/rpc`. Use HTTPS for any non-loopback connection.

## Production secrets

Set `auth.existingSecret` to a Secret containing `core-token`, or create that Secret through `externalSecrets.items`. Optionally select `keyring.existingSecret` containing a 64-character hexadecimal `master-key`. Losing the keyring key makes encrypted provider credentials unrecoverable.

## State and upgrades

Workspace and projects claims are both enabled and retained by default. Back them up before image upgrades because application migrations are not documented as downgrade-safe. The official container is currently `linux/amd64` only.

## Exposure

The bearer grants full agent RPC control. Keep the default ClusterIP whenever possible. Ingress requires an explicit class and TLS configuration. Gateway API parent Gateways must terminate TLS. Set `openhuman.allowedOrigins` to exact browser origins and restrict `networkPolicy.ingressFrom`.

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
