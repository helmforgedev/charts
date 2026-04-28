# Gophish Architecture

Research date: 2026-04-28

## Scope

This document records the upstream facts and HelmForge design decisions for the Gophish chart.

## Upstream Product

Gophish is an open-source phishing toolkit for security awareness training, phishing simulation, and authorized penetration testing workflows.

Primary upstream references:

- Official site: https://getgophish.com
- Source repository: https://github.com/gophish/gophish
- Release `v0.12.1`: https://github.com/gophish/gophish/releases/tag/v0.12.1
- Official Docker image: https://hub.docker.com/r/gophish/gophish
- User guide installation and configuration: https://github.com/gophish/user-guide/blob/master/installation.md

## Version Decision

Use Gophish `0.12.1` as the chart `appVersion`.

Evidence:

- GitHub release `v0.12.1` is published, non-prerelease, and marked as the current release page for this version.
- Docker Hub tag `0.12.1` exists for `docker.io/gophish/gophish`.
- Docker Hub reports tag digest `sha256:8a57cd171999dcd1fa33f346d6898440913ae14be114ffc850cc678354672d29`.

Chart implication:

- Default image repository: `docker.io/gophish/gophish`
- Default image tag: `0.12.1`
- Do not use floating or branch/channel image tags.

## Official Image Behavior

The upstream `v0.12.1` Dockerfile has these runtime characteristics:

| Property | Upstream value |
| --- | --- |
| Runtime base | Debian slim |
| Runtime user | `app` |
| Home directory | `/opt/gophish` |
| Work directory | `/opt/gophish` |
| Default command | `./docker/run.sh` |
| Exposed ports | `3333`, `8080`, `8443`, `80` |
| Config file | `/opt/gophish/config.json` |
| Temp config file | `/opt/gophish/config.json.tmp` |

The Dockerfile sets `cap_net_bind_service` on `/opt/gophish/gophish`, which allows the non-root `app` user to bind low ports such as `80`.

Chart implication:

- Run as non-root by default.
- Keep container port `80` for phishing traffic unless runtime validation proves a safer remap is needed.
- Mount persistent data at a path that keeps SQLite writable by the `app` user.
- If mounting `config.json`, ensure the container can still handle `config.json.tmp` writes or bypass the upstream mutating entrypoint behavior.

## Runtime Configuration Model

Gophish reads configuration from `config.json`. The official image also supports selected environment variables in `docker/run.sh`, which mutate `config.json` at container start.

Supported upstream image environment overrides include:

- `ADMIN_LISTEN_URL`
- `ADMIN_USE_TLS`
- `ADMIN_CERT_PATH`
- `ADMIN_KEY_PATH`
- `ADMIN_TRUSTED_ORIGINS`
- `PHISH_LISTEN_URL`
- `PHISH_USE_TLS`
- `PHISH_CERT_PATH`
- `PHISH_KEY_PATH`
- `CONTACT_ADDRESS`
- `DB_FILE_PATH`

The image does not expose environment overrides for all database modes. In particular, MySQL configuration requires `db_name` and `db_path`, so the chart should render a full `config.json` when database mode is not default SQLite.

Chart decision:

- Render the full `config.json` from Helm values into a Kubernetes Secret.
- Support `gophish.config.existingSecret` for operators who want to manage the full config externally.
- Avoid ConfigMap for generated config because database DSNs may contain credentials.

## Network Architecture

Gophish has two web-facing surfaces:

| Surface | Upstream default | Chart resource |
| --- | --- | --- |
| Admin UI | `admin_server.listen_url` on port `3333` | Dedicated admin Service and optional admin Ingress |
| Phishing listener | `phish_server.listen_url` on port `80` | Dedicated phishing Service and optional phishing Ingress |

The chart should not combine admin and phishing traffic into a single Service by default. These surfaces have different trust models:

- Admin UI is privileged and should be reachable only by trusted operators.
- Phishing listener is the public campaign endpoint.

Chart decisions:

- `adminService` targets container port `3333`.
- `phishService` targets container port `80`.
- Both Services support optional `ipFamilyPolicy` and `ipFamilies` values for IPv4, IPv6, or dual-stack clusters. Defaults are omitted so Services inherit cluster defaults.
- `adminIngress.enabled` defaults to `false`.
- `phishIngress.enabled` defaults to `false`.
- Document port-forward access for admin as the first safe access path.
- Require explicit values for public campaign ingress.

## TLS Model

Upstream supports native TLS for both admin and phishing servers through `use_tls`, `cert_path`, and `key_path`.

Gophish `v0.12.1` also added `admin_server.trusted_origins` for deployments where TLS termination happens upstream from the app.

Chart decision:

- Treat ingress TLS termination as the recommended Kubernetes pattern.
- Keep native Gophish TLS as an advanced, explicit configuration path.
- Support mounting certificate secrets for native TLS only when users enable it.
- Expose `trustedOrigins` for admin CSRF handling behind ingress or load balancers.

## Workload Shape

Initial chart workload type: `Deployment`.

Initial replica count: `1`.

Rationale:

- SQLite is the default upstream database and is single-writer oriented.
- Campaign state and application configuration must remain consistent.
- Gophish does not document a Kubernetes-native HA pattern.

Future multi-replica support should require:

- external MySQL-compatible database
- no shared-writer SQLite
- explicit network and ingress behavior
- local k3d validation for the chosen mode

## Persistence

The default upstream SQLite path is `gophish.db` relative to the working directory. In the official container this resolves under `/opt/gophish`.

Chart decision:

- Use a PVC for the SQLite database in default mode.
- Prefer a dedicated mounted file or directory such as `/opt/gophish/data/gophish.db` if the implementation can validate permissions and path behavior.
- Keep runtime-generated certificates and database state inside persistent storage only when required.

## Existing Chart Search

Search results:

- Artifact Hub package search for `gophish`: no packages returned.
- GitHub repository search for `gophish helm chart`: no relevant repositories returned.
- GitHub code search for `gophish Chart.yaml`: no relevant public chart files returned.

HelmForge differentiation:

- First-class chart documentation and values schema.
- Admin and phishing traffic separated by default.
- Generated config as Secret with existing Secret override.
- Default single-replica SQLite with PVC and clear production guidance.
- External and HelmForge MySQL dependency paths.
- Optional NetworkPolicy.
- Explicit backup boundary and backup validation.
- Full Helm unit tests and k3d evidence.

## Site Sync Notes

HelmForge MCP site sync check for a new `gophish` chart requires:

- dedicated chart documentation page
- chart card entry on the charts overview page
- playground entry for interactive demo
- install snippet
- values reference table

These are Phase 10 deliverables, but they are recorded here because architecture decisions affect the public documentation surface.

## Research Tooling Notes

- Tavily was attempted first for this phase.
- Tavily detailed research timed out, and a second query returned a plan usage limit error.
- Context7 MCP was requested by policy during initial research; later implementation used local Helm and Kubernetes references plus HelmForge MCP guardrails.
- Fallback research used official GitHub, Docker Hub, upstream user guide, and HelmForge MCP resources.

## References

- Gophish release `v0.12.1`: https://github.com/gophish/gophish/releases/tag/v0.12.1
- Gophish Dockerfile at `v0.12.1`: https://raw.githubusercontent.com/gophish/gophish/v0.12.1/Dockerfile
- Gophish default config at `v0.12.1`: https://raw.githubusercontent.com/gophish/gophish/v0.12.1/config.json
- Gophish Docker entrypoint at `v0.12.1`: https://raw.githubusercontent.com/gophish/gophish/v0.12.1/docker/run.sh
- Gophish installation guide: https://github.com/gophish/user-guide/blob/master/installation.md
- Docker Hub tag API: https://hub.docker.com/v2/repositories/gophish/gophish/tags/0.12.1

<!-- @AI-METADATA
type: chart-docs
title: Gophish - Architecture Research
description: Phase 1 architecture research for the Gophish HelmForge chart

keywords: gophish, architecture, helm, kubernetes, phishing-awareness

purpose: Capture upstream runtime facts and HelmForge chart architecture decisions
scope: Chart Research

relations:
  - charts/gophish/docs/database.md
  - charts/gophish/docs/security.md
path: charts/gophish/docs/architecture.md
version: 1.0
date: 2026-04-28
-->
