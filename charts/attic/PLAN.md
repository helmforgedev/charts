# Attic Helm Chart Implementation Plan

**Issue:** helmforgedev/charts#1378
**Initial chart release:** 1.0.0
**Maturity:** beta

## Executive summary

Build a product-specific Attic chart that is safe for a local persistent cache
and can be promoted to a distributed production topology without replacing the
chart. The chart will encode upstream lifecycle constraints rather than expose
an unconstrained generic container surface.

## Priority 1: safe standalone cache

- Stateful workload running `atticd --mode monolithic`.
- SQLite and local object storage on one PVC.
- Stable Secret reference for JWT material.
- Non-root, read-only-root-filesystem defaults.
- Service, process probes and cache-aware operational NOTES.
- Fail-fast rejection of replicas other than one.

Success criterion: install on k3d, become Ready, serve the Attic root endpoint,
retain data across pod restart and emit no fatal logs or critical events.

## Priority 2: distributed production topology

- PostgreSQL URL and S3 configuration through Secret-backed environment values.
- Pre-install/pre-upgrade migration Job.
- Replicated `api-server` Deployment with PDB and topology controls.
- Singleton `garbage-collector` Deployment.
- Ingress and Gateway API exposure, dual-stack Service and NetworkPolicy.
- External Secrets integration for JWT, database and S3 credentials.

Success criterion: render and unit-test every distributed component and reject
distributed mode unless PostgreSQL, S3 and an existing Secret are configured.

## Priority 3: operations and documentation

- Backup and restore guidance covering metadata plus object storage.
- Nix client bootstrap, trust-key and CI upload examples.
- Upgrade warnings for the commit-SHA image channel and database migrations.
- Complete schema, examples, CI scenarios and site configuration reference.
- Official upstream icon and catalog/playground integration.

## Values contract

- `mode`: `standalone` or `distributed`.
- `image`: official repository and immutable commit tag.
- `replicaCount`: API replicas; exactly one in standalone mode.
- `config`: endpoints, allowed hosts, proof-of-possession, chunking,
  compression, GC and logging.
- `database`: SQLite path or Secret-provided PostgreSQL URL.
- `storage`: local PVC path or S3 settings with Secret-provided credentials.
- `auth`: existing Secret and key mappings; no default plaintext JWT secret.
- standard HelmForge contracts for Service, Ingress, Gateway API, External
  Secrets, NetworkPolicy, PDB, scheduling, security and extra manifests.

## Validation strategy

- Schema validation for the complete values surface.
- Unit tests for workload switching, config, secrets, exposure, policy,
  dual-stack, migrations, GC and all fail-fast constraints.
- CI values for defaults, distributed, Ingress, Gateway API, ESO, policy and
  dual-stack.
- `make validate-chart CHART=attic` as the mandatory end-to-end gate.
- `make standards-check CHART=attic` and zero template-standard warnings.
- Kubescape output recorded in README.
- Site lint, format, build, links and site-sync checks.

## Release plan

Use `feat(attic)!: add chart` so the first automated publication is 1.0.0.
The charts PR owns `Resolves #1378`; the site PR uses a neutral related-issue
link. Merge the site companion only when both PRs are ready, merge the chart PR
to close the issue, confirm the published release, then reply to the requester.
