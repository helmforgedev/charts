<!-- SPDX-License-Identifier: Apache-2.0 -->

# Security

The official WebODM and NodeODM images initialize as root. The chart documents
this exception, disables privilege escalation, applies RuntimeDefault seccomp,
drops all capabilities, and adds only the capabilities required by upstream
startup scripts. Service account token mounting is disabled.

NodeODM remains a ClusterIP Service and requires a generated token. Expose only
the WebODM Service. Use TLS at Ingress or Gateway, source production credentials
from existing Secrets or ESO, and restrict network paths with NetworkPolicy.

NetworkPolicy is enabled by default. It permits same-release communication,
cluster DNS, and HTTPS egress. Add `networkPolicy.ingressFrom` peers for the
Ingress controller or Gateway data plane and `networkPolicy.extraEgress` rules
for external PostgreSQL, Redis, OIDC, or object-storage endpoints. Policies
cannot portably select DNS names, so validate the resulting traffic on the
cluster's CNI rather than assuming a hostname is covered.

Helm can checksum the chart-rendered OIDC ConfigMap, but it cannot read data in
an externally managed Secret deterministically. After rotating an application,
OIDC, database, or Redis Secret, explicitly restart the consuming web, worker,
processing, and registration paths as applicable and wait for readiness. Avoid
printing Secret values in shell history or support output.

OIDC reduces local password use but does not replace provider-side MFA, client
secret rotation, or callback URI restrictions.
