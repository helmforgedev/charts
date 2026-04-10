# TLS Certificates

This chart handles two distinct certificate concerns: internal TLS for the controller (managed automatically by a certgen job) and application TLS for HTTPS Gateway listeners (managed externally by the user).

## Internal Certificates (Certgen Job)

### Architecture

```
Helm install/upgrade
      │
      ▼
certgen Job (pre-install/pre-upgrade hook)
      │
      ▼
Secret: <release>-certs
      │
      ├→ Controller webhook TLS
      └→ xDS server TLS (controller ↔ proxy communication)
```

The chart runs a `certgen` Kubernetes Job as a Helm pre-install and pre-upgrade hook. This job generates self-signed TLS certificates for:
- The EG controller webhook (required by the Kubernetes API server)
- The xDS gRPC server used for controller-to-proxy communication

### Configuration

```yaml
certgen:
  enabled: true          # Enable the certgen job (required for EG to function)
  image:
    repository: docker.io/envoyproxy/gateway
    tag: v1.7.1
  resources:
    requests:
      cpu: 10m
      memory: 64Mi
    limits:
      cpu: 100m
      memory: 128Mi
```

The generated certs are stored in `<release>-certs` Secret in the same namespace as the chart.

### Verifying Certgen

```bash
# Check certgen job completed
kubectl get job -l app.kubernetes.io/component=certgen

# View certgen logs
kubectl logs job/<release>-certgen

# Verify certs secret was created
kubectl get secret <release>-certs
```

## Application TLS (HTTPS Gateway Listeners)

For HTTPS listeners on your Gateway, you must supply a TLS Secret separately. This chart does **not** create Certificate resources or integrate with cert-manager directly — you manage application certificates externally.

### Using cert-manager (External, Not Chart-Integrated)

Install cert-manager separately, then create a Certificate that produces a Secret, and reference that Secret in your Gateway listener.

#### Install cert-manager

```bash
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

#### Create a ClusterIssuer

Let's Encrypt (production):

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
        gateway:
          parentRefs:
          - name: envoy-gateway
            namespace: default
```

Self-signed (for development/testing):

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned
spec:
  selfSigned: {}
```

#### Create a Certificate

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

#### Reference the Secret in your Gateway listener

Configure the Gateway HTTPS listener via chart values:

```yaml
gateway:
  create: true
  listeners:
    http:
      enabled: true
      port: 80
    https:
      enabled: true
      port: 443
      tls:
        mode: Terminate
        certificateRef:
          name: my-app-tls-secret  # Must exist before EG processes the Gateway
```

Or create the Gateway manually:

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
    tls:
      mode: Terminate
      certificateRefs:
      - name: my-app-tls-secret
```

### Using a Manual TLS Secret

If you manage certificates outside of cert-manager (e.g., from a corporate PKI or manually generated):

```bash
# Create TLS secret from existing certificate files
kubectl create secret tls my-tls-cert \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key
```

Then reference `my-tls-cert` in the Gateway listener as shown above.

### Verifying TLS

```bash
# Check the TLS secret exists
kubectl get secret my-app-tls-secret

# Verify Gateway accepted the listener
kubectl describe gateway envoy-gateway

# Test TLS handshake
openssl s_client -connect app.example.com:443 -servername app.example.com
```

## Monitoring Certificate Expiration

Since application certificates are managed externally, set up your own monitoring. If using cert-manager, it exposes the `certmanager_certificate_expiration_timestamp_seconds` metric that Prometheus can scrape:

```yaml
# Example manual PrometheusRule for cert-manager certificates
- alert: CertificateExpiringSoon
  expr: certmanager_certificate_expiration_timestamp_seconds - time() < 604800
  for: 1h
  annotations:
    summary: Certificate expiring in less than 7 days
```

## Best Practices

1. **Let certgen manage internal certs** — Do not disable the certgen job unless you manage controller certs manually
2. **Use cert-manager for application TLS** — Automated renewal prevents outages
3. **Use Let's Encrypt staging for testing** — Avoid rate limits during development
4. **Wildcard certificates** — Use DNS-01 challenge with cert-manager for `*.example.com`
5. **Ensure Secret exists before Gateway** — The Gateway will not accept an HTTPS listener if the referenced Secret is missing

<!-- @AI-METADATA
type: chart-docs
title: TLS Certificates Guide
description: Internal certgen job and external application TLS configuration for Envoy Gateway
keywords: tls, certificates, certgen, letsencrypt, acme, ssl, https, envoy-gateway, gateway-listener
purpose: Guide for internal cert generation and configuring HTTPS on Gateway listeners
scope: Chart
relations:
  - charts/envoy-gateway/README.md
  - charts/envoy-gateway/values.yaml
  - charts/envoy-gateway/examples/production.yaml
path: charts/envoy-gateway/docs/certificates.md
version: 2.0
date: 2026-04-10
-->
