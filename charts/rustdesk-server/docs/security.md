# Identity and security

## Generated identity

With `auth.existingSecret: ""`, hbbs generates the native files on first boot;
hbbr starts only after that initialization. Inspect the public key:

```bash
kubectl -n rustdesk logs deployment/rustdesk-rustdesk-server -c hbbs
```

Copy only the `Key:` value to clients. Never distribute `id_ed25519`, which is the
private signing key. The image has no shell or `cat`; `kubectl exec -- cat` and
ordinary `kubectl cp` cannot operate inside these production containers.

The key check identifies the selected server to clients and restricts use to
clients configured with that public key. It is not per-user authentication,
authorization or a substitute for endpoint consent and access passwords.

## Existing identity

Use matching files from a trusted existing RustDesk server. The native private
file contains base64 of 64 bytes (32-byte seed followed by 32-byte public key).
The public file contains base64 of 32 bytes. PEM/SSH formats are unsupported.

```bash
kubectl -n rustdesk create secret generic rustdesk-identity \
  --from-file=id_ed25519=./id_ed25519 \
  --from-file=id_ed25519.pub=./id_ed25519.pub
helm upgrade --install rustdesk helmforge/rustdesk-server -n rustdesk \
  --set auth.existingSecret=rustdesk-identity
```

Supply both files; the chart mounts them read-only into both processes. Custom
Secret key names use `auth.privateKeyKey` and `auth.publicKeyKey`. Helm does not
read or store the file contents in its release values. Kubernetes Secret access,
encryption at rest and backups remain cluster administration concerns.
The server derives its effective public identity from the private file, so
operators must verify the distributed public file matches that private key.

SubPath Secret mounts are immutable for a running container. After changing a
Secret, explicitly restart the Deployment and verify both processes report the
expected public key. Rotating identity requires updating clients and ends active
sessions. Do not rotate accidentally during ordinary application upgrades.

## External Secrets

Install External Secrets Operator and a SecretStore/ClusterSecretStore separately.
`examples/external-secrets.yaml` maps two properties in a provider secret to the
native filenames and points `auth.existingSecret` at the synchronized target.
Wait for ExternalSecret Ready before considering the installation healthy.
Each item carries its complete spec; item refreshInterval overrides the block
default. Rotation still needs Pod replacement and client coordination.
Each ExternalSecret must have a unique rendered name, including after truncation.
Repeated or colliding names are rejected before resources are applied.

Fixtures under `ci/fixtures/` contain a deliberately public test identity. Never
use it for a deployed server. The runtime test uses a namespace-scoped fake store
so it does not modify shared provider credentials.

## Runtime privileges and exposure

Both binaries run as UID/GID 1000 with fsGroup 1000. Storage must support those
permissions. The chart does not run a root chown init container. The root
filesystem is read-only; data writes go to the mounted volume. All capabilities
are dropped and privilege escalation is disabled. Service account tokens are
not mounted by default.

Use network admission rules for office/VPN clients, monitor server logs and
resource consumption, and pin tested upstream updates. Version 1.1.16 includes
the upstream UDP reflection/amplification fix. HTTP TLS settings apply to
WebSocket ingress only and do not convert native listeners into HTTPS.
