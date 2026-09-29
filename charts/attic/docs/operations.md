# Attic operations

## Bootstrap a cache

Install the Attic CLI in a trusted administrative environment, log in with a
root or delegated token, create a cache and then issue narrower CI tokens.

```bash
attic login platform https://cache.example.com/ ROOT_TOKEN
attic cache create ci --public
atticadm make-token --sub builder --validity '30 days' --pull ci --push ci
```

Retrieve the cache public key with `attic cache info ci` and distribute it with
the Nix substituter URL through configuration management.

## Validate functionality

A process-level HTTP response is not enough. The operational smoke test is:

1. create or select a small Nix store path;
2. push it with `attic push`;
3. fetch its `.narinfo`;
4. restore it into an alternate empty Nix store;
5. restart an API pod;
6. fetch it again.

This exercises authentication, database metadata, object storage, signing and
persistence.

## Distributed lifecycle

Helm runs a migration Job before install and upgrade. The Job requires the
existing Secret and external PostgreSQL to be reachable before other release
resources are applied. On failure, inspect hook logs and leave the old API
version running until the cause is understood.

The API Deployment uses a zero-unavailable rolling strategy. The GC Deployment
uses Recreate and one replica. Do not manually scale GC.

## Logging

Set `config.logLevel` using Rust tracing filters. Start with
`attic_server=info`; temporarily raise a narrow module to debug rather than
enabling verbose logs globally. Credentials must never be logged.

Useful commands:

```bash
kubectl -n attic logs deployment/attic -c attic --tail=200
kubectl -n attic logs deployment/attic-gc --tail=200
kubectl -n attic get events --sort-by=.lastTimestamp
```

## Upgrade procedure

1. Read upstream commits and migration source between image SHAs.
2. Confirm the target multi-architecture image manifest.
3. Back up metadata and objects together.
4. Render and validate the new configuration.
5. Upgrade a non-production environment.
6. Push and pull a real store path.
7. Upgrade production and monitor migration/API/GC logs.

Because upstream does not promise database downgrade compatibility, a rollback
may require restoring the pre-upgrade backup rather than only changing the image.

## Incident checks

- Listener available but requests fail: inspect PostgreSQL/S3 logs and egress.
- HTTP 400: verify Host against `allowedHosts`.
- HTTP 401: inspect token expiry, permissions, issuer and audience.
- Push stalls: inspect proxy buffering, body size and timeouts.
- Objects missing: compare DB recovery point with object-store versions.
- GC stuck: preserve logs and check upstream known issues before manual deletes.
