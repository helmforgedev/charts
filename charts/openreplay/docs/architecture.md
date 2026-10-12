# Architecture

OpenReplay 1.28 is a distributed session-replay pipeline. The chart deploys
fifteen independently pinned application components, an internal router, an
shared scratch volume, and optional data-service dependencies.

The public Service targets Caddy. Caddy owns the path behavior that upstream
implements with F5 NGINX snippets: API and ingest prefix removal, WebSockets,
object paths, the tracker CDN proxy, and SPA fallback. Ingress or HTTPRoute then
needs only one portable prefix route to the Caddy Service.

PostgreSQL stores metadata, ClickHouse stores analytical/session data, Redis or
Valkey carries transient coordination state, and RustFS or an external S3 API
stores recording objects. Workers exchange in-flight recording chunks through
`/mnt/efs`; multi-node deployments require a proven RWX CSI driver.

The application images publish only linux/amd64. The default node selector is
therefore a correctness constraint, not a scheduling preference. Supporting
data images may be multi-architecture, but that does not make the whole stack
ARM-compatible.

Kafka, Vault, connector, and enterprise-only jobs are deliberately absent. The
chart describes the OSS topology and does not accept an enterprise license key.

## Availability

The bundled data services are convenient singleton defaults. Increasing an
application replica count does not create an HA stack. A resilient deployment
uses external HA PostgreSQL, ClickHouse, Valkey, S3, and RWX storage, then scales
only components whose request-affinity behavior has been tested. Assist remains
one replica unless the selected proxy provides compatible session affinity.
