# OpenCloud monitoring

Enable metrics.enabled for native Prometheus exposition through a private metrics Service. The native debug listener
remains on 127.0.0.1:9205: it also exposes an unauthenticated configuration endpoint. A small official Node sidecar
forwards only exact GET /metrics, preserving the native Bearer authentication. It returns 404 for /config, debug
paths and query-string variants, and 405 for other methods. It is a path filter, not a synthetic application exporter.

The generated token is retained across upgrades, or set metrics.existingSecret and metrics.tokenKey. Tokens require
at least 16 bytes. Native authentication rejects missing and incorrect credentials. Keep the token private, restrict
metrics.ingressFrom to scraper Pods and use a trusted cluster network; this internal scrape path uses HTTP.

metrics.serviceMonitor.enabled renders Secret-backed Bearer credentials with configurable labels, interval and
scrapeTimeout. The timeout must not exceed the interval. metrics.prometheusRule.enabled adds a target availability
alert and supports additionalRules. Install Prometheus Operator CRDs first and align its selectors with these labels.

The monolithic native registry includes OpenCloud component collectors. Runtime evidence checks
opencloud_proxy_requests_total and opencloud_proxy_build_info, actual Prometheus up=1, and the loaded availability
rule. This does not establish complete coverage of every optional OpenCloud integration. Review native metrics before
adding alert thresholds; a live scrape alone does not prove login or storage health.

To rotate an externally managed metrics token, update its Secret and restart the Deployment so the native server
loads the new environment value. Coordinate scraper updates. Application identity keys are separate from this token.
