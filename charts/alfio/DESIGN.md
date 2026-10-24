<!-- SPDX-License-Identifier: Apache-2.0 -->

# alf.io Chart Design

## Scope

This chart deploys the official alf.io image as a single Spring Boot application
with PostgreSQL. It owns the Kubernetes workload, HTTP Service, optional Ingress,
database credential wiring, default ingress isolation, and an optional HelmForge
PostgreSQL dependency.

## Architecture

One `Deployment` serves the public ticketing UI, administrator UI, and API. A
named `http` container port connects the process to the Service. The Service is
the stable in-cluster endpoint and an optional Ingress provides external HTTPS.
All durable event, ticket, attendee, invoice, and configuration data belongs in
PostgreSQL; the application pod is disposable.

The default release includes the PostgreSQL subchart. Operators can disable it
and supply an external PostgreSQL endpoint and Secret. A hardened init container
waits for the database listener before the application starts.

## Design Choices and Decisions

- The application remains single-replica with a `Recreate` strategy because
  clustered sessions, schedulers, and concurrent administrative work are not
  validated by this chart.
- `alfio.containerPort` configures both Spring Boot through `SERVER_PORT` and the
  declared container port. `service.port` is independent and targets the named
  port.
- `jdbc-session` is the default additional Spring profile, matching the official
  container example. The launcher adds `spring-boot` itself. The insecure `dev`
  profile is never enabled by default.
- The application filesystem is read-only except for an ephemeral `/tmp` volume.
- Inbound network isolation is enabled by default. Egress is intentionally not
  restricted because alf.io can contact payment, email, webhook, and external
  database services selected by the operator.

## Production Boundary

The chart provides a secure Kubernetes baseline, but operators own DNS, TLS,
Ingress controller policy, resource sizing, PostgreSQL availability and backup,
payment-provider configuration, email delivery, and disaster recovery. For
production, configure `alfio.baseUrl`, use an existing database Secret, and
prefer an externally managed PostgreSQL service when platform guarantees are
required.

## Security Boundary

The chart uses a pinned official image, disables service-account token mounting,
drops Linux capabilities, prevents privilege escalation, enforces non-root UID
and GID `1001`, uses `RuntimeDefault` seccomp, and enables a read-only root
filesystem. Database passwords are read from a Secret. NetworkPolicy limits
inbound traffic to the application listener but does not authenticate clients or
replace TLS, WAF, payment-provider, or database controls.

Version `2.0-M5-2609` includes upstream fixes for authorization, SSRF, password
change, API-key role, sponsor scan, and promotion-code issues. Operators remain
responsible for tracking later upstream releases.

## Observability Boundary

Startup, liveness, and readiness probes use `/healthz`. Application and init
container logs are available through Kubernetes. The chart does not create a
metrics scraper, alerting rules, dashboards, or distributed tracing components;
connect alf.io logs and platform metrics to the cluster observability stack.

## Known Gaps

- Horizontal application scaling is not validated.
- The chart does not create application-level database backups or test restores.
- No chart-managed SMTP, payment provider, object storage, WAF, or certificate
  issuer is included.
- Egress allow-listing is deployment-specific and left to the operator.

## Non-Goals

- Managing alf.io organizations, events, users, tickets, or payment credentials.
- Operating a highly available PostgreSQL cluster.
- Installing or configuring an Ingress controller or certificate authority.
- Guaranteeing payment-provider compliance for an operator deployment.

## Validation

`make validate-chart CHART=alfio` is the mandatory gate. It covers dependency
resolution, strict linting, every `ci/` scenario, unit tests, kubeconform,
Artifact Hub lint, and behavioral k3d installs. The chart-owned runtime smoke
test verifies the exact image, process/listener wiring, named Service target,
and the application `/healthz` response through the Service.
