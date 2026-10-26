# IB Gateway Helm chart

Deploy the community-maintained [IB Gateway Docker](https://github.com/gnzsnz/ib-gateway-docker)
runtime with a pinned image, Secret-file credentials, persistent settings,
External Secrets, restricted TCP Services, and product-aware health checks.

## Features

- Immutable multi-architecture image selection and a hardened non-root Pod.
- Paper, live, or simultaneous sessions with conservative trading defaults.
- Secret-file passwords, existing Secret mappings, and External Secrets support.
- Retained TWS settings with product-aware startup, readiness, and liveness.
- Private named-port Services, NetworkPolicy, dual stack, and optional VNC.
- Optional singleton disruption protection with an explicit node-drain warning.

## Install

Create a mode-`0600` password file outside the repository, then create a Secret
without placing the password in shell history:

```bash
kubectl -n ib-gateway create secret generic ib-gateway-credentials \
  --from-literal=username='your-username' \
  --from-file=password=/secure/path/ibkr-password

helm install ib-gateway oci://ghcr.io/helmforgedev/helm/ib-gateway \
  --version 1.0.1 \
  --namespace ib-gateway \
  --create-namespace \
  --set auth.existingSecret=ib-gateway-credentials
```

Protect that temporary file and remove it securely after confirming the Secret
exists.

The default mode is paper trading with read-only API access. Confirm that mode
and the target account before enabling live trading.

## Architecture

The container runs IB Gateway through IBC, Xvfb, and `socat`. The chart exposes
friendly Service ports 4001 for live trading and 4002 for paper trading while
targeting the upstream proxy listeners on 4003 and 4004. It enforces one replica
and a `Recreate` strategy because concurrent IBKR sessions are not safe high
availability and can evict one another.

Ports 4003, 4004, and 5900 are fixed by the upstream `socat` and x11vnc
processes. The chart deliberately keeps those container ports fixed; only the
client-facing Service ports are configurable.

The image is maintained by the `gnzsnz/ib-gateway-docker` project and includes
proprietary Interactive Brokers software. It is not an official Interactive
Brokers image. HelmForge and the image project are not affiliated with or
endorsed by Interactive Brokers.

## Image provenance

The default image is `ghcr.io/gnzsnz/ib-gateway:10.51`, pinned to manifest
digest `sha256:1e2236804ac949b789197c225a048c0c891c9958f948c87166226e5b647ff581`.
The Linux amd64 and arm64 manifests were verified on 2026-10-12.

## Credentials and External Secrets

Passwords are projected from a Secret and passed through upstream `_FILE`
variables. Usernames use `secretKeyRef`; credentials are never written to a
ConfigMap. `auth.existingSecret` is the recommended production contract.

The canonical `externalSecrets.items` contract can materialize that Secret from
External Secrets Operator. See [credentials and External Secrets](docs/credentials.md)
for required keys and rotation behavior.

## Networking

The IBKR API is unauthenticated and unencrypted TCP. Keep the Service internal,
restrict callers with NetworkPolicy, and use a private encrypted network between
clients and the cluster. The chart intentionally provides no Ingress or Gateway
API resource because those HTTP routing abstractions do not secure this protocol.

VNC is disabled by default and uses a separate ClusterIP Service when enabled.
Use port-forwarding or a private access path rather than exposing it publicly.
See [networking](docs/networking.md).

## Health contract

The upstream image has no HTTP health endpoint. Startup and readiness probes
check the active internal Gateway listener on 127.0.0.1:4001 or 4002 instead of
the earlier-starting public `socat` proxy. Liveness verifies the relevant IBC
process marker conservatively to avoid restart loops during IBKR outages.

When credentials are configured, readiness proves a local API listener exists.
An empty evaluation install instead reports the credential-waiting process as
ready so operators can inspect logs and add a Secret; its Service is not usable
until credentials are configured and the internal listener starts. Neither
signal proves an account can place orders, that market data is subscribed, or
that upstream services are healthy.

## State, 2FA, and recovery

The PVC stores `/home/ibgateway/tws_settings`. Credentials and generated IBC
configuration are not persisted there. A persisted `jts.ini` can retain the
initial timezone, so later `gateway.timeZone` changes may require deliberate
settings cleanup.

Daily restart automation can maintain a session, but manual two-factor approval
is still periodically required. Back up settings only when their customization
is valuable; account and trading state remain external to this chart. See
[operations and 2FA](docs/operations.md).

Set `podDisruptionBudget.enabled: true` only when blocking voluntary eviction of
the singleton is preferable to completing an unattended node drain. The budget
uses `minAvailable: 1`; it does not make the workload highly available.

## Key values

| Value | Default | Purpose |
| --- | --- | --- |
| `image.tag` | `10.51` | Release channel paired with an immutable digest |
| `replicaCount` | `1` | Enforced singleton session owner |
| `gateway.tradingMode` | `paper` | `paper`, `live`, or `both` |
| `gateway.readOnlyApi` | `true` | Disable order-changing API calls |
| `auth.existingSecret` | `""` | Existing credential Secret |
| `externalSecrets.enabled` | `false` | Materialize Secrets through ESO |
| `persistence.enabled` | `true` | Persist TWS settings |
| `podDisruptionBudget.enabled` | `false` | Block voluntary eviction of the singleton |
| `service.type` | `ClusterIP` | Internal raw-TCP access |
| `vnc.enabled` | `false` | Optional maintenance VNC listener |
| `networkPolicy.enabled` | `true` | Restrict API and VNC clients |
| `networkPolicy.egressIsolation` | `false` | Opt-in explicit egress policy |

Every value is documented in [values.yaml](values.yaml) and validated by
[values.schema.json](values.schema.json).

## Examples

- [Paper trading](examples/paper-trading.yaml) keeps the safe default mode.
- [Live trading](examples/live-trading.yaml) shows the deliberate live-mode switch.
- [Live and paper](examples/live-and-paper.yaml) configures both account sessions.
- [External Secrets](examples/external-secrets.yaml) materializes credential keys.

Review account identity, Secret references, NetworkPolicy peers, and Service
exposure before applying any example.

## Troubleshooting

Inspect rollout state, login logs, and recent cluster events before weakening a
probe or network policy:

```bash
kubectl -n ib-gateway rollout status deployment/ib-gateway
kubectl -n ib-gateway logs deployment/ib-gateway --tail=200
kubectl -n ib-gateway get events --sort-by=.lastTimestamp
```

If readiness remains false, look for two-factor timeouts, competing sessions,
or a missing internal 4001/4002 listener. A listening 4003/4004 proxy alone does
not prove that authentication completed.

## Security scan

Security scan results use the same Kubescape policy set as HelmForge CI.

Security Scan: ib-gateway

| Framework | Score |
| --- | ---: |
| MITRE | **100.00%** |
| NSA | **95.00%** |
| SOC 2 | **100.00%** |
| Aggregate resource score | **96.97%** |

Kubescape reported no critical, high, or medium-severity failures. The remaining
low finding is the writable root filesystem required by the upstream desktop
runtime; non-root execution, dropped capabilities, seccomp, and disabled
privilege escalation remain enforced.

## Limitations

- IBC was retired by its maintainers on 2026-09-01 and now receives limited
  maintenance.
- There is no supported horizontal scaling or rolling update model.
- No documented Prometheus endpoint exists, so the chart does not publish a
  misleading ServiceMonitor.
- The chart cannot automate IBKR account enrollment, two-factor approval,
  subscriptions, permissions, or trading-risk controls.
- Use of the image and IB Gateway remains subject to upstream licenses and IBKR
  agreements.

## Additional documentation

- [Design](DESIGN.md)
- [Credentials and External Secrets](docs/credentials.md)
- [Networking](docs/networking.md)
- [Operations and 2FA](docs/operations.md)
- [Paper trading example](examples/paper-trading.yaml)
- [Live trading example](examples/live-trading.yaml)
- [Live and paper example](examples/live-and-paper.yaml)
- [External Secrets example](examples/external-secrets.yaml)
