<!-- SPDX-License-Identifier: Apache-2.0 -->
# Security

## Workload Identity

The Countly and backup pods use the chart ServiceAccount with
`automountServiceAccountToken: false`. Enable token mounting only when a
deliberate extension needs Kubernetes API access.

## Upstream Root Exception

The pinned official combined image starts `/sbin/my_init` as root and then uses
`setuser countly` for the Node.js processes. Forcing `runAsNonRoot` or dropping
all capabilities at the Kubernetes container boundary breaks that supported
entrypoint. The chart instead disables privilege escalation and applies
`RuntimeDefault` seccomp. Init and backup containers use a stricter non-root,
read-only policy.

Re-evaluate the exception whenever the image changes. Do not treat it as a
general exemption for other workloads.

## Credentials

- Prefer `externalMongodb.existingSecret` over an inline URI.
- Prefer `backup.s3.existingSecret` over inline object-store keys.
- Use External Secrets when the cluster already has a managed secret provider.
- Restrict Secret RBAC and rotate MongoDB and object-store credentials.
- Remember that direct values are stored in Helm release Secrets.

## Network Boundaries

The default NetworkPolicy admits both Countly ports from cluster sources and
permits all egress for plugin compatibility. Production policy should narrow:

- dashboard ingress to trusted proxies or operator namespaces;
- API ingress to approved gateways or in-cluster applications;
- egress to cluster DNS, MongoDB, mail, push, webhooks, and other enabled plugin
  destinations;
- backup egress to MongoDB, DNS, and the object-store endpoint.

Test every enabled plugin after tightening policy.

## Public Exposure

Terminate TLS at the Ingress, Gateway, or external load balancer. Keep the
dashboard private where possible. Apply rate limiting and request-size limits at
the edge, and expose the ingestion API only to the client populations that need
it.
