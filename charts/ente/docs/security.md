# Security

## Workload hardening

Museum and web run as non-root users, drop Linux capabilities, disable privilege
escalation, use RuntimeDefault seccomp, and mount read-only root filesystems.
Service account tokens are disabled.

The upstream web image normally modifies `/out` and nginx runtime directories.
An init container copies static content into an emptyDir, then the non-root main
container performs endpoint substitution and starts nginx with writable
emptyDirs only where required.

## Secret management

Use existing Secrets or External Secrets Operator in production. Treat Museum's
encryption key, hash key, JWT secret, PostgreSQL password, and S3 credentials as
high-impact secrets. Restrict read access and audit every rotation.

Generated Museum keys use `lookup` and remain stable across ordinary upgrades.
Deleting the Secret before upgrade generates a new recovery identity and can
make existing data unusable.

## Transport security

Terminate TLS at Ingress or Gateway. Use TLS to external PostgreSQL and S3.
Configure WebAuthn with the exact Accounts hostname and HTTPS origin.

## Network policy

NetworkPolicy restricts workloads to published ports and known egress classes.
Private S3, SMTP, and external PostgreSQL often need explicit CIDR or selector
rules. Review the rendered rules against the cluster CNI before enabling them.

## Registration

Create the first administrator through a controlled bootstrap. Then set
`museum.config.disableRegistration=true` if the instance is private.

## Operational review

- Verify pod security against the cluster's Restricted admission policy.
- Scan pinned image digests on every update.
- Review Museum and ingress logs for unexpected origins.
- Test backup restoration after credential changes.
- Avoid exposing Museum metrics publicly.
