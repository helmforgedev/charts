# OpenSign external services

## External MongoDB

Disable `mongodb.enabled`, enable `externalMongodb.enabled`, and provide either
an existing Secret or a URI. The database user needs read/write access to the
OpenSign database. TLS and replica-set parameters belong in the URI.

```yaml
mongodb:
  enabled: false
externalMongodb:
  enabled: true
  existingSecret: opensign-mongodb
  existingSecretUriKey: mongodb-uri
```

If NetworkPolicy is enabled and MongoDB is outside the namespace, add a precise
`networkPolicy.extraEgress` rule for its namespace, pod, or IP block and TCP
port 27017.

## S3-compatible storage

Set `storage.type=s3` and provide the bucket, endpoint, public base URL, region,
and credentials. The base URL must be reachable by browsers downloading signed
documents. Restrict bucket credentials to the required object operations.

## SMTP

Enable SMTP only after supplying the host, sender address, and password. Port
465 selects implicit TLS in OpenSign; port 587 normally uses submission with
TLS negotiation. Add private SMTP destinations to `networkPolicy.extraEgress`.

## External Secrets Operator

Set `secrets.existingSecret` to the target Secret name, enable
`externalSecrets`, select a SecretStore or ClusterSecretStore, and map the
required master key plus any configured certificate, SMTP, or S3 keys through
`externalSecrets.items`.
