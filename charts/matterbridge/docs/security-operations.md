# Security and operations

## Default controls

Matterbridge runs as UID/GID 1000, without Linux capabilities, privilege
escalation or a Kubernetes API token. RuntimeDefault seccomp and a read-only root
filesystem are enabled. Persistent state and temporary files are isolated to
`/data` and `/tmp`.

## Frontend boundary

Treat the frontend as an administrative interface. The chart leaves it on a
ClusterIP by default and does not claim that upstream provides a chart-managed
login contract. If exposed through Ingress or Gateway API, enforce TLS and
authentication in the proxy and restrict client networks.

Commissioning QR codes, manual pairing codes, fabric data and private keys are
credentials. Redact them from tickets, screenshots and centralized logs.

## Plugins

Plugins execute inside the Matterbridge process and may connect to LAN devices,
MQTT brokers or cloud APIs. Install only trusted plugins, pin versions where the
upstream workflow permits, and back up before changing them. Use `extraEnvFrom`
with a Secret rather than putting credentials in values.

## NetworkPolicy

NetworkPolicy is available only in pod-network mode. Enabling it with host
network is rejected because enforcement differs by CNI. Egress is unrestricted
unless explicitly enabled; plugin destinations are product-specific and cannot
be safely guessed by the chart.

## Upgrade procedure

1. Read upstream release notes and HelmForge chart changes.
2. Verify a restorable PVC backup.
3. Upgrade without changing the singleton identity or network node.
4. Wait for readiness and inspect startup logs.
5. Verify installed plugins and a representative bridged device.

For an incompatible migration, keep the StatefulSet stopped, roll back the Helm
release, restore the complete `/data` contents on the application PVC from the
verified pre-upgrade snapshot or backup, and only then start the rolled-back
release. Chart and PVC state must return to the same point in time.
