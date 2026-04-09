# TLS Certificates

Envoy Gateway integrates with cert-manager for automated TLS certificate provisioning.

## Architecture

```
Gateway → Certificate → CertificateRequest → cert-manager Issuer → CA/ACME
   ↓
TLS Secret (auto-created)
```

1. Gateway defines listeners with TLS enabled
2. Chart creates Certificate resources (when `autoProvision: true`)
3. cert-manager provisions certificates from configured Issuer
4. TLS secrets are automatically created and referenced by Gateway

## cert-manager Installation

The chart **does not** install cert-manager. Install it separately:

```bash
# Add cert-manager repository
helm repo add jetstack https://charts.jetstack.io

# Install cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

Verify installation:

```bash
kubectl get pods -n cert-manager
```

## Certificate Providers

### Let's Encrypt (Production)

Create ClusterIssuer for Let's Encrypt production:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
    - http01:
        ingress:
          class: envoy
```

Enable in chart:

```yaml
certificates:
  certManager:
    enabled: true
    issuer: letsencrypt-prod
    issuerKind: ClusterIssuer
  autoProvision: true
```

### Let's Encrypt (Staging)

For testing, use Let's Encrypt staging to avoid rate limits:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-staging-key
    solvers:
    - http01:
        ingress:
          class: envoy
```

Chart configuration:

```yaml
certificates:
  certManager:
    enabled: true
    issuer: letsencrypt-staging
    issuerKind: ClusterIssuer
  autoProvision: true
```

### Self-Signed Certificates

For development or internal use:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned
spec:
  selfSigned: {}
```

Chart configuration:

```yaml
certificates:
  certManager:
    enabled: true
    issuer: selfsigned
    issuerKind: ClusterIssuer
  autoProvision: true
```

### Private CA

Use organization's private CA:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: company-ca
spec:
  ca:
    secretName: company-ca-secret
```

Chart configuration:

```yaml
certificates:
  certManager:
    enabled: true
    issuer: company-ca
    issuerKind: ClusterIssuer
  autoProvision: true
```

## Auto-Provisioning

When `autoProvision: true`, the chart automatically creates Certificate resources for Gateway listeners:

```yaml
certificates:
  certManager:
    enabled: true
    issuer: letsencrypt-prod
    issuerKind: ClusterIssuer
  autoProvision: true
```

This generates Certificate resources like:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: envoy-gateway-example-com
spec:
  secretName: envoy-gateway-example-com-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - example.com
  - www.example.com
```

## Manual Certificate Management

Disable auto-provisioning to manage certificates manually:

```yaml
certificates:
  certManager:
    enabled: true
  autoProvision: false
```

Create Certificate resources separately:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-tls
  namespace: default
spec:
  secretName: my-app-tls-secret
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - app.example.com
  - api.example.com
```

Reference in HTTPRoute:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app
spec:
  parentRefs:
  - name: envoy-gateway
    sectionName: https
  hostnames:
  - app.example.com
  rules:
  - backendRefs:
    - name: my-app
      port: 80
```

## Certificate Lifecycle

### Issuance

Check certificate status:

```bash
# List certificates
kubectl get certificate

# Describe certificate
kubectl describe certificate <cert-name>

# Check certificate request
kubectl get certificaterequest
```

Certificate states:
- **True** — Certificate issued successfully
- **False** — Issuance failed (check events)
- **Unknown** — Issuance in progress

### Renewal

cert-manager automatically renews certificates before expiration:

- **Let's Encrypt**: Renews 30 days before expiration (certificates valid 90 days)
- **Self-Signed**: Renews based on `spec.duration` (default 90 days)

Force renewal:

```bash
# Delete certificate secret to trigger reissuance
kubectl delete secret <cert-secret-name>

# Or use cert-manager kubectl plugin
kubectl cert-manager renew <cert-name>
```

### Expiration Monitoring

Monitor certificate expiration:

```bash
# Check certificate expiration
kubectl get certificate -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.notAfter}{"\n"}{end}'
```

Set up Prometheus alerts (included with chart when monitoring enabled):

```yaml
- alert: CertificateExpiringSoon
  expr: certmanager_certificate_expiration_timestamp_seconds - time() < 604800
  for: 1h
  annotations:
    summary: Certificate expiring in less than 7 days
```

## Troubleshooting

### Certificate Not Issued

**Symptom**: Certificate stuck in "False" or "Unknown" state

**Diagnosis**:

```bash
# Check certificate status
kubectl describe certificate <cert-name>

# Check certificate request
kubectl get certificaterequest
kubectl describe certificaterequest <request-name>

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

**Common Causes**:
1. **Issuer not found** — Verify issuer exists: `kubectl get clusterissuer`
2. **ACME challenge failed** — Check domain DNS points to Gateway's external IP
3. **Rate limit exceeded** — Let's Encrypt has rate limits (5 certs/week per domain)
4. **Invalid email** — ACME requires valid email address
5. **Webhook timeout** — cert-manager webhook not responding

### HTTP-01 Challenge Fails

**Symptom**: ACME HTTP-01 challenge validation fails

**Requirements for HTTP-01**:
- Gateway must have public IP address
- Domain DNS must resolve to Gateway IP
- Port 80 must be accessible (for challenge validation)
- No firewall blocking HTTP traffic

**Diagnosis**:

```bash
# Check Gateway external IP
kubectl get svc envoy-gateway-proxy

# Test domain resolution
nslookup example.com

# Test HTTP access
curl http://example.com/.well-known/acme-challenge/test
```

**Solution**:

Ensure Gateway has HTTP listener:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: envoy-gateway
spec:
  gatewayClassName: envoy-gateway
  listeners:
  - name: http
    port: 80
    protocol: HTTP
  - name: https
    port: 443
    protocol: HTTPS
```

### Certificate Not Used by Gateway

**Symptom**: Gateway still serving default/invalid certificate

**Diagnosis**:

```bash
# Check TLS secret exists
kubectl get secret <cert-secret-name>

# Check Gateway references correct secret
kubectl get gateway envoy-gateway -o yaml | grep secretName

# Test TLS
openssl s_client -connect example.com:443 -servername example.com
```

**Solution**:

Ensure Gateway listener references the certificate secret:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: envoy-gateway
spec:
  listeners:
  - name: https
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
      certificateRefs:
      - name: my-app-tls-secret
```

## Best Practices

1. **Use Let's Encrypt staging for testing** — Avoid rate limits during development
2. **Monitor certificate expiration** — Set up alerts for expiring certificates
3. **Use ClusterIssuer over Issuer** — ClusterIssuer can be used across all namespaces
4. **Enable auto-provisioning for simplicity** — Let the chart manage Certificate resources
5. **Backup CA private keys** — Keep secure copies of CA secrets
6. **Use DNS-01 for wildcard certificates** — HTTP-01 only supports single domains
7. **Test certificate renewal** — Verify auto-renewal works before expiration

## Advanced Configuration

### Wildcard Certificates

Use DNS-01 challenge for wildcard certificates:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-dns-key
    solvers:
    - dns01:
        cloudflare:
          email: admin@example.com
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: api-token
```

Certificate with wildcard:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-example-com
spec:
  secretName: wildcard-example-com-tls
  issuerRef:
    name: letsencrypt-dns
    kind: ClusterIssuer
  dnsNames:
  - "*.example.com"
  - example.com
```

### Multiple Domains

Single certificate for multiple domains:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: multi-domain
spec:
  secretName: multi-domain-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - example.com
  - www.example.com
  - api.example.com
  - app.example.com
```

### Custom Certificate Duration

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: long-lived-cert
spec:
  secretName: long-lived-tls
  duration: 8760h  # 1 year
  renewBefore: 720h  # 30 days before expiration
  issuerRef:
    name: company-ca
    kind: ClusterIssuer
  dnsNames:
  - internal.example.com
```

<!-- @AI-METADATA
type: chart-docs
title: TLS Certificates Guide
description: Automated TLS certificate management with cert-manager for Envoy Gateway
keywords: tls, certificates, cert-manager, letsencrypt, acme, ssl, https, envoy-gateway
purpose: Guide for configuring TLS certificates with cert-manager integration
scope: Chart
relations:
  - charts/envoy-gateway/README.md
  - charts/envoy-gateway/values.yaml
  - charts/envoy-gateway/examples/production.yaml
  - charts/envoy-gateway/examples/staging.yaml
path: charts/envoy-gateway/docs/certificates.md
version: 1.0
date: 2026-04-09
-->
