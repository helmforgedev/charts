# Operations and troubleshooting

## Health

Kubernetes probes call `/api/health`. A healthy response is HTTP 200 with `status: healthy`. With the shared store, readiness calls `/api/ready`, which answers 200 with `"store":"redis"` when the pod can serve and 503 while it starts or cannot reach the store; liveness stays on `/api/health`. `/api/config` provides a safe public view of active JMAP, OAuth, remember-me, settings-sync, and branding settings.

## Upgrade

Back up the PVC and Secret, review upstream changes, and run `helm upgrade`. Recreate strategy intentionally stops the old pod before the new one mounts storage. Expect a short outage. With the shared store and no volume, replicas roll one at a time without an outage; back up the store instead of the PVC.

## Mode changes

Wizard to declarative changes should be rehearsed on a PVC clone. Saved admin values override environment values; remove only the specific obsolete keys after backing up the admin directory.

Declarative to wizard requires writable admin configuration. Change the mode and confirm the PVC is mounted before opening `/setup`.

## Diagnosis

```bash
kubectl -n mail get deploy,pod,svc,pvc
kubectl -n mail describe pod -l app.kubernetes.io/name=bulwark-mail
kubectl -n mail logs deployment/bulwark-mail --tail=200
kubectl -n mail get events --sort-by=.lastTimestamp
```

Use a browser developer console for CORS and cookie problems. Pod-local health does not prove that a user's browser can resolve or trust the JMAP endpoint.

## Common failures

- Pending PVC: select a valid StorageClass or existing claim.
- CreateContainerConfigError: existing Secret is missing a configured key.
- Setup API 404 in declarative mode: expected behavior.
- Root redirects to `/setup` in wizard mode: setup is incomplete or its state was not restored.
- OAuth metadata timeout: NetworkPolicy or SSRF safeguards block discovery.
- Read-only errors outside `/app/data` or `/tmp`: report an upstream writable-path regression.
- Pods Running but not Ready with the shared store: `/api/ready` returns 503. Check the store URL key, the store itself, and NetworkPolicy egress to its port.
- Readiness probe 404 on `/api/ready`: the image predates the shared store; use a newer image or set `probes.readiness.path: /api/health`.

## Rollback

Rollback the Helm release only when the older image can read the current on-disk state. Otherwise restore a matching PVC snapshot and Secret. Never pair old encrypted settings with a new session secret.

<!-- @AI-METADATA
type: chart-docs
title: Bulwark Mail operations
description: Health, upgrades, mode changes, and troubleshooting
keywords: bulwark, operations, upgrade, troubleshooting
purpose: Operate and recover Bulwark Mail
scope: Chart
relations:
  - charts/bulwark-mail/README.md
path: charts/bulwark-mail/docs/operations.md
version: 1.0
date: 2026-09-28
-->
