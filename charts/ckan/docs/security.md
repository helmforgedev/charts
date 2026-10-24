<!-- SPDX-License-Identifier: Apache-2.0 -->
# CKAN security

## Secrets

Production deployments should provide `ckan.existingSecret`, external database
and Redis Secrets, and backup credentials through a secret manager. The session
and JWT secrets are cryptographic application state. Preserve them across
upgrades and include them in encrypted recovery procedures.

Inline passwords are stored in Kubernetes Secrets, but still exist in Helm
release values. Prefer existing Secrets to avoid placing credentials in values
files or Helm release history.

## Container security

The default UIDs and GIDs match the official CKAN, DataPusher, and Solr images.
Privilege escalation is disabled, Linux capabilities are dropped, seccomp uses
`RuntimeDefault`, and ServiceAccount token mounting is disabled. CKAN's root
filesystem remains writable because the upstream startup script updates
`/srv/app/ckan.ini`; do not enable a read-only root filesystem without a derived
image or writable configuration mount designed for that behavior.

## Network isolation

The default NetworkPolicy exposes the CKAN port, restricts DataPusher and Solr
ports to CKAN pods, and permits egress. Use `networkPolicy.ingressFrom` to limit
the public listener to the ingress controller or trusted namespaces. Replace
`networkPolicy.egress` with rules for DNS, PostgreSQL, Redis, Solr, DataPusher,
and approved remote data sources after inventorying extension requirements.

## External services

External PostgreSQL defaults to TLS through `sslMode: require`; use certificate
verification settings and mounted CA material where available. External Redis
defaults to TLS and always requires a password Secret. Network encryption does
not replace database role separation: configure DataStore read and write roles
according to the upstream CKAN DataStore guidance.

## Extensions and remote resources

Treat CKAN plugins and derived images as executable code. Pin versions, review
their transitive dependencies, scan the final image, and test compatibility
with CKAN 2.12. Resource URLs processed by DataPusher are untrusted input;
restrict network reachability and apply upstream content-size and URL controls
appropriate to the deployment.
