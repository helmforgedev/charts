# Operations and configuration

OpenClaw is a personal/operator-trusted gateway. Deploy separate releases and claims for independent trust domains.
There is one writer per release. Do not scale its StatefulSet or reuse its claim in another active gateway.

## First access and device pairing

Port-forward the Service to local port 18789 and open `http://localhost:18789`. Retrieve the gateway token from the Secret
named in Helm NOTES. Supply it in the Control UI connection settings. Treat token-bearing URLs as credentials and keep
them out of logs and tickets. Remote browser access needs HTTPS, an exact `gateway.controlUi.allowedOrigins` entry,
WebSocket-capable routing, and a NetworkPolicy peer allowlist.

With NetworkPolicy enabled, Ingress or Gateway API requires nonempty `networkPolicy.ingressFrom` selectors for the
actual controller Pods/namespaces. Missing selectors fail rendering. Route names must be unique; rendered HTTPRoute
names include a deterministic hash to keep long names distinct. Parent Helm `global` values are accepted when using
this chart as a dependency; application settings and images still use this chart's explicit values.

Remote device enrollment remains enabled. Inspect `openclaw devices list` in the running container and approve only the
request ID associated with the intended browser using `openclaw devices approve <requestId>`. Local loopback connections
can be auto-approved after authentication; this is not evidence of remote pairing. Do not enable dangerous device or
origin bypass flags. Configure `gateway.trustedProxies` only for the actual reverse-proxy addresses.

## Models, tools, agents and channels

Set `agent.model` to an upstream provider/model ID and supply its environment key through `credentials.existingSecret`.
Custom provider definitions belong in `config.values.models.providers`; use SecretRef or environment placeholders for
API keys, never literal credentials in values. An OpenAI-compatible backend normally uses `api: openai-completions`.

`agent.toolProfile` defaults to `minimal`. Add specific tools with `agent.allowTools`; deny unwanted tools with
`agent.denyTools`. Filesystem tools are workspace-limited and elevated execution is disabled. Shell execution still has
access to the container's writable data and environment. Kubernetes hardening does not turn mutually untrusted agents
into isolated tenants. Configure upstream remote sandboxing in `agent.defaults.sandbox` when needed and independently
validate the selected remote service. The chart does not mount a Docker socket or grant cluster permissions.

`agent.defaults` accepts additional upstream settings, such as memory search and heartbeat. `agent.entries` adds named
agents; state and workspace paths must remain below `/home/node` for automated recovery. Model routing and other
non-secret upstream settings can be supplied in `config.values`. Keep application state on the persistent home volume.

Telegram and Discord are opt-in and require nonempty `allowFrom` lists plus their upstream environment token in the
credentials Secret. Group traffic is disabled by the simple chart contract. Test account access and permissions before
connecting real users. External APIs, channels and browser services have their own permissions and recovery requirements.

## Ownership and upgrades

Managed mode applies declared JSON, AGENTS.md and SOUL.md on initialization. Existing state and sessions are preserved;
operator edits to managed files are overwritten at the next restart. Empty instruction values leave those workspace
files unmanaged. Seed mode initializes missing files only; subsequent UI/CLI edits are authoritative. Updating values
in seed mode does not overwrite existing config. Back up before deliberately replacing or reseeding an existing file.

Rotate external credentials by updating the Secret and restarting the StatefulSet. Keep the generated gateway Secret
with retained state; changing a token deliberately can require updating clients. Uninstall retains the chart-created
claim and generated Secret by default. Reinstall with the same release identity to reuse them, or explicitly reference
the retained resources. Claims are independent of StatefulSet recreation.

Before upgrading, create and verify a recovery point, review upstream migrations and schedule downtime. Kubernetes
owns restarts and the image is immutable: do not run self-update inside the gateway. Helm rollback does not reverse
database migrations. If an older release cannot read the upgraded schema, recover a pre-upgrade archive into a new claim.

## Health and networking

Startup/readiness inspect `/startupz` JSON; liveness inspects `/healthz`. `/readyz` includes individual channel health and
is useful for diagnosis without evicting the entire UI when a channel is down. Probes reject the UI's HTML fallback.
The current upstream gateway binds IPv4; IPv6 Service requests are rejected by the chart.

NetworkPolicy denies ingress unless callers are explicitly selected. Default egress permits cluster DNS and public HTTPS;
private model servers, MCP, remote browsers and non-HTTPS services need `networkPolicy.extraEgress`. Ingress controllers
also require an ingress peer rule. Controller-specific TLS redirects and WebSocket timeouts must be configured at the edge.
