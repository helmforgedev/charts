# JupyterHub Networking

## Ingress

Use `ingress.ingressClassName` to select the ingress controller. Public Ingress requires a secure authenticator configuration or an explicit dummy-auth opt-in for local testing.

## Gateway API

Use `gateway.enabled=true` and set `gateway.parentRefs` to the Gateway that should serve JupyterHub traffic.

## NetworkPolicy

Enable `networkPolicy.enabled=true` to restrict Hub, proxy, and single-user notebook traffic to the expected paths.
