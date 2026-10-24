# Heimdall Security

## Runtime Identity

The LinuxServer image starts with `/init` as root so it can prepare files and
then apply the configured `PUID` and `PGID`. Do not set `runAsNonRoot: true` on
the main container without replacing the upstream initialization contract.

The chart keeps that required root bootstrap while applying these defaults:

- privilege escalation disabled;
- all capabilities dropped, with only the initialization and low-port binding
  capabilities added back;
- `RuntimeDefault` seccomp at pod level;
- Kubernetes API token automount disabled;
- a NetworkPolicy that admits only the named HTTP port.

The upstream s6-overlay initialization writes outside `/config`, so the main
container cannot use a read-only root filesystem. The backup uploader uses a
non-root identity and read-only root filesystem. The archive init container
runs as root because `/config` includes root-owned TLS key material; its PVC
mount and root filesystem are read-only, privilege escalation is disabled,
only `DAC_READ_SEARCH` is added after dropping all capabilities, and no
Kubernetes API token is mounted.

## Network Boundaries

The default NetworkPolicy limits inbound traffic to Heimdall's named HTTP port.
It does not restrict sources because cluster Ingress controllers and local
administration patterns vary. `networkPolicy.extraIngress` is additive and
should be used only to admit traffic on other ports; it cannot narrow the source
set allowed by the default HTTP rule. To restrict HTTP sources, set
`networkPolicy.enabled=false` and manage a replacement NetworkPolicy containing
the required source selectors.

Egress is not isolated. Heimdall enhanced tiles can call arbitrary service URLs
configured by an operator. Environments with a known destination set should
apply a separate egress NetworkPolicy and include DNS plus every required tile
endpoint.

## Secrets and External Access

Heimdall does not receive chart-managed login credentials. Protect the dashboard
with TLS, upstream Heimdall controls, and Ingress authentication where required.
Use `backup.s3.existingSecret` for S3 credentials in production. Inline backup
credentials are rendered into a Kubernetes Secret and are intended only for
disposable test environments.

## Verification

```bash
kubectl get pod -l app.kubernetes.io/component=server -o jsonpath='{.items[0].spec.automountServiceAccountToken}'
kubectl get networkpolicy
kubectl auth can-i --as=system:serviceaccount:<namespace>:<service-account> get secrets
```

The final command should return `no` unless separate RBAC grants permissions.
