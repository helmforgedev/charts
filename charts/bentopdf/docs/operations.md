# Browser and availability operations

Use a dedicated HTTPS origin and preserve upstream CSP/COOP/COEP. Localhost is a secure-context exception; plain remote
HTTP is not. Check browser console and network output for WASM failures before changing pod network policies.

CDN requests originate from the browser. Corporate proxies, content filters, TLS interception and extensions may block
them. Offline operation requires an audited image with suitable build-time asset URLs and CSP, followed by validation of
each required workflow.

Tool controls use exact upstream IDs such as compress-pdf or annotation-shape. They affect presentation and do not
enforce permissions. Save downloads to managed client storage; server logs do not contain recovery copies.

Use two replicas and spread them across nodes. PDBs cover voluntary disruptions. Rolling updates need surge capacity.
HPA requires metrics-server and measures serving CPU, not client processing.

Match ServiceMonitor labels to Prometheus selectors and permit its namespace through metrics.ingressFrom. Confirm
nginx_up is one and nginx_http_requests_total increases. Configure target-down alerts separately. stub_status does not
expose per-status HTTP counters.

Restore server state by reinstalling pinned images and values. Back up edge identity configuration and client documents
separately.

<!-- @AI-METADATA
 type: guide
 title: BentoPDF operations
 description: Browser diagnostics, scaling and recovery
 keywords: bentopdf, operations, prometheus
 purpose: Operate browser-local PDF tools
 scope: chart
 path: charts/bentopdf/docs/operations.md
 version: 1.0
 date: 2026-09-10
-->
