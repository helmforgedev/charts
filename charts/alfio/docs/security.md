<!-- SPDX-License-Identifier: Apache-2.0 -->

# Security

## Default Controls

The application runs as the upstream image user `1001` with all Linux
capabilities dropped, privilege escalation denied, a read-only root filesystem,
and `RuntimeDefault` seccomp. The database wait init container runs as the
unprivileged UID `65534`. The application receives a writable `emptyDir` only at
`/tmp`.

The pod does not receive a Kubernetes API token by default. Enable
`serviceAccount.automountServiceAccountToken` only if a separately reviewed
integration requires Kubernetes API access.

## Network Boundary

The default NetworkPolicy selects only the alf.io server pod and allows inbound
traffic only to its named HTTP port. It deliberately does not restrict egress:
alf.io deployments may need PostgreSQL, payment providers, email services,
webhooks, and other operator-selected endpoints. Define an additional platform
egress policy when those destinations are known.

NetworkPolicy requires an enforcing CNI. TLS and client authentication remain
the responsibility of the Ingress and application configuration.

## Secrets

Use `database.external.existingSecret` for production rather than placing a
password in values. Restrict Secret read permissions, rotate database
credentials, and avoid logging rendered values. alf.io payment credentials and
administrator accounts are application configuration and are outside this
chart's ownership boundary.

## Upgrades

The default image is pinned. Review alf.io security releases, validate the
upgrade against a database backup, and keep both the chart and application
current. Version `2.0-M5-2609` contains upstream fixes for authorization, SSRF,
password-change, API-key role, sponsor-scan, and promotion-code vulnerabilities.
