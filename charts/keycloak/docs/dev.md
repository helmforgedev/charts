# Dev Mode

## When to use it

Use `mode: dev` for:

- local validation
- temporary review environments
- quick bootstrap testing

## What it delivers

- single Keycloak Deployment
- local development database through `start-dev`
- optional realm import
- optional ingress

## What it does not deliver

- production-grade database handling
- production hostname guarantees
- HA behavior

## Best practices

- keep `replicaCount: 1`
- treat dev mode as disposable
- use it for bootstrap and integration validation, not for long-lived production traffic

<!-- @AI-METADATA
type: chart-docs
title: Keycloak - Dev Mode
description: Development mode setup

keywords: keycloak, dev, development

purpose: Development mode setup guide for Keycloak chart
scope: Chart Architecture

relations:
  - charts/keycloak/README.md
  - charts/keycloak/docs/production.md
path: charts/keycloak/docs/dev.md
version: 1.0
date: 2026-03-20
-->
