# OpenCloud Helm Chart

OpenCloud file collaboration with the official `opencloudeu/opencloud:7.2.4` image, native identity initialization,
extended-attribute storage checks and retained configuration. The chart runs one monolithic instance with planned
downtime during upgrades.

## Features

- Official pinned OpenCloud image with native identity and PosixFS initialization.
- Retained configuration, identity keys and file data on one xattr-capable PVC.
- Native HTTPS or explicit edge TLS termination with trusted private CA support.
- Ingress and Gateway API exposure, including verified Gateway backend TLS policy.
- Default NetworkPolicy, restricted security contexts and disabled Kubernetes API token.
- External Secrets integration and authenticated Prometheus metrics without exposing the debug API.
- Behavioral validation for OIDC, Graph, WebDAV, persistence, restore, monitoring and negative access paths.

## Installation

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install opencloud helmforge/opencloud \
  --set bootstrap.password='replace-with-at-least-16-bytes'
```

OCI installation is also supported:

```bash
helm install opencloud oci://ghcr.io/helmforgedev/helm/opencloud \
  --set bootstrap.password='replace-with-at-least-16-bytes'
```

The remaining commands use the `helmforge/opencloud` repository alias created by the first installation flow. OCI-only
users can replace that reference with `oci://ghcr.io/helmforgedev/helm/opencloud`.

For production, create the bootstrap and TLS Secrets first and supply the values shown below. The inline password is
intended only for an initial isolated evaluation.

## Production configuration

```yaml
server:
  publicUrl: https://files.example.com
  tls:
    enabled: true
    existingSecret: opencloud-server-tls
bootstrap:
  existingSecret: opencloud-initial-admin
persistence:
  size: 100Gi
```

Create the bootstrap Secret with key `admin-password` and at least 16 bytes before installation. Create a TLS Secret whose
certificate matches the canonical hostname. Include `ca.crt` when a private CA is needed by OpenCloud's own OIDC
clients, or supply `server.trustedCaSecret`. Both browsers and the application must resolve and trust the same public
HTTPS origin. Configure ingress-to-backend HTTPS verification when retaining native TLS.

If the ingress terminates TLS and forwards HTTP, set `server.tls.enabled: false` while keeping the external
`server.publicUrl` on HTTPS. Allow required public issuer access through `networkPolicy.extraEgress`. The chart does
not disable OIDC certificate verification to make an internal/public DNS mismatch work.

Without a configured public URL, the chart uses an internal Service hostname and a retained private certificate for
initial evaluation. That private certificate is valid for one year and is not automatically renewed. Production
certificate management should own `server.tls.existingSecret`; coordinate certificate rotation and application restart
so the trust bundle and listener use matching material. Changing the public hostname does not regenerate retained
identity or TLS Secrets.

## Configuration reference

| Value | Default | Purpose |
| --- | --- | --- |
| `replicaCount` | `1` | Fixed monolithic replica count |
| `server.port` | `9200` | Real OpenCloud HTTPS or HTTP listener |
| `server.publicUrl` | empty | Canonical external HTTPS origin |
| `server.tls.enabled` | `true` | Enable native server TLS |
| `server.tls.existingSecret` | empty | Existing server certificate Secret |
| `server.trustedCaSecret` | empty | Additional issuer CA bundle |
| `service.port` | `9200` | Kubernetes Service port |
| `persistence.enabled` | `true` | Persist configuration and file data |
| `persistence.existingClaim` | empty | Restore or reuse an existing workspace claim |
| `persistence.size` | `20Gi` | Generated workspace claim size |
| `persistence.retain` | `true` | Keep the generated claim after uninstall |
| `bootstrap.existingSecret` | empty | Initial administrator password Secret |
| `networkPolicy.enabled` | `true` | Restrict application traffic through NetworkPolicy |
| `networkPolicy.extraEgress` | `[]` | Additional integration egress rules |
| `metrics.enabled` | `false` | Enable the authenticated metrics sidecar |
| `metrics.serviceMonitor.enabled` | `false` | Render a Prometheus Operator ServiceMonitor |
| `gatewayAPI.enabled` | `false` | Render HTTPRoutes and backend TLS policy |
| `externalSecrets.enabled` | `false` | Reconcile application Secrets through ESO |

Run `helm show values helmforge/opencloud` for the complete contract. `global` is an optional parent-chart compatibility
map and has no direct runtime effect.

## Initial identity

The initializer runs the upstream `opencloud init --insecure=false --quiet` command as UID1000 before the server starts.
It consumes the administrator password privately and persists native configuration. The first username is `admin`.
Demo users and Basic authentication are disabled; browser login uses the native identity provider.

Existing nonempty identity configuration is preserved. Data without matching configuration fails initialization;
ordinary upgrades never force-overwrite identity or reset accounts. Changing the bootstrap Secret after initialization
is not a password-rotation operation.

## Storage and recovery

One PVC contains `config` and `data` directories, mounted at `/etc/opencloud` and `/var/lib/opencloud`. The official
image's extended-attribute tools verify user xattr access on the mounted filesystem before starting OpenCloud. Choose
a storage class compatible with the native PosixFS backend.

Back up consistent config and data together, including all extended attributes and exact native encryption/signing
keys. A plain file-content copy is insufficient. Use a volume snapshot or an archive tool that preserves xattrs,
ownership and modes. Retain the bootstrap and TLS Secrets separately. Test restoration into a fresh isolated volume
with a new login and exact file-content comparison before accepting a recovery procedure.

## Architecture

A bootstrap init container creates native configuration on the workspace claim, then the OpenCloud container mounts
the same claim through separate `config` and `data` subpaths. A bounded `emptyDir` carries temporary files. The client
Service targets the named application port; optional Ingress or Gateway resources publish it. Metrics use an isolated
sidecar that can read loopback debug metrics but cannot read the identity workspace. See [DESIGN.md](DESIGN.md) for the
Mermaid topology, trust boundaries and explicit non-goals.

## Examples

- [Production NGINX ingress](examples/production-ingress.yaml) configures a public origin and edge routing.
- [Production Gateway](examples/production-gateway.yaml) demonstrates HTTPRoute and backend TLS verification.
- [Authenticated monitoring](examples/monitoring.yaml) enables the metrics sidecar and Prometheus resources.

Apply an example only after replacing hostnames, Secret names, issuer trust and storage settings:

```bash
helm upgrade --install opencloud helmforge/opencloud \
  --values charts/opencloud/examples/production-ingress.yaml
```

## Security and availability

- UID/GID1000, read-only root filesystem, dropped capabilities and no Kubernetes API token.
- One replica and Recreate upgrades; this chart does not implement distributed OpenCloud HA.
- Separate writable config, data and bounded temporary storage.
- Native OIDC TLS verification remains enabled, with explicit CA trust.
- The debug listener stays on loopback because it includes a configuration endpoint.
- Ingress, Gateway API, dual-stack Services, External Secrets and placement controls follow HelmForge contracts.

NetworkPolicy requires an enforcing CNI. Open required integration destinations explicitly and configure the public
issuer before users begin storing files or enrolling clients.

## Upgrade compatibility

Chart upgrades preserve resource names, the generated claim, native identity configuration and explicit Secret
references. Back up the workspace with xattrs before every application upgrade. Validate both a normal upgrade and an
upgrade using retained values because `--reuse-values` may preserve an older image tag or obsolete overrides. Use
`--reset-then-reuse-values` with Helm 3.14 or later when adopting new defaults while keeping explicit release values.

```bash
helm repo update
helm upgrade opencloud helmforge/opencloud --reset-then-reuse-values
```

Never delete the workspace to repair an upgrade. A successful Helm revision is incomplete until login, Graph discovery
and a WebDAV read/write operation succeed against the effective application image.

## Troubleshooting

Inspect the Deployment, claim, events and both init/application logs before changing retained state:

```bash
kubectl get deployment,pods,pvc -l app.kubernetes.io/instance=opencloud
kubectl logs deployment/opencloud-opencloud -c bootstrap
kubectl logs deployment/opencloud-opencloud -c opencloud
kubectl describe pod -l app.kubernetes.io/instance=opencloud
```

An xattr admission failure means the filesystem or restored data does not satisfy PosixFS requirements. OIDC issuer
errors usually indicate that the public URL, DNS, certificate SAN or trusted CA differs between browsers and the pod. A
pending pod with an existing claim can indicate an access-mode or zone conflict. Metrics scrape failures should be
checked against the token Secret, ServiceMonitor selector and NetworkPolicy peers. Do not force-overwrite native
configuration or rotate the bootstrap Secret as a substitute for application-level account recovery.

## Validation

The full HelmForge gate passed all 20 layers, including 21 Helm tests and ten Kubernetes runtime profiles. Acceptance
covers native OIDC with verified PS256 signatures and S256 verifiers, private Graph/WebDAV operations, wrong-password
and unauthorized-access denial, retained identity across restart and upgrade, and fresh-PVC xattr-preserving recovery.
ExternalSecret Ready, actual Prometheus ServiceMonitor up=1 and its loaded rule, and the Gateway backend CA/hostname
contract also passed. Gateway/Ingress controller-specific public routing remains an operator acceptance check.

## Documentation

- [Onboarding and identity](docs/onboarding.md)
- [Networking, Gateway API and TLS](docs/networking.md)
- [Prometheus monitoring](docs/monitoring.md)
- [Recovery procedure](docs/recovery.md)
- [Production NGINX ingress](examples/production-ingress.yaml)
- [Production Gateway](examples/production-gateway.yaml)
- [Authenticated monitoring](examples/monitoring.yaml)

## Security Scan: `opencloud`

| Framework | Score |
| --- | --- |
| Overall | **98.48%** |
| MITRE | **97.06%** |
| NSA | **97.50%** |
| SOC2 | **90.00%** |

Kubescape 4.0.13, default rendered manifests, 2026-09-10. The sole C-0012 finding flags the literal
`AUTH_BEARER_OIDC_INSECURE=false` environment setting in native init and server containers because its name contains
`BEARER`. It is a certificate-verification policy flag, not a credential. No controls were suppressed.
This manifest scan does not replace application review or image vulnerability management.

## Sources

- [OpenCloud v7.2.4](https://github.com/opencloud-eu/opencloud/tree/v7.2.4)
- [PosixFS storage requirements](https://docs.opencloud.eu/docs/admin/configuration/storage/storage-posix)
