# Storage

BookLore uses three filesystem paths for persistent data.

## Data volume (`/app/data`)

Stores library metadata, cover images, configuration, and internal caches.
This volume is required for data to survive pod restarts.

```yaml
persistence:
  data:
    enabled: true
    size: 10Gi
    storageClass: ""
```

## Books volume (`/books`)

Stores the managed ebook, comic, PDF, and audiobook library. Back up this
volume together with the database and `/app/data`; database metadata alone
cannot restore the book files.

```yaml
persistence:
  books:
    enabled: true
    size: 50Gi
    storageClass: ""
```

## BookDrop volume (`/bookdrop`)

Optional import folder. Place EPUB, PDF, or comic files here and BookLore
will automatically import them into the library.

```yaml
persistence:
  bookdrop:
    enabled: true
    size: 5Gi
```

## Local and network storage

The upstream application supports two explicit storage modes:

- `app.diskType=LOCAL` permits normal file writes and reorganization.
- `app.diskType=NETWORK` disables file writes and reorganization for
  network-attached filesystems whose semantics are not safe for those
  operations.

Use `ReadWriteMany` only with a StorageClass that actually supports concurrent
mounts. Multiple replicas are rejected unless every enabled persistence volume
declares `ReadWriteMany`.

## External database

To use an existing MariaDB instance:

```yaml
mariadb:
  enabled: false

database:
  external:
    host: mariadb.example.com
    port: "3306"
    name: booklore
    username: booklore
    password: "secret"
```
