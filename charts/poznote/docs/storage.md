# Storage

Poznote stores all data in a single directory: the SQLite database, user notes, attachments, and configuration.

## Default Behavior

By default, the chart creates a `5Gi` PersistentVolumeClaim mounted at `/var/www/html/data`.
This PVC holds the entire application state.

## Disabling Persistence

For testing or ephemeral environments, persistence can be disabled:

```yaml
persistence:
  data:
    enabled: false
```

When disabled, data is stored in an `emptyDir` volume and lost when the pod restarts.

## Using an Existing PVC

```yaml
persistence:
  data:
    enabled: true
    existingClaim: my-existing-poznote-pvc
```

## Backup

Poznote supports data export from the web interface (Settings > Export).
The exported ZIP contains HTML and Markdown versions of all notes.

For volume-level backup, use your storage provider's snapshot mechanism or a tool like Velero.
