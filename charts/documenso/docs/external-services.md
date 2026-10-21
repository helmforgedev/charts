# External services

Disable `postgresql.enabled`, enable `database.external.enabled`, and provide
a Secret containing URL-encoded `database-url`. Add
`direct-database-url` when migrations must bypass a pooler. Host and port are
separate values because init waiting and NetworkPolicy cannot parse a Secret.

For BullMQ, set `documenso.jobsProvider=bullmq` and choose exactly one of the
bundled Redis dependency or `redis.external`. The external Redis password is
read from a Secret.

S3, SMTP, signing, and Gotenberg integrations also use existing Secrets.
Private endpoints need `networkPolicy.extraEgress` or the typed database and
Redis peer lists. The production example shows the full shared-service shape.
