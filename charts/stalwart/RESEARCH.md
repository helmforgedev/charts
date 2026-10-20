# Stalwart Chart Research

Chart request: [#1481](https://github.com/helmforgedev/charts/issues/1481)

Requester: `@Aidas-dev`

Research date: 2026-10-15

## Recommendation

Ship a beta chart for Stalwart 0.16.27. The request is aligned with HelmForge:
there is no published first-party chart repository, and existing community
charts do not combine external-secret-native configuration, safe HA validation,
Gateway API L4/L7 routes, and the current v0.16 configuration model.

## Primary Sources

- <https://github.com/stalwartlabs/stalwart/releases/tag/v0.16.26>
- <https://stalw.art/docs/cluster/orchestration/kubernetes/>
- <https://stalw.art/docs/configuration/>
- <https://stalw.art/docs/configuration/declarative-deployments/>
- <https://stalw.art/docs/cluster/deployment/storage/>
- <https://stalw.art/docs/cluster/coordination/>
- <https://stalw.art/docs/management/cli/apply/>

## Image Evidence

`make image-verify` confirmed the official images:

| Image | Platforms |
| --- | --- |
| `docker.io/stalwartlabs/stalwart:v0.16.26` | `linux/amd64`, `linux/arm64`, `linux/arm` |
| `ghcr.io/stalwartlabs/cli:1.0.13` | `linux/amd64`, `linux/arm64` |

The server OCI index digest is
`sha256:254ce5d7f3dbe4bb628ce2c7912e664ecb1c3466db79907f4a44d9a00117776b`.
The issue's `:sha256-...` value is not a runnable semantic image tag.

## Current Configuration Model

Since Stalwart 0.16, `config.json` contains exactly one DataStore object. Blob,
search and in-memory stores, the Coordinator, listeners and telemetry are
database-backed objects. Operators manage those with the Web UI or
`stalwart-cli apply`. Secret fields support environment-variable and file
references, so this chart exposes full `valueFrom`, `envFrom`, and Secret
mounts instead of duplicating thousands of application fields in Helm values.

Settings can be reloaded cluster-wide through `Action/ReloadSettings`; a pod
restart is not normally required. The chart retains a generic rollout trigger
for exceptional operational use.

## Corrections to the Request

- StatefulSet rolling updates have no Deployment-style `maxSurge`.
- The S3 object has a custom endpoint and region but no `pathStyle` field.
- `/healthz/ready` verifies storage initialization, not coordinator membership.
- Zenoh peer-to-peer support is not compiled into the standard image.
- Web clients remain separate workloads; HelmForge already ships bulwark-mail.

These constraints are documented rather than represented by no-op values.

## Design Outcome

- Single-node default: RocksDB plus a per-pod PVC.
- HA mode: external DataStore, no local data PVC, PDB and spread controls.
- Other shared stores and the Coordinator are applied through a mounted NDJSON
  plan using the official CLI image.
- No database, cache, search, object store, NATS, or webmail dependency is
  bundled by default.
- HTTPRoute targets HTTP/JMAP; TCPRoute covers plain and STARTTLS protocols;
  TLSRoute covers implicit TLS passthrough.
- Annotation scraping, optional ServiceMonitor, and extra manifests keep the
  chart compatible with Prometheus and VictoriaMetrics ecosystems.
