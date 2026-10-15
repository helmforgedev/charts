# Stalwart Chart Design

## Boundaries

The chart owns the Stalwart StatefulSet, Services and Kubernetes integration.
It does not own external stores, a Gateway controller, certificates, DNS,
webmail, or the database-backed Stalwart object model.

## Configuration Sources

Exactly one source supplies `/etc/stalwart/config.json`: a generated DataStore
object, an existing ConfigMap, or an existing Secret. Credentials are injected
through environment/file references and are never copied into a generated
Secret. A checksum covers generated config; external-source rotation remains
under the operator's rollout controller or `rolloutTrigger`.

## HA Invariants

StatefulSet identity provides stable hostnames and node leases. More than one
replica requires an external shared DataStore and disables the local data PVC.
Blob, search, in-memory, coordinator, and role objects live in the DataStore;
the production HA example installs them through the CLI apply Job. The chart
cannot prove an external service is itself highly available.

## Exposure

The HTTP Service carries management/JMAP and metrics traffic. The mail Service
carries SMTP, submission, IMAP, POP3, and ManageSieve. STARTTLS listeners use
TCPRoute. Implicit TLS listeners may use TLSRoute passthrough. All routes are
disabled together with `gatewayAPI.enabled=false`.

## Security

The official image runs as UID/GID 2000. `NET_BIND_SERVICE` is the only added
capability because the image binary uses a file capability for privileged mail
ports. The root filesystem is read-only and service account token mounting is
disabled. No default password or chart-generated credential exists.
