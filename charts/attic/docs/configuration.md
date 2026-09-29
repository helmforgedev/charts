# Attic configuration

The chart renders upstream `server.toml` from explicit values and keeps secret
material in environment variables. Attic rejects unknown TOML fields, and an
init container runs `atticd --mode check-config` before every API start.

## Canonical URLs and hosts

`config.apiEndpoint` is the address clients store after login. It must be a
complete HTTP(S) URL ending in `/`. When TLS terminates at an Ingress or
Gateway, use that public HTTPS URL, not the internal Service address.

`config.allowedHosts` constrains accepted Host headers. Include each public
hostname. A request with another host returns an error even when Kubernetes
networking and TLS are otherwise correct.

`config.substituterEndpoint` is optional. Set it only when Nix clients download
from a different public address than the API endpoint.

## Chunking and compression

Attic splits large NAR archives into chunks for global deduplication. The
defaults mirror upstream: 64 KiB threshold, 16 KiB minimum, 64 KiB average and
256 KiB maximum. Changing these values changes future chunk boundaries and can
temporarily reduce deduplication. Treat them as lifecycle settings.

Supported compression algorithms are `none`, `brotli`, `zstd` and `xz`. Zstd
provides the default balance of CPU and size. Leave `level` null to use the
upstream algorithm-specific default.

## Database and storage pairing

The supported pairs are deliberate:

| Mode | Database | Object storage | API replicas |
| --- | --- | --- | --- |
| `standalone` | SQLite | Local PVC | Exactly 1 |
| `distributed` | PostgreSQL | S3-compatible | 1 or more |

The validation helper rejects cross-pairs. Local storage is not made safe by a
ReadWriteMany volume because Attic's SQLite database and process lifecycle are
still single-instance concerns.

## Environment overrides

The chart maps Secret keys to the upstream variables for database, JWT and S3
credentials. `extraEnv` is available for supported upstream variables not yet
modeled, but it must not replace the typed values contract for ordinary use.

## JWT claims

Optional issuer and audience binding narrows accepted tokens. Changing either
setting invalidates tokens without matching claims. All API replicas must share
the same signing or verification material.

HS256 lets every API replica sign and verify. RS256 can separate signing from
verification: API replicas can receive only the public key while an isolated
administrative environment retains the private key.

## Proof of possession

`requireProofOfPossession` prevents an uploader from claiming access to an
already stored NAR merely by knowing its hash. It is enabled by default and
should remain enabled in multi-tenant deployments.

## Configuration changes

Review a rendered configuration before upgrading:

```bash
helm template attic ./charts/attic -f production.yaml \
  --show-only templates/configmap.yaml
```

Validate the live non-secret configuration:

```bash
kubectl -n attic get configmap attic -o jsonpath='{.data.server\.toml}'
```

Never paste Secret values into issue reports, logs or rendered manifests.
