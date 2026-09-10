# Ryot design

## Native image and process lifecycle

The official image combines a Rust backend, React Router frontend and Caddy under the upstream process supervisor. The
chart preserves that entrypoint. Replacing it with the backend alone would remove the UI and proxy behavior. The image's
Caddy binary carries file capabilities that conflict with dropping all process capabilities. A non-root init container
copies the identical binary into an emptyDir without extended capability metadata; the main container mounts that copy
read-only at the original path. No privilege is added and the binary is not modified.

The release backend uses relative `tmp`, unlike its debug build's `/tmp`. The chart mounts `/home/ryot/tmp`, `/tmp` and
a separate runtime home without masking `/home/ryot/build` or node_modules. Writable volumes have explicit size limits.
Native backend listeners stay on loopback; NetworkPolicy exposes only the Caddy service port.

## Identity and bootstrap

The native registration endpoint supports an administrator override. A nonempty retained token closes the empty-token
bypass while registration remains disabled. A same-image Node helper starts only the Rust backend on loopback, creates
the initial user through native registration and verifies its administrator role through native login. It does not write
password hashes or user rows directly. Interrupted registration may verify the same already-created account; it never
resets a password or silently promotes an unrelated account.

Before bootstrap, the official PostgreSQL client performs read-only admission. Existing users suppress first-user
initialization. OIDC-linked accounts block deployment because the pinned upstream release's subject-only login accepts
unproven identity input. A disposable owned-account regression reproduced this behavior and the admission rejection. S3
is also disabled because native storage resolvers lack authorization and ownership checks. These are explicit
supported-feature boundaries, not claims that the chart repairs upstream code.

## Database and recovery

The maintained HelmForge PostgreSQL subchart supplies its actual writable Service, Secret and password key through
subchart helpers. Required extensions are created by its first-boot administrator script; Ryot uses the application
role. URI credentials are encoded into a mode-0600 memory file, avoiding plaintext rendered DSNs and process arguments.
External components default to verified TLS and support a read-only private CA bundle.

One scheduler avoids duplicate in-memory jobs and includes Recreate downtime. PostgreSQL stores durable state; temporary
import files are not durable attachments. Recovery uses pg_dump/pg_restore into a separate empty database and validates
retained identity and tracking content. It does not imply database failover or preservation of in-flight memory jobs.

## Operational boundaries

Ingress, Gateway API, dual-stack Services and External Secrets use the repository's common contracts. The chart does not
invent a Prometheus endpoint; database monitoring belongs to the maintained dependency. Additional provider API
credentials can use Secret-backed environment references with explicit network peers. SMTP remains outside runtime
delivery evidence because its native test swallows transport errors and its pinned Rust TLS stack requires trusted
public roots on implicit TLS port 465.
