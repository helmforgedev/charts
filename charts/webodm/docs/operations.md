<!-- SPDX-License-Identifier: Apache-2.0 -->

# Operations

Back up PostgreSQL and WebODM media as one consistency domain. Quiesce uploads
and task creation, record the database recovery point, then snapshot the media
claim. NodeODM task data is useful for recovery of in-flight work but does not
replace the WebODM media backup.

Before upgrades, verify upstream migrations, take a coordinated backup, render
the new chart, and exercise a real small processing task. Do not roll back an
application image across incompatible database migrations without restoring a
matching database backup.

The chart runs WebODM's idempotent migration and boot routine before the
upstream startup script. This initializes the default settings before the
script's first internal HTTP request; seeing the migration command twice in
startup logs is expected because the upstream script retains ownership of its
normal lifecycle.

Monitor web, worker, PostgreSQL, Redis, processing storage, and NodeODM task
duration. Large projects routinely require more resources than chart defaults.

After rotating an external Secret, restart the consumers because a Helm upgrade
with unchanged values cannot observe external Secret data:

```bash
kubectl rollout restart deployment/<release> deployment/<release>-worker \
  deployment/<release>-processing -n <namespace>
kubectl rollout status deployment/<release> -n <namespace>
kubectl rollout status deployment/<release>-worker -n <namespace>
kubectl rollout status deployment/<release>-processing -n <namespace>
```

Before changing listener values, render the release and confirm that Service
ports remain independent. After the upgrade, inspect `WO_PORT` in the web pod,
the generated `/webodm/nginx/nginx.conf`, the NodeODM command line, both named
container ports, and both Service endpoint slices. The chart rewrites the
upstream NGINX template's fixed `8000` listeners to `WO_PORT` before startup.
Run `helm test` and submit a small representative image set; HTTP health alone
does not exercise the processing pipeline or prove resource capacity.

For incidents, capture pod status, restart counts, warning events, previous
container logs, Celery queue state, database connectivity, PVC usage, and the
processor registration Job before restarting components. Preserve the database
and media recovery point together when recovery involves persistent state.
