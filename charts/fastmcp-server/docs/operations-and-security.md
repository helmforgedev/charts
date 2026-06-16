<!-- SPDX-License-Identifier: Apache-2.0 -->

# Operations and Security

## Health and Startup

The chart enables all probes by default:

| Probe | Default path | Purpose |
| --- | --- | --- |
| Startup | `/startupz` | Gives source loading time before liveness starts enforcing restarts. |
| Liveness | `/healthz` | Restarts the pod when the server becomes unhealthy. |
| Readiness | `/healthz` | Removes the pod from Service endpoints when it is not ready. |

Use `server.strictLoading=true` in production when malformed tools, resources,
or prompts should fail the pod instead of starting with partial content.

## Observability

Set `server.logFormat=json` for structured logs. Enable metrics with:

```yaml
metrics:
  enabled: true
```

When Prometheus Operator is installed, enable the ServiceMonitor:

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
```

## NetworkPolicy

`networkPolicy.enabled=true` creates an ingress policy for the MCP server port.
The chart does not generate egress restrictions because each deployment may
need different endpoints:

- S3-compatible object storage;
- Git hosts;
- JWT JWKS URI;
- package indexes when `extraPipPackages` is used;
- DNS and cluster services.

If your cluster enforces default-deny egress, add a separate platform
NetworkPolicy that allows the endpoints required by the selected sources.

## Pod Security

The default pod security posture is restricted:

- service account token automount is disabled;
- pod and container run as non-root UID/GID `1000`;
- privilege escalation is disabled;
- all Linux capabilities are dropped;
- `RuntimeDefault` seccomp is enabled.

The root filesystem is not immutable by default. The application may install
`extraPipPackages` and writes synchronized source content to `/app/workspace`.
Use a persistent workspace or extra mounts when larger source trees must survive
pod restarts.

## Production Checklist

- Use `auth.type=bearer` or `auth.type=jwt`; avoid unauthenticated public MCP
  endpoints.
- Store S3, Git, and bearer credentials in existing Kubernetes secrets.
- Use `server.strictLoading=true` for fail-fast startup.
- Enable JSON logs and metrics.
- Set explicit CPU and memory requests and limits.
- Enable ingress TLS or Gateway API TLS at the platform Gateway.
- Enable persistence when external source synchronization should survive pod
  restarts.
- Review egress requirements before enabling default-deny NetworkPolicy.

## Troubleshooting

Port-forward the Service for local diagnosis:

```bash
kubectl port-forward svc/fastmcp-server 8000:8000
curl http://localhost:8000/healthz
curl http://localhost:8000/mcp
```

Inspect source-loading failures with:

```bash
kubectl logs deploy/fastmcp-server
kubectl describe pod -l app.kubernetes.io/name=fastmcp-server
```

For source-sync deployments, also inspect the init container logs:

```bash
kubectl logs deploy/fastmcp-server -c source-sync
```
