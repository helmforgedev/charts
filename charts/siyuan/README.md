# SiYuan

Private knowledge workspace with a persistent filesystem, native access-code authentication and optional OIDC. The chart
uses the official `docker.io/b3log/siyuan:v3.8.3` image, verified for Linux amd64, arm64 and arm.

## Production contract

- Exactly one writer per workspace, enforced even for RWX claims. Deployment strategy is Recreate.
- Complete workspace persistence, including documents, configuration, history, assets and encrypted content.
- Native access code in a Kubernetes Secret, generated once and retained on Helm upgrades.
- Existing Secret and External Secrets Operator support for GitOps credentials.
- Optional native OIDC with explicit claim admission rules and Secret-backed client credentials.
- Non-root UID/GID 1000, read-only image filesystem, RuntimeDefault seccomp, dropped capabilities and no API token.
- Native boot-completion readiness, resource defaults, dual-stack Service, Ingress, Gateway API and explicit egress
  policies.
- Functional notebook/document tests, pod-replacement persistence checks and quiesced restore into a fresh PVC.

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install siyuan helmforge/siyuan --namespace siyuan --create-namespace
kubectl -n siyuan port-forward service/siyuan-siyuan 6806:6806
```

Open <http://localhost:6806> and use the access code described in Helm NOTES. For remote access, configure an HTTPS
hostname and a WebSocket-capable ingress or Gateway. SiYuan is a personal administrative workspace; this is not a
tenant-isolated collaboration server.

## Storage and availability

The default claim is 10Gi ReadWriteOnce and mounts at `/siyuan/workspace`. The chart keeps the generated PVC on
uninstall. Existing claims are never created or deleted by the chart. Reusing a retained claim requires
`persistence.existingClaim`.

```yaml
persistence:
  existingClaim: restored-workspace
```

There is no external PostgreSQL/MySQL/Redis backend. Do not scale replicas or share the workspace between independent
releases. RWX does not make multiple writers safe. Recreate deliberately permits downtime during upgrades so the old
process exits before the new writer starts. No HPA or PDB is provided for this singleton.

`persistence.enabled: false` is for disposable trials; replacement loses workspace data. A StorageClass of `-` requests
no dynamic provisioning. Provision a compatible PV yourself in that case. fsGroupChangePolicy OnRootMismatch avoids
repeated ownership walks where supported by the CSI driver. The chart does not run a privileged recursive chown init
container.

## Authentication

The native access code is read from `SIYUAN_ACCESS_AUTH_CODE`. It never appears in container arguments or ConfigMaps.
Empty `auth.accessCode` generates a random 32-character code and retains it via Helm lookup. Existing-secret mode
bypasses generated credentials.

```yaml
auth:
  existingSecret: siyuan-auth
  accessCodeKey: access-code
```

Use a Secret containing that key and avoid committing plaintext credentials. Changing an existing Secret requires a pod
restart or your configured Secret-reload controller. Generated inline values change the checksum and roll the pod.
Preserve the Secret for disaster recovery. The API token and the access code are different native credentials.

Local access-code login remains available when OIDC is enabled. Treat it as an administrative recovery credential and
restrict access to its Secret. OIDC admission grants administration of the same workspace; it does not create isolated
per-user workspaces.

## Native OIDC

```yaml
oidc:
  enabled: true
  provider: custom
  issuerURL: https://identity.example.com/realms/personal
  clientID: siyuan
  existingSecret: siyuan-oidc
  clientSecretKey: client-secret
  redirectURL: https://notes.example.com/api/system/oidc/callback
  claimRules:
    - claim: email
      operator: equals
      values:
        - owner@example.com
    - claim: email_verified
      operator: equals
      values:
        - "true"
```

Register the exact HTTPS callback in your provider. Remote HTTP callbacks are rejected upstream. Configure DNS and HTTPS
egress to the issuer's discovery, JWKS and token endpoints. Use the standard custom OIDC provider contract;
provider-specific OAuth adapters are not exposed by this chart.

Rules are ANDed, with OR across values within each rule. Claims are top-level keys. `equals` is case-sensitive;
`contains` performs substring matching and is unsuitable for many exact identity restrictions. Boolean claims are
converted to strings. Empty rules are rejected unless `allowAll` explicitly grants the workspace to every authenticated
identity. Keep allowAll false.

The runtime fixture exercises real discovery, JWKS/RS256 validation, authorization code, PKCE, nonce and rejected
identity claims. Its instant-login Node provider is disposable test infrastructure and must never be deployed as an
identity service.

## External Secrets

```yaml
auth:
  existingSecret: siyuan-auth
externalSecrets:
  enabled: true
  items:
    - fullnameOverride: siyuan-auth
      spec:
        secretStoreRef:
          name: production
          kind: ClusterSecretStore
        data:
          - secretKey: access-code
            remoteRef:
              key: applications/siyuan/access-code
```

Install External Secrets Operator and the store first. The chart renders the v1 API and requires a store or per-item
source reference. The target Secret must match auth.existingSecret or oidc.existingSecret. Native login in the ESO CI
profile verifies actual consumption after Ready=True.

## Network and exposure

The Service defaults to ClusterIP:6806. Use a dedicated root hostname; configure long-lived WebSocket support at the
edge. Gateway API requires existing v1 CRDs and a Gateway controller. TLS configuration belongs to the edge; the native
kernel's local certificates are retained in workspace configuration.

Default NetworkPolicy permits HTTP from pods in the release namespace and DNS egress. It denies other outbound traffic.
Set ingressFrom for the edge namespace, and add explicit webEgress/extraEgress for OIDC, cloud sync, webhooks or
extension downloads. Permit all endpoints involved in your provider or sync service. Policy enforcement requires a
capable CNI.

PreferDualStack can fall back to single-stack. RequireDualStack requires cluster support. Extra containers inherit the
pod identity but need their own restrictive security context and resource limits. They are an integration extension, not
an alternative application architecture.

## Health and resources

Startup and readiness inspect native boot progress and require 100 percent completion. Liveness uses the unauthenticated
version endpoint so an external sync outage does not restart a healthy workspace. Initial requests are 100m CPU and
256Mi memory, with 1 CPU/1Gi limits. Size for indexing, document count and plugins. A large workspace may require a
longer startup budget and more memory.

No native Prometheus endpoint is exposed by this release. The chart does not fabricate a ServiceMonitor. Monitor
workload/PVC metrics and edge availability through your existing observability stack; use authenticated behavioral
checks for deeper application coverage.

## Backup and recovery

Back up the complete workspace after gracefully stopping the writer, or use an application-consistent storage procedure
appropriate to your platform. Copying a live SQLite file alone is unsafe and omits documents, assets and encryption
state. Protect backups as sensitive: configuration includes identity and cryptographic material.

The recovery CI profile scales the writer to zero, archives the complete workspace, restores it into a fresh claim, then
starts the chart using existingClaim. It verifies native login and an identical exported Unicode document. See
[recovery procedure](docs/recovery.md).

Encrypted notebooks also require their recovery passwords and native encrypted backups. Kubernetes storage alone cannot
reconstruct a lost encryption password. Keep recovery credentials separately protected and exercise restore regularly.

## Upgrade

```bash
helm upgrade siyuan helmforge/siyuan -n siyuan -f production.yaml
kubectl -n siyuan rollout status deployment/siyuan-siyuan
```

Take a quiesced backup first. Review upstream storage-format changes and allow Recreate downtime. Helm rollback changes
manifests and image, not data migrations. Restore a compatible workspace backup when an older version cannot read newer
storage.

## Security Scan

### Security Scan: `siyuan`

| Framework          | Score    |
| ------------------ | -------- |
| MITRE + NSA + SOC2 | **100%** |

> Security posture acceptable.

Measured with Kubescape 4.0.13 against default manifests. This assesses deployment configuration, not every upstream
feature or extension.

## Values

See [values.yaml](values.yaml) and [values.schema.json](values.schema.json) for the full contract, including scheduling
and dual-stack settings.

<!-- @AI-METADATA
 type: guide
 title: SiYuan chart
 description: Production personal knowledge workspace
 keywords: siyuan, notes, oidc, recovery
 purpose: Explain the supported production contract
 scope: chart
 path: charts/siyuan/README.md
 version: 1.0
 date: 2026-09-10
-->

## Gateway API contract

Use `gatewayAPI.enabled` and `gatewayAPI.httpRoutes[]`. Set each route's `parentRefs` to a shared Gateway that allows
this namespace, and configure its HTTPS listener and public hostname. Routes accept labels, annotations and rules
with matches, filters and optional backend references; omitted backends target this chart's application Service.
Ingress and HTTPRoute resources can coexist. Verify controller conditions and public traffic before production use.
See the [Gateway API documentation](https://gateway-api.sigs.k8s.io/).
