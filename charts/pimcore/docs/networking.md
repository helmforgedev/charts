# Networking

The public Service selects only the web component and exposes nginx on port 80.
nginx forwards PHP requests to the co-located PHP-FPM process and proxies
`/hub` to the internal Mercure Service.

Ingress and Gateway API HTTPRoutes are optional. Terminate TLS at the routing
layer and pass trusted proxy information appropriate to the cluster.

NetworkPolicy is opt-in. Internal egress rules cover chart-managed MariaDB,
RabbitMQ, optional Redis, Mercure, and DNS. Bootstrap requires outbound HTTPS;
immutable production images do not.

The chart exposes `/healthz` for nginx liveness and `/readyz` for PHP-FPM
readiness. These runtime endpoints deliberately remain independent from
Pimcore product registration and database installation.
