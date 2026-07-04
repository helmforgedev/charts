# Kibana Elasticsearch Connectivity

By default, Kibana deploys the HelmForge Elasticsearch subchart and connects to
its generated in-cluster Service:

```yaml
bundledElasticsearch:
  enabled: true
```

## External Elasticsearch

Disable the bundled dependency when connecting to a separately operated
Elasticsearch cluster:

```yaml
bundledElasticsearch:
  enabled: false

elasticsearch:
  hosts:
    - http://elasticsearch:9200
```

For production, operate Elasticsearch separately and keep the subchart disabled.

## Secured Elasticsearch

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
```
