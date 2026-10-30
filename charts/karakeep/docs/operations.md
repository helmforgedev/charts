<!-- SPDX-License-Identifier: Apache-2.0 -->

# Karakeep Operations

## Preflight

Render the chart before installing production values:

```bash
helm template karakeep charts/karakeep -f values.yaml
make validate-chart CHART=karakeep
```

Verify that every image tag is pinned:

```bash
make image-verify IMAGE=ghcr.io/karakeep-app/karakeep:0.34.1
make image-verify IMAGE=docker.io/getmeili/meilisearch:v1.53.0
make image-verify IMAGE=ghcr.io/karakeep-app/karakeep-chrome:154.0.8037.57-r1
```

## Installation

Local port-forward values:

```yaml
karakeep:
  nextAuthUrl: "http://localhost:3000"
```

Install and open the UI:

```bash
helm install karakeep helmforge/karakeep -f values.yaml
kubectl port-forward svc/karakeep-karakeep 3000:80
```

## Production Checklist

- Set `karakeep.nextAuthUrl` to the exact external URL.
- Use TLS at the Ingress, Gateway, or upstream edge proxy.
- Set resource requests and limits for Karakeep, Meilisearch, and Chromium.
- Use `karakeep.existingSecret` or External Secrets Operator for managed
  credentials.
- Define a PVC backup and restore procedure.
- Restrict `networkPolicy.ingressFrom` to the namespaces or pods that need
  access when the default cross-namespace rule is too broad.

## Health Checks

Check rollout and container status:

```bash
kubectl rollout status deploy/karakeep-karakeep
kubectl get pods -l app.kubernetes.io/name=karakeep
kubectl logs deploy/karakeep-karakeep -c karakeep --tail=100
```

Inspect sidecars:

```bash
kubectl logs deploy/karakeep-karakeep -c meilisearch --tail=100
kubectl logs deploy/karakeep-karakeep -c chromium --tail=100
```

## Backup and Restore

Back up the PVC that backs `/data`. A restore should verify:

- login succeeds with the restored `NEXTAUTH_SECRET`;
- bookmarks and uploaded content are present;
- Meilisearch starts and can search restored content;
- Chromium capture still works for a new bookmark.

If restoring into a new release name, either restore the Secret keys with the PVC
or set `karakeep.existingSecret` to a Secret that contains the original
`nextauth-secret` and `meili-master-key` values.

## Meilisearch Database Upgrades

The default `meilisearch.upgradeDb: true` allows the pinned Meilisearch image to
upgrade an older database stored on the PVC. Meilisearch migrations are not
atomic. Take a volume snapshot or an application-consistent backup before a
chart upgrade that changes `meilisearch.image.tag`.

After the upgraded release has started successfully, confirm that the
Meilisearch `UpgradeDatabase` task reached the `succeeded` status and verify a
search. Only then may `meilisearch.upgradeDb` be set to `false`. Keep it enabled
when task success has not been confirmed or a restored PVC may contain a
database created by an older Meilisearch release.

The default `meilisearch.environment: development` preserves compatibility
with existing secrets that may contain a master key shorter than 16 bytes.
Before opting into `production`, rotate any shorter key to at least 16 bytes and
update the Secret used by both containers.

Use `meilisearch.extraEnv` only for additional settings such as log levels. The
chart rejects overrides of credentials, listener, runtime environment, and the
database-upgrade switch because those variables are controlled by dedicated
values.

## Common Issues

### Login redirects fail

Check `karakeep.nextAuthUrl`. It must match the public URL exactly, including
scheme and host. A port-forward setup commonly needs:

```yaml
karakeep:
  nextAuthUrl: "http://localhost:3000"
```

### Pod is OOMKilled

The default sidecars are useful but memory intensive. Add limits and inspect the
container that was killed:

```bash
kubectl describe pod -l app.kubernetes.io/name=karakeep
kubectl logs -l app.kubernetes.io/name=karakeep -c chromium --tail=100
```

For small nodes, disable one or both sidecars:

```yaml
meilisearch:
  enabled: false

chromium:
  enabled: false
```

### Search is unavailable

Confirm Meilisearch is enabled and receiving the same master key as the main
container:

```bash
kubectl get secret <secret-name> -o jsonpath='{.data.meili-master-key}'
kubectl logs deploy/karakeep-karakeep -c meilisearch --tail=100
```

### Screenshots are not created

Confirm Chromium is enabled and listening on its upstream-fixed port 9222:

```bash
kubectl get deploy karakeep-karakeep -o jsonpath='{.spec.template.spec.containers[*].name}'
kubectl logs deploy/karakeep-karakeep -c chromium --tail=100
```

Karakeep reaches the sidecar proxy through the IPv4 loopback address
`http://127.0.0.1:9222`. Do not replace it with `localhost`; the proxy does not
listen on IPv6. Port 9222 is unauthenticated and binds all pod IPv4 interfaces,
so keep the NetworkPolicy enabled or provide another access boundary.

Remove any `BROWSER_WEB_URL` or `BROWSER_CONNECT_ONDEMAND` entry from
`karakeep.extraEnv` when the Chromium sidecar is enabled. Dedicated chart values
manage those variables and duplicate definitions are rejected.

### Custom port rollout fails

`containerPorts.http` changes Karakeep's `PORT`; `meilisearch.port` changes both
`MEILI_HTTP_ADDR` and Karakeep's `MEILI_ADDR`. Inspect the rendered environment
and probe the named ports rather than changing `service.port`, which only
changes the Service-facing port. Chromium port 9222 cannot be overridden because
the official image reserves it in the entrypoint.

### ExternalSecret renders but pod cannot start

The target Secret must exist before the Deployment can consume it. Check the
ExternalSecret status and target Secret keys:

```bash
kubectl get externalsecret
kubectl describe externalsecret karakeep-karakeep-secret
kubectl get secret karakeep-app-secret
```
