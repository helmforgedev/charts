<!-- SPDX-License-Identifier: Apache-2.0 -->
# Countly — Chart Design

Design notes for the HelmForge `countly` chart. Countly is a product-analytics
platform (event tracking, crash reporting, dashboards, plugin system).

## Application shape

The Countly server bundles its API and dashboard (frontend) in the app image,
served via the Service on port 80. It is backed entirely by **MongoDB** — there
is no SQL datastore.

## Datastore

- **MongoDB** (bundled subchart, `mongodb.enabled`) is the single source of truth
  for events, app data, dashboards and plugin state. Point at a managed MongoDB by
  disabling the subchart and supplying connection details.
- MongoDB readiness can be slow to come up on constrained/arm64 nodes (the
  `mongosh` ping probe); an init/readiness gate keeps Countly from starting before
  the database accepts connections.

## Persistence

Countly state lives in MongoDB (which has its own persistent volume via the
subchart). The app tier is stateless beyond MongoDB and configuration.

## Configuration & secrets

MongoDB credentials come from the subchart/existing secret; never templated into
ConfigMaps. Plugin configuration and app settings are passed via values/env.

## Scaling boundaries

The app tier can run multiple replicas if the datastore supports it, but the
default is a single replica fronted by MongoDB. Scale MongoDB (replica set) for
data resilience.

## What this chart deliberately does NOT do

- No SQL datastore (MongoDB only).
- No embedded MongoDB in the app pod (bundled subchart or external).

## References

- Project: <https://count.ly> · <https://github.com/Countly/countly-server>
- See [`docs/`](docs/) and [`examples/`](examples/).
