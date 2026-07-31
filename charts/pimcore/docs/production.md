# Production operations

Use an immutable project image, disable bootstrap and project persistence, and
store public assets on RWX or project-configured object storage. Environments
belonging to the same registered instance must reuse the product key, instance
identifier, and encryption secret. Application, administrator, and Mercure
credentials may remain environment-specific.

Enable workers and maintenance only after schema installation. Scale web and
workers independently. Configure resource requests from observed PHP-FPM and
queue behavior, not generic presets.

Back up MariaDB and assets in one recovery window. Retain image digests,
configuration, encryption/registration values, and the Composer lock file.
Test restores and application migrations before every version upgrade.

Monitor pod availability, HTTP runtime probes, PHP-FPM errors, Messenger
failure transports, maintenance completion, MariaDB health, RabbitMQ queue
depth, and asset-volume capacity.

Before upgrading, read Pimcore upgrade notes, build and test a new immutable
image, run database backups, execute migrations once, then roll web and worker
deployments. Never allow every replica to race the same migration.
