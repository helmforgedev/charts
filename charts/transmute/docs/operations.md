# Transmute Operations Guide

## First installation

```bash
helm install transmute oci://ghcr.io/helmforgedev/helm/transmute \
  --namespace transmute --create-namespace
kubectl rollout status deployment/transmute-transmute --namespace transmute
helm test transmute --namespace transmute
```

Use a port-forward for private first access:

```bash
kubectl port-forward service/transmute-transmute 8080:8080 --namespace transmute
```

Open `http://127.0.0.1:8080` and register the first account. On an empty data
volume, that account becomes administrator. Do this before exposing a public route.

## Ingress with TLS

```yaml
config:
  appUrl: https://transmute.example.com

ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: transmute.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: transmute-tls
      hosts:
        - transmute.example.com
```

## Gateway API

The Gateway and controller must already exist. `backendRefs` defaults to the
Transmute Service and port when omitted:

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - name: public
      parentRefs:
        - name: shared-gateway
          namespace: gateway-system
          sectionName: https
      hostnames:
        - transmute.example.com
      rules:
        - matches:
            - path:
                type: PathPrefix
                value: /
```

## OIDC setup and verification

1. Register `https://transmute.example.com/api/oidc/callback` in the provider.
2. Configure `config.appUrl`, `oidc.issuerUrl`, `oidc.clientId` and a client secret.
3. Set `oidc.internalUrl` only when pods cannot reach the public issuer URL.
4. Install or upgrade the release.
5. Verify `/api/oidc/config` reports OIDC enabled.
6. Complete a browser authorization-code login and confirm the callback returns an
   authenticated Transmute session.

Example with an existing Secret:

```bash
kubectl create secret generic transmute-auth --namespace transmute \
  --from-literal=AUTH_SECRET_KEY='replace-with-at-least-32-random-characters' \
  --from-literal=OIDC_CLIENT_SECRET='provider-client-secret'
```

```yaml
config:
  appUrl: https://transmute.example.com
auth:
  existingSecret: transmute-auth
oidc:
  enabled: true
  issuerUrl: https://id.example.com/realms/main
  internalUrl: http://keycloak.identity.svc/realms/main
  clientId: transmute
```

## External Secrets

Set `auth.existingSecret` to the exact `spec.target.name` produced by an
`externalSecrets.items[]` entry. The target must contain `AUTH_SECRET_KEY` and,
when OIDC is enabled, `OIDC_CLIENT_SECRET`. Confirm synchronization before the
Deployment starts:

```bash
kubectl get externalsecret --namespace transmute
kubectl wait --for=condition=Ready externalsecret/transmute-auth \
  --namespace transmute --timeout=120s
kubectl get secret transmute-auth --namespace transmute
```

## Backup and restore

All durable data is on the PVC. Before a consistent file-level backup:

```bash
kubectl scale deployment/transmute-transmute --replicas=0 --namespace transmute
kubectl wait --for=delete pod \
  --selector app.kubernetes.io/instance=transmute,app.kubernetes.io/name=transmute \
  --namespace transmute --timeout=120s
```

Only after the Pod has terminated, snapshot or copy the volume. Then return the
chart-managed replica count:

```bash
helm upgrade transmute oci://ghcr.io/helmforgedev/helm/transmute \
  --namespace transmute --reuse-values
```

Back up the external or chart-owned authentication Secret separately. During
restore, recreate the Secret, restore the PVC, then install the same values.

## Upgrade to chart v2

Chart v2 rejects v1-only values. Remove the unsupported admin, registration,
storage directory, timeout, OIDC redirect/scope and legacy ESO keys. Map worker
concurrency and issuer values according to the migration table in the README.

Render and inspect before upgrading:

```bash
helm template transmute ./charts/transmute --namespace transmute \
  --values production-values.yaml
helm upgrade transmute ./charts/transmute --namespace transmute \
  --values production-values.yaml
```

The `Recreate` strategy causes a short outage but prevents two application
versions from writing the same SQLite database.

## Troubleshooting

Check rollout, events and logs:

```bash
kubectl rollout status deployment/transmute-transmute --namespace transmute
kubectl describe pod --selector app.kubernetes.io/instance=transmute --namespace transmute
kubectl logs deployment/transmute-transmute --namespace transmute --tail=200
```

For OIDC, confirm issuer discovery from inside the cluster and ensure the issuer
returned by `/.well-known/openid-configuration` exactly matches
`oidc.issuerUrl`. A wrong `config.appUrl` produces an invalid callback URI.

For conversion failures, inspect memory limits, PVC capacity and application
logs. Writable caches live under `/tmp`; persistent files live under `/app/data`.
