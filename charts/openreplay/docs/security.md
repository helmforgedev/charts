<!-- SPDX-License-Identifier: Apache-2.0 -->

# Security

All application and supporting images are pinned by tag and manifest digest.
OpenReplay application images are official but were not verifiably Cosign
signed and do not publish an SBOM. BuildKit provenance exists but is incomplete,
so digest pins are the primary immutability control.

The chart disables service-account token automounting, selects amd64 nodes,
drops Linux capabilities, enables RuntimeDefault seccomp, and runs application
containers as their upstream non-root users. Read-only root filesystems are not
applied blindly because several upstream services require writable runtime
paths; hardening them requires component-specific runtime tests.

NetworkPolicy is opt-in because external database and object-store networks are
cluster-specific. When egress restriction is enabled, add explicit peers or
complete rules through `extraTo` and `extraEgress`.

Do not store credentials in values committed to source control. Use an existing
Secret or the External Secrets Operator contract. Rotate API/JWT and data-store
credentials as one planned maintenance operation because all components share
the application Secret.

Application and RustFS pod templates include a checksum of the credential key contract so changes to Secret names or key
mappings trigger a rollout. Changes to the data of an externally managed Secret do not change Helm-rendered manifests;
after rotating external Secret data, perform a controlled rollout and verify every dependent component.

The upstream v1.28 API and Chalice images had high-severity dependency findings
in the validation-date scan. Track patched upstream component digests and do not
claim the absence of vulnerabilities merely because Alpine OS packages were
clean in that snapshot.
