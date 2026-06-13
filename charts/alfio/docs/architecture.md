<!-- SPDX-License-Identifier: Apache-2.0 -->

# alf.io Architecture

alf.io is a Spring Boot ticketing platform backed by PostgreSQL. This chart
keeps that topology explicit: one application pod handles the public ticketing
UI, admin UI, and API, while PostgreSQL owns all durable event, ticket, attendee,
invoice, and configuration data.

## Components

- `Deployment`: runs the official alf.io container image.
- `Secret`: stores generated or supplied database credentials.
- `Service`: exposes HTTP traffic inside the cluster.
- `Ingress`: optional edge route for public ticketing and admin access.
- PostgreSQL subchart: optional database for self-contained deployments.
- Init container: waits for PostgreSQL before starting the application.

## Request Flow

Users reach the application through either an Ingress or a port-forwarded
ClusterIP Service. alf.io serves public event pages, checkout flows, admin
screens, and API endpoints from the same HTTP port. The application then uses a
JDBC connection to PostgreSQL for all persistent state.

## Database Ownership

The bundled PostgreSQL mode is useful when the Helm release should own the
database lifecycle. Production teams commonly disable the subchart and point
alf.io at an externally managed PostgreSQL service so backup, retention,
replication, and maintenance windows are handled by the platform database team.

## Scaling Boundary

This chart intentionally keeps `replicaCount` out of the public values surface.
alf.io is deployed as a single application replica because the chart does not
validate clustered sessions, concurrent scheduler behavior, or multi-pod
administrative workflows. Run one pod and scale the database independently.

## Production Checklist

1. Set `alfio.baseUrl` to the externally reachable HTTPS URL.
2. Use `alfio.profiles=spring-boot`.
3. Use an external PostgreSQL instance or define a backup plan for the bundled
   PostgreSQL volume.
4. Enable Ingress with TLS through the cluster standard.
5. Set CPU and memory requests and limits after load testing expected ticket
   sale traffic.
6. Store database credentials in an existing Secret for GitOps workflows.

