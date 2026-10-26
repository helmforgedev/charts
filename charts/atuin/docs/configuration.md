# Configuration

`atuin.openRegistration` defaults to `false`. `atuin.path` optionally prefixes every route, including probes.
`atuin.maxRecordSize` retains the upstream 1 GiB limit, and `atuin.logLevel` controls `RUST_LOG`.

`containerPorts.http` configures the actual Atuin listener through
`ATUIN_PORT`. The Kubernetes-facing `service.port` is separate and targets the
named `http` port. For example, `containerPorts.http=8899` with
`service.port=8080` makes Atuin listen on 8899 while clients inside the cluster
connect to the Service on 8080. Listener ports below 1024 are rejected because
the hardened container runs as UID 1000 with all capabilities dropped.

SQLite is the default and requires persistence, one replica and no HPA. PostgreSQL can use the bundled dependency or
`database.existingSecret`. The Secret key defaults to `db-uri` and must contain the entire connection URI, including TLS
parameters where required.

The optional registration webhook URL is secret material. Store it in `atuin.registerWebhook.existingSecret`; never
place it in plain values. Advanced upstream settings can be supplied with `atuin.extraEnv`.

External Secrets renders full native `ExternalSecret` specs from `externalSecrets.items[]`. This keeps provider-specific
authentication outside the chart API.
