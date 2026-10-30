# Networking

## API ports

The Service exposes live API port 4001 and paper API port 4002. These target the
container's `socat` listeners on 4003 and 4004. Only the ports active for
`gateway.tradingMode` are added to the Service.

The upstream image fixes the proxy listeners at 4003 and 4004 and fixes x11vnc
at 5900. They are not values because changing Kubernetes metadata would not
reconfigure the upstream processes. The client-facing Service ports remain
independently configurable and target the named container ports.

The protocol is raw TCP without chart-provided authentication or encryption.
Keep `service.type: ClusterIP`, run clients inside a trusted private network, and
do not place the Service directly on the internet.

## NetworkPolicy

With NetworkPolicy enabled and no custom peers, API ingress is limited to Pods
in the release namespace. Set `networkPolicy.apiIngressFrom` to explicit
namespace or Pod selectors for trading clients. VNC has an independent
`vncIngressFrom` list.

Egress isolation is disabled by default because IBKR destinations and addresses
change. If your environment supplies a maintained egress gateway or allowlist,
enable `networkPolicy.egressIsolation` and populate `extraEgress`. DNS egress is
preserved through `dnsEgress`.

## Client access

For temporary local access:

```bash
kubectl -n ib-gateway port-forward service/ib-gateway 4002:4002
```

Connect the paper client to `127.0.0.1:4002`. Use 4001 only for live mode and
after separately verifying account identity, API permissions, and read-only
settings.

## VNC

VNC is a maintenance surface, not an application UI. Enable it only when visual
diagnostics are required, keep the Service internal, use a strong Secret-backed
password, and prefer `kubectl port-forward`. Disable VNC again after maintenance.

## Dual stack

Set `service.ipFamilyPolicy` and `service.ipFamilies` only when the cluster
supports those families. The values affect Kubernetes Service addresses, not
IBKR's external endpoint behavior.
