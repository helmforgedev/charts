# Security Policies

Envoy Gateway's `SecurityPolicy` CRD provides native authentication and authorization at the Gateway or HTTPRoute level — a major differential over traditional nginx-based ingress controllers.

## Features vs nginx-ingress

| Feature | nginx-ingress | Envoy Gateway |
|---------|--------------|---------------|
| JWT validation | External plugin | Native (SecurityPolicy) |
| OIDC/OAuth2 | External auth-server | Native (SecurityPolicy) |
| API Key | Header check only | Native (SecurityPolicy) |
| CORS | Annotation only | Native (SecurityPolicy) |
| mTLS | Limited | Native (ClientTrafficPolicy) |

## Quick Start

Enable via values:

```yaml
securityPolicy:
  create: true
  jwt:
    enabled: true
    providers:
      - name: google
        issuer: https://accounts.google.com
        remoteJWKS:
          uri: https://www.googleapis.com/oauth2/v3/certs
```

## JWT Authentication

JWT validation verifies bearer tokens against a remote JWKS endpoint before forwarding the request to the backend.

### Values Configuration

```yaml
securityPolicy:
  create: true
  jwt:
    enabled: true
    providers:
      - name: my-provider
        issuer: https://auth.example.com
        remoteJWKS:
          uri: https://auth.example.com/.well-known/jwks.json
        claimToHeaders:
          - claim: sub
            header: x-user-id
          - claim: email
            header: x-user-email
```

### Raw CRD Example

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: jwt-auth
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: envoy-gateway
  jwt:
    providers:
    - name: my-provider
      issuer: https://auth.example.com
      remoteJWKS:
        uri: https://auth.example.com/.well-known/jwks.json
      claimToHeaders:
      - claim: sub
        header: x-user-id
```

### Per-Route JWT Override

Attach a SecurityPolicy to an HTTPRoute to override Gateway-level auth for a specific route:

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: public-route-jwt-skip
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: public-health-check
  # No jwt block = route is unauthenticated
```

## OIDC Authentication

OIDC enables OAuth2 Authorization Code Flow — the proxy handles the redirect to the identity provider and token exchange. Ideal for browser-based access to protected services.

### Values Configuration

```yaml
securityPolicy:
  create: true
  oidc:
    enabled: true
    provider:
      issuer: https://accounts.google.com
    clientID: my-client-id
    clientSecret:
      name: oidc-client-secret
      key: client-secret
    redirectURL: https://app.example.com/oauth2/callback
    scopes:
      - openid
      - email
      - profile
```

Create the client secret:

```bash
kubectl create secret generic oidc-client-secret \
  --from-literal=client-secret=<your-oidc-client-secret>
```

### Raw CRD Example

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: oidc-auth
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: envoy-gateway
  oidc:
    provider:
      issuer: https://accounts.google.com
    clientID: my-client-id
    clientSecret:
      name: oidc-client-secret
      key: client-secret
    redirectURL: https://app.example.com/oauth2/callback
    scopes:
    - openid
    - email
    - profile
```

## API Key Authentication

API Key auth validates a key provided in a request header or query parameter against a set of pre-shared secrets.

### Values Configuration

```yaml
securityPolicy:
  create: true
  apiKey:
    enabled: true
    credentials:
      - name: api-keys
        key: keys
    extractFrom:
      - headers:
          - name: x-api-key
```

Create the API keys secret (newline-separated):

```bash
kubectl create secret generic api-keys \
  --from-literal=keys=$'key-abc123\nkey-xyz789'
```

### Raw CRD Example

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: api-key-auth
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: envoy-gateway
  apiKeyAuth:
    credentials:
    - name: api-keys
      key: keys
    extractFrom:
    - headers:
      - name: x-api-key
```

## CORS

CORS configuration is applied at the Gateway or HTTPRoute level. It controls which origins, methods, and headers are permitted for cross-origin requests.

### Values Configuration

```yaml
securityPolicy:
  create: true
  cors:
    enabled: true
    allowOrigins:
      - "https://app.example.com"
      - "https://admin.example.com"
    allowMethods:
      - GET
      - POST
      - PUT
      - DELETE
      - OPTIONS
    allowHeaders:
      - Authorization
      - Content-Type
      - X-Requested-With
    exposeHeaders:
      - X-Request-Id
    maxAge: 86400
```

### Raw CRD Example

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: cors-policy
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: my-api
  cors:
    allowOrigins:
    - type: Exact
      value: https://app.example.com
    allowMethods:
    - GET
    - POST
    allowHeaders:
    - Authorization
    - Content-Type
    maxAge: 86400s
```

## Combining Auth Methods

Multiple auth methods can be combined in a single SecurityPolicy:

```yaml
securityPolicy:
  create: true
  jwt:
    enabled: true
    providers:
      - name: my-idp
        issuer: https://auth.example.com
        remoteJWKS:
          uri: https://auth.example.com/.well-known/jwks.json
  cors:
    enabled: true
    allowOrigins:
      - "https://app.example.com"
    allowMethods:
      - GET
      - POST
```

## Troubleshooting

### JWT Validation Failing

```bash
# Check SecurityPolicy status
kubectl get securitypolicy -o wide

# Describe SecurityPolicy for conditions
kubectl describe securitypolicy my-jwt-policy

# Check controller logs
kubectl logs deployment/envoy-gateway-controller | grep security
```

Common causes:
- JWKS URI unreachable from proxy pods
- Token audience mismatch
- Clock skew between issuer and proxy

### OIDC Redirect Loop

Verify that:
1. `redirectURL` matches the redirect URI configured in your identity provider
2. The Gateway has an HTTPS listener (OIDC requires HTTPS)
3. The client secret exists in the same namespace as the SecurityPolicy

<!-- @AI-METADATA
type: chart-docs
title: Security Policies Guide
description: JWT, OIDC, API Key, and CORS authentication with SecurityPolicy CRD for Envoy Gateway
keywords: security, jwt, oidc, oauth2, api-key, cors, mtls, authentication, authorization, securitypolicy, envoy-gateway
purpose: Guide for configuring authentication and security policies with the SecurityPolicy CRD
scope: Chart
relations:
  - charts/envoy-gateway/README.md
  - charts/envoy-gateway/values.yaml
  - charts/envoy-gateway/docs/architecture.md
path: charts/envoy-gateway/docs/security-policies.md
version: 1.0
date: 2026-04-10
-->
