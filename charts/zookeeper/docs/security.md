# ZooKeeper Security

## Overview

This chart provides Kubernetes hardening, optional client SASL authentication,
optional secure client port configuration, External Secrets integration, and
NetworkPolicy controls. It keeps credential and certificate authority ownership
outside the chart so platform teams can use their existing secret management
and PKI workflows.

## Container Hardening

Default workload security settings:

```yaml
podSecurityContext:
  fsGroup: 1000
  fsGroupChangePolicy: OnRootMismatch

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
```

The chart also defaults `serviceAccount.automountServiceAccountToken=false`
because ZooKeeper does not need Kubernetes API credentials for normal operation.

## SASL Client Authentication

Enable SASL/Digest client authentication:

```yaml
auth:
  client:
    enabled: true
    username: app
    password: change-me
```

For production, prefer an existing Secret or ExternalSecret-managed JAAS file:

```yaml
auth:
  client:
    enabled: true
    existingSecret: zookeeper-jaas
    existingSecretJaasKey: jaas.conf
```

The Secret key must contain a ZooKeeper `Server` JAAS login context.

## Secure Client Port

TLS client listener support requires user-provided JKS files:

```yaml
tls:
  client:
    enabled: true
    port: 3181
    existingSecret: zookeeper-client-tls
    keystoreKey: zookeeper.keystore.jks
    truststoreKey: zookeeper.truststore.jks
    existingPasswordsSecret: zookeeper-client-tls-passwords
```

The chart does not generate keystores, truststores, private keys, or CA
material. Store those artifacts in your platform PKI and rotate them through a
normal Secret update plus rolling restart.

## External Secrets

External Secrets Operator can reconcile JAAS or TLS password material:

```yaml
auth:
  client:
    enabled: true

externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  data:
    - secretKey: jaas.conf
      remoteRef:
        key: zookeeper/jaas
```

When TLS is enabled without chart-managed SASL, the default ExternalSecret
target is the TLS password Secret. Set `externalSecrets.target.name` when both
auth and TLS password material should land in a shared Secret.

## NetworkPolicy

Enable NetworkPolicy to restrict traffic:

```yaml
networkPolicy:
  enabled: true
  allowSameNamespace: true
  egress:
    allowDns: true
```

The policy always allows quorum traffic between ZooKeeper pods. Client and
metrics ingress can be restricted with namespace selectors, pod selectors, or
IP blocks under `networkPolicy.client` and `networkPolicy.metrics`.

## Four-Letter Commands

The chart defaults to a limited whitelist:

```yaml
zookeeper:
  fourLetterWordWhitelist: srvr,stat,ruok,mntr,conf,isro
```

Avoid enabling every command in shared environments. Use the smallest set
required for health checks, monitoring, and troubleshooting.

## Security Checklist

- keep `replicaCount` odd for quorum safety
- keep NetworkPolicy enabled in production namespaces
- use SASL or TLS for clients that support it
- store JAAS and TLS password material in an existing Secret or ExternalSecret
- avoid broad four-letter command whitelists
- keep persistent volumes on trusted storage classes

## References

- [Apache ZooKeeper Administrator's Guide](https://zookeeper.apache.org/doc/current/zookeeperAdmin.html)
- [External Secrets Operator](https://external-secrets.io/latest/)
