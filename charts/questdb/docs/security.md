# QuestDB security

## Runtime hardening

The chart runs QuestDB directly as UID/GID 10001 with `DO_CHOWN=false`, seccomp
RuntimeDefault, no Linux capabilities, no privilege escalation, a read-only root
filesystem and no Kubernetes API token. Only the database PVC and `/tmp` are
writable by default.

Do not add a privileged ownership init container as a routine workaround. Fix
storage ownership or select a CSI driver that honors `fsGroup`.

## Authentication

The insecure upstream PostgreSQL password is replaced by a random retained
password. HTTP basic authentication is also enabled. Secrets are mounted as
files rather than copied into plain environment values. Rotate operator-managed
passwords by updating the Secret and restarting the StatefulSet because mounted
file updates do not guarantee immediate connection credential reload.

## Transport security

QuestDB OSS does not provide native TLS for its protocols. The default ClusterIP
and NetworkPolicy keep access internal. Public HTTP exposure requires TLS at an
Ingress or Gateway. Use a service mesh or another trusted encrypted path for
PostgreSQL, ILP TCP and QWP when transport confidentiality is required.

The unauthenticated `/status` endpoint on port 9003 exists for Kubernetes probes.
It is not exposed by the client Service. Metrics exposure is opt-in and has its
own NetworkPolicy peer list.

## Supply chain

The image is the official QuestDB 10.0.1 multi-architecture image pinned to its
OCI digest. Upstream publishes BuildKit provenance but no verified Cosign
signature or SBOM was found. Image scan findings and the upstream Web Console
asset licensing issue are recorded in [RESEARCH.md](../RESEARCH.md).
