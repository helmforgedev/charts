# BookLore Chart — Design Document

## Architecture

BookLore is a Spring Boot (Java) application with an Angular frontend bundled
into a single container. It uses MariaDB as its database backend and stores
library data on a local filesystem path.

## Container layout

The official image `ghcr.io/booklore-app/booklore` runs as a single process
serving both the API and the static Angular frontend on a configurable port
(default 6060).

### Volumes

- `/app/data` — library data, configuration, cover images, and metadata cache.
- `/bookdrop` — optional drop folder for automatic book imports.

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| BOOKLORE_PORT | 6060 | HTTP listen port |
| DATABASE_URL | auto-generated | Full JDBC connection URL |
| DATABASE_HOST | mariadb | MariaDB host |
| DATABASE_PORT | 3306 | MariaDB port |
| DATABASE_NAME | booklore | Database name |
| DATABASE_USERNAME | root | Database user |
| DATABASE_PASSWORD | (secret) | Database password |
| LOG_LEVEL | INFO | Application log level |
| ROOT_LOG_LEVEL | INFO | Root log level |
| REMOTE_AUTH_ENABLED | false | Enable proxy auth headers |
| FORCE_DISABLE_OIDC | false | Force disable OIDC |

## Database

The chart deploys MariaDB as a HelmForge subchart by default. The application
uses Flyway for schema migrations which run automatically on startup.

## Health checks

BookLore serves a basic health endpoint at `/`. The chart uses HTTP GET probes
with a generous startup probe (up to 6 minutes) to accommodate Java warm-up.

## Security

- Container starts as root (UID 0) because the upstream entrypoint uses
  `addgroup`/`adduser` to create a non-root user, then drops privileges via
  `su-exec` to the configured USER_ID/GROUP_ID (default 1000:1000).
- Capabilities dropped (ALL).
- Seccomp profile: RuntimeDefault.
- ServiceAccount token not mounted by default.
