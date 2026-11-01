<!-- markdownlint-disable MD013 -->

# Bulwark Mail

Production-ready Helm chart for [Bulwark Mail](https://github.com/bulwarkmail/webmail), a self-hosted JMAP web client for Stalwart Mail Server.

## Scope

This chart deploys the full Node.js Bulwark edition. It does not install Stalwart. Supply an external, browser-reachable JMAP endpoint or complete that choice through the setup wizard.

## Installation

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install bulwark-mail helmforge/bulwark-mail --namespace mail --create-namespace
```

OCI installation after the first public release:

```bash
helm install bulwark-mail oci://ghcr.io/helmforgedev/helm/bulwark-mail \
  --version 1.0.0 --namespace mail --create-namespace
```

## Quick start

Wizard mode is the default. It creates one persistent volume and directs the first browser session to `/setup`:

```bash
kubectl -n mail port-forward service/bulwark-mail 3000:3000
```

Open `http://127.0.0.1:3000` and enter the public Stalwart/JMAP URL.

For immutable infrastructure, use declarative mode:

```yaml
config:
  mode: declarative
  jmap:
    serverUrl: https://mail.example.com
secrets:
  existingSecret: bulwark-mail-runtime
  generate: false
```

The existing Secret must contain `session-secret`; add `admin-password`, `oauth-client-secret`, or the JWT master keys only for enabled features.

## Architecture

The chart creates a single `Deployment` with `Recreate` strategy. Bulwark stores encrypted settings, admin configuration, admin runtime state, telemetry state, and update-check state below `/app/data`. A single PVC backs that root, while `/tmp` uses `emptyDir`.

Without the shared store, the single-writer contract is enforced:

- `replicaCount` must remain `1`;
- autoscaling and the PDB are rejected;
- one PVC is mounted once at `/app/data`, avoiding duplicate claim attachments.

With `sharedStore.enabled: true`, Bulwark keeps all state in an external Redis-protocol store instead, and the chart allows several replicas, autoscaling, and a PDB. See [Several replicas](#several-replicas).

## Image and security

The chart uses `ghcr.io/bulwarkmail/webmail:1.15.0-always`. The `-always` tag is the deterministic upstream index for 1.15.0. The image supports linux/amd64 and linux/arm64.

Defaults match the upstream image user:

- UID, GID, and fsGroup `1001`;
- read-only root filesystem;
- all Linux capabilities dropped;
- privilege escalation disabled;
- RuntimeDefault seccomp;
- ServiceAccount token not mounted.

## Configuration modes

### Wizard

`config.mode: wizard` preserves upstream onboarding. Persistence is mandatory because setup completion, policy, admin password hash, plugins, themes, and runtime state are written below `/app/data`.

### Declarative

`config.mode: declarative` requires `config.jmap.serverUrl`, which is exported as `JMAP_SERVER_URL`. Admin read-only behavior is independent: leave `config.admin.readOnly: false` during bootstrap so `ADMIN_PASSWORD` can persist `admin.json`, then opt in after the configuration exists.

Upstream admin files have higher precedence than environment values. When reusing a wizard-created PVC, remove stale admin overrides before expecting declarative values to take effect.

## Several replicas

Bulwark images released after 1.19.1 can share their state through one Redis-protocol store (Valkey, Redis 5 or newer, KeyDB, Dragonfly, or a managed service). Every replica then sees the same admin configuration, plugins, branding, user settings, sign-in limits, and sessions, so any number of replicas runs behind the plain Service without sticky sessions and without a data volume. Upstream documentation: [Running several instances](https://bulwarkmail.org/docs/deployment/multi-instance).

The chart does not install the store. Run one next to Bulwark, for example with the [HelmForge Valkey chart](https://helmforge.dev/docs/charts/valkey), and configure it with `maxmemory-policy noeviction` and persistence (`appendonly yes`) so that it never drops Bulwark state. Redis Cluster is not supported upstream; a single endpoint is.

```yaml
image:
  tag: "<a release after 1.19.1>"
replicaCount: 3
sharedStore:
  enabled: true
  existingSecret: bulwark-mail-store   # key shared-store-url: redis://:password@valkey:6379/0
config:
  mode: declarative
  jmap:
    serverUrl: https://mail.example.com
persistence:
  enabled: false
pdb:
  enabled: true
```

With the shared store enabled:

- the store URL is exported as `REDIS_URL` from `sharedStore.existingSecret`, or from the runtime Secret (`secrets.existingSecret` or the generated one) under `sharedStore.existingSecretKey`. `sharedStore.url` writes it into the generated Secret for local tests; it becomes part of Helm release state;
- `sharedStore.keyPrefix` sets `REDIS_KEY_PREFIX` when several releases share one store;
- every replica receives the same `SESSION_SECRET` from the runtime Secret;
- the readiness probe moves to `/api/ready`, which answers 503 while a pod starts or cannot reach the store. Liveness and startup stay on `/api/health`, so a store outage takes pods out of the Service without restarting them. Set `probes.readiness.path` to override;
- `replicaCount` above 1, `autoscaling.enabled`, and `pdb.enabled` are accepted. `persistence.enabled` must be `false` with more than one replica or autoscaling, because one ReadWriteOnce volume cannot follow pods to other nodes and the store holds all state;
- the Deployment uses `RollingUpdate` when no volume is mounted, and `Recreate` while one replica still mounts its old volume;
- wizard mode no longer needs a volume, because the setup state is written to the store.

The default readiness settings remove a pod after about 60 seconds of failures (`periodSeconds: 10`, `failureThreshold: 6`). Lower them, for example to `periodSeconds: 5` and `failureThreshold: 3`, to react to a store outage faster.

To move an existing single-instance release, back up the PVC, then upgrade with `sharedStore.enabled: true` while keeping `replicaCount: 1` and the existing volume. On first start against an empty store Bulwark imports everything from `/app/data` and logs what it imported. Then upgrade again with `persistence.enabled: false` and more replicas. The retained PVC is no longer mounted; delete it after a verified backup.

If `networkPolicy.egress.enabled` is true, add an `extraEgress` rule that allows the store's port. Store data includes the admin password hash, OAuth client secrets, and encrypted user settings: require a password, use `rediss://` across untrusted networks, restrict access to the Bulwark pods, and back the store up together with the runtime Secret.

`extraEnv` may not set `REDIS_URL`, `REDIS_URL_FILE`, or `REDIS_KEY_PREFIX` while the chart manages the store. If you set `PLUGIN_SIGNING_KEY_FILE` through `extraEnv`, it applies to every replica, which is what upstream requires.

## JMAP networking

The browser communicates with the configured JMAP server directly. Consequently:

- a `.svc.cluster.local` address normally does not work;
- the URL must be resolvable and trusted by both browser and Bulwark pod;
- cross-origin deployments require credentialed CORS on Stalwart;
- a same-origin reverse proxy can avoid CORS.

## Exposure

Ingress and Gateway API are mutually exclusive. The published upstream image supports the root path `/` only. Non-root paths require a custom Bulwark image rebuilt with `NEXT_PUBLIC_BASE_PATH` and are rejected by this chart.

Ingress uses `ingress.ingressClassName`. Gateway API follows the canonical `gatewayAPI.httpRoutes[]` contract and injects the chart Service backend only for route items that omit `rules`.

`containerPorts.http` configures the real Next.js listener through the upstream `PORT` environment variable. `service.port` is independent and the Service targets the named `http` container port. Ports below `1024` require the container runtime to permit non-root binds for UID `1001`.

## Secrets

By default the chart creates a stable 64-character session secret and preserves it through Helm upgrades. Production installations can select an existing Secret or use `externalSecrets.items[]`.

Optional secret keys:

| Key | Consumer |
| --- | --- |
| `session-secret` | Remember-me sessions and settings encryption |
| `admin-password` | Initial admin dashboard bootstrap |
| `oauth-client-secret` | OAuth token exchange |
| `jwt-auth-secret` | Trusted-platform JWT verification |
| `stalwart-master-user` | JWT impersonation master account |
| `stalwart-master-password` | JWT impersonation master credential |

JWT impersonation is disabled unless all three sensitive values are configured. The signing secret must be at least 32 characters.

## Persistence and backup

Back up the PVC and runtime Secret together. The PVC contains:

- `/app/data/settings`;
- `/app/data/admin`;
- `/app/data/admin-state`;
- `/app/data/telemetry`;
- `/app/data/version-check`.

Restore both artifacts before starting a replacement release. See [Storage and recovery](docs/storage.md).

## NetworkPolicy

NetworkPolicy is opt-in. When egress isolation is enabled, the chart permits DNS plus configured JMAP TCP ports. Narrow `networkPolicy.egress.jmapTo` to known CIDRs or namespace/pod selectors when the JMAP service is in-cluster. `extraEgress` accepts complete additional rules for OAuth discovery, extension directories, update checks, translation services, or push relays.

## OAuth and JWT impersonation

OAuth requires a client ID and issuer URL. The client secret is optional for public clients using PKCE. `config.oauth.only` cannot be enabled without OAuth. Private discovered endpoints stay blocked unless explicitly enabled.

`config.admin.readOnly` is independent from `config.mode`. Leave it disabled during bootstrap so an `ADMIN_PASSWORD` can persist `admin.json`, then enable it when the persisted admin configuration should no longer be changed through the UI.

JWT impersonation grants the trusted caller the ability to enter arbitrary Stalwart mailboxes. Treat its signing key and master password as root credentials and isolate the endpoint with network policy and an authenticating proxy.

## Dual-stack

Set `service.ipFamilyPolicy` to `SingleStack`, `PreferDualStack`, or `RequireDualStack`. `service.ipFamilies` preserves the requested family order. Defaults omit both fields and inherit cluster behavior.

## Probes and runtime acceptance

Startup, liveness, and readiness probes call `/api/health`. With the shared store, readiness calls `/api/ready` instead; `probes.readiness.path` overrides either default. `/api/ready` exists only in Bulwark images released after 1.19.1. The chart-owned runtime smoke additionally verifies:

- the exact deterministic image;
- the configured application listener and independent Service port;
- health JSON reports `healthy`;
- `/api/config` exposes the expected JMAP, remember-me, and settings-sync contract;
- wizard mode reports bootstrap state and redirects `/` to `/setup`;
- declarative mode hides the setup API.

## Examples

- [Wizard setup](examples/simple.yaml)
- [Declarative setup](examples/declarative.yaml)
- [Ingress](examples/ingress.yaml)
- [Gateway API](examples/gateway-api.yaml)
- [External Secrets](examples/external-secrets.yaml)
- [Several replicas with a shared store](examples/shared-store.yaml)

## Operational guides

- [Configuration and authentication](docs/configuration.md)
- [Storage and recovery](docs/storage.md)
- [Ingress, Gateway API, and CORS](docs/exposure.md)
- [Security model](docs/security.md)
- [Operations and troubleshooting](docs/operations.md)

## Important values

| Value | Default | Purpose |
| --- | --- | --- |
| `config.mode` | `wizard` | Wizard or declarative configuration |
| `config.jmap.serverUrl` | empty | Public external JMAP URL |
| `config.settingsSync` | `true` | Encrypted server-side settings |
| `config.telemetry` | `off` | Explicit upstream telemetry choice |
| `replicaCount` | `1` | Single writer; above 1 requires the shared store |
| `sharedStore.enabled` | `false` | Share state through an external Redis-protocol store |
| `sharedStore.existingSecret` | empty | Secret holding the store URL; empty uses the runtime Secret |
| `probes.readiness.path` | empty | `/api/ready` with the shared store, `/api/health` otherwise |
| `persistence.size` | `5Gi` | Single `/app/data` PVC |
| `persistence.retain` | `true` | Keep generated PVC on uninstall |
| `containerPorts.http` | `3000` | Next.js application listener configured through `PORT` |
| `service.port` | `3000` | Independent Kubernetes Service port targeting the named listener |
| `networkPolicy.enabled` | `false` | Opt-in traffic restrictions |

The complete, validated contract is documented inline in [values.yaml](values.yaml) and enforced by [values.schema.json](values.schema.json).

## Upgrades

Without the shared store, `Recreate` is intentional: the old pod releases the RWO volume before the new pod starts. Back up data and the session Secret first. Review upstream changes for state migrations, environment renames, and new writable directories.

## Non-goals

This chart intentionally does not:

- deploy Stalwart or another JMAP server;
- install the shared store, or support multiple Bulwark replicas or HPA without it;
- rewrite arbitrary subpaths for the published image;
- create certificate, Gateway, ingress-controller, or External Secrets CRDs;
- configure DNS, SMTP, IMAP, or mail delivery.

## Security Scan: `bulwark-mail`

| Framework | Score |
| --- | ---: |
| MITRE | **100.00%** |
| NSA | **95.00%** |
| SOC 2 | **80.00%** |
| Aggregate resource score | **93.94%** |

Kubescape v4.0.14 reported no critical or high-severity control failures. The
two medium findings concern unrestricted ingress and egress when the optional
NetworkPolicy is disabled by default.

## Support

Chart issues belong in the [HelmForge charts repository](https://github.com/helmforgedev/charts/issues). Application issues belong in the [Bulwark repository](https://github.com/bulwarkmail/webmail/issues).

<!-- @AI-METADATA
type: chart-readme
title: Bulwark Mail Chart
description: Production-ready Kubernetes deployment for Bulwark Mail
keywords: bulwark, webmail, jmap, stalwart, kubernetes
purpose: Install and operate Bulwark Mail on Kubernetes
scope: Chart
relations:
  - charts/bulwark-mail/Chart.yaml
  - charts/bulwark-mail/values.yaml
path: charts/bulwark-mail/README.md
version: 1.0
date: 2026-09-28
-->
