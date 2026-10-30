<!-- SPDX-License-Identifier: Apache-2.0 -->
# Validation evidence

Validated on 2026-10-16 with Helm 3.17.3, official RustFS 1.0.1, and official
RustFS CLI v0.1.36. The CLI release tag and Docker Hub image tag were both checked.

## Static checks

- `./test.sh rustfs --skip-kubescape`: all nine checks passed, including strict
  Helm lint, eight CI render scenarios, strict kubeconform validation, 40 Helm
  unit tests, and Artifact Hub lint.
- Ten additional invalid cluster/replication configurations were rejected,
  covering missing peers/rules/secrets, invalid flags, reserved aliases, endpoint
  credentials, missing site endpoints, mixed site/bucket configuration, and
  invalid cluster storage/replica counts.
- Kubescape MITRE/NSA/SOC2 against the rendered cluster + bucket setup `.yaml`
  scored 89.09%. Remaining findings concern optional resource limits and network
  isolation. The repository helper's extensionless temporary scan file yielded
  "no resources found to scan", so this scan was performed separately.
- The packaged chart includes the setup script and RPC/replication templates.

## Container runtime scenarios

All scenarios used isolated Docker containers/network and disposable tmpfs data.
Application and CLI containers used UID/GID 10001, dropped capabilities, read-only
roots, and writable tmpfs volumes. The host rejected executable startup with
`no-new-privileges`, including a standalone `/bin/sh` invocation, so that option
was omitted from Docker smoke tests. The chart retains
`allowPrivilegeEscalation: false`.

- Standalone health/readiness and signed S3 bucket/object create/read/delete passed.
- A four-node cluster reported four online drives, an erasure backend, and parity
  two. An object written through node zero was read through node two with matching
  content. With one node stopped, reads and writes through a surviving node passed.
- Distributed startup required explicit shared RPC credentials with the default
  access key. The chart now supplies a dedicated shared RPC Secret. A bootstrap
  delay allowed all Docker aliases to exist; Kubernetes uses a headless Service
  publishing not-ready addresses and parallel StatefulSet startup.
- The packaged bucket setup script configured two standalone deployments. Running
  it again updated the same ID without creating a duplicate rule. A new object
  arrived at the destination with identical content.
- The site setup script linked two clean deployments, then reran successfully
  against the existing membership. Objects replicated in both directions with
  matching content.
- The bucket setup script also configured replication from the four-node cluster
  to a separate deployment; an object arrived with matching content.
- Runtime guard checks rejected a changed bucket destination and a changed site
  membership without replacing the existing replication configuration.

## Kubernetes runtime: Helm hooks and PVC

Validated on a disposable `k3d-rustfs-chart-tests` cluster using Kubernetes
`v1.31.5+k3s1`, Helm `3.17.3`, and the default `local-path` StorageClass. The
kubeconfig was isolated from the user's default configuration; the active context
was checked before installs. All test resources used namespace
`hf-rustfs-runtime`. Kubernetes pods ran with the chart's unmodified restricted
security contexts, including `allowPrivilegeEscalation: false`.

| Scenario | Result |
| --- | --- |
| Bucket post-install hook | Job reached Complete 1/1; source object replicated with identical content |
| Bucket post-upgrade hook | Job reached Complete 1/1; same rule ID updated to priority 2 and prefix archive/; no duplicate rule |
| Upgraded bucket data path | Object under archive/ replicated with identical content |
| Site post-install hook | Job reached Complete 1/1 and linked two fresh deployments |
| Site post-upgrade hook | Job reached Complete 1/1 against existing membership |
| Site data path | Objects replicated in both directions with matching content |
| Successful setup cleanup | Hook Jobs were deleted after Helm observed completion |
| Standalone pod replacement | Pod UID changed; PVC UID and bound PV stayed unchanged; original object read correctly |
| Four-member cluster storage | Four independent 1Gi PVCs Bound; S3 write through Service/read through a peer succeeded |
| Cluster uninstall retention | All four PVCs retained their original UIDs after helm uninstall |
| Cluster reinstall recovery | Same four PVC/PV bindings reused; stored object read with identical content |
| Existing claim reuse | A new standalone release mounted the retained target PVC and read the old replicated object; no new claim created |
| Helm health test | Standalone and cluster tests succeeded with logs; consecutive standalone test runs succeeded |

Runtime testing exposed a test-hook cleanup bug: deleting successful test pods
immediately made `helm test --logs` fail while retrieving logs, despite successful
health checks. The test hook now uses only `before-hook-creation`; completed pods
remain available for logs and are replaced on the next test run. The replication
Job retains its original successful-hook cleanup policy. A regression unit test
covers this distinction.

Final snapshots showed zero container restarts. Two transient readiness HTTP 503
warnings occurred during cluster initialization/recovery; all storage pods became
Ready. The disposable cluster and its test storage were removed after evidence
collection. Raw logs and resource snapshots were saved locally under
`/tmp/rustfs-runtime-evidence/`.

These tests use one local Kubernetes node and the local-path driver. They do not
validate multi-node scheduling, production CSI drivers, node loss, capacity
expansion, ingress traffic, backup/restore, or production durability. The chart
remains alpha pending broader environment coverage.

## Design consistency review

The follow-up review corrected the documented percentage PDB support in the
schema, invalid trailing-hyphen peer names, self-peer validation against the
generated local endpoint, and ignored existing claims with disabled persistence.
Auxiliary pods now retain common metadata without matching storage selectors;
Helm test pods inherit registry credentials, ServiceAccount, node selectors, and
tolerations. Six regression tests cover these contracts; one additional test covers runtime hook log retention. Invalid peer names and
out-of-range percentage budgets were also checked through Helm schema validation.

## StatefulSet name length regression

The resource base-name limit is 52 characters, reserving a hyphen plus up to ten
characters for the controller revision hash in pod labels (63 characters total).
Five regression tests cover long release names, fullnameOverride values, distinct
long releases sharing the same first 52 characters, exact-boundary names, and
short names. Long generated names include a stable eight-character SHA-256 suffix;
fullnameOverride retains its previous truncation behavior. All 40 unit tests and
the nine static checks passed after this change. On 2026-10-17, two valid
53-character release names sharing their first 52 characters were installed in
the same k3d namespace. They created distinct StatefulSets, both passed native S3
write/read checks, and their controller-revision-hash labels stayed within 63
characters. The test namespace was removed afterward.

## Merge-blocker follow-up: self-contained CI matrix (2026-10-17)

All eight `ci/*.yaml` scenarios plus default installation passed on the disposable
`k3d-helmforge-rustfs-ci` cluster (Kubernetes 1.31.5+k3s1, local-path storage).
The chart-local `scripts/validate-runtime.sh` applied same-name fixtures before
installation and used `scripts/runtime-smoke.mjs` for native data verification.

| Scenario | Runtime evidence |
| --- | --- |
| default | Helm health test and authenticated S3 content round trip |
| cluster-values | Fixture credentials; four Ready members and independent Bound PVCs; S3 content verified |
| distributed-values | Fixture credentials; default StorageClass instead of missing fast-ssd; four members and S3 content verified |
| ephemeral-values | Console disabled, emptyDir storage, Helm health and S3 content verified |
| existing-claim-values | Fixture PVC and custom credential keys; Helm health and S3 content verified |
| ingress-values | Ingress objects installed using cluster-default class; configured Service ports and S3 content verified |
| replication-bucket-values | Real RustFS peer; setup hooks on install and upgrade; one matching rule ID and matching remote object content on both runs |
| replication-site-values | Two real RustFS peers; setup hooks on install and upgrade; matching object content to both peers and reverse writes to source on both runs |
| standalone-values | Explicit chart-managed credentials; Helm health and S3 content round trip |

Every scenario passed `helm test --logs`; all application/fixture pods in final
snapshots had zero restarts. The installed NOTES ended with `Happy Helmforging :)`.
The source NOTES includes an SPDX header in its first five lines. All sixteen
fixture resources passed strict kubeconform. Forty Helm unit tests and the nine
public static checks passed; a separate default-manifest Kubescape scan scored
88.89%, now recorded in the README's repository-format Security Scan section.
The final runner completed with exit code 0 and PASS all 9 runtime scenarios.
Raw matrix evidence is under `/tmp/rustfs-ci-runtime-final-evidence/`; the aggregate
log is `/tmp/rustfs-ci-runtime-final.log`. Long-name regression evidence is under
`/tmp/rustfs-ci-runtime-evidence/long-name-*`. Test namespaces and the disposable cluster
were removed after evidence collection. Ingress routing, production CSI drivers,
and multi-node failures remain outside this local matrix's coverage.

### Private full gate remains unavailable

A full search, including hidden and ignored files, found no Makefile or
`validate-chart` target in this checkout. Repository docs and
`.githooks/pre-push` identify `helmforgedev/helmforge-ops` as the owner of the
maintainer tooling; `.github/workflows/standards-check.yml` explicitly checks out
that private repository using OPS_AUTOMATION_TOKEN. There is no local ops checkout
or HELMFORGE_OPS_DIR, and the current GitHub account receives Repository not found
when querying the private repository.

`make validate-chart CHART=rustfs` was attempted and failed with No rule to make
target. The chart-local matrix above is successful end-to-end evidence, but is
not reported as a successful run of that private target or standards guard.
A maintainer with access must rerun those gates against the updated revision.
