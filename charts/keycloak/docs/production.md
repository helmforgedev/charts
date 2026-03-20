# Production Mode

## When to use it

Use `mode: production` for real reverse-proxy deployments where Keycloak is backed by an external database.

## What it delivers

- external database configuration
- explicit hostname and proxy modeling
- separated management service for health and metrics
- optional separate public and admin ingresses
- optional multi-replica runtime
- optional realm import
- optional providers and themes mounting

## What it does not deliver

- bundled production database
- operator-style realm reconciliation
- management ingress exposure

## Best practices

- always configure `hostname.hostname`
- prefer a separate admin hostname when operationally possible
- use a separate admin ingress when the admin console must use a different ingress class or an internal load balancer policy
- keep the management service internal
- document the reverse proxy behavior alongside the chart values
- use multiple replicas only when the shared database and cache expectations are understood
- review [Reverse Proxy and Hostname](reverse-proxy.md) before exposing the chart
- review [Scaling and Clustering](scaling-and-clustering.md) before increasing replica count
- review [Security and Trust](security-and-trust.md) when database TLS or private CAs are involved
- review [Extensions and Themes](extensions-and-themes.md) before mounting providers, themes, or sidecars
- review [Scope and Automation Boundaries](scope-and-automation-boundaries.md) before treating the chart like an operator or autoscaling control plane
- review [Production Capacity](production-capacity.md) before choosing explicit `resources` and `priorityClassName`

## Operational notes

- production mode assumes the reverse proxy is part of the deployment design, not an optional add-on
- the public ingress and the admin ingress both route to the application service only
- the management interface remains internal even when both ingresses are enabled
- a safe production rollout validates hostname resolution, login flow, admin access, and health endpoints together
- external secret and truststore rotation require a controlled rollout plan
- HPA is intentionally not modeled by the current chart scope
- `hostname.admin` must be set when the admin ingress is enabled in production mode
