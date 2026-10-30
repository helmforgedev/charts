<!-- SPDX-License-Identifier: Apache-2.0 -->
# RustFS

RustFS provides an S3-compatible object API and web console. This chart uses the
HelmForge naming, labels, security, persistence, CI scenarios, and test conventions.
It has no chart dependencies. RustFS is pinned to `1.0.3`, verified against the
[official release](https://github.com/rustfs/rustfs/releases/tag/1.0.3) and
[official image tag](https://hub.docker.com/r/rustfs/rustfs/tags?name=1.0.3).

## Features

- Standalone or distributed StatefulSet topology with retained per-Pod storage.
- Configurable S3 API and console listeners wired to the real RustFS process.
- Generated or existing S3 credentials and a separate distributed RPC Secret.
- Default ingress isolation, named-port Services, and independent TLS Ingresses.
- Product-aware health probes and authenticated S3 content validation on k3d.
- Bucket and site replication setup through the pinned official RustFS CLI.

## Install

```bash
helm install storage oci://ghcr.io/helmforgedev/helm/rustfs \
  --version 1.1.1 \
  --namespace rustfs \
  --create-namespace
kubectl -n rustfs port-forward svc/storage-rustfs-console 9001:9001
```

Open `http://localhost:9001`. The default access key is `rustfsadmin`. Retrieve the
chart-generated secret key with:

```bash
kubectl -n rustfs get secret storage-rustfs -o jsonpath='{.data.secret-key}' | base64 -d
```

For production, supply an existing Secret with `access-key` and `secret-key` entries:

```yaml
auth:
  existingSecret: rustfs-credentials
```

Custom entry names are supported through `auth.existingSecretAccessKeyKey` and
`auth.existingSecretSecretKeyKey`. Credentials are referenced using `secretKeyRef`.
When the chart generates a secret key, it reuses that key from the live Secret on
upgrade. Offline `helm template` cannot look up live Secrets and generates a new
key each time. Use an existing Secret for GitOps. Restart pods after changing
credentials; Secret environment variables are read at container startup.

## Architecture

One StatefulSet implements both storage topologies. The API Service selects all
ready members, the console Service selects ordinal zero in distributed mode, and
a headless Service provides peer discovery. Per-Pod PVCs preserve storage
identity. See [DESIGN.md](DESIGN.md) for trust boundaries, topology decisions,
replication ownership, and production limitations.

## Storage topologies

The default `architecture: standalone` runs one StatefulSet pod with a 10Gi PVC.
Set `persistence.existingClaim` to reuse a standalone PVC. Setting
`persistence.enabled: false` uses ephemeral storage and loses data on pod removal.

For distributed storage, use `architecture: cluster` (or the compatible alias
`architecture: distributed`):

```bash
helm install storage ./charts/rustfs -n rustfs --create-namespace \
  -f charts/rustfs/examples/distributed/values.yaml
```

Create the referenced credentials Secret first. Distributed mode requires at least
four pods, durable storage, and independent PVCs. A headless Service publishes pod
DNS before readiness, and parallel pod startup avoids a bootstrap deadlock.
`clusterDomain` controls internal endpoint FQDNs. Configure pod anti-affinity or
spread constraints for separate failure domains, and size resources for your load.
The chart does not automatically spread pods across nodes.

Cluster members use a shared `RUSTFS_RPC_SECRET`, stored separately in the
`<release>-rustfs-rpc` Secret. `auth.rpcSecret` can supply a value of at least 32
characters; otherwise the chart generates and reuses a random value on upgrades.
For GitOps, provide `auth.rpcExistingSecret` and optionally `auth.rpcSecretKey`
instead. Offline renders generate a fresh RPC key unless an existing Secret or
explicit value is used. Restart all members together according to upstream
rotation guidance when changing this key; do not let cluster members diverge.

Do not change architecture, replica count, release name, or storage layout on an
existing installation. Distributed expansion and migration require an application
level procedure outside this chart. PVCs created by the StatefulSet are retained
when the release is removed. Back up data and test restores before upgrades.

## Upgrading

### To 1.0.3

RustFS 1.0.3 includes bug fixes, stability and performance improvements.
No breaking configuration or values changes are introduced in this release.

Upstream release notes: [1.0.3](https://github.com/rustfs/rustfs/releases/tag/1.0.3).

## Networking

API and console default to container ports 9000 and 9001. `containerPorts.api`
and `containerPorts.console` configure the real RustFS listeners through
`RUSTFS_ADDRESS` and `RUSTFS_CONSOLE_ADDRESS`. `service.port` and
`consoleService.port` change the client-facing Service ports only. The console
Service selects pod zero in distributed mode. Console access is unavailable while pod zero is down; API traffic uses all
ready pods. `config.consoleEnabled: false` removes the console Service and port.

NetworkPolicy is enabled by default. Empty API and console peer lists allow only
Pods in the release namespace; set `networkPolicy.apiIngressFrom` and
`networkPolicy.consoleIngressFrom` before admitting clients or ingress
controllers from other namespaces. Internode RPC shares the named API port.

`ingress` and `consoleIngress` have independent `enabled`, `ingressClassName`,
`annotations`, `hosts`, and `tls` values. Both are disabled by default. See
[the ingress scenario](ci/ingress-values.yaml). TLS terminates at the ingress;
backend traffic is HTTP. Configure `config.externalAddress` for the externally
visible API address. Tune CORS origins for the intended clients.

## Replication

Replication is configured independently of `architecture`. Each destination is an
independent RustFS deployment with its own storage; this chart does not install
remote deployments. Cluster erasure coding protects data inside one deployment.
Bucket/site replication moves data between deployments.

For directional bucket replication, start with
[the bucket example](examples/replication-bucket/values.yaml):

```yaml
architecture: cluster
replicaCount: 4
replication:
  enabled: true
  mode: bucket
  peers:
    - name: backup
      endpoint: https://s3-backup.example.com
      existingSecret: backup-credentials
  buckets:
    - id: uploads-backup
      sourceBucket: uploads
      destinationPeer: backup
      destinationBucket: uploads-backup
      priority: 1
      createBuckets: true
```

Create `backup-credentials` in the release namespace with `access-key` and
`secret-key` entries. Each peer can override these names with `accessKeyKey` and
`secretKeyKey`. Local credentials come from the chart's normal `auth` settings.
Use credentials authorized to administer replication and versioning; site mode
requires root administration credentials at every deployment. Keep credentials
out of values files.

The post-install/post-upgrade Job runs official `rustfs/rc:v0.1.36`, waits for
endpoint readiness, enables versioning on source and destination buckets, then
adds or updates rules by ID. Missing buckets are created only when
`createBuckets: true`. Rule IDs and priorities must be unique per source bucket.
The default flags replicate deletes, delete markers, and existing objects.
`prefix` narrows matching object keys. Other rules on the source bucket are
preserved. Existing rule destinations must match; destination changes fail for
manual migration. Rotating credentials stored in a server-side remote target
also requires the upstream administration procedure.

For whole-site replication, use
[the site example](examples/replication-site/values.yaml), set `mode: site`, leave
`buckets: []`, and supply a stable `localEndpoint` reachable from every peer.
The Job links local plus all configured peers in one operation. On subsequent
runs it checks membership and reads status; it fails if existing endpoints differ.
Only one release should own setup for a site relationship. Validate existing
buckets/IAM for conflicts before linking populated deployments.

Site replication is asynchronous and does not provide DNS/application failover.
Bucket setup also uses asynchronous replication; no synchronous option is exposed.
The Job must reach every endpoint; source servers must reach bucket destinations,
and site peers must reach each other. Use publicly trusted HTTPS endpoints or
cluster endpoints with certificates trusted by both CLI and servers; this chart
does not configure custom CA bundles or skip TLS verification.

The Job has a bounded `activeDeadlineSeconds` and retry limit. Set Helm's
`--timeout` above that deadline (for example `--timeout 15m` with the default
600-second Job deadline). Hooks always wait for Job completion. GitOps controllers
must execute the post-install/post-upgrade hooks to run setup. Successful Jobs
are deleted; failed Jobs are retained until their configured TTL expires.
Disabling replication, deleting a rule from values, or uninstalling the release
**does not remove existing replication rules or site relationships**. These
operations require explicit administration. Setup is applied at install/upgrade,
not continuously reconciled.

See the official [CLI reference](https://github.com/rustfs/cli/tree/v0.1.36/docs/reference/rc)
and [site replication guide](https://github.com/rustfs/docs.rustfs.com/blob/main/content/en/operations/high-availability/site-replication.md).

## Examples

- [Standalone](examples/standalone/values.yaml) for one durable node.
- [Distributed](examples/distributed/values.yaml) for four or more storage members.
- [Cluster alias](examples/cluster/values.yaml) for the equivalent cluster topology.
- [Bucket replication](examples/replication-bucket/values.yaml) for directional rules.
- [Site replication](examples/replication-site/values.yaml) for whole-site relationships.

Every example is a starting point. Replace credentials, storage classes,
endpoints, TLS settings, failure-domain scheduling, and NetworkPolicy peers for
the target environment.

## Configuration

See [values.yaml](values.yaml) for all defaults and [values.schema.json](values.schema.json)
for constraints. Important settings:

| Value | Default | Purpose |
| --- | --- | --- |
| `architecture` | `standalone` | Storage topology |
| `replicaCount` | `1` | Must be one for standalone, at least four for distributed |
| `image.repository` / `image.tag` | `docker.io/rustfs/rustfs` / `1.0.3` | Server image |
| `image.digest` | empty | Overrides tag when supplied |
| `containerPorts.api` | `9000` | Real S3 API and internode RPC listener |
| `containerPorts.console` | `9001` | Real console listener |
| `persistence.size` | `10Gi` | Capacity per pod |
| `persistence.storageClass` | empty | Cluster default; `-` disables dynamic provisioning |
| `config.logLevel` | `info` | RustFS observability logger level |
| `networkPolicy.enabled` | `true` | Restrict API, peer, and console ingress |
| `pdb.enabled` | `false` | Optional disruption budget |
| `resources` | `{}` | Explicit workload requests and limits |
| `extraEnv` / `extraEnvFrom` | `[]` | Additional application configuration |
| `extraManifests` | `[]` | Extra manifests rendered with `tpl` |

The image runs as UID/GID 10001, drops capabilities, uses a read-only root
filesystem, and does not mount a service account token. `/data` is durable; `/logs`
and `/tmp` use temporary volumes. Ship logs externally if retention is required.
Liveness/startup probes use `/health`; readiness uses `/health/ready`. The optional PDB limits voluntary disruptions only;
it does not guarantee storage quorum. User/policy provisioning, Gateway API, and application TLS are outside this chart's scope.
Bucket creation and versioning can be enabled through replication setup.

## Troubleshooting

Start with workload state, storage binding, application logs, and recent events:

```bash
kubectl -n rustfs get statefulset,pod,svc,pvc
kubectl -n rustfs logs statefulset/storage-rustfs --tail=200
kubectl -n rustfs get events --sort-by=.lastTimestamp
helm test storage -n rustfs --logs
```

For distributed startup failures, verify that every Pod resolves the headless
Service and reaches `containerPorts.api`, that PVCs are bound and writable by
UID/GID 10001, and that every member receives the same RPC Secret. If the console
alone is unavailable, inspect ordinal zero and its NetworkPolicy peers.

## Security Scan

### Security Scan: `rustfs`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **88.89%** |

> Security posture acceptable.

This local scan used the default rendered workloads. Findings
include optional resource limits and network isolation; configure these for your
environment. See [validation evidence](docs/validation.md) for scope and limits.

## Validation and provenance

```bash
./test.sh rustfs
helm test storage -n rustfs --logs
```

Every CI scenario is runnable on a local k3d cluster. Files in `ci/fixtures/`
provide external Secrets, an existing PVC, and real RustFS replication peers for
the matching `ci/<scenario>.yaml`. Distributed scenarios use the cluster's default
StorageClass instead of assuming a class named fast-ssd. Replication scenarios
use local test Services; public HTTPS examples remain under `examples/`.

```bash
kubectl config current-context
./charts/rustfs/scripts/validate-runtime.sh k3d-helmforge-<lab> /tmp/rustfs-ci-evidence
```

This chart-local runner creates a separate namespace per scenario, applies its
fixtures, installs the chart, runs Helm health tests and native S3 checks, and
removes the namespace afterward. Replication scenarios execute the real setup
hook, verify object content at every configured peer, then upgrade and rerun the
checks. The native smoke hook can also be invoked by repository tooling:

```bash
node charts/rustfs/scripts/runtime-smoke.mjs <context> <namespace> <release>
```

The maintainer's `make validate-chart CHART=rustfs` target belongs to the private
`helmforgedev/helmforge-ops` repository. The chart-local runner supplements that
gate; it does not claim to replace or pass the private gate.

Health test pods remain available for `helm test --logs` and are replaced on the
next test run. Helm does not manage hook pods during uninstall; remove a retained
test pod explicitly with `kubectl delete pod <release>-rustfs-test -n <namespace>`.
Replication setup Jobs still clean up automatically after success.

CI scenarios cover standalone, distributed, ephemeral, existing claims/secrets,
separate API/console ingress, the cluster alias, and bucket/site replication setup. Unit tests check endpoint generation, console
routing, credentials, storage ownership, port mapping, and selector protection.
See [design](DESIGN.md), [operations](docs/operations.md), and
[validation evidence](docs/validation.md).

Application settings and operational workflows are documented in the official
[RustFS sources](https://github.com/rustfs/rustfs) and
[CLI reference](https://github.com/rustfs/cli/tree/v0.1.36/docs/reference/rc).
Templates use repository-local HelmForge helpers without external chart dependencies.
