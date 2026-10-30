# NetBird security

## Credential handling

Replace `server.authSecret` before production. Preserve `server.store.encryptionKey` across every upgrade and recovery;
changing it makes encrypted database values unreadable. Avoid inline owner and database passwords. Prefer an existing
Secret or `externalSecrets.items` backed by a namespaced SecretStore or ClusterSecretStore.

Restrict Secret read access to the Helm release identity and the NetBird pods. Encrypt backups and audit access to the
config Secret, database credentials, and identity-provider client secrets.

## Container boundary

The server runs as non-root UID/GID 1000, drops all capabilities, disables privilege escalation, and uses
`RuntimeDefault` seccomp. The dashboard's official image starts supervisord and nginx as root and drops nginx worker
privileges internally. Its container receives only `CHOWN`, `SETGID`, and `SETUID`; its writable nginx paths are bounded
emptyDirs. ServiceAccount token mounting is disabled for both workloads by default.

## Network boundary

Enable `networkPolicy.enabled` only after identifying ingress controllers, monitoring systems, DNS, database, identity
provider, GeoLite, and peer infrastructure. If `networkPolicy.extraEgress` is non-empty, the policy isolates egress and
adds baseline DNS plus HTTP, HTTPS, and UDP STUN access. Replace broad internet rules with platform-specific destinations
where your CNI and operating model allow it.

Terminate TLS at a trusted ingress, Gateway, load balancer, or reverse proxy. Preserve HTTP/2 and gRPC, constrain trusted
proxy CIDRs through upstream configuration, and expose UDP STUN only where peers require it.

## Authentication

The embedded identity provider is convenient for self-contained deployments, but production credentials still belong
in a Secret. When using an external provider, validate issuer, audience, client ID, scopes, redirect URIs, logout, and
key rotation in staging. Callback URIs must exactly match the browser origin; default scheme ports are intentionally
removed from generated callback URLs.

## Review checklist

- Replace bootstrap secrets and verify the stable encryption key is backed up.
- Restrict Secret RBAC and disable ServiceAccount tokens unless a feature explicitly needs them.
- Verify TLS, HTTP/2 or gRPC, trusted proxy CIDRs, and public hostname behavior.
- Test API authentication, OIDC discovery, dashboard login, relay WebSocket, and UDP STUN.
- Apply resource limits, bounded ephemeral storage, database encryption, and backup retention.
- Scan the pinned upstream images and review NetBird release security notes before upgrades.
