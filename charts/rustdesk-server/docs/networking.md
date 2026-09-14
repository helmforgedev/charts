# Networking and client configuration

## Native port map

| Purpose | Default | Derived value |
| --- | --- | --- |
| NAT test | TCP 21115 | rendezvousPort - 1 |
| Rendezvous | TCP and UDP 21116 | rendezvousPort |
| Relay | TCP 21117 | relayPort |
| Rendezvous WebSocket | TCP 21118 | rendezvousPort + 2 |
| Relay WebSocket | TCP 21119 | relayPort + 2 |

Both base ports are configurable. All TCP listeners, including unexposed native
WebSocket listeners, must remain distinct. There is no OSS console on 21114.

## LoadBalancer and firewall

Start from `examples/staging.yaml` or `examples/production.yaml`. Replace every
example hostname and documentation CIDR. Permit client access to the four native
protocol mappings in the Service, network firewall and NetworkPolicy. The default
policy permits only Pods in the release namespace. For an internet-facing server,
use the actual trusted office/VPN CIDRs where possible. If all public clients are
required, explicitly allow `0.0.0.0/0` and, if applicable, `::/0`; evaluate that
admission choice separately from the public-key check.

Confirm that your provider supports mixed TCP and UDP in one LoadBalancer Service.
The chart cannot make an unsupported cloud service accept mixed protocols. Use
NodePort behind an external compatible load balancer when needed.
`loadBalancerSourceRanges` is provider-dependent and complements NetworkPolicy.

Source addresses matter for hole punching. `externalTrafficPolicy: Local` uses
node-local endpoints for external Service traffic; only the node hosting this
singleton can serve those requests. Health checks must track that node. Additional
load balancer SNAT can still prevent clients from discovering useful addresses.
Test clients on different real networks before depending on direct connections.

## RustDesk clients

In each compatible RustDesk client's network settings, configure:

1. ID server: your reachable rendezvous hostname, with its public base port when
   non-default, for example `rustdesk.example.com:31116`.
2. Relay server: your reachable relay endpoint, for example
   `rustdesk.example.com:31117`. Alternatively, configure `server.relayServers`
   so hbbs advertises the correct endpoint. An empty list does not discover your
   external address automatically.
3. Key: the public key reported by hbbs, copied through a trusted channel.

`server.alwaysUseRelay: true` disables attempts at direct hole punching. It does
not provision an external relay address or repair a blocked relay port.
Relay bandwidth and CPU then become relevant to every remote desktop session.

For NodePort, preserve a coherent external mapping: NAT must be ID base minus one,
and TCP/UDP rendezvous must use the same public port. `examples/nodeport.yaml`
uses 31115, 31116 TCP/UDP and 31117. Public forwarding can map these to different
node ports, but clients must use the public mapping. Kubernetes controls the
allowed nodePort range; this varies by cluster.

## WebSockets and HTTP controllers

Set `websocket.enabled: true` for compatible WebSocket clients. Ingress requires
two distinct hostnames. Gateway API accepts one route per component with
`component: hbbs` or `hbbr`; omitted component means hbbs. Default backends select
the derived WebSocket ports. `rules` preserves explicit matches, filters and
backendRefs; `omitDefaultBackend` permits a rule that intentionally has no backend.
Operators are responsible for any custom backend references.

Use a controller that supports WebSocket upgrade and suitably long connection
timeouts. Configure HTTPS listeners and certificates on that controller. An
HTTPRoute alone does not create a Gateway, certificate or DNS record. Cross-namespace
Gateway attachment requires its allowedRoutes policy to admit this namespace.
NetworkPolicy must admit the controller's Pods as well as native clients.

The chart does not install the RustDesk web client or enable Pro features.
