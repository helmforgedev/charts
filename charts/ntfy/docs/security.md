<!-- SPDX-License-Identifier: Apache-2.0 -->

# ntfy Security

## Default Controls

The chart defaults to a non-root pod and containers with UID/GID 1000,
`RuntimeDefault` seccomp, no privilege escalation, a read-only root filesystem,
and all Linux capabilities dropped. The Kubernetes API token is not mounted.
CPU, memory, `/tmp`, and non-persistent data storage are bounded.

The upstream ntfy process listens on unprivileged port 2586. The Service can
still expose port 80 because Kubernetes forwards to the named container port.

## Trust Boundaries

- Ingress and Gateway controllers terminate or forward external traffic; the
  chart does not provision a controller or TLS issuer.
- `/var/cache/ntfy` contains messages, SQLite authentication data, attachments,
  and optional ban-feed output. Protect its PVC and backups as sensitive data.
- PostgreSQL, OIDC, SMTP, S3, web push, and External Secrets providers are
  external trust boundaries whose identity, TLS, availability, and audit
  controls remain operator responsibilities.
- The optional ServiceMonitor gives Prometheus access to the metrics endpoint.

## Credentials

Prefer existing Kubernetes Secrets or External Secrets Operator. Inline
passwords are rendered into Secrets but remain in Helm release state. Restrict
access to Helm storage and Kubernetes Secrets, encrypt data at rest, and use
provider-specific rotation procedures.

Database, OIDC, and SMTP secret values are injected through environment
variables. Restart the Deployment after rotation. The chart adds a checksum of
the credential configuration, but cannot observe changes made directly to an
existing Secret.

## Network Isolation

`networkPolicy.enabled` restricts ingress to the configured peers. Enabling
`networkPolicy.egress.enabled` also isolates outbound traffic and permits DNS
when requested. External PostgreSQL requires
`networkPolicy.egress.externalDatabaseCIDR`; all other integrations require
explicit `networkPolicy.egress.extraEgress` rules.

Use stable CIDRs only when they are appropriate for the provider. DNS names are
not valid Kubernetes NetworkPolicy peers. Test web push, OIDC discovery, SMTP,
S3 backup, and database connectivity after applying egress isolation.

## Operational Recommendations

- Set `ntfy.authDefaultAccess: deny-all` for private instances.
- Publish ntfy only through HTTPS and set `ntfy.baseUrl` to the canonical URL.
- Keep the official image pin and review upstream security advisories before
  upgrades.
- Retain and restore-test both PVC backups and PostgreSQL backups where used.
- Monitor authentication errors, publish rate anomalies, pod restarts, storage
  pressure, and backup failures.
- Review custom `extraEnv`, `extraVolumes`, `extraVolumeMounts`, and
  `extraManifests` because they extend the chart's security boundary.
