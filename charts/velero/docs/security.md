<!-- SPDX-License-Identifier: Apache-2.0 -->

# Velero Security Guide

## Default Server Boundary

The server uses the UID and group declared by the official Velero image. The
chart defaults to a non-root process, a read-only root filesystem, no added
Linux capabilities, disabled privilege escalation, and RuntimeDefault seccomp.
Writable `emptyDir` volumes are mounted only at `/scratch`, `/plugins`, and
`/tmp`; Velero uses `/tmp` for plugin process files.

The default AWS plugin init container also runs as the non-root identity from
its official image with the same restrictions. Review custom entries in
`plugins.extra`; their images and security contexts are operator-controlled.

## Kubernetes API Access

Velero is a Kubernetes controller, so its ServiceAccount token is mounted by
default. The default ClusterRoleBinding uses `cluster-admin` because backup and
restore can span cluster-scoped and namespaced resources. To manage narrower
RBAC externally, set:

```yaml
rbac:
  create: false
  clusterAdministrator: false
```

The replacement permissions must still cover every resource type selected for
backup and restore, including Velero CRDs.

## Credentials

Do not commit provider credentials in values files. Use a pre-created Secret,
an external secret controller, or cloud workload identity:

```yaml
credentials:
  useSecret: true
  existingSecret: velero-cloud-credentials
  secretContents: ""
```

Scope bucket permissions to the required backup location and enable provider
encryption, versioning, retention, and audit logs where available.

## Network Policy

The default NetworkPolicy admits only the metrics listener. Egress remains open
because the Kubernetes API address and object-storage endpoints vary by
cluster. To replace it with a restrictive environment-specific policy, set
`networkPolicy.allowExternalEgress=false` before adding the required Kubernetes
API, DNS, and object-storage rules. NetworkPolicy rules are additive, so leaving
the chart's allow-all egress rule enabled defeats a second restrictive policy.
Disabling external egress without replacement rules prevents the server from
reaching its control plane and storage. The chart policy selects only the
server; node-agent networking must be restricted separately.

## Node-Agent Exception

The optional node-agent runs as UID 0 and mounts kubelet host paths for
filesystem backup. It remains unprivileged, drops all capabilities, blocks
privilege escalation, uses a read-only root filesystem, and applies
RuntimeDefault seccomp. Enable it only on trusted nodes after reviewing Pod
Security admission, hostPath policy, and workload isolation.

When the node-agent uses the Kopia uploader, the chart mounts ephemeral writable
volumes at `/home/cnb/udmrepo` and `/home/cnb/.cache` in both the server and
node-agent. These paths hold Kopia configuration and cache data and keep the
remaining root filesystem read-only. The mounts are enabled with the node-agent
so per-backup annotations and schedules can opt into filesystem backup even
when `configuration.defaultVolumesToFsBackup=false`.
