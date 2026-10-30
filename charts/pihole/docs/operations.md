<!-- SPDX-License-Identifier: Apache-2.0 -->

# Pi-hole Operations Guide

## Production Preflight

Reserve `serviceDns.loadBalancerIP` before deployment and keep it stable for the
lifetime of the installation. Confirm that TCP and UDP traffic can reach
`serviceDns.port`, provide the admin password through an existing Secret or
ExternalSecret, set resource requests and limits for every enabled sidecar, and
choose a StorageClass with a tested recovery procedure.

`containerPorts.dns` configures the Pi-hole FTL DNS listener.
`containerPorts.http` configures the primary unencrypted FTL web listener used
by the Web Service, probes, and metrics exporter. They are independent from the
cluster-facing DNS and web Service ports. Set `pihole.webserverPort` when FTL
must listen on multiple IPv4, IPv6, HTTP, or HTTPS addresses and include
`containerPorts.http` in that full value as directly served HTTP bound to all
pod interfaces. Do not redirect, secure, or bind that primary listener to a
specific address; those modes may be used on additional listeners. The chart
Web Service and default NetworkPolicy do not expose additional listeners. Use
Ingress or Gateway TLS termination for ordinary pod networking. With
`hostNetwork`, access additional listeners through the node and enforce them
with the node firewall. DHCP remains on UDP 67 because it is a fixed protocol
port and requires host networking or equivalent broadcast-aware network
integration.

## Backup and Restore

The optional backup CronJob uploads Pi-hole configuration archives to an
S3-compatible bucket. Use a dedicated Secret for the access key and secret key,
enable bucket versioning, and test restore outside the production namespace.
The chart backup covers the selected `/etc/pihole` and `/etc/dnsmasq.d` data; it
does not replace a storage-level snapshot policy.

Before an upgrade, take a PersistentVolume snapshot or an application backup.
To restore, stop the Deployment, restore the data into the bound PVC, and then
restart the Deployment. Verify file ownership against the official Pi-hole
image before allowing traffic.

## Upgrade Procedure

1. Read the upstream Docker release notes and HelmForge chart changes.
2. Back up `/etc/pihole` and `/etc/dnsmasq.d`.
3. Render the proposed values and review image digests and listener ports.
4. Upgrade during a DNS maintenance window.
5. Confirm rollout status, DNS over both UDP and TCP, admin login, gravity
   updates, metrics, and Unbound or DHCP when enabled.

Use an explicit rollback plan. A Helm rollback restores Kubernetes manifests,
but it does not reverse an application data migration inside the PVC.

When migrating a chart 2.1.x `securityContext.capabilities.add` override, first
inspect stored overrides with `helm get values <release> -n <namespace>`. Remove
the old capability override and upgrade with `--reset-values`, passing all other
intended overrides again. `--reuse-values` and `--reset-then-reuse-values` both
retain the stored array and prevent the chart 2.2.0 capability defaults from
taking effect. DHCP automatically receives `NET_ADMIN` when enabled.

## Runtime Verification

```bash
kubectl rollout status deployment/<release>-pihole -n <namespace>
kubectl get endpointslice -n <namespace> -l kubernetes.io/service-name=<release>-pihole-dns
dig @<dns-service-ip> -p 53 pi.hole A
dig +tcp @<dns-service-ip> -p 53 pi.hole A
kubectl port-forward -n <namespace> svc/<release>-pihole-web 8080:80
```

When ports are overridden, substitute the configured Service ports in client
commands. Inspect the pod environment to confirm that `FTLCONF_dns_port`
matches `containerPorts.dns` and that `FTLCONF_webserver_port` contains the
primary `containerPorts.http` listener.

## Troubleshooting

### DNS Service Has No Response

Check the Service address, EndpointSlice, LoadBalancer health, and both UDP and
TCP firewall rules. Confirm that `pihole.listeningMode` is `ALL` for normal
Kubernetes networking. If `networkPolicy.ingressFrom` is set, ensure it selects
the actual client source namespaces or pods.

### Web Admin Is Unreachable

Verify the web Service target, the `http` named container port, and the startup
and readiness probes. `serviceWeb.port` changes only the Service-facing port;
use `containerPorts.http` to change the primary FTL listener. When
`pihole.webserverPort` is set, confirm its full listener list includes that
primary port as directly served HTTP bound to all pod interfaces.

### Gravity Update Fails

Inspect both init-container logs and confirm outbound DNS and HTTPS access.
Validate PVC capacity and permissions, then run `pihole -g` in the application
container only after the pod becomes Ready.

### Unbound Does Not Resolve

Inspect the `unbound` sidecar and confirm that Pi-hole points to
`127.0.0.1#<unbound.port>`. See [Unbound Recursive DNS](unbound.md) for the
listener and trust-anchor contract.

### DHCP Clients Receive No Lease

DHCP broadcasts normally require `dhcp.hostNetwork: true` and node placement on
the intended network segment. Confirm `dhcp.start`, `dhcp.end`, and
`dhcp.router`, verify UDP 67 reachability, and avoid running two DHCP servers on
the same broadcast domain. The chart adds `NET_ADMIN` only when DHCP is enabled.
Because NetworkPolicy enforcement for host-networked pods depends on the
network plugin, verify enforcement and use node-level controls when access to
the Pi-hole listeners must be restricted.
