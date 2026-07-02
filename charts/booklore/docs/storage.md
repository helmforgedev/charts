# Storage

BookLore uses two filesystem paths for persistent data:

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

## BookDrop volume (`/bookdrop`)

Optional import folder. Place EPUB, PDF, or comic files here and BookLore
will automatically import them into the library.

```yaml
persistence:
  bookdrop:
    enabled: true
    size: 5Gi
```

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
