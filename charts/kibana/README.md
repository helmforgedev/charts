# Kibana

Kibana is the Elastic Stack analytics and visualization UI for Elasticsearch.

This HelmForge chart deploys Kibana with the official Elastic image, optional
Wolfi image hardening, secure Elasticsearch credential wiring, optional
HelmForge Elasticsearch subchart support, and static encryption key support.

It also includes Gateway API, dual-stack services, NetworkPolicy, PDB, External Secrets Operator integration, and focused Helm tests.

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install kibana helmforge/kibana \
  --set elasticsearch.hosts[0]=http://elasticsearch:9200
```

Elastic recommends running the same Elastic Stack version across Kibana and
Elasticsearch. The default chart version targets Kibana `9.4.2`.

## HelmForge Elasticsearch Subchart

The chart can deploy HelmForge Elasticsearch as an optional dependency for local
or self-contained environments:

```yaml
bundledElasticsearch:
  enabled: true

elasticsearch:
  hosts:
    - http://kibana-bundled-elasticsearch:9200

bundled-elasticsearch:
  image:
    tag: "9.4.2"
```

For production, keep `bundledElasticsearch.enabled=false` and connect to an
independently operated Elasticsearch cluster.

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
| `image.tag` | Kibana image tag | `9.4.2` |
| `replicaCount` | Number of Kibana replicas | `1` |
| `elasticsearch.hosts` | Elasticsearch URLs | `[http://elasticsearch:9200]` |
| `bundledElasticsearch.enabled` | Enable HelmForge Elasticsearch dependency | `false` |
| `elasticsearch.auth.type` | Elasticsearch auth mode: `none`, `basic`, `serviceAccountToken` | `none` |
| `elasticsearch.auth.existingSecret` | Secret containing Elasticsearch credentials | `""` |
| `elasticsearch.tls.enabled` | Configure Elasticsearch CA trust | `false` |
| `encryptionKeys.existingSecret` | Secret containing Kibana encryption keys | `""` |
| `waitForElasticsearch.enabled` | Wait for the first Elasticsearch endpoint before starting Kibana | `false` |
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

### 🟢 Security Scan: `kibana`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **88.333336%** |

> ✅ Security posture acceptable.
