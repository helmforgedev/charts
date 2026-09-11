# PostgreSQL and local storage

Behavioral acceptance of this chart is still in progress. The following describes
the implemented configuration contract, not completed runtime evidence.

## Bundled PostgreSQL

The chart uses the HelmForge PostgreSQL dependency in standalone mode. Its
application role has CREATE permission on the configured database and runs the
unchanged native Drizzle migrations in its dedicated schema. It is not granted
superuser or permission to create other databases. Application containers receive the role password through a
Secret reference. They do not receive the PostgreSQL superuser password.

PostgreSQL temporary and socket directories have explicit writable volumes so
that its root filesystem can remain read-only. Protect the database PVC and retain
the role credential across upgrades. The application startup checks both database
access and local storage before becoming ready.

## External PostgreSQL

Set `postgresql.enabled=false`, then configure `database.host`, `database.port`,
`database.name`, `database.username` and `database.passwordSecret`. The selected
Secret key defaults to `password`. The launcher constructs the native PostgreSQL
URL with encoded credentials and database name; do not concatenate a password
into `extraEnv` or expose it in a command line.

External TLS is enabled by default. Verification uses the hostname in
`database.host` and the trusted certificate chain. An optional `database.tls.caSecret`
adds a PEM CA bundle from `database.tls.caKey`. Certificate bypasses are outside
the contract. Explicit NetworkPolicy egress rules must permit the actual database
endpoint and port. The external TLS profile still requires runtime acceptance,
including rejection of an unknown CA and an incorrect certificate hostname.
The external role also needs CREATE on this database and appropriate privileges
on the public schema; connection permission alone cannot run Drizzle migrations.

## Readiness and shutdown

Native `/api/health` tests PostgreSQL and storage. Readiness uses that result;
liveness checks the native listener so a database outage does not by itself cause
a restart loop. The initialization budget includes network admission, dependency
admission, migrations and private first-user enrollment. Inspect the reported
initialization stage when an installation cannot become ready.

The application uses one replica and the Recreate strategy. Changes cause planned
downtime. A disruption budget cannot make a singleton highly available. Avoid
concurrent releases pointing at the same database or upload volume.

## PDF generation

The native v5 server generates PDFs without Browserless. Its fonts and rendering
behavior belong to the pinned application artifact. The runtime acceptance script
creates a private resume through the native API, edits its contents, downloads a
real PDF and extracts its text. Merely returning a PDF content type is insufficient.

The verified image fetches a Noto punctuation fallback even when Helvetica is
selected. It therefore needs font-network access for ordinary PDF rendering.
The default policy permits public TCP 443, excluding private and special-use
address ranges. This is an IP/port rule, not a DNS allowlist. Set
`networkPolicy.allowPublicHttps=false` only when equivalent approved font egress
is supplied through `extraEgress` or an operator-managed egress policy. Standard
Kubernetes NetworkPolicy cannot enforce a hostname allowlist for changing CDNs.
Offline PDF export is not currently part of the native image contract.
