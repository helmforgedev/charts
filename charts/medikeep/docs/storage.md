# Storage

MediKeep persists structured records in PostgreSQL and stores files on local mounted paths.

## PostgreSQL

The bundled PostgreSQL dependency is enabled by default:

```yaml
postgresql:
  enabled: true
  auth:
    database: medical_records
    username: medapp
```

Use an external database when you already operate PostgreSQL:

```yaml
postgresql:
  enabled: false

database:
  external:
    host: postgres.example.com
    name: medical_records
    username: medapp
    existingSecret: medikeep-db
    existingSecretPasswordKey: password
```

## File Volumes

The chart separates MediKeep writable paths:

```yaml
persistence:
  uploads:
    enabled: true
    size: 20Gi
  backups:
    enabled: true
    size: 20Gi
  logs:
    enabled: false
```

Back up PostgreSQL and both uploads and backups PVCs together. A database-only backup is not enough if users attach lab files or photos.
