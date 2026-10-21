# DocuSeal upstream research

Research snapshot: 2026-10-21.

## Selected release

- Upstream source: `docusealco/docuseal`.
- Release: 3.3.3.
- Official image: `docker.io/docuseal/docuseal:3.3.3`.
- Multi-platform manifest digest:
  `sha256:28d0ca583860e2c73e5b068756023a93a325799a22da1f788355d566865dd051`.

## Runtime contract

- HTTP port: 3000.
- Health endpoint: `/up`.
- Runtime identity: UID/GID 2000.
- Durable attachment path: `/data/docuseal`.
- Primary data store: PostgreSQL.
- Queue/cache service: Redis.
- Database preparation command: `bundle exec rails db:prepare`.

The chart models these contracts directly and does not substitute a generic TCP
probe for application health.

## Operational conclusions

Single-replica local storage is a supported baseline. Multiple replicas require
shared database, Redis, and object storage. Application identity secrets must be
stable across upgrades and disaster recovery.
