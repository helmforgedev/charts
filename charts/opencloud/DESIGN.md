# OpenCloud design

## Native runtime

Use the official image and native server command. Initialization precedes the public server and uses the same UID1000
and persistent config/data. The generated YAML coordinates many internal identities and secrets; a password Secret
alone cannot reconstruct it. Native IDP keys created during server startup are also part of the recovery unit.

## Filesystem contract

A single PVC keeps config and data together. Init mounts its root and creates the directories before application
subPath mounts are used. The image's native setfattr/getfattr tools check user extended attributes on the actual data
mount. This establishes basic capability, not distributed locking or backup correctness. Recovery must separately
prove xattr-preserving restore and native authenticated file access.

## TLS and identity

The canonical HTTPS URL serves browser redirects and the application's own issuer validation. Native TLS uses an
operator Secret or an initially generated retained private certificate. A pod-local trust bundle combines image
roots with explicit private CAs. No insecure certificate flags are enabled. The internal default origin resolves to
loopback inside the singleton to avoid waiting for Service readiness during self-discovery.

Production should use a stable public hostname and externally managed certificate lifecycle. Retained TLS identity
does not renew itself when chart values change. Edge TLS termination is supported only with the same external HTTPS
issuer and actual trusted connectivity back to it.

## Availability boundary

One monolithic replica with Recreate avoids concurrent writers to embedded identity/storage state. Metrics and HA
cannot be inferred from increasing replicas or exposing the debug listener. The debug configuration endpoint remains
private. The metrics extension filters exact GET /metrics through an official Node sidecar and retains native Bearer authentication.
Runtime checks prove credential denial, configuration-path denial and actual Prometheus scraping.

## Behavioral acceptance

The MVP fixture must verify explicit CA trust, native browser OIDC, Graph identity/personal drive discovery and real
WebDAV upload/download/deletion with exact bytes. Anonymous and invalid-token file access must fail. Later acceptance
must exercise retained identity and files across replacement, followed by a fresh-volume restore preserving xattrs.
