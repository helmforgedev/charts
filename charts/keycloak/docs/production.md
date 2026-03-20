# Production Mode

## When to use it

Use `mode: production` for real reverse-proxy deployments where Keycloak is backed by an external database.

## What it delivers

- external database configuration
- explicit hostname and proxy modeling
- separated management service for health and metrics
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
- keep the management service internal
- document the reverse proxy behavior alongside the chart values
- use multiple replicas only when the shared database and cache expectations are understood
