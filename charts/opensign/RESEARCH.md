# OpenSign research

## Scope

- Chart request: [helmforgedev/charts#1665](https://github.com/helmforgedev/charts/issues/1665)
- Upstream: [OpenSignLabs/OpenSign](https://github.com/OpenSignLabs/OpenSign)
- Release studied: v2.41.3
- Source commit: `e5f2c5c0a9f65ec01d8a53e4bf3a390c7ade7bcd`
- Verification date: 2026-10-21

## Upstream architecture

OpenSign deploys a React frontend, a Node.js Parse Server backend, MongoDB, and
document storage. The frontend listens on port 3000. The backend listens on
port 8080, mounts Parse at `/app`, performs migrations during startup, sends
mail through SMTP, and stores documents locally or in an S3-compatible service.

The signing workflow requires a PKCS#12 certificate and passphrase. The Parse
master key is application identity and must remain stable. A recovery that
restores only MongoDB but loses documents or secrets is incomplete.

## Image assessment

The official Docker Hub repositories are `opensign/opensign` and
`opensign/opensignserver`. Upstream deployment examples use floating channels,
so the chart records the manifests resolved for v2.41.3 and renders digest-only
references. This preserves provenance without exposing users to silent image
replacement.

## Production requirements

- Immutable official images and explicit source provenance.
- Authenticated MongoDB from a maintained HelmForge subchart or external URI.
- Durable local documents or explicit S3-compatible object storage.
- Stable master key and certificate recovery through existing Secrets or ESO.
- TLS-terminated frontend and API endpoints with canonical browser URLs.
- Non-root execution, read-only root filesystems, least capabilities, and
  default-deny-aware NetworkPolicy.
- Frontend redundancy while keeping the migration-running backend singleton.
- Coordinated backup, restore, and upgrade procedures.

## HelmForge differentiation

The chart replaces a manual multi-container deployment with schema-validated
values, immutable image provenance, managed MongoDB, retained identity,
component-aware routing and networking, External Secrets, availability
controls, and executable k3d evidence. It deliberately refuses unsupported
combinations rather than producing a superficially valid manifest.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Floating upstream image channels | Pin verified digests and record revision/date |
| Migration races | Keep backend singleton with `Recreate` |
| Lost master key | Retain generated Secret and support existing Secret/ESO |
| Partial backup | Document MongoDB, document store, and secrets as one recovery set |
| Local volume concurrency | Keep one backend replica and recommend S3 for external durability |
| Controller-specific rewrites | Use distinct frontend and API hostnames |

## Recommendation

Release as HelmForge chart 1.0.0 after the full chart and site gates pass. The
known backend singleton limitation is explicit and does not prevent a robust
production deployment when stateful dependencies are resilient and upgrades
are scheduled.
