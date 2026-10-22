# Transmute Chart Design

## Purpose

This chart deploys the official Transmute container as a production-oriented,
single-node file conversion service. It maps only configuration supported by
Transmute v2.1.1 and keeps Kubernetes integration explicit and testable.

## State and rollout model

Transmute keeps its SQLite database, user records, job state, uploaded inputs and
generated outputs below `DATA_DIR`. Those components are not designed for shared,
concurrent writes by horizontally scaled application pods.

The chart consequently treats these as invariants:

1. `replicaCount` is exactly one.
2. `persistence.enabled` is true.
3. The Deployment strategy is `Recreate`.
4. One stable `AUTH_SECRET_KEY` signs JWTs across restarts and upgrades.

Both JSON Schema and template validation reject unsafe value combinations.

## Storage

A single PVC is mounted at `persistence.mountPath`, which defaults to `/app/data`
and matches `config.dataDir`. An existing claim can be attached for restore or
migration. The chart deliberately does not advertise an online, application-aware
backup API; snapshots or file-level copies must be taken while writes are stopped.

## Authentication

Transmute generates a random JWT signing key when none is supplied, but an
application-generated key changes at every restart. The chart instead owns a
Kubernetes Secret, preserves the generated 64-character value through Helm
upgrades with `lookup`, and injects it as `AUTH_SECRET_KEY`.

The upstream application has no initial-administrator environment variables. The
first user registered on an empty database becomes administrator. The chart does
not emulate unsupported bootstrap behavior.

## OIDC

OIDC is activated by the upstream tuple `APP_URL`, `OIDC_ISSUER_URL`,
`OIDC_CLIENT_ID` and `OIDC_CLIENT_SECRET`. `OIDC_INTERNAL_URL` optionally separates
browser-facing redirects from cluster-internal discovery and token exchange. The
callback is always `<APP_URL>/api/oidc/callback`; scopes are fixed upstream.

The OIDC client secret shares the application Secret interface so it can be
supplied inline, from an existing Secret or through External Secrets Operator.

## Runtime security

The pod and container run as UID/GID 1000 with runtime-default seccomp,
privilege escalation disabled and all Linux capabilities dropped. The root
filesystem is read-only. A memory-independent `emptyDir` mounted at `/tmp`
provides writable font and conversion caches through `HOME` and `XDG_CACHE_HOME`.
Durable writes remain on the PVC.

The ServiceAccount token is not mounted. NetworkPolicy is opt-in because OIDC and
conversion integrations can require provider-specific DNS and external egress.

## Supported integrations

- Ingress using `ingress.ingressClassName`;
- Gateway API v1 HTTPRoute with multiple route definitions;
- IPv4, IPv6 and dual-stack Services;
- External Secrets Operator using complete `items[].spec` objects;
- custom environment variables and volumes for upstream-compatible extensions.

## Non-goals

- horizontal scaling or high availability for the local SQLite application;
- installing an identity provider, Gateway controller, CSI driver or ESO;
- claiming generic GPU acceleration without explicit upstream device support;
- manufacturing unsupported registration, administrator or OIDC scope settings.
