# Compatibility

## Supported Matrix

| CRD chart | Envoy Gateway chart | Envoy Gateway | Gateway API | Channel | Kubernetes |
| --- | --- | --- | --- | --- | --- |
| 1.x | Bridge release for v1.9 | v1.9.0 | v1.6.1 | Experimental | 1.33-1.36 |

The exact application chart version is workflow-generated when the bridge
release is published. Do not select compatibility using chart version ordering
alone; inspect `appVersion` and this matrix.

## Required CRDs

Gateway API:

- `backendtlspolicies.gateway.networking.k8s.io`
- `gatewayclasses.gateway.networking.k8s.io`
- `gateways.gateway.networking.k8s.io`
- `grpcroutes.gateway.networking.k8s.io`
- `httproutes.gateway.networking.k8s.io`
- `listenersets.gateway.networking.k8s.io`
- `referencegrants.gateway.networking.k8s.io`
- `tcproutes.gateway.networking.k8s.io`
- `tlsroutes.gateway.networking.k8s.io`
- `udproutes.gateway.networking.k8s.io`

Envoy Gateway extensions:

- `backends.gateway.envoyproxy.io`
- `backendtrafficpolicies.gateway.envoyproxy.io`
- `clienttrafficpolicies.gateway.envoyproxy.io`
- `envoyextensionpolicies.gateway.envoyproxy.io`
- `envoypatchpolicies.gateway.envoyproxy.io`
- `envoyproxies.gateway.envoyproxy.io`
- `httproutefilters.gateway.envoyproxy.io`
- `securitypolicies.gateway.envoyproxy.io`

## Provider-Managed Gateway API

A provider-managed Gateway API is supported only after the operator verifies
its bundle version, channel, and required served GVKs. Leave those CRDs with the
provider and install only the Envoy Gateway extension bundle.

The default HelmForge contract is v1.6.1 Experimental. A Standard bundle does
not contain the complete Experimental API surface and must not be treated as an
equivalent full bundle.

## Unsupported Combinations

- Envoy Gateway v1.9 with Gateway API v1.5.1.
- Kubernetes earlier than 1.33 or later than 1.36 without a separately tested
  compatibility decision.
- Mixed Standard and Experimental Gateway API CRDs.
- Unknown or newer Gateway API bundle versions.
- Automatic rollback to an older CRD schema.
