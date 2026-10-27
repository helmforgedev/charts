<!-- SPDX-License-Identifier: Apache-2.0 -->

# Security and Network Policy

## Default posture

Apache Answer runs as UID and GID `1000` with RuntimeDefault seccomp. The
container cannot escalate privileges, drops every Linux capability, and adds only
`NET_BIND_SERVICE` so the official port-80 default remains usable. The root
filesystem is read-only. Durable writes go to `/data`; temporary writes go to an
ephemeral `/tmp` volume.

The application has no Kubernetes API integration, so
`serviceAccount.automountServiceAccountToken` defaults to `false`. Keep that
setting unless a separately reviewed extension genuinely requires cluster API
credentials.

Existing volumes must be writable by UID/GID `1000`. Kubernetes applies the
default `fsGroup: 1000` to supported volume types. A volume populated by an older
root-running deployment may require an administrator-controlled ownership
migration before the hardened pod can start.

## Network policy

`networkPolicy.enabled` defaults to `true`. The policy selects only pods labeled
as the Answer `server` component and permits inbound TCP traffic solely on the
named `http` port. It does not select the PostgreSQL or MySQL subcharts and it does
not select runtime validation clients.

By default the ingress rule has no source selector, so ingress controllers,
Gateways, and in-cluster clients can reach the HTTP listener. To restrict the
source, provide peers through `networkPolicy.extraIngress`:

```yaml
networkPolicy:
  enabled: true
  extraIngress:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-system
```

When `extraIngress` is non-empty, this policy allows only those peers. Kubernetes
NetworkPolicies are additive, however, so another policy selecting the Answer
pod can still allow broader sources. The restriction also depends on a network
plugin that enforces NetworkPolicy. Before relying on it in production, verify
both cluster enforcement and every policy selecting the Answer pod, and confirm
that the peer labels match the actual ingress-controller or Gateway workloads.

The chart intentionally does not apply an egress policy. Answer deployments may
need DNS, SMTP, OAuth/OIDC, external databases, plugin services, and external
content. Build a destination-specific egress policy with `extraManifests` or the
cluster policy engine when those destinations are known.

## Secrets

Use `admin.existingSecret` and the database existing-Secret values for production.
External Secrets support is optional and assumes the operator and SecretStore
already exist. Do not commit administrator, database, backup, SMTP, or identity
provider credentials to a values file.

Before upgrades, verify that Secrets retain the same keys and that the selected
database and `/data` backup can be restored. Rotating the initial administrator
password value does not necessarily rotate credentials already persisted by
Answer; follow the application-supported password flow after installation.

## Listener capability

The default listener is port `80`, which requires `NET_BIND_SERVICE` for a
non-root process. If `containerPorts.http` is changed to a port above `1024`, the
capability may be removed explicitly:

```yaml
containerPorts:
  http: 8080

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
    add: []
```

Keep `INSTALL_PORT`, `SITE_ADDR`, and `SWAGGER_ADDRESS_PORT` under chart control.
They are derived from `containerPorts.http`, and the chart fails rendering if an
entry in `answer.extraEnv` attempts to override them.
