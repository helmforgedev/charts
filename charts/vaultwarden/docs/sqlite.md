# SQLite Mode

## When to use it

Use this mode for small and medium self-hosted Vaultwarden deployments where a single instance is acceptable and no external database path is being used.

## What it delivers

- persistent local database under `/data`
- simple operational model
- low chart complexity

## What it does not deliver

- HA
- multi-replica scaling
- coordinated failover

## Best practices

- keep PVC-backed storage enabled
- back up `/data` regularly
- do not scale the deployment above one replica
- treat SQLite as the v1 default, not as a clustering strategy
- treat SQLite as the automatic fallback mode, not as the recommended production database path when external PostgreSQL or MySQL is available
