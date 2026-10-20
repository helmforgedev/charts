# Transmute Chart Design

## Purpose

The  chart deploys the official Transmute self-hosted audio and video
transcoding and compression server as a single-instance Kubernetes workload with
persistent job queue management, local hardware-accelerated processing capabilities,
OpenID Connect (OIDC) Single Sign-On, and modern traffic exposure.

Transmute is stateful regarding its media conversion queue and in-flight workers.
The chart therefore models one pod as the supported topology with  rollout
semantics so that a single instance owns  at any given time.

## Workload Model

The chart renders a Deployment with one replica. The main container exposes an HTTP
service over port 8080. The application coordinates asynchronous FFmpeg and Libvips
worker tasks against a local database and scratch workspace.

## Storage Design

Transmute persists configuration, SQLite queue state, user metadata, and upload scratch
spaces under . The chart provisions a single PVC for that path with
 access mode by default. Operators can attach an existing claim
() for disaster recovery or migrations.

## Supported Boundaries

The chart supports:

- Official upstream  container images with immutable version pinning
- Single-replica Deployment with  strategy
- Dedicated PVC storage for  with configurable storageClass and size
- Both standard Kubernetes Ingress and canonical Gateway API  multi-route definitions
- Kubernetes Secret management for administrative credentials and JWT secret keys
- Dynamic credential synchronization via External Secrets Operator (ESO)
- Native OIDC Single Sign-On parameters
- Non-root execution (, ) with  capabilities dropped and  seccomp profile

The chart does **not** support:

- Multi-replica Deployments sharing the same filesystem (SQLite queue locking prevents concurrent multi-node writes)
- Running stateless without persistent storage (all queues, configs, and user databases would reset on restart)

## Trade-offs and Invariants

1. **Single replica vs availability**: Video/audio transcoding queue workers rely on
   local filesystem state and SQLite. Data consistency is prioritized over horizontal autoscaling.
2. **Recreate rollout**:  is prohibited by design because two pods cannot
   safely mount the same  volume simultaneously.
3. **Worker resource bounds**: Transcoding is CPU- and memory-intensive; operators are
   strongly advised to set explicit resource limits to prevent worker starvation on adjacent pods.

## Non-Goals

- Managing external distributed Celery/Redis worker clusters out-of-band
- Bundling third-party object storage drivers or CSI plugins inside the chart
- Providing automated hardware GPU driver installation on the host node
