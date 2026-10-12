# IB Gateway - Research Findings

**Chart request:** helmforgedev/charts#1424
**Requester:** Aidas-dev
**Upstream:** [gnzsnz/ib-gateway-docker](https://github.com/gnzsnz/ib-gateway-docker)
**Research date:** 2026-10-12

## Product and runtime

The upstream container runs Interactive Brokers Gateway through IBC, Xvfb and
`socat`. It is a community wrapper, not an Interactive Brokers image. The
container runs as UID/GID 1000 and publishes the live and paper API proxies on
container ports 4003 and 4004. VNC on port 5900 is optional.

The API is raw TCP without transport authentication or encryption. Kubernetes
exposure must therefore default to ClusterIP and explicit NetworkPolicy peers.
Ingress and Gateway API are not applicable. A single replica with Recreate
strategy is required because concurrent logins can evict each other and do not
provide safe high availability.

## Upstream version and supply chain

- Stable release: `10.50.1f`, published 2026-10-06.
- Image: `ghcr.io/gnzsnz/ib-gateway:10.50.1f`.
- Manifest index: `sha256:1e2236804ac949b789197c225a048c0c891c9958f948c87166226e5b647ff581`.
- Platforms: linux/amd64 and linux/arm64.
- `make image-verify` passed for both platforms.
- The repository is MIT licensed, but the image contains proprietary IB
  Gateway software. The chart references the external image and must document
  that it is community-maintained and subject to IBKR account agreements.

## Configuration contract

The upstream runtime supports `paper`, `live` and `both` trading modes. Paper
mode is the safe default. Live and paper use different credentials and internal
ports. The chart must expose friendly Service ports 4001 and 4002 while targeting
container ports 4003 and 4004.

Password inputs support `_FILE` variants. Passwords must be mounted from a
Secret and never written into ConfigMaps or plain environment values. Usernames
use `secretKeyRef`. Existing Secret and External Secrets Operator integrations
are first-class requirements from the requester.

Settings can be persisted below `/home/ibgateway/tws_settings`. Persisted
`jts.ini` prevents later `TIME_ZONE` changes from being applied automatically,
which must be called out in operations documentation. IBC configuration is not
persisted because it contains expanded credentials.

## Health and lifecycle

The image has no HTTP health endpoint. The public 4003/4004 listeners belong to
`socat`, which can start before Gateway authentication, so a TCP probe on those
ports is not sufficient. Product-specific exec probes should inspect the
internal 127.0.0.1:4001/4002 listeners. Startup receives a large 2FA budget;
liveness is conservative to avoid restart loops during upstream outages.

Daily restart automation can usually preserve a weekly session, but manual 2FA
is still periodically required. Horizontal autoscaling and rolling updates are
non-goals. Graceful termination must allow IBC and Xvfb to stop cleanly.

## Existing solutions

| Solution | Strengths | Gaps |
| --- | --- | --- |
| `kieranmanning/ib-gateway-helm` | Uses the upstream image | Old tag, plaintext credentials, fixed NodePorts, no schema, ESO, PVC, probes or NetworkPolicy |
| `fossum/elite-flux-cluster` | Recreate strategy and PVC | Floating tag, always-on VNC, env credentials, no reusable production contract |
| `omdv/ibkr-trading` | Bundles a trading bot | Different image and application-specific topology, no reusable gateway contract |
| `marvin-hansen/IB-gateway` | Demonstrates Kubernetes deployment | Static 2021 manifest with plaintext password; not Helm |

No supported upstream chart exists. Upstream issue #34 explicitly leaves
Kubernetes packaging to the community.

## HelmForge differentiation

1. Safe trading defaults: paper, read-only API, blind trading disabled,
   ClusterIP-only and VNC disabled.
2. Secret-file projection, existing Secret key mapping and canonical ESO
   `items[]` support.
3. Correct live/paper/both Service mapping across `socat` target ports.
4. Product-aware probes, singleton validation, Recreate upgrades and documented
   2FA/restart limitations.
5. Persistent settings, dual-stack Service, baseline pod security and explicit
   client NetworkPolicy.

## Risks and non-goals

- IBC was retired by its maintainers on 2026-09-01 and receives limited fixes.
- A Kubernetes readiness signal cannot prove that an IBKR account can place an
  order. It only proves the configured local API listener is available.
- The chart does not provide HA, autoscaling, public API exposure, noVNC,
  Prometheus metrics or automated trading strategies.
- The project and HelmForge are not affiliated with or endorsed by Interactive
  Brokers. Users remain responsible for account agreements and market-data
  restrictions.

## Sources

- [IB Gateway Docker repository](https://github.com/gnzsnz/ib-gateway-docker)
- [IB Gateway Docker 10.50.1f release](https://github.com/gnzsnz/ib-gateway-docker/releases/tag/ibgateway-stable%4010.50.1f)
- [Upstream Compose contract](https://github.com/gnzsnz/ib-gateway-docker/blob/master/docker-compose.yml)
- [Upstream Kubernetes packaging discussion](https://github.com/gnzsnz/ib-gateway-docker/issues/34)
- [IBC user guide](https://github.com/IbcAlpha/IBC/blob/master/userguide.md)
- [IBKR two-factor authentication guidance](https://www.ibkrguides.com/kb/en-us/article-2816.htm)
