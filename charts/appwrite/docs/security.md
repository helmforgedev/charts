<!-- SPDX-License-Identifier: Apache-2.0 -->
# Appwrite security guide

## Trust boundary

Ingress or Gateway API is the public boundary. The Console, API, and realtime
endpoint share one origin, while workers, schedulers, MariaDB, Redis, and shared
PVCs remain cluster-internal. NetworkPolicies isolate Appwrite workloads and
open only the three listener ports for ingress. Default egress remains open
because SMTP, OAuth, webhooks, storage, and execution integrations are selected
by each operator.

## Credentials

Use `appwrite.existingSecret`, the external database and Redis existing-Secret
fields, and `backup.s3.existingSecret` in production. Do not rotate the OpenSSL
key by replacing a Helm value: encrypted application data requires an explicit
Appwrite key-rotation procedure. Protect Secret backups together with the
MariaDB and shared-volume backups they decrypt.

## Runtime posture

ServiceAccount tokens are not mounted. Application containers use
RuntimeDefault seccomp, cannot escalate privileges, and drop all capabilities.
The official Appwrite image still needs writable runtime paths and is not forced
to a non-root UID. Backup containers run as UID/GID 1000 with a read-only root
filesystem and a dedicated temporary volume.

## Production checklist

- Terminate TLS at the shared Console/API/realtime origin.
- Restrict NetworkPolicy ingress peers and egress destinations.
- Use externally managed Secrets and a supported rotation process.
- Scan pinned Appwrite, Console, MariaDB, Redis, and backup images.
- Back up MariaDB, every shared PVC, and the application Secret.
- Keep Appwrite migrations separate from Helm hooks and observe them directly.
- Restrict access to the optional S3 backup bucket and test restores.
- Monitor authentication failures, worker errors, restarts, and backup jobs.

## NetworkPolicy customization

`networkPolicy.ingressFrom` limits callers allowed to reach the API, Console,
and realtime listeners. `networkPolicy.egress` is a standard Kubernetes egress
rule list applied to Appwrite workloads. Include DNS and every required external
dependency before replacing the permissive default.
