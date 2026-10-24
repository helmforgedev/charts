<!-- SPDX-License-Identifier: Apache-2.0 -->
# Open WebUI security

## Default controls

The chart enables the following controls without requiring application changes:

- a dedicated ServiceAccount with token automount disabled;
- `RuntimeDefault` seccomp for application and backup pods;
- privilege escalation disabled and all Linux capabilities dropped;
- ingress isolation to the named HTTP port;
- generated or existing Kubernetes Secrets for sensitive values;
- a stable generated session key retained across upgrades;
- pinned official application and utility image tags;
- fail-fast validation for ambiguous credential sources.

## Upstream image exception

The official Open WebUI image declares UID 0 and expects writable application
and home paths. The chart therefore does not enable `runAsNonRoot` or
`readOnlyRootFilesystem` by default. Enabling those controls without validating
the exact image can prevent model caching or application startup.

An operator-built compatible image may override `podSecurityContext` and
`securityContext`. Validate cold startup, upgrades, model downloads, uploads,
and backup jobs before adopting stricter values.

## Credential handling

Use existing Secrets for production credentials. Inline values are convenient
for evaluation but can remain in Helm release metadata and command history.
Limit access to both Helm releases and Kubernetes Secrets with RBAC.

Rotate the Open WebUI session key only during a planned authentication event;
changing it invalidates active sessions. Ensure every restored installation uses
the intended key rather than accidentally generating a new identity boundary.

## Network boundary

The default policy isolates inbound traffic but permits egress. Open WebUI may
connect to model APIs, Ollama, identity providers, object storage, and package
hubs chosen by the operator. In regulated environments, replace the egress rule
with explicit DNS and destination rules supported by the cluster CNI.

NetworkPolicy does not replace TLS or application authorization. Terminate TLS
at a trusted ingress, protect provider endpoints, and restrict direct Service
access according to the environment threat model.

## Initial administrator enrollment

The first account can become the administrator. Do not expose a fresh instance
publicly before enrollment controls are in place. Prefer private ingress or a
temporary port-forward, create the administrator, configure authentication, and
then open the intended route.

## Data protection

Conversation history, uploaded documents, embeddings, provider credentials, and
database backups may contain sensitive data. Apply storage encryption, object
retention, backup access control, and deletion policies that match the data
classification. Verify what external model providers retain before sending
prompts or documents.

## Supply chain and upgrades

The chart pins image tags but tags are not immutable digests. Verify upstream
release provenance and vulnerability scan results as part of the release
process. Back up data and review upstream security notices before upgrades.

Do not install plugins, functions, Python packages, or system packages at pod
startup. Build and scan a derived image when runtime extensions are required.
