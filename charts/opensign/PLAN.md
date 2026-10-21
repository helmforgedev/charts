# OpenSign implementation plan

## Target

- Chart: `opensign`
- Issue: [helmforgedev/charts#1665](https://github.com/helmforgedev/charts/issues/1665)
- First release: 1.0.0
- Upstream application: 2.41.3

## Deliverables

1. Separate frontend and backend Deployments and Services.
2. Immutable digest-pinned official images.
3. HelmForge MongoDB dependency plus external MongoDB contract.
4. Retained local document PVC and S3-compatible mode.
5. Stable Secret, existing Secret, and External Secrets paths.
6. Ingress, Gateway API, dual-stack Service, and NetworkPolicy support.
7. Non-root restricted security contexts, probes, HPA, and PDB.
8. Unit, schema, static, security, and k3d behavioral validation.
9. Complete chart and helmforge.dev documentation.

## Validation matrix

| Scenario | Purpose |
|---|---|
| default | Official images, MongoDB, local PVC, retained identity, HTTP smoke |
| dual-stack | Canonical Service address-family behavior |
| ingress | Separate frontend and API Ingress resources |
| gateway-api | Separate frontend and API HTTPRoutes |
| external-secrets | Native ESO materialization of application identity |
| unit validation | Invalid database, S3, SMTP, routing, and secret contracts fail fast |

## Release sequence

1. Pass `make validate-chart CHART=opensign` on local k3d.
2. Pass template standards, dependency, release, attribution, and Markdown gates.
3. Open the chart and site pull requests against `main`.
4. Resolve all review threads and wait for required checks.
5. Merge the chart and verify the published `opensign` 1.0.0 artifact.
6. Merge the site documentation and verify the production page and icon.
