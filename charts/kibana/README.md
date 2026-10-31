# Kibana

Kibana is the Elastic Stack analytics and visualization UI for Elasticsearch.

This HelmForge chart deploys Kibana with the official Elastic image, optional
Wolfi image hardening, secure Elasticsearch credential wiring, optional
HelmForge Elasticsearch subchart support, and static encryption key support.

It also includes Gateway API, dual-stack services, NetworkPolicy, PDB, External Secrets Operator integration, and focused Helm tests.

NetworkPolicy supports `networkPolicy.extraEgress` for appending egress rules
without replacing the generated DNS, Elasticsearch, and
`networkPolicy.egress.extra` controls.

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install kibana helmforge/kibana
```

Elastic recommends running the same Elastic Stack version across Kibana and
Elasticsearch. The default chart version targets Kibana `9.5.1`.

## HelmForge Elasticsearch Subchart

The chart deploys HelmForge Elasticsearch by default so local and validation
installs are self-contained:

```yaml
bundledElasticsearch:
  enabled: true

bundled-elasticsearch:
  image:
    tag: "9.5.1"
```

For production, keep `bundledElasticsearch.enabled=false` and connect to an
independently operated Elasticsearch cluster.

## Configuration

The application listener and Kubernetes Service port are independent:

| Purpose | Process listener | Service port |
| --- | --- | --- |
| Kibana HTTP | `containerPorts.http` (default `5601`) | `service.port` (default `5601`) |

Changing `containerPorts.http` writes Kibana's official `server.port` setting,
updates the container port and NetworkPolicy, and keeps probes on the named
`http` port. The Service always targets that named port, so `service.port` may
be changed independently.

```yaml
containerPorts:
  http: 15601
service:
  port: 15602
```

## Upgrade compatibility

Chart 1.2 keeps the legacy `service.targetPort: http` value upgrade-compatible;
the Service routes to the named listener managed by `containerPorts.http`.
A retained integer or string target equal to `containerPorts.http` is also
accepted. Only a divergent target is rejected with migration guidance so
routing cannot silently diverge from Kibana's real listener.

The bundled Elasticsearch dependency moved from 1.x to 2.x. Export the release
overrides, then edit `retained-values.yaml` to move custom
`bundled-elasticsearch.resources` settings to
`bundled-elasticsearch.master.resources`. The Elasticsearch dependency schema
rejects the obsolete path instead of ignoring it. Review the Elasticsearch 2.x
storage and security contracts before upgrading a persistent bundled cluster.

Do not upgrade from chart 1.1.x with `--reuse-values` alone. It can omit the
newer `networkPolicy` parent map and make template rendering fail at
`.Values.networkPolicy.enabled`. Export the release overrides with
`(umask 077 && helm get values RELEASE -o yaml > retained-values.yaml)` so the
file is created with owner-only permissions. Apply the Elasticsearch value
migration described above, then preview with
`helm upgrade RELEASE helmforge/kibana --reset-values -f retained-values.yaml --dry-run`,
then repeat that command without `--dry-run`. Use this migrated-file procedure
with every Helm version for releases retaining the obsolete Elasticsearch path.
The preview can contain rendered Kubernetes Secrets. Run it only in a trusted
environment and keep its output out of logs. Use an equivalent owner-only
creation method on non-POSIX systems and remove `retained-values.yaml`
immediately after the upgrade.

## Production Notes

Use static encryption keys for HA deployments. Kibana uses these keys for
sessions, reporting, and encrypted saved objects. Rotating pods without stable
keys can invalidate sessions and break encrypted object access.

```yaml
replicaCount: 2
encryptionKeys:
  existingSecret: kibana-encryption-keys
```

For secured Elasticsearch clusters, use either basic auth or an Elasticsearch service account token:

```yaml
bundledElasticsearch:
  enabled: false

elasticsearch:
  hosts:
    - https://elasticsearch:9200
  auth:
    type: serviceAccountToken
    existingSecret: kibana-elasticsearch-token
  tls:
    enabled: true
    certificateAuthoritiesSecret: elasticsearch-ca
    verificationMode: certificate
```

## Hardened Image

Elastic publishes a Wolfi-based Kibana image. Enable it with:

```yaml
image:
  flavor: wolfi
```

## Gateway API

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: shared-gateway
      namespace: gateway-system
  hostnames:
    - kibana.example.com
```

## Parameters

| Name | Description | Default |
| --- | --- | --- |
| `image.repository` | Official Elastic Kibana image repository | `docker.elastic.co/kibana/kibana` |
| `image.wolfiRepository` | Official Elastic Kibana Wolfi image repository | `docker.elastic.co/kibana/kibana-wolfi` |
| `image.flavor` | Image flavor: `default` or `wolfi` | `default` |
| `image.tag` | Kibana image tag | `9.5.1` |
| `replicaCount` | Number of Kibana replicas | `1` |
| `containerPorts.http` | Kibana `server.port` application listener | `5601` |
| `service.port` | Kubernetes Service port | `5601` |
| `elasticsearch.hosts` | External Elasticsearch URLs used when bundled mode is disabled | `[http://elasticsearch:9200]` |
| `bundledElasticsearch.enabled` | Enable HelmForge Elasticsearch dependency | `true` |
| `elasticsearch.auth.type` | Elasticsearch auth mode: `none`, `basic`, `serviceAccountToken` | `none` |
| `elasticsearch.auth.existingSecret` | Secret containing Elasticsearch credentials | `""` |
| `elasticsearch.tls.enabled` | Configure Elasticsearch CA trust | `false` |
| `encryptionKeys.existingSecret` | Secret containing Kibana encryption keys | `""` |
| `waitForElasticsearch.enabled` | Wait for the first Elasticsearch endpoint before starting Kibana | `true` |
| `service.ipFamilyPolicy` | Dual-stack ipFamilyPolicy | `null` |
| `ingress.enabled` | Create Kubernetes Ingress | `false` |
| `gateway.enabled` | Create Gateway API HTTPRoute | `false` |
| `networkPolicy.enabled` | Create NetworkPolicy | `false` |
| `externalSecrets.enabled` | Create ExternalSecret for Kibana secrets | `false` |
| `serviceMonitor.enabled` | Create ServiceMonitor | `false` |

## Validation

```bash
helm dependency build charts/kibana
helm lint --strict charts/kibana
helm unittest charts/kibana
helm template kibana-test charts/kibana | kubeconform -strict -summary
```

## Documentation

- [Design](./DESIGN.md)
- [Production guide](./docs/production.md)
- [Elasticsearch connectivity](./docs/elasticsearch.md)
- [Networking](./docs/networking.md)
- [External Secrets](./docs/external-secrets.md)

### Security Scan: `kibana`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **88.333336%** |

Security posture: acceptable.
