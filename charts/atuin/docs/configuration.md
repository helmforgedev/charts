# Configuration

`atuin.openRegistration` defaults to `false`. `atuin.path` optionally prefixes every route, including probes.
`atuin.maxRecordSize` retains the upstream 1 GiB limit, and `atuin.logLevel` controls `RUST_LOG`.

SQLite is the default and requires persistence, one replica and no HPA. PostgreSQL can use the bundled dependency or
`database.existingSecret`. The Secret key defaults to `db-uri` and must contain the entire connection URI, including TLS
parameters where required.

The optional registration webhook URL is secret material. Store it in `atuin.registerWebhook.existingSecret`; never
place it in plain values. Advanced upstream settings can be supplied with `atuin.extraEnv`.

External Secrets renders full native `ExternalSecret` specs from `externalSecrets.items[]`. This keeps provider-specific
authentication outside the chart API.
