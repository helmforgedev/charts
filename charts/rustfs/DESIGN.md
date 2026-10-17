<!-- SPDX-License-Identifier: Apache-2.0 -->
# RustFS chart design

A single StatefulSet implementation serves standalone and distributed modes.
Stable pod identities and per-pod claim templates keep storage ownership explicit.
Standalone accepts an existing claim or ephemeral storage; distributed requires
independent persistent claims and at least four members. Validation rejects
inconsistent combinations instead of silently changing the replica count.

The API Service balances ready members; the distributed console Service selects
ordinal zero. A separate headless Service publishes not-ready addresses for
bootstrap. All container ports are fixed independently of Service ports.

ConfigMap contents trigger rolling restarts through a checksum annotation.
Credentials use Kubernetes Secret references, with generated passwords reused
through Helm lookup. Existing Secrets are supported for GitOps and external
credential management. Credential updates require an explicit pod restart.

Local helpers preserve HelmForge naming, selector labels, and common metadata.
No external common library or chart dependencies are required. The chart is
experimental while multi-node failure scenarios and production storage drivers
remain unvalidated. Local k3d hook and PVC runtime scenarios have passed. Release signing metadata follows the repository publishing convention.

Official RustFS 1.0.1 sources document distributed endpoint configuration, health
checks, credential environment names, image user, writable directories, and logger
settings. The chart exposes console traffic through a dedicated Service.

## Cluster and replication setup

`cluster` is an alias for `distributed`; both generate the same peer URLs,
StatefulSet, independent PVCs, and ordinal-zero console selection. No storage
topology named `replication` is introduced, because replication is a relationship
between independently deployed stores.

An optional post-install/post-upgrade hook Job applies bucket or site replication
using the pinned official CLI. A regular ConfigMap supplies JSON configuration
and the packaged shell script; credentials mount from Secrets as read-only files.
The CLI writes its private config only to an ephemeral /tmp volume. Job pods omit
the storage name label so storage Services cannot route requests to setup pods.
The health test pod likewise does not match storage Service selectors. Both use
a shared auxiliary-label helper that preserves common labels and release metadata
while removing the storage name label. Pull secrets, ServiceAccount selection,
node selectors, tolerations, and security settings are shared across those pods.
The replication JSON and self-peer validation use one local-endpoint helper so
explicit and default Service endpoints follow the same validation rules.

Bucket setup preserves unrelated rules, updates known IDs, and rejects destination
changes. Site setup adds all peers together, then checks membership on retries.
Neither mode deletes remote state when chart settings are removed. The Job is a
bounded bootstrap/upgrade operation, not a controller or a replication health
monitor. Credentials and endpoint migrations require explicit operations.

Cluster internode RPC uses its own Secret, independent of S3 credentials. This
avoids relying on derived RPC authentication, which RustFS 1.0.1 rejects for the
default access-key case tested here. Generated keys are reused with Helm lookup;
existing RPC Secrets support GitOps and explicit credential ownership.

Helm health test pods use `before-hook-creation` cleanup so `helm test --logs` can
retrieve their logs. A subsequent test replaces the previous pod; operators can
delete retained test pods explicitly. Successful replication Jobs continue using
`hook-succeeded` cleanup because Helm only needs their completion status.

Generated resource base names are limited to 52 characters to accommodate the
StatefulSet revision label. Longer generated names retain a shortened prefix and
a stable hash of the full name to reduce collisions between releases. Explicit
fullnameOverride values keep truncation semantics; operators own their uniqueness.
Changing from the previous truncation scheme requires migration planning for
existing long-name releases and their PVCs.

CI scenarios declare external prerequisites through same-name files under
`ci/fixtures/`. These fixtures own their Secrets, existing data claim, and real
RustFS peer Deployments/Services. No CI replication endpoint depends on external
DNS or a public cluster. The runtime smoke script checks authenticated object
content after the setup hook and after upgrades; rendering alone is insufficient
evidence for replication behavior. Fixtures are isolated from release storage
selectors and are removed with the test namespace.
