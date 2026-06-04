<!-- SPDX-License-Identifier: Apache-2.0 -->
# Countly — Configuration

Countly is a product-analytics platform (events, crash reporting, dashboards,
plugins). This chart runs the Countly server (API + dashboard) backed entirely by
**MongoDB** — there is no SQL datastore.

## Key values

| Value | Default | Purpose |
|---|---|---|
| `mongodb.enabled` | `true` | Bundle the HelmForge MongoDB subchart. |
| `mongodb.auth.*` | — | MongoDB database/credentials for the bundled subchart. |
| `image.tag` | appVersion | Countly server image. |
| `ingress.*` | disabled | Expose the dashboard (Service on port 80). |
| `plugins` / app settings | — | Countly plugin and runtime configuration. |

## Datastore

MongoDB is the single source of truth (events, app data, dashboards, plugin
state). Use the bundled subchart for small installs, or point Countly at a
managed MongoDB by disabling the subchart and supplying connection details. The
MongoDB credentials come from the subchart/existing secret, never templated into
a ConfigMap.

On constrained or arm64 nodes the MongoDB readiness probe (a `mongosh` ping) can
be slow to pass on first boot; an init/readiness gate keeps Countly from starting
before MongoDB accepts connections.

## Access

With ingress disabled, port-forward the Service:

```bash
kubectl port-forward svc/<release>-countly 8080:80
# open http://localhost:8080/  and complete the initial setup wizard
```

## Persistence and scaling

Countly's state lives in MongoDB (which has its own persistent volume via the
subchart). Back up MongoDB — it holds all analytics data. Scale MongoDB (replica
set) for resilience; the app tier fronts it.
