# Extensions and Themes

## When to use this guide

Read this guide before mounting providers, themes, sidecars, or auxiliary init containers into the Keycloak pod.

## What this chart supports

The chart keeps extension workflows explicit:

- providers mounted into `/opt/keycloak/providers`
- themes mounted into `/opt/keycloak/themes`
- optional `initContainers`
- optional `extraEnvFrom`
- optional `extraContainers`

This is intentionally narrower than an operator-style build pipeline. The chart helps wire runtime mounts and controlled pod composition, but it does not pretend to own provider packaging or long-term extension lifecycle management.

## Providers and themes

Current supported inputs:

- `extensions.providers.existingConfigMap`
- `extensions.providers.existingSecret`
- `extensions.themes.existingConfigMap`
- `extensions.themes.existingSecret`

Use these when the content is already prepared by another pipeline or controller.

## Predictable rollouts

Kubernetes does not restart a Deployment automatically when the content of an externally managed Secret or ConfigMap changes.

To keep rollouts predictable, the chart exposes:

- `extensions.providers.rolloutToken`
- `extensions.themes.rolloutToken`

When the external provider or theme content changes, bump the matching rollout token in Helm values and perform a controlled upgrade.

Example:

```yaml
extensions:
  providers:
    existingSecret: keycloak-providers
    rolloutToken: providers-2026-03-19
  themes:
    existingConfigMap: keycloak-themes
    rolloutToken: themes-2026-03-19
```

## Controlled extensibility

For advanced cases, the chart exposes:

- `extraEnvFrom`
- `initContainers`
- `extraContainers`

Use these only when the runtime behavior is understood and documented by the team.

Recommended uses:

- `extraEnvFrom` for additional runtime configuration sources
- `initContainers` for one-time preparation steps
- `extraContainers` for well-defined sidecars such as log shippers or support tooling

## What not to assume

Do not assume this chart provides:

- provider build automation
- binary compatibility validation
- hot reload of provider or theme content
- operator-style orchestration of custom images

## Rollout checklist

- validate extension compatibility against the target Keycloak version
- update `rolloutToken` when externally managed provider or theme content changes
- perform a controlled rollout after changing providers, themes, or sidecars
- validate login flow, admin console, and any extension-specific behavior after rollout

## Example

```yaml
extensions:
  providers:
    existingSecret: keycloak-providers
    rolloutToken: providers-v2
  themes:
    existingConfigMap: keycloak-themes
    rolloutToken: themes-v3

extraEnvFrom:
  - configMapRef:
      name: keycloak-runtime-env

initContainers:
  - name: prepare-themes
    image: busybox:1.36
    command:
      - sh
      - -c
      - echo preparing mounted content

extraContainers:
  - name: support-sidecar
    image: busybox:1.36
    command:
      - sh
      - -c
      - tail -f /dev/null
```

<!-- @AI-METADATA
type: chart-docs
title: Keycloak - Extensions and Themes
description: Custom providers and themes

keywords: keycloak, extensions, themes, providers

purpose: Custom providers and themes configuration guide for Keycloak
scope: Chart Architecture

relations:
  - charts/keycloak/README.md
path: charts/keycloak/docs/extensions-and-themes.md
version: 1.0
date: 2026-03-20
-->
