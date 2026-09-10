# Widgets, configuration and network boundaries

## Declarative dashboard

config.data accepts the native Glance pages, theme, branding and document settings.
The auth and server sections are reserved so they cannot contradict chart ports
or bypass native login accidentally. Arrays such as pages are replaced during
values merging; supply a complete page list when overriding the default dashboard.
Configuration is mounted as a directory, without subPath, and a Helm-managed
ConfigMap change triggers a Deployment rollout through a checksum.

## Literal widget templates

Custom API widgets use Go templates that look like Helm template delimiters.
This chart intentionally does not call tpl on config.data. An expression such as
`{{ .JSON.String "value" }}` reaches Glance unchanged. The functional CI fixture
renders a known JSON value through this path and verifies the output.

## Secret-backed feeds

widgetSecrets.sources projects selected keys from existing Kubernetes Secrets into
/run/secrets. Use the upstream secret-file interpolation in the configuration:

~~~yaml
widgetSecrets:
  sources:
    - name: glance-integrations
      items:
        - key: github-token
          path: github-token
config:
  data:
    pages:
      - name: Releases
        columns:
          - size: full
            widgets:
              - type: releases
                token: ${secret:github-token}
                repositories:
                  - glanceapp/glance
~~~

The auth-password and auth-signing-key filenames are reserved. Mount only the
keys a widget needs. Do not put credentials into assets.existingConfigMap: assets
are deliberately served as public static content and are not a secret store.

## Egress

The default NetworkPolicy allows DNS and TCP ports 80/443 for feed retrieval.
Restrict webEgress CIDRs for an intranet-only dashboard. Add extraEgress for
internal APIs using other ports and restrict the matching destination as well.
Application egress rules do not control a user's browser fetching remote images.
Do not infer offline operation from a deny-egress pod policy.

## Proxy trust and subpaths

Enable server.proxied only when the Service is reachable through trusted peers.
Restrict networkPolicy.ingressFrom to the actual ingress controller namespace and
pod selector. The namespace field alone is not a guarantee that every pod there
is trusted. For server.baseUrl=/glance, configure the proxy to remove /glance
before forwarding. The chart does not silently install controller-specific rewrite
annotations or claim that a PathPrefix match performs rewriting.

## Docker widgets

This chart never mounts /var/run/docker.sock. A dashboard does not require host
daemon control. If Docker widgets are needed, provide a separately authenticated,
restricted proxy that exposes only the necessary read operations, with appropriate
network rules. Kubernetes API credentials are likewise not mounted by default.

<!-- @AI-METADATA
type: guide
title: Glance docs/widgets-and-network
description: Product-specific Glance deployment and operation contract
keywords: glance, helm, authentication, widgets, kubernetes
purpose: Operate the Glance chart safely
scope: charts/glance
-->
