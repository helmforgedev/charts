# OpenHuman upstream research

<!-- markdownlint-disable MD013 -->

## Verified baseline

- Upstream: <https://github.com/tinyhumansai/openhuman>
- Stable release: `v0.64.15`, published 2026-10-09.
- Official image: `ghcr.io/tinyhumansai/openhuman-core:v0.64.15`.
- OCI index digest: `sha256:c694baccddb47a41ea26db2f6f398fd387b1da1069e91e08ee6bd63509fbb9ab`.
- Platform: `linux/amd64` only. The additional unknown-platform manifest is build provenance.
- License: GPL-3.0.

The release workflow, image labels and release commit agree. Upstream publishes immutable release tags from the official organization. The image has BuildKit provenance but no published SBOM or independently verifiable GitHub artifact attestation, so this chart does not claim either.

## Runtime contract

OpenHuman Core is a headless Rust JSON-RPC server on port 7788. `GET /health` is public and `POST /rpc` requires a bearer token. Remote clients use a local desktop UI connected to the Core; the container does not serve the full desktop application.

The upstream image defines UID/GID 10001 but starts as root to repair Docker volume ownership before dropping privileges. Its entrypoint explicitly supports a pinned non-root identity. Kubernetes can therefore run it directly as 10001 with `fsGroup: 10001`, no capabilities and a read-only root filesystem. Restored files owned by root with mode 0600 need an operator ownership repair before startup.

State lives in `/home/openhuman/.openhuman`; agent projects and file actions use `/home/openhuman/OpenHuman`. Both must remain writable and persistent. `/tmp` must be writable. Upstream documents no clustering or shared-store mode, so the safe topology is one replica with Recreate updates.

## Security and operations

`OPENHUMAN_CORE_TOKEN` is mandatory for remote/container deployments and grants complete RPC authority. Any non-loopback exposure must terminate TLS and define exact allowed origins. The encrypted keyring optionally uses `OPENHUMAN_KEYRING_MASTER_KEY_FILE`; losing that key or rotating it without migration orphans encrypted credentials.

The application can execute side-effecting tools and contact configured model, search and OAuth providers. The chart keeps browser allow-all disabled, disables application-managed updates, disables analytics, blocks Kubernetes API credentials and defaults to a private Service plus NetworkPolicy.

Workspace migrations are ordered and retried, but downgrade is not documented. Back up both claims before upgrades. No Prometheus endpoint is documented, so the chart does not invent one. No database, Redis, Ollama or browser dependency is bundled.

## Ecosystem survey

No maintained Kubernetes manifest or Helm chart was found in GitHub code and ecosystem searches. Official deployments are Docker Compose, DigitalOcean App Platform and Fly.io. Third-party deployments also remain single-container Compose wrappers. HelmForge adds immutable supply-chain pinning, Kubernetes-native persistence, Secret/ExternalSecret contracts, TLS-only exposure options and behavioral validation.

## Primary sources

- <https://github.com/tinyhumansai/openhuman/releases/tag/v0.64.15>
- <https://github.com/tinyhumansai/openhuman/blob/v0.64.15/Dockerfile>
- <https://github.com/tinyhumansai/openhuman/blob/v0.64.15/docker-compose.yml>
- <https://github.com/tinyhumansai/openhuman/blob/v0.64.15/scripts/docker-entrypoint-core.sh>
- <https://github.com/tinyhumansai/openhuman/blob/v0.64.15/gitbooks/features/cloud-deploy.md>
- <https://github.com/tinyhumansai/openhuman/blob/v0.64.15/.env.example>
- <https://github.com/tinyhumansai/openhuman/security>
