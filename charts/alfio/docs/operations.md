<!-- SPDX-License-Identifier: Apache-2.0 -->

# Operations

## Health and Logs

The `/healthz` endpoint backs all probes. Inspect it through the Service and
review every container when diagnosing startup:

```bash
kubectl get --raw /api/v1/namespaces/<namespace>/services/http:<release>-alfio:http/proxy/healthz
kubectl logs deployment/<release>-alfio --all-containers --tail=200
kubectl get events -n <namespace> --sort-by=.lastTimestamp
```

## Resource Sizing

The chart leaves requests and limits unset because ticket volumes and JVM heap
requirements vary. Establish a load-test baseline, set a memory limit with JVM
headroom, and monitor CPU throttling, memory working set, restarts, response
latency, and database saturation.

## Upgrade Procedure

1. Read the upstream and chart release notes.
2. Back up PostgreSQL and verify the backup is restorable.
3. Render the new release and review image, environment, listener, and Secret
   references.
4. Run `helm upgrade` during the selected maintenance window.
5. Wait for rollout, verify `/healthz`, and exercise public and administrator
   workflows.
6. Review pod restarts, logs, events, and database migration output.

## Recovery

The application pod is disposable; database recovery restores the durable
state. Restore PostgreSQL through the owning database process, deploy alf.io
with the matching credentials, and validate events, ticket inventory, attendees,
and administrator access. Do not treat pod recreation as a database restore.
