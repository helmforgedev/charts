# Dependencies and secrets

Set `database.mode=postgresql` with `postgresql.enabled=true` for the bundled PostgreSQL dependency, or use
`database.mode=external` and an existing password Secret. Redis follows the same pattern through `messageBus.mode`.
Use distinct Redis database indexes for cache and message-bus data. External PostgreSQL requires
`database.external.existingSecret`; external Redis requires `messageBus.external.existingSecret`.

Bundled services are intended for evaluation. Production systems should use managed services with backups, TLS,
capacity planning, and tested recovery. Store venue and strategy credentials in `secrets.existingSecret`, or render
provider-neutral ExternalSecret resources through `externalSecrets.items`.

NautilusTrader does not expose one universal PostgreSQL schema command across adapters and builds. The strategy factory
owns adapter construction and its supported schema lifecycle; the chart deliberately does not execute guessed SQL.
Use `extraInitContainers` only with the documented initialization command for the exact adapter packaged in your image.
