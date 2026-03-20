# Vaultwarden

Vaultwarden for Kubernetes with explicit persistent SQLite storage, ingress-oriented deployment, and clear modeling for admin token and SMTP.

## Install

```bash
helm install vaultwarden oci://ghcr.io/mberlofa/helm/vaultwarden -f values.yaml
```

## What this chart covers

- single-instance Vaultwarden deployment
- persistent `/data` storage through PVC
- SQLite as the v1 storage model
- optional ingress with `ingressClassName`
- optional SMTP configuration
- optional admin token through inline value or `existingSecret`
- websocket notifications on the same HTTP service

## Architecture guides

- [SQLite Mode](docs/sqlite.md)
- [Ingress and Domain](docs/ingress-and-domain.md)

## Operational direction

- this chart is intentionally single-instance in v1
- persistent `/data` is the normal path
- SQLite is the default and recommended mode for the current chart scope
- ingress and `domain` should be aligned for attachment links and client behavior
- websocket traffic uses the same HTTP service and ingress path as the web vault

## Official product references

- Vaultwarden repository: https://github.com/dani-garcia/vaultwarden
- Vaultwarden configuration template: https://raw.githubusercontent.com/dani-garcia/vaultwarden/main/.env.template

## Best practices

### Persistence

- keep `data.persistence.enabled=true` for real environments
- back up `/data` regularly
- do not treat SQLite plus one PVC as HA

### Ingress and domain

- configure `domain` for real deployments
- terminate TLS at ingress or reverse proxy
- keep ingress hosts and `domain` aligned

### Security

- keep signups disabled unless the instance is intended for self-service use
- prefer a hashed `ADMIN_TOKEN` value
- expose the admin panel carefully and only behind trusted access patterns

## Production notes

- v1 does not support multiple replicas
- v1 does not claim HA
- v1 does not try to abstract external databases
- if you disable persistence, the deployment becomes disposable and data loss is expected

## Main values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Vaultwarden image repository | `vaultwarden/server` |
| `image.tag` | Vaultwarden image tag | `1.35.4` |
| `domain` | Public Vaultwarden domain | `""` |
| `vaultwarden.signupsAllowed` | Allow new user signups | `false` |
| `vaultwarden.invitationsAllowed` | Allow invitation flows | `true` |
| `vaultwarden.sendsAllowed` | Allow Bitwarden Send | `true` |
| `vaultwarden.websocket.enabled` | Enable websocket notifications | `true` |
| `admin.token` | Inline admin token | `""` |
| `admin.existingSecret` | Existing secret containing the admin token | `""` |
| `smtp.enabled` | Enable SMTP configuration | `false` |
| `smtp.host` | SMTP host | `""` |
| `smtp.from` | SMTP sender address | `""` |
| `smtp.existingSecret` | Existing secret containing the SMTP password | `""` |
| `data.persistence.enabled` | Persist `/data` | `true` |
| `data.persistence.existingClaim` | Existing PVC for `/data` | `""` |
| `data.persistence.size` | PVC size | `5Gi` |
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.ingressClassName` | Ingress class name | `traefik` |
| `resources` | Pod resources | `{}` |

## CI scenarios

The `ci/` scenarios validate the main chart behaviors:

- `minimal.yaml`
- `persistent.yaml`
- `smtp.yaml`
- `existing-secret.yaml`
- `ingress.yaml`

## Examples

See `examples/`:

- `minimal.yaml`
- `persistent.yaml`
- `smtp.yaml`
- `ingress-tls.yaml`
