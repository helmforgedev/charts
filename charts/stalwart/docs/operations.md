# Operations

## Health

The official endpoints are `/healthz/live` and `/healthz/ready` on the
management listener. Readiness confirms that the DataStore initialized; it does
not confirm coordinator membership. Validate membership and cross-node behavior
separately during HA acceptance.

## Upgrades

Pin a full Stalwart patch tag, review upstream release notes, snapshot the
database-backed configuration, and back up every external store. StatefulSet
RollingUpdate replaces ready pods one at a time; it has no Deployment-style
surge. Keep a PDB and topology placement appropriate to the failure domains.

## Mail delivery

Production mail requires correct public DNS, reverse DNS, SPF, DKIM, DMARC,
TLS certificates, stable public addresses, and deliberate source-IP handling.
Those provider-specific resources are outside the chart boundary.

## Graceful shutdown

Stalwart handles SIGTERM and drains sessions. Increase
`terminationGracePeriodSeconds` for long-lived IMAP sessions. Custom lifecycle
hooks are available but should not mask termination failures.

## Troubleshooting

Inspect pod events and previous logs before retrying. An `operation not
permitted` failure at process exec usually means the image's
`NET_BIND_SERVICE` file capability was removed from the bounding set.
