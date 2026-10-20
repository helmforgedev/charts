# Transmute Design

## Upstream boundary

The official pinned container image `ghcr.io/transmute-app/transmute` is used directly without modification.
Transmute is a media conversion and compression service utilizing FFmpeg, Libvips, and hardware encoders.

Runtime state is isolated in persistent storage (`/app/data`), housing the queue database and temporary processing workspaces.
Authentication supports internal authentication with administrator bootstrapping, optional self-registration, and native OpenID Connect (OIDC) Single Sign-On.

## Storage and availability

Transmute operates with a persistent filesystem claim for job processing and queue persistence.
The workload runs as a single-writer Deployment with `ReadWriteOnce` PVC storage to guarantee queue integrity.

## Security and identity

The container runs under non-root UID/GID 1000 with dropped capabilities (`ALL`), `RuntimeDefault` seccomp profile, and denied privilege escalation.
Secret keys and initial admin passwords can be mounted from Kubernetes Secrets or synchronized dynamically via External Secrets Operator (ESO).

## Networking and exposure

Standard ClusterIP service exposes HTTP port 8080.
External exposure supports standard Kubernetes Ingress as well as Gateway API HTTPRoute.
