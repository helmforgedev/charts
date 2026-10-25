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
