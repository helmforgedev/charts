---
title: Vaultwarden - Scope
description: Chart scope and boundaries
keywords: [vaultwarden, scope, boundaries]
scope: chart-docs
audience: users
---

# Scope and Automation Boundaries

## What this chart is

This chart is a pragmatic Vaultwarden deployment for Kubernetes with:

- one application replica
- persistent `/data`
- explicit database-mode selection
- ingress, SMTP, admin access, and restore guidance

It aims to make the operational boundary clear, not to automate every lifecycle concern.

## What this chart is not

This chart is not:

- an HA Vaultwarden platform
- a multi-replica application manager
- a database operator
- a complete backup platform
- an identity integration platform

That means some responsibilities stay outside the chart on purpose.

## Boundaries kept outside the chart

### High availability

The chart does not attempt multi-replica Vaultwarden orchestration.

If you need stronger availability, solve that as a broader architecture question, not as a hidden extra value in this chart.

### Continuous backup automation

The chart documents backup and restore, but it does not embed a full backup scheduler.

That responsibility is better handled by:

- a separate backup release
- platform-native snapshots
- or database-native backup tooling

### Full SSO/OIDC lifecycle modeling

The chart documents SSO/OIDC as an advanced integration topic, but it does not expose every SSO variable as first-class values.

That keeps the core chart smaller and avoids pretending that identity integration is trivial.

### Database lifecycle management

The chart supports:

- `sqlite`
- `external`
- `postgresql`
- `mysql`

But it does not try to automate everything around:

- database upgrades
- PITR
- major-version migration orchestration
- failover
- long-running operational workflows

## Why this boundary is intentional

Vaultwarden is simple to deploy but easy to overcomplicate.

If the chart grows into:

- app runtime manager
- backup orchestrator
- IdP integration system
- database control plane

it stops being predictable and becomes harder to operate honestly.

## Future evolution

These boundaries are about current chart scope, not a permanent ban on future work.

If a future requirement proves valuable and coherent, it can be added by:

- a clearly scoped v3/v4 expansion
- a companion chart
- or a separate operational solution outside this chart

## References

- Vaultwarden repository: https://github.com/dani-garcia/vaultwarden
- Vaultwarden configuration template: https://raw.githubusercontent.com/dani-garcia/vaultwarden/main/.env.template

<!-- @AI-METADATA
type: chart-docs
title: Vaultwarden - Scope
description: Chart scope and boundaries

keywords: vaultwarden, scope, boundaries

purpose: Chart scope definition and automation boundaries for Vaultwarden
scope: Chart Architecture

relations:
  - charts/vaultwarden/README.md
  - charts/vaultwarden/DESIGN.md
path: charts/vaultwarden/docs/scope-and-automation-boundaries.md
version: 1.0
date: 2026-03-20
-->
