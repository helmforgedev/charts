# External services

## PostgreSQL

Disable `postgresql.enabled`, enable `database.external.enabled`, and provide a
hostname plus a Secret containing the password. The database and user must
exist before installation. With NetworkPolicy enabled, add explicit peers for
the database or a complete `networkPolicy.extraEgress` rule.

## Redis

Disable `redis.enabled`, enable `redisExternal.enabled`, and provide the Redis
host and credential Secret. Protect Redis with persistence and backups when
queued background work must survive service loss.

## S3-compatible storage

Set `storage.type=s3`, configure the bucket, endpoint, and region, and put the
access key fields in `docuseal.existingSecret`. Use a private bucket, encryption
at rest, versioning, and tested lifecycle policies.

## SMTP

Enable SMTP only after supplying an address, sender, and password in the
application Secret. Private SMTP endpoints may require explicit egress rules.

## External Secrets Operator

`externalSecrets.enabled` creates one native ExternalSecret targeting
`docuseal.existingSecret`. Map the application identity and only the optional
integration keys used by the selected topology.
