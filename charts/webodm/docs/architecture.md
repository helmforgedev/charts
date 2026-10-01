# Architecture

WebODM runs as one web Deployment and one or more Celery worker pods. They
share `/webodm/app/media`, PostgreSQL/PostGIS stores metadata, and Redis carries
Celery messages and results. A private NodeODM Deployment performs processing.

The web pod stays singleton because its upstream startup script runs database
migrations, grid synchronization, Celery Beat, cron, NGINX, and Gunicorn. The
Recreate strategy prevents overlapping schedulers during upgrades.

The processor registration hook waits for PostgreSQL and authenticated NodeODM
health, then uses `manage.py addnode`. The processor token is never placed in a
ConfigMap or command-line value.
