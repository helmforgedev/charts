# Security

## Security Context

The openHAB image ultimately runs the application as UID/GID `9001`, but its
entrypoint starts as root so it can create the `openhab` user/group, adjust
directory ownership, and then drop privileges through `gosu`. For that reason,
the chart does not force `runAsUser`, `runAsGroup`, or `capabilities.drop: ALL`
on the application container.

This chart applies the safe hardening controls that are compatible with the
official image bootstrap sequence:

```yaml
podSecurityContext:
  fsGroup: 9001
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false   # openHAB writes to internal dirs at runtime
```

`fsGroup: 9001` keeps mounted PVCs group-accessible after privilege drop.
`allowPrivilegeEscalation: false` and `RuntimeDefault` seccomp reduce the
runtime attack surface without removing the capabilities required during
startup.

### Why readOnlyRootFilesystem is false

openHAB (OSGi/Karaf) writes to several directories at runtime:

- `/openhab/runtime/` — OSGi framework state
- `/openhab/userdata/tmp/` — Temporary files
- `/openhab/userdata/cache/` — Bundle cache

These are internal to the container and cannot be avoided. Mount your persistent
data on the three PVCs (`userdata`, `conf`, `addons`) to ensure durability.

## Network Security

### Exposed Ports

| Port | Protocol | Exposure |
|------|----------|---------|
| 8080 | HTTP | Web UI + REST API (always enabled) |
| 8443 | HTTPS | Secure access (not configured in this chart by default) |
| 8101 | TCP | Karaf SSH admin console (optional, disabled by default) |

### Karaf SSH Console

The Karaf console (port 8101) provides full administrative access to openHAB's
OSGi runtime. It is **disabled by default**. Enable only if needed:

```yaml
karaf:
  enabled: true
  service:
    type: ClusterIP   # Never expose as NodePort/LoadBalancer
```

When enabled, access it only via `kubectl port-forward`:

```bash
kubectl port-forward svc/<release>-karaf 8101:8101
ssh -p 8101 openhab@127.0.0.1
# Default Karaf password: habopen (change via Karaf console)
```

### Ingress

When using Ingress, configure authentication at the Ingress level if your openHAB
instance is publicly accessible. openHAB's built-in authentication handles
local API access, but consider adding an Ingress-level auth layer for public exposure.

## Admin Credentials

openHAB does not support injecting admin credentials via environment variables.
The admin account is created through the first-boot setup wizard.

When `admin.secretEnabled: true`, this chart creates a Kubernetes Secret to store
credentials for operational reference (e.g., for documentation or other tooling).
The Secret does NOT automatically configure openHAB — you still need to complete
the first-boot wizard with the same credentials.

```yaml
admin:
  secretEnabled: true
  username: admin
  password: "strongpassword"   # Set via --set or external secret manager
```

## Pod Security Standards

This chart is compatible with the `baseline` Pod Security Standard. It is not a
strict `restricted` workload because the official image must start as root and
because `readOnlyRootFilesystem` must remain false for the OSGi/Karaf runtime.

Use a baseline namespace for openHAB:

```bash
kubectl label namespace openhab pod-security.kubernetes.io/enforce=baseline
```
