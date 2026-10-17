<!-- SPDX-License-Identifier: Apache-2.0 -->
# Operations

Keep a backup outside the cluster and verify restores. Kubernetes PVC retention
is not a backup. Confirm StorageClass capacity, reclaim policy, and failure-domain
placement before installation. Log storage is ephemeral.

Before an upgrade, read the RustFS release notes and render the new chart with
the same values. Do not change endpoint topology, replica count, or claim layout.
Run `helm test <release> -n <namespace> --logs` after installation and upgrades;
it checks the API health endpoint, not an authenticated S3 write/read cycle.
Test pods remain for log retrieval and are replaced on the next test run. Delete
retained test pods explicitly when removing a release.

For credentials rotation, update the existing Secret, then run
`kubectl rollout restart statefulset/<release>-rustfs -n <namespace>`.
All distributed members must receive the same credentials. Plan a maintenance
window and follow upstream rotation guidance.

If distributed pods do not start, check PVC binding and permissions, pod DNS
resolution through the headless Service, network access to peer port 9000, and
matching credentials. If the console is unavailable while API traffic works,
inspect pod zero. No external ingress is needed for intra-cluster communication.

Run `./test.sh rustfs` for static validation. Runtime testing must target a clearly
local `k3d-` context. A multi-node S3 round trip and data persistence across pod
restart should be validated before production use.

## Replication operations

Use one release to configure each site relationship. Prepare reachable endpoints
and existing credential Secrets before installation. Inspect the setup Job logs
on failure; its name is `<release>-rustfs-repl`. A Helm timeout does not prove the
remote mutation failed, so inspect replication state before retrying.

Check bucket rules with `rc replicate list local/<bucket>` and verify objects at
the destination. Check sites with `rc admin replicate info local` and
`rc admin replicate status local` from every site. Test an actual object round trip;
successful setup or status output alone does not verify ongoing data replication.

Rule destination changes and site membership changes are rejected by setup for
manual migration. Removed values and release uninstall leave remote configuration
intact. Apply explicit upstream remove/edit commands when changing those
relationships. Review server-side target credentials when rotating a peer Secret.

## Validated PVC lifecycle

Local k3d testing confirmed standalone data survives pod replacement, distributed
claim templates retain four independent claims after Helm uninstall, and a new
installation with the same release name reuses those claims and reads stored
objects. Existing-claim mode was also tested by attaching a retained standalone
claim to a new release. These results used the local-path StorageClass; verify the
same lifecycle with your production CSI driver before deployment.

## Long resource names

Resource base names are capped at 52 characters to reserve space for the
StatefulSet controller revision hash in pod labels. Generated names longer than
52 characters use up to 43 prefix characters plus a hyphen and eight characters
from the SHA-256 hash of the full generated name. This keeps different long
release names distinguishable and naming deterministic. Generated names that fit
remain unchanged; explicit fullnameOverride values retain truncation to 52
characters and remain the operator's responsibility for uniqueness.

If upgrading from a revision that truncated generated names without hashing, a
raw <release>-<chart> name longer than 52 characters now changes the generated
resource and claim names, even when the old truncated name was already 52 characters. Plan an explicit data migration before upgrading;
do not assume the renamed StatefulSet will attach the old claims automatically.
