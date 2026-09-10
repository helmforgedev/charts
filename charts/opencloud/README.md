# OpenCloud Helm Chart

OpenCloud file collaboration with the official `opencloudeu/opencloud:7.2.4` image, native identity initialization,
extended-attribute storage checks and retained configuration. The chart runs one monolithic instance with planned
downtime during upgrades.

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

## Security and availability

- UID/GID1000, read-only root filesystem, dropped capabilities and no Kubernetes API token.
- One replica and Recreate upgrades; this chart does not implement distributed OpenCloud HA.
- Separate writable config, data and bounded temporary storage.
- Native OIDC TLS verification remains enabled, with explicit CA trust.
- The debug listener stays on loopback because it includes a configuration endpoint.
- Ingress, Gateway API, dual-stack Services, External Secrets and placement controls follow HelmForge contracts.

NetworkPolicy requires an enforcing CNI. Open required integration destinations explicitly and configure the public
issuer before users begin storing files or enrolling clients.

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
