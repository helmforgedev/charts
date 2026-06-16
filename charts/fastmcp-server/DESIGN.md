<!-- SPDX-License-Identifier: Apache-2.0 -->

# FastMCP Server Chart Design

## Purpose

The `fastmcp-server` chart deploys a single FastMCP HTTP server that exposes
tools, resources, prompts, and knowledge files through the MCP endpoint. The
chart is optimized for platform-owned MCP servers where the runtime image stays
pinned and the deployer supplies MCP content from one or more controlled
sources.

## Workload Model

The chart renders one `Deployment` by default. Autoscaling can delegate replica
count to an HPA, but the deployment strategy remains `Recreate` because the
workspace can be backed by a ReadWriteOnce PVC and source synchronization should
not race across rolling pods that share the same release identity.

The server container always mounts `/app/workspace`. That mount is an
`emptyDir` by default and becomes a PVC when `persistence.enabled=true`.
Inline sources are mounted read-only from separate ConfigMaps:

- `sources.inline.tools` -> `/app/inline/tools`
- `sources.inline.resources` -> `/app/inline/resources`
- `sources.inline.prompts` -> `/app/inline/prompts`
- `sources.inline.knowledge` -> `/app/inline/knowledge`

The pod receives checksum annotations for inline source maps so ConfigMap
changes trigger a rollout.

## Source Loading Contract

The chart exposes the application source contract without trying to parse or
validate user Python modules:

- Inline content is rendered into Kubernetes ConfigMaps.
- S3-compatible sources are enabled with `sources.s3.enabled=true`.
- Git sources are enabled with `sources.git.enabled=true`.
- `initSync.enabled=true` runs `/app/sync_only.py` before the main container.

Merge precedence is documented as inline content first, then S3, then Git. That
precedence is an application contract; the chart's responsibility is to mount
and pass the source locations and credentials consistently.

## Secret Handling

The chart can either reference existing secrets or create release-scoped
secrets from values:

- bearer auth uses `<fullname>-auth` unless `auth.bearer.existingSecret` is set;
- S3 credentials use `<fullname>-s3` unless `sources.s3.existingSecret` is set;
- Git tokens use `<fullname>-git` unless `sources.git.existingSecret` is set.

Production deployments should prefer existing secrets from a secret manager or
External Secrets workflow. Inline credentials are mainly for CI and local
evaluation.

## Network Exposure

The Service exposes the configured HTTP port and defaults to ClusterIP.
Ingress and Gateway API are both opt-in. The Gateway API template requires at
least one `parentRef` when enabled because the chart intentionally references a
platform-owned Gateway instead of creating one.

The chart supports dual-stack Service fields through `service.ipFamilyPolicy`
and `service.ipFamilies`. These fields are empty by default so clusters keep
their own Service IP-family policy.

## Security Posture

Defaults disable service account token automount and run the container as
non-root UID/GID `1000` with privilege escalation disabled, all Linux
capabilities dropped, and the runtime default seccomp profile. The root
filesystem remains writable because the image installs optional
`extraPipPackages` and maintains `/app/workspace` content at runtime.

NetworkPolicy is opt-in. When enabled, it constrains ingress to the configured
server port. Egress remains unrestricted because Git, S3-compatible object
stores, JWKS endpoints, and package indexes are environment-specific.

## Validation Strategy

The chart carries CI scenarios for the default install, bearer auth, inline
content, S3, Git, Gateway API, and full production-style values. Unit tests
cover rendered objects, source ConfigMaps, secrets, probes, security context,
ServiceMonitor, HTTPRoute, ingress, HPA, PDB, and NOTES behavior.
