<!-- SPDX-License-Identifier: Apache-2.0 -->

# Pi-hole Operations Guide

## Production Preflight

Reserve `serviceDns.loadBalancerIP` before deployment and keep it stable for the
lifetime of the installation. Confirm that TCP and UDP traffic can reach
`serviceDns.port`, provide the admin password through an existing Secret or
ExternalSecret, set resource requests and limits for every enabled sidecar, and
choose a StorageClass with a tested recovery procedure.

`containerPorts.dns` and `containerPorts.http` configure the Pi-hole FTL
listeners. They are independent from the cluster-facing DNS and web Service
ports. DHCP remains on UDP 67 because it is a fixed protocol port and requires
host networking or equivalent broadcast-aware network integration.

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

## Runtime Verification

```bash
kubectl rollout status deployment/<release>-pihole -n <namespace>
kubectl get endpointslice -n <namespace> -l kubernetes.io/service-name=<release>-pihole-dns
dig @<dns-service-ip> -p 53 pi.hole A
dig +tcp @<dns-service-ip> -p 53 pi.hole A
kubectl port-forward -n <namespace> svc/<release>-pihole-web 8080:80
```

When ports are overridden, substitute the configured Service ports in client
commands. Inspect the pod environment to confirm that `FTLCONF_dns_port` and
`FTLCONF_webserver_port` match the declared container ports.

## Troubleshooting

### DNS Service Has No Response

Check the Service address, EndpointSlice, LoadBalancer health, and both UDP and
TCP firewall rules. Confirm that `pihole.listeningMode` is `ALL` for normal
Kubernetes networking. If `networkPolicy.ingressFrom` is set, ensure it selects
the actual client source namespaces or pods.

### Web Admin Is Unreachable

Verify the web Service target, the `http` named container port, and the startup
and readiness probes. `serviceWeb.port` changes only the Service-facing port;
use `containerPorts.http` to change the FTL listener.

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
