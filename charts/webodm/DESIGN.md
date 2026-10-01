# WebODM Chart Design

The chart runs the upstream WebODM webapp and Celery worker as separate
Deployments sharing persistent media. A private, authenticated NodeODM Service
performs photogrammetry processing and is registered by a Helm hook Job.

The web Deployment is intentionally a single replica with a Recreate strategy
because the upstream startup script performs migrations, starts periodic jobs,
and watches geospatial grids. Celery workers may scale when the media claim
supports ReadWriteMany access.

PostgreSQL uses the HelmForge subchart with the official PostGIS image and
enables the PostGIS and raster extensions during initialization. Redis uses the
HelmForge subchart as the Celery broker and result backend. Both may be replaced
with external services through existing Secrets.

The processing API is never exposed publicly. Its generated token is shared
between NodeODM, the registration Job, and the Helm smoke test. Generated
credentials are retained across upgrades through Secret lookup and the Helm
keep policy.
