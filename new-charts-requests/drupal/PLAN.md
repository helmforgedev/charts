# Drupal - Implementation Plan

Chart Name: `drupal`
Issue: #104
Target Version: 1.0.0
Complexity: Medium
Estimated Timeline: single implementation workstream

## Executive Summary

Add a HelmForge Drupal chart that deploys the Docker Official Drupal image with a correct Kubernetes persistence model for `sites/`, a bundled MySQL path for easy first install, optional external database or SQLite install paths, and explicit installation guidance in both `NOTES.txt` and the public site docs.

## Strategic Differentiation

| Area | Typical Public Chart | HelmForge Plan |
|------|----------------------|----------------|
| Runtime image | Often Bitnami | Pinned Docker Official Image |
| Persistence | Generic app-root PVC | Seeded `sites/` persistence |
| Installation UX | Implicit assumptions | Explicit installer steps and database commands |
| Docs | Varies | Chart docs plus synced site docs |

## Feature Prioritization

### PRIORITY 1: MVP

#### P1-1: Seeded `sites/` persistence

Impact: High

- Persist only `sites/`
- Seed default contents through an init container
- Support PVC or `emptyDir`

Effort: Medium

#### P1-2: MySQL subchart path

Impact: High

- Bundle HelmForge `mysql` as the default installation path
- Expose the exact credentials users need for the Drupal installer

Effort: Low

#### P1-3: SQLite and external DB guidance

Impact: High

- Allow explicit `database.mode=sqlite`
- Allow `database.mode=external` for user-managed databases
- Keep the chart honest about what is and is not automated

Effort: Low

#### P1-4: Public documentation sync

Impact: High

- Add a site docs page
- Add chart catalog entry
- Add playground entry
- Update charts overview page

Effort: Medium

## PRIORITY 2: Follow-Up

### P2-1: S3/object-storage aware multi-replica story

- Document or implement a stronger multi-replica media strategy

### P2-2: Built-in backup workflow

- Database dump plus `sites/default/files` archive

### P2-3: Optional PostgreSQL bundled path

- Add HelmForge `postgresql` support if demand justifies the extra matrix

## Implementation Phases

### Phase 1: Charts Repo

- Create research and planning artifacts
- Add chart metadata, values, schema, templates, tests, CI examples, README, and docs
- Use MySQL subchart dependency

### Phase 2: Site Repo

- Add `/docs/charts/drupal`
- Add chart metadata to `charts.ts`
- Add playground config and scenarios
- Update `/docs/charts` overview page

### Phase 3: Validation

- `helm dependency build`
- `helm lint --strict`
- `helm template`
- `helm unittest`
- Render `ci/*.yaml`
- Site lint, format check, and build

## Technical Architecture

### Chart Structure

- `Chart.yaml`
- `values.yaml`
- `values.schema.json`
- `.helmignore`
- `templates/`
- `tests/`
- `ci/`
- `examples/`
- `docs/`
- `README.md`

### Dependencies

- `mysql` from `oci://ghcr.io/helmforgedev/helm`

## Validation Strategy

### Helm Tests

- Deployment rendering
- Seed init container presence
- PVC rendering behavior
- Service rendering
- Ingress rendering
- Optional PHP config rendering

### Runtime Intent

- Single replica by default
- Persistent `sites/` path
- Database info surfaced through NOTES

## Documentation Plan

### Chart Documentation

- README with install paths and values summary
- `docs/database.md`
- `docs/persistence.md`

### Site Documentation

- Product overview
- Installation
- Quick start
- Persistence explanation
- Database modes
- Examples
- Troubleshooting
- Resources

## Risks

### Policy Fit Of The Runtime Image

- Severity: Medium
- Probability: Medium
- Impact: The chart may require explicit maintainer approval because Drupal upstream does not publish its own official runtime image.
- Mitigation: Document the decision clearly in research, README, site docs, and PR summary.

### User Expectation Around Auto-Install

- Severity: Medium
- Probability: High
- Impact: Users may expect a fully automated first-time site bootstrap.
- Mitigation: Make manual installer steps explicit in docs and NOTES.

## Success Metrics

- Chart renders cleanly in default, ingress, external DB, and SQLite scenarios
- Site docs cover the public install flow and values surface
- Users can finish the Drupal installer without guessing any cluster-specific database details

## Next Steps

1. Implement the MVP chart
2. Sync the site docs and playground
3. Run local validation
4. Open cross-referenced PRs if validation passes
