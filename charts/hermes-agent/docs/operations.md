# Operating Hermes Agent

## Provider credentials

Create a Secret from an environment file kept outside version control, then set `credentials.existingSecret`:

```bash
kubectl -n agents create secret generic hermes-provider --from-env-file=provider.env
helm upgrade --install hermes helmforge/hermes-agent -n agents \
  --set credentials.existingSecret=hermes-provider
```

For OpenRouter, the file contains `OPENROUTER_API_KEY`. For a custom OpenAI-compatible endpoint, use `agent.provider=custom:internal`, `agent.baseUrl` and
`agent.apiKeyEnv` naming the environment variable in that Secret. The pinned upstream release intentionally does not forward generic OPENAI_API_KEY credentials
to arbitrary hosts. Provider URL, model and credentials must agree.

The API implements OpenAI-compatible chat completions and requires `Authorization: Bearer <API token>`. This API token is distinct from the provider key and
dashboard credentials. Use `X-Hermes-Session-Id` for gateway-backed conversation continuity. A new session reloads persistent memory; existing sessions can
retain their original system prompt.

## Tool and messaging access

Default `agent.toolsets: [memory]` avoids exposing terminal/browser execution through a newly installed API. Configure additional native toolsets only for
trusted API users. Terminal tools using the local backend can read and modify the agent's data and environment. Remote SSH or other upstream execution backends
can be configured under `config.values.terminal`; provision their authentication, host verification, network access and independent runtime tests before use.
The chart does not claim a sandbox merely because it uses a container.

Telegram requires `TELEGRAM_BOT_TOKEN`; Discord requires `DISCORD_BOT_TOKEN`; Slack Socket Mode requires `SLACK_BOT_TOKEN` and `SLACK_APP_TOKEN`. Store them in
`credentials.existingSecret`, enable the corresponding `channels` entry and declare its `allowedUsers`. Use platform user/member IDs, not display names. Each
adapter has its own `toolsets`. Do not set allow-all variables in the credential Secret. The chart explicitly sets supported adapter allow-all flags to false
and owns the configured user lists.

The supported default transports are outbound polling/WebSocket/Socket Mode. No extra inbound Service is needed. Upstream plugins, other channels and external
tools may need additional dependencies or network access; they are not all included in the chart's runtime acceptance matrix.

## Dashboard administration

Enable the dashboard with `config.policy=seed` and `dashboard.existingSecret`. For basic login, that Secret contains `HERMES_DASHBOARD_BASIC_AUTH_USERNAME`,
`HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` and a stable, random `HERMES_DASHBOARD_BASIC_AUTH_SECRET` of at least 32 bytes. Upstream also accepts a password hash
instead of plaintext. For public access, use HTTPS and the upstream OIDC provider variables in this Secret, with `dashboard.publicUrl` and bounded
`config.values.dashboard.trusted_proxies`.

The chart exposes the dashboard through a separate ClusterIP Service. Use a trusted tunnel or an explicit HTTPRoute backend reference to `<fullname>-dashboard`
and `dashboard.service.port`; permit the controller through `dashboard.ingressFrom`. API ingress defaults never silently expose the administration UI. OIDC
identity-provider integration is environment-specific; basic login and session-cookie authentication are exercised locally.

Dashboard users are administrators of the same agent, not isolated tenants. Kubernetes owns lifecycle and image updates: use Helm rollouts instead of UI
self-update or gateway start/restart controls. The read-only installation intentionally prevents runtime package modifications. Changes to an existing seed-mode
config survive Helm upgrades; to reconcile declared config again, disable the dashboard, switch to managed policy for the rollout, then deliberately return to
seed mode.

## Upgrades, retention and credentials

Take and restore-test a backup before changing the image tag/digest together. Inspect upstream release notes for SQLite/config migrations; a Helm image rollback
cannot undo an incompatible data migration. One writer means a rollout or node drain interrupts service. Avoid a mandatory singleton PDB that prevents
deliberate maintenance.

PVC and generated API Secret are retained after uninstall by default. Reinstall with the same release/namespace/fullname to reuse them. An existing claim and
externally managed Secrets retain their own lifecycle. Keep the release identity stable and never attach its data to two gateways.

For GitOps, select `auth.existingSecret` or configure `externalSecrets.items[]` to project that Secret through an already installed ESO. Rotating a Secret
requires a Pod rollout because provider/API/dashboard credentials are environment variables. Do not change the key name of a retained generated Secret without
an explicit Secret migration.

## Troubleshooting

- API 401/403: check the API token, not the provider credential; never post credential values in logs/issues.
- Agent responds with provider authentication errors: verify the selected provider, model, endpoint and named custom provider `key_env` mapping.
- Service timeout with a Ready Pod: inspect the relevant NetworkPolicy peer list and fixed container target port.
- HTTP 200 from health but Pod not Ready: inspect authenticated detailed readiness and its individual checks.
- New values do not affect runtime: check whether `config.policy=seed` is preserving an existing config.yaml.
- Pending backup Pod: ensure the state PVC supports concurrent same-node mounts; ReadWriteOncePod is incompatible with this design.
- Missing skills/browser binaries: inspect configure logs and the pinned official image; do not enable ad hoc dependency downloads to hide a broken image
  upgrade.
- Restore refuses startup: preserve the incomplete volume for diagnosis and recover again into a new empty PVC. Do not bypass the incomplete marker.

## Transport security and collector identity

Credentialed custom endpoints require HTTPS by default. `agent.allowInsecureHTTP=true` is an explicit exception for isolated fixtures or a trusted private
transport; never use it for public provider traffic. Advanced upstream provider configuration under `config.values` must follow the same transport policy.

Public API and dashboard clients must use HTTPS at the trusted edge. The production example attaches only to a Gateway HTTPS listener. When using Ingress,
configure its TLS Secret or an external TLS terminator, and configure that controller or load balancer to reject HTTP or redirect it before clients send
credentials. A generic Ingress has no portable redirect field, so the chart does not inject controller-specific annotations or require a local TLS Secret when
termination occurs upstream. Ingress stays disabled and inbound traffic denied by default.

The gateway and administrative dashboard use UID 10000 in a shared PID namespace. The metrics collector uses UID/GID 10001 with all capabilities dropped; it
cannot read the gateway's process environment. It has no state-volume or credential Secret mount. The production example budgets 120Gi of node staging for its
50Gi persistent state and raises restore bounds accordingly; verify node ephemeral-storage capacity before scheduling backup or recovery.
