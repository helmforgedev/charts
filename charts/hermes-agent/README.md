# Hermes Agent

Deploy [Hermes Agent](https://hermes-agent.nousresearch.com/) as a persistent, authenticated agent gateway using the official Nous Research image. One release
owns its sessions, memory, learned skills, schedules and workspace.

## Features

- Verified official release and immutable multi-platform image digest.
- Singleton StatefulSet, retained data and API identity, non-root execution and read-only installation.
- Authenticated OpenAI-compatible API, explicit toolsets and messaging user allowlists.
- Managed or seed-once configuration, bundled skills and optional privileged dashboard with separate authentication.
- Existing Secrets and canonical External Secrets Operator integration.
- Default-deny inbound networking, Ingress, Gateway API and explicit dual-stack API and dashboard support.
- Native OTLP gateway metrics, optional official collector, ServiceMonitor and PrometheusRule.
- Scheduled S3 backups with SQLite snapshots, file inventories, remote byte verification and empty-volume-only recovery.

## Install

Create a provider Secret from an environment file that is not committed to Git. For the default OpenRouter provider, include OPENROUTER_API_KEY. Select another
model/provider in values as needed.

```bash
kubectl create namespace agents
kubectl -n agents create secret generic hermes-provider --from-env-file=provider.env
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm upgrade --install hermes helmforge/hermes-agent --namespace agents \
  --set credentials.existingSecret=hermes-provider
```

OCI distribution is also available at `oci://ghcr.io/helmforgedev/helm/hermes-agent`. Kubernetes 1.30 or newer and a suitable StorageClass are required. The
default gateway requests 1Gi memory; increase it for browser, terminal, MCP and concurrent work. An arm64 image manifest exists; the local runtime evidence is
Linux amd64.

The generated API Secret is `<fullname>-auth`, key `api-key`. Supply `auth.existingSecret` for stable render-only GitOps identity. A Ready Pod confirms gateway
health, not provider billing/quota or external platform access.

## Connect

```bash
kubectl -n agents port-forward service/hermes-hermes-agent 8642:8642
```

Use an OpenAI-compatible client with base URL `http://127.0.0.1:8642/v1` and the API bearer token. API credentials authorize the selected agent tools. For
in-cluster clients, configure `networkPolicy.ingressFrom`; for external clients, terminate TLS at a trusted ingress/Gateway controller. Default toolsets permit
memory only.

## Production boundaries

This chart runs one trusted agent, with one gateway writer. There is no horizontal scaling or transparent HA; upgrades and node replacement cause downtime.
Separate untrusted agents into separate releases and credentials. The optional dashboard is a full administrative surface in the same trust boundary. No default
host socket, privileged container or Kubernetes API token is granted.

The chart-owned acceptance fixture drives real Hermes inference orchestration and tool calls without paid external requests. Cloud credentials, live messaging,
remote execution and OIDC providers still require environment-specific acceptance. See the operational guides below before enabling additional tools.

## Operational guides

- [Design and trust boundaries](DESIGN.md)
- [Providers, dashboard, messaging and upgrades](docs/operations.md)
- [Backup and disaster recovery](docs/backup-restore.md)
- [Native observability](docs/observability.md)

## Values reference

All default values are listed below; upstream pass-through configuration remains under `config.values`.

| Value | Default | Purpose |
| --- | --- | --- |
| `nameOverride` | `""` | Override the chart name used in resource labels. |
| `fullnameOverride` | `""` | Override all resource name prefixes for a stable existing installation. |
| `image` | Object | Official Hermes runtime, pinned to a verified multi-platform release digest. |
| `image.repository` | `"docker.io/nousresearch/hermes-agent"` | Official container image repository. |
| `image.tag` | `"v2026.9.11@sha256:9469b3e78b9545b6d576eb8887a95352e9a0ea83730eaf31431cf862ca1010e1"` | Pinned release tag and immutable digest. |
| `image.pullPolicy` | `"IfNotPresent"` | Kubernetes image pull policy. |
| `imagePullSecrets` | `[]` | image pull secrets setting for the gateway. |
| `auth` | Object | Bearer credential protecting API access and configured agent tools. |
| `auth.existingSecret` | `""` | Use an existing Secret; empty generates a random token retained with persistent state. |
| `auth.key` | `"api-key"` | Secret key containing the API bearer token. |
| `credentials` | Object | Provider and messaging credentials are injected only from a Kubernetes Secret. |
| `credentials.existingSecret` | `""` | Secret containing upstream environment variables such as OPENROUTER_API_KEY. |
| `agent` | Object | Default model and explicitly allowed API toolsets. |
| `agent.model` | `"anthropic/claude-opus-4.6"` | Upstream model identifier; a corresponding provider credential is required for inference. |
| `agent.provider` | `"openrouter"` | Provider identifier, including custom:<name> for an OpenAI-compatible endpoint. |
| `agent.baseUrl` | `""` | Optional model endpoint; custom providers should use apiKeyEnv for credential selection. |
| `agent.toolsets` | `["memory"]` | API toolsets. Memory-only by default; enabling terminal/browser grants additional capabilities. |
| `agent.maxIterations` | `30` | Maximum tool execution turns for one agent request. |
| `agent.apiKeyEnv` | `""` | Credential environment variable for a named custom provider; never an inline API key. |
| `agent.allowInsecureHTTP` | `false` | Explicit HTTP exception for credentialed custom endpoints in isolated tests or trusted networks. |
| `config` | Object | Non-secret upstream configuration with explicit ownership on Pod initialization. |
| `config.policy` | `"managed"` | managed reconciles declared files; seed preserves existing files and permits dashboard edits. |
| `config.values` | `{}` | Additional upstream configuration. Do not place credentials here; chart-owned sections are validated. |
| `config.soul` | `""` | Optional SOUL.md persona. Empty leaves upstream/user persona unmanaged. |
| `persistence` | Object | One retained state volume per release; no concurrent gateway writers. |
| `persistence.enabled` | `true` | Persist sessions, SQLite state, memory, skills and workspace. |
| `persistence.existingClaim` | `""` | Existing persistent claim to mount instead of creating one. |
| `persistence.storageClass` | `""` | StorageClass name; empty uses the cluster default. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | Claim access modes; shared backup mounts require RWO or RWX. |
| `persistence.size` | `"10Gi"` | Requested persistent volume capacity. |
| `persistence.retain` | `true` | Keep chart-created PVC and generated API Secret after uninstall. |
| `service` | Object | service setting for the gateway. |
| `service.type` | `"ClusterIP"` | type setting for service. |
| `service.port` | `8642` | Service port; network policies use the fixed container port. |
| `service.annotations` | `{}` | Additional Kubernetes annotations. |
| `service.ipFamilyPolicy` | `""` | ip family policy setting for service. |
| `service.ipFamilies` | `[]` | ip families setting for service. |
| `service.loadBalancerSourceRanges` | `[]` | load balancer source ranges setting for service. |
| `serviceAccount` | Object | service account setting for the gateway. |
| `serviceAccount.create` | `true` | create setting for serviceAccount. |
| `serviceAccount.name` | `""` | Existing or overridden Kubernetes resource name. |
| `serviceAccount.annotations` | `{}` | Additional Kubernetes annotations. |
| `resources` | Object | Container CPU and memory requests and limits. |
| `resources.requests` | Object | Guaranteed scheduler resource requests. |
| `resources.requests.cpu` | `"250m"` | CPU quantity. |
| `resources.requests.memory` | `"1Gi"` | Memory quantity. |
| `resources.limits` | Object | Enforced container resource limits. |
| `resources.limits.cpu` | `"2"` | CPU quantity. |
| `resources.limits.memory` | `"2Gi"` | Memory quantity. |
| `nodeSelector` | Object | node selector setting for the gateway. |
| `nodeSelector.kubernetes.io/os` | `"linux"` | See the values contract. |
| `tolerations` | `[]` | tolerations setting for the gateway. |
| `affinity` | `{}` | affinity setting for the gateway. |
| `podAnnotations` | `{}` | pod annotations setting for the gateway. |
| `extraEnv` | `[]` | extra env setting for the gateway. |
| `networkPolicy` | Object | Default-deny ingress with separate API, dashboard and metrics peer allowlists. |
| `networkPolicy.enabled` | `true` | Enable this optional integration. |
| `networkPolicy.ingressFrom` | `[]` | Kubernetes NetworkPolicy peers allowed to call container port 8642. |
| `networkPolicy.extraEgress` | `[]` | Explicit extra egress rules for custom providers, MCP servers or remote execution. |
| `networkPolicy.allowInternet` | `true` | Allow public IPv4/IPv6 HTTPS egress for providers; private networks require extraEgress. |
| `terminationGracePeriodSeconds` | `120` | Time for gateway shutdown and in-flight work before Kubernetes terminates the Pod. |
| `channels` | Object | Opt-in messaging adapters; credentials come from credentials.existingSecret and user allowlists are required. |
| `channels.telegram` | Object | telegram setting for channels. |
| `channels.telegram.enabled` | `false` | Enable this optional integration. |
| `channels.telegram.allowedUsers` | `[]` | Explicit upstream user IDs permitted to interact with this messaging adapter. |
| `channels.telegram.toolsets` | `["memory"]` | Toolsets exposed to this messaging adapter. |
| `channels.discord` | Object | discord setting for channels. |
| `channels.discord.enabled` | `false` | Enable this optional integration. |
| `channels.discord.allowedUsers` | `[]` | Explicit upstream user IDs permitted to interact with this messaging adapter. |
| `channels.discord.toolsets` | `["memory"]` | Toolsets exposed to this messaging adapter. |
| `channels.slack` | Object | slack setting for channels. |
| `channels.slack.enabled` | `false` | Enable this optional integration. |
| `channels.slack.allowedUsers` | `[]` | Explicit upstream user IDs permitted to interact with this messaging adapter. |
| `channels.slack.toolsets` | `["memory"]` | Toolsets exposed to this messaging adapter. |
| `dashboard` | Object | Optional privileged administration UI in the gateway Pod; requires config.policy=seed. |
| `dashboard.enabled` | `false` | Enable this optional integration. |
| `dashboard.existingSecret` | `""` | Secret with HERMES_DASHBOARD_BASIC_AUTH_USERNAME, HERMES_DASHBOARD_BASIC_AUTH_PASSWORD and HERMES_DASHBOARD_BASIC_AUTH_SECRET. |
| `dashboard.publicUrl` | `""` | External HTTPS dashboard origin, used by Host validation and OAuth redirects. |
| `dashboard.resources` | Object | Container CPU and memory requests and limits. |
| `dashboard.resources.requests` | Object | Guaranteed scheduler resource requests. |
| `dashboard.resources.requests.cpu` | `"100m"` | CPU quantity. |
| `dashboard.resources.requests.memory` | `"256Mi"` | Memory quantity. |
| `dashboard.resources.limits` | Object | Enforced container resource limits. |
| `dashboard.resources.limits.cpu` | `"1"` | CPU quantity. |
| `dashboard.resources.limits.memory` | `"1Gi"` | Memory quantity. |
| `dashboard.service` | Object | service setting for dashboard. |
| `dashboard.service.port` | `9119` | Service port; network policies use the fixed container port. |
| `dashboard.service.annotations` | `{}` | Additional Kubernetes annotations. |
| `dashboard.ingressFrom` | `[]` | NetworkPolicy peers allowed to reach the administrative dashboard on container port 9119. |
| `ingress` | Object | Optional API ingress. TLS termination is the ingress controller responsibility. |
| `ingress.enabled` | `false` | Enable this optional integration. |
| `ingress.ingressClassName` | `""` | ingress class name setting for ingress. |
| `ingress.annotations` | `{}` | Additional Kubernetes annotations. |
| `ingress.hosts` | `[{"host":"hermes.example.com","paths":[{"path":"/","pathType":"Prefix"}]}]` | hosts setting for ingress. |
| `ingress.tls` | `[]` | tls setting for ingress. |
| `gatewayAPI` | Object | Canonical Gateway API HTTPRoutes; backend defaults to the authenticated API Service. |
| `gatewayAPI.enabled` | `false` | Enable this optional integration. |
| `gatewayAPI.httpRoutes` | `[]` | http routes setting for gatewayAPI. |
| `externalSecrets` | Object | Optional integration with an existing External Secrets Operator installation. |
| `externalSecrets.enabled` | `false` | Enable this optional integration. |
| `externalSecrets.refreshInterval` | `"1h"` | refresh interval setting for externalSecrets. |
| `externalSecrets.items` | `[]` | items setting for externalSecrets. |
| `metrics` | Object | Native Hermes gateway health metrics exported through OTLP; no synthetic inference/cost metrics. |
| `metrics.enabled` | `false` | Enable native upstream OTLP gateway-health metrics. |
| `metrics.intervalSeconds` | `15` | interval seconds setting for metrics. |
| `metrics.externalEndpoint` | `""` | Full external OTLP HTTP metrics URL ending in /v1/metrics when the collector is disabled. |
| `metrics.collector` | Object | Optional local official collector translating OTLP to Prometheus on port 8889. |
| `metrics.collector.enabled` | `true` | Enable this optional integration. |
| `metrics.collector.image` | Object | image setting for metrics.collector. |
| `metrics.collector.image.repository` | `"ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib"` | Official container image repository. |
| `metrics.collector.image.tag` | `"0.160.0@sha256:799dc6cf12c96192af37b5bdba804da8c10b3bc563b43cb90c3f3c58d9572ad6"` | Pinned release tag and immutable digest. |
| `metrics.collector.image.pullPolicy` | `"IfNotPresent"` | Kubernetes image pull policy. |
| `metrics.collector.resources` | Object | Container CPU and memory requests and limits. |
| `metrics.collector.resources.requests` | Object | Guaranteed scheduler resource requests. |
| `metrics.collector.resources.requests.cpu` | `"50m"` | CPU quantity. |
| `metrics.collector.resources.requests.memory` | `"64Mi"` | Memory quantity. |
| `metrics.collector.resources.limits` | Object | Enforced container resource limits. |
| `metrics.collector.resources.limits.cpu` | `"500m"` | CPU quantity. |
| `metrics.collector.resources.limits.memory` | `"256Mi"` | Memory quantity. |
| `metrics.serviceMonitor` | Object | service monitor setting for metrics. |
| `metrics.serviceMonitor.enabled` | `false` | Enable this optional integration. |
| `metrics.serviceMonitor.labels` | `{}` | Additional Kubernetes labels. |
| `metrics.serviceMonitor.interval` | `"30s"` | Prometheus scrape interval. |
| `metrics.serviceMonitor.scrapeTimeout` | `"10s"` | Prometheus scrape timeout. |
| `metrics.prometheusRule` | Object | prometheus rule setting for metrics. |
| `metrics.prometheusRule.enabled` | `false` | Enable this optional integration. |
| `metrics.prometheusRule.labels` | `{}` | Additional Kubernetes labels. |
| `metrics.prometheusRule.additionalRules` | `[]` | additional rules setting for metrics.prometheusRule. |
| `metrics.ingressFrom` | `[]` | NetworkPolicy peers allowed to scrape the private metrics Service. |
| `backup` | Object | Scheduled SQLite-consistent native snapshots uploaded to S3 with a completion manifest. |
| `backup.enabled` | `false` | Enable the backup CronJob; requires persistent storage and S3 configuration. |
| `backup.schedule` | `"0 3 * * *"` | schedule setting for backup. |
| `backup.timeZone` | `"Etc/UTC"` | time zone setting for backup. |
| `backup.suspend` | `false` | suspend setting for backup. |
| `backup.successfulJobsHistoryLimit` | `1` | successful jobs history limit setting for backup. |
| `backup.failedJobsHistoryLimit` | `2` | failed jobs history limit setting for backup. |
| `backup.activeDeadlineSeconds` | `1800` | active deadline seconds setting for backup. |
| `backup.stagingSize` | `"10Gi"` | Ephemeral archive staging size; budget for the ZIP and temporary SQLite snapshots. |
| `backup.resources` | Object | Container CPU and memory requests and limits. |
| `backup.resources.requests` | Object | Guaranteed scheduler resource requests. |
| `backup.resources.requests.cpu` | `"100m"` | CPU quantity. |
| `backup.resources.requests.memory` | `"256Mi"` | Memory quantity. |
| `backup.resources.limits` | Object | Enforced container resource limits. |
| `backup.resources.limits.cpu` | `"1"` | CPU quantity. |
| `backup.resources.limits.memory` | `"1Gi"` | Memory quantity. |
| `backup.s3` | Object | s3 setting for backup. |
| `backup.s3.bucket` | `""` | bucket setting for backup.s3. |
| `backup.s3.prefix` | `"hermes-agent"` | prefix setting for backup.s3. |
| `backup.s3.region` | `"us-east-1"` | region setting for backup.s3. |
| `backup.s3.endpoint` | `""` | endpoint setting for backup.s3. |
| `backup.s3.allowInsecureEndpoint` | `false` | Allow HTTP only for explicitly trusted local test/object-storage networks. |
| `backup.s3.existingSecret` | `""` | Secret with AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY, optionally AWS_SESSION_TOKEN. |
| `backup.s3.sse` | `"AES256"` | sse setting for backup.s3. |
| `backup.s3.kmsKeyId` | `""` | kms key id setting for backup.s3. |
| `backup.s3.caSecret` | `""` | Optional Secret containing ca.crt for a private HTTPS endpoint. |
| `backup.image` | Object | image setting for backup. |
| `backup.image.repository` | `"public.ecr.aws/aws-cli/aws-cli"` | Official container image repository. |
| `backup.image.tag` | `"2.36.43@sha256:d948ee299a7ffcaec0d6052a00b9f4c513c61cacfaedfe68b098c85808394441"` | Pinned release tag and immutable digest. |
| `backup.image.pullPolicy` | `"IfNotPresent"` | Kubernetes image pull policy. |
| `backup.networkPolicy` | Object | network policy setting for backup. |
| `backup.networkPolicy.extraEgress` | `[]` | Additional backup Pod egress, for example private object storage. |
| `restore` | Object | Explicit disaster recovery into an empty volume before configuration initialization. |
| `restore.enabled` | `false` | Restore exactly once into empty state; existing nonempty state is never overwritten. |
| `restore.manifestKey` | `""` | Full S3 object key of the completed backup manifest; uses backup.s3 settings. |
| `restore.maxArchiveBytes` | `10737418240` | Maximum downloaded archive size accepted in bytes. |
| `restore.maxExpandedBytes` | `21474836480` | Maximum aggregate uncompressed archive bytes accepted during restore. |

## Security Scan: hermes-agent

| Framework | Score |
| --- | --- |
| MITRE + NSA + SOC2 | 99.393936% |

Security posture acceptable. Scanned the production example with Kubescape v4.0.14.
The remaining C-0012 finding identifies the literal Bearer authorization header in
the readiness helper ConfigMap; the actual token is read from the Secret-backed
process environment and is not embedded in the ConfigMap.
