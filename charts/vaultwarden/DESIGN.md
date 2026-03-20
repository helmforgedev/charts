# Vaultwarden Chart Design

Internal design document for the `vaultwarden` Helm chart.

This file defines the product contract before implementation.

## Product Goal

Deliver a small, explicit, and secure Helm chart for Vaultwarden on Kubernetes.

The chart should optimize for:

- simple self-hosted deployments
- persistent local storage with SQLite
- clean ingress and domain configuration
- explicit SMTP and admin-token modeling
- clear operational boundaries

The chart should not try to behave like a generic web-app wrapper.

## Product Model

Vaultwarden is primarily a lightweight single-instance application.

For the v1 scope in this repository:

- the normal path is one pod
- persistence is handled with a PVC mounted at `/data`
- the default database model is SQLite
- WebSocket notifications ride through the same HTTP service
- TLS termination is expected at ingress or reverse proxy level

## v1 Scope

### Included

- single Deployment
- single Service for HTTP and websocket-compatible traffic
- PVC-backed persistent storage for `/data`
- `ingress` with `ingressClassName`
- optional SMTP configuration
- optional admin token with `existingSecret`
- security-focused defaults for container and pod context
- explicit docs for SQLite limitations

### Excluded

- HA claims
- multi-replica scaling
- automatic failover
- embedded backup job
- operator-like lifecycle control
- external database mode unless later implementation proves it can stay small and clear
- split websocket Service unless a real product need appears

## Architecture Decision

### Runtime topology

Use a single Deployment instead of StatefulSet for v1.

Reasoning:

- one replica is the intended operating mode
- persistence is PVC-backed but not identity-based
- Deployment keeps the chart smaller

### Persistence

Persist `/data` through a PVC by default.

This directory holds:

- SQLite database
- attachments
- configuration files created by the application
- icon cache and related runtime state

### Database model

Default to SQLite.

Reasoning:

- matches the simplest and most common Vaultwarden self-hosted pattern
- avoids inflating the chart with a second operational mode before the first one is mature

### Domain and ingress

`domain` should be modeled explicitly and strongly recommended when ingress is enabled.

Ingress should support:

- `enabled`
- `ingressClassName`
- `annotations`
- `hosts[].paths[]`
- `tls[]`

The chart should assume HTTPS is terminated outside the pod.

### WebSocket handling

Use the same Service for normal HTTP and websocket traffic.

Reasoning:

- simpler for operators
- aligns with common reverse-proxy setups
- avoids extra manifests unless the product truly needs them

### SMTP

SMTP should be fully optional.

When enabled, it should support:

- host
- port
- from address
- username/password through inline values or `existingSecret`
- security mode if the product supports it cleanly

### Admin token

Admin access should be explicit and secret-driven.

Support:

- inline `adminToken`
- `existingSecret`
- clear docs that the admin page should not be casually exposed

## Proposed Values Structure

```yaml
image:
  repository:
  tag:
  pullPolicy:

domain: ""

admin:
  token: ""
  existingSecret: ""
  existingSecretTokenKey: admin-token

data:
  persistence:
    enabled: true
    accessMode: ReadWriteOnce
    size: 5Gi
    storageClass: ""
    existingClaim: ""

service:
  type: ClusterIP
  port: 80
  annotations: {}

ingress:
  enabled: false
  ingressClassName: traefik
  annotations: {}
  hosts: []
  tls: []

smtp:
  enabled: false
  host: ""
  port: 587
  from: ""
  username: ""
  password: ""
  existingSecret: ""
  existingSecretPasswordKey: smtp-password

websocket:
  enabled: true

resources: {}
podSecurityContext: {}
securityContext: {}
nodeSelector: {}
tolerations: []
affinity: {}
topologySpreadConstraints: []
priorityClassName: ""
networkPolicy:
  enabled: false
```

## Templates Expected in v1

- `_helpers.tpl`
- `secret.yaml`
- `deployment.yaml`
- `service.yaml`
- `ingress.yaml`
- `pvc.yaml`
- `serviceaccount.yaml` only if needed
- `networkpolicy.yaml` only if the implementation stays small and clear
- `NOTES.txt`

## CI Matrix

The chart should validate at least these scenarios:

- `ci/minimal.yaml`
- `ci/persistent.yaml`
- `ci/smtp.yaml`
- `ci/existing-secret.yaml`
- `ci/ingress.yaml`

## Documentation Set

User-facing docs should include:

- `README.md`
- `docs/sqlite.md`
- `docs/ingress-and-domain.md`

The docs must explain:

- why SQLite is the v1 default
- why multi-replica is out of scope
- why `/data` persistence is essential
- how websocket traffic behaves behind ingress
- how to secure the admin interface

## Security Direction

The chart should default to:

- non-root execution
- dropped Linux capabilities where possible
- no privilege escalation
- explicit secret modeling for admin token and SMTP password

The docs should also recommend:

- HTTPS at ingress
- restricted exposure of `/admin`
- conservative registration/signup settings when relevant

## Open Decisions To Revisit During Implementation

- whether `domain` becomes required whenever ingress is enabled
- whether `networkPolicy` enters v1 or waits for v2
- whether SMTP security mode deserves its own structured block
- whether admin-token modeling should support hashed/precomputed forms or stay simple

## Non-Goals Reminder

Do not turn v1 into:

- a Bitnami-style giant values surface
- a multi-database chart
- a pseudo-HA architecture
- a backup platform
