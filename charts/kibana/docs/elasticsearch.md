# Kibana Elasticsearch Connectivity

By default, Kibana connects to an external Elasticsearch endpoint:

```yaml
elasticsearch:
  hosts:
    - http://elasticsearch:9200
```

## HelmForge Elasticsearch Subchart

Enable the bundled HelmForge Elasticsearch subchart for local development or
self-contained test environments:

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

When using a custom release name, set the host to the service rendered by the
aliased dependency:

```yaml
elasticsearch:
  hosts:
    - http://<release-name>-bundled-elasticsearch:9200
```

For production, operate Elasticsearch separately and keep the subchart disabled.

## Secured Elasticsearch

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
```
