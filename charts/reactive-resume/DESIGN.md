# Reactive Resume architecture

Implementation and behavioral acceptance are in progress.

One Recreate application Pod contains a serialized native bootstrap, the Node
server and an unprivileged NGINX proxy. The official image generates PDFs natively;
Browserless and a privileged browser container are unnecessary for v5. PostgreSQL
is mandatory and can use the HelmForge dependency or an external service.

Local uploads and a retained identity marker share one PVC. An optional S3 bucket
stores native uploads; the PVC still retains the ownership marker. Read-only root
filesystems, UID/GID 1000, dropped capabilities, bounded temporary volumes and
tokenless ServiceAccounts apply to application and helper workloads. Concurrent
application migrations and horizontal scaling are outside the initial contract.

Native enrollment requires an enforcing CNI and trusted namespace policy ownership.
A harmless same-Pod admission check precedes any signup-enabled native listener.
The helper has no database or application credentials and can only probe its TCP
caller's fixed native/control ports. Ordinary operation keeps signup disabled.
The checks reduce initial policy timing uncertainty; they do not replace a
conformant CNI or prove global denial against additive policies and privileged
actors. See [the onboarding contract](docs/onboarding.md).

The image is pinned by digest because the official v5.3.0 tag has been rebuilt
after its Git release tag. Actual runtime revision and dependencies must remain
part of acceptance evidence. Native API resume mutation and real PDF text, followed
by Pod replacement, are the initial functional checks. Recovery, browser HTTPS,
external TLS, optional integrations and the full chart gate remain required.

Authenticated implicit TLS SMTP enables the native mail-dependent account routes.
Without it, the proxy blocks those routes to avoid native log-only token delivery.
Custom OAuth uses the image's standard social-provider API and explicit HTTPS
endpoints with signup closed; native account linking remains authoritative.
The optional private CAs are combined before starting Node and augment process-wide
trust. No TLS verification bypass is exposed.

The recovery profile quiesces the application and restores a database dump and
complete upload archive into fresh destinations, including the hidden identity
marker. Existing authentication, exact resume content, upload hashes and real PDF
output must all pass afterward. Behavioral acceptance has exercised these recovery
checks and the optional SMTP, S3, OAuth, external database and browser integrations.
