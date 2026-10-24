<!-- SPDX-License-Identifier: Apache-2.0 -->
# Flowise security

## Container and pod controls

The official 3.1.3 image has no default user, but includes the `node` account as
UID/GID 1000. The chart sets that identity explicitly, uses RuntimeDefault
seccomp, drops all capabilities, prevents privilege escalation, and makes the
root filesystem read-only. Writable state is limited to the data mount and
`/tmp`. Backup containers use the same baseline.

The dedicated ServiceAccount does not receive a Kubernetes API token by
default. Enabling token mounting should be paired with a narrowly scoped RBAC
role; the chart itself does not require Kubernetes API access.

## Secrets

Use existing Kubernetes Secrets or External Secrets Operator for authentication,
database, Redis, S3, and backup credentials. Inline secret values are rendered
into Kubernetes Secrets but still appear in Helm release values. Avoid them in
production and avoid committing secret-bearing values files.

## Network access

NetworkPolicy isolates main and worker pods. Only main pods receive the Flowise
listener; worker ingress is denied. Egress remains open by default because
Flowise contacts user-selected model providers and tool endpoints. A restricted
egress policy must include DNS, databases, Redis, S3, model APIs, and any tools
used by chatflows.

## Flowise application risk

Flowise administrators can configure nodes that run code, fetch URLs, or start
custom MCP tools. Keep `HTTP_SECURITY_CHECK`, `PATH_TRAVERSAL_SAFETY`, and
`CUSTOM_MCP_SECURITY_CHECK` enabled. Prefer the `sse` custom MCP protocol and do
not allow commands or environment variables that are not required. Restrict
administrative access with authentication, TLS, and an identity-aware proxy
when appropriate.

Do not place broad cloud credentials, host sockets, or cluster-admin tokens in
the pod. Kubernetes isolation reduces blast radius but does not turn Flowise
into a safe multi-tenant code-execution sandbox.
