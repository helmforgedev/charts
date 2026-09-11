# Papra design

## Durable pending tasks

The native libSQL queue uses a separate local tasks.sqlite inside the existing db directory, so consistent whole-state
archives include pending extraction work even with a remote application database. Web-only mode pauses consumption for
maintenance and deterministic recovery testing. The chart does not claim retries or stale-processing recovery absent
from the pinned queue library. Queue metadata remains plaintext independently of application database encryption.

The unchanged upstream image remains responsible for native migrations, authentication, document storage and extraction.
The chart supplies explicit Kubernetes ownership, protected initialization, retained credentials and durable mount
points.

The initial-user endpoint grants the first user administrative permissions asynchronously. An init container starts the
native server on loopback, creates the account, verifies the actual permissions and terminates it before the public
process starts. A successful read-only user-count query after strict migrations prevents reinitialization of existing
deployments; query errors cannot be interpreted as an empty database. The public process always disables first-user
privilege grants.

One Recreate writer avoids assuming that remote SQL alone makes all native jobs, migrations and document processing safe
for concurrent replicas. The chart exposes SQLite/libSQL because those are the actual supported database contracts.

Encryption keys have separate lifecycles: the session secret preserves authentication, the local database key unlocks
its file, and the versioned document key ring unwraps original-file encryption keys. None is treated as a disposable
startup value. Existing Secrets and External Secrets support keep key custody outside Helm values when required.

The read-only image receives writable PVC, temporary and home directories. Neither root ownership repair nor a runtime
package installation is required. Explicit environment fields take precedence over advanced envFrom configuration.

Observability follows verified upstream endpoints. Application health and platform monitoring are provided without
inventing a native Prometheus exporter. TLS CA bundles extend trust rather than suppress certificate verification.
