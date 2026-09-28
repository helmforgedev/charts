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

The single-writer contract is enforced:

- `replicaCount` must remain `1`;
- autoscaling is rejected;
- the PDB is omitted for the supported single replica;
- one PVC is mounted once at `/app/data`, avoiding duplicate claim attachments.

## Image and security

The chart uses `ghcr.io/bulwarkmail/webmail:1.11.2-always`. The `-always` tag is the deterministic upstream index for 1.11.2; the plain tag exposed duplicate manifests. The image supports linux/amd64 and linux/arm64.

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

## JMAP networking

The browser communicates with the configured JMAP server directly. Consequently:

- a `.svc.cluster.local` address normally does not work;
- the URL must be resolvable and trusted by both browser and Bulwark pod;
- cross-origin deployments require credentialed CORS on Stalwart;
- a same-origin reverse proxy can avoid CORS.

## Exposure

Ingress and Gateway API are mutually exclusive. The published upstream image supports the root path `/` only. Non-root paths require a custom Bulwark image rebuilt with `NEXT_PUBLIC_BASE_PATH` and are rejected by this chart.

Ingress uses `ingress.ingressClassName`. Gateway API follows the canonical `gatewayAPI.httpRoutes[]` contract and injects the chart Service backend only for route items that omit `rules`.

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

Startup, liveness, and readiness probes call `/api/health`. The chart-owned runtime smoke additionally verifies:

- the exact deterministic image;
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
| `replicaCount` | `1` | Enforced single-writer topology |
| `persistence.size` | `5Gi` | Single `/app/data` PVC |
| `persistence.retain` | `true` | Keep generated PVC on uninstall |
| `service.port` | `3000` | HTTP Service port |
| `networkPolicy.enabled` | `false` | Opt-in traffic restrictions |

The complete, validated contract is documented inline in [values.yaml](values.yaml) and enforced by [values.schema.json](values.schema.json).

## Upgrades

Use `Recreate` intentionally: the old pod releases the RWO volume before the new pod starts. Back up data and the session Secret first. Review upstream changes for state migrations, environment renames, and new writable directories.

## Non-goals

This chart intentionally does not:

- deploy Stalwart or another JMAP server;
- support multiple Bulwark replicas or HPA;
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
