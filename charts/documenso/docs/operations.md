# Operations and recovery

## Before an upgrade

1. Read the upstream release notes.
2. Back up PostgreSQL.
3. Back up the object bucket when enabled.
4. Export the application identity and signing-certificate Secrets securely.
5. Record the current chart and image digests.
6. Restore the backup into an isolated namespace and test login and signing.

The image entrypoint applies Prisma migrations. A database rollback therefore
requires restoring a pre-upgrade backup rather than only reverting the image.

## Availability

Use managed PostgreSQL, Redis, and S3 for multiple replicas. Set BullMQ as the
job provider, preserve identical identity keys, and budget database connections
per replica. Keep startup probes long enough for migrations.

## Troubleshooting

Inspect `/api/health`, `/api/certificate-status`, pod events, and application
logs. A health warning may indicate that signing is not configured. Database
errors should withdraw readiness without tripping TCP liveness. Verify DNS and
NetworkPolicy before changing application credentials.
