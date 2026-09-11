# Production operations

Use a dedicated HTTPS origin and existing administrator Secret. Restrict document processing to trusted users. Native
login is always enabled. Use dedicated native accounts for automation and rotate or revoke API keys in the app.

Default NetworkPolicy permits same-namespace application HTTP and DNS egress. Select the ingress controller namespace
for a cross-namespace edge. Add narrow extraEgress rules for approved integrations. Remote URL conversion requires
intentional outbound access; broad internet access is not automatic. Preserve native SSRF protection. The CNI must
enforce policies.

Align controller-specific body limits and timeouts with server.maxUploadSize, server.maxRequestSize and
server.connectionTimeoutMilliseconds. Application values do not configure the proxy. A dedicated root hostname is the
default; when using server.basePath, align edge routes and public callbacks with that prefix.

The full image includes English OCR data. Additional language data must come from trusted compatible sources and is not
downloaded automatically. Temporary files disappear with the pod. Processed documents are not a durable document
library; the upstream experimental storage feature is disabled.

Load-test realistic concurrent documents. Native tools share memory with Java, so allocating nearly all memory to heap
can starve OCR and office conversion. Inspect tool diagnostics and readiness rather than disabling probes to hide
failures. Keep API credentials and document contents out of operational logs.

Fresh-install native OAuth SSO and external SQL have upstream license constraints. This Community deployment validates
password authentication and H2; it does not manufacture grandfathered accounts or promise licensed clustering.
