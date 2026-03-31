# Scope and Automation Boundaries

## Why this guide exists

This chart aims to be production-aware without pretending to be a Keycloak operator.

It supports real production concerns such as:

- external database configuration
- public and admin ingress separation
- management health and metrics
- multi-replica cache wiring
- truststore and database TLS inputs
- controlled extension hooks

It does not attempt to own continuous Keycloak operations that require deeper control loops.

## HPA decision for the current chart scope

Horizontal Pod Autoscaling remains out of scope as a built-in chart feature for now.

Reasoning:

- Keycloak scaling is not only a CPU or memory decision
- session behavior depends on reverse-proxy affinity and login flow patterns
- startup and warm-up time matter more than in simpler stateless services
- scaling pressure is often constrained by the external database, not only by pod resources
- multi-replica behavior should stay explicit and intentional in this chart

This does not mean HPA is forbidden forever. It means the current chart does not expose it as a first-class feature until there is a stronger operational model for safe autoscaling.

## What remains outside this chart

The current chart does not deliver:

- operator-style cluster lifecycle management
- coordinated rolling strategies based on Keycloak-specific control loops
- automatic evaluation of sticky-session or ingress behavior
- automated realm reconciliation beyond startup import
- deep day-2 automation for extension lifecycle
- a built-in HPA contract

## Why this matters

If the chart exposed too many automation knobs without real control logic behind them, it would over-promise operational safety.

That is the wrong tradeoff for this repository.

The chart should stay:

- explicit
- predictable
- honest about what it manages

## Operator boundary

If future requirements include more of the following, the solution is probably moving toward operator territory:

- coordinated autoscaling tied to Keycloak-specific health and login behavior
- upgrade orchestration with stronger runtime safety guarantees
- ongoing cluster convergence and advanced cache topology control
- full reconciliation of realms, providers, and extensions over time
- deeper automation around external database dependencies

At that point, it is more honest to evaluate:

- a separate chart with materially different scope
- an operator-driven model
- or a documented platform pattern outside this chart

## Current recommendation

For the current chart:

- set `replicaCount` intentionally
- validate reverse proxy and sticky-session behavior explicitly
- treat multi-replica as a production architecture decision, not an autoscaling shortcut
- keep day-2 operational automation outside the chart unless the control model is genuinely implemented

<!-- @AI-METADATA
type: chart-docs
title: Keycloak - Scope
description: Chart scope and boundaries

keywords: keycloak, scope, boundaries

purpose: Chart scope definition and automation boundaries for Keycloak
scope: Chart Architecture

relations:
  - charts/keycloak/README.md
  - charts/keycloak/DESIGN.md
path: charts/keycloak/docs/scope-and-automation-boundaries.md
version: 1.0
date: 2026-03-20
-->
