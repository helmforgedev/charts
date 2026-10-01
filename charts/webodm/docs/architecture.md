# Architecture

WebODM runs as one web Deployment and one or more Celery worker pods. They
share `/webodm/app/media`, PostgreSQL/PostGIS stores metadata, and Redis carries
Celery messages and results. A private NodeODM Deployment performs processing.

The web pod stays singleton because its upstream startup script runs database
migrations, grid synchronization, Celery Beat, cron, NGINX, and Gunicorn. The
Recreate strategy prevents overlapping schedulers during upgrades.

The processor registration hook waits for PostgreSQL, authenticated NodeODM,
and WebODM readiness before it uses `manage.py addnode`. The processor token is
sourced from a Secret and never stored in a ConfigMap. NodeODM and `addnode`
receive it as a process argument, so users with pod exec access can inspect it.
