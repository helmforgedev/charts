# OpenClaw design

The chart packages the official OpenClaw gateway as one persistent StatefulSet replica. The gateway owns SQLite state,
agent directories, device identities, sessions and workspaces. Kubernetes replaces the existing Pod before admitting its
successor. This is a single-writer deployment with planned downtime, not an HA service or a tenant isolation boundary.

The official image and its real tini entrypoint are preserved. UID/GID 1000, a read-only root filesystem, dropped
capabilities, RuntimeDefault seccomp and no service-account token reduce container privileges. Writable home and temporary
storage remain necessary for the application. Tools execute with the agent's credentials and permissions; enabling shell
tools does not create a sandbox. Remote execution requires an explicitly configured supported upstream backend.

The default minimal tool profile exposes only session status. Providers and channel tokens come from Secrets. Gateway
token authentication remains enabled, and Control UI device authentication is never bypassed. The unauthenticated UI shell
is not proof of an authenticated session. The optional OpenAI/OpenResponses endpoints grant operator-level authority and
must remain private to trusted clients.

Configuration has explicit ownership. Managed mode reconciles declared files at Pod initialization. Seed mode writes
missing files and preserves subsequent operator changes. Updates to bootstrap scripts/configuration trigger rollout by
checksum; changes to existing external Secrets require a rollout. A generated gateway token is recovered by Secret lookup
and retained with the PVC, avoiding silent identity rotation during upgrades.

The gateway's current bind implementation is IPv4-only. Service family settings deliberately reject IPv6 and dual-stack
requests until the upstream listener can support them. Ingress and Gateway API route to the same authenticated gateway;
TLS termination, WebSocket upgrade support and timeout policy belong to the selected controller.

The release bundles diagnostics-otel. A pinned official collector receives metrics on loopback and exposes a private
Prometheus Service. This avoids downloading plugins at startup and avoids giving Prometheus a gateway operator token.
Traces, logs and model content export are disabled in the chart's metrics integration. Provider usage coverage is not a
financial accounting guarantee.

Backups use the same OpenClaw version and its native verified archive API. Native SQLite online snapshots capture WAL
commits and sanitize transient ownership/delivery state. They do not provide global atomicity across databases and files.
The uploader receives only the staging volume and S3 credentials. Archive bytes are read back and hashed before publishing
the completion manifest. Restore verifies the manifest/hash and native archive, extracts into isolated staging, and only
activates into an empty home volume. Interrupted activation fails closed and requires inspection rather than overwriting.

The test strategy uses the actual gateway and a deterministic local model service. The fixture returns tool calls; only
OpenClaw writes agent state. Paid providers and real messaging accounts are outside automated acceptance.
