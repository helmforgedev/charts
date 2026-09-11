# Pocket ID design

## Upstream contract

Use the official `ghcr.io/pocket-id/pocket-id:v2.14.0` image and its unchanged startup entrypoint. This release includes
a static Go binary and embedded frontend. Its native first-user API is public while no user exists, so merely placing
the Service after a Deployment does not protect setup.

## Private bootstrap

An initializer copies the exact binary to a pod-local emptyDir. A pinned official Node helper runs that binary with
`HOST=127.0.0.1` and `ACTORS_HOST=127.0.0.1`, preserving the final HTTPS `APP_URL`. This uses native binding controls
and does not patch application code. The helper creates the first administrator through the native API, verifies its
role and the closed setup response, then gracefully terminates the process. The main container starts afterward using
its original entrypoint.

For existing databases the helper verifies closed setup and preserves users and credentials. Disabled account creation
still performs this private admission check. Unexpected HTTP responses fail rather than being interpreted as an existing
installation. An operator invokes the native CLI for a fresh one-hour login link when ready to enroll a passkey.

## Storage and availability

SQLite and uploads live on one retained PVC. The generated encryption Secret uses Helm lookup to retain its exact key
across upgrades. An existing Secret supports external ownership. This key encrypts sensitive native fields rather than
the complete database file.

Single replica and Recreate upgrades are deliberate with either SQLite or PostgreSQL: upstream HA is unfinished and is
not exposed as a supported environment flag. No HPA or misleading multi-replica availability is offered.

## PostgreSQL migrations

The optional HelmForge subchart initializes `citext` and `pgcrypto` with its DBA role. The former is required by
application migrations, the latter by the independent Francis actor migration runner. External databases require
equivalent preparation. A read-only PostgreSQL client checks extensions, separate schema USAGE/CREATE privileges and the
application's dirty migration flag before the private bootstrap executes either native runner. No runtime superuser
grant, database CREATE grant, forced migration version or automatic dirty-state repair is used.

The connection URL is assembled with encoded components in a mode-0600 memory-backed file. External PostgreSQL defaults
to `verify-full`; a mounted optional CA enables private trust without disabling hostname validation.

## Monitoring boundary

Native OpenTelemetry Prometheus export uses a separate port, Service and NetworkPolicy ingress rule. ServiceMonitor and
PrometheusRule are optional and depend on installed operator CRDs. The private initialization process overrides metric
export to none, so it exposes no additional bootstrap listener. The availability alert evaluates discovered targets;
missing monitoring discovery requires separate platform alerts.

## Validation plan

Validate private first-user setup, native operator token exchange/replay rejection, identity and key retention, real
browser passkey enrollment/login and OIDC authorization code with S256. Release readiness remains pending until the
complete HelmForge gate passes. The browser fixture must generate a new credential with an empty virtual authenticator;
seeded private keys and upstream test-only API routes cannot establish production behavior.
