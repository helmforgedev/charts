# Countly Helm Chart

Deploy Countly product analytics on Kubernetes with the official
`countly/countly-server:25.05.4` image, a bundled or external MongoDB, optional
Gateway API and External Secrets integration, and scheduled S3-compatible
backups.

## Features

- Separate, configurable Countly API and dashboard listeners.
- HelmForge MongoDB dependency or one external MongoDB URI.
- Ingress and Gateway API exposure for the dashboard.
- External Secrets support for MongoDB credentials.
- Default NetworkPolicy and disabled service-account token mounting.
- Optional non-root MongoDB-to-S3 backup pipeline.
- Runtime validation of both application listeners, including custom ports.

## Architecture

One pod runs the official combined Countly image with independent API and
dashboard processes. Named Service targets keep Kubernetes ports separate from
the native listener values. MongoDB is the only durable state; the application
tier and backup staging directory are disposable.

## Installation

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install countly helmforge/countly
```

OCI installation:

```bash
helm install countly oci://ghcr.io/helmforgedev/helm/countly
```

Access the dashboard without public exposure:

```bash
kubectl port-forward service/countly-countly 8080:80
```

Open `http://127.0.0.1:8080` and complete the Countly setup flow.

## Configuration

The most important values are:

| Value | Default | Purpose |
|---|---|---|
| `countly.apiPort` | `3001` | Native SDK ingestion listener. |
| `countly.dashboardPort` | `6001` | Native dashboard listener. |
| `service.apiPort` | `3001` | Kubernetes Service port for ingestion. |
| `service.port` | `80` | Kubernetes Service port for the dashboard. |
| `mongodb.enabled` | `true` | Deploy HelmForge MongoDB. |
| `externalMongodb.enabled` | `false` | Use an external MongoDB URI. |
| `networkPolicy.enabled` | `true` | Create the Countly NetworkPolicy. |
| `backup.enabled` | `false` | Schedule MongoDB backups to object storage. |

See [configuration](docs/configuration.md) for the full operating contract.

## External MongoDB

Prefer an existing Secret so the URI does not enter Helm release values:

```yaml
mongodb:
  enabled: false

externalMongodb:
  enabled: true
  existingSecret: countly-mongodb
  existingSecretUriKey: mongodb-uri
```

The Secret value must contain a complete MongoDB URI, including any
`authSource`, replica-set, TLS, and certificate parameters required by the
managed service.

## Backups

```yaml
backup:
  enabled: true
  s3:
    endpoint: https://s3.example.com
    bucket: countly-backups
    existingSecret: countly-backup-s3
```

Backups stage one compressed archive in ephemeral storage before upload. Read
[backup and restore](docs/backup-and-restore.md) before enabling the schedule.

## Security

The chart disables Kubernetes API token mounting, applies seccomp, creates a
NetworkPolicy, and runs init and backup containers as non-root. The official
combined Countly image must start its supervisor as root before it drops the
Node.js processes to the `countly` user; this documented upstream constraint is
why the main container does not set `runAsNonRoot`.

Restrict `networkPolicy.ingressFrom` and `networkPolicy.egress`, keep database
and object-store credentials in Secrets, expose both listeners only through
TLS, and scan the pinned image in your admission pipeline. See
[security](docs/security.md).

## Production Guidance

- Use a managed or replicated MongoDB topology with tested backups.
- Set resource requests and limits from observed load.
- Keep the dashboard private where possible; SDK clients need only the API.
- Use External Secrets or pre-created Secrets for credentials.
- Test custom plugin requirements and outbound policy before restricting
  egress.
- Perform a restore drill before relying on scheduled backups.

A reusable baseline is available in [the production example](examples/production.yaml).

## Examples

- [Simple bundled MongoDB](examples/simple.yaml)
- [External MongoDB](examples/external-mongodb.yaml)
- [Production baseline](examples/production.yaml)

## Operations and Troubleshooting

The [operations guide](docs/operations.md) covers upgrades, probes, listener
verification, scaling limits, and common failures. The
[external MongoDB example](examples/external-mongodb.yaml) and
[simple example](examples/simple.yaml) are renderable values files.

## Limitations

- MongoDB is the only supported datastore.
- The pinned combined upstream image is amd64-only.
- The chart does not claim application or database high availability.
- Ingress and HTTPRoute target the dashboard; expose the API separately when
  SDKs are outside the cluster.

## More Information

- [Countly](https://count.ly)
- [Upstream source](https://github.com/Countly/countly-server)
- [Chart design](DESIGN.md)

### Security Scan: `countly`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **72.72727%** |

> Security posture acceptable.

<!-- @AI-METADATA
type: chart-readme
title: Countly Helm Chart
description: Production deployment and operations for Countly on Kubernetes
keywords: countly, analytics, mongodb, backup, gateway-api, external-secrets
purpose: Install and operate the HelmForge Countly chart
scope: Chart
relations:
  - charts/countly/values.yaml
  - charts/countly/DESIGN.md
path: charts/countly/README.md
version: 2.0
date: 2026-10-24
-->
