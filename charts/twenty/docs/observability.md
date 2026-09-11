# Native observability

`metrics.enabled` enables the upstream Prometheus driver on the server's fixed port 9464. A private Service, optional
ServiceMonitor and optional PrometheusRule expose that native endpoint only to configured NetworkPolicy scrape peers.
The public application proxy does not forward requests to this metrics port.

Server and worker share a Pod for local-file consistency. The native Prometheus port cannot be configured; enabling it
in both processes would cause a bind conflict. This ServiceMonitor therefore covers the server only. The worker uses
native process, authenticated Redis and BullMQ registration checks, with actual SDK job completion in behavioral
acceptance. A probe is not a Prometheus metric.

The metrics profile requires real Prometheus `up=1`, a loaded target-availability rule and a native successful GraphQL
operation counter reflecting CRM traffic. An unrelated Pod must fail to reach metrics while retaining access to public
application health. This runtime profile passed all these checks, including the
retained company, session and attachment after Pod replacement.

Use the native server/worker logs for job failures and startup diagnostics. Private bootstrap output is stored
separately and deleted before successful public startup. Keep authorized access to those diagnostics; they may contain
secrets.

The chart does not ship an OTLP collector or claim worker metrics coverage. Native worker OTLP export needs an
independently validated collector pipeline, including DELTA-to-cumulative conversion before Prometheus counters are
exposed.
