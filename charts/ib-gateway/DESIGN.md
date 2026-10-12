# IB Gateway chart design

## Goals

The chart translates the `gnzsnz/ib-gateway-docker` Compose contract into
Kubernetes resources while preserving upstream ports, file-based password
inputs, settings storage, process lifecycle, and two-factor behavior. Paper and
read-only operation are the safe defaults.

## Architecture

One Deployment owns IBC, Xvfb, IB Gateway, and the upstream `socat` proxies. A
single Service selects the active live and paper ports. An optional second
Service exposes VNC for maintenance. A PVC contains only TWS settings, while a
projected Secret supplies credentials. NetworkPolicy restricts API and VNC
clients without pretending that changing IBKR endpoints can be expressed as a
stable default egress allowlist.

## Singleton invariant

An IBKR account session is not a replicated service. Concurrent logins can
replace or downgrade one another, while mobile two-factor approval and IBC
restarts belong to one process tree. The schema and template therefore constrain
`replicaCount` to one, and `Recreate` prevents overlap during upgrades.

## Credential lifecycle

Passwords use upstream `_FILE` variables and a projected Secret. Usernames use
Secret references because upstream does not provide username-file variables.
The chart-managed Secret is suitable for evaluation, while an existing Secret
or ExternalSecret is the deterministic production contract. A values checksum
restarts the Pod when references or key mappings change; external secret
controllers remain responsible for rotation-triggered rollout policy.

## Health semantics

The public container ports are `socat` proxies and can listen before account
authentication finishes. With credentials configured, startup and readiness
instead inspect the internal live or paper Gateway listener. An intentionally
empty evaluation install checks the credential-waiting process so its logs can
be inspected before a Secret is added; the Service remains unusable. Liveness
checks process markers and deliberately does not make remote IBKR availability a
restart condition. These signals prove local runtime state, not trading
authorization or order execution.

## Security boundaries

The upstream image runs with UID/GID 1000. The chart requires non-root execution,
drops all capabilities, disables privilege escalation, selects runtime-default
seccomp, and disables API-token automount. The root filesystem remains writable
because upstream generates runtime files below its home directory and `/tmp`.
The raw TCP API and VNC carry no chart-provided transport security, so both stay
ClusterIP-only by default and require explicit client trust boundaries.

## Persistence and recovery

Only `/home/ibgateway/tws_settings` is durable. The IBC configuration is generated
again so expanded credentials are not retained. Recovery consists of restoring
optional settings, recreating the credential Secret, and completing IBKR login
and two-factor approval. Kubernetes replicas cannot replace that workflow.

## Deliberate omissions

There is no HPA, PodDisruptionBudget, Ingress, HTTPRoute, public LoadBalancer
default, or ServiceMonitor. Those resources would imply availability, HTTP
routing, public safety, or metrics contracts that upstream does not provide.
