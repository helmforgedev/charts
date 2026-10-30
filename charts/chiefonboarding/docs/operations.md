<!-- SPDX-License-Identifier: Apache-2.0 -->

# ChiefOnboarding Operations Guide

## Readiness and health

Wait for the Deployment and inspect the application endpoint before creating
users:

```bash
kubectl -n <namespace> rollout status deployment/<release>-chiefonboarding --timeout=300s
kubectl -n <namespace> get pods,service,endpoints -l app.kubernetes.io/instance=<release>
kubectl -n <namespace> port-forward service/<release>-chiefonboarding 8000:80
```

The init container proves TCP reachability to PostgreSQL. HTTP probes then
exercise the configured Gunicorn listener. The HelmForge runtime smoke goes
further by checking migration state, network HTTP behavior, Django Q execution,
the immutable image, and optional server-side S3 upload behavior.

The wrapper runs migrations before Supervisor because the upstream process
manager starts Django Q and the web migration command concurrently. This avoids
transient missing-table tracebacks on a fresh database; the upstream web command
then repeats the idempotent migration check.

## Backup and restore

Treat PostgreSQL and the Django secret key as one recovery domain. Back up the
database with platform tooling, export the retained application Secret through
an approved encrypted path, and record the image digest plus values used by the
release. A restore test must verify login, existing workflows, scheduled tasks,
documents, and integrations.

The chart does not run backup jobs or roll back database migrations. Read the
upstream release notes, take a recovery point, upgrade in a representative
environment, and validate workflows before production rollout.

## Secret rotation

After an external secret manager changes the application or database Secret,
restart the consumer explicitly:

```bash
kubectl -n <namespace> rollout restart deployment/<release>-chiefonboarding
kubectl -n <namespace> rollout status deployment/<release>-chiefonboarding --timeout=300s
```

Rotating the Django secret invalidates user sessions and signed tokens. Rotate
it only as a deliberate incident or lifecycle action. Database credential
rotation must be coordinated with PostgreSQL so the init container and
application reconnect with the new value.

## NetworkPolicy and ingress

When an ingress controller runs outside the release namespace, add its
namespace and pod selectors to `networkPolicy.ingressFrom`. Confirm the labels
on the actual controller pods; an Ingress object alone does not grant network
access. Egress policy is a platform responsibility because integration
destinations vary by deployment.

## Incident evidence

Capture evidence before restarting components:

```bash
kubectl -n <namespace> describe deployment/<release>-chiefonboarding
kubectl -n <namespace> logs deployment/<release>-chiefonboarding -c wait-for-db --tail=100
kubectl -n <namespace> logs deployment/<release>-chiefonboarding -c chiefonboarding --tail=300
kubectl -n <namespace> get events --sort-by=.lastTimestamp
kubectl -n <namespace> get networkpolicy <release>-chiefonboarding -o yaml
```

Correlate pod restarts, HTTP failures, PostgreSQL availability, Django Q errors,
Secret rotation time, and integration provider failures. Preserve logs needed
for audit or post-incident analysis before replacing the pod.
