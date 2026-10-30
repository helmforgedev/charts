<!-- SPDX-License-Identifier: Apache-2.0 -->
# Apache Superset security

## Secret management

`SECRET_KEY` signs sessions and encrypts sensitive application metadata. Reuse
neither the key nor administrator credentials between environments. Prefer an
operator-managed `superset.existingSecret`; keep it with the PostgreSQL recovery
material. Follow the upstream `PREVIOUS_SECRET_KEY` and
`superset re-encrypt-secrets` procedure for planned rotation.

PostgreSQL, Redis, administrator, and backup credentials enter containers
through Secret references. Connection URLs are assembled in Python with
URL-encoded credentials, so Secret values are not written to the ConfigMap.
Avoid inline passwords in Git even though values support them for development.

## Container controls

The default Superset containers run as UID/GID 1000, deny privilege escalation,
drop every Linux capability, use a read-only root filesystem, and select the
runtime-default seccomp profile. EmptyDir volumes provide the writable home and
temporary directories required by the official image. Dependency wait
containers run as an explicit non-root UID with the same capability and
filesystem restrictions.

The application ServiceAccount has read-only, namespaced Job access while
managed initialization is enabled. Initialization and backup Jobs disable token
mounting. If `init.enabled=false`, application pods also disable token mounting.

## Network controls

NetworkPolicy is enabled by default. It selects every Superset component,
allows ingress only on `web.containerPort`, and permits egress. Restrict ingress
to trusted ingress-controller or monitoring peers. An egress allowlist must
include DNS, PostgreSQL, Redis, required data sources, and the Python package
index only when runtime package installation remains enabled. While
`init.enabled=true`, it must also allow the Kubernetes API server so the
`wait-for-init` container can read the revisioned Job status.

Terminate TLS at a trusted ingress or load balancer. Use PostgreSQL
`verify-full` with a trusted CA and enable Redis TLS for managed services where
supported. Configure proxy headers through the existing Superset proxy-fix
setting only behind a trusted reverse proxy.

## Trusted configuration and images

`superset.extraConfig` is executable Python with the authority of the Superset
process. Review it like application code and place OAuth client secrets in
environment variables sourced from Secrets, not in the ConfigMap.

Use official or controlled derived images under immutable tags. A production
derived image should contain PostgreSQL, Redis, warehouse drivers, and any
browser dependencies required for alerts and reports. Set
`superset.installPythonPackages=false` so pod startup does not download code.

## Operational verification

Monitor authentication failures, administrator changes, role and permission
changes, unexpected data-source connections, Celery failures, and backup Jobs.
Scan the selected image and rebuild derived images when its base or Python
dependencies receive security fixes. Test recovery with the original
`SECRET_KEY`; a database-only restore is incomplete.
