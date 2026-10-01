# Operations

Back up PostgreSQL and WebODM media as one consistency domain. Quiesce uploads
and task creation, record the database recovery point, then snapshot the media
claim. NodeODM task data is useful for recovery of in-flight work but does not
replace the WebODM media backup.

Before upgrades, verify upstream migrations, take a coordinated backup, render
the new chart, and exercise a real small processing task. Do not roll back an
application image across incompatible database migrations without restoring a
matching database backup.

Monitor web, worker, PostgreSQL, Redis, processing storage, and NodeODM task
duration. Large projects routinely require more resources than chart defaults.
