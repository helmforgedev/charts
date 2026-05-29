# JupyterHub

JupyterHub provides multi-user notebook servers for teams, classrooms, and
research platforms.

This HelmForge chart deploys a JupyterHub Hub and configurable-http-proxy pair
with a managed proxy token Secret, KubeSpawner configuration, namespaced RBAC for
user pods, optional user PVCs, Gateway API, Ingress, dual-stack Service,
NetworkPolicy, ExternalSecret, ServiceMonitor, PodDisruptionBudget, schema, and
Helm tests.

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install jupyterhub helmforge/jupyterhub
```

## Proxy Token

The chart generates a proxy token by default. For GitOps-managed credentials,
set `proxy.existingSecret` and optionally render an `ExternalSecret`.

## Production Notes

Keep the default SQLite Hub database to one Hub replica. For larger deployments,
configure an external database with `hub.extraConfig` and manage it with the
HelmForge PostgreSQL chart.

## Single-User Image

```yaml
singleuser:
  image:
    name: quay.io/jupyter/scipy-notebook
    tag: "2026-05-26"
```

## Profiles

```yaml
singleuser:
  profiles:
    - display_name: Standard
      slug: standard
      default: true
      kubespawner_override:
        cpu_limit: 1
        mem_limit: 2G
```
