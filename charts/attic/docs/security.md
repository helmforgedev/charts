# Attic security

## Container isolation

The official upstream image does not declare a user. The chart supplies UID,
GID and fsGroup 10001, enables RuntimeDefault seccomp, drops every capability,
disables privilege escalation and uses a read-only root filesystem. Only the
data volume and `/tmp` are writable.

The ServiceAccount token is not mounted. Attic does not call the Kubernetes API.

Some storage drivers do not honor fsGroup. If the pod reports permission errors
under `/data`, fix volume ownership through the storage platform rather than
running the application as root.

## Signing keys and tokens

The root token can administer every cache and must not be shared with routine
builders. Generate cache-scoped, short-lived tokens using `atticadm`:

```bash
atticadm make-token \
  --sub ci-builder \
  --validity '30 days' \
  --pull 'ci-*' \
  --push 'ci-*' \
  --create-cache 'ci-*'
```

Use separate tokens for humans and automation. Rotate them independently of
the server signing key.

RS256 supports a useful separation: API replicas can verify with the public
key, while only an isolated administrator holds the private key needed to mint
tokens. HS256 is operationally simpler but grants signing capability wherever
the shared key is mounted.

## External Secrets

The canonical `externalSecrets.items` contract can project Vault, cloud secret
manager or other provider data into the Secret consumed by Attic. For the
distributed migration hook, the target Secret must exist before Helm starts.
Bootstrap it out of band or reconcile the ExternalSecret before installing the
distributed release.

## Network policy

When enabled, ingress is limited to configured peers and port `http`. Egress
restriction is opt-in because PostgreSQL and S3 destinations differ between
environments. Always preserve DNS and add precise database and object-storage
rules.

NetworkPolicy enforcement requires a capable CNI. A rendered policy is not
proof that the cluster enforces it.

## Nix trust

Clients trust cache public keys to accept substituted store paths. Publish the
expected public key through an authenticated configuration channel and audit
changes. Do not copy a key from an unverified chat message or HTTP endpoint.

## Proxy security

Use TLS, restrict accepted hosts and keep proof-of-possession enabled. Rate
limits must account for legitimate long uploads without allowing unlimited
anonymous abuse. Public caches grant unauthenticated pull access by design;
push and administrative actions still require scoped tokens.
