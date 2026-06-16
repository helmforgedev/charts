<!-- SPDX-License-Identifier: Apache-2.0 -->

# Cronicle Architecture

Cronicle is a web-managed scheduler for recurring jobs, ad hoc commands, HTTP
requests, and plugin-backed tasks. The HelmForge chart deploys it as a
single-writer Kubernetes workload with durable filesystem state.

## Components

| Component | Kubernetes resource | Purpose |
| --- | --- | --- |
| Cronicle application | Deployment | Runs the web UI, scheduler, API, and job runner. |
| Service | Service | Exposes the HTTP UI and optional UDP discovery port. |
| Configuration | ConfigMap | Renders `config.json` from Helm values. |
| Session secret | Secret | Provides `secret_key` through `CRONICLE_secret_key`. |
| Data store | PersistentVolumeClaim | Stores schedules, queue, history, and job logs. |
| Public access | Ingress | Optional HTTP routing and TLS termination. |

## Request Flow

```text
Browser
   |
   | port-forward or Ingress
   v
Kubernetes Service
   |
   v
Cronicle web server on port 3012
   |
   +--> /opt/cronicle/conf/config.json
   +--> /opt/cronicle/data
```

The default chart keeps access private. Operators can enable Ingress once the
public URL, TLS, and surrounding access controls are ready.

## Scheduler Flow

```text
Cronicle scheduler
   |
   +--> reads event definitions from /opt/cronicle/data
   +--> starts jobs inside the Cronicle process
   +--> writes run logs and history to /opt/cronicle/data
   +--> sends SMTP notifications when configured
```

The chart does not create Kubernetes Jobs for each Cronicle event. Cronicle owns
job execution inside its own container, so pod resource limits and
`cronicle.maxJobs` are the primary controls for runtime pressure.

## Single-Replica Rationale

The chart renders `replicas: 1` and `strategy.type: Recreate`. This is
intentional:

- the default storage is a single PVC;
- Cronicle job definitions and queue state are filesystem-backed;
- overlapping scheduler pods could duplicate work or corrupt local state;
- Recreate avoids parallel old/new pods during upgrades.

If you need multi-server Cronicle, validate the upstream storage and discovery
design independently before changing the chart topology.

## Configuration Rendering

The chart writes a complete `config.json` with the values that are safe to
parameterize:

- `base_app_url` from `cronicle.baseUrl`;
- SMTP sender and host from `cronicle.emailFrom` and
  `cronicle.smtpHostname`;
- filesystem storage rooted at `/opt/cronicle/data`;
- queue directory under the same PVC;
- HTTP server port from `cronicle.port`;
- `job_memory_max` and `max_jobs` controls.

Additional Cronicle environment variables can be passed through
`cronicle.extraEnv` for advanced upstream settings.

## Operational Controls

Production installations should set:

- `cronicle.baseUrl` to the externally reachable URL;
- `cronicle.maxJobs` to a bounded value that matches pod resources;
- CPU and memory requests/limits;
- a stable `secret.existingSecret` for production sessions;
- persistent storage sized for job logs and history;
- TLS and access control at the Ingress or Gateway layer.

## Failure Domains

| Failure | Expected behavior | Operator action |
| --- | --- | --- |
| Pod restart | Cronicle restarts and reads state from the PVC. | Confirm pod readiness and inspect logs. |
| PVC loss | Schedules, history, and logs are lost. | Restore from storage snapshot or backup process. |
| Secret rotation | Existing sessions become invalid. | Re-login and avoid unnecessary key rotation. |
| SMTP outage | Jobs continue, notifications fail upstream. | Fix SMTP host and review Cronicle notification logs. |
| Public URL mismatch | Links in email/UI point to the wrong host. | Correct `cronicle.baseUrl` and upgrade the release. |
