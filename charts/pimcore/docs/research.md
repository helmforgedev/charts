# Research and differentiation

## Upstream findings

Pimcore is a Symfony platform covering PIM/MDM, DAM, CDP, DXP/CMS, and digital
commerce. Version 2026.2 requires PHP 8.4 or 8.5 and product registration. The
official skeleton uses PHP-FPM, nginx, MariaDB 10.11-compatible semantics,
RabbitMQ, Redis, Mercure, and optional OpenSearch.

The official container is a runtime/toolchain. The skeleton mounts project code
into it; a container tag alone cannot produce a Pimcore installation.

## Existing deployment gap

Generic PHP charts ignore Pimcore's registration, Messenger transports,
maintenance, shared public assets, database collation, and Mercure topology.
Development Docker Compose files download code at runtime and explicitly warn
that their supervisor configuration is not production optimized.

## HelmForge differentiation

| Capability | Generic runtime chart | HelmForge Pimcore |
| --- | --- | --- |
| Runtime/project boundary | Implicit | Explicit bootstrap and immutable-image modes |
| Product registration | Unmodeled | Secret contract and guarded installer |
| Background operations | Ad hoc | Dedicated Messenger and maintenance workloads |
| Database/broker | Manual | HelmForge dependencies or external services |
| Studio real-time updates | Manual | Internal Mercure with nginx proxy |
| HA safety | User guesswork | RWX and immutable-image validation |
| Secret exposure | Common DSN values | In-container DSN construction |
| Local validation | Template only | Behavioral k3d gate |

## Risks and mitigations

- Registration cannot be automated without user-specific credentials; the chart
  fails fast instead of inventing them.
- Runtime Composer bootstrap is network-dependent; production guidance requires
  immutable images.
- Pimcore projects vary; advanced OpenSearch, cache, and object-storage behavior
  remains project-owned and extensible through environment values.
