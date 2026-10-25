<!-- SPDX-License-Identifier: Apache-2.0 -->

# Ghost Security

## Default Runtime Controls

The Ghost pod runs as UID and GID 1000 with `RuntimeDefault` seccomp. It prevents privilege escalation, drops all Linux
capabilities, mounts the image filesystem read-only, and disables Kubernetes API token automounting. The database wait
init container uses an independent non-root context. The writable content and temporary filesystems are explicit and
bounded when they use `emptyDir`.

Changing these defaults transfers responsibility for verifying the official image's permissions and the cluster's pod
security policy to the operator.

## Credentials

Prefer `database.external.existingSecret` or `externalSecrets.items` to inline database passwords. Prefer
`backup.s3.existingSecret` for backup credentials. Restrict Secret read permissions outside this chart; Ghost does not
need Kubernetes API access. Rotate a credential by updating its Secret or ExternalSecret source. The Deployment
credential checksum triggers a rollout when chart-managed credential inputs change.

## Network Isolation

`networkPolicy.enabled` limits inbound traffic to the named Ghost HTTP port. Enabling
`networkPolicy.egress.enabled` also allows DNS plus the configured database path. Bundled MySQL is selected by pod
labels. External MySQL requires `networkPolicy.egress.externalDatabaseCIDR`; add any SMTP, S3, webhook or external API
destinations through `networkPolicy.egress.extraEgress`.

## TLS and Application Security

Terminate TLS at an Ingress or Gateway managed by the platform and set `ghost.url` to the canonical HTTPS URL. Keep the
Ghost image pinned, review upstream release notes, validate themes and custom adapters, and protect the Ghost Admin
endpoint with the organization's access and monitoring controls.
