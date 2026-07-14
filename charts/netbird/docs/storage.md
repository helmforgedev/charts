# NetBird storage

The chart persists NetBird server data under `/var/lib/netbird` by default.

With the default sqlite store, keep `server.replicaCount: 1`. Use an external `postgres` or `mysql` store before scaling the server Deployment horizontally.

Back up the PersistentVolumeClaim before chart upgrades. If you use an external database, include the database backup and the mounted NetBird data directory in the same recovery plan.
