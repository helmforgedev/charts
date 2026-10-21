# DocuSeal implementation plan

## Scope

1. Pin the official 3.3.3 image by digest.
2. Integrate HelmForge PostgreSQL and Redis subcharts.
3. Support retained local storage and production S3 topology.
4. Preserve identity secrets and support External Secrets Operator.
5. Add Ingress, Gateway API, dual-stack Service, PDB, and NetworkPolicy.
6. Validate schema, templates, unit tests, policy, and behavior on k3d.
7. Synchronize the HelmForge site catalog, documentation, and playground.

## Release gate

The chart is releasable only after `make validate-chart CHART=docuseal` passes
end to end, including every k3d scenario and the application-specific smoke.
