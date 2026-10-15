# Stalwart Chart Implementation Plan

Issue: [#1481](https://github.com/helmforgedev/charts/issues/1481)

Target chart release: 1.0.0

## Priority 1: Functional Server

- Official pinned server image and current DataStore-only bootstrap contract.
- StatefulSet with stable identity, headless discovery, PVC single-node mode,
  official probes, graceful shutdown, and split HTTP/mail Services.
- Generated config, existing ConfigMap, or existing Secret sources.
- Full Secret/ConfigMap environment references without literal credentials.

## Priority 2: HA and Production Controls

- Fail fast for multiple replicas with a local DataStore or local persistence.
- Automatic HA PDB and default topology spread, with override escape hatches.
- HTTPRoute, TCPRoute, and TLSRoute behind one off-by-default switch.
- Canonical ExternalSecret items, NetworkPolicy, dual-stack Services,
  monitoring annotations, optional ServiceMonitor, and extra manifests.

## Priority 3: Declarative Operations

- Optional pinned CLI Job with ConfigMap/Secret plan source, Secret-backed
  authentication, dry-run validation, bounded retries, and Helm hook mode.
- Product-specific examples for single node, external-secret HA, Gateway API,
  monitoring, and apply-plan operation.
- Complete operations, storage, clustering, backup, and exposure documentation.

## Validation

The chart must pass `make validate-chart CHART=stalwart`, the standalone
template standards check, end-to-end ESO validation, and product-level k3d
smoke checks for HTTP health plus the SMTP protocol banner and EHLO exchange.
