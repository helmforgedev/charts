# OpenHuman chart plan

## Contract

- Deploy the official `v0.64.15` image by digest and schedule only on amd64 Linux nodes.
- Run one Recreate Deployment as UID/GID 10001 with all capabilities dropped.
- Persist the workspace and projects directories in separate retained claims.
- Generate and retain an RPC token by default; support existing Secrets and External Secrets Operator.
- Expose only a ClusterIP Service by default; make TLS Ingress and Gateway API routes explicit opt-ins.
- Probe the real `/health` endpoint and behaviorally verify the actual image on k3d.

## Validation

- Cover deployment, authentication, persistence, Service, Ingress, Gateway API, dual stack and ExternalSecret rendering.
- Run lint, template, unittest, kubeconform, Artifact Hub lint, security scan and k3d scenarios through `make validate-chart CHART=openhuman`.
- Run the dedicated ESO end-to-end validation and site synchronization checks.

## Delivery

- Create one charts PR resolving issue 1425 and one linked site PR.
- Wait for green CI and zero unresolved review threads, merge both, and verify the `openhuman-v1.0.0` release before reporting delivery.
