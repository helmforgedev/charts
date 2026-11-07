# Primary object storage

Nextcloud can store user file contents in an exclusive S3-compatible bucket
while retaining application code, configuration, custom applications and themes
on the application PVC. PostgreSQL remains authoritative for filenames,
directories, shares and the mapping from file IDs to object keys. The database,
PVC and bucket therefore form one recovery boundary.

Never enable primary object storage on an existing installation that currently
uses local file storage. Upstream Nextcloud warns that doing so makes existing
files inaccessible. This chart supports new installations and migrations where
the source Nextcloud instance already uses the same primary object store.

## Wasabi and other S3-compatible providers

Create an exclusive private bucket and a Kubernetes Secret before installing:

```bash
kubectl -n nextcloud create secret generic nextcloud-primary-object-store \
  --from-literal=access-key='<access-key>' \
  --from-literal=secret-key='<secret-key>'
```

Configure the chart independently from `backup.s3`:

```yaml
primaryObjectStore:
  enabled: true
  provider: s3
  endpoint: https://s3.wasabisys.com
  port: 443
  useSsl: true
  region: us-east-1
  bucket: nextcloud-data
  usePathStyle: false
  objectPrefix: "urn:oid:"
  storageClass: STANDARD
  legacyAuth: false
  autocreate: false
  existingSecret: nextcloud-primary-object-store
  existingSecretAccessKeyKey: access-key
  existingSecretSecretKeyKey: secret-key
```

Use `usePathStyle: true` for MinIO and other providers that require path-style
requests. The endpoint accepts a hostname or an `http://`/`https://` URL without
a path. The URL scheme must agree with `useSsl`. Plain HTTP is suitable only for
a trusted isolated test network.

The chart supplies the official image's `OBJECTSTORE_S3_*` contract to both the
application and the background CronJob. The application mounts static
credentials from the Secret as files. The CronJob bypasses the image entrypoint,
so it reads the same Secret keys through Kubernetes `secretKeyRef` environment
sources. Credential values are never placed in chart values or Pod environment
literals.

## External Secrets

The canonical `externalSecrets.items` contract can create the Secret consumed by
`primaryObjectStore.existingSecret`:

```yaml
primaryObjectStore:
  enabled: true
  endpoint: https://s3.wasabisys.com
  bucket: nextcloud-data
  existingSecret: nextcloud-primary-object-store

externalSecrets:
  enabled: true
  items:
    - name: primary-object-store
      spec:
        secretStoreRef:
          name: production-secrets
          kind: ClusterSecretStore
        target:
          name: nextcloud-primary-object-store
        data:
          - secretKey: access-key
            remoteRef: {key: nextcloud/primary-s3-access-key}
          - secretKey: secret-key
            remoteRef: {key: nextcloud/primary-s3-secret-key}
```

## Workload identity

Set `credentialsFromPodIdentity: true` to omit static S3 credentials. The chart
assigns the application and CronJob to the same dedicated ServiceAccount:

```yaml
primaryObjectStore:
  enabled: true
  endpoint: s3.us-east-1.amazonaws.com
  region: us-east-1
  bucket: nextcloud-data
  credentialsFromPodIdentity: true
  serviceAccount:
    create: true
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/nextcloud
    automountServiceAccountToken: true
```

The identity must grant the exact bucket permissions required by Nextcloud. A
non-AWS provider must explicitly support the AWS SDK credential chain used by
the Pod identity; otherwise use an existing Secret.

## NetworkPolicy

Kubernetes NetworkPolicy cannot select an external destination by DNS name.
When `networkPolicy.enabled=true`, supply provider CIDRs or in-cluster selectors
through `primaryObjectStore.networkPolicyEgress`; rendering fails when the rule
is missing.

IRSA (IAM Roles for Service Accounts) also requires HTTPS egress to the AWS STS
endpoint selected by the SDK. Add that endpoint's CIDR ranges to
`primaryObjectStore.networkPolicyEgress`. If the SDK uses the global
`sts.amazonaws.com` endpoint, add its CIDR ranges. To allow only the regional
STS endpoint, configure IRSA to use regional STS before restricting the egress
rules.
EKS Pod Identity requires access to the Pod Identity Agent endpoint in addition
to the S3 endpoint. Include those credential-provider destinations in the same
explicit egress list when the selected identity mechanism needs them.

For example:

```yaml
primaryObjectStore:
  networkPolicyEgress:
    - to:
        - ipBlock: {cidr: 203.0.113.0/24}
      ports:
        - {port: 443, protocol: TCP}
```

Replace the documentation CIDR with the provider's current published ranges and
manage range changes operationally. DNS egress remains part of the chart's base
policy.

## Upgrade protection

The chart records the enabled primary-storage configuration in a guard Secret.
Every real Helm upgrade reads that Secret and rejects an accidental disable or a
change to the endpoint, bucket, prefix, credential source or other identity
fields. `helm template` alone cannot query the live guard.

For an intentional migration, first stop all writers and complete a provider-
supported data migration. Run the upgrade once and copy the previous
configuration hash from the failure message into:

```yaml
primaryObjectStore:
  protection:
    acknowledgePreviousConfigurationHash: <exact-previous-hash>
```

The acknowledgement is valid only for the recorded previous configuration. The
updated guard receives a new fingerprint, so the same value cannot authorize a
later change. Remove the acknowledgement from retained overrides after the
successful migration.

## Migration from `nextcloud/nextcloud`

This path applies only when the source instance already uses S3 as primary
storage. It does not convert local user files into objects.

1. Record the exact Nextcloud version, database endpoint, Redis endpoint, bucket,
   endpoint, region, object prefix, instance ID and Secret references.
2. Stop web and cron writers and take coordinated database, PVC and bucket
   snapshots. Preserve `config/config.php`, custom applications and themes.
3. Install this chart at the same Nextcloud version with the source PostgreSQL,
   Redis, PVC and primary-object-store settings. Do not point two live instances
   at the database or bucket.
4. Verify non-admin login, WebDAV reads of existing files, new writes, file IDs,
   shares, background jobs and application logs before switching traffic.
5. Keep the source frozen and all snapshots recoverable until acceptance.

Never change `objectPrefix`, bucket or instance database independently. Object
keys are opaque; filenames and directory structure cannot be reconstructed from
the bucket without the matching Nextcloud database.

## Backup boundary

`primaryObjectStore.bucket` contains live user file contents.
`backup.s3.bucket` contains the chart's checksummed database/PVC backup sets and
must be a different bucket. Integrated backups do not copy the primary bucket;
protect it with provider versioning, immutable snapshots or replication and test
recovery of the database, PVC and primary objects together.
