# MySQL Chart Design

## v1 Scope

- `architecture: standalone | replication`
- official `mysql` image
- standalone or fixed source plus asynchronous read replicas
- init scripts through generated scripts or an existing ConfigMap
- optional `mysqld-exporter` and `ServiceMonitor`
- passwords through generated secrets or `existingSecret`

## Explicit Non-Goals

- InnoDB Cluster
- Group Replication
- automatic source promotion
- operator-style topology management

## Product Direction

- keep the chart smaller than Bitnami
- document replication as read scaling and operational recovery support
- expose dedicated endpoints for source and read replicas
- keep MySQL configuration centered on `my.cnf`, binlog, and replication semantics
