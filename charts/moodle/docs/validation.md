# Moodle validation evidence

Validated on 2026-09-09 against Moodle 5.2.2 and the pinned MoodleHQ PHP 8.4
runtime. Local Kubernetes context: `k3d-helmforge-tests-wsl`, Kubernetes 1.31.5.

## Full chart gate

`make validate-chart CHART=moodle` passed all 17 layers: dependency resolution
and bundle integrity, strict lint, all CI renders, unit tests, strict
kubeconform with real CRD schemas, Artifact Hub lint and seven runtime installs.

| Runtime scenario | Result | Application evidence |
| --- | --- | --- |
| Default | PASS | Clean installation, administrator login, dashboard and cron |
| Dual-stack values | PASS | Service policy accepted; installed application and login |
| External PostgreSQL | PASS | Installation and login with verify-full TLS and mounted CA |
| External Secrets | PASS | SecretSynced/Ready and login with the synchronized password |
| Ingress/Gateway API | PASS | Resources accepted; application checks through its Service |
| Redis and worker | PASS | Redis-backed login, cron, ad-hoc container and NetworkPolicy |
| Shared storage | PASS | Two replicas, serialized bootstrap, login, cron and shared file marker |

Every application check verified exact health bodies, rendered login HTML,
authenticated administrator dashboard, private configuration paths and
read-only application code. All chart containers completed validation without
restarts or crash terminations. Test namespaces were removed afterwards.

Transient fixture startup warnings included PostgreSQL readiness before startup,
a Redis readiness timeout and a concurrent PVC binding update. The affected
workloads recovered without container restarts and passed application checks.

## Persistence, backup and maintenance

- A Moodledata marker survived a Helm upgrade and pod replacement.
- PostgreSQL pg_dump produced a custom-format archive with 5049 TOC entries.
  pg_restore restored it into a separate database; the two initial users existed.
- A Moodledata tar archive was extracted separately and its marker verified.
- The maintenance Job ran Moodle's upgrade CLI against an already current
  5.2.2 database and left maintenance enabled. A separate disable operation,
  normal deployment and explicit cron enable restored authenticated access.

The maintenance exercise was a same-version operation, not a version-to-version
schema migration. The restore exercise verified both data domains separately;
it did not certify a full production recovery or measure an RTO/RPO.

## Security and site

Kubescape scored the default rendered Kubernetes configuration at 94.24%, with
no critical or high findings. This is a Kubernetes configuration assessment,
not an image vulnerability assessment.

The site passed lint, formatting and build with Node 24.21.0 and Astro 7.2.9
after npm ci. All 127 local references on the Moodle page resolved. Browser
checks verified documentation and playground output without console warnings
or errors. Cross-repository catalog parity was 97 charts.

## Validation boundaries

- Shared-volume concurrency used a single-node lab claim. Real multi-node RWX
  storage, failover, HPA load behavior and capacity require production testing.
- Ingress and HTTPRoute resources were validated with real schemas. No external
  Gateway controller traffic path or production certificate was certified.
- Dual-stack values were accepted; this does not certify IPv6 connectivity.
- SMTP delivery, SSO, custom plugins and operator-built offline images require
  validation with their actual infrastructure and artifacts.
- Automated full-site backup is not included. Follow the coordinated
  [backup and restore procedure](backup-restore.md).
