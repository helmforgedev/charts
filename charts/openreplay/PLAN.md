# OpenReplay implementation plan

1. Model all fifteen OSS application components with independent pinned images,
   resources, probes, replica counts, and scheduling overrides.
2. Add a controller-neutral router that owns SPA fallback, prefix rewrites,
   WebSocket forwarding, object-store paths, and the tracker CDN proxy.
3. Provide bundled HelmForge PostgreSQL, Redis, and ClickHouse dependencies,
   plus a pinned RustFS workload, while keeping every data service replaceable
   by an external endpoint and existing Secret or ExternalSecret.
4. Provide generated, existing, and ESO-managed application credentials.
5. Implement the required revision-scoped migration Job and downgrade protection.
6. Add RWX scratch persistence, optional PDBs, NetworkPolicy, monitoring,
   conventional Ingress, Gateway API HTTPRoute, and dual-stack service fields.
7. Validate rendering, schemas, unit tests, real ESO reconciliation, and a
   lightweight but real frontend/router behavioral scenario on k3d.
8. Synchronize the site catalog, documentation, playground, icon, and all
   organization chart counts.
