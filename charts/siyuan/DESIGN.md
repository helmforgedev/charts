# SiYuan design

## Single-writer architecture

SiYuan is a personal workspace kernel with an embedded index and document files. Exactly one writer is allowed,
regardless of storage access mode. Recreate prevents rolling overlap. A singleton PDB would obstruct maintenance, and
HPA cannot safely scale this architecture.

## Restricted image startup

The official entrypoint creates accounts and recursively chowns directories as root. The chart directly invokes
/opt/siyuan/kernel serve with an explicit workspace. UID/GID/fsGroup 1000 provide access to the claim. The image root
stays read-only; HOME and temporary paths are separate emptyDir mounts. Complete workspace configuration and custom
appearance data persist in the claim.

## Authentication and OIDC

Native access-code environment configuration uses a generated retained Secret or an existing Secret. The code is never a
command-line argument. OIDC client credentials are separate Secret references. Exact claim admission defaults are
required; the opt-in allowAll value is explicit. Both login methods grant administration of the same personal workspace.
Local access-code recovery remains enabled.

The test-only Node sidecar implements discovery/JWKS, one-use codes, client authentication, PKCE and signed ID tokens.
The client test exercises the native callback from the pod's loopback network, as required by the upstream local HTTP
exception. Production callbacks remain HTTPS. The fixture is not a production identity provider.

## Readiness and networking

A version endpoint alone does not prove initialization finished. Startup and readiness inspect bootProgress JSON and
require 100. Liveness uses the version endpoint without external dependencies. NetworkPolicy permits DNS plus explicit
outbound endpoints, and separates ingress peers from outgoing service access.

## Recovery and upgrades

Backup covers the whole workspace after graceful shutdown. The runtime gate archives and restores it into a new PVC and
then deploys through existingClaim. This proves data and authentication recovery, not only volume attachment. Rollbacks
involving storage-format changes require a compatible backup. Encryption passwords remain external recovery
requirements.

## Observability boundary

No native Prometheus contract was found for this release. The chart uses logs, Kubernetes health and documented external
workload/PVC/HTTP monitoring. It does not expose a fictitious /metrics endpoint or unrelated database exporter.

<!-- @AI-METADATA
 type: guide
 title: SiYuan design
 description: Product-specific runtime and recovery design
 keywords: siyuan, design, oidc, storage
 purpose: Explain chart architecture and limits
 scope: chart
 path: charts/siyuan/DESIGN.md
 version: 1.0
 date: 2026-09-10
-->
