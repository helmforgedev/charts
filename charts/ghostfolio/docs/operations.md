# Operations and recovery

## Upgrade

1. Read the Ghostfolio release notes and identify database migrations.
2. Back up PostgreSQL and export critical portfolio data through Ghostfolio.
3. Preserve the application, OIDC, database, Redis, and provider Secrets.
4. Upgrade in a staging namespace with a restored database copy.
5. Confirm migration and seed log lines, both health endpoints, login, holdings,
   historical values, and provider refresh.
6. Upgrade production during a maintenance window. `Recreate` intentionally
   stops the old singleton before starting the new one.

## Backup scope

PostgreSQL contains durable application state. Back it up consistently with the
database service or operator. Redis persistence is optional operational state
and is not a substitute. The application Secret must be captured separately;
database recovery with new salts can invalidate authentication behavior.

## Restore test

Restore to a fresh database and namespace, create the credential Secrets, point
the chart at the restored services, and wait for Ghostfolio to apply any forward
migrations. Verify administrator login, account count, activities, holdings,
historical calculations, and provider synchronization before accepting the
restore point.

## Troubleshooting

- Init container timeout: check Service DNS, NetworkPolicy, and endpoints for
  PostgreSQL and Redis.
- Migration failure: inspect the first Ghostfolio container log and verify that
  `DIRECT_URL` bypasses transaction poolers.
- Readiness timeout: query `/api/v1/health`; Redis checks may consume five
  seconds, so do not reduce the probe timeout.
- Liveness succeeds but readiness fails: the process is healthy and a state
  dependency is unavailable; restarting Ghostfolio will not repair it.
- OIDC callback mismatch: compare `ROOT_URL`, provider registration, ingress
  forwarded headers, and `TRUST_PROXY`.
- Login breaks after upgrade: confirm the application Secret did not rotate.
- Market data fails: inspect provider rate limits, API-key Secret wiring, DNS,
  and public HTTP/HTTPS egress.
- First registration is exposed: restrict ingress until the administrator has
  been created.
- Upgrade does not overlap pods: this is intentional `Recreate` behavior for
  migration safety.
- Metrics are absent: Ghostfolio has no documented Prometheus endpoint; monitor
  HTTP availability, logs, PostgreSQL, and Redis separately.
