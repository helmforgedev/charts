# Apache Druid Networking and Security Guide

## Router Exposure

The Druid router is the chart's public entry point. It exposes the web console
and routes API calls to other Druid services.

For local access:

```bash
kubectl port-forward svc/druid 8080:80
```

For cluster ingress, enable either Ingress or Gateway API. Do not enable both
for the same hostname unless your platform intentionally supports parallel
routes.

## Ingress

Ingress routes traffic to the router Service:

```yaml
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: druid.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: druid-tls
      hosts:
        - druid.example.com
```

The chart uses `ingress.ingressClassName` and does not rely on legacy
annotation-only class selection.

## Gateway API

Gateway API support renders an HTTPRoute and expects the Gateway to be managed
outside the chart:

```yaml
gatewayAPI:
  enabled: true
  parentRefs:
    - name: shared-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - druid.example.com
  paths:
    - type: PathPrefix
      value: /
```

This split lets platform teams own listener policy, TLS, and cross-namespace
route admission while application teams own the backend route.

## Dual-stack Services

Service IP family fields are omitted by default so the cluster default applies.
For dual-stack clusters:

```yaml
service:
  ipFamilyPolicy: PreferDualStack
```

Set `service.ipFamilies` only when the cluster requires an explicit ordered
family list.

## NetworkPolicy

NetworkPolicy is disabled by default. Druid requires internal communication
between all Druid components, metadata storage, ZooKeeper, DNS, and optionally
S3-compatible storage.

A baseline same-namespace policy:

```yaml
networkPolicy:
  enabled: true
  ingress:
    allowSameNamespace: true
  egress:
    enabled: true
    allowDNS: true
    allowSameNamespace: true
    allowHTTPS: true
```

When the router is exposed through a Gateway controller in another namespace,
add that namespace to `networkPolicy.ingress.extraFrom`.

When using MinIO over plain HTTP, set `networkPolicy.egress.allowHTTP=true` or
add a more specific `extraTo` rule.

## Pod Security

Druid containers run as non-root by default:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  runAsGroup: 1000
  runAsNonRoot: true
  runAsUser: 1000
  seccompProfile:
    type: RuntimeDefault
```

The init container that prepares writable directories runs as root with a small
capability set so the main Druid process can run as UID 1000.

## Resource Limits

The chart leaves component `resources` empty by default because Druid sizing is
workload-specific and tied to JVM heap settings. Production values should set
requests and limits for every component and keep memory limits above the
configured heap plus native overhead.

Example Broker sizing:

```yaml
broker:
  javaOpts: "-Xms1g -Xmx1g"
  resources:
    requests:
      cpu: 500m
      memory: 1536Mi
    limits:
      cpu: "2"
      memory: 2Gi
```

## Operational Checks

After installation:

```bash
kubectl get pods -l app.kubernetes.io/instance=druid
kubectl logs -l app.kubernetes.io/instance=druid --all-containers --tail=200
kubectl port-forward svc/druid 8080:80
```

Then open `http://localhost:8080` and verify the Druid console can load
Services, Datasources, and Tasks.
