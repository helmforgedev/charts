# Gophish

Gophish is an open-source phishing awareness platform for authorized security training.
This chart deploys Gophish with separate admin and phishing traffic, safe SQLite defaults, optional HelmForge MySQL,
optional external MySQL, NetworkPolicy, and SQLite backup support.

## Install

```bash
helm install gophish oci://ghcr.io/helmforgedev/helm/gophish
```

Local chart validation:

```bash
helm install gophish ./charts/gophish --namespace gophish --create-namespace
```

## Access

Admin access is private by default:

```bash
kubectl port-forward svc/gophish-gophish-admin 3333:3333 -n gophish
```

Then open `http://127.0.0.1:3333`.

The phishing listener is also private by default:

```bash
kubectl port-forward svc/gophish-gophish-phish 8080:80 -n gophish
```

Then open `http://127.0.0.1:8080`.

## Initial Admin Password

Gophish writes the generated initial admin password to startup logs on first boot. Retrieve it from a trusted workstation and change it immediately after login:

```bash
kubectl logs deploy/gophish-gophish -n gophish | grep "Please login with the username admin"
```

Do not store this password in values files, examples, tickets, or PR bodies.

## Configuration

The full value contract is in `values.yaml` and validated by `values.schema.json`.

| Key | Default | Description |
| --- | --- | --- |
| `database.mode` | `auto` | `auto`, `sqlite`, `mysql` (HelmForge MySQL subchart), or `external` |
| `adminService.port` | `3333` | Admin Service port |
| `phishService.port` | `80` | Phishing Service port |
| `adminIngress.enabled` / `phishIngress.enabled` | `false` | Separate Ingresses for the admin UI and the phishing listener |
| `gateway.enabled` | `false` | Separate HTTPRoutes for the admin UI and the phishing listener |
| `persistence.enabled` | `true` | PVC for the SQLite database and chart-managed runtime files |
| `networkPolicy.enabled` | `false` | Render NetworkPolicy resources |
| `backup.enabled` | `false` | SQLite backups to S3-compatible storage |

## Database Modes

| Mode | Values | Notes |
| --- | --- | --- |
| SQLite | `database.mode=auto` or `sqlite` | Default. Requires one replica and persistent storage. |
| Embedded MySQL | `database.mode=mysql`, `mysql.enabled=true` | Uses the HelmForge MySQL dependency and sets a Gophish-compatible `sql_mode`. |
| External MySQL | `database.mode=external` | Prefer `database.external.existingSecret` with a complete DSN. |

External DSN Secret example:

```text
dsn=gophish:<password>@(mysql.database.svc.cluster.local:3306)/gophish?charset=utf8&parseTime=True&loc=UTC
```

## Ingress

`adminIngress.enabled` and `phishIngress.enabled` are both disabled by default.

Admin ingress requires TLS:

```yaml
adminIngress:
  enabled: true
  tls:
    - secretName: gophish-admin-tls
      hosts:
        - gophish-admin.example.com
  hosts:
    - host: gophish-admin.example.com
      paths:
        - path: /
          pathType: Prefix
```

Phishing ingress is configured separately:

```yaml
phishIngress:
  enabled: true
  hosts:
    - host: training.example.com
      paths:
        - path: /
          pathType: Prefix
```

## Gateway API

Gateway API HTTPRoutes are available as an opt-in alongside Ingress. The chart keeps admin and phishing routes separate so operators can attach them to different Gateway listeners.

```yaml
gateway:
  enabled: true
  admin:
    enabled: true
    parentRefs:
      - name: internal-gateway
        namespace: gateway-system
    hostnames:
      - gophish-admin.example.com
  phish:
    enabled: true
    parentRefs:
      - name: public-gateway
        namespace: gateway-system
    hostnames:
      - training.example.com
```

The Gateway API resources target `gateway.networking.k8s.io/v1` and require the Gateway API CRDs and a Gateway controller installed in the cluster.

## Dual-Stack Services

Admin and phishing Services can opt into Kubernetes dual-stack fields independently, or inherit shared defaults from `service`. Leave these values omitted to inherit cluster defaults.

```yaml
service:
  ipFamilyPolicy: PreferDualStack

phishService:
  ipFamilies:
    - IPv4
    - IPv6
```

Explicit `ipFamilies` should be used only on clusters that advertise those families.

## Backup

The chart-managed backup supports SQLite mode only. It archives the chart-managed PVC path that contains the SQLite database and uploads the archive plus checksum to S3-compatible storage with `docker.io/helmforge/mc:1.0.0`.

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: gophish-backups
    prefix: gophish
    existingSecret: gophish-backup
```

For MySQL modes, use the MySQL dependency backup flow or external database backup tooling.

## Examples

- `examples/simple.yaml`: SQLite with port-forward access.
- `examples/phish-ingress.yaml`: public phishing listener ingress.
- `examples/external-db.yaml`: external MySQL DSN Secret flow.
- `examples/production.yaml`: production-oriented external DB, phishing ingress, and NetworkPolicy.

## Documentation

- [Chart design](DESIGN.md)
- [Architecture](docs/architecture.md): image behavior, database modes, network surfaces, and TLS
- [Database](docs/database.md): SQLite, embedded MySQL, and external MySQL
- [Security](docs/security.md): admin exposure, NetworkPolicy, and secrets
- [Backup](docs/backup.md): SQLite backups to S3-compatible storage

## Quality Gates

```bash
helm lint charts/gophish
helm unittest charts/gophish
helm template gophish charts/gophish | kubeconform -strict -kubernetes-version 1.30.0 -schema-location default
ct lint --target-branch main --charts charts/gophish
```

### Security Scan: `gophish`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **88.38384%** |

Security posture: acceptable.
