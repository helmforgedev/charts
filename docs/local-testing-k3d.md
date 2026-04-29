# Local Testing with k3d

This guide covers how to run Helm charts locally using [k3d](https://k3d.io), a lightweight Kubernetes distribution
that runs k3s inside Docker containers. Use this for integration testing beyond what `helm template` and `helm-unittest` can validate.

## When to Use Local Testing

| Scenario | Tool |
|----------|------|
| YAML syntax and template rendering | `helm lint`, `helm template` |
| Assert template output | `helm-unittest` |
| Validate against K8s schemas | `kubeconform` |
| **Verify pods start and become ready** | **k3d** |
| **Test persistence, networking, ingress** | **k3d** |
| **Validate init containers, probes, env vars** | **k3d** |
| **End-to-end chart behavior** | **k3d** |

Static validation (lint, template, unittest, kubeconform) catches most issues. Use k3d when you need to verify runtime behavior.

## Prerequisites

| Tool | Minimum Version | Install |
|------|----------------|---------|
| Docker | 20.10+ | [docs.docker.com](https://docs.docker.com/get-docker/) |
| k3d | 5.x | `choco install k3d` or `brew install k3d` |
| kubectl | 1.28+ | `choco install kubernetes-cli` or `brew install kubectl` |
| Helm | 3.14+ | `choco install kubernetes-helm` or `brew install helm` |

## Cluster Management

### Create a Cluster

```bash
# Standard single-node cluster for chart testing
k3d cluster create helmforge-test \
  --agents 0 \
  --servers 1 \
  --port "8080:80@loadbalancer" \
  --port "8443:443@loadbalancer" \
  --wait
```

Port mapping exposes the traefik ingress at `localhost:8080` (HTTP) and `localhost:8443` (HTTPS).

### Multi-node Cluster

For testing anti-affinity, PDBs, and replication:

```bash
k3d cluster create helmforge-test \
  --agents 2 \
  --servers 1 \
  --port "8080:80@loadbalancer" \
  --port "8443:443@loadbalancer" \
  --wait
```

### Delete a Cluster

```bash
k3d cluster delete helmforge-test
```

### List Clusters

```bash
k3d cluster list
```

## Testing Workflow

### 1. Create Cluster

```bash
k3d cluster create helmforge-test --wait
```

### 2. Verify Connectivity

```bash
kubectl cluster-info
kubectl get nodes
```

### 3. Install Chart

```bash
# From local source
helm install test-release charts/<chart-name> -f charts/<chart-name>/ci/<values-file>.yaml

# From OCI registry (to test published charts)
helm install test-release oci://ghcr.io/helmforgedev/helm/<chart-name>
```

### 4. Verify Deployment

```bash
# Wait for pods to become ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=test-release --timeout=120s

# Check all resources
kubectl get all -l app.kubernetes.io/instance=test-release

# Check pod logs
kubectl logs -l app.kubernetes.io/instance=test-release --tail=50

# Describe pod (useful for debugging startup failures)
kubectl describe pod -l app.kubernetes.io/instance=test-release
```

### 5. Validate Functionality

```bash
# Port-forward to test the application directly
kubectl port-forward svc/test-release-<chart-name> 8080:<service-port>

# Test with curl
curl -s http://localhost:8080/
```

### 6. Cleanup

```bash
helm uninstall test-release
# Or delete the entire cluster
k3d cluster delete helmforge-test
```

## Chart-Specific Testing

### Databases (PostgreSQL, MySQL, MongoDB, Redis)

Databases need persistence and readiness probes to pass:

```bash
# Install with standalone ci values
helm install test-db charts/postgresql -f charts/postgresql/ci/standalone.yaml

# Wait for StatefulSet to be ready
kubectl rollout status statefulset/test-db-postgresql --timeout=120s

# Test connectivity
kubectl exec -it test-db-postgresql-0 -- pg_isready
```

### Stateful Applications (Vaultwarden, Keycloak)

These require persistence and may need specific environment variables:

```bash
# Install with minimal ci values
helm install test-vault charts/vaultwarden -f charts/vaultwarden/ci/minimal.yaml

# Wait and verify
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=test-vault --timeout=180s
kubectl logs -l app.kubernetes.io/instance=test-vault --tail=20
```

### Replication and Clustering (Redis, RabbitMQ, PostgreSQL, MySQL)

Test with multi-node cluster and replication values:

```bash
# Create multi-node cluster
k3d cluster create helmforge-test --agents 2 --wait

# Install replication config
helm install test-redis charts/redis -f charts/redis/ci/replication.yaml

# Wait for all replicas
kubectl rollout status statefulset/test-redis-primary --timeout=120s
kubectl rollout status statefulset/test-redis-replicas --timeout=120s

# Verify replication
kubectl exec test-redis-primary-0 -- redis-cli INFO replication | grep connected_slaves
```

### Ingress Testing

k3d ships with traefik by default:

```bash
# Create cluster with port mapping
k3d cluster create helmforge-test --port "8080:80@loadbalancer" --wait

# Install chart with ingress enabled
helm install test-vault charts/vaultwarden \
  --set domain="http://vault.localhost:8080" \
  --set ingress.enabled=true \
  --set ingress.ingressClassName=traefik \
  --set "ingress.hosts[0].host=vault.localhost" \
  --set "ingress.hosts[0].paths[0].path=/" \
  --set "ingress.hosts[0].paths[0].pathType=Prefix"

# Test (vault.localhost resolves to 127.0.0.1 on most systems)
curl -s http://vault.localhost:8080/
```

## Using CI Values for Testing

Every chart has `ci/*.yaml` files designed for template validation. These files also work as starting points for local testing:

```bash
# List available CI values for a chart
ls charts/<chart-name>/ci/

# Install with a specific CI values file
helm install test charts/<chart-name> -f charts/<chart-name>/ci/<values>.yaml
```

CI values files cover different configurations (standalone, replication, TLS, metrics, etc.) and are a good baseline for integration tests.

## Troubleshooting

### Pod stuck in CrashLoopBackOff

```bash
kubectl logs <pod-name> --previous   # logs from the crashed container
kubectl describe pod <pod-name>       # events and conditions
```

### Pod stuck in Pending

```bash
kubectl describe pod <pod-name>       # check for scheduling issues
kubectl get pvc                       # check if PVC is bound
kubectl get events --sort-by=.lastTimestamp
```

### Service not reachable

```bash
kubectl get svc                       # verify service exists and has endpoints
kubectl get endpoints <svc-name>      # verify endpoints are populated
kubectl port-forward svc/<svc-name> <local-port>:<svc-port>  # bypass ingress
```

### Ingress not routing

```bash
kubectl get ingress                   # check ingress resource
kubectl get pods -n kube-system       # check traefik is running
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=20
```

## Standard Validation Checklist

Before pushing changes, after local testing passes:

```bash
# Static validation (always required)
helm lint charts/<name> --strict
helm template test charts/<name>
helm unittest charts/<name>
for f in charts/<name>/ci/*.yaml; do helm template test charts/<name> -f "$f"; done

# Local integration test (when testing runtime behavior)
k3d cluster create helmforge-test --wait
helm install test charts/<name> -f charts/<name>/ci/<values>.yaml
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=test --timeout=120s
kubectl get all -l app.kubernetes.io/instance=test
helm uninstall test
k3d cluster delete helmforge-test
```

<!-- @AI-METADATA
type: guide
title: Local Testing with k3d
description: Guide for local integration testing of Helm charts using k3d (k3s in Docker)

keywords: k3d, k3s, local-testing, integration, kubernetes, docker, validation

purpose: Document local integration testing workflow using k3d for Helm chart validation
scope: Testing

relations:
  - docs/testing-strategy.md
  - .claude/CLAUDE.md
  - .claude/AGENTS.md
path: docs/local-testing-k3d.md
version: 1.0
date: 2026-03-20
-->
