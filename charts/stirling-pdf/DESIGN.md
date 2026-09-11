# Stirling PDF design

## Runtime boundary

The official full image preserves native authentication and OCR/office tools. The chart does not rebuild the application
or replace its entrypoint. An init container seeds `/usr/local/bin` into an emptyDir because the upstream entrypoint
updates tool links. An unseeded volume would hide Ghostscript, OCR and UNO commands. Temporary, home, log and tool
volumes allow a read-only image filesystem without root.

## State and availability

One claim is declared once and mounted through configs, customFiles and pipeline subpaths. H2 contains authentication
state and persisted API keys. Community remains a single writer with Recreate. Neither extra replicas nor RWX storage
make H2 a distributed database. Retention protects ordinary Helm uninstall, while namespace deletion and storage failure
require independently retained backups.

## Authentication and entitlement

Native login is mandatory. Initial passwords are retained through Helm lookup; existing Secrets are preferred for
GitOps. ESO uses canonical items. Changing initial credentials does not overwrite existing accounts. The native OAuth
success handler requires a valid paid license for fresh installs. Grandfathering is a historical upgrade exception; the
chart does not manufacture eligibility or claim untested licensed integrations.

## Metrics contract

Management stays authenticated on a separate port. The native MeterFilter permits only http.requests, exported as
http_requests_total with method, URI and session labels. JVM, GC and conversion latency are not promised. The supported
ServiceMonitor schema cannot express X-API-KEY. A raw additionalScrapeConfigs Secret references a mounted credential
file; it does not misuse Bearer authentication, put API keys in ConfigMaps or disable application security.
