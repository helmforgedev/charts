# Security

The official WebODM and NodeODM images initialize as root. The chart documents
this exception, disables privilege escalation, applies RuntimeDefault seccomp,
drops all capabilities, and adds only the capabilities required by upstream
startup scripts. Service account token mounting is disabled.

NodeODM remains a ClusterIP Service and requires a generated token. Expose only
the WebODM Service. Use TLS at Ingress or Gateway, source production credentials
from existing Secrets or ESO, and restrict network paths with NetworkPolicy.

OIDC reduces local password use but does not replace provider-side MFA, client
secret rotation, or callback URI restrictions.
