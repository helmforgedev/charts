# Local Testing with k3d

Use local k3d validation when a chart change needs proof beyond static rendering.
Static validation catches template and schema issues.
k3d validation proves that the chart installs, workloads become ready, services work, events are clean, and logs do not show runtime problems.

## When to Use Local Testing

| Scenario | Required tool |
|----------|---------------|
| YAML syntax and template rendering | `helm lint`, `helm template` |
| Template output assertions | `helm-unittest` |
| Kubernetes API schema validation | `kubeconform` |
| Artifact Hub metadata validation | `ah` |
| Security compliance scan | `kubescape` |
| Pod readiness, probes, init containers, env vars, and persistence | `k3d`, `helm`, `kubectl` |
| Service, ingress, Gateway API, and application smoke tests | `k3d`, `curl`, chart-specific clients |

Runtime validation is mandatory for new charts, release updates, startup fixes, dependency changes, persistence changes, networking changes, and fixes that previously failed only after installation.

## Prerequisites

| Tool | Expected baseline | Purpose |
|------|-------------------|---------|
| Docker | 20.10+ | k3d runtime |
| k3d | 5.x | local Kubernetes cluster |
| kubectl | 1.28+ | Kubernetes inspection |
| Helm | 4.x | chart validation and install |
| helm-unittest | current plugin | chart unit tests |
| kubeconform | current CLI | rendered manifest schema validation |
| ah | current CLI | Artifact Hub lint |
| kubescape | current CLI | security scanning |
| jq | current CLI | local score parsing and JSON inspection |

The local helper expects these tools to be installed permanently on the workstation.
Do not download them ad hoc for each PR.

## Cluster Standard

The default local cluster used by HelmForge validation is:

```text
k3d-helmforge-tests-wsl
```

Create it when needed:

```bash
k3d cluster create helmforge-tests-wsl \
  --agents 2 \
  --servers 1 \
  --port "8080:80@loadbalancer" \
  --port "8443:443@loadbalancer" \
  --wait
```

Confirm context before every install, upgrade, or uninstall:

```bash
kubectl config current-context
```

The context must be clearly local and should start with `k3d-`.
Never run runtime validation against production, staging, shared development clusters, or unclear contexts.

## CRDs

Install required CRDs before validating charts that render CRD-backed resources.
Do not bypass validation with `kubeconform --ignore-missing-schema`.

Common examples:

```bash
# Gateway API
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml

# External Secrets Operator CRDs
kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/crds/bundle.yaml
```

Use the current official CRD release when validating a specific chart.
The commands above are examples for common local setup.

## Standard Workflow

Run static validation first:

```bash
./test.sh <chart-name>
```

Run runtime validation with a representative scenario:

```bash
kubectl config current-context
./test.sh <chart-name> --runtime -f charts/<chart-name>/ci/<scenario>.yaml
```

The helper installs with:

```bash
helm upgrade --install hf-test charts/<chart-name> \
  --namespace hf-test-<chart-name> \
  --wait \
  --timeout 120s
```

If rollout is not progressing, inspect status after roughly 60 seconds.
Do not wait for long-running broken installs when events or logs already show the cause.

## Manual Runtime Checks

When you need to inspect a chart manually:

```bash
ns=hf-test-<chart-name>
release=hf-test

kubectl get all,pvc,ingress -n "$ns"
kubectl get events -n "$ns" --sort-by=.lastTimestamp
kubectl get pods -n "$ns" -o wide
kubectl logs -n "$ns" -l app.kubernetes.io/instance="$release" --all-containers --tail=120
```

For Deployments:

```bash
kubectl rollout status deployment -n "$ns" -l app.kubernetes.io/instance="$release" --timeout=120s
kubectl rollout restart deployment -n "$ns" -l app.kubernetes.io/instance="$release"
kubectl rollout status deployment -n "$ns" -l app.kubernetes.io/instance="$release" --timeout=120s
```

For StatefulSets:

```bash
kubectl rollout status statefulset -n "$ns" -l app.kubernetes.io/instance="$release" --timeout=120s
kubectl rollout restart statefulset -n "$ns" -l app.kubernetes.io/instance="$release"
kubectl rollout status statefulset -n "$ns" -l app.kubernetes.io/instance="$release" --timeout=120s
```

## Functional Smoke Tests

Use chart-specific checks after readiness passes.

HTTP applications:

```bash
kubectl port-forward -n "$ns" svc/<service-name> 8080:<service-port>
curl -fsS http://127.0.0.1:8080/
```

Databases:

```bash
kubectl exec -n "$ns" <pod-name> -- <native-readiness-command>
```

Queues, caches, and coordinators:

```bash
kubectl exec -n "$ns" <pod-name> -- <native-cli> <health-or-info-command>
```

## Required Evidence

A PR that includes runtime validation should record:

- Current Kubernetes context.
- Exact `./test.sh` command.
- Values scenario used.
- Workload rollout result.
- Functional smoke test performed.
- Confirmation that events and logs were clean.
- Confirmation that the namespace was removed.

## Cleanup

The helper removes the runtime namespace by default.
If you used `--keep-namespace` or manual commands, clean up explicitly:

```bash
helm uninstall hf-test -n hf-test-<chart-name>
kubectl delete namespace hf-test-<chart-name>
```

Verify no leftover namespaces:

```bash
kubectl get ns | grep hf-test || true
```

## Troubleshooting

CrashLoopBackOff:

```bash
kubectl logs -n "$ns" <pod-name> --all-containers --previous
kubectl describe pod -n "$ns" <pod-name>
kubectl get events -n "$ns" --sort-by=.lastTimestamp
```

Pending pods:

```bash
kubectl describe pod -n "$ns" <pod-name>
kubectl get pvc -n "$ns"
kubectl get events -n "$ns" --sort-by=.lastTimestamp
```

Service not reachable:

```bash
kubectl get svc,endpoints,endpointslice -n "$ns"
kubectl port-forward -n "$ns" svc/<service-name> 8080:<service-port>
curl -v http://127.0.0.1:8080/
```

Permission denied at startup:

```bash
kubectl get pod -n "$ns" <pod-name> -o yaml
kubectl logs -n "$ns" <pod-name> --all-containers --tail=120
kubectl describe pod -n "$ns" <pod-name>
```

Check container user, security context, service target ports, environment variables, mounted volume ownership, and upstream application bind addresses.

<!-- @AI-METADATA
type: guide
title: Local Testing with k3d
description: Local k3d validation guide for HelmForge charts covering cluster setup, CRDs, runtime checks, logs, events, and cleanup

keywords: k3d, kubernetes, helm, runtime validation, logs, events, kubeconform, crds

purpose: Explain how to validate HelmForge charts locally before opening or updating a PR
scope: Testing

relations:
  - testing-strategy.md
  - ../CONTRIBUTING.md
  - ../test.sh
path: docs/local-testing-k3d.md
version: 1.1
date: 2026-06-02
-->
