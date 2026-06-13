# Discount Bandit Operations

## Runtime Profile

Discount Bandit runs a Laravel application with FrankenPHP, a scheduler, queue workers, and Chromium-based crawlers in a
single upstream container. The chart keeps one Deployment with `Recreate` strategy so SQLite development mode and log
volumes are not mounted concurrently by multiple pods.

The upstream image currently runs as root and listens on port 80. The chart therefore applies conservative hardening by
default:

- service account token automount disabled
- RuntimeDefault seccomp profile
- privilege escalation disabled
- explicit CPU and memory requests and limits

Do not force `runAsNonRoot`, `readOnlyRootFilesystem`, or dropped capabilities without validating the upstream image and
Chromium crawler behavior in a real workload test.

## Database Modes

Use the default HelmForge MySQL subchart for production when the cluster should own the database lifecycle. Use
`database.mode=external` when a platform MySQL or MariaDB service already exists. SQLite mode is intended for development
and small personal installs only and should stay at `replicaCount=1`.

Production database values should use Secrets or External Secrets for `APP_KEY`, database passwords, and optional
exchange-rate credentials.

## Crawling And Egress

Discount Bandit crawls product pages and can send notifications through user-configured providers. NetworkPolicy should be
enabled only after the required outbound destinations are understood. The production example allows DNS, HTTPS crawler
traffic, and same-namespace MySQL egress.

If product updates stop working after enabling NetworkPolicy, inspect:

```bash
kubectl logs -n discount-bandit -l app.kubernetes.io/name=discount-bandit --all-containers --tail=100
kubectl describe networkpolicy -n discount-bandit
```

## Routing

Set `discountBandit.appUrl` and `discountBandit.assetUrl` before exposing the application. Use Gateway API when the
cluster has a platform-owned Gateway. Use classic Ingress for clusters that still standardize on an Ingress controller.

## Validation Checklist

- Confirm the first admin account can be created through the web UI.
- Add one product and verify crawler logs show successful fetches.
- Confirm MySQL or external database credentials are read from the intended Secret.
- Review memory use after enabling Chromium-heavy stores and adjust `resources` for the workload.
- Enable NetworkPolicy only after crawler and notification egress has been tested.
