# Changelog

## generic - breaking feature release

### Added

- Added optional Security, RBAC, NetworkPolicy, Secret, ExternalSecret, and SealedSecret resources.
- Added additional Services, headless Service mode, richer Service fields, Ingress custom backends, and Gateway API HTTPRoutes.
- Added declarative PVC/PV storage contracts, PodMonitor, PrometheusRule, advanced HPA metrics, KEDA ScaledObject/ScaledJob, and advanced Job/CronJob controls.
- Added deterministic rollout controls with `rollout.restartAt`, rollout pod annotations, and ConfigMap/Secret checksums.

### Changed

- Changed the default image to the pinned `docker.io/library/nginx:1.27.5` image with `IfNotPresent`.
- Removed render-time timestamp annotations from workload pod templates.
- Tightened validation for HPA, PDB, names, Ingress, ServiceMonitor, CronJobs, and storage capacity.

### Migration

- Set explicit image tags or digests for production workloads.
- Use `rollout.restartAt` or checksum controls for intentional pod restarts.
- Ensure optional CRD-backed features are enabled only after their CRDs exist in the target cluster.

