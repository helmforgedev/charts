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
cluster. Define a separate environment-specific egress policy when those
destinations and DNS requirements are known. Disabling external egress without
replacement rules prevents Velero from reaching its control plane and storage.

## Node-Agent Exception

The optional node-agent runs as UID 0 and mounts kubelet host paths for
filesystem backup. It remains unprivileged, drops all capabilities, blocks
privilege escalation, uses a read-only root filesystem, and applies
RuntimeDefault seccomp. Enable it only on trusted nodes after reviewing Pod
Security admission, hostPath policy, and workload isolation.
