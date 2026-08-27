# Production operations

Poznote stores its SQLite database, notes, attachments, and application
configuration in the `data` volume. Use a retained storage class, monitor free
space, and take application-consistent backups before upgrades.

Poznote supports one replica because the embedded SQLite database and local
filesystem are not safe for concurrent writers. The chart therefore uses the
`Recreate` deployment strategy. A PodDisruptionBudget protects the single pod
from voluntary eviction, but it does not provide high availability.

Expose the Service through TLS-enabled Ingress or Gateway API. Enable the
NetworkPolicy and restrict `networkPolicy.ingressFrom` to the namespace or
pods that run the selected ingress controller. Permit only the egress required
by DNS, OIDC, S3, and other integrations that are actually configured.

For SSO, place OIDC credentials in an existing Secret or synchronize them with
External Secrets. Test OIDC end to end before setting
`poznote.oidc.disableNormalLogin=true`, so an identity-provider outage does not
lock administrators out unexpectedly.

Before an upgrade, back up the complete `data` volume and verify a restore in a
separate namespace. After rollout, confirm `/api/health`, authentication, note
rendering, search, attachments, and any external storage integration.
