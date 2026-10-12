# QuestDB research

## Upstream and image

QuestDB 10.0.1 is the latest stable upstream release. The chart uses the
official multi-architecture image for Linux amd64 and arm64, pinned to OCI
index digest `sha256:67eaed863ebb2383227919ea9a5499a4a39ceca3862c20b974c84a10e11cdf89`.
The image supplies provenance attestations, but no Cosign signature or SBOM was
found, so this chart does not claim either verification.

The image creates the `questdb` user and group with ID 10001. Runtime testing
confirmed that it starts directly as that user with a read-only root filesystem,
all Linux capabilities dropped, `DO_CHOWN=false`, a writable data volume and a
writable `/tmp`.

## Architecture

QuestDB OSS is a standalone database. Replication, automated failover, native
TLS and advanced authorization are Enterprise features. The chart therefore
creates exactly one StatefulSet replica and does not expose a replica control or
autoscaler that could imply unsupported horizontal scaling.

The complete `/var/lib/questdb` root is persistent. QuestDB relies on memory
mapped files and does not support NFS or distributed filesystems for database
storage. Production deployments should use fast local block storage and follow
upstream capacity-planning guidance.

## Interfaces and security

Port 9000 serves the Web Console, REST, ILP over HTTP and QWP WebSocket. Port
8812 serves PostgreSQL wire, port 9009 serves legacy ILP TCP, and port 9003 is
the minimal health and metrics server. Kubernetes probes use `/status` on port
9003. Metrics use `/metrics` and are opt-in.

The chart replaces insecure upstream default passwords with retained generated
passwords or an existing Secret. Passwords are mounted as files and consumed via
QuestDB's `_FILE` convention. HTTP exposure requires TLS termination at an
Ingress, Gateway or service mesh because QuestDB OSS provides no native TLS.

## Operations and supply chain

Consistent OSS backups require `CHECKPOINT CREATE`, an external copy or volume
snapshot, and `CHECKPOINT RELEASE`. Upgrades require a tested backup and release
note review because on-disk metadata migrations can make rollback unsafe.

The 10.0.1 amd64 image scan found zero critical and three high findings in the
bundled `gosu` Go runtime. Their network-server code paths appear unrelated to
the local privilege-drop helper, but the findings remain part of the upstream
image risk record. The upstream project is Apache-2.0; an open upstream issue
also tracks third-party Web Console asset licensing, reinforcing the decision to
consume rather than repackage the official image.

## Sources

- <https://github.com/questdb/questdb/releases/tag/10.0.1>
- <https://questdb.com/docs/deployment/docker/>
- <https://questdb.com/docs/deployment/kubernetes/>
- <https://questdb.com/docs/configuration/overview/>
- <https://questdb.com/docs/operations/backup/>
- <https://questdb.com/docs/high-availability/overview/>
