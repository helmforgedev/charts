# Matterbridge networking

## Choose a mode

The default pod-network mode is useful for evaluation and clusters whose CNI can
carry IPv4/IPv6 multicast between pods and the physical LAN. Most conventional
CNIs do not, so a production Matter installation normally enables host network:

```yaml
network:
  hostNetwork: true
nodeSelector:
  matterbridge.helmforge.dev/lan-node: "true"
```

Label exactly one trusted node before installing. Matterbridge then sees that
node's LAN interfaces and uses `ClusterFirstWithHostNet` DNS automatically.

## Ports and discovery

The frontend listens on TCP 8283. Matterbridge starts at TCP/UDP 5540 and may use
the configured consecutive range for child bridges and plugins. Commissioning
also needs mDNS on UDP 5353 and functional IPv6 reachability.

The optional `matterService` publishes the configured Matter range for advanced
pod-network designs. It does not publish or relay mDNS. Confirm CNI multicast,
source address preservation, firewall rules and controller routing before using
that mode.

## Frontend exposure

Ingress and Gateway API expose only HTTP/HTTPS for administration. Keep them
private or require authentication at the proxy. Never treat either as a way to
carry Matter traffic.

## Troubleshooting

If the UI works but controllers cannot discover or commission the bridge:

1. Confirm the controller and selected Kubernetes node share routable LAN/IPv6
   connectivity.
2. Enable host network and pin the pod to that node.
3. Check node firewall rules for UDP 5353 and the reserved Matter TCP/UDP range.
4. Set `matterbridge.mdnsInterface` when the node has several LAN interfaces.
5. Inspect logs for mDNS advertisements and commissioning status.
