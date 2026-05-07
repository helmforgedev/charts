# Discount Bandit Helm Chart

Deploy [Discount Bandit](https://github.com/Cybrarist/Discount-Bandit) on Kubernetes using the
[cybrarist/discount-bandit](https://hub.docker.com/r/cybrarist/discount-bandit) container image.

Discount Bandit is a self-hosted price tracker for products across multiple stores. It provides a web UI, scheduled crawling,
price history, currency conversion, multi-user management, and notifications through services such as Ntfy, Telegram, and
Gotify.

## Features

- MySQL primary deployment path through the `helmforge/mysql` subchart
- SQLite development mode for small single-replica installs
- External MySQL/MariaDB support
- Gateway API `HTTPRoute` and classic Kubernetes Ingress
- Service dual-stack fields (`ipFamilyPolicy`, `ipFamilies`)
- External Secrets Operator v1 integration for `APP_KEY`, exchange-rate key, and external database password
- Optional NetworkPolicy for HTTP ingress, crawler egress, notification egress, DNS, and database egress
- Optional persistent logs volume mounted at `/logs`
- Optional PodDisruptionBudget
- Kubernetes-safe Supervisor base config that removes the upstream unauthenticated Supervisor HTTP endpoint
- Production example with MySQL, Gateway API, NetworkPolicy, and resources

## Installation

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install discount-bandit helmforge/discount-bandit -n discount-bandit --create-namespace
```

OCI registry:

```bash
helm install discount-bandit oci://ghcr.io/helmforgedev/helm/discount-bandit -n discount-bandit --create-namespace
```

Default values deploy Discount Bandit with the HelmForge MySQL subchart.

Ready-to-use examples are available in `examples/production.yaml`, `examples/sqlite.yaml`,
`examples/external-mysql.yaml`, `examples/external-secrets.yaml`, and `examples/gateway-api.yaml`.

## Access

```bash
kubectl port-forward -n discount-bandit svc/discount-bandit 8080:80
```

Open `http://localhost:8080` and create the first admin account.

## Production Example

```yaml
discountBandit:
  appUrl: https://deals.example.com
  assetUrl: https://deals.example.com
  timezone: UTC
  themeColor: Stone

mysql:
  enabled: true
  standalone:
    persistence:
      enabled: true
      size: 20Gi

gatewayAPI:
  enabled: true
  parentRefs:
    - name: public-gateway
      namespace: gateway-system
  hostnames:
    - deals.example.com

networkPolicy:
  enabled: true
  egress:
    enabled: true
    allowDNS: true
    allowHTTPS: true
    allowSameNamespaceDatabase: true

serviceAccount:
  automountServiceAccountToken: false

resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    memory: 1Gi
```

## Database Modes

### MySQL Subchart

MySQL is the primary default:

```yaml
mysql:
  enabled: true
  auth:
    database: discount_bandit
    username: discount_bandit
```

The application reads the generated MySQL user password from the subchart Secret.

### External MySQL

```yaml
mysql:
  enabled: false

database:
  mode: external
  external:
    type: mysql
    host: mysql.example.com
    port: 3306
    name: discount_bandit
    username: discount_bandit
    existingSecret: discount-bandit-db
    existingSecretPasswordKey: database-password
```

### SQLite Development Mode

```yaml
mysql:
  enabled: false

database:
  mode: sqlite
  sqlite:
    enabled: true

persistence:
  database:
    enabled: true
    size: 5Gi
```

Keep `replicaCount=1` with SQLite.

## External Secrets

```yaml
mysql:
  enabled: false

database:
  mode: external
  external:
    host: mysql.example.com
    name: discount_bandit
    username: discount_bandit

externalSecrets:
  enabled: true
  secretStoreRef:
    name: cluster-secrets
    kind: ClusterSecretStore
  app:
    enabled: true
    appKeyRemoteRef:
      key: discount-bandit/app
      property: app-key
    exchangeRateApiKeyRemoteRef:
      key: discount-bandit/app
      property: exchange-rate-api-key
  database:
    enabled: true
    passwordRemoteRef:
      key: discount-bandit/mysql
      property: password
```

The chart renders `external-secrets.io/v1` resources.

## Gateway API

```yaml
gatewayAPI:
  enabled: true
  parentRefs:
    - name: public-gateway
      namespace: gateway-system
  hostnames:
    - deals.example.com
```

Use Gateway API when the cluster has a Gateway controller. Use `ingress.enabled=true` for classic Ingress controllers.

## NetworkPolicy

Discount Bandit needs outbound network access for product crawling, exchange-rate API calls, and user-configured notification
services. Start with `networkPolicy.enabled=false`, then enable egress rules once you understand the required destinations.

```yaml
networkPolicy:
  enabled: true
  egress:
    enabled: true
    allowDNS: true
    allowHTTPS: true
    allowSameNamespaceDatabase: true
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `mysql.enabled` | `true` | Deploy HelmForge MySQL as the primary database. |
| `database.mode` | `auto` | Database mode: `auto`, `mysql`, `external`, or `sqlite`. |
| `database.sqlite.enabled` | `false` | Enables explicit SQLite development mode. |
| `discountBandit.appUrl` | `""` | Public application URL (`APP_URL`). |
| `discountBandit.assetUrl` | `""` | Public asset URL (`ASSET_URL`). |
| `discountBandit.cron` | `*/5 * * * *` | Product crawl schedule. |
| `discountBandit.themeColor` | `Stone` | UI theme color. |
| `discountBandit.exchangeRateApiKey` | `""` | ExchangeRate API key; prefer Secret/ExternalSecret. |
| `service.ipFamilyPolicy` | `""` | Optional dual-stack Service policy. |
| `service.ipFamilies` | `[]` | Optional Service IP families. |
| `gatewayAPI.enabled` | `false` | Render Gateway API HTTPRoute. |
| `externalSecrets.enabled` | `false` | Enable External Secrets Operator resources. |
| `networkPolicy.enabled` | `false` | Render NetworkPolicy. |
| `serviceAccount.automountServiceAccountToken` | `false` | Disable Kubernetes API token mount by default. |
| `persistence.logs.enabled` | `false` | Persist `/logs` instead of using `emptyDir`. |
| `supervisor.configMap.enabled` | `true` | Replace the upstream Supervisor base config with a Kubernetes-safe config. |
| `pdb.enabled` | `false` | Render PodDisruptionBudget. |

## Operational Notes

- The upstream container runs FrankenPHP, Laravel scheduler, queue worker, and Chromium-based crawlers under Supervisor.
- Some stores require Chromium headless; review pod logs when validating product crawling.
- The chart waits for MySQL before starting the application container in MySQL and external database modes.
- By default the chart mounts a sanitized Supervisor base config without the upstream unauthenticated `inet_http_server`.
- SQLite is suitable for development and small personal installs only.
- Production deployments should use the MySQL subchart or external MySQL/MariaDB.
- Enable NetworkPolicy carefully because product crawling and notifications need outbound internet access.

## More Information

- [Discount Bandit source](https://github.com/Cybrarist/Discount-Bandit)
- [Discount Bandit documentation](https://discount-bandit.cybrarist.com)
- [HelmForge chart source](https://github.com/helmforgedev/charts/tree/main/charts/discount-bandit)
