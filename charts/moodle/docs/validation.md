# Moodle validation evidence

Validated on 2026-09-09 against Moodle 5.2.2 and the pinned MoodleHQ PHP 8.4
runtime. Local Kubernetes context: `k3d-helmforge-tests-wsl`, Kubernetes 1.31.5.

## Full chart gate

Validation covered dependency resolution and bundle integrity, strict lint,
all CI renders, 64 unit tests, strict kubeconform with real CRD schemas,
Artifact Hub lint and the eight runtime scenarios below.

The all-scenario run passed every static layer and seven runtime scenarios;
shared-storage startup exceeded the original 180-second installer-lock wait.
The shared-storage CI profile and HA example now allow 600 seconds. The final
gate repeated all static layers and the default/shared-storage scenarios:

```bash
make validate-chart CHART=moodle TIMEOUT=900 \
  K3D_SCENARIOS="default ci/shared-storage-values.yaml"
```

Result: `FULLY VALIDATED (12 layers)`, exit 0. The six unchanged runtime
scenarios retain their passing evidence from the preceding all-scenario run.
To reproduce every runtime scenario in one run, omit `K3D_SCENARIOS` and keep
`TIMEOUT=900`. The successful shared-storage retry became ready in 293 seconds
without container restarts.

| Runtime scenario | Result | Application evidence |
| --- | --- | --- |
| Default | PASS | Clean installation, administrator login, dashboard and cron |
| Dual-stack values | PASS | Service policy accepted; installed application and login |
| External PostgreSQL | PASS | Installation and login with verify-full TLS and mounted CA |
| External Secrets | PASS | SecretSynced/Ready and login with the synchronized password |
| Ingress/Gateway API | PASS | Resources accepted; application checks through its Service |
| Prometheus monitoring | PASS | Authentication, isolated listener, discovery, real course count changes and rule evaluation |
| Redis and worker | PASS | Redis-backed login, cron, ad-hoc container and NetworkPolicy |
| Shared storage | PASS | Two replicas, serialized bootstrap, login, cron and shared file marker |

Every application check verified exact health bodies, rendered login HTML,
authenticated administrator dashboard, private configuration paths and
read-only application code. Successful runtime scenarios completed without
restarts or crash terminations. Test namespaces were removed afterwards.

Transient fixture startup warnings included PostgreSQL readiness before startup,
a Redis readiness timeout and a concurrent PVC binding update. The affected
workloads recovered without container restarts and passed application checks.

## Prometheus monitoring

The monitoring scenario ran Prometheus Operator 0.94.0 with a digest-pinned
Prometheus 3.14.0 instance and tool_monitoring 1.1.0. It verified:

- Missing and invalid bearer credentials returned 403; valid credentials returned 200.
- All five configured metric families appeared in Prometheus exposition.
- The public listener rejected the monitoring route; the metrics listener rejected login pages.
- Prometheus discovered the ServiceMonitor and reported `up=1`.
- Creating a real temporary course increased the collected count; removing it restored the count.
- PrometheusRule resources were loaded and evaluated with healthy rule status.

This certifies discovery, collection, authentication, listener isolation and rule
evaluation. Notification delivery to an Alertmanager receiver was not exercised.

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
after npm ci. All 158 local references on the Moodle page resolved. Browser
checks verified documentation and metrics/ServiceMonitor playground output without console warnings
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
