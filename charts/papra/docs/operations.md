# Papra operations

## First installation

Set the administrator email, a dedicated public HTTPS URL and durable storage before installation. Supply existing
Secrets through your secret manager, or securely retrieve generated credentials using the names reported by Helm NOTES.
The session secret and initial password have separate roles. Changing the latter never resets an existing user.

Monitor the bootstrap init container for migration and setup failures. A failed native database query is an error, not
permission to recreate users. Avoid exposing a fresh deployment with bootstrap disabled until its onboarding is
protected.

## Network and resources

Ingress and Gateway API are optional. Add controller peers to the default NetworkPolicy, plus explicit external-service
egress. Same-namespace traffic is the default HTTP allowance. DNS defaults can be narrowed to your cluster DNS labels.
Do not infer enforcement from a rendered policy; the cluster CNI must implement it.

The image runs as UID/GID 1000 with a read-only root. The data PVC, temporary volume and home volume provide the
required writable paths. Ensure the storage driver honors fsGroup or pre-provision appropriate ownership. Size requests
and limits for native extraction and document sizes; configure edge upload limits and request timeouts independently.

Readiness `/api/health` includes database health; `/api/ping` supports process liveness. Use platform monitoring for
workload health, disk capacity and edge errors. No native Prometheus exporter is claimed by this chart.

## External Secrets

`externalSecrets.items` accepts a full native ExternalSecret spec, optional metadata and explicit target names. Install
the operator and CRDs first. Set `auth.existingSecret`, `bootstrap.existingSecret` and encryption/storage Secret
references to the materialized target names. Secret refresh does not itself restart environment-based consumers;
coordinate application rollouts and upstream credential rotation. Keep historical document-encryption key versions
available.

## Adoption and upgrade

The bootstrap init container checks existing users after native migrations. It skips setup for an existing instance and
does not compare or reset the administrator password. Preserve the native session secret and all encryption keys when
adopting an existing PVC. Keep the same application storage paths and verify version-specific migrations on a restored
copy.

Recreate updates include downtime and retain one writer. A Helm rollback restores Kubernetes configuration, not previous
database or file formats. Follow the recovery procedure when a data migration must be reversed.
