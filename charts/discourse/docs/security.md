<!-- SPDX-License-Identifier: Apache-2.0 -->

# Security

The official experimental image requires root and a writable filesystem. These
are upstream constraints, not recommended generic Kubernetes defaults. The chart
still disables privilege escalation, drops all capabilities before adding a
reviewed set, and disables service-account-token mounting.

Use existing Secrets or External Secrets for every credential. Restrict Secret
RBAC, rotate credentials through a tested maintenance procedure, and never commit
real values. TLS termination belongs to the ingress or Gateway layer; configure
SMTP before inviting users.

NetworkPolicy is disabled by default because destination requirements vary. When
enabled, review DNS, PostgreSQL, Redis, HTTPS, and SMTP rules and add explicit
peers for external services. The default same-namespace rule is convenient for
bundled dependencies but is not a tenant-isolation boundary.

Scan custom images, pin every image by digest, and rebuild plugins into the image
rather than modifying a running container. Monitor security advisories from
Discourse, PostgreSQL, Redis, pgvector, and the Kubernetes platform.
