<!-- SPDX-License-Identifier: Apache-2.0 -->

# Cronicle Operations

This guide covers day-two operations for the HelmForge Cronicle chart: access,
storage, scheduler safety, notifications, and troubleshooting.

## Access

Default installs are private:

```bash
kubectl port-forward -n cronicle svc/cronicle-cronicle 3012:80
```

Open `http://127.0.0.1:3012` and change the default upstream credentials after
the first login.

For public access, enable Ingress and align `cronicle.baseUrl`:

```yaml
cronicle:
  baseUrl: https://cronicle.example.com

ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: cronicle.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: cronicle-tls
      hosts:
        - cronicle.example.com
```

Use TLS and put Cronicle behind trusted network controls, SSO, VPN, or reverse
proxy authentication when it is reachable outside the cluster.

## Storage Operations

Cronicle stores schedules, run history, and job logs on the PVC mounted at
`/opt/cronicle/data`.

Useful checks:

```bash
kubectl get pvc -n cronicle -l app.kubernetes.io/instance=cronicle
kubectl exec -n cronicle deploy/cronicle-cronicle -- du -sh /opt/cronicle/data
kubectl logs -n cronicle deploy/cronicle-cronicle --tail=100
```

The quality baseline introduced after chart `1.1.11` preserves the previous
default pod security and ServiceAccount-token behavior. The new
`securityProfile` and `networkPolicy` features are disabled unless explicitly
enabled. Test both a normal upgrade and `--reuse-values` before enabling either
feature in production.

## Optional Security Profile

The community image starts as root, so the chart cannot safely force
`runAsNonRoot` or a read-only root filesystem. The compatible opt-in profile
still reduces the pod's privileges:

```yaml
securityProfile:
  enabled: true
```

This profile uses RuntimeDefault seccomp, drops all Linux capabilities, blocks
privilege escalation, and disables ServiceAccount token automount. Test all
scheduled commands because jobs execute inside the Cronicle container. Use
explicit `podSecurityContext` and `securityContext` values for the smallest
required exceptions.

An optional NetworkPolicy can be enabled independently. With no custom rules,
it preserves ingress and egress connectivity. Define restrictive rules only
after inventorying DNS, SMTP, webhook, package repository, and job-specific
destinations.

Size the PVC according to job log retention. Long-running shell commands and
chatty jobs can grow the log directory faster than the scheduler metadata.

## Scheduler Capacity

`cronicle.maxJobs` defaults to `0`, which means unlimited. Production
installations should cap concurrency and match resources to expected workload:

```yaml
cronicle:
  maxJobs: 4
  jobMemoryMax: 268435456

resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: "2"
    memory: 2Gi
```

Cronicle runs jobs inside the application container. Resource limits apply to
the scheduler and the jobs together. The example above budgets up to four
concurrent 256 MiB jobs inside a 2 GiB pod limit, leaving headroom for the
scheduler process and job log buffering.

## Notifications

Set SMTP identity values when email notifications are required:

```yaml
cronicle:
  baseUrl: https://cronicle.example.com
  emailFrom: cronicle@example.com
  smtpHostname: smtp.example.com
  extraEnv:
    - name: CRONICLE_smtp_port
      value: "587"
    - name: CRONICLE_mail_options__secure
      value: "0"
```

Port 587 commonly uses STARTTLS, so keep `CRONICLE_mail_options__secure` at
`"0"` unless the SMTP provider requires implicit TLS on connect, typically on
port 465.

If SMTP requires credentials, store them in a Kubernetes Secret and reference it
from `cronicle.extraEnv` with `valueFrom.secretKeyRef`.

## Upgrades

The Deployment uses the `Recreate` strategy, so upgrades briefly stop the
scheduler before starting the new pod. This prevents overlapping scheduler
instances with the same PVC.

Recommended upgrade checks:

```bash
helm upgrade cronicle oci://ghcr.io/helmforgedev/helm/cronicle -n cronicle -f values.yaml
kubectl rollout status deploy/cronicle-cronicle -n cronicle --timeout=300s
kubectl logs -n cronicle deploy/cronicle-cronicle --tail=100
```

## Troubleshooting

### The UI is reachable but links point to localhost

Set `cronicle.baseUrl` to the public URL and upgrade the release.

### Jobs disappeared after reinstall

Check whether the PVC was deleted or a different claim is mounted:

```bash
kubectl describe deploy/cronicle-cronicle -n cronicle
kubectl get pvc -n cronicle
```

Cronicle schedules live on the PVC. Losing the PVC loses application state.

### Users are logged out after reinstall or upgrade

The `secret_key` changed. The chart-generated key is convenient for simple
installs but is generated during rendering. Use a stable existing Secret for
production:

```yaml
secret:
  create: false
  existingSecret: cronicle-secret
```

The referenced Secret must contain the `secret_key` key. The chart maps this
key to `CRONICLE_secret_key`, Cronicle's case-sensitive environment override
for the top-level `secret_key` configuration path.

### The pod is ready but jobs overload the node

Set `cronicle.maxJobs`, lower job memory limits, and add pod CPU/memory limits.
Review Cronicle job definitions for commands that should run outside the
scheduler pod.
