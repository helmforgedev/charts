# Hermes Agent design

## One trusted agent per release

Hermes combines an agent loop, persistent memory, learned skills, SQLite session history, scheduled work, messaging adapters and an OpenAI-compatible API. These
capabilities share one state directory and execution identity. The chart deploys one StatefulSet replica and one retained PVC; adding replicas would create
competing gateway writers. Kubernetes reschedules the singleton, with downtime. This is not an HA or multi-tenant isolation design.

Use separate releases, Secrets, storage and network policies for mutually untrusted agents. API credentials permit the selected tools. The optional dashboard
has full administrative access to the same state and process namespace. The default API toolset contains only memory; enabling terminal, browser, MCP or other
tools expands that trust boundary.

## Official image and immutable execution

The chart pins the official Nous Research multi-platform image by release and manifest digest. The tested release is v2026.9.11; its internal Python version
string is 0.21.2. Linux amd64 was exercised in k3d; an arm64 manifest is present but was not runtime-tested here.

The image's standard s6 startup performs root-only initialization. Kubernetes instead starts the official gateway/dashboard foreground commands as UID/GID 10000
with a read-only root filesystem and all capabilities dropped. A configure init container creates state directories, reconciles declared files and synchronizes
the image's bundled skills. A small exec-only entrypoint discovers the bundled Chromium binary without downloading anything. Runtime lazy installation is
disabled.

The Pod shares its process namespace so the Kubernetes sandbox process reaps orphaned children and the dashboard can observe the gateway PID. No host PID
namespace, host Docker socket, default API token, ClusterRole or privileged container is used. The collector has no agent-state mount; the backup uploader has
only completed archive staging.

## Configuration and identity lifecycle

`config.policy=managed` reconciles config.yaml at every Pod initialization. `seed` writes it only when absent and is required for dashboard editing. SOUL.md is
chart-managed only when `config.soul` is nonempty; an empty value leaves an existing persona untouched. Seed mode also preserves existing provider, monitoring
and platform configuration: changing values alone does not replace the seeded file. Choose a deliberate maintenance migration back to managed mode when needed.

Generated API credentials use live Helm lookup and are retained with the PVC. Render-only GitOps controllers should supply an existing Secret or ESO-generated
Secret; random render output is not a stable identity. Secret changes do not automatically restart environment consumers. Roll the StatefulSet after credential
rotation. Secret names, keys and chart-created retention are explicit contracts.

## Connectivity and health

The API listens on container port 8642. Ingress and HTTPRoute target its Service; dashboard administration uses a separate private Service on 9119. Network
policies select container ports independently of user-facing Service ports. Inbound API, dashboard and metrics peers are separate allowlists. Public HTTPS
egress is available by default; private provider/MCP/S3 endpoints require explicit extra rules. The chart does not provide DNS-name-aware egress filtering.

Liveness uses inexpensive public process health. Readiness parses authenticated `/health/detailed`: upstream can return HTTP 200 while reporting degraded
readiness. A healthy gateway is not proof that a paid model credential has quota or that an external messaging platform is reachable.

## Observability and recovery

Hermes exports native gateway-health metrics through OTLP. An optional official collector accepts OTLP only on loopback and exposes Prometheus metrics through a
restricted Service. ServiceMonitor and PrometheusRule integrate with an existing Prometheus Operator. These are native gateway/scheduler metrics, not inferred
token costs or request accounting.

Backups use the pinned native exclusion policy, backup lock and SQLite online backup helper inside a stricter archive pipeline. Missing files, unreadable data
and failed database snapshots prevent success. Checksums cover every member and the complete ZIP. The uploader reads the remote archive back and compares its
bytes before publishing the completion manifest. The consistency boundary is each SQLite database; ordinary files and separate databases are not captured in one
global transaction.

Recovery validates an archive in staging before copying to an empty volume. A persistent incomplete marker prevents gateway startup after interrupted
publication. A completion marker makes later Pod restarts idempotent. Importing upstream backup code has initialization side effects, so recovery uses a
temporary HERMES_HOME and a separate target path. It never invokes native service-revival or overwrite import commands.

## Comparison and implementation provenance

The community chart at <https://github.com/ultraworkers/hermes-agent-helm-chart> already offers useful non-root security, API authentication, ESO and network
isolation. This implementation was written independently using HelmForge conventions. It adds a verified current image, explicit configuration ownership,
retained identity/state, semantic readiness, native telemetry and tested S3 disaster recovery. No unsupported operator or multi-tenant CRDs are installed.

## Validation scope

The chart-owned runtime harness drives the real Hermes agent and memory tool using a deterministic local OpenAI-compatible provider. It checks authentication,
network isolation, state survival, metrics, dashboard login, ESO and S3 recovery in the relevant profiles. This validates integration mechanics without paid API
calls or messages to real users. Cloud provider credentials, live Telegram/Discord/Slack delivery, remote SSH services and OIDC identity providers still require
environment-specific acceptance.
