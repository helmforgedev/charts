<!-- markdownlint-disable MD013 MD034 -->

# Bulwark Mail research

## Request

- Issue: https://github.com/helmforgedev/charts/issues/1358
- Upstream: https://github.com/bulwarkmail/webmail
- Target: Bulwark 1.11.2

## Runtime findings

Bulwark full edition is a Next.js application listening on port 3000. The official image runs as UID/GID 1001 and publishes `/api/health`. Mutable data is split upstream into settings, admin configuration, admin runtime state, telemetry, and version-check storage below `/app/data`.

JMAP traffic is not wholly proxied through the Bulwark pod. The configured URL must be reachable by the browser, and cross-origin deployments require credentialed CORS. Stalwart remains an external dependency.

## Existing charts

The only Bulwark chart found in Artifact Hub was the community L4G chart 0.2.2 for Bulwark 1.6.0. It provided Ingress, schema, probes, NetworkPolicy, ServiceMonitor, and basic settings persistence, but it predated the current split admin state and was five minor releases behind at research time.

Stalwart has several community charts. WrenIX was active but explicitly alpha, lacked a values schema, and documented incomplete clustering. A newer kgrubb chart followed the official Kubernetes reference and signed releases. This evidence supports keeping Stalwart outside the Bulwark chart rather than selecting one community dependency.

## Image evidence

`ghcr.io/bulwarkmail/webmail:1.11.2-always` resolves for linux/amd64 and linux/arm64. The verified index digest is `sha256:0d48c66f993f7f52c0c2b75d4f70ee08b2d638ba3ea9fae7e09c9371365b533a`.

The upstream plain `1.11.2` tag had duplicate manifests; the deterministic `1.11.2-always` index was selected deliberately.

## HelmForge differentiation

- current deterministic official image;
- complete storage model for all current mutable state;
- explicit wizard and declarative modes;
- generated, existing, and External Secrets paths;
- guarded OAuth and JWT impersonation;
- fail-fast single-writer, exposure, and subpath rules;
- Ingress and canonical Gateway API support;
- dual-stack Service and product-specific NetworkPolicy;
- runtime verification of health, configuration, and setup behavior.

## Risks

- Browser/JMAP CORS remains an external integration responsibility.
- Single replica means application downtime during pod replacement.
- Admin-file precedence can retain wizard overrides after switching modes.
- Backup consistency requires copying the PVC and Secret together.
