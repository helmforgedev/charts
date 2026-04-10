# Rate Limiting

Envoy Gateway supports distributed rate limiting with Redis backend for API protection.

## Architecture

```
Client → Gateway (EG Operator provisions Envoy) → Rate Limit Service → Redis
                    ↓
               Backend Service
```

1. Envoy proxy pods (provisioned automatically by the EG operator when a Gateway resource exists) receive requests
2. Rate limit service checks Redis for request counts
3. Requests within limits are forwarded to backends
4. Requests exceeding limits receive 429 (Too Many Requests)

## Enabling Rate Limiting

### With Deployed Redis

Deploy Redis StatefulSet with the chart:

```yaml
rateLimiting:
  enabled: true
  redis:
    enabled: true
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
    persistence:
      enabled: true
      size: 2Gi
```

The chart automatically:
- Creates Redis StatefulSet with PVC
- Configures rate limit service to use Redis
- Sets up headless service for Redis

### With External Redis

Use an existing Redis instance:

```yaml
rateLimiting:
  enabled: true
  redis:
    enabled: false
  externalRedis:
    host: redis.example.com
    port: 6379
    auth:
      enabled: true
      secretName: redis-auth
      secretKey: password
```

Create the secret:

```bash
kubectl create secret generic redis-auth \
  --from-literal=password=your-redis-password
```

## Rate Limit Presets

The chart includes two pre-configured presets:

### API Preset (100 requests/minute)

```yaml
rateLimiting:
  presets:
    api: true
```

Creates `BackendTrafficPolicy` with a `targetRef.kind: Gateway` targeting the active Gateway resource:
- **Limit**: 100 requests per minute
- **Scope**: Per client IP (x-real-ip header)
- **Type**: Global (distributed across all proxy instances)

Usage:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-api
spec:
  rules:
  - backendRefs:
    - name: api-service
      port: 80
    filters:
    - type: ExtensionRef
      extensionRef:
        group: gateway.envoyproxy.io
        kind: BackendTrafficPolicy
        name: envoy-gateway-ratelimit-api
```

### Strict Preset (10 requests/minute)

```yaml
rateLimiting:
  presets:
    strict: true
```

Creates `BackendTrafficPolicy` with:
- **Limit**: 10 requests per minute
- **Scope**: Per client IP
- **Type**: Global

## Custom Rate Limit Policies

Create custom `BackendTrafficPolicy` for specific requirements:

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: BackendTrafficPolicy
metadata:
  name: custom-ratelimit
spec:
  targetRef:
    kind: HTTPRoute
    name: my-api
  rateLimit:
    type: Global
    global:
      rules:
      # Different limits for authenticated vs anonymous users
      - clientSelectors:
        - headers:
          - name: authorization
            type: Exists
        limit:
          requests: 1000
          unit: Minute
      - clientSelectors:
        - headers:
          - name: x-real-ip
            type: Distinct
        limit:
          requests: 100
          unit: Minute
```

## Redis Configuration

### Persistence

Enable persistence for rate limit data survival across restarts:

```yaml
rateLimiting:
  redis:
    persistence:
      enabled: true
      size: 2Gi
      storageClass: fast-ssd
```

### Resources

Tune Redis resources based on traffic:

```yaml
rateLimiting:
  redis:
    resources:
      requests:
        cpu: 200m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
```

**Guidelines**:
- **Low traffic** (<1000 req/s): 100m CPU, 128Mi memory
- **Medium traffic** (1000-10000 req/s): 200m CPU, 256Mi memory
- **High traffic** (>10000 req/s): 500m CPU, 512Mi memory

## Monitoring

### Check Redis Status

```bash
# Get Redis pod
kubectl get pods -l app.kubernetes.io/component=redis

# View Redis logs
kubectl logs envoy-gateway-redis-0

# Test Redis connectivity
kubectl exec -it envoy-gateway-redis-0 -- redis-cli ping
```

### View Rate Limit Metrics

```bash
# Port-forward to controller
kubectl port-forward svc/envoy-gateway-controller 8081:8081

# Check rate limit metrics
curl http://localhost:8081/metrics | grep ratelimit
```

Key metrics:
- `envoy_cluster_ratelimit_over_limit` — requests rejected by rate limiter
- `envoy_cluster_ratelimit_ok` — requests allowed by rate limiter
- `envoy_cluster_ratelimit_error` — rate limiter errors

## Troubleshooting

### Rate Limiting Not Working

**Symptom**: No 429 errors despite exceeding limits

**Diagnosis**:

```bash
# Check Redis is running
kubectl get pods -l app.kubernetes.io/component=redis

# Check rate limit policy
kubectl get backendtrafficpolicy

# Verify HTTPRoute has ExtensionRef filter
kubectl get httproute <route-name> -o yaml | grep -A 10 filters
```

**Common Causes**:
1. Redis pod not running
2. Rate limit policy not attached to HTTPRoute
3. Wrong header selector (x-real-ip vs x-forwarded-for)
4. External Redis not reachable

### High Redis Memory Usage

**Symptom**: Redis OOMKilled or high memory consumption

**Solution**:

Increase memory limits:

```yaml
rateLimiting:
  redis:
    resources:
      limits:
        memory: 1Gi
```

Or configure Redis maxmemory policy (evict old keys):

```yaml
rateLimiting:
  redis:
    extraArgs:
    - --maxmemory-policy
    - allkeys-lru
```

## Best Practices

1. **Use distributed rate limiting** — `type: Global` ensures limits work across multiple proxy instances
2. **Monitor Redis health** — Set up alerts for Redis availability
3. **Size Redis appropriately** — Allocate memory based on expected traffic
4. **Use different limits for different routes** — Apply stricter limits to expensive operations
5. **Test rate limits** — Validate limits work before production deployment

<!-- @AI-METADATA
type: chart-docs
title: Rate Limiting Guide
description: Distributed rate limiting with Redis backend for Envoy Gateway
keywords: rate-limiting, redis, api-protection, distributed, envoy-gateway, backendtrafficpolicy
purpose: Architecture guide and configuration reference for rate limiting with Envoy Gateway
scope: Chart
relations:
  - charts/envoy-gateway/README.md
  - charts/envoy-gateway/values.yaml
  - charts/envoy-gateway/examples/rate-limiting.yaml
path: charts/envoy-gateway/docs/rate-limiting.md
version: 1.0
date: 2026-04-09
-->
