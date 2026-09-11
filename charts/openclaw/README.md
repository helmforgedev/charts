# OpenClaw

Deploy [OpenClaw](https://docs.openclaw.ai/) as a persistent, authenticated agent gateway using its official container image.
One installation owns its device pairing, agent sessions, tools, memory and workspaces.

## Features

- Official immutable release image; singleton StatefulSet and retained state/token identity.
- Restricted non-root runtime with the upstream tini entrypoint and no Kubernetes API token.
- Control UI with device pairing, exact origins, private Ingress and Gateway API.
- Explicit managed/seed configuration, named agents, provider Secrets and channel allowlists.
- Native OTLP metrics, official collector, private Prometheus Service, ServiceMonitor and alert rules.
- Native SQLite-consistent archives, verified S3 publication and empty-volume disaster recovery.
- Full values schema and application behavior tests with a local model provider.

## Install

Kubernetes 1.30 or newer and a suitable StorageClass are required. The image publishes Linux AMD64 and ARM64 manifests;
runtime acceptance is performed on AMD64. The gateway currently supports IPv4 listeners.

Create a namespace and a provider Secret from a local environment file excluded from version control. For the default
Anthropic model, include ANTHROPIC_API_KEY. Ready gateway health alone does not validate provider credentials or quota.

```bash
kubectl create namespace agents
kubectl -n agents create secret generic openclaw-provider --from-env-file=provider.env
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm upgrade --install openclaw helmforge/openclaw --namespace agents \
  --set credentials.existingSecret=openclaw-provider
```

OCI: `oci://ghcr.io/helmforgedev/helm/openclaw`.
Use `auth.existingSecret` for render-only GitOps so offline renders do not generate different tokens.
The default generated Secret is `<fullname>-auth`, key `gateway-token`; Helm upgrades preserve it by lookup.

## Access and trust

Port-forward the Service to 18789 and open `http://localhost:18789`. Use the gateway token in the UI connection settings.
Remote access needs HTTPS and an explicit allowed origin. Approve only the intended pending device; pairing is preserved
across restarts. Gateway tokens authorize operator APIs and enabled tools. Keep model APIs private to trusted callers.

One release is one operator trust boundary. There is no shared-writer HA or HPA. Enable shell/browser tools only with an
understood execution boundary. Upgrades require downtime; preserve a verified recovery point before schema migrations.

## Guides

- [Operations, models, agents, channels and upgrades](docs/operations.md)
- [Native backup and S3 recovery](docs/backup.md)
- [Observability](docs/observability.md)
- [Design and limitations](DESIGN.md)

## Examples

See [simple](examples/simple.yaml), [staging](examples/staging.yaml), [production](examples/production.yaml),
[custom provider](examples/custom-provider.yaml) and [recovery](examples/restore.yaml).
Replace hostnames, Secret names and selectors with your environment's actual resources.

## Security Scan

Security Scan: openclaw

| Framework | Score |
| --- | --- |
| MITRE + NSA + SOC2 | 99.393936% |

Security posture acceptable. Scanned production manifests with Kubescape v4.0.14.
C-0012 flags the public SSE-KMS key ARN environment value as a potential secret;
AWS credentials themselves use Secret references. No finding is suppressed.

## Values

| Parameter | Default | Description |
| --- | --- | --- |
| `nameOverride` | `""` | name override setting for the gateway. |
| `fullnameOverride` | `""` | fullname override setting for the gateway. |
| `image.repository` | `"ghcr.io/openclaw/openclaw"` | repository setting for image. |
| `image.tag` | `"2026.9.4@sha256:cc596b846506a5f4cfcee111394a2725f375f01cca2ebb492a161fd1b747f101"` | tag setting for image. |
| `image.pullPolicy` | `"IfNotPresent"` | pull policy setting for image. |
| `imagePullSecrets` | `[]` | image pull secrets setting for the gateway. |
| `auth.existingSecret` | `""` | Existing Secret with the gateway token; empty generates and retains a token across upgrades. |
| `auth.key` | `"gateway-token"` | Secret key containing the gateway token. |
| `credentials.existingSecret` | `""` | Existing Secret containing provider keys and TELEGRAM_BOT_TOKEN or DISCORD_BOT_TOKEN as applicable. |
| `agent.defaults` | `{}` | Additional upstream agent defaults, for example memorySearch or sandbox. Model, workspace and concurrency use the explicit fields below. |
| `agent.entries` | `{}` | Additional named agents; keep their workspace and agentDir below /home/node for chart-managed backup recovery. |
| `agent.model` | `"anthropic/claude-opus-4-6"` | Upstream provider/model identifier; inference needs the corresponding credential. |
| `agent.toolProfile` | `"minimal"` | Upstream tool profile: minimal, coding, messaging or full. Minimal permits session_status only. |
| `agent.allowTools` | `[]` | Additional upstream tool allowlist; exec and filesystem access grant access within the agent container. |
| `agent.denyTools` | `[]` | Additional upstream tool denylist. |
| `agent.maxConcurrent` | `1` | Maximum concurrent agent runs. |
| `config.policy` | `"managed"` | managed reconciles declared config on restart; seed preserves UI/CLI config after first initialization. |
| `config.values` | `{}` | Additional upstream configuration; chart security, state and telemetry fields are reserved. |
| `config.agentInstructions` | `""` | Optional workspace AGENTS.md content with the selected configuration ownership policy. |
| `config.soul` | `""` | Optional workspace SOUL.md content with the selected configuration ownership policy. |
| `persistence.enabled` | `true` | enabled setting for persistence. |
| `persistence.existingClaim` | `""` | existing claim setting for persistence. |
| `persistence.storageClass` | `""` | storage class setting for persistence. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | access modes setting for persistence. |
| `persistence.size` | `"10Gi"` | size setting for persistence. |
| `persistence.retain` | `true` | retain setting for persistence. |
| `service.type` | `"ClusterIP"` | type setting for service. |
| `service.port` | `18789` | port setting for service. |
| `service.annotations` | `{}` | annotations setting for service. |
| `service.ipFamilyPolicy` | `""` | ip family policy setting for service. |
| `service.ipFamilies` | `[]` | ip families setting for service. |
| `service.loadBalancerSourceRanges` | `[]` | load balancer source ranges setting for service. |
| `serviceAccount.create` | `true` | create setting for serviceAccount. |
| `serviceAccount.name` | `""` | name setting for serviceAccount. |
| `serviceAccount.annotations` | `{}` | annotations setting for serviceAccount. |
| `resources.requests.cpu` | `"250m"` | cpu setting for resources.requests. |
| `resources.requests.memory` | `"1Gi"` | memory setting for resources.requests. |
| `resources.limits.cpu` | `"2"` | cpu setting for resources.limits. |
| `resources.limits.memory` | `"3Gi"` | memory setting for resources.limits. |
| `nodeSelector.kubernetes.io/os` | `"linux"` | Upstream/Kubernetes setting. |
| `tolerations` | `[]` | tolerations setting for the gateway. |
| `affinity` | `{}` | affinity setting for the gateway. |
| `podAnnotations` | `{}` | pod annotations setting for the gateway. |
| `extraEnv` | `[]` | extra env setting for the gateway. |
| `networkPolicy.enabled` | `true` | enabled setting for networkPolicy. |
| `networkPolicy.ingressFrom` | `[]` | ingress from setting for networkPolicy. |
| `networkPolicy.extraEgress` | `[]` | extra egress setting for networkPolicy. |
| `networkPolicy.allowInternet` | `true` | allow internet setting for networkPolicy. |
| `terminationGracePeriodSeconds` | `120` | termination grace period seconds setting for the gateway. |
| `ingress.enabled` | `false` | enabled setting for ingress. |
| `ingress.ingressClassName` | `""` | ingress class name setting for ingress. |
| `ingress.annotations` | `{}` | annotations setting for ingress. |
| `ingress.hosts` | `[{"host":"openclaw.example.com","paths":[{"path":"/","pathType":"Prefix"}]}]` | hosts setting for ingress. |
| `ingress.tls` | `[]` | tls setting for ingress. |
| `gatewayAPI.enabled` | `false` | enabled setting for gatewayAPI. |
| `gatewayAPI.httpRoutes` | `[]` | http routes setting for gatewayAPI. |
| `externalSecrets.enabled` | `false` | enabled setting for externalSecrets. |
| `externalSecrets.refreshInterval` | `"1h"` | refresh interval setting for externalSecrets. |
| `externalSecrets.items` | `[]` | items setting for externalSecrets. |
| `metrics.enabled` | `false` | Enable bundled diagnostics-otel metrics; no runtime plugin downloads. |
| `metrics.intervalSeconds` | `15` | interval seconds setting for metrics. |
| `metrics.externalEndpoint` | `""` | External OTLP HTTP base endpoint when the local collector is disabled. |
| `metrics.collector.enabled` | `true` | enabled setting for metrics.collector. |
| `metrics.collector.image.repository` | `"ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib"` | repository setting for metrics.collector.image. |
| `metrics.collector.image.tag` | `"0.160.0@sha256:799dc6cf12c96192af37b5bdba804da8c10b3bc563b43cb90c3f3c58d9572ad6"` | tag setting for metrics.collector.image. |
| `metrics.collector.image.pullPolicy` | `"IfNotPresent"` | pull policy setting for metrics.collector.image. |
| `metrics.collector.resources.requests.cpu` | `"50m"` | cpu setting for metrics.collector.resources.requests. |
| `metrics.collector.resources.requests.memory` | `"64Mi"` | memory setting for metrics.collector.resources.requests. |
| `metrics.collector.resources.limits.cpu` | `"500m"` | cpu setting for metrics.collector.resources.limits. |
| `metrics.collector.resources.limits.memory` | `"256Mi"` | memory setting for metrics.collector.resources.limits. |
| `metrics.serviceMonitor.enabled` | `false` | enabled setting for metrics.serviceMonitor. |
| `metrics.serviceMonitor.labels` | `{}` | labels setting for metrics.serviceMonitor. |
| `metrics.serviceMonitor.interval` | `"30s"` | interval setting for metrics.serviceMonitor. |
| `metrics.serviceMonitor.scrapeTimeout` | `"10s"` | scrape timeout setting for metrics.serviceMonitor. |
| `metrics.prometheusRule.enabled` | `false` | enabled setting for metrics.prometheusRule. |
| `metrics.prometheusRule.labels` | `{}` | labels setting for metrics.prometheusRule. |
| `metrics.prometheusRule.additionalRules` | `[]` | additional rules setting for metrics.prometheusRule. |
| `metrics.ingressFrom` | `[]` | ingress from setting for metrics. |
| `backup.enabled` | `false` | enabled setting for backup. |
| `backup.schedule` | `"0 3 * * *"` | schedule setting for backup. |
| `backup.timeZone` | `"Etc/UTC"` | time zone setting for backup. |
| `backup.suspend` | `false` | suspend setting for backup. |
| `backup.successfulJobsHistoryLimit` | `1` | successful jobs history limit setting for backup. |
| `backup.failedJobsHistoryLimit` | `2` | failed jobs history limit setting for backup. |
| `backup.activeDeadlineSeconds` | `1800` | active deadline seconds setting for backup. |
| `backup.stagingSize` | `"10Gi"` | Ephemeral capacity for native tar.gz archive and temporary SQLite snapshots; size for peak usage. |
| `backup.resources.requests.cpu` | `"100m"` | cpu setting for backup.resources.requests. |
| `backup.resources.requests.memory` | `"256Mi"` | memory setting for backup.resources.requests. |
| `backup.resources.limits.cpu` | `"1"` | cpu setting for backup.resources.limits. |
| `backup.resources.limits.memory` | `"2Gi"` | memory setting for backup.resources.limits. |
| `backup.s3.bucket` | `""` | bucket setting for backup.s3. |
| `backup.s3.prefix` | `"openclaw"` | prefix setting for backup.s3. |
| `backup.s3.region` | `"us-east-1"` | region setting for backup.s3. |
| `backup.s3.endpoint` | `""` | endpoint setting for backup.s3. |
| `backup.s3.allowInsecureEndpoint` | `false` | allow insecure endpoint setting for backup.s3. |
| `backup.s3.existingSecret` | `""` | existing secret setting for backup.s3. |
| `backup.s3.sse` | `"AES256"` | sse setting for backup.s3. |
| `backup.s3.kmsKeyId` | `""` | kms key id setting for backup.s3. |
| `backup.s3.caSecret` | `""` | ca secret setting for backup.s3. |
| `backup.image.repository` | `"public.ecr.aws/aws-cli/aws-cli"` | repository setting for backup.image. |
| `backup.image.tag` | `"2.36.43@sha256:d948ee299a7ffcaec0d6052a00b9f4c513c61cacfaedfe68b098c85808394441"` | tag setting for backup.image. |
| `backup.image.pullPolicy` | `"IfNotPresent"` | pull policy setting for backup.image. |
| `backup.networkPolicy.extraEgress` | `[]` | extra egress setting for backup.networkPolicy. |
| `restore.enabled` | `false` | enabled setting for restore. |
| `restore.manifestKey` | `""` | manifest key setting for restore. |
| `restore.maxArchiveBytes` | `10737418240` | max archive bytes setting for restore. |
| `restore.maxExpandedBytes` | `21474836480` | Maximum expanded bytes accepted during recovery. |
| `gateway.controlUi.enabled` | `true` | Enable the bundled Control UI with device pairing enforced. |
| `gateway.controlUi.allowedOrigins` | `["http://localhost:18789","http://127.0.0.1:18789"]` | Exact trusted browser origins; add the HTTPS public origin before exposing the UI. |
| `gateway.trustedProxies` | `[]` | Explicit trusted reverse-proxy IPs/CIDRs for client identity; never trust all networks. |
| `gateway.chatCompletions.enabled` | `false` | Expose authenticated OpenAI-compatible chat completions. |
| `gateway.responses.enabled` | `false` | Expose authenticated OpenResponses API. |
| `channels.telegram.enabled` | `false` | enabled setting for channels.telegram. |
| `channels.telegram.allowFrom` | `[]` | allow from setting for channels.telegram. |
| `channels.discord.enabled` | `false` | enabled setting for channels.discord. |
| `channels.discord.allowFrom` | `[]` | allow from setting for channels.discord. |
